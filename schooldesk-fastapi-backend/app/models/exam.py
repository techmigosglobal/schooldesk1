from __future__ import annotations
from datetime import date, datetime
from decimal import Decimal
from sqlalchemy import Date, DateTime, ForeignKey, Integer, Numeric, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from app.models.base import Base, SchoolScopedMixin

class Exam(Base, SchoolScopedMixin):
    __tablename__ = "exams"
    __table_args__ = (UniqueConstraint("school_id", "academic_year_id", "exam_name", "exam_date", name="uq_exam_school_year_name_date"),)
    
    academic_year_id: Mapped[str] = mapped_column(String(36), ForeignKey("academic_years.id"), nullable=False, index=True)
    term_id: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)
    exam_name: Mapped[str] = mapped_column(String(180), nullable=False)
    exam_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    description: Mapped[str] = mapped_column(Text, default="", nullable=False)
    weight: Mapped[Decimal] = mapped_column(Numeric(4, 2), default=Decimal("1.0"), nullable=False)
    is_practical: Mapped[bool] = mapped_column(default=False, nullable=False)
    status: Mapped[str] = mapped_column(String(40), default="scheduled", nullable=False)

class ExamMark(Base, SchoolScopedMixin):
    __tablename__ = "exam_marks"
    __table_args__ = (UniqueConstraint("exam_id", "student_id", "grade_subject_id", name="uq_exam_mark_unique"),)
    
    exam_id: Mapped[str] = mapped_column(String(36), ForeignKey("exams.id"), nullable=False, index=True)
    student_id: Mapped[str] = mapped_column(String(36), ForeignKey("students.id"), nullable=False, index=True)
    grade_subject_id: Mapped[str] = mapped_column(String(36), ForeignKey("grade_subjects.id"), nullable=False, index=True)
    marks_obtained: Mapped[Decimal] = mapped_column(Numeric(8, 2), nullable=False)
    created_by: Mapped[str | None] = mapped_column(String(36), nullable=True)
    updated_by: Mapped[str | None] = mapped_column(String(36), nullable=True)