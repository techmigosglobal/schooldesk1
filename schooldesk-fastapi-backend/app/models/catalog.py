from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Integer, Numeric, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, SchoolScopedMixin


class AcademicYear(Base, SchoolScopedMixin):
    __tablename__ = "academic_years"
    __table_args__ = (UniqueConstraint("school_id", "year_label", name="uq_academic_years_school_label"),)

    year_label: Mapped[str] = mapped_column(String(40), nullable=False)
    start_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    end_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    is_current: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    status: Mapped[str] = mapped_column(String(40), default="upcoming", nullable=False)


class AcademicTerm(Base, SchoolScopedMixin):
    __tablename__ = "academic_terms"

    academic_year_id: Mapped[str] = mapped_column(String(36), ForeignKey("academic_years.id"), nullable=False, index=True)
    term_name: Mapped[str] = mapped_column(String(80), nullable=False)
    start_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    end_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    status: Mapped[str] = mapped_column(String(40), default="active", nullable=False)


class Grade(Base, SchoolScopedMixin):
    __tablename__ = "grades"
    __table_args__ = (UniqueConstraint("school_id", "grade_number", name="uq_grades_school_number"),)

    grade_number: Mapped[int] = mapped_column(Integer, nullable=False)
    grade_name: Mapped[str] = mapped_column(String(80), nullable=False)


class Subject(Base, SchoolScopedMixin):
    __tablename__ = "subjects"
    __table_args__ = (UniqueConstraint("school_id", "subject_code", name="uq_subjects_school_code"),)

    department_id: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)
    subject_name: Mapped[str] = mapped_column(String(120), nullable=False)
    subject_code: Mapped[str] = mapped_column(String(40), nullable=False)
    subject_type: Mapped[str] = mapped_column(String(60), default="core", nullable=False)
    subject_color: Mapped[str] = mapped_column(String(20), default="#2563EB", nullable=False)


class GradeSubject(Base, SchoolScopedMixin):
    __tablename__ = "grade_subjects"
    __table_args__ = (
        UniqueConstraint("school_id", "academic_year_id", "grade_id", "subject_id", name="uq_grade_subject_year_grade_subject"),
    )

    academic_year_id: Mapped[str] = mapped_column(String(36), ForeignKey("academic_years.id"), nullable=False, index=True)
    grade_id: Mapped[str] = mapped_column(String(36), ForeignKey("grades.id"), nullable=False, index=True)
    subject_id: Mapped[str] = mapped_column(String(36), ForeignKey("subjects.id"), nullable=False, index=True)
    periods_per_week: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    max_marks: Mapped[int] = mapped_column(Integer, default=100, nullable=False)
    pass_marks: Mapped[int] = mapped_column(Integer, default=35, nullable=False)
    is_mandatory: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)


class StaffSubject(Base, SchoolScopedMixin):
    __tablename__ = "staff_subjects"
    __table_args__ = (
        UniqueConstraint(
            "school_id",
            "academic_year_id",
            "grade_id",
            "section_id",
            "subject_id",
            "staff_id",
            name="uq_staff_subject_year_scope",
        ),
    )

    academic_year_id: Mapped[str] = mapped_column(String(36), ForeignKey("academic_years.id"), nullable=False, index=True)
    grade_id: Mapped[str] = mapped_column(String(36), ForeignKey("grades.id"), nullable=False, index=True)
    section_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("sections.id"), nullable=True, index=True)
    subject_id: Mapped[str] = mapped_column(String(36), ForeignKey("subjects.id"), nullable=False, index=True)
    staff_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("staff.id"), nullable=True, index=True)
    is_primary: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)


class Room(Base, SchoolScopedMixin):
    __tablename__ = "rooms"
    __table_args__ = (UniqueConstraint("school_id", "room_number", name="uq_rooms_school_number"),)

    room_number: Mapped[str] = mapped_column(String(80), nullable=False)
    room_type: Mapped[str] = mapped_column(String(60), default="classroom", nullable=False)
    capacity: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    block: Mapped[str] = mapped_column(String(80), default="", nullable=False)
    floor: Mapped[int] = mapped_column(Integer, default=0, nullable=False)


class Staff(Base, SchoolScopedMixin):
    __tablename__ = "staff"
    __table_args__ = (UniqueConstraint("school_id", "staff_code", name="uq_staff_school_code"),)

    staff_code: Mapped[str] = mapped_column(String(80), nullable=False)
    first_name: Mapped[str] = mapped_column(String(120), nullable=False)
    last_name: Mapped[str] = mapped_column(String(120), default="", nullable=False)
    email: Mapped[str] = mapped_column(String(160), default="", nullable=False)
    phone: Mapped[str] = mapped_column(String(40), default="", nullable=False)
    designation: Mapped[str] = mapped_column(String(120), default="", nullable=False)
    employment_type: Mapped[str] = mapped_column(String(60), default="full_time", nullable=False)
    department_id: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)
    department_name: Mapped[str] = mapped_column(String(120), default="", nullable=False)
    status: Mapped[str] = mapped_column(String(40), default="active", nullable=False)
    date_of_birth: Mapped[date | None] = mapped_column(Date, nullable=True)
    gender: Mapped[str] = mapped_column(String(40), default="unspecified", nullable=False)
    join_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    photo_url: Mapped[str] = mapped_column(String(500), default="", nullable=False)


class Student(Base, SchoolScopedMixin):
    __tablename__ = "students"
    __table_args__ = (
        UniqueConstraint("school_id", "student_code", name="uq_students_school_code"),
        UniqueConstraint("school_id", "admission_number", name="uq_students_school_admission"),
    )

    student_code: Mapped[str] = mapped_column(String(80), nullable=False)
    admission_number: Mapped[str] = mapped_column(String(80), nullable=False)
    first_name: Mapped[str] = mapped_column(String(120), nullable=False)
    last_name: Mapped[str] = mapped_column(String(120), default="", nullable=False)
    date_of_birth: Mapped[date | None] = mapped_column(Date, nullable=True)
    admission_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    gender: Mapped[str] = mapped_column(String(40), default="unspecified", nullable=False)
    current_section_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("sections.id"), nullable=True, index=True)
    status: Mapped[str] = mapped_column(String(40), default="active", nullable=False)
    photo_url: Mapped[str] = mapped_column(String(500), default="", nullable=False)


class FeeStructure(Base, SchoolScopedMixin):
    __tablename__ = "fee_structures"

    academic_year_id: Mapped[str] = mapped_column(String(36), ForeignKey("academic_years.id"), nullable=False, index=True)
    grade_id: Mapped[str] = mapped_column(String(36), ForeignKey("grades.id"), nullable=False, index=True)
    section_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("sections.id"), nullable=True, index=True)
    category_name: Mapped[str] = mapped_column(String(120), nullable=False)
    frequency: Mapped[str] = mapped_column(String(40), default="term", nullable=False)
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=Decimal("0"), nullable=False)
    due_day: Mapped[int] = mapped_column(Integer, default=10, nullable=False)
    late_fine_per_day: Mapped[Decimal] = mapped_column(Numeric(10, 2), default=Decimal("0"), nullable=False)
    status: Mapped[str] = mapped_column(String(40), default="active", nullable=False)


class LeaveType(Base, SchoolScopedMixin):
    __tablename__ = "leave_types"
    __table_args__ = (UniqueConstraint("school_id", "leave_name", name="uq_leave_types_school_name"),)

    leave_name: Mapped[str] = mapped_column(String(120), nullable=False)
    description: Mapped[str] = mapped_column(Text, default="", nullable=False)
    max_days_per_year: Mapped[Decimal] = mapped_column(Numeric(6, 2), default=Decimal("0"), nullable=False)
    applicable_to: Mapped[str] = mapped_column(String(40), default="staff", nullable=False)


class LeaveBalance(Base, SchoolScopedMixin):
    __tablename__ = "leave_balances"
    __table_args__ = (UniqueConstraint("school_id", "staff_id", "leave_type_id", "academic_year_id", name="uq_leave_balance_staff_type_year"),)

    staff_id: Mapped[str] = mapped_column(String(36), ForeignKey("staff.id"), nullable=False, index=True)
    leave_type_id: Mapped[str] = mapped_column(String(36), ForeignKey("leave_types.id"), nullable=False, index=True)
    academic_year_id: Mapped[str] = mapped_column(String(36), ForeignKey("academic_years.id"), nullable=False, index=True)
    total_entitled: Mapped[Decimal] = mapped_column(Numeric(6, 2), default=Decimal("0"), nullable=False)
    used_days: Mapped[Decimal] = mapped_column(Numeric(6, 2), default=Decimal("0"), nullable=False)
    remaining_days: Mapped[Decimal] = mapped_column(Numeric(6, 2), default=Decimal("0"), nullable=False)


class LeaveApplication(Base, SchoolScopedMixin):
    __tablename__ = "leave_applications"

    staff_id: Mapped[str] = mapped_column(String(36), ForeignKey("staff.id"), nullable=False, index=True)
    leave_type_id: Mapped[str] = mapped_column(String(36), ForeignKey("leave_types.id"), nullable=False, index=True)
    from_date: Mapped[date] = mapped_column(Date, nullable=False)
    to_date: Mapped[date] = mapped_column(Date, nullable=False)
    half_day: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    total_days: Mapped[Decimal] = mapped_column(Numeric(6, 2), default=Decimal("1"), nullable=False)
    reason: Mapped[str] = mapped_column(Text, default="", nullable=False)
    status: Mapped[str] = mapped_column(String(40), default="pending", nullable=False, index=True)
    rejection_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    applied_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    actioned_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    actioned_by: Mapped[str | None] = mapped_column(String(36), ForeignKey("users.id"), nullable=True)


class StudentLeaveApplication(Base, SchoolScopedMixin):
    __tablename__ = "student_leave_applications"

    student_id: Mapped[str] = mapped_column(String(36), ForeignKey("students.id"), nullable=False, index=True)
    parent_user_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("users.id"), nullable=True, index=True)
    leave_type: Mapped[str] = mapped_column(String(120), nullable=False)
    from_date: Mapped[date] = mapped_column(Date, nullable=False)
    to_date: Mapped[date] = mapped_column(Date, nullable=False)
    half_day: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    total_days: Mapped[Decimal] = mapped_column(Numeric(6, 2), default=Decimal("1"), nullable=False)
    reason: Mapped[str] = mapped_column(Text, default="", nullable=False)
    status: Mapped[str] = mapped_column(String(40), default="pending", nullable=False, index=True)
    rejection_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    applied_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    actioned_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    actioned_by: Mapped[str | None] = mapped_column(String(36), ForeignKey("users.id"), nullable=True)
