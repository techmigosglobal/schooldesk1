from __future__ import annotations

from decimal import Decimal

from sqlalchemy import Integer, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, SchoolScopedMixin


class VpsFee(Base, SchoolScopedMixin):
    __tablename__ = "vps_fees"

    name: Mapped[str] = mapped_column(String(180), nullable=False)
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=Decimal("0"), nullable=False)
    frequency: Mapped[str] = mapped_column(String(40), default="monthly", nullable=False)
    due_day: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    late_fine_per_day: Mapped[Decimal] = mapped_column(Numeric(10, 2), default=Decimal("0"), nullable=False)
    status: Mapped[str] = mapped_column(String(40), default="active", nullable=False)