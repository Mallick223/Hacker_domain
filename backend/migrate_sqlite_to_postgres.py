"""One-off data migration from the legacy SQLite database into Postgres."""

import sys

from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

from app import models
from app.config import settings

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

TABLES_IN_ORDER = [models.User, models.LocationPing, models.SosAlert]

try:
    for model in TABLES_IN_ORDER:
        rows = src.query(model).all()
        print(f"  {model.__tablename__}: {len(rows)} rows")
        for row in rows:
            data = {column.name: getattr(row, column.name) for column in model.__table__.columns}
            dst.merge(model(**data))
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
    src_engine.dispose()
    dst_engine.dispose()
