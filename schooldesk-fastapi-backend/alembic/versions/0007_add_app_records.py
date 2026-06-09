"""Add app_records for FastAPI-only compatibility modules.

Revision ID: 0007_add_app_records
Revises: 0006_add_vps_attendance_timetable_exam_tables
Create Date: 2026-06-09
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.engine import Connection

revision = "0007_add_app_records"
down_revision = "0006_add_vps_attendance_timetable_exam_tables"
branch_labels = None
depends_on = None


def table_exists(connection: Connection, table_name: str) -> bool:
    from sqlalchemy import inspect

    return table_name in inspect(connection).get_table_names()


def upgrade() -> None:
    connection = op.get_bind()
    if table_exists(connection, "app_records"):
        return

    op.create_table(
        "app_records",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("school_id", sa.String(length=36), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_by", sa.String(length=36), nullable=True),
        sa.Column("updated_by", sa.String(length=36), nullable=True),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("resource", sa.String(length=160), nullable=False),
        sa.Column("parent_id", sa.String(length=36), nullable=True),
        sa.Column("owner_role", sa.String(length=40), nullable=False),
        sa.Column("owner_user_id", sa.String(length=36), nullable=True),
        sa.Column("owner_staff_id", sa.String(length=36), nullable=True),
        sa.Column("owner_student_id", sa.String(length=36), nullable=True),
        sa.Column("status", sa.String(length=60), nullable=False),
        sa.Column("title", sa.String(length=240), nullable=False),
        sa.Column("payload", sa.JSON(), nullable=False),
        sa.Column("notes", sa.Text(), nullable=False),
    )
    for column in (
        "school_id",
        "resource",
        "parent_id",
        "owner_role",
        "owner_user_id",
        "owner_staff_id",
        "owner_student_id",
        "status",
    ):
        op.create_index(f"ix_app_records_{column}", "app_records", [column])


def downgrade() -> None:
    connection = op.get_bind()
    if table_exists(connection, "app_records"):
        op.drop_table("app_records")
