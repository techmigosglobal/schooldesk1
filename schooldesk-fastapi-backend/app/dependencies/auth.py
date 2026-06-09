from __future__ import annotations

from dataclasses import dataclass

import jwt
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings, get_settings
from app.core.database import get_db
from app.core.security import decode_access_token
from app.models.auth import Permission, Role, RolePermission, Section, User, UserRole
from app.models.goal_task import Task

bearer_scheme = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class CurrentUser:
    id: str
    school_id: str
    username: str
    full_name: str
    role: str
    linked_type: str | None
    linked_id: str | None
    permissions: frozenset[str]
    class_teacher_sections: tuple[str, ...]

    @property
    def is_principal(self) -> bool:
        return self.role == "principal"

    @property
    def is_staff(self) -> bool:
        return self.role in {"principal", "admin", "teacher"}


def _permissions_for_user(db: Session, user: User) -> set[str]:
    stmt = (
        select(Permission.code)
        .join(RolePermission, RolePermission.permission_id == Permission.id)
        .join(Role, Role.id == RolePermission.role_id)
        .join(UserRole, UserRole.role_id == Role.id)
        .where(UserRole.user_id == user.id)
    )
    return set(db.scalars(stmt).all())


def _class_teacher_sections(db: Session, user: User) -> tuple[str, ...]:
    if user.role.lower() != "teacher" or not user.linked_id:
        return ()
    stmt = select(Section.id).where(
        Section.school_id == user.school_id,
        Section.class_teacher_id == user.linked_id,
    )
    return tuple(db.scalars(stmt).all())


def get_current_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings),
) -> CurrentUser:
    if credentials is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentication required")
    try:
        payload = decode_access_token(settings, credentials.credentials)
    except jwt.PyJWTError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token") from exc

    user = db.get(User, payload.get("sub"))
    if user is None or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Inactive or missing user")
    current = CurrentUser(
        id=user.id,
        school_id=user.school_id,
        username=user.username,
        full_name=user.full_name,
        role=user.role.lower(),
        linked_type=user.linked_type,
        linked_id=user.linked_id,
        permissions=frozenset(_permissions_for_user(db, user)),
        class_teacher_sections=_class_teacher_sections(db, user),
    )
    request.state.current_user = current
    return current


def require_permission(permission: str):
    def dependency(current_user: CurrentUser = Depends(get_current_user)) -> CurrentUser:
        if permission not in current_user.permissions:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permission denied")
        return current_user

    return dependency


def require_internal_user(current_user: CurrentUser = Depends(get_current_user)) -> CurrentUser:
    if current_user.role in {"parent", "guardian"}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Parent/Guardian cannot access tasks")
    return current_user


def require_principal_or_admin(current_user: CurrentUser = Depends(get_current_user)) -> CurrentUser:
    if current_user.role not in {"principal", "admin"}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Principal or Admin access required")
    return current_user


def can_access_task(current_user: CurrentUser, task: Task) -> bool:
    if task.school_id != current_user.school_id or task.deleted_at is not None:
        return False
    if current_user.is_principal:
        return True
    if current_user.role in {"parent", "guardian"}:
        return False
    if task.assigned_user_id and task.assigned_user_id == current_user.id:
        return True
    if task.assigned_role and task.assigned_role.lower() == current_user.role:
        return True
    if task.assigned_staff_id and task.assigned_staff_id == current_user.linked_id:
        return True
    if task.assigned_section_id and task.assigned_section_id in current_user.class_teacher_sections:
        return True
    if task.scope_type == "staff" and task.scope_id and task.scope_id == current_user.linked_id:
        return True
    if task.scope_type == "section" and task.scope_id and task.scope_id in current_user.class_teacher_sections:
        return True
    return False
