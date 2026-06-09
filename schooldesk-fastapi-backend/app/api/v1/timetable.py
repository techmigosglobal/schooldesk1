from __future__ import annotations

from datetime import time
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import and_, select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import utcnow
from app.dependencies.auth import CurrentUser, get_current_user, require_principal_or_admin
from app.models.auth import Section
from app.models.catalog import Grade, StaffSubject, Subject
from app.models.goal_task import AuditLog
from app.models.timetable import TimetableSlot

router = APIRouter(prefix="/api/v1/timetable", tags=["timetable"])


class TimetableSlotCreate(BaseModel):
    academic_year_id: str
    grade_id: str
    section_id: str
    day_of_week: int  # 0=monday, 6=sunday
    period_number: int
    subject_id: str
    staff_id: str | None = None
    room_id: str | None = None
    start_time: str  # HH:MM format
    end_time: str  # HH:MM format


class TimetableSlotUpdate(BaseModel):
    day_of_week: int | None = None
    period_number: int | None = None
    subject_id: str | None = None
    staff_id: str | None = None
    room_id: str | None = None
    start_time: str | None = None
    end_time: str | None = None


class GenerateTimetableRequest(BaseModel):
    academic_year_id: str
    grade_id: str
    section_id: str
    periods_per_day: int = 8
    period_duration_minutes: int = 40


def parse_time(value: str) -> time:
    parts = value.split(":")
    return time(int(parts[0]), int(parts[1]))


def slot_payload(slot: TimetableSlot) -> dict[str, Any]:
    return {
        "id": slot.id,
        "academic_year_id": slot.academic_year_id,
        "grade_id": slot.grade_id,
        "section_id": slot.section_id,
        "day_of_week": slot.day_of_week,
        "period_number": slot.period_number,
        "subject_id": slot.subject_id,
        "staff_id": slot.staff_id,
        "room_id": slot.room_id,
        "start_time": slot.start_time.isoformat() if slot.start_time else None,
        "end_time": slot.end_time.isoformat() if slot.end_time else None,
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
            module="timetable",
            entity_type="timetable_slot",
            entity_id=entity_id,
            old_value=old_value,
            new_value=new_value,
            created_by=current_user.id,
            updated_by=current_user.id,
        )
    )


@router.get("/slots")
def list_timetable_slots(
    academic_year_id: str | None = Query(None),
    grade_id: str | None = Query(None),
    section_id: str | None = Query(None),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    stmt = select(TimetableSlot).where(
        TimetableSlot.school_id == current_user.school_id,
        TimetableSlot.deleted_at.is_(None),
    )

    # RBAC: teachers can only view slots for their sections or subjects
    if current_user.role == "teacher":
        section_filter = TimetableSlot.section_id.in_(current_user.class_teacher_sections) if current_user.class_teacher_sections else False
        if current_user.linked_id:
            subject_ids = db.scalars(
                select(StaffSubject.subject_id).where(
                    StaffSubject.school_id == current_user.school_id,
                    StaffSubject.staff_id == current_user.linked_id,
                    StaffSubject.deleted_at.is_(None),
                )
            ).all()
            subject_filter = TimetableSlot.subject_id.in_(subject_ids) if subject_ids else False
            stmt = stmt.where(section_filter | subject_filter)
        else:
            stmt = stmt.where(section_filter)
    elif current_user.role not in {"principal", "admin"}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Timetable access denied")

    if academic_year_id:
        stmt = stmt.where(TimetableSlot.academic_year_id == academic_year_id)
    if grade_id:
        stmt = stmt.where(TimetableSlot.grade_id == grade_id)
    if section_id:
        stmt = stmt.where(TimetableSlot.section_id == section_id)

    slots = db.scalars(stmt.order_by(TimetableSlot.day_of_week, TimetableSlot.period_number)).all()
    return {"success": True, "data": [slot_payload(s) for s in slots], "message": "Timetable slots retrieved"}


@router.post("/slots")
def create_timetable_slot(
    payload: TimetableSlotCreate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal_or_admin(current_user)

    existing = db.scalar(
        select(TimetableSlot).where(
            TimetableSlot.school_id == current_user.school_id,
            TimetableSlot.section_id == payload.section_id,
            TimetableSlot.day_of_week == payload.day_of_week,
            TimetableSlot.period_number == payload.period_number,
            TimetableSlot.deleted_at.is_(None),
        )
    )
    if existing is not None:
        existing.subject_id = payload.subject_id
        existing.staff_id = payload.staff_id
        existing.room_id = payload.room_id
        existing.start_time = parse_time(payload.start_time)
        existing.end_time = parse_time(payload.end_time)
        existing.updated_by = current_user.id
        db.flush()
        record_audit(db, current_user, action="update", entity_id=existing.id)
        db.commit()
        db.refresh(existing)
        return {"success": True, "data": slot_payload(existing), "message": "Timetable slot updated"}

    slot = TimetableSlot(
        school_id=current_user.school_id,
        academic_year_id=payload.academic_year_id,
        grade_id=payload.grade_id,
        section_id=payload.section_id,
        day_of_week=payload.day_of_week,
        period_number=payload.period_number,
        subject_id=payload.subject_id,
        staff_id=payload.staff_id,
        room_id=payload.room_id,
        start_time=parse_time(payload.start_time),
        end_time=parse_time(payload.end_time),
        created_by=current_user.id,
        updated_by=current_user.id,
    )
    db.add(slot)
    db.flush()
    record_audit(db, current_user, action="create", entity_id=slot.id)
    db.commit()
    db.refresh(slot)
    return {"success": True, "data": slot_payload(slot), "message": "Timetable slot created"}


@router.delete("/slots/{slot_id}")
def delete_timetable_slot(
    slot_id: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal_or_admin(current_user)
    slot = db.scalar(
        select(TimetableSlot).where(
            TimetableSlot.id == slot_id,
            TimetableSlot.school_id == current_user.school_id,
            TimetableSlot.deleted_at.is_(None),
        )
    )
    if slot is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Timetable slot not found")

    slot.deleted_at = utcnow()
    slot.is_active = False
    slot.updated_by = current_user.id
    record_audit(db, current_user, action="delete", entity_id=slot.id)
    db.commit()
    return {"success": True, "data": None, "message": "Timetable slot deleted"}


@router.post("/generate")
def generate_timetable(
    payload: GenerateTimetableRequest,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal_or_admin(current_user)

    subjects = db.scalars(
        select(Subject).where(
            Subject.school_id == current_user.school_id,
            Subject.deleted_at.is_(None),
        )
    ).all()

    if not subjects:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No subjects found")

    staff_subjects = db.scalars(
        select(StaffSubject).where(
            StaffSubject.school_id == current_user.school_id,
            StaffSubject.academic_year_id == payload.academic_year_id,
            StaffSubject.grade_id == payload.grade_id,
            StaffSubject.section_id == payload.section_id,
            StaffSubject.deleted_at.is_(None),
        )
    ).all()

    slots = []
    period_duration = payload.period_duration_minutes
    base_hour = 8  # 8 AM start

    for day in range(5):  # Monday to Friday
        for period in range(1, payload.periods_per_day + 1):
            subject_index = (day * payload.periods_per_day + period - 1) % len(subjects)
            subject = subjects[subject_index]

            staff_id = None
            for ss in staff_subjects:
                if ss.subject_id == subject.id:
                    staff_id = ss.staff_id
                    break

            start_minutes = (base_hour * 60) + ((period - 1) * period_duration)
            end_minutes = start_minutes + period_duration
            start_time_str = f"{start_minutes // 60:02d}:{start_minutes % 60:02d}"
            end_time_str = f"{end_minutes // 60:02d}:{end_minutes % 60:02d}"

            existing = db.scalar(
                select(TimetableSlot).where(
                    TimetableSlot.school_id == current_user.school_id,
                    TimetableSlot.section_id == payload.section_id,
                    TimetableSlot.day_of_week == day,
                    TimetableSlot.period_number == period,
                    TimetableSlot.deleted_at.is_(None),
                )
            )
            if existing is not None:
                existing.subject_id = subject.id
                existing.staff_id = staff_id
                existing.start_time = parse_time(start_time_str)
                existing.end_time = parse_time(end_time_str)
                existing.updated_by = current_user.id
                slots.append(existing)
            else:
                slot = TimetableSlot(
                    school_id=current_user.school_id,
                    academic_year_id=payload.academic_year_id,
                    grade_id=payload.grade_id,
                    section_id=payload.section_id,
                    day_of_week=day,
                    period_number=period,
                    subject_id=subject.id,
                    staff_id=staff_id,
                    start_time=parse_time(start_time_str),
                    end_time=parse_time(end_time_str),
                    created_by=current_user.id,
                    updated_by=current_user.id,
                )
                db.add(slot)
                slots.append(slot)

    db.flush()
    record_audit(db, current_user, action="generate", entity_id=payload.section_id, new_value=f"Generated {len(slots)} slots")
    db.commit()
    return {"success": True, "data": [slot_payload(s) for s in slots], "message": f"Generated {len(slots)} timetable slots"}