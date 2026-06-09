from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "0004_class_hub_setup_module"
down_revision = "0003_leave_module"
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


def downgrade() -> None:
    for table_name in ["fee_structures", "staff_subjects", "grade_subjects"]:
        op.drop_table(table_name)
