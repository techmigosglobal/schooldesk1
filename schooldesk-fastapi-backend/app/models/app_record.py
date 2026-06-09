from __future__ import annotations

from typing import Any

from sqlalchemy import JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, SchoolScopedMixin


class AppRecord(Base, SchoolScopedMixin):
    __tablename__ = "app_records"

    resource: Mapped[str] = mapped_column(String(160), nullable=False, index=True)
    parent_id: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)
    owner_role: Mapped[str] = mapped_column(String(40), default="", nullable=False, index=True)
    owner_user_id: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)
    owner_staff_id: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)
    owner_student_id: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)
    status: Mapped[str] = mapped_column(String(60), default="active", nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(240), default="", nullable=False)
    payload: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict, nullable=False)
    notes: Mapped[str] = mapped_column(Text, default="", nullable=False)
