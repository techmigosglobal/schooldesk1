from __future__ import annotations

from datetime import date, datetime

from sqlalchemy import Date, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, SchoolScopedMixin


class StaffAttendance(Base, SchoolScopedMixin):
    __tablename__ = "staff_attendance"

    staff_id: Mapped[str] = mapped_column(String(36), ForeignKey("staff.id"), nullable=False, index=True)
    date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    status: Mapped[str] = mapped_column(String(40), default="present", nullable=False)
    marked_by: Mapped[str] = mapped_column(String(36), nullable=False)
    marked_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class StudentAttendance(Base, SchoolScopedMixin):
    __tablename__ = "student_attendance"

    student_id: Mapped[str] = mapped_column(String(36), ForeignKey("students.id"), nullable=False, index=True)
    section_id: Mapped[str] = mapped_column(String(36), ForeignKey("sections.id"), nullable=False, index=True)
    date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    status: Mapped[str] = mapped_column(String(40), default="present", nullable=False)
    marked_by: Mapped[str] = mapped_column(String(36), nullable=False)
    marked_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)