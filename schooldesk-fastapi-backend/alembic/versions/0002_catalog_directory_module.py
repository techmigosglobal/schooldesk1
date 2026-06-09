from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "0002_catalog_directory_module"
down_revision = "0001_goal_task_module"
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
    for name, column_type in [
        ("school_type", sa.String(length=80)),
        ("affiliation_board", sa.String(length=120)),
        ("email", sa.String(length=160)),
        ("phone", sa.String(length=40)),
        ("city", sa.String(length=120)),
        ("state", sa.String(length=120)),
        ("principal_name", sa.String(length=160)),
        ("registration_number", sa.String(length=120)),
        ("logo_url", sa.String(length=500)),
        ("updated_at", sa.DateTime(timezone=True)),
    ]:
        op.add_column("schools", sa.Column(name, column_type, nullable=True))

    for name, column_type in [
        ("grade_id", sa.String(length=36)),
        ("academic_year_id", sa.String(length=36)),
        ("room_id", sa.String(length=36)),
        ("capacity", sa.Integer()),
    ]:
        op.add_column("sections", sa.Column(name, column_type, nullable=True))

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
    op.create_table(
        "grades",
        *scoped_columns(),
        sa.Column("grade_number", sa.Integer(), nullable=False),
        sa.Column("grade_name", sa.String(length=80), nullable=False),
        sa.UniqueConstraint("school_id", "grade_number", name="uq_grades_school_number"),
    )
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


def downgrade() -> None:
    for table_name in [
        "students",
        "staff",
        "rooms",
        "subjects",
        "grades",
        "academic_terms",
        "academic_years",
    ]:
        op.drop_table(table_name)

    for name in ["capacity", "room_id", "academic_year_id", "grade_id"]:
        op.drop_column("sections", name)

    for name in [
        "updated_at",
        "logo_url",
        "registration_number",
        "principal_name",
        "state",
        "city",
        "phone",
        "email",
        "affiliation_board",
        "school_type",
    ]:
        op.drop_column("schools", name)
