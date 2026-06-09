from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import utcnow
from app.dependencies.auth import CurrentUser, get_current_user, require_principal_or_admin
from app.models.goal_task import AuditLog
from app.models.vps import VpsFee

router = APIRouter(prefix="/api/v1/vps/fees", tags=["vps-fees"])


class VpsFeeCreate(BaseModel):
    name: str
    amount: float
    frequency: str = "monthly"
    due_day: int = 1
    late_fine_per_day: float = 0.0


class VpsFeeUpdate(BaseModel):
    name: str | None = None
    amount: float | None = None
    frequency: str | None = None
    due_day: int | None = None
    late_fine_per_day: float | None = None
    status: str | None = None


def vps_fee_payload(fee: VpsFee) -> dict[str, Any]:
    return {
        "id": fee.id,
        "name": fee.name,
        "amount": float(fee.amount),
        "frequency": fee.frequency,
        "due_day": fee.due_day,
        "late_fine_per_day": float(fee.late_fine_per_day),
        "status": fee.status,
        "is_active": fee.is_active,
        "created_at": fee.created_at.isoformat() if fee.created_at else None,
        "updated_at": fee.updated_at.isoformat() if fee.updated_at else None,
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
            module="vps_fees",
            entity_type="vps_fee",
            entity_id=entity_id,
            old_value=old_value,
            new_value=new_value,
            created_by=current_user.id,
            updated_by=current_user.id,
        )
    )


@router.get("")
def list_vps_fees(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal_or_admin(current_user)
    fees = db.scalars(
        select(VpsFee)
        .where(VpsFee.school_id == current_user.school_id, VpsFee.deleted_at.is_(None))
        .order_by(VpsFee.created_at.desc())
    ).all()
    return {"success": True, "data": [vps_fee_payload(f) for f in fees], "message": "VPS fees retrieved"}


@router.post("")
def create_vps_fee(
    payload: VpsFeeCreate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal_or_admin(current_user)
    fee = VpsFee(
        school_id=current_user.school_id,
        name=payload.name,
        amount=payload.amount,
        frequency=payload.frequency,
        due_day=payload.due_day,
        late_fine_per_day=payload.late_fine_per_day,
        created_by=current_user.id,
        updated_by=current_user.id,
    )
    db.add(fee)
    db.flush()
    record_audit(db, current_user, action="create", entity_id=fee.id, new_value=fee.name)
    db.commit()
    db.refresh(fee)
    return {"success": True, "data": vps_fee_payload(fee), "message": "VPS fee created"}


@router.put("/{fee_id}")
def update_vps_fee(
    fee_id: str,
    payload: VpsFeeUpdate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal_or_admin(current_user)
    fee = db.scalar(
        select(VpsFee).where(
            VpsFee.id == fee_id,
            VpsFee.school_id == current_user.school_id,
            VpsFee.deleted_at.is_(None),
        )
    )
    if fee is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="VPS fee not found")

    old_value = vps_fee_payload(fee)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(fee, field, value)
    fee.updated_by = current_user.id
    db.flush()
    record_audit(db, current_user, action="update", entity_id=fee.id, old_value=str(old_value), new_value=vps_fee_payload(fee))
    db.commit()
    db.refresh(fee)
    return {"success": True, "data": vps_fee_payload(fee), "message": "VPS fee updated"}


@router.delete("/{fee_id}")
def delete_vps_fee(
    fee_id: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal_or_admin(current_user)
    fee = db.scalar(
        select(VpsFee).where(
            VpsFee.id == fee_id,
            VpsFee.school_id == current_user.school_id,
            VpsFee.deleted_at.is_(None),
        )
    )
    if fee is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="VPS fee not found")

    fee.deleted_at = utcnow()
    fee.is_active = False
    fee.updated_by = current_user.id
    record_audit(db, current_user, action="delete", entity_id=fee.id, old_value=fee.name)
    db.commit()
    return {"success": True, "data": None, "message": "VPS fee deleted"}