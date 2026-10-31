"""Resync Postgres ID sequences with existing row IDs.

Revision ID: 20261031_resync_ids
Revises: 20261031_firebase_uid
Create Date: 2026-10-31
"""
from alembic import op
import sqlalchemy as sa


revision = "20261031_resync_ids"
down_revision = "20261031_firebase_uid"
branch_labels = None
depends_on = None


def upgrade() -> None:
    for table in ("users", "location_pings", "sos_alerts", "sos_dispatch_attempts"):
        op.execute(sa.text(
            f"""SELECT setval(
                pg_get_serial_sequence('{table}', 'id'),
                COALESCE((SELECT MAX(id) FROM {table}), 1),
                (SELECT MAX(id) FROM {table}) IS NOT NULL
            )"""
        ))


def downgrade() -> None:
    pass