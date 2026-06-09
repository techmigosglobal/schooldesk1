from __future__ import annotations

from typing import Iterable

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import and_, false, or_, select
from sqlalchemy.orm import Session, selectinload

from app.core.cache import get_cache
from app.core.database import get_db
from app.core.logging_config import get_logger
from app.core.security import utcnow
from app.dependencies.auth import CurrentUser, can_access_task, require_internal_user, require_permission
from app.models.auth import Section, User
from app.models.goal_task import AuditLog, Goal, GoalKeyResult, NotificationLog, Task, TaskChecklistItem, TaskComment
from app.schemas.goal_task import (
    ChecklistItemUpdate,
    GoalCreate,
    GoalRead,
    GoalStatus,
    GoalUpdate,
    TaskCommentCreate,
    TaskCreate,
    TaskProgressUpdate,
    TaskRead,
    TaskStatus,
    TaskUpdate,
)

logger = get_logger(__name__)

router = APIRouter(tags=["goals-and-tasks"])
goals_router = APIRouter(prefix="/api/v1/goals", tags=["goals"])
tasks_router = APIRouter(prefix="/api/v1/tasks", tags=["tasks"])


def record_audit(
    db: Session,
    current_user: CurrentUser,
    *,
    action: str,
    module: str,
    entity_type: str,
    entity_id: str,
    old_value: str = "",
    new_value: str = "",
) -> None:
    db.add(
        AuditLog(
            school_id=current_user.school_id,
            user_id=current_user.id,
            action=action,
            module=module,
            entity_type=entity_type,
            entity_id=entity_id,
            old_value=old_value,
            new_value=new_value,
            created_by=current_user.id,
            updated_by=current_user.id,
        )
    )


def visible_task_filter(current_user: CurrentUser):
    base = [Task.school_id == current_user.school_id, Task.deleted_at.is_(None)]
    if current_user.is_principal:
        return and_(*base)
    if current_user.role in {"parent", "guardian"}:
        return and_(*base, false())

    conditions = [Task.assigned_user_id == current_user.id, Task.assigned_role == current_user.role]
    if current_user.linked_id:
        conditions.extend(
            [
                Task.assigned_staff_id == current_user.linked_id,
                and_(Task.scope_type == "staff", Task.scope_id == current_user.linked_id),
            ]
        )
    if current_user.class_teacher_sections:
        conditions.extend(
            [
                Task.assigned_section_id.in_(current_user.class_teacher_sections),
                and_(Task.scope_type == "section", Task.scope_id.in_(current_user.class_teacher_sections)),
            ]
        )
    return and_(*base, or_(*conditions))


def load_visible_task(db: Session, current_user: CurrentUser, task_id: str) -> Task:
    task = db.scalar(
        select(Task)
        .options(selectinload(Task.checklist_items), selectinload(Task.comments))
        .where(Task.id == task_id, visible_task_filter(current_user))
    )
    if task is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Task not found")
    return task


def load_principal_goal(db: Session, current_user: CurrentUser, goal_id: str) -> Goal:
    goal = db.scalar(
        select(Goal)
        .options(selectinload(Goal.key_results))
        .where(Goal.id == goal_id, Goal.school_id == current_user.school_id, Goal.deleted_at.is_(None))
    )
    if goal is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Goal not found")
    return goal


def notify_task_assignment(db: Session, current_user: CurrentUser, task: Task) -> None:
    recipients: set[tuple[str | None, str | None]] = set()
    if task.assigned_user_id:
        recipients.add((task.assigned_user_id, None))
    if task.assigned_role:
        recipients.add((None, task.assigned_role))
    if task.assigned_staff_id:
        user_ids = db.scalars(
            select(User.id).where(
                User.school_id == current_user.school_id,
                User.linked_id == task.assigned_staff_id,
                User.is_active.is_(True),
            )
        ).all()
        recipients.update((user_id, None) for user_id in user_ids)
    if task.assigned_section_id:
        section = db.get(Section, task.assigned_section_id)
        if section and section.class_teacher_id:
            user_ids = db.scalars(
                select(User.id).where(
                    User.school_id == current_user.school_id,
                    User.linked_id == section.class_teacher_id,
                    User.is_active.is_(True),
                )
            ).all()
            recipients.update((user_id, None) for user_id in user_ids)

    for recipient_user_id, recipient_role in recipients:
        db.add(
            NotificationLog(
                school_id=current_user.school_id,
                recipient_user_id=recipient_user_id,
                recipient_role=recipient_role,
                reference_type="task",
                reference_id=task.id,
                title="New task assigned",
                body=task.title,
                created_by=current_user.id,
                updated_by=current_user.id,
            )
        )


def create_task_row(
    db: Session,
    current_user: CurrentUser,
    payload: TaskCreate,
    *,
    goal_id: str | None = None,
) -> Task:
    task = Task(
        school_id=current_user.school_id,
        goal_id=goal_id,
        title=payload.title,
        description=payload.description,
        priority=payload.priority.value,
        scope_type=payload.scope_type.value,
        scope_id=payload.scope_id,
        assigned_role=payload.assigned_role,
        assigned_user_id=payload.assigned_user_id,
        assigned_staff_id=payload.assigned_staff_id,
        assigned_section_id=payload.assigned_section_id,
        due_at=payload.due_at,
        created_by=current_user.id,
        updated_by=current_user.id,
    )
    for index, item in enumerate(payload.checklist_items):
        task.checklist_items.append(
            TaskChecklistItem(
                school_id=current_user.school_id,
                title=item.title,
                sort_order=item.sort_order or index,
                created_by=current_user.id,
                updated_by=current_user.id,
            )
        )
    db.add(task)
    db.flush()
    notify_task_assignment(db, current_user, task)
    record_audit(
        db,
        current_user,
        action="create",
        module="tasks",
        entity_type="tasks",
        entity_id=task.id,
        new_value=task.title,
    )
    db.commit()
    db.refresh(task)
    return load_visible_task(db, current_user, task.id)


@goals_router.post("", response_model=GoalRead, status_code=status.HTTP_201_CREATED)
def create_goal(
    request: Request,
    payload: GoalCreate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("goals.manage")),
) -> Goal:
    goal = Goal(
        school_id=current_user.school_id,
        title=payload.title,
        description=payload.description,
        priority=payload.priority.value,
        owner_user_id=current_user.id,
        starts_on=payload.starts_on,
        due_on=payload.due_on,
        created_by=current_user.id,
        updated_by=current_user.id,
    )
    for key_result in payload.key_results:
        goal.key_results.append(
            GoalKeyResult(
                school_id=current_user.school_id,
                title=key_result.title,
                target_value=key_result.target_value,
                current_value=key_result.current_value,
                unit=key_result.unit,
                created_by=current_user.id,
                updated_by=current_user.id,
            )
        )
    db.add(goal)
    db.flush()
    record_audit(
        db,
        current_user,
        action="create",
        module="goals",
        entity_type="goals",
        entity_id=goal.id,
        new_value=goal.title,
    )
    db.commit()
    logger.info("goal_created", goal_id=goal.id, school_id=current_user.school_id)
    # Invalidate cache
    get_cache().delete_pattern(f"goals:{current_user.school_id}:*")
    return load_principal_goal(db, current_user, goal.id)


@goals_router.get("", response_model=list[GoalRead])
def list_goals(
    request: Request,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_internal_user),
) -> Iterable[Goal]:
    if "goals.read" not in current_user.permissions:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permission denied")
    cache = get_cache()
    cache_key = f"goals:list:{current_user.school_id}:{current_user.id}:{current_user.is_principal}"
    cached = cache.get(cache_key)
    if cached:
        return [Goal(**g) for g in cached]
    stmt = (
        select(Goal)
        .options(selectinload(Goal.key_results))
        .where(Goal.school_id == current_user.school_id, Goal.deleted_at.is_(None))
        .order_by(Goal.created_at.desc())
    )
    if not current_user.is_principal:
        visible_goal_ids = select(Task.goal_id).where(
            visible_task_filter(current_user),
            Task.goal_id.is_not(None),
        )
        stmt = stmt.where(Goal.id.in_(visible_goal_ids))
    goals = db.scalars(stmt).all()
    cache.set(cache_key, [g.to_dict() if hasattr(g, 'to_dict') else {"id": g.id} for g in goals], ttl=120)
    return goals


@goals_router.get("/{goal_id}", response_model=GoalRead)
def get_goal(
    goal_id: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_internal_user),
) -> Goal:
    if "goals.read" not in current_user.permissions:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permission denied")
    goal = load_principal_goal(db, current_user, goal_id)
    if current_user.is_principal:
        return goal
    visible = db.scalar(select(Task.id).where(visible_task_filter(current_user), Task.goal_id == goal.id))
    if visible is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Goal not found")
    return goal


@goals_router.patch("/{goal_id}", response_model=GoalRead)
def update_goal(
    request: Request,
    goal_id: str,
    payload: GoalUpdate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("goals.manage")),
) -> Goal:
    goal = load_principal_goal(db, current_user, goal_id)
    for field, value in payload.model_dump(exclude_unset=True).items():
        if isinstance(value, GoalStatus):
            value = value.value
        setattr(goal, field, value)
    if goal.status == "completed" and goal.completed_at is None:
        goal.completed_at = utcnow()
    goal.updated_by = current_user.id
    record_audit(db, current_user, action="update", module="goals", entity_type="goals", entity_id=goal.id)
    db.commit()
    logger.info("goal_updated", goal_id=goal.id)
    get_cache().delete_pattern(f"goals:{current_user.school_id}:*")
    return load_principal_goal(db, current_user, goal.id)


@goals_router.post("/{goal_id}/activate", response_model=GoalRead)
def activate_goal(
    request: Request,
    goal_id: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("goals.manage")),
) -> Goal:
    goal = load_principal_goal(db, current_user, goal_id)
    goal.status = "active"
    goal.updated_by = current_user.id
    record_audit(db, current_user, action="activate", module="goals", entity_type="goals", entity_id=goal.id)
    db.commit()
    logger.info("goal_activated", goal_id=goal.id)
    get_cache().delete_pattern(f"goals:{current_user.school_id}:*")
    return load_principal_goal(db, current_user, goal.id)


@goals_router.post("/{goal_id}/archive", response_model=GoalRead)
def archive_goal(
    request: Request,
    goal_id: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("goals.manage")),
) -> Goal:
    goal = load_principal_goal(db, current_user, goal_id)
    now = utcnow()
    goal.status = "archived"
    goal.archived_at = now
    goal.deleted_at = now
    goal.is_active = False
    goal.updated_by = current_user.id
    record_audit(db, current_user, action="archive", module="goals", entity_type="goals", entity_id=goal.id)
    db.commit()
    logger.info("goal_archived", goal_id=goal.id)
    get_cache().delete_pattern(f"goals:{current_user.school_id}:*")
    db.refresh(goal)
    return goal


@goals_router.post("/{goal_id}/tasks", response_model=TaskRead, status_code=status.HTTP_201_CREATED)
def create_goal_task(
    request: Request,
    goal_id: str,
    payload: TaskCreate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("tasks.manage")),
) -> Task:
    load_principal_goal(db, current_user, goal_id)
    task = create_task_row(db, current_user, payload, goal_id=goal_id)
    logger.info("task_created", task_id=task.id, goal_id=goal_id)
    get_cache().delete_pattern(f"tasks:{current_user.school_id}:*")
    return task


@tasks_router.post("", response_model=TaskRead, status_code=status.HTTP_201_CREATED)
def create_standalone_task(
    request: Request,
    payload: TaskCreate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("tasks.manage")),
) -> Task:
    task = create_task_row(db, current_user, payload)
    logger.info("task_created", task_id=task.id)
    get_cache().delete_pattern(f"tasks:{current_user.school_id}:*")
    return task


@tasks_router.get("", response_model=list[TaskRead])
def list_tasks(
    request: Request,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_internal_user),
) -> Iterable[Task]:
    if "tasks.read" not in current_user.permissions:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permission denied")
    cache = get_cache()
    cache_key = f"tasks:list:{current_user.school_id}:{current_user.id}"
    cached = cache.get(cache_key)
    if cached:
        return [Task(**t) for t in cached]
    tasks = db.scalars(
        select(Task)
        .options(selectinload(Task.checklist_items), selectinload(Task.comments))
        .where(visible_task_filter(current_user))
        .order_by(Task.created_at.desc())
    ).all()
    return tasks


@tasks_router.get("/my", response_model=list[TaskRead])
def list_my_tasks(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_internal_user),
) -> Iterable[Task]:
    if "tasks.read" not in current_user.permissions:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permission denied")
    return db.scalars(
        select(Task)
        .options(selectinload(Task.checklist_items), selectinload(Task.comments))
        .where(visible_task_filter(current_user))
        .order_by(Task.due_at.asc().nulls_last(), Task.created_at.desc())
    ).all()


@tasks_router.get("/{task_id}", response_model=TaskRead)
def get_task(
    task_id: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_internal_user),
) -> Task:
    if "tasks.read" not in current_user.permissions:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permission denied")
    return load_visible_task(db, current_user, task_id)


@tasks_router.patch("/{task_id}", response_model=TaskRead)
def update_task(
    request: Request,
    task_id: str,
    payload: TaskUpdate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("tasks.manage")),
) -> Task:
    task = load_visible_task(db, current_user, task_id)
    for field, value in payload.model_dump(exclude_unset=True).items():
        if hasattr(value, "value"):
            value = value.value
        setattr(task, field, value)
    task.updated_by = current_user.id
    record_audit(db, current_user, action="update", module="tasks", entity_type="tasks", entity_id=task.id)
    db.commit()
    logger.info("task_updated", task_id=task.id)
    get_cache().delete_pattern(f"tasks:{current_user.school_id}:*")
    return load_visible_task(db, current_user, task.id)


@tasks_router.patch("/{task_id}/progress", response_model=TaskRead)
def update_task_progress(
    request: Request,
    task_id: str,
    payload: TaskProgressUpdate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_internal_user),
) -> Task:
    if "tasks.update_own" not in current_user.permissions and "tasks.manage" not in current_user.permissions:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permission denied")
    task = load_visible_task(db, current_user, task_id)
    if payload.status is not None:
        allowed = {TaskStatus.todo, TaskStatus.in_progress, TaskStatus.blocked, TaskStatus.submitted}
        if payload.status not in allowed:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Use complete/reopen endpoints")
        task.status = payload.status.value
    if payload.progress_percent is not None:
        task.progress_percent = payload.progress_percent
    if payload.evidence_url is not None:
        task.evidence_url = payload.evidence_url
    if payload.blocker_note is not None:
        task.blocker_note = payload.blocker_note
        if task.blocker_note and task.status != "submitted":
            task.status = "blocked"
    task.updated_by = current_user.id
    record_audit(db, current_user, action="progress", module="tasks", entity_type="tasks", entity_id=task.id)
    db.commit()
    logger.info("task_progress_updated", task_id=task.id)
    get_cache().delete_pattern(f"tasks:{current_user.school_id}:*")
    return load_visible_task(db, current_user, task.id)


@tasks_router.post("/{task_id}/comments", response_model=TaskRead, status_code=status.HTTP_201_CREATED)
def add_task_comment(
    request: Request,
    task_id: str,
    payload: TaskCommentCreate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_internal_user),
) -> Task:
    if "tasks.update_own" not in current_user.permissions and "tasks.manage" not in current_user.permissions:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permission denied")
    task = load_visible_task(db, current_user, task_id)
    db.add(
        TaskComment(
            school_id=current_user.school_id,
            task_id=task.id,
            author_user_id=current_user.id,
            body=payload.body,
            evidence_url=payload.evidence_url,
            created_by=current_user.id,
            updated_by=current_user.id,
        )
    )
    record_audit(db, current_user, action="comment", module="tasks", entity_type="tasks", entity_id=task.id)
    db.commit()
    logger.info("task_comment_added", task_id=task.id)
    return load_visible_task(db, current_user, task.id)


@tasks_router.patch("/{task_id}/checklist/{item_id}", response_model=TaskRead)
def update_checklist_item(
    request: Request,
    task_id: str,
    item_id: str,
    payload: ChecklistItemUpdate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_internal_user),
) -> Task:
    if "tasks.update_own" not in current_user.permissions and "tasks.manage" not in current_user.permissions:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permission denied")
    task = load_visible_task(db, current_user, task_id)
    item = next((row for row in task.checklist_items if row.id == item_id), None)
    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Checklist item not found")
    item.completed_at = utcnow() if payload.completed else None
    item.completed_by = current_user.id if payload.completed else None
    item.updated_by = current_user.id
    record_audit(db, current_user, action="checklist", module="tasks", entity_type="tasks", entity_id=task.id)
    db.commit()
    logger.info("task_checklist_updated", task_id=task_id, item_id=item_id)
    return load_visible_task(db, current_user, task.id)


@tasks_router.post("/{task_id}/complete", response_model=TaskRead)
def complete_task(
    request: Request,
    task_id: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("tasks.manage")),
) -> Task:
    task = load_visible_task(db, current_user, task_id)
    task.status = "completed"
    task.progress_percent = 100
    task.completed_at = utcnow()
    task.updated_by = current_user.id
    record_audit(db, current_user, action="complete", module="tasks", entity_type="tasks", entity_id=task.id)
    db.commit()
    logger.info("task_completed", task_id=task.id)
    get_cache().delete_pattern(f"tasks:{current_user.school_id}:*")
    return load_visible_task(db, current_user, task.id)


@tasks_router.post("/{task_id}/reopen", response_model=TaskRead)
def reopen_task(
    request: Request,
    task_id: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("tasks.manage")),
) -> Task:
    task = load_visible_task(db, current_user, task_id)
    task.status = "reopened"
    task.completed_at = None
    task.reopened_at = utcnow()
    task.updated_by = current_user.id
    record_audit(db, current_user, action="reopen", module="tasks", entity_type="tasks", entity_id=task.id)
    db.commit()
    logger.info("task_reopened", task_id=task.id)
    get_cache().delete_pattern(f"tasks:{current_user.school_id}:*")
    return load_visible_task(db, current_user, task.id)


@tasks_router.post("/{task_id}/archive", response_model=TaskRead)
def archive_task(
    request: Request,
    task_id: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("tasks.manage")),
) -> Task:
    task = load_visible_task(db, current_user, task_id)
    now = utcnow()
    task.status = "archived"
    task.archived_at = now
    task.deleted_at = now
    task.is_active = False
    task.updated_by = current_user.id
    record_audit(db, current_user, action="archive", module="tasks", entity_type="tasks", entity_id=task.id)
    db.commit()
    logger.info("task_archived", task_id=task.id)
    get_cache().delete_pattern(f"tasks:{current_user.school_id}:*")
    db.refresh(task)
    return task


router.include_router(goals_router)
router.include_router(tasks_router)

