"""Add Firebase UID mapping and allow Firebase-managed accounts.

Revision ID: 20261031_firebase_uid
Revises: cc0dbc1bfed5
Create Date: 2026-10-31
"""
from alembic import op
import sqlalchemy as sa


revision = "20261031_firebase_uid"
down_revision = "cc0dbc1bfed5"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("firebase_uid", sa.String(), nullable=True))
    op.create_index("ix_users_firebase_uid", "users", ["firebase_uid"], unique=True)
    op.alter_column(
        "users",
        "hashed_password",
        existing_type=sa.String(),
        nullable=True,
    )


def downgrade() -> None:
    op.alter_column(
        "users",
        "hashed_password",
        existing_type=sa.String(),
        nullable=False,
    )
    op.drop_index("ix_users_firebase_uid", table_name="users")
    op.drop_column("users", "firebase_uid")