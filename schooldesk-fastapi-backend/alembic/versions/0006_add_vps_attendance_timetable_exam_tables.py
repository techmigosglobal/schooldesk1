"""
Add missing tables: vps_fees, guardians, timetable_slots, exams, exam_marks, staff_attendance, student_attendance.

These tables are defined as SQLAlchemy models but had no Alembic migration, causing
UndefinedTable errors at runtime when querying these endpoints.

Revision ID: 0006_add_vps_attendance_timetable_exam_tables
Revises: 0005_consolidated_initial_schema
Create Date: 2026-06-09
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.engine import Connection

revision = "0006_add_vps_attendance_timetable_exam_tables"
down_revision = "0005_consolidated_initial_schema"
branch_labels = None
depends_on = None


def scoped_columns() -> list[sa.Column]:
    return [
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("school_id", sa.String(length=36), nullable=False, index=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_by", sa.String(length=36), nullable=True),
        sa.Column("updated_by", sa.String(length=36), nullable=True),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False),
    ]


def table_exists(connection: Connection, table_name: str) -> bool:
    from sqlalchemy import inspect
    inspector = inspect(connection)
    return table_name in inspector.get_table_names()


def upgrade() -> None:
    connection = op.get_bind()

    # =========================================================================
    # ADDITIVE: add read_at to notification_logs (model added this column after initial migration)
    # =========================================================================
    try:
        op.execute(
            "ALTER TABLE notification_logs ADD COLUMN IF NOT EXISTS read_at TIMESTAMP WITH TIME ZONE"
        )
    except Exception:
        pass  # Column may already exist in some DB states

    # =========================================================================
    # VPS FEES
    # =========================================================================
    if not table_exists(connection, "vps_fees"):
        op.create_table(
            "vps_fees",
            *scoped_columns(),
            sa.Column("name", sa.String(length=180), nullable=False),
            sa.Column("amount", sa.Numeric(12, 2), nullable=False),
            sa.Column("frequency", sa.String(length=40), nullable=False),
            sa.Column("due_day", sa.Integer(), nullable=False),
            sa.Column("late_fine_per_day", sa.Numeric(10, 2), nullable=False),
            sa.Column("status", sa.String(length=40), nullable=False),
        )

    # =========================================================================
    # GUARDIANS
    # =========================================================================
    if not table_exists(connection, "guardians"):
        op.create_table(
            "guardians",
            *scoped_columns(),
            sa.Column("student_id", sa.String(length=36), nullable=False, index=True),
            sa.Column("name", sa.String(length=160), nullable=False),
            sa.Column("phone", sa.String(length=40), nullable=False),
            sa.Column("email", sa.String(length=160), nullable=False),
            sa.Column("relation", sa.String(length=40), nullable=False),
            sa.Column("is_primary", sa.Boolean(), nullable=False),
        )

    # =========================================================================
    # TIMETABLE SLOTS
    # =========================================================================
    if not table_exists(connection, "timetable_slots"):
        op.create_table(
            "timetable_slots",
            *scoped_columns(),
            sa.Column("academic_year_id", sa.String(length=36), sa.ForeignKey("academic_years.id"), nullable=False, index=True),
            sa.Column("grade_id", sa.String(length=36), sa.ForeignKey("grades.id"), nullable=False, index=True),
            sa.Column("section_id", sa.String(length=36), sa.ForeignKey("sections.id"), nullable=False, index=True),
            sa.Column("day_of_week", sa.Integer(), nullable=False),
            sa.Column("period_number", sa.Integer(), nullable=False),
            sa.Column("subject_id", sa.String(length=36), sa.ForeignKey("subjects.id"), nullable=False, index=True),
            sa.Column("staff_id", sa.String(length=36), sa.ForeignKey("staff.id"), nullable=True, index=True),
            sa.Column("room_id", sa.String(length=36), nullable=True),
            sa.Column("start_time", sa.Time(), nullable=False),
            sa.Column("end_time", sa.Time(), nullable=False),
        )

    # =========================================================================
    # EXAMS
    # =========================================================================
    if not table_exists(connection, "exams"):
        op.create_table(
            "exams",
            *scoped_columns(),
            sa.Column("academic_year_id", sa.String(length=36), sa.ForeignKey("academic_years.id"), nullable=False, index=True),
            sa.Column("term_id", sa.String(length=36), nullable=True, index=True),
            sa.Column("exam_name", sa.String(length=180), nullable=False),
            sa.Column("exam_date", sa.Date(), nullable=False, index=True),
            sa.Column("description", sa.Text(), nullable=False),
            sa.Column("weight", sa.Numeric(4, 2), nullable=False),
            sa.Column("is_practical", sa.Boolean(), nullable=False),
            sa.Column("status", sa.String(length=40), nullable=False),
        )
        op.create_unique_constraint(
            "uq_exam_school_year_name_date",
            "exams",
            ["school_id", "academic_year_id", "exam_name", "exam_date"],
        )

    # =========================================================================
    # EXAM MARKS
    # =========================================================================
    if not table_exists(connection, "exam_marks"):
        op.create_table(
            "exam_marks",
            *scoped_columns(),
            sa.Column("exam_id", sa.String(length=36), sa.ForeignKey("exams.id"), nullable=False, index=True),
            sa.Column("student_id", sa.String(length=36), sa.ForeignKey("students.id"), nullable=False, index=True),
            sa.Column("grade_subject_id", sa.String(length=36), sa.ForeignKey("grade_subjects.id"), nullable=False, index=True),
            sa.Column("marks_obtained", sa.Numeric(8, 2), nullable=False),
        )
        op.create_unique_constraint(
            "uq_exam_mark_unique",
            "exam_marks",
            ["exam_id", "student_id", "grade_subject_id"],
        )

    # =========================================================================
    # STAFF ATTENDANCE
    # =========================================================================
    if not table_exists(connection, "staff_attendance"):
        op.create_table(
            "staff_attendance",
            *scoped_columns(),
            sa.Column("staff_id", sa.String(length=36), sa.ForeignKey("staff.id"), nullable=False, index=True),
            sa.Column("date", sa.Date(), nullable=False, index=True),
            sa.Column("status", sa.String(length=40), nullable=False),
            sa.Column("marked_by", sa.String(length=36), nullable=False),
            sa.Column("marked_at", sa.DateTime(timezone=True), nullable=False),
        )
        # Composite unique to prevent duplicate attendance records
        op.create_unique_constraint(
            "uq_staff_attendance_unique",
            "staff_attendance",
            ["school_id", "staff_id", "date"],
        )

    # =========================================================================
    # STUDENT ATTENDANCE
    # =========================================================================
    if not table_exists(connection, "student_attendance"):
        op.create_table(
            "student_attendance",
            *scoped_columns(),
            sa.Column("student_id", sa.String(length=36), sa.ForeignKey("students.id"), nullable=False, index=True),
            sa.Column("section_id", sa.String(length=36), sa.ForeignKey("sections.id"), nullable=False, index=True),
            sa.Column("date", sa.Date(), nullable=False, index=True),
            sa.Column("status", sa.String(length=40), nullable=False),
            sa.Column("marked_by", sa.String(length=36), nullable=False),
            sa.Column("marked_at", sa.DateTime(timezone=True), nullable=False),
        )
        # Composite unique to prevent duplicate attendance records
        op.create_unique_constraint(
            "uq_student_attendance_unique",
            "student_attendance",
            ["school_id", "student_id", "date"],
        )


def downgrade() -> None:
    op.drop_table("student_attendance")
    op.drop_table("staff_attendance")
    op.drop_table("exam_marks")
    op.drop_table("exams")
    op.drop_table("timetable_slots")
    op.drop_table("guardians")
    op.drop_table("vps_fees")