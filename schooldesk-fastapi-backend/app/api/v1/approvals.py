from __future__ import annotations

import json
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.dependencies.auth import CurrentUser, get_current_user
from app.models.auth import User
from app.models.base import now_utc
from app.models.goal_task import ApprovalRequest, AuditLog, NotificationLog

router = APIRouter(prefix="/api/v1", tags=["approvals"])

ALIAS_TYPES = {
    "account-approvals": "account",
    "class-approvals": "class",
    "student-approvals": "student",
}


def success(data: Any = None, message: str = "Operation completed successfully", **extra: Any) -> dict[str, Any]:
    return {"success": True, "message": message, "data": data, "meta": {}, **extra}


def clean(value: Any, default: str = "") -> str:
    text = str(value or "").strip()
    return text or default


def json_text(value: Any) -> str:
    return json.dumps(value or {}, separators=(",", ":"), sort_keys=True)


def parse_payload(row: ApprovalRequest) -> dict[str, Any]:
    try:
        value = json.loads(row.payload or "{}")
    except json.JSONDecodeError:
        value = {}
    return value if isinstance(value, dict) else {}


def require_principal_or_admin(current_user: CurrentUser) -> None:
    if current_user.role not in {"principal", "admin"}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Principal or Admin access required")


def require_principal(current_user: CurrentUser) -> None:
    if not current_user.is_principal:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Principal approval authority required")


def can_modify_request(current_user: CurrentUser, row: ApprovalRequest) -> bool:
    if current_user.is_principal:
        return True
    return current_user.role == "admin" and row.requester_user_id == current_user.id


def audit(db: Session, current_user: CurrentUser, row: ApprovalRequest, action: str, old_value: Any, new_value: Any) -> None:
    db.add(
        AuditLog(
            school_id=current_user.school_id,
            user_id=current_user.id,
            action=action,
            module="approvals",
            entity_type="approval_request",
            entity_id=row.id,
            old_value=json_text(old_value),
            new_value=json_text(new_value),
            created_by=current_user.id,
        )
    )


def notify_principal(db: Session, current_user: CurrentUser, row: ApprovalRequest, title: str, body: str) -> None:
    db.add(
        NotificationLog(
            school_id=current_user.school_id,
            recipient_role="principal",
            reference_type="approval",
            reference_id=row.id,
            title=title,
            body=body,
            status="queued",
            created_by=current_user.id,
        )
    )


def notify_requester(db: Session, current_user: CurrentUser, row: ApprovalRequest, title: str, body: str) -> None:
    db.add(
        NotificationLog(
            school_id=current_user.school_id,
            recipient_user_id=row.requester_user_id,
            reference_type="approval",
            reference_id=row.id,
            title=title,
            body=body,
            status="queued",
            created_by=current_user.id,
        )
    )


def request_payload(payload: dict[str, Any], *, default_type: str = "") -> dict[str, Any]:
    module = clean(payload.get("module"), default_type or "general")
    operation_type = clean(payload.get("operation_type") or payload.get("action"), "review")
    entity_type = clean(payload.get("entity_type"), module)
    student_payload = payload.get("student")
    student_name = clean(student_payload.get("name")) if isinstance(student_payload, dict) else ""
    title = clean(
        payload.get("title")
        or payload.get("summary")
        or payload.get("class_name")
        or student_name,
        f"{module.title()} {operation_type.replace('_', ' ').title()}",
    )
    details = clean(
        payload.get("details")
        or payload.get("description")
        or payload.get("reason")
        or payload.get("purpose"),
        operation_type,
    )
    return {
        "module": module,
        "type": clean(payload.get("type"), default_type or module),
        "operation_type": operation_type,
        "entity_type": entity_type,
        "entity_id": clean(payload.get("entity_id") or payload.get("student_id")),
        "academic_year_id": clean(payload.get("academic_year_id")),
        "title": title,
        "details": details,
        "payload_json": payload.get("payload_json", payload),
        "before_snapshot_json": payload.get("before_snapshot_json", {}),
        "after_snapshot_json": payload.get("after_snapshot_json", {}),
        "remarks": clean(payload.get("remarks")),
        "reason": clean(payload.get("reason")),
    }


def approval_payload(db: Session, row: ApprovalRequest) -> dict[str, Any]:
    payload = parse_payload(row)
    requester = db.get(User, row.requester_user_id)
    requester_name = requester.full_name if requester is not None else row.requester_user_id
    requester_role = requester.role if requester is not None else ""
    module = clean(payload.get("module"), row.module)
    operation_type = clean(payload.get("operation_type"), row.action)
    title = clean(payload.get("title"), f"{module.title()} {operation_type.replace('_', ' ').title()}")
    details = clean(payload.get("details"), operation_type)
    actioned_at = clean(payload.get("actioned_at") or payload.get("applied_at"))
    return {
        "id": row.id,
        "approval_id": row.id,
        "school_id": row.school_id,
        "module": module,
        "module_label": module.replace("_", " ").title(),
        "type": clean(payload.get("type"), module),
        "operation_type": operation_type,
        "action": row.action,
        "entity_type": clean(payload.get("entity_type"), module),
        "entity_id": clean(payload.get("entity_id")),
        "academic_year_id": clean(payload.get("academic_year_id")),
        "requester_user_id": row.requester_user_id,
        "requested_by_user_id": row.requester_user_id,
        "requester_name": requester_name,
        "requester_role": requester_role,
        "requested_by_role": requester_role,
        "title": title,
        "summary": title,
        "details": details,
        "description": details,
        "status": row.status,
        "remarks": clean(payload.get("remarks")) or None,
        "reason": clean(payload.get("reason")) or None,
        "change_request_note": clean(payload.get("change_request_note")) or None,
        "apply_note": clean(payload.get("apply_note")) or None,
        "submitted_at": row.created_at.isoformat(),
        "created_at": row.created_at.isoformat(),
        "action_date": actioned_at,
        "applied_at": clean(payload.get("applied_at")) or None,
        "payload_json": payload.get("payload_json", {}),
        "before_snapshot_json": payload.get("before_snapshot_json", {}),
        "after_snapshot_json": payload.get("after_snapshot_json", {}),
    }


def get_request(db: Session, current_user: CurrentUser, approval_id: str) -> ApprovalRequest:
    row = db.get(ApprovalRequest, approval_id)
    if row is None or row.school_id != current_user.school_id or row.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Approval request not found")
    if current_user.role == "admin" and row.requester_user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Approval request is outside your scope")
    if current_user.role not in {"principal", "admin"}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Approval access denied")
    return row


def list_requests(
    db: Session,
    current_user: CurrentUser,
    *,
    status_filter: str = "",
    module: str = "",
    approval_type: str = "",
) -> list[dict[str, Any]]:
    require_principal_or_admin(current_user)
    stmt = select(ApprovalRequest).where(
        ApprovalRequest.school_id == current_user.school_id,
        ApprovalRequest.deleted_at.is_(None),
    )
    if current_user.role == "admin":
        stmt = stmt.where(ApprovalRequest.requester_user_id == current_user.id)
    if status_filter:
        stmt = stmt.where(ApprovalRequest.status == status_filter)
    if module:
        stmt = stmt.where(ApprovalRequest.module == module)
    rows = db.scalars(stmt.order_by(ApprovalRequest.created_at.desc())).all()
    data = [approval_payload(db, row) for row in rows]
    if approval_type:
        data = [row for row in data if row["type"] == approval_type]
    return data


def create_request(
    db: Session,
    current_user: CurrentUser,
    payload: dict[str, Any],
    *,
    default_type: str = "",
) -> ApprovalRequest:
    require_principal_or_admin(current_user)
    normalized = request_payload(payload, default_type=default_type)
    requested_status = clean(payload.get("status"), "draft")
    if requested_status not in {"draft", "pending", "submitted", "principal_review"}:
        requested_status = "draft"
    row = ApprovalRequest(
        school_id=current_user.school_id,
        requester_user_id=current_user.id,
        module=normalized["module"],
        action=normalized["operation_type"],
        status="pending" if requested_status in {"submitted", "principal_review"} else requested_status,
        payload=json_text(normalized),
        created_by=current_user.id,
    )
    db.add(row)
    db.flush()
    audit(db, current_user, row, "create", {}, approval_payload(db, row))
    notify_principal(
        db,
        current_user,
        row,
        title=f"Approval requested: {normalized['title']}",
        body=normalized["details"],
    )
    return row


@router.get("/approvals")
def approvals(
    status: str = "",
    module: str = "",
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    return success(list_requests(db, current_user, status_filter=clean(status), module=clean(module)))


@router.post("/approvals")
def create_approval(
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    row = create_request(db, current_user, payload)
    db.commit()
    db.refresh(row)
    return success(approval_payload(db, row), message="Approval request created")


@router.get("/approvals/{approval_id}")
def approval_detail(
    approval_id: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    row = get_request(db, current_user, approval_id)
    return success(approval_payload(db, row))


@router.patch("/approvals/{approval_id}")
@router.put("/approvals/{approval_id}")
def update_approval(
    approval_id: str,
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    row = get_request(db, current_user, approval_id)
    if not can_modify_request(current_user, row):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Approval request is outside your scope")
    if row.status not in {"draft", "changes_requested"} and not current_user.is_principal:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Only draft or changes-requested approvals can be edited")
    old = approval_payload(db, row)
    merged = parse_payload(row)
    merged.update(request_payload(payload, default_type=clean(merged.get("type"))))
    row.module = clean(merged.get("module"), row.module)
    row.action = clean(merged.get("operation_type"), row.action)
    row.payload = json_text(merged)
    row.updated_by = current_user.id
    audit(db, current_user, row, "update", old, approval_payload(db, row))
    db.commit()
    db.refresh(row)
    return success(approval_payload(db, row), message="Approval request updated")


@router.post("/approvals/{approval_id}/submit")
def submit_approval(
    approval_id: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    row = get_request(db, current_user, approval_id)
    if not can_modify_request(current_user, row):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Approval request is outside your scope")
    if row.status not in {"draft", "changes_requested"}:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Approval request cannot be submitted")
    old = approval_payload(db, row)
    row.status = "pending"
    row.updated_by = current_user.id
    payload = parse_payload(row)
    payload["submitted_at"] = now_utc().isoformat()
    row.payload = json_text(payload)
    audit(db, current_user, row, "submit", old, approval_payload(db, row))
    notify_principal(db, current_user, row, "Approval submitted", clean(payload.get("details"), row.action))
    db.commit()
    db.refresh(row)
    return success(approval_payload(db, row), message="Approval request submitted")


@router.post("/approvals/{approval_id}/approve")
def approve_approval(
    approval_id: str,
    payload: dict[str, Any] | None = None,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal(current_user)
    row = get_request(db, current_user, approval_id)
    if row.status not in {"pending", "changes_requested"}:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Only pending approvals can be approved")
    old = approval_payload(db, row)
    row.status = "approved"
    row.updated_by = current_user.id
    details = parse_payload(row)
    details["remarks"] = clean((payload or {}).get("note"), "Approved")
    details["actioned_at"] = now_utc().isoformat()
    details["approved_by"] = current_user.id
    row.payload = json_text(details)
    audit(db, current_user, row, "approve", old, approval_payload(db, row))
    notify_requester(db, current_user, row, "Approval approved", details["remarks"])
    db.commit()
    db.refresh(row)
    return success(approval_payload(db, row), message="Approval request approved")


@router.post("/approvals/{approval_id}/reject")
def reject_approval(
    approval_id: str,
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal(current_user)
    row = get_request(db, current_user, approval_id)
    if row.status not in {"pending", "changes_requested"}:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Only pending approvals can be rejected")
    reason = clean(payload.get("reason"))
    if not reason:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="reason is required")
    old = approval_payload(db, row)
    row.status = "rejected"
    row.updated_by = current_user.id
    details = parse_payload(row)
    details["remarks"] = reason
    details["reason"] = reason
    details["actioned_at"] = now_utc().isoformat()
    details["rejected_by"] = current_user.id
    row.payload = json_text(details)
    audit(db, current_user, row, "reject", old, approval_payload(db, row))
    notify_requester(db, current_user, row, "Approval rejected", reason)
    db.commit()
    db.refresh(row)
    return success(approval_payload(db, row), message="Approval request rejected")


@router.post("/approvals/{approval_id}/request-changes")
def request_changes(
    approval_id: str,
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal(current_user)
    row = get_request(db, current_user, approval_id)
    if row.status != "pending":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Only pending approvals can request changes")
    note = clean(payload.get("note"))
    if not note:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="note is required")
    old = approval_payload(db, row)
    row.status = "changes_requested"
    row.updated_by = current_user.id
    details = parse_payload(row)
    details["change_request_note"] = note
    details["remarks"] = note
    details["actioned_at"] = now_utc().isoformat()
    row.payload = json_text(details)
    audit(db, current_user, row, "request_changes", old, approval_payload(db, row))
    notify_requester(db, current_user, row, "Approval changes requested", note)
    db.commit()
    db.refresh(row)
    return success(approval_payload(db, row), message="Changes requested")


@router.post("/approvals/{approval_id}/cancel")
def cancel_approval(
    approval_id: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    row = get_request(db, current_user, approval_id)
    if not can_modify_request(current_user, row):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Approval request is outside your scope")
    if row.status in {"approved", "applied", "rejected"}:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Resolved approvals cannot be cancelled")
    old = approval_payload(db, row)
    row.status = "cancelled"
    row.updated_by = current_user.id
    details = parse_payload(row)
    details["actioned_at"] = now_utc().isoformat()
    row.payload = json_text(details)
    audit(db, current_user, row, "cancel", old, approval_payload(db, row))
    notify_requester(db, current_user, row, "Approval cancelled", "Approval request cancelled")
    db.commit()
    db.refresh(row)
    return success(approval_payload(db, row), message="Approval request cancelled")


@router.post("/approvals/{approval_id}/apply")
def apply_approval(
    approval_id: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal(current_user)
    row = get_request(db, current_user, approval_id)
    if row.status == "applied":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Approval request has already been applied")
    if row.status != "approved":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Only approved requests can be marked applied")
    old = approval_payload(db, row)
    row.status = "applied"
    row.updated_by = current_user.id
    details = parse_payload(row)
    details["applied_at"] = now_utc().isoformat()
    details["applied_by"] = current_user.id
    details["apply_note"] = "Marked applied by Principal; no sensitive school mutation was auto-applied."
    row.payload = json_text(details)
    audit(db, current_user, row, "apply_mark", old, approval_payload(db, row))
    notify_requester(db, current_user, row, "Approval applied", details["apply_note"])
    db.commit()
    db.refresh(row)
    return success(approval_payload(db, row), message="Approval request marked applied")


def alias_list(
    alias: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    return success(list_requests(db, current_user, approval_type=ALIAS_TYPES[alias]))


def alias_create(
    alias: str,
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    row = create_request(db, current_user, payload, default_type=ALIAS_TYPES[alias])
    if row.status == "draft":
        row.status = "pending"
    db.commit()
    db.refresh(row)
    return success(approval_payload(db, row), message="Approval request created")


def alias_update(
    alias: str,
    approval_id: str,
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    if "status" in payload:
        requested = clean(payload.get("status")).lower()
        if requested == "approved":
            return approve_approval(approval_id, {"note": clean(payload.get("remarks"), "Approved")}, db, current_user)
        if requested == "rejected":
            return reject_approval(approval_id, {"reason": clean(payload.get("reason") or payload.get("remarks"))}, db, current_user)
    return update_approval(approval_id, payload, db, current_user)


@router.get("/account-approvals")
def account_approvals(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    return alias_list("account-approvals", db, current_user)


@router.post("/account-approvals")
def create_account_approval(
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    return alias_create("account-approvals", payload, db, current_user)


@router.put("/account-approvals/{approval_id}")
def update_account_approval(
    approval_id: str,
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    return alias_update("account-approvals", approval_id, payload, db, current_user)


@router.get("/class-approvals")
def class_approvals(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    return alias_list("class-approvals", db, current_user)


@router.post("/class-approvals")
def create_class_approval(
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    return alias_create("class-approvals", payload, db, current_user)


@router.put("/class-approvals/{approval_id}")
def update_class_approval(
    approval_id: str,
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    return alias_update("class-approvals", approval_id, payload, db, current_user)


@router.get("/student-approvals")
def student_approvals(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    return alias_list("student-approvals", db, current_user)


@router.post("/student-approvals")
def create_student_approval(
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    return alias_create("student-approvals", payload, db, current_user)


@router.put("/student-approvals/{approval_id}")
def update_student_approval(
    approval_id: str,
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    return alias_update("student-approvals", approval_id, payload, db, current_user)
