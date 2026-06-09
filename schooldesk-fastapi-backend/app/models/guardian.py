from __future__ import annotations

from sqlalchemy import Boolean, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, SchoolScopedMixin


class Guardian(Base, SchoolScopedMixin):
    __tablename__ = "guardians"

    student_id: Mapped[str] = mapped_column(String(36), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    phone: Mapped[str] = mapped_column(String(40), default="", nullable=False)
    email: Mapped[str] = mapped_column(String(160), default="", nullable=False)
    relation: Mapped[str] = mapped_column(String(40), default="guardian", nullable=False)  # father, mother, guardian
    is_primary: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)