from __future__ import annotations

from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, UUIDPrimaryKeyMixin, now_utc


class School(Base, UUIDPrimaryKeyMixin):
    __tablename__ = "schools"

    name: Mapped[str] = mapped_column(String(160), nullable=False)
    school_type: Mapped[str | None] = mapped_column(String(80), nullable=True)
    affiliation_board: Mapped[str | None] = mapped_column(String(120), nullable=True)
    email: Mapped[str | None] = mapped_column(String(160), nullable=True)
    phone: Mapped[str | None] = mapped_column(String(40), nullable=True)
    city: Mapped[str | None] = mapped_column(String(120), nullable=True)
    state: Mapped[str | None] = mapped_column(String(120), nullable=True)
    principal_name: Mapped[str | None] = mapped_column(String(160), nullable=True)
    registration_number: Mapped[str | None] = mapped_column(String(120), nullable=True)
    logo_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc, nullable=False)
    updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class User(Base, UUIDPrimaryKeyMixin):
    __tablename__ = "users"

    school_id: Mapped[str] = mapped_column(String(36), ForeignKey("schools.id"), nullable=False, index=True)
    username: Mapped[str] = mapped_column(String(80), nullable=False, unique=True, index=True)
    full_name: Mapped[str] = mapped_column(String(160), nullable=False)
    role: Mapped[str] = mapped_column(String(40), nullable=False, index=True)
    linked_type: Mapped[str | None] = mapped_column(String(40), nullable=True)
    linked_id: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(180), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc, nullable=False)

    school: Mapped[School] = relationship()


class Role(Base, UUIDPrimaryKeyMixin):
    __tablename__ = "roles"
    __table_args__ = (UniqueConstraint("school_id", "name", name="uq_roles_school_name"),)

    school_id: Mapped[str] = mapped_column(String(36), ForeignKey("schools.id"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(60), nullable=False)


class Permission(Base, UUIDPrimaryKeyMixin):
    __tablename__ = "permissions"

    code: Mapped[str] = mapped_column(String(80), nullable=False, unique=True)
    description: Mapped[str] = mapped_column(String(240), nullable=False)


class RolePermission(Base, UUIDPrimaryKeyMixin):
    __tablename__ = "role_permissions"
    __table_args__ = (UniqueConstraint("role_id", "permission_id", name="uq_role_permissions_role_permission"),)

    role_id: Mapped[str] = mapped_column(String(36), ForeignKey("roles.id"), nullable=False)
    permission_id: Mapped[str] = mapped_column(String(36), ForeignKey("permissions.id"), nullable=False)


class UserRole(Base, UUIDPrimaryKeyMixin):
    __tablename__ = "user_roles"
    __table_args__ = (UniqueConstraint("user_id", "role_id", name="uq_user_roles_user_role"),)

    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False)
    role_id: Mapped[str] = mapped_column(String(36), ForeignKey("roles.id"), nullable=False)


class Section(Base, UUIDPrimaryKeyMixin):
    __tablename__ = "sections"

    school_id: Mapped[str] = mapped_column(String(36), ForeignKey("schools.id"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(80), nullable=False)
    grade_id: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)
    academic_year_id: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)
    class_teacher_id: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)
    room_id: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)
    capacity: Mapped[int | None] = mapped_column(Integer, nullable=True)
