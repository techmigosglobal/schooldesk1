from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import utcnow
from app.dependencies.auth import CurrentUser, get_current_user, require_principal_or_admin
from app.models.catalog import Student, StudentLeaveApplication
from app.models.goal_task import AuditLog
from app.models.guardian import Guardian

router = APIRouter(prefix="/api/v1/guardians", tags=["guardians"])


class GuardianCreate(BaseModel):
    student_id: str
    name: str
    phone: str = ""
    email: str = ""
    relation: str = "guardian"  # father, mother, guardian
    is_primary: bool = False


class GuardianUpdate(BaseModel):
    name: str | None = None
    phone: str | None = None
    email: str | None = None
    relation: str | None = None
    is_primary: bool | None = None


def guardian_payload(g: Guardian) -> dict[str, Any]:
    return {
        "id": g.id,
        "student_id": g.student_id,
        "name": g.name,
        "phone": g.phone,
        "email": g.email,
        "relation": g.relation,
        "is_primary": g.is_primary,
        "is_active": g.is_active,
        "created_at": g.created_at.isoformat() if g.created_at else None,
        "updated_at": g.updated_at.isoformat() if g.updated_at else None,
    }


def record_audit(
    db: Session,
    current_user: CurrentUser,
    *,
    action: str,
    entity_id: str,
    old_value: str = "",
    new_value: str = "",
) -> None:
    db.add(
        AuditLog(
            school_id=current_user.school_id,
            user_id=current_user.id,
            action=action,
            module="guardians",
            entity_type="guardian",
            entity_id=entity_id,
            old_value=old_value,
            new_value=new_value,
            created_by=current_user.id,
            updated_by=current_user.id,
        )
    )


@router.get("")
def list_guardians(
    student_id: str | None = Query(None),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal_or_admin(current_user)
    stmt = select(Guardian).where(
        Guardian.school_id == current_user.school_id,
        Guardian.deleted_at.is_(None),
    )
    if student_id:
        stmt = stmt.where(Guardian.student_id == student_id)

    # RBAC: parents/guardians see only guardians for their linked students
    if current_user.role in {"parent", "guardian"}:
        linked_student_ids = db.scalars(
            select(StudentLeaveApplication.student_id).where(
                StudentLeaveApplication.school_id == current_user.school_id,
                StudentLeaveApplication.parent_user_id == current_user.id,
                StudentLeaveApplication.deleted_at.is_(None),
            )
        ).all()
        if not linked_student_ids:
            return {"success": True, "data": [], "message": "No linked students"}
        stmt = stmt.where(Guardian.student_id.in_(linked_student_ids))
    elif student_id:
        stmt = stmt.where(Guardian.student_id == student_id)

    guardians = db.scalars(stmt.order_by(Guardian.is_primary.desc(), Guardian.created_at)).all()
    return {"success": True, "data": [guardian_payload(g) for g in guardians], "message": "Guardians retrieved"}


@router.post("")
def create_guardian(
    payload: GuardianCreate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal_or_admin(current_user)

    if payload.is_primary:
        db.scalars(
            select(Guardian).where(
                Guardian.school_id == current_user.school_id,
                Guardian.student_id == payload.student_id,
                Guardian.is_primary.is_(True),
                Guardian.deleted_at.is_(None),
            )
        ).all()
        for g in db.scalars(
            select(Guardian).where(
                Guardian.school_id == current_user.school_id,
                Guardian.student_id == payload.student_id,
                Guardian.is_primary.is_(True),
                Guardian.deleted_at.is_(None),
            )
        ):
            g.is_primary = False
            g.updated_by = current_user.id

    guardian = Guardian(
        school_id=current_user.school_id,
        student_id=payload.student_id,
        name=payload.name,
        phone=payload.phone,
        email=payload.email,
        relation=payload.relation,
        is_primary=payload.is_primary,
        created_by=current_user.id,
        updated_by=current_user.id,
    )
    db.add(guardian)
    db.flush()
    record_audit(db, current_user, action="create", entity_id=guardian.id, new_value=guardian.name)
    db.commit()
    db.refresh(guardian)
    return {"success": True, "data": guardian_payload(guardian), "message": "Guardian linked to student"}


@router.put("/{guardian_id}")
def update_guardian(
    guardian_id: str,
    payload: GuardianUpdate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal_or_admin(current_user)
    guardian = db.scalar(
        select(Guardian).where(
            Guardian.id == guardian_id,
            Guardian.school_id == current_user.school_id,
            Guardian.deleted_at.is_(None),
        )
    )
    if guardian is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Guardian not found")

    if payload.is_primary is True:
        for g in db.scalars(
            select(Guardian).where(
                Guardian.school_id == current_user.school_id,
                Guardian.student_id == guardian.student_id,
                Guardian.id != guardian_id,
                Guardian.is_primary.is_(True),
                Guardian.deleted_at.is_(None),
            )
        ):
            g.is_primary = False
            g.updated_by = current_user.id

    old_value = guardian_payload(guardian)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(guardian, field, value)
    guardian.updated_by = current_user.id
    db.flush()
    record_audit(db, current_user, action="update", entity_id=guardian.id, old_value=str(old_value), new_value=guardian_payload(guardian))
    db.commit()
    db.refresh(guardian)
    return {"success": True, "data": guardian_payload(guardian), "message": "Guardian updated"}


@router.delete("/{guardian_id}")
def delete_guardian(
    guardian_id: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal_or_admin(current_user)
    guardian = db.scalar(
        select(Guardian).where(
            Guardian.id == guardian_id,
            Guardian.school_id == current_user.school_id,
            Guardian.deleted_at.is_(None),
        )
    )
    if guardian is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Guardian not found")

    guardian.deleted_at = utcnow()
    guardian.is_active = False
    guardian.updated_by = current_user.id
    record_audit(db, current_user, action="delete", entity_id=guardian.id)
    db.commit()
    return {"success": True, "data": None, "message": "Guardian unlinked"}