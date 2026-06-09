from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "0001_goal_task_module"
down_revision = None
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


def upgrade() -> None:
    op.create_table(
        "schools",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("name", sa.String(length=160), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
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
    op.create_table(
        "roles",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("school_id", sa.String(length=36), sa.ForeignKey("schools.id"), nullable=False),
        sa.Column("name", sa.String(length=60), nullable=False),
        sa.UniqueConstraint("school_id", "name", name="uq_roles_school_name"),
    )
    op.create_table(
        "permissions",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("code", sa.String(length=80), nullable=False, unique=True),
        sa.Column("description", sa.String(length=240), nullable=False),
    )
    op.create_table(
        "role_permissions",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("role_id", sa.String(length=36), sa.ForeignKey("roles.id"), nullable=False),
        sa.Column("permission_id", sa.String(length=36), sa.ForeignKey("permissions.id"), nullable=False),
        sa.UniqueConstraint("role_id", "permission_id", name="uq_role_permissions_role_permission"),
    )
    op.create_table(
        "user_roles",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("user_id", sa.String(length=36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("role_id", sa.String(length=36), sa.ForeignKey("roles.id"), nullable=False),
        sa.UniqueConstraint("user_id", "role_id", name="uq_user_roles_user_role"),
    )
    op.create_table(
        "sections",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("school_id", sa.String(length=36), sa.ForeignKey("schools.id"), nullable=False),
        sa.Column("name", sa.String(length=80), nullable=False),
        sa.Column("class_teacher_id", sa.String(length=36), nullable=True),
    )
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
    op.create_table(
        "task_checklist_items",
        *scoped_columns(),
        sa.Column("task_id", sa.String(length=36), sa.ForeignKey("tasks.id"), nullable=False),
        sa.Column("title", sa.String(length=180), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("completed_by", sa.String(length=36), sa.ForeignKey("users.id"), nullable=True),
    )
    op.create_table(
        "task_comments",
        *scoped_columns(),
        sa.Column("task_id", sa.String(length=36), sa.ForeignKey("tasks.id"), nullable=False),
        sa.Column("author_user_id", sa.String(length=36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("evidence_url", sa.String(length=500), nullable=True),
    )
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
    op.create_table(
        "approval_requests",
        *scoped_columns(),
        sa.Column("requester_user_id", sa.String(length=36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("module", sa.String(length=80), nullable=False),
        sa.Column("action", sa.String(length=80), nullable=False),
        sa.Column("status", sa.String(length=30), nullable=False),
        sa.Column("payload", sa.Text(), nullable=False),
    )


def downgrade() -> None:
    for table in [
        "approval_requests",
        "notification_logs",
        "audit_logs",
        "task_comments",
        "task_checklist_items",
        "tasks",
        "goal_key_results",
        "goals",
        "sections",
        "user_roles",
        "role_permissions",
        "permissions",
        "roles",
        "users",
        "schools",
    ]:
        op.drop_table(table)

