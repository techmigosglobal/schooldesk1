from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "0003_leave_module"
down_revision = "0002_catalog_directory_module"
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
        "leave_types",
        *scoped_columns(),
        sa.Column("leave_name", sa.String(length=120), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("max_days_per_year", sa.Numeric(6, 2), nullable=False),
        sa.Column("applicable_to", sa.String(length=40), nullable=False),
        sa.UniqueConstraint("school_id", "leave_name", name="uq_leave_types_school_name"),
    )
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


def downgrade() -> None:
    for table_name in [
        "student_leave_applications",
        "leave_applications",
        "leave_balances",
        "leave_types",
    ]:
        op.drop_table(table_name)
