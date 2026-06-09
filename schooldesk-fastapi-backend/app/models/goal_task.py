from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import Date, DateTime, ForeignKey, Integer, Numeric, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, SchoolScopedMixin


class Goal(Base, SchoolScopedMixin):
    __tablename__ = "goals"

    title: Mapped[str] = mapped_column(String(180), nullable=False)
    description: Mapped[str] = mapped_column(Text, default="", nullable=False)
    status: Mapped[str] = mapped_column(String(30), default="draft", nullable=False, index=True)
    priority: Mapped[str] = mapped_column(String(20), default="normal", nullable=False)
    owner_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    starts_on: Mapped[date | None] = mapped_column(Date, nullable=True)
    due_on: Mapped[date | None] = mapped_column(Date, nullable=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    archived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    key_results: Mapped[list["GoalKeyResult"]] = relationship(
        back_populates="goal",
        cascade="all, delete-orphan",
        order_by="GoalKeyResult.created_at",
    )
    tasks: Mapped[list["Task"]] = relationship(back_populates="goal")


class GoalKeyResult(Base, SchoolScopedMixin):
    __tablename__ = "goal_key_results"

    goal_id: Mapped[str] = mapped_column(String(36), ForeignKey("goals.id"), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(180), nullable=False)
    target_value: Mapped[Decimal | None] = mapped_column(Numeric(12, 2), nullable=True)
    current_value: Mapped[Decimal | None] = mapped_column(Numeric(12, 2), nullable=True)
    unit: Mapped[str | None] = mapped_column(String(40), nullable=True)
    status: Mapped[str] = mapped_column(String(30), default="draft", nullable=False)

    goal: Mapped[Goal] = relationship(back_populates="key_results")


class Task(Base, SchoolScopedMixin):
    __tablename__ = "tasks"

    goal_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("goals.id"), nullable=True, index=True)
    title: Mapped[str] = mapped_column(String(180), nullable=False)
    description: Mapped[str] = mapped_column(Text, default="", nullable=False)
    status: Mapped[str] = mapped_column(String(30), default="todo", nullable=False, index=True)
    priority: Mapped[str] = mapped_column(String(20), default="normal", nullable=False)
    scope_type: Mapped[str] = mapped_column(String(20), default="school", nullable=False, index=True)
    scope_id: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)
    assigned_role: Mapped[str | None] = mapped_column(String(40), nullable=True, index=True)
    assigned_user_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("users.id"), nullable=True, index=True)
    assigned_staff_id: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)
    assigned_section_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("sections.id"), nullable=True, index=True)
    due_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    progress_percent: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    evidence_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    blocker_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    reopened_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    archived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    goal: Mapped[Goal | None] = relationship(back_populates="tasks")
    checklist_items: Mapped[list["TaskChecklistItem"]] = relationship(
        back_populates="task",
        cascade="all, delete-orphan",
        order_by="TaskChecklistItem.sort_order",
    )
    comments: Mapped[list["TaskComment"]] = relationship(
        back_populates="task",
        cascade="all, delete-orphan",
        order_by="TaskComment.created_at",
    )


class TaskChecklistItem(Base, SchoolScopedMixin):
    __tablename__ = "task_checklist_items"

    task_id: Mapped[str] = mapped_column(String(36), ForeignKey("tasks.id"), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(180), nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    completed_by: Mapped[str | None] = mapped_column(String(36), ForeignKey("users.id"), nullable=True)

    task: Mapped[Task] = relationship(back_populates="checklist_items")


class TaskComment(Base, SchoolScopedMixin):
    __tablename__ = "task_comments"

    task_id: Mapped[str] = mapped_column(String(36), ForeignKey("tasks.id"), nullable=False, index=True)
    author_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    evidence_url: Mapped[str | None] = mapped_column(String(500), nullable=True)

    task: Mapped[Task] = relationship(back_populates="comments")


class AuditLog(Base, SchoolScopedMixin):
    __tablename__ = "audit_logs"

    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    action: Mapped[str] = mapped_column(String(60), nullable=False)
    module: Mapped[str] = mapped_column(String(80), nullable=False, index=True)
    entity_type: Mapped[str] = mapped_column(String(80), nullable=False)
    entity_id: Mapped[str] = mapped_column(String(36), nullable=False, index=True)
    old_value: Mapped[str] = mapped_column(Text, default="", nullable=False)
    new_value: Mapped[str] = mapped_column(Text, default="", nullable=False)


class NotificationLog(Base, SchoolScopedMixin):
    __tablename__ = "notification_logs"

    recipient_user_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("users.id"), nullable=True, index=True)
    recipient_role: Mapped[str | None] = mapped_column(String(40), nullable=True, index=True)
    reference_type: Mapped[str] = mapped_column(String(60), nullable=False, index=True)
    reference_id: Mapped[str] = mapped_column(String(36), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(180), nullable=False)
    body: Mapped[str] = mapped_column(Text, default="", nullable=False)
    status: Mapped[str] = mapped_column(String(30), default="queued", nullable=False)
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class ApprovalRequest(Base, SchoolScopedMixin):
    __tablename__ = "approval_requests"

    requester_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False)
    module: Mapped[str] = mapped_column(String(80), nullable=False, index=True)
    action: Mapped[str] = mapped_column(String(80), nullable=False)
    status: Mapped[str] = mapped_column(String(30), default="pending", nullable=False)
    payload: Mapped[str] = mapped_column(Text, default="", nullable=False)

