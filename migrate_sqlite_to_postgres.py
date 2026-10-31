"""
One-off data migration: copies existing rows out of the old
tourist_safety.db (SQLite) into Postgres.

Run this ONCE, after:
  1. Postgres is up (docker-compose up -d postgres)
  2. Alembic has created the schema in Postgres:
       alembic upgrade head
  3. DATABASE_URL in .env points at Postgres

Usage:
    python migrate_sqlite_to_postgres.py [path-to-old-sqlite-file]

Defaults to ./tourist_safety.db if no path given.
"""

import sys
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

from app.config import settings
from app.database import Base
from app import models

SQLITE_PATH = sys.argv[1] if len(sys.argv) > 1 else "tourist_safety.db"
sqlite_url = f"sqlite:///{SQLITE_PATH}"

if "sqlite" in settings.database_url:
    print(
        "ERROR: DATABASE_URL in your .env is still pointing at SQLite.\n"
        "Set DATABASE_URL to your Postgres connection string before running this."
    )
    sys.exit(1)

print(f"Source (SQLite):  {sqlite_url}")
print(f"Target (Postgres): {settings.database_url}")

src_engine = create_engine(sqlite_url, connect_args={"check_same_thread": False})
dst_engine = create_engine(settings.database_url)

SrcSession = sessionmaker(bind=src_engine)
DstSession = sessionmaker(bind=dst_engine)

src = SrcSession()
dst = DstSession()

# Order matters: users first (parent), then anything with a user_id FK.
TABLES_IN_ORDER = [models.User, models.LocationPing, models.SosAlert]

try:
    for model in TABLES_IN_ORDER:
        rows = src.query(model).all()
        print(f"  {model.__tablename__}: {len(rows)} rows")

        for row in rows:
            # Detach the row's state and re-insert as a plain dict of columns,
            # so we're not carrying the SQLite session identity along.
            data = {c.name: getattr(row, c.name) for c in model.__table__.columns}
            dst.merge(model(**data))  # merge = insert-or-update by PK, safe to re-run

        dst.commit()
        print(f"  -> committed {model.__tablename__}")

    for table in ("users", "location_pings", "sos_alerts", "sos_dispatch_attempts"):
        dst.execute(text(
            f"""SELECT setval(
                pg_get_serial_sequence('{table}', 'id'),
                COALESCE((SELECT MAX(id) FROM {table}), 1),
                (SELECT MAX(id) FROM {table}) IS NOT NULL
            )"""
        ))
    dst.commit()
    print("Done. Verify row counts against the old SQLite DB before decommissioning it.")

except Exception:
    dst.rollback()
    raise
finally:
    src.close()
    dst.close()
