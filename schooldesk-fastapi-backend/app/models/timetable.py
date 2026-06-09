from __future__ import annotations

from datetime import time

from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, SchoolScopedMixin


class TimetableSlot(Base, SchoolScopedMixin):
    __tablename__ = "timetable_slots"

    academic_year_id: Mapped[str] = mapped_column(String(36), ForeignKey("academic_years.id"), nullable=False, index=True)
    grade_id: Mapped[str] = mapped_column(String(36), ForeignKey("grades.id"), nullable=False, index=True)
    section_id: Mapped[str] = mapped_column(String(36), ForeignKey("sections.id"), nullable=False, index=True)
    day_of_week: Mapped[int] = mapped_column(Integer, nullable=False)  # 0=monday, 6=sunday
    period_number: Mapped[int] = mapped_column(Integer, nullable=False)
    subject_id: Mapped[str] = mapped_column(String(36), ForeignKey("subjects.id"), nullable=False, index=True)
    staff_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("staff.id"), nullable=True, index=True)
    room_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    start_time: Mapped[time] = mapped_column(nullable=False)
    end_time: Mapped[time] = mapped_column(nullable=False)