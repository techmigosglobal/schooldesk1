from __future__ import annotations

from datetime import date, datetime
from math import ceil
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import utcnow
from app.dependencies.auth import CurrentUser, get_current_user
from app.models.app_record import AppRecord
from app.models.auth import School
from app.models.catalog import AcademicYear

router = APIRouter(prefix="/api/v1", tags=["app-records"])

COLLECTION_PATHS = {
    "attendance/reports/exports",
    "attendance/sessions",
    "audit-logs",
    "communications",
    "diary-entries",
    "documents/access-requests",
    "documents/requests",
    "events",
    "events/approvals",
    "exams/grading-scale",
    "exams/report-cards",
    "exams/schedules",
    "exams/types",
    "fees/categories",
    "fees/concessions",
    "fees/payments",
    "fees/payment-requests",
    "fees/reminders",
    "fees/reports/exports",
    "holidays",
    "homework",
    "leaves",
    "message-conversations",
    "messages",
    "notices",
    "notifications/device-tokens",
    "parent-teacher-meetings",
    "principal/exam-advice",
    "principal-reports",
    "reports/exports",
    "student-discipline",
    "student-notes",
    "teacher-performance",
    "timetable/substitutions",
}

NESTED_COLLECTIONS = {
    "attachment-requests",
    "marks",
    "prints",
    "review",
    "submissions",
}

ACTION_SEGMENTS = {
    "generate",
    "mark",
    "publish",
    "read",
    "read-all",
    "approve",
    "reject",
    "decision",
    "review",
}


def success(data: Any = None, message: str = "Operation completed successfully", **extra: Any) -> dict[str, Any]:
    return {"success": True, "message": message, "data": data, "meta": {}, **extra}


def page_response(data: list[dict[str, Any]], *, page: int, page_size: int) -> dict[str, Any]:
    total = len(data)
    return success(
        data,
        page=page,
        page_size=page_size,
        total=total,
        total_pages=max(1, ceil(total / page_size)) if page_size > 0 else 1,
    )


def _segments(path: str) -> list[str]:
    return [segment.strip() for segment in path.split("/") if segment.strip()]


def _resource_from_segments(segments: list[str]) -> str:
    return "/".join(segments)


def _normalize_payload(payload: dict[str, Any], *, record_id: str, current_user: CurrentUser) -> dict[str, Any]:
    row = dict(payload)
    row.setdefault("id", record_id)
    row.setdefault("school_id", current_user.school_id)
    row.setdefault("created_by", current_user.id)
    row.setdefault("updated_by", current_user.id)
    row.setdefault("created_role", current_user.role)
    row.setdefault("updated_role", current_user.role)
    return row


def _json_safe(value: Any) -> Any:
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    if isinstance(value, dict):
        return {str(k): _json_safe(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_json_safe(v) for v in value]
    return value


def _title_for(payload: dict[str, Any], resource: str) -> str:
    for key in ("title", "name", "subject", "report_name", "event_title", "document_type", "message"):
        value = str(payload.get(key) or "").strip()
        if value:
            return value[:240]
    return resource.replace("/", " ").replace("-", " ").title()[:240]


def _parent_student_id(payload: dict[str, Any], current_user: CurrentUser) -> str | None:
    for key in ("student_id", "studentId", "child_id", "childId"):
        value = str(payload.get(key) or "").strip()
        if value:
            return value
    if current_user.role == "parent":
        return current_user.linked_id
    return None


def _can_write(resource: str, current_user: CurrentUser) -> bool:
    if resource == "notifications/device-tokens":
        return current_user.role in {"principal", "admin", "teacher", "parent"}
    if current_user.role in {"principal", "admin"}:
        return True
    if current_user.role == "teacher":
        return resource.startswith(
            (
                "attendance/sessions",
                "homework",
                "messages",
                "message-conversations",
                "communications",
                "diary-entries",
                "student-notes",
                "student-discipline",
                "teacher-performance",
                "parent-teacher-meetings",
            )
        )
    if current_user.role == "parent":
        return resource.startswith(
            (
                "documents/access-requests",
                "fees/payment-requests",
                "homework/submissions",
                "homework/attachment-requests",
                "messages",
                "message-conversations",
                "parent-teacher-meetings",
            )
        )
    return False


def _visibility_filter(stmt, current_user: CurrentUser):
    if current_user.role in {"principal", "admin"}:
        return stmt
    if current_user.role == "teacher":
        return stmt.where(
            or_(
                AppRecord.owner_user_id == current_user.id,
                AppRecord.owner_staff_id == current_user.linked_id,
                AppRecord.owner_role.in_(("teacher", "principal", "admin")),
            )
        )
    if current_user.role == "parent":
        return stmt.where(
            or_(
                AppRecord.owner_user_id == current_user.id,
                AppRecord.owner_student_id == current_user.linked_id,
                AppRecord.owner_role.in_(("parent", "principal", "admin", "")),
            )
        )
    return stmt.where(AppRecord.owner_user_id == current_user.id)


def _record_payload(record: AppRecord) -> dict[str, Any]:
    payload = dict(record.payload or {})
    payload.update(
        {
            "id": record.id,
            "school_id": record.school_id,
            "resource": record.resource,
            "parent_id": record.parent_id or payload.get("parent_id", ""),
            "status": payload.get("status", record.status),
            "created_at": record.created_at.isoformat() if record.created_at else "",
            "updated_at": record.updated_at.isoformat() if record.updated_at else "",
            "created_by": record.created_by or payload.get("created_by", ""),
            "updated_by": record.updated_by or payload.get("updated_by", ""),
        }
    )
    return payload


def _collection_context(path: str) -> tuple[str, str | None]:
    segments = _segments(path)
    if len(segments) >= 3 and segments[-1] in NESTED_COLLECTIONS:
        return _resource_from_segments([*segments[:-2], segments[-1]]), segments[-2]
    return _resource_from_segments(segments), None


def _item_context(path: str) -> tuple[str, str] | None:
    segments = _segments(path)
    if len(segments) < 2:
        return None
    if len(segments) >= 3 and segments[-1] in NESTED_COLLECTIONS:
        return None
    candidate = _resource_from_segments(segments[:-1])
    if _resource_from_segments(segments) in COLLECTION_PATHS:
        return None
    if segments[-1] in ACTION_SEGMENTS:
        return None
    return candidate, segments[-1]


def _special_get(path: str, db: Session, current_user: CurrentUser) -> dict[str, Any] | None:
    segments = _segments(path)
    if len(segments) == 2 and segments[0] == "academic-years":
        row = db.scalar(select(AcademicYear).where(AcademicYear.id == segments[1], AcademicYear.school_id == current_user.school_id))
        if row is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Academic year not found")
        return success(
            {
                "id": row.id,
                "school_id": row.school_id,
                "year_label": row.year_label,
                "start_date": row.start_date.isoformat() if row.start_date else "",
                "end_date": row.end_date.isoformat() if row.end_date else "",
                "is_current": row.is_current,
                "status": row.status,
            },
            message="Academic year retrieved",
        )
    if len(segments) == 1 and segments[0] == "schools":
        rows = db.scalars(select(School)).all()
        return success([{"id": row.id, "name": row.name} for row in rows], message="Schools retrieved")
    return None


@router.get("/{path:path}")
def list_or_get_records(
    path: str,
    page: int = Query(1, ge=1),
    page_size: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    special = _special_get(path, db, current_user)
    if special is not None:
        return special

    item = _item_context(path)
    if item is not None:
        resource, record_id = item
        stmt = select(AppRecord).where(
            AppRecord.id == record_id,
            AppRecord.resource == resource,
            AppRecord.school_id == current_user.school_id,
            AppRecord.deleted_at.is_(None),
        )
        record = db.scalar(_visibility_filter(stmt, current_user))
        if record is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Record not found")
        return success(_record_payload(record), message="Record retrieved")

    resource, parent_id = _collection_context(path)
    stmt = select(AppRecord).where(
        AppRecord.resource == resource,
        AppRecord.school_id == current_user.school_id,
        AppRecord.deleted_at.is_(None),
    )
    if parent_id:
        stmt = stmt.where(AppRecord.parent_id == parent_id)
    rows = db.scalars(_visibility_filter(stmt.order_by(AppRecord.created_at.desc()), current_user)).all()
    return page_response([_record_payload(row) for row in rows], page=page, page_size=page_size)


@router.post("/{path:path}")
def create_record(
    path: str,
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    segments = _segments(path)
    resource, parent_id = _collection_context(path)
    if segments and segments[-1] in ACTION_SEGMENTS and len(segments) > 1:
        resource = _resource_from_segments(segments[:-1])
    if not _can_write(resource, current_user):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Write access denied")

    payload = _json_safe(payload or {})
    record = AppRecord(
        school_id=current_user.school_id,
        resource=resource,
        parent_id=parent_id or str(payload.get("parent_id") or payload.get("parentId") or ""),
        owner_role=current_user.role,
        owner_user_id=current_user.id,
        owner_staff_id=current_user.linked_id if current_user.linked_type == "staff" else str(payload.get("staff_id") or ""),
        owner_student_id=_parent_student_id(payload, current_user),
        status=str(payload.get("status") or "active"),
        title=_title_for(payload, resource),
        payload={},
        notes=str(payload.get("notes") or payload.get("description") or ""),
        created_by=current_user.id,
        updated_by=current_user.id,
    )
    db.add(record)
    db.flush()
    record.payload = _normalize_payload(payload, record_id=record.id, current_user=current_user)
    db.commit()
    db.refresh(record)
    return success(_record_payload(record), message="Record created")


@router.put("/{path:path}")
@router.patch("/{path:path}")
def update_record(
    path: str,
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    item = _item_context(path)
    if item is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Record id is required")
    resource, record_id = item
    if not _can_write(resource, current_user):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Write access denied")
    stmt = select(AppRecord).where(
        AppRecord.id == record_id,
        AppRecord.resource == resource,
        AppRecord.school_id == current_user.school_id,
        AppRecord.deleted_at.is_(None),
    )
    record = db.scalar(_visibility_filter(stmt, current_user))
    if record is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Record not found")

    merged = dict(record.payload or {})
    merged.update(_json_safe(payload or {}))
    record.payload = _normalize_payload(merged, record_id=record.id, current_user=current_user)
    record.status = str(merged.get("status") or record.status or "active")
    record.title = _title_for(merged, resource)
    record.updated_by = current_user.id
    db.commit()
    db.refresh(record)
    return success(_record_payload(record), message="Record updated")


@router.delete("/{path:path}")
def delete_record(
    path: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    item = _item_context(path)
    if item is None:
        resource, _ = _collection_context(path)
        if resource in COLLECTION_PATHS:
            return success(None, message="Record collection action completed")
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Record id is required")
    resource, record_id = item
    if not _can_write(resource, current_user):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Write access denied")
    record = db.scalar(
        _visibility_filter(
            select(AppRecord).where(
                AppRecord.id == record_id,
                AppRecord.resource == resource,
                AppRecord.school_id == current_user.school_id,
                AppRecord.deleted_at.is_(None),
            ),
            current_user,
        )
    )
    if record is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Record not found")
    record.deleted_at = utcnow()
    record.is_active = False
    record.updated_by = current_user.id
    db.commit()
    return success(None, message="Record deleted")


def _operation_name(prefix: str, resource: str) -> str:
    return f"{prefix}_{resource.replace('/', '_').replace('-', '_')}"


def _schema_list_handler(resource: str):
    def handler(
        page: int = Query(1, ge=1),
        page_size: int = Query(100, ge=1, le=500),
        db: Session = Depends(get_db),
        current_user: CurrentUser = Depends(get_current_user),
    ) -> dict[str, Any]:
        return list_or_get_records(resource, page, page_size, db, current_user)

    return handler


def _schema_create_handler(resource: str):
    def handler(
        payload: dict[str, Any],
        db: Session = Depends(get_db),
        current_user: CurrentUser = Depends(get_current_user),
    ) -> dict[str, Any]:
        return create_record(resource, payload, db, current_user)

    return handler


def _schema_item_get_handler(resource: str):
    def handler(
        record_id: str,
        db: Session = Depends(get_db),
        current_user: CurrentUser = Depends(get_current_user),
    ) -> dict[str, Any]:
        return list_or_get_records(f"{resource}/{record_id}", 1, 100, db, current_user)

    return handler


def _schema_item_update_handler(resource: str):
    def handler(
        record_id: str,
        payload: dict[str, Any],
        db: Session = Depends(get_db),
        current_user: CurrentUser = Depends(get_current_user),
    ) -> dict[str, Any]:
        return update_record(f"{resource}/{record_id}", payload, db, current_user)

    return handler


def _schema_item_delete_handler(resource: str):
    def handler(
        record_id: str,
        db: Session = Depends(get_db),
        current_user: CurrentUser = Depends(get_current_user),
    ) -> dict[str, Any]:
        return delete_record(f"{resource}/{record_id}", db, current_user)

    return handler


for _resource in sorted(COLLECTION_PATHS):
    router.add_api_route(
        f"/{_resource}",
        _schema_list_handler(_resource),
        methods=["GET"],
        name=_operation_name("list", _resource),
        summary=f"List {_resource}",
        include_in_schema=True,
    )
    router.add_api_route(
        f"/{_resource}",
        _schema_create_handler(_resource),
        methods=["POST"],
        name=_operation_name("create", _resource),
        summary=f"Create {_resource}",
        include_in_schema=True,
    )
    router.add_api_route(
        f"/{_resource}/{{record_id}}",
        _schema_item_get_handler(_resource),
        methods=["GET"],
        name=_operation_name("get", _resource),
        summary=f"Get {_resource}",
        include_in_schema=True,
    )
    router.add_api_route(
        f"/{_resource}/{{record_id}}",
        _schema_item_update_handler(_resource),
        methods=["PATCH"],
        name=_operation_name("patch", _resource),
        summary=f"Update {_resource}",
        include_in_schema=True,
    )
    router.add_api_route(
        f"/{_resource}/{{record_id}}",
        _schema_item_update_handler(_resource),
        methods=["PUT"],
        name=_operation_name("put", _resource),
        summary=f"Replace {_resource}",
        include_in_schema=True,
    )
    router.add_api_route(
        f"/{_resource}/{{record_id}}",
        _schema_item_delete_handler(_resource),
        methods=["DELETE"],
        name=_operation_name("delete", _resource),
        summary=f"Delete {_resource}",
        include_in_schema=True,
    )
