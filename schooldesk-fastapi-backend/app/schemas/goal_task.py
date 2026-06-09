from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal
from enum import StrEnum

from pydantic import BaseModel, ConfigDict, Field, field_validator


class GoalStatus(StrEnum):
    draft = "draft"
    active = "active"
    completed = "completed"
    archived = "archived"


class TaskStatus(StrEnum):
    todo = "todo"
    in_progress = "in_progress"
    blocked = "blocked"
    submitted = "submitted"
    completed = "completed"
    reopened = "reopened"
    archived = "archived"


class Priority(StrEnum):
    low = "low"
    normal = "normal"
    high = "high"
    urgent = "urgent"


class ScopeType(StrEnum):
    school = "school"
    grade = "grade"
    section = "section"
    staff = "staff"


class GoalKeyResultCreate(BaseModel):
    title: str = Field(min_length=1, max_length=180)
    target_value: Decimal | None = None
    current_value: Decimal | None = None
    unit: str | None = Field(default=None, max_length=40)


class GoalKeyResultRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    goal_id: str
    title: str
    target_value: Decimal | None = None
    current_value: Decimal | None = None
    unit: str | None = None
    status: str
    created_at: datetime


class GoalCreate(BaseModel):
    title: str = Field(min_length=1, max_length=180)
    description: str = ""
    priority: Priority = Priority.normal
    starts_on: date | None = None
    due_on: date | None = None
    key_results: list[GoalKeyResultCreate] = Field(default_factory=list)


class GoalUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=180)
    description: str | None = None
    status: GoalStatus | None = None
    priority: Priority | None = None
    starts_on: date | None = None
    due_on: date | None = None


class GoalRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    school_id: str
    title: str
    description: str
    status: str
    priority: str
    owner_user_id: str
    starts_on: date | None = None
    due_on: date | None = None
    completed_at: datetime | None = None
    archived_at: datetime | None = None
    created_at: datetime
    updated_at: datetime
    key_results: list[GoalKeyResultRead] = Field(default_factory=list)


class ChecklistItemCreate(BaseModel):
    title: str = Field(min_length=1, max_length=180)
    sort_order: int = Field(default=0, ge=0)


class TaskCreate(BaseModel):
    title: str = Field(min_length=1, max_length=180)
    description: str = ""
    priority: Priority = Priority.normal
    scope_type: ScopeType = ScopeType.school
    scope_id: str | None = Field(default=None, max_length=36)
    assigned_role: str | None = Field(default=None, max_length=40)
    assigned_user_id: str | None = Field(default=None, max_length=36)
    assigned_staff_id: str | None = Field(default=None, max_length=36)
    assigned_section_id: str | None = Field(default=None, max_length=36)
    due_at: datetime | None = None
    checklist_items: list[ChecklistItemCreate] = Field(default_factory=list)

    @field_validator("assigned_role")
    @classmethod
    def normalize_role(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip().lower()
        if value not in {"principal", "admin", "teacher", "parent", "guardian"}:
            raise ValueError("assigned_role must be principal, admin, teacher, parent, or guardian")
        return "parent" if value == "guardian" else value


class TaskUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=180)
    description: str | None = None
    priority: Priority | None = None
    scope_type: ScopeType | None = None
    scope_id: str | None = Field(default=None, max_length=36)
    assigned_role: str | None = Field(default=None, max_length=40)
    assigned_user_id: str | None = Field(default=None, max_length=36)
    assigned_staff_id: str | None = Field(default=None, max_length=36)
    assigned_section_id: str | None = Field(default=None, max_length=36)
    due_at: datetime | None = None


class TaskProgressUpdate(BaseModel):
    status: TaskStatus | None = None
    progress_percent: int | None = Field(default=None, ge=0, le=100)
    evidence_url: str | None = Field(default=None, max_length=500)
    blocker_note: str | None = None


class TaskCommentCreate(BaseModel):
    body: str = Field(min_length=1)
    evidence_url: str | None = Field(default=None, max_length=500)


class ChecklistItemUpdate(BaseModel):
    completed: bool


class ChecklistItemRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    task_id: str
    title: str
    sort_order: int
    completed_at: datetime | None = None
    completed_by: str | None = None


class TaskCommentRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    task_id: str
    author_user_id: str
    body: str
    evidence_url: str | None = None
    created_at: datetime


class TaskRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    school_id: str
    goal_id: str | None = None
    title: str
    description: str
    status: str
    priority: str
    scope_type: str
    scope_id: str | None = None
    assigned_role: str | None = None
    assigned_user_id: str | None = None
    assigned_staff_id: str | None = None
    assigned_section_id: str | None = None
    due_at: datetime | None = None
    progress_percent: int
    evidence_url: str | None = None
    blocker_note: str | None = None
    completed_at: datetime | None = None
    reopened_at: datetime | None = None
    archived_at: datetime | None = None
    created_at: datetime
    updated_at: datetime
    checklist_items: list[ChecklistItemRead] = Field(default_factory=list)
    comments: list[TaskCommentRead] = Field(default_factory=list)
