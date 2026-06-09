from __future__ import annotations

from datetime import date
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import and_, select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import utcnow
from app.dependencies.auth import CurrentUser, get_current_user, require_principal_or_admin
from app.models.attendance import StaffAttendance, StudentAttendance
from app.models.goal_task import AuditLog

router = APIRouter(prefix="/api/v1/attendance", tags=["attendance"])


class StaffAttendanceMark(BaseModel):
    status: str = "present"  # present, absent, half_day, late


class StudentAttendanceMark(BaseModel):
    student_id: str
    status: str = "present"  # present, absent, half_day, late


class BulkStudentAttendanceMark(BaseModel):
    attendance: list[StudentAttendanceMark]


def attendance_payload(att: StaffAttendance | StudentAttendance) -> dict[str, Any]:
    return {
        "id": att.id,
        "staff_id": att.staff_id if isinstance(att, StaffAttendance) else None,
        "student_id": att.student_id if isinstance(att, StudentAttendance) else None,
        "section_id": att.section_id if isinstance(att, StudentAttendance) else None,
        "date": att.date.isoformat() if att.date else None,
        "status": att.status,
        "marked_by": att.marked_by,
        "marked_at": att.marked_at.isoformat() if att.marked_at else None,
    }


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


@router.get("/staff/me/today")
def get_my_today_attendance(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    if not current_user.linked_id:
        return {"success": True, "data": {"attendance": None}, "message": "No linked staff record"}

    today = date.today()
    att = db.scalar(
        select(StaffAttendance).where(
            StaffAttendance.school_id == current_user.school_id,
            StaffAttendance.staff_id == current_user.linked_id,
            StaffAttendance.date == today,
            StaffAttendance.deleted_at.is_(None),
        )
    )
    if att is None:
        return {"success": True, "data": {"attendance": None}, "message": "Attendance not marked"}
    return {"success": True, "data": {"attendance": attendance_payload(att)}, "message": "Attendance found"}


@router.post("/staff/me/today")
def mark_my_today_attendance(
    payload: StaffAttendanceMark,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    if not current_user.linked_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No linked staff record")

    if payload.status not in {"present", "absent", "half_day", "late"}:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid status")

    today = date.today()
    att = db.scalar(
        select(StaffAttendance).where(
            StaffAttendance.school_id == current_user.school_id,
            StaffAttendance.staff_id == current_user.linked_id,
            StaffAttendance.date == today,
            StaffAttendance.deleted_at.is_(None),
        )
    )
    now = utcnow()
    if att is None:
        att = StaffAttendance(
            school_id=current_user.school_id,
            staff_id=current_user.linked_id,
            date=today,
            status=payload.status,
            marked_by=current_user.id,
            marked_at=now,
            created_by=current_user.id,
            updated_by=current_user.id,
        )
        db.add(att)
        action = "mark"
    else:
        att.status = payload.status
        att.marked_by = current_user.id
        att.marked_at = now
        att.updated_by = current_user.id
        action = "update"

    db.flush()
    record_audit(db, current_user, action=action, module="staff_attendance", entity_type="staff_attendance", entity_id=att.id)
    db.commit()
    db.refresh(att)
    return {"success": True, "data": {"attendance": attendance_payload(att)}, "message": f"Attendance {action}ed"}


@router.get("/staff")
def list_staff_attendance(
    date_from: str | None = Query(None),
    date_to: str | None = Query(None),
    staff_id: str | None = Query(None),
    status_filter: str | None = Query(None),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal_or_admin(current_user)
    stmt = select(StaffAttendance).where(
        StaffAttendance.school_id == current_user.school_id,
        StaffAttendance.deleted_at.is_(None),
    )
    if staff_id:
        stmt = stmt.where(StaffAttendance.staff_id == staff_id)
    if status_filter:
        stmt = stmt.where(StaffAttendance.status == status_filter)
    if date_from:
        stmt = stmt.where(StaffAttendance.date >= date_from)
    if date_to:
        stmt = stmt.where(StaffAttendance.date <= date_to)

    atts = db.scalars(stmt.order_by(StaffAttendance.date.desc())).all()
    return {"success": True, "data": [attendance_payload(a) for a in atts], "message": "Staff attendance retrieved"}


@router.get("/students/{section_id}/{date_str}")
def get_student_attendance(
    section_id: str,
    date_str: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    if current_user.role not in {"principal", "admin"}:
        if current_user.role == "teacher" and section_id not in (current_user.class_teacher_sections or ()):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your class section")
        if current_user.role not in {"teacher"}:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Student attendance access denied")
    try:
        attendance_date = date.fromisoformat(date_str)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid date format")

    atts = db.scalars(
        select(StudentAttendance).where(
            StudentAttendance.school_id == current_user.school_id,
            StudentAttendance.section_id == section_id,
            StudentAttendance.date == attendance_date,
            StudentAttendance.deleted_at.is_(None),
        )
    ).all()
    return {"success": True, "data": [attendance_payload(a) for a in atts], "message": "Student attendance retrieved"}


@router.post("/students/{section_id}/{date_str}")
def mark_student_attendance(
    section_id: str,
    date_str: str,
    payload: BulkStudentAttendanceMark,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    if current_user.role not in {"principal", "admin"}:
        if current_user.role == "teacher" and section_id not in (current_user.class_teacher_sections or ()):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your class section")
        if current_user.role not in {"teacher"}:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Student attendance access denied")
    try:
        attendance_date = date.fromisoformat(date_str)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid date format")

    now = utcnow()
    results = []
    for item in payload.attendance:
        if item.status not in {"present", "absent", "half_day", "late"}:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Invalid status for student {item.student_id}")

        att = db.scalar(
            select(StudentAttendance).where(
                StudentAttendance.school_id == current_user.school_id,
                StudentAttendance.student_id == item.student_id,
                StudentAttendance.section_id == section_id,
                StudentAttendance.date == attendance_date,
                StudentAttendance.deleted_at.is_(None),
            )
        )
        if att is None:
            att = StudentAttendance(
                school_id=current_user.school_id,
                student_id=item.student_id,
                section_id=section_id,
                date=attendance_date,
                status=item.status,
                marked_by=current_user.id,
                marked_at=now,
                created_by=current_user.id,
                updated_by=current_user.id,
            )
            db.add(att)
            action = "mark"
        else:
            att.status = item.status
            att.marked_by = current_user.id
            att.marked_at = now
            att.updated_by = current_user.id
            action = "update"

        db.flush()
        record_audit(db, current_user, action=action, module="student_attendance", entity_type="student_attendance", entity_id=att.id)
        results.append(attendance_payload(att))

    db.commit()
    return {"success": True, "data": results, "message": "Student attendance marked"}