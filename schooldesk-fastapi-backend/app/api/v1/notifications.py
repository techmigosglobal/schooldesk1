from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import utcnow
from app.api.v1 import app_records
from app.dependencies.auth import CurrentUser, get_current_user
from app.models.goal_task import AuditLog, NotificationLog

router = APIRouter(prefix="/api/v1/notifications", tags=["notifications"])


def notification_payload(n: NotificationLog) -> dict[str, Any]:
    return {
        "id": n.id,
        "recipient_user_id": n.recipient_user_id,
        "recipient_role": n.recipient_role,
        "reference_type": n.reference_type,
        "reference_id": n.reference_id,
        "title": n.title,
        "body": n.body,
        "status": n.status,
        "read_at": n.read_at.isoformat() if n.read_at else None,
        "created_at": n.created_at.isoformat() if n.created_at else None,
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
            module="notifications",
            entity_type="notification",
            entity_id=entity_id,
            old_value=old_value,
            new_value=new_value,
            created_by=current_user.id,
            updated_by=current_user.id,
        )
    )


@router.get("")
def list_notifications(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    stmt = select(NotificationLog).where(
        NotificationLog.school_id == current_user.school_id,
        NotificationLog.deleted_at.is_(None),
        or_(
            NotificationLog.recipient_user_id == current_user.id,
            NotificationLog.recipient_role == current_user.role,
        ),
    )
    notifications = db.scalars(stmt.order_by(NotificationLog.created_at.desc())).all()
    return {"success": True, "data": [notification_payload(n) for n in notifications], "message": "Notifications retrieved"}


@router.patch("/{notification_id}/read")
def mark_notification_read(
    notification_id: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    notification = db.scalar(
        select(NotificationLog).where(
            NotificationLog.id == notification_id,
            NotificationLog.school_id == current_user.school_id,
            NotificationLog.deleted_at.is_(None),
            or_(
                NotificationLog.recipient_user_id == current_user.id,
                NotificationLog.recipient_role == current_user.role,
            ),
        )
    )
    if notification is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Notification not found")

    notification.read_at = utcnow()
    notification.updated_by = current_user.id
    db.flush()
    record_audit(db, current_user, action="read", entity_id=notification.id)
    db.commit()
    db.refresh(notification)
    return {"success": True, "data": notification_payload(notification), "message": "Notification marked as read"}


@router.patch("/read-all")
def mark_all_notifications_read(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    now = utcnow()
    notifications = db.scalars(
        select(NotificationLog).where(
            NotificationLog.school_id == current_user.school_id,
            NotificationLog.deleted_at.is_(None),
            NotificationLog.read_at.is_(None),
            or_(
                NotificationLog.recipient_user_id == current_user.id,
                NotificationLog.recipient_role == current_user.role,
            ),
        )
    ).all()

    count = 0
    for n in notifications:
        n.read_at = now
        n.updated_by = current_user.id
        count += 1

    db.flush()
    record_audit(db, current_user, action="read_all", entity_id="bulk", new_value=f"Marked {count} as read")
    db.commit()
    return {"success": True, "data": {"count": count}, "message": f"{count} notifications marked as read"}


@router.post("/device-tokens")
def register_device_token(
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    return app_records.create_record("notifications/device-tokens", payload, db, current_user)


@router.delete("/device-tokens")
def revoke_device_token(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    return app_records.delete_record("notifications/device-tokens", db, current_user)


@router.delete("/{notification_id}")
def delete_notification(
    notification_id: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    notification = db.scalar(
        select(NotificationLog).where(
            NotificationLog.id == notification_id,
            NotificationLog.school_id == current_user.school_id,
            NotificationLog.deleted_at.is_(None),
            or_(
                NotificationLog.recipient_user_id == current_user.id,
                NotificationLog.recipient_role == current_user.role,
            ),
        )
    )
    if notification is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Notification not found")

    notification.deleted_at = utcnow()
    notification.is_active = False
    notification.updated_by = current_user.id
    record_audit(db, current_user, action="delete", entity_id=notification.id)
    db.commit()
    return {"success": True, "data": None, "message": "Notification deleted"}
