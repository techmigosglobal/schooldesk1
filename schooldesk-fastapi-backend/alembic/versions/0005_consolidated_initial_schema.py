"""
Consolidated initial schema migration.

This migration creates all remaining indexes and ensures column defaults
for tables created by migrations 0001-0004. It is idempotent and safe to
run on existing databases that already have the base tables from prior
migrations.

For fresh installations with no prior migrations, this migration will
create all tables from scratch in the correct dependency order.

Revision ID: 0005_consolidated_initial_schema
Revises: 0004_class_hub_setup_module
Create Date: 2026-06-09
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.engine import Connection

revision = "0005_consolidated_initial_schema"
down_revision = "0004_class_hub_setup_module"
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
    inspector = inspect(connection)
    return table_name in inspector.get_table_names()


def column_exists(connection: Connection, table_name: str, column_name: str) -> bool:
    inspector = inspect(connection)
    columns = {col["name"] for col in inspector.get_columns(table_name)}
    return column_name in columns


def index_exists(connection: Connection, index_name: str) -> bool:
    inspector = inspect(connection)
    return index_name in inspector.get_index_names([])


def fk_exists(connection: Connection, table_name: str, constraint_name: str) -> bool:
    inspector = inspect(connection)
    foreign_keys = inspector.get_foreign_keys(table_name)
    return any(fk.get("name") == constraint_name for fk in foreign_keys)


def upgrade() -> None:
    connection = op.get_bind()

    # =========================================================================
    # MIGRATION 0001 TABLES (re-create if missing for fresh installs)
    # =========================================================================

    if not table_exists(connection, "schools"):
        op.create_table(
            "schools",
            sa.Column("id", sa.String(length=36), primary_key=True),
            sa.Column("name", sa.String(length=160), nullable=False),
            sa.Column("school_type", sa.String(length=80), nullable=True),
            sa.Column("affiliation_board", sa.String(length=120), nullable=True),
            sa.Column("email", sa.String(length=160), nullable=True),
            sa.Column("phone", sa.String(length=40), nullable=True),
            sa.Column("city", sa.String(length=120), nullable=True),
            sa.Column("state", sa.String(length=120), nullable=True),
            sa.Column("principal_name", sa.String(length=160), nullable=True),
            sa.Column("registration_number", sa.String(length=120), nullable=True),
            sa.Column("logo_url", sa.String(length=500), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        )

    if not table_exists(connection, "users"):
        op.create_table(
            "users",
            sa.Column("id", sa.String(length=36), primary_key=True),
            sa.Column("school_id", sa.String(length=36), sa.ForeignKey("schools.id"), nullable=False),
            sa.Column("username", sa.String(length=80), nullable=False, unique=True),
            sa.Column("full_name", sa.String(length=160), nullable=False),
            sa.Column("role", sa.String(length=40), nullable=False),
            sa.Column("linked_type", sa.String(length=40), nullable=True),
            sa.Column("linked_id", sa.String(length=36), nullable=True),
            sa.Column("password_hash", sa.String(length=180), nullable=False),
            sa.Column("is_active", sa.Boolean(), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        )

    if not table_exists(connection, "roles"):
        op.create_table(
            "roles",
            sa.Column("id", sa.String(length=36), primary_key=True),
            sa.Column("school_id", sa.String(length=36), sa.ForeignKey("schools.id"), nullable=False),
            sa.Column("name", sa.String(length=60), nullable=False),
            sa.UniqueConstraint("school_id", "name", name="uq_roles_school_name"),
        )

    if not table_exists(connection, "permissions"):
        op.create_table(
            "permissions",
            sa.Column("id", sa.String(length=36), primary_key=True),
            sa.Column("code", sa.String(length=80), nullable=False, unique=True),
            sa.Column("description", sa.String(length=240), nullable=False),
        )

    if not table_exists(connection, "role_permissions"):
        op.create_table(
            "role_permissions",
            sa.Column("id", sa.String(length=36), primary_key=True),
            sa.Column("role_id", sa.String(length=36), sa.ForeignKey("roles.id"), nullable=False),
            sa.Column("permission_id", sa.String(length=36), sa.ForeignKey("permissions.id"), nullable=False),
            sa.UniqueConstraint("role_id", "permission_id", name="uq_role_permissions_role_permission"),
        )

    if not table_exists(connection, "user_roles"):
        op.create_table(
            "user_roles",
            sa.Column("id", sa.String(length=36), primary_key=True),
            sa.Column("user_id", sa.String(length=36), sa.ForeignKey("users.id"), nullable=False),
            sa.Column("role_id", sa.String(length=36), sa.ForeignKey("roles.id"), nullable=False),
            sa.UniqueConstraint("user_id", "role_id", name="uq_user_roles_user_role"),
        )

    if not table_exists(connection, "sections"):
        op.create_table(
            "sections",
            sa.Column("id", sa.String(length=36), primary_key=True),
            sa.Column("school_id", sa.String(length=36), sa.ForeignKey("schools.id"), nullable=False),
            sa.Column("name", sa.String(length=80), nullable=False),
            sa.Column("grade_id", sa.String(length=36), nullable=True),
            sa.Column("academic_year_id", sa.String(length=36), nullable=True),
            sa.Column("class_teacher_id", sa.String(length=36), nullable=True),
            sa.Column("room_id", sa.String(length=36), nullable=True),
            sa.Column("capacity", sa.Integer(), nullable=True),
        )

    if not table_exists(connection, "goals"):
        op.create_table(
            "goals",
            *scoped_columns(),
            sa.Column("title", sa.String(length=180), nullable=False),
            sa.Column("description", sa.Text(), nullable=False),
            sa.Column("status", sa.String(length=30), nullable=False),
            sa.Column("priority", sa.String(length=20), nullable=False),
            sa.Column("owner_user_id", sa.String(length=36), sa.ForeignKey("users.id"), nullable=False),
            sa.Column("starts_on", sa.Date(), nullable=True),
            sa.Column("due_on", sa.Date(), nullable=True),
            sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("archived_at", sa.DateTime(timezone=True), nullable=True),
        )

    if not table_exists(connection, "goal_key_results"):
        op.create_table(
            "goal_key_results",
            *scoped_columns(),
            sa.Column("goal_id", sa.String(length=36), sa.ForeignKey("goals.id"), nullable=False),
            sa.Column("title", sa.String(length=180), nullable=False),
            sa.Column("target_value", sa.Numeric(12, 2), nullable=True),
            sa.Column("current_value", sa.Numeric(12, 2), nullable=True),
            sa.Column("unit", sa.String(length=40), nullable=True),
            sa.Column("status", sa.String(length=30), nullable=False),
        )

    if not table_exists(connection, "tasks"):
        op.create_table(
            "tasks",
            *scoped_columns(),
            sa.Column("goal_id", sa.String(length=36), sa.ForeignKey("goals.id"), nullable=True),
            sa.Column("title", sa.String(length=180), nullable=False),
            sa.Column("description", sa.Text(), nullable=False),
            sa.Column("status", sa.String(length=30), nullable=False),
            sa.Column("priority", sa.String(length=20), nullable=False),
            sa.Column("scope_type", sa.String(length=20), nullable=False),
            sa.Column("scope_id", sa.String(length=36), nullable=True),
            sa.Column("assigned_role", sa.String(length=40), nullable=True),
            sa.Column("assigned_user_id", sa.String(length=36), sa.ForeignKey("users.id"), nullable=True),
            sa.Column("assigned_staff_id", sa.String(length=36), nullable=True),
            sa.Column("assigned_section_id", sa.String(length=36), sa.ForeignKey("sections.id"), nullable=True),
            sa.Column("due_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("progress_percent", sa.Integer(), nullable=False),
            sa.Column("evidence_url", sa.String(length=500), nullable=True),
            sa.Column("blocker_note", sa.Text(), nullable=True),
            sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("reopened_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("archived_at", sa.DateTime(timezone=True), nullable=True),
        )

    if not table_exists(connection, "task_checklist_items"):
        op.create_table(
            "task_checklist_items",
            *scoped_columns(),
            sa.Column("task_id", sa.String(length=36), sa.ForeignKey("tasks.id"), nullable=False),
            sa.Column("title", sa.String(length=180), nullable=False),
            sa.Column("sort_order", sa.Integer(), nullable=False),
            sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("completed_by", sa.String(length=36), sa.ForeignKey("users.id"), nullable=True),
        )

    if not table_exists(connection, "task_comments"):
        op.create_table(
            "task_comments",
            *scoped_columns(),
            sa.Column("task_id", sa.String(length=36), sa.ForeignKey("tasks.id"), nullable=False),
            sa.Column("author_user_id", sa.String(length=36), sa.ForeignKey("users.id"), nullable=False),
            sa.Column("body", sa.Text(), nullable=False),
            sa.Column("evidence_url", sa.String(length=500), nullable=True),
        )

    if not table_exists(connection, "audit_logs"):
        op.create_table(
            "audit_logs",
            *scoped_columns(),
            sa.Column("user_id", sa.String(length=36), sa.ForeignKey("users.id"), nullable=False),
            sa.Column("action", sa.String(length=60), nullable=False),
            sa.Column("module", sa.String(length=80), nullable=False),
            sa.Column("entity_type", sa.String(length=80), nullable=False),
            sa.Column("entity_id", sa.String(length=36), nullable=False),
            sa.Column("old_value", sa.Text(), nullable=False),
            sa.Column("new_value", sa.Text(), nullable=False),
        )

    if not table_exists(connection, "notification_logs"):
        op.create_table(
            "notification_logs",
            *scoped_columns(),
            sa.Column("recipient_user_id", sa.String(length=36), sa.ForeignKey("users.id"), nullable=True),
            sa.Column("recipient_role", sa.String(length=40), nullable=True),
            sa.Column("reference_type", sa.String(length=60), nullable=False),
            sa.Column("reference_id", sa.String(length=36), nullable=False),
            sa.Column("title", sa.String(length=180), nullable=False),
            sa.Column("body", sa.Text(), nullable=False),
            sa.Column("status", sa.String(length=30), nullable=False),
        )

    if not table_exists(connection, "approval_requests"):
        op.create_table(
            "approval_requests",
            *scoped_columns(),
            sa.Column("requester_user_id", sa.String(length=36), sa.ForeignKey("users.id"), nullable=False),
            sa.Column("module", sa.String(length=80), nullable=False),
            sa.Column("action", sa.String(length=80), nullable=False),
            sa.Column("status", sa.String(length=30), nullable=False),
            sa.Column("payload", sa.Text(), nullable=False),
        )

    # =========================================================================
    # MIGRATION 0002 TABLES
    # =========================================================================

    if not table_exists(connection, "academic_years"):
        op.create_table(
            "academic_years",
            *scoped_columns(),
            sa.Column("year_label", sa.String(length=40), nullable=False),
            sa.Column("start_date", sa.Date(), nullable=True),
            sa.Column("end_date", sa.Date(), nullable=True),
            sa.Column("is_current", sa.Boolean(), nullable=False),
            sa.Column("status", sa.String(length=40), nullable=False),
            sa.UniqueConstraint("school_id", "year_label", name="uq_academic_years_school_label"),
        )

    if not table_exists(connection, "academic_terms"):
        op.create_table(
            "academic_terms",
            *scoped_columns(),
            sa.Column("academic_year_id", sa.String(length=36), sa.ForeignKey("academic_years.id"), nullable=False),
            sa.Column("term_name", sa.String(length=80), nullable=False),
            sa.Column("start_date", sa.Date(), nullable=True),
            sa.Column("end_date", sa.Date(), nullable=True),
            sa.Column("sort_order", sa.Integer(), nullable=False),
            sa.Column("status", sa.String(length=40), nullable=False),
        )

    if not table_exists(connection, "grades"):
        op.create_table(
            "grades",
            *scoped_columns(),
            sa.Column("grade_number", sa.Integer(), nullable=False),
            sa.Column("grade_name", sa.String(length=80), nullable=False),
            sa.UniqueConstraint("school_id", "grade_number", name="uq_grades_school_number"),
        )

    if not table_exists(connection, "subjects"):
        op.create_table(
            "subjects",
            *scoped_columns(),
            sa.Column("department_id", sa.String(length=36), nullable=True),
            sa.Column("subject_name", sa.String(length=120), nullable=False),
            sa.Column("subject_code", sa.String(length=40), nullable=False),
            sa.Column("subject_type", sa.String(length=60), nullable=False),
            sa.Column("subject_color", sa.String(length=20), nullable=False),
            sa.UniqueConstraint("school_id", "subject_code", name="uq_subjects_school_code"),
        )

    if not table_exists(connection, "rooms"):
        op.create_table(
            "rooms",
            *scoped_columns(),
            sa.Column("room_number", sa.String(length=80), nullable=False),
            sa.Column("room_type", sa.String(length=60), nullable=False),
            sa.Column("capacity", sa.Integer(), nullable=False),
            sa.Column("block", sa.String(length=80), nullable=False),
            sa.Column("floor", sa.Integer(), nullable=False),
            sa.UniqueConstraint("school_id", "room_number", name="uq_rooms_school_number"),
        )

    if not table_exists(connection, "staff"):
        op.create_table(
            "staff",
            *scoped_columns(),
            sa.Column("staff_code", sa.String(length=80), nullable=False),
            sa.Column("first_name", sa.String(length=120), nullable=False),
            sa.Column("last_name", sa.String(length=120), nullable=False),
            sa.Column("email", sa.String(length=160), nullable=False),
            sa.Column("phone", sa.String(length=40), nullable=False),
            sa.Column("designation", sa.String(length=120), nullable=False),
            sa.Column("employment_type", sa.String(length=60), nullable=False),
            sa.Column("department_id", sa.String(length=36), nullable=True),
            sa.Column("department_name", sa.String(length=120), nullable=False),
            sa.Column("status", sa.String(length=40), nullable=False),
            sa.Column("date_of_birth", sa.Date(), nullable=True),
            sa.Column("gender", sa.String(length=40), nullable=False),
            sa.Column("join_date", sa.Date(), nullable=True),
            sa.Column("photo_url", sa.String(length=500), nullable=False),
            sa.UniqueConstraint("school_id", "staff_code", name="uq_staff_school_code"),
        )

    if not table_exists(connection, "students"):
        op.create_table(
            "students",
            *scoped_columns(),
            sa.Column("student_code", sa.String(length=80), nullable=False),
            sa.Column("admission_number", sa.String(length=80), nullable=False),
            sa.Column("first_name", sa.String(length=120), nullable=False),
            sa.Column("last_name", sa.String(length=120), nullable=False),
            sa.Column("date_of_birth", sa.Date(), nullable=True),
            sa.Column("admission_date", sa.Date(), nullable=True),
            sa.Column("gender", sa.String(length=40), nullable=False),
            sa.Column("current_section_id", sa.String(length=36), sa.ForeignKey("sections.id"), nullable=True),
            sa.Column("status", sa.String(length=40), nullable=False),
            sa.Column("photo_url", sa.String(length=500), nullable=False),
            sa.UniqueConstraint("school_id", "student_code", name="uq_students_school_code"),
            sa.UniqueConstraint("school_id", "admission_number", name="uq_students_school_admission"),
        )

    # =========================================================================
    # MIGRATION 0003 TABLES
    # =========================================================================

    if not table_exists(connection, "leave_types"):
        op.create_table(
            "leave_types",
            *scoped_columns(),
            sa.Column("leave_name", sa.String(length=120), nullable=False),
            sa.Column("description", sa.Text(), nullable=False),
            sa.Column("max_days_per_year", sa.Numeric(6, 2), nullable=False),
            sa.Column("applicable_to", sa.String(length=40), nullable=False),
            sa.UniqueConstraint("school_id", "leave_name", name="uq_leave_types_school_name"),
        )

    if not table_exists(connection, "leave_balances"):
        op.create_table(
            "leave_balances",
            *scoped_columns(),
            sa.Column("staff_id", sa.String(length=36), sa.ForeignKey("staff.id"), nullable=False),
            sa.Column("leave_type_id", sa.String(length=36), sa.ForeignKey("leave_types.id"), nullable=False),
            sa.Column("academic_year_id", sa.String(length=36), sa.ForeignKey("academic_years.id"), nullable=False),
            sa.Column("total_entitled", sa.Numeric(6, 2), nullable=False),
            sa.Column("used_days", sa.Numeric(6, 2), nullable=False),
            sa.Column("remaining_days", sa.Numeric(6, 2), nullable=False),
            sa.UniqueConstraint(
                "school_id",
                "staff_id",
                "leave_type_id",
                "academic_year_id",
                name="uq_leave_balance_staff_type_year",
            ),
        )

    if not table_exists(connection, "leave_applications"):
        op.create_table(
            "leave_applications",
            *scoped_columns(),
            sa.Column("staff_id", sa.String(length=36), sa.ForeignKey("staff.id"), nullable=False),
            sa.Column("leave_type_id", sa.String(length=36), sa.ForeignKey("leave_types.id"), nullable=False),
            sa.Column("from_date", sa.Date(), nullable=False),
            sa.Column("to_date", sa.Date(), nullable=False),
            sa.Column("half_day", sa.Boolean(), nullable=False),
            sa.Column("total_days", sa.Numeric(6, 2), nullable=False),
            sa.Column("reason", sa.Text(), nullable=False),
            sa.Column("status", sa.String(length=40), nullable=False),
            sa.Column("rejection_reason", sa.Text(), nullable=True),
            sa.Column("applied_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("actioned_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("actioned_by", sa.String(length=36), sa.ForeignKey("users.id"), nullable=True),
        )

    if not table_exists(connection, "student_leave_applications"):
        op.create_table(
            "student_leave_applications",
            *scoped_columns(),
            sa.Column("student_id", sa.String(length=36), sa.ForeignKey("students.id"), nullable=False),
            sa.Column("parent_user_id", sa.String(length=36), sa.ForeignKey("users.id"), nullable=True),
            sa.Column("leave_type", sa.String(length=120), nullable=False),
            sa.Column("from_date", sa.Date(), nullable=False),
            sa.Column("to_date", sa.Date(), nullable=False),
            sa.Column("half_day", sa.Boolean(), nullable=False),
            sa.Column("total_days", sa.Numeric(6, 2), nullable=False),
            sa.Column("reason", sa.Text(), nullable=False),
            sa.Column("status", sa.String(length=40), nullable=False),
            sa.Column("rejection_reason", sa.Text(), nullable=True),
            sa.Column("applied_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("actioned_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("actioned_by", sa.String(length=36), sa.ForeignKey("users.id"), nullable=True),
        )

    # =========================================================================
    # MIGRATION 0004 TABLES
    # =========================================================================

    if not table_exists(connection, "grade_subjects"):
        op.create_table(
            "grade_subjects",
            *scoped_columns(),
            sa.Column("academic_year_id", sa.String(length=36), sa.ForeignKey("academic_years.id"), nullable=False),
            sa.Column("grade_id", sa.String(length=36), sa.ForeignKey("grades.id"), nullable=False),
            sa.Column("subject_id", sa.String(length=36), sa.ForeignKey("subjects.id"), nullable=False),
            sa.Column("periods_per_week", sa.Integer(), nullable=False),
            sa.Column("max_marks", sa.Integer(), nullable=False),
            sa.Column("pass_marks", sa.Integer(), nullable=False),
            sa.Column("is_mandatory", sa.Boolean(), nullable=False),
            sa.UniqueConstraint(
                "school_id",
                "academic_year_id",
                "grade_id",
                "subject_id",
                name="uq_grade_subject_year_grade_subject",
            ),
        )

    if not table_exists(connection, "staff_subjects"):
        op.create_table(
            "staff_subjects",
            *scoped_columns(),
            sa.Column("academic_year_id", sa.String(length=36), sa.ForeignKey("academic_years.id"), nullable=False),
            sa.Column("grade_id", sa.String(length=36), sa.ForeignKey("grades.id"), nullable=False),
            sa.Column("section_id", sa.String(length=36), sa.ForeignKey("sections.id"), nullable=True),
            sa.Column("subject_id", sa.String(length=36), sa.ForeignKey("subjects.id"), nullable=False),
            sa.Column("staff_id", sa.String(length=36), sa.ForeignKey("staff.id"), nullable=True),
            sa.Column("is_primary", sa.Boolean(), nullable=False),
            sa.UniqueConstraint(
                "school_id",
                "academic_year_id",
                "grade_id",
                "section_id",
                "subject_id",
                "staff_id",
                name="uq_staff_subject_year_scope",
            ),
        )

    if not table_exists(connection, "fee_structures"):
        op.create_table(
            "fee_structures",
            *scoped_columns(),
            sa.Column("academic_year_id", sa.String(length=36), sa.ForeignKey("academic_years.id"), nullable=False),
            sa.Column("grade_id", sa.String(length=36), sa.ForeignKey("grades.id"), nullable=False),
            sa.Column("section_id", sa.String(length=36), sa.ForeignKey("sections.id"), nullable=True),
            sa.Column("category_name", sa.String(length=120), nullable=False),
            sa.Column("frequency", sa.String(length=40), nullable=False),
            sa.Column("amount", sa.Numeric(12, 2), nullable=False),
            sa.Column("due_day", sa.Integer(), nullable=False),
            sa.Column("late_fine_per_day", sa.Numeric(10, 2), nullable=False),
            sa.Column("status", sa.String(length=40), nullable=False),
        )

    # =========================================================================
    # ADD INDEXES MISSING FROM PREVIOUS MIGRATIONS
    # These indexes are defined in the SQLAlchemy models but not created
    # by migrations 0001-0004. We add them here for completeness.
    # =========================================================================

    # Indexes on users table
    if not index_exists(connection, "ix_users_school_id"):
        op.create_index("ix_users_school_id", "users", ["school_id"])
    if not index_exists(connection, "ix_users_username"):
        op.create_index("ix_users_username", "users", ["username"], unique=True)
    if not index_exists(connection, "ix_users_role"):
        op.create_index("ix_users_role", "users", ["role"])
    if not index_exists(connection, "ix_users_linked_id"):
        op.create_index("ix_users_linked_id", "users", ["linked_id"])

    # Indexes on roles table
    if not index_exists(connection, "ix_roles_school_id"):
        op.create_index("ix_roles_school_id", "roles", ["school_id"])

    # Indexes on sections table
    if not index_exists(connection, "ix_sections_school_id"):
        op.create_index("ix_sections_school_id", "sections", ["school_id"])
    if not index_exists(connection, "ix_sections_grade_id"):
        op.create_index("ix_sections_grade_id", "sections", ["grade_id"])
    if not index_exists(connection, "ix_sections_academic_year_id"):
        op.create_index("ix_sections_academic_year_id", "sections", ["academic_year_id"])
    if not index_exists(connection, "ix_sections_class_teacher_id"):
        op.create_index("ix_sections_class_teacher_id", "sections", ["class_teacher_id"])
    if not index_exists(connection, "ix_sections_room_id"):
        op.create_index("ix_sections_room_id", "sections", ["room_id"])

    # Indexes on staff table
    if not index_exists(connection, "ix_staff_school_id"):
        op.create_index("ix_staff_school_id", "staff", ["school_id"])
    if not index_exists(connection, "ix_staff_department_id"):
        op.create_index("ix_staff_department_id", "staff", ["department_id"])

    # Indexes on students table
    if not index_exists(connection, "ix_students_school_id"):
        op.create_index("ix_students_school_id", "students", ["school_id"])
    if not index_exists(connection, "ix_students_current_section_id"):
        op.create_index("ix_students_current_section_id", "students", ["current_section_id"])

    # Indexes on academic_terms table
    if not index_exists(connection, "ix_academic_terms_academic_year_id"):
        op.create_index("ix_academic_terms_academic_year_id", "academic_terms", ["academic_year_id"])

    # Indexes on subjects table
    if not index_exists(connection, "ix_subjects_school_id"):
        op.create_index("ix_subjects_school_id", "subjects", ["school_id"])
    if not index_exists(connection, "ix_subjects_department_id"):
        op.create_index("ix_subjects_department_id", "subjects", ["department_id"])

    # Indexes on grade_subjects table
    if not index_exists(connection, "ix_grade_subjects_academic_year_id"):
        op.create_index("ix_grade_subjects_academic_year_id", "grade_subjects", ["academic_year_id"])
    if not index_exists(connection, "ix_grade_subjects_grade_id"):
        op.create_index("ix_grade_subjects_grade_id", "grade_subjects", ["grade_id"])
    if not index_exists(connection, "ix_grade_subjects_subject_id"):
        op.create_index("ix_grade_subjects_subject_id", "grade_subjects", ["subject_id"])

    # Indexes on staff_subjects table
    if not index_exists(connection, "ix_staff_subjects_academic_year_id"):
        op.create_index("ix_staff_subjects_academic_year_id", "staff_subjects", ["academic_year_id"])
    if not index_exists(connection, "ix_staff_subjects_grade_id"):
        op.create_index("ix_staff_subjects_grade_id", "staff_subjects", ["grade_id"])
    if not index_exists(connection, "ix_staff_subjects_section_id"):
        op.create_index("ix_staff_subjects_section_id", "staff_subjects", ["section_id"])
    if not index_exists(connection, "ix_staff_subjects_subject_id"):
        op.create_index("ix_staff_subjects_subject_id", "staff_subjects", ["subject_id"])
    if not index_exists(connection, "ix_staff_subjects_staff_id"):
        op.create_index("ix_staff_subjects_staff_id", "staff_subjects", ["staff_id"])

    # Indexes on leave_balances table
    if not index_exists(connection, "ix_leave_balances_staff_id"):
        op.create_index("ix_leave_balances_staff_id", "leave_balances", ["staff_id"])
    if not index_exists(connection, "ix_leave_balances_leave_type_id"):
        op.create_index("ix_leave_balances_leave_type_id", "leave_balances", ["leave_type_id"])
    if not index_exists(connection, "ix_leave_balances_academic_year_id"):
        op.create_index("ix_leave_balances_academic_year_id", "leave_balances", ["academic_year_id"])

    # Indexes on leave_applications table
    if not index_exists(connection, "ix_leave_applications_staff_id"):
        op.create_index("ix_leave_applications_staff_id", "leave_applications", ["staff_id"])
    if not index_exists(connection, "ix_leave_applications_leave_type_id"):
        op.create_index("ix_leave_applications_leave_type_id", "leave_applications", ["leave_type_id"])

    # Indexes on student_leave_applications table
    if not index_exists(connection, "ix_student_leave_applications_student_id"):
        op.create_index("ix_student_leave_applications_student_id", "student_leave_applications", ["student_id"])
    if not index_exists(connection, "ix_student_leave_applications_parent_user_id"):
        op.create_index("ix_student_leave_applications_parent_user_id", "student_leave_applications", ["parent_user_id"])

    # Indexes on fee_structures table
    if not index_exists(connection, "ix_fee_structures_academic_year_id"):
        op.create_index("ix_fee_structures_academic_year_id", "fee_structures", ["academic_year_id"])
    if not index_exists(connection, "ix_fee_structures_grade_id"):
        op.create_index("ix_fee_structures_grade_id", "fee_structures", ["grade_id"])
    if not index_exists(connection, "ix_fee_structures_section_id"):
        op.create_index("ix_fee_structures_section_id", "fee_structures", ["section_id"])


def downgrade() -> None:
    # This migration is additive - it only creates tables and indexes.
    # Tables created by migrations 0001-0004 should be dropped by those
    # migrations' downgrade functions. To avoid breaking the migration chain,
    # we do not drop anything here.
    pass