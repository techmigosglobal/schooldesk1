from __future__ import annotations

import csv
import io
from datetime import date
from decimal import Decimal
from math import ceil
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import hash_password
from app.dependencies.auth import CurrentUser, can_access_task, get_current_user
from app.models.auth import Role, School, Section, User, UserRole
from app.models.base import now_utc, uuid_str
from app.models.catalog import (
    AcademicTerm,
    AcademicYear,
    FeeStructure,
    Grade,
    GradeSubject,
    LeaveApplication,
    LeaveBalance,
    LeaveType,
    Room,
    Staff,
    StaffSubject,
    Student,
    StudentLeaveApplication,
    Subject,
)
from app.models.goal_task import ApprovalRequest, AuditLog, NotificationLog, Task

router = APIRouter(prefix="/api/v1", tags=["flutter-compatibility"])


def success(data: Any = None, message: str = "Operation completed successfully", **extra: Any) -> dict[str, Any]:
    return {"success": True, "message": message, "data": data, "meta": {}, **extra}


def page_response(data: list[dict[str, Any]], *, page: int = 1, page_size: int = 20) -> dict[str, Any]:
    total = len(data)
    return success(
        data,
        page=page,
        page_size=page_size,
        total=total,
        total_pages=max(1, ceil(total / page_size)) if page_size > 0 else 1,
    )


def parse_date(value: Any, *, field_name: str) -> date | None:
    text = str(value or "").strip()
    if not text:
        return None
    try:
        return date.fromisoformat(text)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"{field_name} must be an ISO date",
        ) from exc


def iso(value: date | None) -> str:
    return value.isoformat() if value else ""


def clean(value: Any, default: str = "") -> str:
    text = str(value or "").strip()
    return text or default


def require_principal_or_admin(current_user: CurrentUser) -> None:
    if current_user.role not in {"principal", "admin"}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Principal or Admin access required")


def require_principal(current_user: CurrentUser) -> None:
    if not current_user.is_principal:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Principal access required")


def role_id(db: Session, school_id: str, role_name: str) -> str:
    role = db.scalar(select(Role).where(Role.school_id == school_id, Role.name == role_name))
    return role.id if role is not None else role_name


def school_payload(school: School) -> dict[str, Any]:
    return {
        "id": school.id,
        "name": school.name,
        "school_type": school.school_type or "school",
        "affiliation_board": school.affiliation_board or "",
        "email": school.email or "",
        "phone": school.phone or "",
        "city": school.city or "",
        "state": school.state or "",
        "principal_name": school.principal_name or "",
        "registration_number": school.registration_number or "",
        "logo_url": school.logo_url or "",
    }


def academic_year_payload(row: AcademicYear) -> dict[str, Any]:
    return {
        "id": row.id,
        "school_id": row.school_id,
        "year_label": row.year_label,
        "start_date": iso(row.start_date),
        "end_date": iso(row.end_date),
        "is_current": row.is_current,
        "status": row.status,
    }


def term_payload(row: AcademicTerm) -> dict[str, Any]:
    return {
        "id": row.id,
        "school_id": row.school_id,
        "academic_year_id": row.academic_year_id,
        "term_name": row.term_name,
        "name": row.term_name,
        "start_date": iso(row.start_date),
        "end_date": iso(row.end_date),
        "sort_order": row.sort_order,
        "status": row.status,
    }


def grade_payload(row: Grade) -> dict[str, Any]:
    return {
        "id": row.id,
        "school_id": row.school_id,
        "grade_number": row.grade_number,
        "grade_name": row.grade_name,
    }


def subject_payload(row: Subject) -> dict[str, Any]:
    return {
        "id": row.id,
        "subject_id": row.id,
        "school_id": row.school_id,
        "department_id": row.department_id or "",
        "subject_name": row.subject_name,
        "subject_code": row.subject_code,
        "subject_type": row.subject_type,
        "subject_color": row.subject_color,
    }


def grade_subject_payload(row: GradeSubject) -> dict[str, Any]:
    return {
        "id": row.id,
        "grade_subject_id": row.id,
        "school_id": row.school_id,
        "academic_year_id": row.academic_year_id,
        "grade_id": row.grade_id,
        "subject_id": row.subject_id,
        "periods_per_week": row.periods_per_week,
        "max_marks": row.max_marks,
        "pass_marks": row.pass_marks,
        "is_mandatory": row.is_mandatory,
    }


def staff_subject_payload(row: StaffSubject) -> dict[str, Any]:
    return {
        "id": row.id,
        "staff_subject_id": row.id,
        "school_id": row.school_id,
        "academic_year_id": row.academic_year_id,
        "grade_id": row.grade_id,
        "section_id": row.section_id or "",
        "subject_id": row.subject_id,
        "staff_id": row.staff_id or "",
        "teacher_id": row.staff_id or "",
        "is_primary": row.is_primary,
    }


def room_payload(row: Room | None) -> dict[str, Any]:
    if row is None:
        return {}
    return {
        "id": row.id,
        "school_id": row.school_id,
        "room_number": row.room_number,
        "room_type": row.room_type,
        "capacity": row.capacity,
        "block": row.block,
        "floor": row.floor,
    }


def staff_payload(row: Staff | None) -> dict[str, Any]:
    if row is None:
        return {}
    return {
        "id": row.id,
        "school_id": row.school_id,
        "staff_code": row.staff_code,
        "first_name": row.first_name,
        "last_name": row.last_name,
        "email": row.email,
        "phone": row.phone,
        "designation": row.designation,
        "employment_type": row.employment_type,
        "department_id": row.department_id or "",
        "department_name": row.department_name,
        "status": row.status,
        "date_of_birth": iso(row.date_of_birth),
        "gender": row.gender,
        "join_date": iso(row.join_date),
        "photo_url": row.photo_url,
        "documents": [],
    }


def section_payload(db: Session, row: Section) -> dict[str, Any]:
    grade = db.get(Grade, row.grade_id) if row.grade_id else None
    teacher = db.get(Staff, row.class_teacher_id) if row.class_teacher_id else None
    room = db.get(Room, row.room_id) if row.room_id else None
    return {
        "id": row.id,
        "section_id": row.id,
        "section_name": row.name,
        "grade_id": row.grade_id or "",
        "grade": grade_payload(grade) if grade is not None else {},
        "grade_name": grade.grade_name if grade is not None else "",
        "academic_year_id": row.academic_year_id or "",
        "capacity": row.capacity or 0,
        "class_teacher_id": row.class_teacher_id or "",
        "class_teacher": staff_payload(teacher),
        "class_teacher_name": f"{teacher.first_name} {teacher.last_name}".strip() if teacher is not None else "",
        "room_id": row.room_id or "",
        "room": room_payload(room),
        "room_number": room.room_number if room is not None else "",
        "room_type": room.room_type if room is not None else "",
    }


def class_hub_row(db: Session, row: Section) -> dict[str, Any]:
    grade = db.get(Grade, row.grade_id) if row.grade_id else None
    teacher = db.get(Staff, row.class_teacher_id) if row.class_teacher_id else None
    room = db.get(Room, row.room_id) if row.room_id else None
    total_students = len(
        db.scalars(
            select(Student.id).where(
                Student.school_id == row.school_id,
                Student.current_section_id == row.id,
                Student.deleted_at.is_(None),
            )
        ).all()
    )
    grade_name = grade.grade_name if grade else ""
    class_name = f"{grade_name} {row.name}".strip() if grade_name else row.name
    class_teacher = f"{teacher.first_name} {teacher.last_name}".strip() if teacher else ""
    pending_issues = 0
    if not row.class_teacher_id:
        pending_issues += 1
    if not row.room_id:
        pending_issues += 1
    subject_count = len(
        db.scalars(
            select(GradeSubject.id).where(
                GradeSubject.school_id == row.school_id,
                GradeSubject.grade_id == (row.grade_id or ""),
                GradeSubject.academic_year_id == (row.academic_year_id or ""),
                GradeSubject.deleted_at.is_(None),
            )
        ).all()
    )
    if subject_count == 0:
        pending_issues += 1
    return {
        "id": row.id,
        "section_id": row.id,
        "grade_id": row.grade_id or "",
        "academic_year_id": row.academic_year_id or "",
        "class_name": class_name,
        "section_name": row.name,
        "grade_name": grade_name,
        "grade_number": grade.grade_number if grade else 0,
        "capacity": row.capacity or 0,
        "class_teacher_id": row.class_teacher_id or "",
        "class_teacher": class_teacher,
        "class_teacher_name": class_teacher,
        "room_id": row.room_id or "",
        "room_number": room.room_number if room else "",
        "room_type": room.room_type if room else "",
        "total_students": total_students,
        "pending_issues": pending_issues,
        "fees_due_amount": 0,
        "subject_count": subject_count,
    }


def student_payload(db: Session, row: Student) -> dict[str, Any]:
    section = db.get(Section, row.current_section_id) if row.current_section_id else None
    return {
        "id": row.id,
        "school_id": row.school_id,
        "student_code": row.student_code,
        "admission_number": row.admission_number,
        "first_name": row.first_name,
        "last_name": row.last_name,
        "date_of_birth": iso(row.date_of_birth),
        "admission_date": iso(row.admission_date),
        "gender": row.gender,
        "current_section_id": row.current_section_id or "",
        "status": row.status,
        "photo_url": row.photo_url,
        "guardians": [],
        "documents": [],
        "parent_accounts": [],
        "primary_guardian": {},
        "medical_record": {},
        "current_section": section_payload(db, section) if section is not None else {},
        "attendance_summary": {},
        "fee_summary": {},
        "performance_summary": {},
    }


def number(value: Any) -> float:
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, (int, float)):
        return float(value)
    return float(value or 0)


def leave_type_payload(row: LeaveType) -> dict[str, Any]:
    return {
        "id": row.id,
        "school_id": row.school_id,
        "leave_name": row.leave_name,
        "name": row.leave_name,
        "description": row.description,
        "max_days_per_year": number(row.max_days_per_year),
        "applicable_to": row.applicable_to,
    }


def leave_balance_payload(row: LeaveBalance) -> dict[str, Any]:
    return {
        "id": row.id,
        "school_id": row.school_id,
        "staff_id": row.staff_id,
        "leave_type_id": row.leave_type_id,
        "academic_year_id": row.academic_year_id,
        "total_entitled": number(row.total_entitled),
        "used_days": number(row.used_days),
        "remaining_days": number(row.remaining_days),
    }


def leave_application_payload(row: LeaveApplication) -> dict[str, Any]:
    return {
        "id": row.id,
        "school_id": row.school_id,
        "staff_id": row.staff_id,
        "leave_type_id": row.leave_type_id,
        "from_date": row.from_date.isoformat(),
        "to_date": row.to_date.isoformat(),
        "half_day": row.half_day,
        "total_days": number(row.total_days),
        "reason": row.reason,
        "status": row.status,
        "rejection_reason": row.rejection_reason,
        "applied_at": row.applied_at.isoformat() if row.applied_at else None,
    }


def fee_structure_payload(row: FeeStructure) -> dict[str, Any]:
    return {
        "id": row.id,
        "school_id": row.school_id,
        "academic_year_id": row.academic_year_id,
        "grade_id": row.grade_id,
        "section_id": row.section_id or "",
        "fee_category_id": f"category-{row.id}",
        "category_name": row.category_name,
        "category": row.category_name,
        "frequency": row.frequency,
        "amount": number(row.amount),
        "due_day": row.due_day,
        "late_fine_per_day": number(row.late_fine_per_day),
        "status": row.status,
        "fee_category": {
            "id": f"category-{row.id}",
            "category_name": row.category_name,
            "name": row.category_name,
            "frequency": row.frequency,
        },
    }


def student_leave_payload(row: StudentLeaveApplication) -> dict[str, Any]:
    return {
        "id": row.id,
        "school_id": row.school_id,
        "student_id": row.student_id,
        "parent_user_id": row.parent_user_id,
        "leave_type": row.leave_type,
        "from_date": row.from_date.isoformat(),
        "to_date": row.to_date.isoformat(),
        "half_day": row.half_day,
        "total_days": number(row.total_days),
        "reason": row.reason,
        "status": row.status,
        "rejection_reason": row.rejection_reason,
        "applied_at": row.applied_at.isoformat() if row.applied_at else None,
    }


def total_leave_days(from_date: date, to_date: date, *, half_day: bool) -> Decimal:
    if to_date < from_date:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="to_date must be on or after from_date")
    if half_day:
        if from_date != to_date:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="half_day leave must start and end on the same date")
        return Decimal("0.5")
    return Decimal((to_date - from_date).days + 1)


def audit(db: Session, current_user: CurrentUser, *, module: str, action: str, entity_type: str, entity_id: str, new_value: str = "") -> None:
    db.add(
        AuditLog(
            school_id=current_user.school_id,
            user_id=current_user.id,
            action=action,
            module=module,
            entity_type=entity_type,
            entity_id=entity_id,
            old_value="",
            new_value=new_value,
        )
    )


def notify(
    db: Session,
    current_user: CurrentUser,
    *,
    reference_type: str,
    reference_id: str,
    title: str,
    body: str,
    recipient_user_id: str | None = None,
    recipient_role: str | None = None,
) -> None:
    db.add(
        NotificationLog(
            school_id=current_user.school_id,
            recipient_user_id=recipient_user_id,
            recipient_role=recipient_role,
            reference_type=reference_type,
            reference_id=reference_id,
            title=title,
            body=body,
        )
    )


def user_for_staff(db: Session, school_id: str, staff_id: str) -> User | None:
    return db.scalar(
        select(User).where(
            User.school_id == school_id,
            User.linked_type == "staff",
            User.linked_id == staff_id,
        )
    )


def as_int(value: Any, fallback: int = 0) -> int:
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    return int(str(value or "").strip() or fallback)


def as_decimal(value: Any, fallback: str = "0") -> Decimal:
    text = str(value if value is not None else "").replace(",", "").strip()
    try:
        return Decimal(text or fallback)
    except Exception:
        return Decimal(fallback)


def split_semicolon(value: Any) -> list[str]:
    return [item.strip() for item in str(value or "").split(";") if item.strip()]


def at(values: list[str], index: int, fallback: str = "") -> str:
    if index < len(values) and values[index].strip():
        return values[index].strip()
    return fallback


def find_or_create_grade(
    db: Session,
    current_user: CurrentUser,
    *,
    grade_id: str = "",
    grade_name: str = "",
    grade_number: int | None = None,
) -> Grade:
    if grade_id:
        row = db.get(Grade, grade_id)
        if row is not None and row.school_id == current_user.school_id and row.deleted_at is None:
            return row
    if grade_number is not None:
        row = db.scalar(select(Grade).where(Grade.school_id == current_user.school_id, Grade.grade_number == grade_number))
        if row is not None:
            if grade_name:
                row.grade_name = grade_name
            return row
    if grade_name:
        row = db.scalar(select(Grade).where(Grade.school_id == current_user.school_id, Grade.grade_name == grade_name))
        if row is not None:
            return row
    if not grade_name:
        grade_name = f"Grade {grade_number or 1}"
    if grade_number is None:
        existing = db.scalars(select(Grade.grade_number).where(Grade.school_id == current_user.school_id)).all()
        grade_number = (max(existing) if existing else 0) + 1
    row = Grade(
        school_id=current_user.school_id,
        grade_name=grade_name,
        grade_number=grade_number,
        created_by=current_user.id,
    )
    db.add(row)
    db.flush()
    return row


def find_or_create_room(
    db: Session,
    current_user: CurrentUser,
    *,
    room_number: str = "",
    room_type: str = "classroom",
    room_capacity: int = 0,
) -> Room | None:
    if not room_number:
        return None
    row = db.scalar(select(Room).where(Room.school_id == current_user.school_id, Room.room_number == room_number))
    if row is not None:
        row.room_type = room_type or row.room_type
        if room_capacity > 0:
            row.capacity = room_capacity
        return row
    row = Room(
        school_id=current_user.school_id,
        room_number=room_number,
        room_type=room_type or "classroom",
        capacity=room_capacity,
        created_by=current_user.id,
    )
    db.add(row)
    db.flush()
    return row


def find_or_create_subject(
    db: Session,
    current_user: CurrentUser,
    *,
    subject_id: str = "",
    subject_name: str = "",
    subject_code: str = "",
    subject_type: str = "core",
    subject_color: str = "#2563EB",
) -> Subject:
    if subject_id:
        row = db.get(Subject, subject_id)
        if row is not None and row.school_id == current_user.school_id and row.deleted_at is None:
            return row
    if subject_code:
        row = db.scalar(select(Subject).where(Subject.school_id == current_user.school_id, Subject.subject_code == subject_code))
        if row is not None:
            return row
    if subject_name:
        row = db.scalar(select(Subject).where(Subject.school_id == current_user.school_id, Subject.subject_name == subject_name))
        if row is not None:
            return row
    if not subject_name:
        subject_name = subject_code or "Subject"
    if not subject_code:
        subject_code = f"SUB-{uuid_str()[:6].upper()}"
    row = Subject(
        school_id=current_user.school_id,
        subject_name=subject_name,
        subject_code=subject_code,
        subject_type=subject_type or "core",
        subject_color=subject_color or "#2563EB",
        created_by=current_user.id,
    )
    db.add(row)
    db.flush()
    return row


def staff_id_from_payload(db: Session, current_user: CurrentUser, payload: dict[str, Any]) -> str:
    staff_id = clean(payload.get("teacher_id") or payload.get("staff_id"))
    if staff_id:
        staff = db.get(Staff, staff_id)
        if staff is not None and staff.school_id == current_user.school_id and staff.deleted_at is None:
            return staff.id
        return ""
    staff_code = clean(payload.get("staff_code") or payload.get("teacher_staff_code"))
    email = clean(payload.get("email") or payload.get("teacher_email"))
    stmt = select(Staff).where(Staff.school_id == current_user.school_id, Staff.deleted_at.is_(None))
    if staff_code:
        found = db.scalar(stmt.where(Staff.staff_code == staff_code))
        if found is not None:
            return found.id
    if email:
        found = db.scalar(stmt.where(Staff.email == email))
        if found is not None:
            return found.id
    return ""


def upsert_subject_mapping(
    db: Session,
    current_user: CurrentUser,
    *,
    academic_year_id: str,
    grade_id: str,
    section_id: str = "",
    mapping: dict[str, Any],
) -> None:
    subject = find_or_create_subject(
        db,
        current_user,
        subject_id=clean(mapping.get("subject_id")),
        subject_name=clean(mapping.get("subject_name")),
        subject_code=clean(mapping.get("subject_code")),
        subject_type=clean(mapping.get("subject_type"), "core"),
    )
    if mapping.get("delete") is True:
        grade_subject_id = clean(mapping.get("grade_subject_id"))
        staff_subject_id = clean(mapping.get("staff_subject_id"))
        if grade_subject_id:
            row = db.get(GradeSubject, grade_subject_id)
            if row is not None and row.school_id == current_user.school_id:
                row.deleted_at = now_utc()
                row.updated_by = current_user.id
        if staff_subject_id:
            row = db.get(StaffSubject, staff_subject_id)
            if row is not None and row.school_id == current_user.school_id:
                row.deleted_at = now_utc()
                row.updated_by = current_user.id
        return
    grade_subject = db.scalar(
        select(GradeSubject).where(
            GradeSubject.school_id == current_user.school_id,
            GradeSubject.academic_year_id == academic_year_id,
            GradeSubject.grade_id == grade_id,
            GradeSubject.subject_id == subject.id,
            GradeSubject.deleted_at.is_(None),
        )
    )
    if grade_subject is None:
        grade_subject = GradeSubject(
            school_id=current_user.school_id,
            academic_year_id=academic_year_id,
            grade_id=grade_id,
            subject_id=subject.id,
            created_by=current_user.id,
        )
        db.add(grade_subject)
    grade_subject.periods_per_week = as_int(mapping.get("periods_per_week"), 0)
    grade_subject.max_marks = as_int(mapping.get("max_marks"), 100)
    grade_subject.pass_marks = as_int(mapping.get("pass_marks"), 35)
    grade_subject.is_mandatory = bool(mapping.get("is_mandatory", True))
    grade_subject.updated_by = current_user.id
    teacher_id = staff_id_from_payload(db, current_user, mapping)
    if teacher_id or section_id:
        staff_subject = None
        assignment_id = clean(mapping.get("assignment_id") or mapping.get("staff_subject_id"))
        if assignment_id:
            staff_subject = db.get(StaffSubject, assignment_id)
            if staff_subject is not None and staff_subject.school_id != current_user.school_id:
                staff_subject = None
        if staff_subject is None:
            staff_subject = db.scalar(
                select(StaffSubject).where(
                    StaffSubject.school_id == current_user.school_id,
                    StaffSubject.academic_year_id == academic_year_id,
                    StaffSubject.grade_id == grade_id,
                    StaffSubject.section_id == (section_id or None),
                    StaffSubject.subject_id == subject.id,
                    StaffSubject.deleted_at.is_(None),
                )
            )
        if staff_subject is None:
            staff_subject = StaffSubject(
                school_id=current_user.school_id,
                academic_year_id=academic_year_id,
                grade_id=grade_id,
                section_id=section_id or None,
                subject_id=subject.id,
                created_by=current_user.id,
            )
            db.add(staff_subject)
        staff_subject.staff_id = teacher_id or None
        staff_subject.is_primary = bool(mapping.get("is_primary", True))
        staff_subject.updated_by = current_user.id


def replace_fee_items(
    db: Session,
    current_user: CurrentUser,
    *,
    academic_year_id: str,
    grade_id: str,
    section_id: str,
    fee_items: list[Any],
) -> None:
    if not fee_items:
        return
    existing = db.scalars(
        select(FeeStructure).where(
            FeeStructure.school_id == current_user.school_id,
            FeeStructure.academic_year_id == academic_year_id,
            FeeStructure.grade_id == grade_id,
            FeeStructure.section_id == (section_id or None),
            FeeStructure.deleted_at.is_(None),
        )
    ).all()
    for row in existing:
        row.deleted_at = now_utc()
        row.updated_by = current_user.id
    for item in fee_items:
        if not isinstance(item, dict):
            continue
        category_name = clean(item.get("category_name") or item.get("name") or item.get("category"))
        if not category_name:
            continue
        db.add(
            FeeStructure(
                school_id=current_user.school_id,
                academic_year_id=academic_year_id,
                grade_id=grade_id,
                section_id=section_id or None,
                category_name=category_name,
                frequency=clean(item.get("frequency"), "term"),
                amount=as_decimal(item.get("amount")),
                due_day=as_int(item.get("due_day"), 10),
                late_fine_per_day=as_decimal(item.get("late_fine_per_day")),
                created_by=current_user.id,
            )
        )


def parse_csv_text(csv_text: str) -> list[dict[str, str]]:
    reader = csv.DictReader(io.StringIO(csv_text))
    if not reader.fieldnames:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="CSV must include headers")
    return [
        {str(key or "").strip(): str(value or "").strip() for key, value in row.items()}
        for row in reader
        if any(str(value or "").strip() for value in row.values())
    ]


def paginated_rows(rows: list[Any], page: int, page_size: int) -> list[Any]:
    if page_size <= 0:
        return rows
    start = max(page - 1, 0) * page_size
    return rows[start : start + page_size]


def normalize_role(value: Any) -> str:
    text = clean(value, "teacher").lower().replace(" ", "_")
    if text in {"class_teacher", "teacher"}:
        return "teacher"
    if text in {"administrator", "admin"}:
        return "admin"
    if text in {"principal"}:
        return "principal"
    if text in {"parent", "guardian"}:
        return "parent"
    return "teacher"


def ensure_user_role(db: Session, user: User, role_name: str) -> None:
    role = db.scalar(select(Role).where(Role.school_id == user.school_id, Role.name == role_name))
    if role is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Role {role_name} is not configured")
    exists = db.scalar(select(UserRole).where(UserRole.user_id == user.id, UserRole.role_id == role.id))
    if exists is None:
        db.add(UserRole(user_id=user.id, role_id=role.id))


def visible_tasks(db: Session, current_user: CurrentUser) -> list[Task]:
    rows = db.scalars(
        select(Task).where(Task.school_id == current_user.school_id, Task.deleted_at.is_(None))
    ).all()
    return [row for row in rows if can_access_task(current_user, row)]


@router.get("/dashboard/{role}")
def dashboard(
    role: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    safe_role = role.strip().lower()
    tasks = visible_tasks(db, current_user)
    open_tasks = [task for task in tasks if task.status not in {"completed", "archived"}]
    if safe_role == "teacher":
        section_rows = [
            db.get(Section, section_id)
            for section_id in current_user.class_teacher_sections
        ]
        assigned_sections = [
            section_payload(db, section)
            for section in section_rows
            if section is not None
        ]
        assigned_student_count = len(
            db.scalars(
                select(Student.id).where(
                    Student.school_id == current_user.school_id,
                    Student.deleted_at.is_(None),
                    Student.current_section_id.in_(current_user.class_teacher_sections or ("",)),
                )
            ).all()
        )
        return success(
            {
                "role": "Teacher",
                "staff_id": current_user.linked_id or "",
                "assigned_classes": assigned_sections,
                "metrics": {
                    "assigned_classes": len(assigned_sections),
                    "assigned_students": assigned_student_count,
                    "homework_due": 0,
                    "homework_total": 0,
                    "open_tasks": len(open_tasks),
                    "unread_messages": 0,
                },
                "today_attendance": {"attendance_pct": 0, "marked": 0, "present": 0, "sessions": 0},
            }
        )
    if safe_role in {"parent", "guardian"}:
        return success(
            {
                "role": "Parent",
                "children": [],
                "metrics": {
                    "linked_children": 0,
                    "open_homework": 0,
                    "open_tasks": 0,
                    "pending_fee_balance": 0,
                    "pending_invoices": 0,
                    "unread_messages": 0,
                },
                "attendance": {"attendance_pct": 0, "marked": 0, "present": 0, "sessions": 0},
            }
        )
    total_students = len(
        db.scalars(
            select(Student.id).where(Student.school_id == current_user.school_id, Student.deleted_at.is_(None))
        ).all()
    )
    total_staff = len(
        db.scalars(
            select(Staff.id).where(Staff.school_id == current_user.school_id, Staff.deleted_at.is_(None))
        ).all()
    )
    total_classes = len(
        db.scalars(select(Section.id).where(Section.school_id == current_user.school_id)).all()
    )
    pending_approval_stmt = select(ApprovalRequest.id).where(
        ApprovalRequest.school_id == current_user.school_id,
        ApprovalRequest.deleted_at.is_(None),
        ApprovalRequest.status == "pending",
    )
    if current_user.role == "admin":
        pending_approval_stmt = pending_approval_stmt.where(ApprovalRequest.requester_user_id == current_user.id)
    pending_approvals = len(db.scalars(pending_approval_stmt).all())
    return success(
        {
            "role": safe_role.title(),
            "metrics": {
                "total_students": total_students,
                "total_staff": total_staff,
                "total_classes": total_classes,
                "pending_approvals": pending_approvals,
                "open_tasks": len(open_tasks),
            },
            "fees": {"collection_pct": 0, "total_paid": 0},
            "today_attendance": {"attendance_pct": 0, "marked": 0, "present": 0},
            "operational_gaps": {"critical": 0, "warning": 0, "items": []},
        }
    )


@router.get("/schools/current")
def current_school(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    school = db.get(School, current_user.school_id)
    if school is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="School not found")
    return success(school_payload(school))


@router.get("/schools")
def schools(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    rows = db.scalars(select(School).where(School.id == current_user.school_id)).all()
    return success([school_payload(row) for row in rows])


@router.patch("/schools/current")
def update_current_school(
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal_or_admin(current_user)
    school = db.get(School, current_user.school_id)
    if school is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="School not found")
    mapping = {
        "name": "name",
        "school_name": "name",
        "school_type": "school_type",
        "affiliation_board": "affiliation_board",
        "email": "email",
        "phone": "phone",
        "city": "city",
        "state": "state",
        "principal_name": "principal_name",
        "registration_number": "registration_number",
        "logo_url": "logo_url",
    }
    for source, target in mapping.items():
        if source in payload:
            value = clean(payload[source])
            if target == "name" and not value:
                continue
            setattr(school, target, value)
    school.updated_at = now_utc()
    db.commit()
    db.refresh(school)
    return success(school_payload(school), message="School updated")


@router.post("/schools/current/logo")
def update_current_school_logo(
    payload: dict[str, Any] | None = None,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal_or_admin(current_user)
    school = db.get(School, current_user.school_id)
    if school is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="School not found")
    logo_url = clean((payload or {}).get("logo_url"), school.logo_url or "")
    school.logo_url = logo_url
    school.updated_at = now_utc()
    db.commit()
    return success({"logo_url": school.logo_url or ""}, message="School logo updated")


@router.get("/announcements")
def announcements(current_user: CurrentUser = Depends(get_current_user)) -> dict[str, Any]:
    return success([])


@router.get("/notifications")
def notifications(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    rows = db.scalars(
        select(NotificationLog)
        .where(
            NotificationLog.school_id == current_user.school_id,
            NotificationLog.deleted_at.is_(None),
            or_(
                NotificationLog.recipient_user_id == current_user.id,
                NotificationLog.recipient_role == current_user.role,
            ),
        )
        .order_by(NotificationLog.created_at.desc())
    ).all()
    return success(
        [
            {
                "id": row.id,
                "notification_id": row.id,
                "title": row.title,
                "message": row.body,
                "body": row.body,
                "notification_type": row.reference_type,
                "reference_type": row.reference_type,
                "reference_id": row.reference_id,
                "is_read": False,
                "created_at": row.created_at.isoformat(),
            }
            for row in rows
        ]
    )


@router.get("/me/students")
def my_students(current_user: CurrentUser = Depends(get_current_user)) -> dict[str, Any]:
    return success([])


@router.get("/principal/classes")
def principal_classes(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal(current_user)
    rows = db.scalars(
        select(Section)
        .where(Section.school_id == current_user.school_id)
        .order_by(Section.name)
    ).all()
    classes = [class_hub_row(db, row) for row in rows]
    total_students = sum(as_int(row["total_students"]) for row in classes)
    total_capacity = sum(as_int(row["capacity"]) for row in classes)
    pending_issues = sum(as_int(row["pending_issues"]) for row in classes)
    return success(
        {
            "summary": {
                "total_classes": len(classes),
                "total_students": total_students,
                "total_capacity": total_capacity,
                "avg_attendance": 0,
                "pending_issues": pending_issues,
            },
            "classes": classes,
        }
    )


def apply_class_setup(
    db: Session,
    current_user: CurrentUser,
    payload: dict[str, Any],
    *,
    section_id: str = "",
) -> Section:
    grade = find_or_create_grade(
        db,
        current_user,
        grade_id=clean(payload.get("grade_id")),
        grade_name=clean(payload.get("grade_name")),
        grade_number=as_int(payload.get("grade_number"), 0) or None,
    )
    academic_year_id = clean(payload.get("academic_year_id"))
    if not academic_year_id:
        current_year = db.scalar(
            select(AcademicYear).where(AcademicYear.school_id == current_user.school_id, AcademicYear.is_current.is_(True))
        )
        academic_year_id = current_year.id if current_year else ""
    if not academic_year_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="academic_year_id is required")
    section_name = clean(payload.get("section_name"))
    if not section_name:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="section_name is required")
    room = find_or_create_room(
        db,
        current_user,
        room_number=clean(payload.get("room_number")),
        room_type=clean(payload.get("room_type"), "classroom"),
        room_capacity=as_int(payload.get("room_capacity") or payload.get("capacity"), 0),
    )
    class_teacher_id = clean(payload.get("class_teacher_id"))
    if class_teacher_id:
        teacher = db.get(Staff, class_teacher_id)
        if teacher is None or teacher.school_id != current_user.school_id or teacher.deleted_at is not None:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="class_teacher_id is invalid")
    section = db.get(Section, section_id) if section_id else None
    if section is not None and section.school_id != current_user.school_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Class section not found")
    if section is None:
        section = db.scalar(
            select(Section).where(
                Section.school_id == current_user.school_id,
                Section.grade_id == grade.id,
                Section.academic_year_id == academic_year_id,
                Section.name == section_name,
            )
        )
    if section is None:
        section = Section(
            school_id=current_user.school_id,
            name=section_name,
        )
        db.add(section)
        db.flush()
    section.name = section_name
    section.grade_id = grade.id
    section.academic_year_id = academic_year_id
    section.class_teacher_id = class_teacher_id or None
    section.room_id = room.id if room else None
    section.capacity = as_int(payload.get("capacity"), section.capacity or 40)
    for mapping in payload.get("subject_mappings") or []:
        if isinstance(mapping, dict):
            upsert_subject_mapping(
                db,
                current_user,
                academic_year_id=academic_year_id,
                grade_id=grade.id,
                section_id=section.id,
                mapping=mapping,
            )
    replace_fee_items(
        db,
        current_user,
        academic_year_id=academic_year_id,
        grade_id=grade.id,
        section_id=section.id,
        fee_items=list(payload.get("fee_items") or []),
    )
    return section


@router.post("/principal/classes")
def create_principal_class(
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal(current_user)
    row = apply_class_setup(db, current_user, payload)
    audit(db, current_user, module="class_hub", action="upsert", entity_type="section", entity_id=row.id)
    db.commit()
    db.refresh(row)
    return success(
        {
            "section": section_payload(db, row),
            "grade": grade_payload(db.get(Grade, row.grade_id)) if row.grade_id and db.get(Grade, row.grade_id) else {},
            "class": class_hub_row(db, row),
        },
        message="Class setup saved",
    )


@router.put("/principal/classes/{section_id}")
def update_principal_class(
    section_id: str,
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal(current_user)
    row = apply_class_setup(db, current_user, payload, section_id=section_id)
    audit(db, current_user, module="class_hub", action="update", entity_type="section", entity_id=row.id)
    db.commit()
    db.refresh(row)
    return success(
        {
            "section": section_payload(db, row),
            "grade": grade_payload(db.get(Grade, row.grade_id)) if row.grade_id and db.get(Grade, row.grade_id) else {},
            "class": class_hub_row(db, row),
        },
        message="Class setup updated",
    )


@router.delete("/principal/classes/{section_id}")
def delete_principal_class(
    section_id: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal(current_user)
    row = db.get(Section, section_id)
    if row is None or row.school_id != current_user.school_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Class section not found")
    row.name = f"{row.name} (archived)"
    audit(db, current_user, module="class_hub", action="archive", entity_type="section", entity_id=row.id)
    db.commit()
    return success({"id": row.id}, message="Class archived")


@router.post("/principal/classes/{section_id}/instructions")
def create_principal_class_instruction(
    section_id: str,
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal(current_user)
    row = db.get(Section, section_id)
    if row is None or row.school_id != current_user.school_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Class section not found")
    notification = NotificationLog(
        school_id=current_user.school_id,
        recipient_role="teacher",
        reference_type="class_instruction",
        reference_id=row.id,
        title=clean(payload.get("title"), "Class instruction"),
        body=clean(payload.get("message")),
        created_by=current_user.id,
    )
    db.add(notification)
    audit(db, current_user, module="class_hub", action="instruction", entity_type="section", entity_id=row.id)
    db.commit()
    db.refresh(notification)
    return success(
        {
            "id": notification.id,
            "section_id": row.id,
            "title": notification.title,
            "message": notification.body,
        },
        message="Class instruction saved",
    )


def class_csv_dry_run_payload(
    db: Session,
    current_user: CurrentUser,
    csv_text: str,
) -> dict[str, Any]:
    parsed = parse_csv_text(csv_text)
    rows: list[dict[str, Any]] = []
    errors: list[dict[str, Any]] = []
    warnings: list[dict[str, Any]] = []
    for index, row in enumerate(parsed, start=2):
        grade_name = clean(row.get("grade_name"))
        section_name = clean(row.get("section_name"))
        year_label = clean(row.get("year_label"))
        academic_year_id = clean(row.get("academic_year_id"))
        if not grade_name:
            errors.append({"row": index, "field": "grade_name", "message": "grade_name is required"})
        if not section_name:
            errors.append({"row": index, "field": "section_name", "message": "section_name is required"})
        if not academic_year_id and not year_label:
            errors.append({"row": index, "field": "academic_year_id", "message": "academic_year_id or year_label is required"})
        year = None
        if academic_year_id:
            year = db.get(AcademicYear, academic_year_id)
        elif year_label:
            year = db.scalar(select(AcademicYear).where(AcademicYear.school_id == current_user.school_id, AcademicYear.year_label == year_label))
        if (academic_year_id or year_label) and (year is None or year.school_id != current_user.school_id):
            errors.append({"row": index, "field": "academic_year_id", "message": "academic year was not found"})
        grade = None
        if grade_name:
            grade = db.scalar(select(Grade).where(Grade.school_id == current_user.school_id, Grade.grade_name == grade_name))
        existing_section = None
        if year is not None and grade is not None:
            existing_section = db.scalar(
                select(Section).where(
                    Section.school_id == current_user.school_id,
                    Section.grade_id == grade.id,
                    Section.academic_year_id == year.id,
                    Section.name == section_name,
                )
            )
        subject_count = len(split_semicolon(row.get("subject_names")))
        fee_count = len(split_semicolon(row.get("fee_categories")))
        if existing_section is not None:
            warnings.append({"row": index, "field": "section_name", "message": "class exists and will be updated"})
        rows.append(
            {
                "row_number": index,
                "mode": "update" if existing_section is not None else "create",
                "grade_name": grade_name,
                "section_name": section_name,
                "subject_count": subject_count,
                "fee_item_count": fee_count,
            }
        )
    valid_rows = max(len(rows) - len({error["row"] for error in errors}), 0)
    create_rows = len([row for row in rows if row["mode"] == "create"])
    update_rows = len([row for row in rows if row["mode"] == "update"])
    return {
        "can_import": bool(rows) and not errors,
        "summary": {
            "total_rows": len(rows),
            "valid_rows": valid_rows,
            "invalid_rows": len({error["row"] for error in errors}),
            "classes_to_create": create_rows,
            "classes_to_update": update_rows,
        },
        "rows": rows,
        "errors": errors,
        "warnings": warnings,
    }


@router.post("/principal/classes/import/dry-run")
def dry_run_principal_class_import(
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal(current_user)
    return success(class_csv_dry_run_payload(db, current_user, clean(payload.get("csv_text"))))


@router.post("/principal/classes/import")
def import_principal_classes(
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal(current_user)
    csv_text = clean(payload.get("csv_text"))
    dry_run = class_csv_dry_run_payload(db, current_user, csv_text)
    if not dry_run["can_import"]:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="CSV contains validation errors")
    created = 0
    updated = 0
    imported_rows = parse_csv_text(csv_text)
    try:
        for row in imported_rows:
            year = None
            academic_year_id = clean(row.get("academic_year_id"))
            if academic_year_id:
                year = db.get(AcademicYear, academic_year_id)
            if year is None:
                year = db.scalar(
                    select(AcademicYear).where(
                        AcademicYear.school_id == current_user.school_id,
                        AcademicYear.year_label == clean(row.get("year_label")),
                    )
                )
            if year is None:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="academic year was not found")
            grade_name = clean(row.get("grade_name"))
            grade_number = as_int(row.get("grade_number"), 0) or None
            grade = db.scalar(select(Grade).where(Grade.school_id == current_user.school_id, Grade.grade_name == grade_name))
            before_exists = False
            if grade is not None:
                before_exists = db.scalar(
                    select(Section.id).where(
                        Section.school_id == current_user.school_id,
                        Section.grade_id == grade.id,
                        Section.academic_year_id == year.id,
                        Section.name == clean(row.get("section_name")),
                    )
                ) is not None
            subject_names = split_semicolon(row.get("subject_names"))
            subject_codes = split_semicolon(row.get("subject_codes"))
            subject_types = split_semicolon(row.get("subject_types"))
            teacher_codes = split_semicolon(row.get("subject_teacher_staff_codes"))
            periods = split_semicolon(row.get("periods_per_week"))
            max_marks = split_semicolon(row.get("max_marks"))
            pass_marks = split_semicolon(row.get("pass_marks"))
            mappings = [
                {
                    "subject_name": subject_name,
                    "subject_code": at(subject_codes, idx),
                    "subject_type": at(subject_types, idx, "core"),
                    "teacher_staff_code": at(teacher_codes, idx),
                    "periods_per_week": as_int(at(periods, idx), 5),
                    "max_marks": as_int(at(max_marks, idx), 100),
                    "pass_marks": as_int(at(pass_marks, idx), 35),
                }
                for idx, subject_name in enumerate(subject_names)
            ]
            fee_categories = split_semicolon(row.get("fee_categories"))
            fee_amounts = split_semicolon(row.get("fee_amounts"))
            fee_frequencies = split_semicolon(row.get("fee_frequencies"))
            fee_due_days = split_semicolon(row.get("fee_due_days"))
            fee_late_fines = split_semicolon(row.get("fee_late_fines"))
            fee_items = [
                {
                    "category_name": category,
                    "amount": at(fee_amounts, idx, "0"),
                    "frequency": at(fee_frequencies, idx, "term"),
                    "due_day": as_int(at(fee_due_days, idx), 10),
                    "late_fine_per_day": at(fee_late_fines, idx, "0"),
                }
                for idx, category in enumerate(fee_categories)
            ]
            apply_class_setup(
                db,
                current_user,
                {
                    "academic_year_id": year.id,
                    "grade_name": grade_name,
                    "grade_number": grade_number,
                    "section_name": clean(row.get("section_name")),
                    "capacity": as_int(row.get("capacity"), 40),
                    "class_teacher_id": clean(row.get("class_teacher_id")) or staff_id_from_payload(
                        db,
                        current_user,
                        {"teacher_staff_code": clean(row.get("class_teacher_staff_code")), "teacher_email": clean(row.get("class_teacher_email"))},
                    ),
                    "room_number": clean(row.get("room_number")),
                    "room_type": clean(row.get("room_type"), "classroom"),
                    "room_capacity": as_int(row.get("room_capacity"), 0),
                    "subject_mappings": mappings,
                    "fee_items": fee_items,
                },
            )
            if before_exists:
                updated += 1
            else:
                created += 1
        audit(db, current_user, module="class_hub", action="csv_import", entity_type="section", entity_id=current_user.school_id)
        db.commit()
    except Exception:
        db.rollback()
        raise
    return success(
        {
            "summary": {
                "created_classes": created,
                "updated_classes": updated,
                "valid_rows": created + updated,
            },
            "errors": [],
            "warnings": dry_run["warnings"],
        },
        message="Class Hub CSV imported",
    )


@router.get("/leave/types")
def leave_types(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    if current_user.role in {"parent", "guardian"}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Staff leave is internal only")
    rows = db.scalars(
        select(LeaveType)
        .where(LeaveType.school_id == current_user.school_id, LeaveType.deleted_at.is_(None))
        .order_by(LeaveType.leave_name)
    ).all()
    return success([leave_type_payload(row) for row in rows])


@router.get("/leave/balances")
def leave_balances(
    staff_id: str | None = None,
    academic_year_id: str | None = None,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    if current_user.role in {"parent", "guardian"}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Staff leave is internal only")
    stmt = select(LeaveBalance).where(LeaveBalance.school_id == current_user.school_id, LeaveBalance.deleted_at.is_(None))
    if current_user.role == "teacher":
        if not current_user.linked_id:
            return success([])
        stmt = stmt.where(LeaveBalance.staff_id == current_user.linked_id)
    elif staff_id:
        stmt = stmt.where(LeaveBalance.staff_id == staff_id)
    if academic_year_id:
        stmt = stmt.where(LeaveBalance.academic_year_id == academic_year_id)
    rows = db.scalars(stmt).all()
    return success([leave_balance_payload(row) for row in rows])


@router.get("/leave/applications")
def leave_applications(
    staff_id: str | None = None,
    status_filter: str | None = None,
    status_value: str | None = None,
    status_query: str | None = None,
    leave_status: str | None = Query(default=None, alias="status"),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    if current_user.role in {"parent", "guardian"}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Staff leave is internal only")
    stmt = select(LeaveApplication).where(
        LeaveApplication.school_id == current_user.school_id,
        LeaveApplication.deleted_at.is_(None),
    )
    if current_user.role == "teacher":
        if not current_user.linked_id:
            return success([])
        stmt = stmt.where(LeaveApplication.staff_id == current_user.linked_id)
    elif staff_id:
        stmt = stmt.where(LeaveApplication.staff_id == staff_id)
    wanted_status = leave_status or status_filter or status_value or status_query
    if wanted_status:
        stmt = stmt.where(LeaveApplication.status == wanted_status.strip().lower())
    rows = db.scalars(stmt.order_by(LeaveApplication.created_at.desc())).all()
    return success([leave_application_payload(row) for row in rows])


@router.post("/leave/applications")
def create_leave_application(
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    if current_user.role in {"parent", "guardian"}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Staff leave is internal only")
    staff_id = clean(payload.get("staff_id")) or (current_user.linked_id if current_user.role == "teacher" else "")
    leave_type_id = clean(payload.get("leave_type_id"))
    if current_user.role == "teacher" and staff_id != current_user.linked_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Teachers can submit only their own leave")
    staff = db.get(Staff, staff_id)
    leave_type = db.get(LeaveType, leave_type_id)
    if staff is None or staff.school_id != current_user.school_id or staff.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="staff access denied")
    if leave_type is None or leave_type.school_id != current_user.school_id or leave_type.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="leave type access denied")
    from_date = parse_date(payload.get("from_date"), field_name="from_date")
    to_date = parse_date(payload.get("to_date"), field_name="to_date")
    if from_date is None or to_date is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="from_date and to_date are required")
    half_day = bool(payload.get("half_day") or False)
    row = LeaveApplication(
        school_id=current_user.school_id,
        staff_id=staff_id,
        leave_type_id=leave_type_id,
        from_date=from_date,
        to_date=to_date,
        half_day=half_day,
        total_days=total_leave_days(from_date, to_date, half_day=half_day),
        reason=clean(payload.get("reason")),
        status="pending",
        applied_at=now_utc(),
        created_by=current_user.id,
    )
    if not row.reason:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="reason is required")
    db.add(row)
    db.flush()
    audit(db, current_user, module="leave", action="submit", entity_type="leave_application", entity_id=row.id)
    notify(
        db,
        current_user,
        reference_type="leave",
        reference_id=row.id,
        title="Teacher leave approval pending",
        body="A teacher leave request is waiting for Principal approval.",
        recipient_role="principal",
    )
    db.commit()
    db.refresh(row)
    return success(leave_application_payload(row), message="Leave application submitted")


@router.put("/leave/applications/{application_id}/approve")
def decide_leave_application(
    application_id: str,
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    if current_user.role != "principal":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Principal approval required")
    row = db.get(LeaveApplication, application_id)
    if row is None or row.school_id != current_user.school_id or row.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Leave application not found")
    if row.status != "pending":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Leave application has already been actioned")
    decision = clean(payload.get("status"), "approved").lower()
    if decision not in {"approved", "rejected"}:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="status must be approved or rejected")
    reason = clean(payload.get("reason") or payload.get("rejection_reason"))
    if decision == "rejected" and not reason:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="reason is required when rejecting leave")
    row.status = decision
    row.rejection_reason = reason or None
    row.actioned_at = now_utc()
    row.actioned_by = current_user.id
    row.updated_by = current_user.id
    if decision == "approved":
        balance = db.scalar(
            select(LeaveBalance).where(
                LeaveBalance.school_id == current_user.school_id,
                LeaveBalance.staff_id == row.staff_id,
                LeaveBalance.leave_type_id == row.leave_type_id,
                LeaveBalance.deleted_at.is_(None),
            )
        )
        if balance is not None:
            balance.used_days = Decimal(str(number(balance.used_days) + number(row.total_days)))
            balance.remaining_days = Decimal(str(max(number(balance.remaining_days) - number(row.total_days), 0)))
            balance.updated_by = current_user.id
    staff_user = user_for_staff(db, current_user.school_id, row.staff_id)
    audit(db, current_user, module="leave", action=decision, entity_type="leave_application", entity_id=row.id)
    notify(
        db,
        current_user,
        reference_type="leave",
        reference_id=row.id,
        title=f"Leave {decision}",
        body=f"Your leave request was {decision}.",
        recipient_user_id=staff_user.id if staff_user else None,
    )
    db.commit()
    db.refresh(row)
    return success(leave_application_payload(row), message="Leave application updated")


@router.get("/student-leave/applications")
def student_leave_applications(
    student_id: str | None = None,
    status_filter: str | None = None,
    leave_status: str | None = Query(default=None, alias="status"),
    page: int = 1,
    page_size: int = 100,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    stmt = select(StudentLeaveApplication).where(
        StudentLeaveApplication.school_id == current_user.school_id,
        StudentLeaveApplication.deleted_at.is_(None),
    )
    if student_id:
        stmt = stmt.where(StudentLeaveApplication.student_id == student_id)
    if current_user.role in {"parent", "guardian"}:
        stmt = stmt.where(StudentLeaveApplication.parent_user_id == current_user.id)
    elif current_user.role == "teacher":
        section_ids = current_user.class_teacher_sections
        if not section_ids:
            return page_response([], page=page, page_size=page_size)
        stmt = stmt.join(Student, Student.id == StudentLeaveApplication.student_id).where(
            Student.current_section_id.in_(section_ids),
            Student.school_id == current_user.school_id,
        )
    elif current_user.role not in {"principal", "admin"}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Student leave access denied")
    wanted_status = leave_status or status_filter
    if wanted_status:
        stmt = stmt.where(StudentLeaveApplication.status == wanted_status.strip().lower())
    rows = list(db.scalars(stmt.order_by(StudentLeaveApplication.created_at.desc())).all())
    data = [student_leave_payload(row) for row in paginated_rows(rows, page, page_size)]
    return success(
        data,
        page=page,
        page_size=page_size,
        total=len(rows),
        total_pages=max(1, ceil(len(rows) / page_size)) if page_size > 0 else 1,
    )


@router.post("/student-leave/applications")
def create_student_leave_application(
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    if current_user.role not in {"parent", "guardian"}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only parents can submit student leave applications")
    student_id = clean(payload.get("student_id"))
    student = db.get(Student, student_id)
    if student is None or student.school_id != current_user.school_id or student.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="student access denied")
    from_date = parse_date(payload.get("from_date"), field_name="from_date")
    to_date = parse_date(payload.get("to_date"), field_name="to_date")
    if from_date is None or to_date is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="from_date and to_date are required")
    leave_type = clean(payload.get("leave_type"))
    reason = clean(payload.get("reason"))
    if not leave_type or not reason:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="student_id, leave_type, and reason are required")
    half_day = bool(payload.get("half_day") or False)
    row = StudentLeaveApplication(
        school_id=current_user.school_id,
        student_id=student_id,
        parent_user_id=current_user.id,
        leave_type=leave_type,
        from_date=from_date,
        to_date=to_date,
        half_day=half_day,
        total_days=total_leave_days(from_date, to_date, half_day=half_day),
        reason=reason,
        status="pending",
        applied_at=now_utc(),
        created_by=current_user.id,
    )
    db.add(row)
    db.flush()
    audit(db, current_user, module="student_leave", action="submit", entity_type="student_leave_application", entity_id=row.id)
    notify(
        db,
        current_user,
        reference_type="leave",
        reference_id=row.id,
        title="Student leave approval pending",
        body="A parent submitted a student leave request.",
        recipient_role="principal",
    )
    db.commit()
    db.refresh(row)
    return success(student_leave_payload(row), message="Student leave application submitted")


@router.put("/student-leave/applications/{application_id}/decision")
def decide_student_leave_application(
    application_id: str,
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    if current_user.role != "principal":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Principal approval required")
    row = db.get(StudentLeaveApplication, application_id)
    if row is None or row.school_id != current_user.school_id or row.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student leave application not found")
    if row.status != "pending":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Student leave application has already been actioned")
    decision = clean(payload.get("status"), "approved").lower()
    if decision not in {"approved", "rejected"}:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="status must be approved or rejected")
    reason = clean(payload.get("rejection_reason") or payload.get("reason"))
    if decision == "rejected" and not reason:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="reason is required when rejecting student leave")
    row.status = decision
    row.rejection_reason = reason or None
    row.actioned_at = now_utc()
    row.actioned_by = current_user.id
    row.updated_by = current_user.id
    audit(db, current_user, module="student_leave", action=decision, entity_type="student_leave_application", entity_id=row.id)
    notify(
        db,
        current_user,
        reference_type="leave",
        reference_id=row.id,
        title=f"Student leave {decision}",
        body=f"Your student leave request was {decision}.",
        recipient_user_id=row.parent_user_id,
    )
    db.commit()
    db.refresh(row)
    return success(student_leave_payload(row), message="Student leave application updated")


@router.get("/students")
def students(
    page: int = 1,
    page_size: int = 20,
    section_id: str | None = None,
    status_filter: str | None = None,
    status: str | None = None,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    stmt = select(Student).where(Student.school_id == current_user.school_id, Student.deleted_at.is_(None))

    # RBAC: teachers see only students in their class_teacher_sections
    if current_user.role == "teacher":
        if not current_user.class_teacher_sections:
            return success([], page=page, page_size=page_size, total=0, total_pages=1)
        stmt = stmt.where(Student.current_section_id.in_(current_user.class_teacher_sections))

    # RBAC: parents see only students they have linked leave applications for
    if current_user.role in {"parent", "guardian"}:
        linked_student_ids = db.scalars(
            select(StudentLeaveApplication.student_id).where(
                StudentLeaveApplication.school_id == current_user.school_id,
                StudentLeaveApplication.parent_user_id == current_user.id,
                StudentLeaveApplication.deleted_at.is_(None),
            )
        ).all()
        if not linked_student_ids:
            return success([], page=page, page_size=page_size, total=0, total_pages=1)
        stmt = stmt.where(Student.id.in_(linked_student_ids))

    if section_id:
        stmt = stmt.where(Student.current_section_id == section_id)
    wanted_status = status or status_filter
    if wanted_status:
        stmt = stmt.where(Student.status == wanted_status)
    rows = db.scalars(stmt.order_by(Student.first_name, Student.last_name)).all()
    data = [student_payload(db, row) for row in paginated_rows(list(rows), page, page_size)]
    return success(
        data,
        page=page,
        page_size=page_size,
        total=len(rows),
        total_pages=max(1, ceil(len(rows) / page_size)) if page_size > 0 else 1,
    )


@router.get("/students/{student_id}/enrollments")
def student_enrollments(
    student_id: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    row = db.get(Student, student_id)
    if row is None or row.school_id != current_user.school_id or row.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")
    if not row.current_section_id:
        return success([])
    section = db.get(Section, row.current_section_id)
    return success(
        [
            {
                "id": f"enrollment-{row.id}-{row.current_section_id}",
                "student_id": row.id,
                "section_id": row.current_section_id,
                "status": row.status,
                "section": section_payload(db, section) if section is not None else {},
            }
        ]
    )


@router.get("/students/{student_id}")
def student_detail(
    student_id: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    row = db.get(Student, student_id)
    if row is None or row.school_id != current_user.school_id or row.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")
    return success(student_payload(db, row))


@router.post("/students")
def create_student(
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal_or_admin(current_user)
    row = Student(
        school_id=current_user.school_id,
        student_code=clean(payload.get("student_code")) or f"STU-{uuid_str()[:8].upper()}",
        admission_number=clean(payload.get("admission_number")) or f"ADM-{uuid_str()[:8].upper()}",
        first_name=clean(payload.get("first_name")),
        last_name=clean(payload.get("last_name")),
        date_of_birth=parse_date(payload.get("date_of_birth"), field_name="date_of_birth"),
        admission_date=parse_date(payload.get("admission_date"), field_name="admission_date"),
        gender=clean(payload.get("gender"), "unspecified"),
        current_section_id=clean(payload.get("current_section_id")) or None,
        status=clean(payload.get("status"), "active"),
        created_by=current_user.id,
    )
    if not row.first_name:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="first_name is required")
    db.add(row)
    db.commit()
    db.refresh(row)
    return success(student_payload(db, row), message="Student created")


@router.put("/students/{student_id}")
def update_student(
    student_id: str,
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal_or_admin(current_user)
    row = db.get(Student, student_id)
    if row is None or row.school_id != current_user.school_id or row.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")
    for field in ["student_code", "admission_number", "first_name", "last_name", "gender", "status"]:
        if field in payload:
            setattr(row, field, clean(payload[field], getattr(row, field)))
    if "date_of_birth" in payload:
        row.date_of_birth = parse_date(payload.get("date_of_birth"), field_name="date_of_birth")
    if "admission_date" in payload:
        row.admission_date = parse_date(payload.get("admission_date"), field_name="admission_date")
    if "current_section_id" in payload:
        row.current_section_id = clean(payload.get("current_section_id")) or None
    row.updated_by = current_user.id
    db.commit()
    db.refresh(row)
    return success(student_payload(db, row), message="Student updated")


@router.delete("/students/{student_id}")
def delete_student(
    student_id: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal_or_admin(current_user)
    row = db.get(Student, student_id)
    if row is None or row.school_id != current_user.school_id or row.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found")
    row.deleted_at = now_utc()
    row.is_active = False
    row.status = "archived"
    row.updated_by = current_user.id
    db.commit()
    return success({"id": row.id}, message="Student deleted")


@router.get("/staff")
def staff(
    page: int = 1,
    page_size: int = 20,
    status_filter: str | None = None,
    status: str | None = None,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    stmt = select(Staff).where(Staff.school_id == current_user.school_id, Staff.deleted_at.is_(None))
    wanted_status = status or status_filter
    if wanted_status:
        stmt = stmt.where(Staff.status == wanted_status)
    rows = db.scalars(stmt.order_by(Staff.first_name, Staff.last_name)).all()
    data = [staff_payload(row) for row in paginated_rows(list(rows), page, page_size)]
    return success(
        data,
        page=page,
        page_size=page_size,
        total=len(rows),
        total_pages=max(1, ceil(len(rows) / page_size)) if page_size > 0 else 1,
    )


@router.get("/staff/{staff_id}")
def staff_detail(
    staff_id: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    row = db.get(Staff, staff_id)
    if row is None or row.school_id != current_user.school_id or row.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Staff not found")
    return success(staff_payload(row))


@router.post("/staff")
def create_staff(
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal_or_admin(current_user)
    row = Staff(
        school_id=current_user.school_id,
        staff_code=clean(payload.get("staff_code")) or f"STF-{uuid_str()[:8].upper()}",
        first_name=clean(payload.get("first_name")),
        last_name=clean(payload.get("last_name")),
        email=clean(payload.get("email")),
        phone=clean(payload.get("phone")),
        designation=clean(payload.get("designation")),
        employment_type=clean(payload.get("employment_type"), "full_time"),
        date_of_birth=parse_date(payload.get("date_of_birth"), field_name="date_of_birth"),
        gender=clean(payload.get("gender"), "unspecified"),
        join_date=parse_date(payload.get("join_date"), field_name="join_date"),
        status="active",
        created_by=current_user.id,
    )
    if not row.first_name:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="first_name is required")
    db.add(row)
    db.flush()
    username = clean(payload.get("username"))
    password = clean(payload.get("password"))
    if username and password:
        if db.scalar(select(User).where(User.username == username)) is not None:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Username already exists")
        account_role = normalize_role(payload.get("account_role"))
        user = User(
            school_id=current_user.school_id,
            username=username,
            full_name=f"{row.first_name} {row.last_name}".strip(),
            role=account_role,
            linked_type="staff",
            linked_id=row.id,
            password_hash=hash_password(password),
        )
        db.add(user)
        db.flush()
        ensure_user_role(db, user, account_role)
    db.commit()
    db.refresh(row)
    return success(staff_payload(row), message="Staff created")


@router.put("/staff/{staff_id}")
def update_staff(
    staff_id: str,
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal_or_admin(current_user)
    row = db.get(Staff, staff_id)
    if row is None or row.school_id != current_user.school_id or row.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Staff not found")
    for field in ["staff_code", "first_name", "last_name", "email", "phone", "designation", "employment_type", "gender"]:
        if field in payload:
            setattr(row, field, clean(payload[field], getattr(row, field)))
    if "date_of_birth" in payload:
        row.date_of_birth = parse_date(payload.get("date_of_birth"), field_name="date_of_birth")
    if "join_date" in payload:
        row.join_date = parse_date(payload.get("join_date"), field_name="join_date")
    row.updated_by = current_user.id
    linked_user = db.scalar(select(User).where(User.linked_type == "staff", User.linked_id == row.id))
    if linked_user is not None:
        linked_user.full_name = f"{row.first_name} {row.last_name}".strip()
        if clean(payload.get("password")):
            linked_user.password_hash = hash_password(clean(payload.get("password")))
    db.commit()
    db.refresh(row)
    return success(staff_payload(row), message="Staff updated")


@router.delete("/staff/{staff_id}")
def delete_staff(
    staff_id: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal_or_admin(current_user)
    row = db.get(Staff, staff_id)
    if row is None or row.school_id != current_user.school_id or row.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Staff not found")
    row.deleted_at = now_utc()
    row.is_active = False
    row.status = "inactive"
    row.updated_by = current_user.id
    linked_user = db.scalar(select(User).where(User.linked_type == "staff", User.linked_id == row.id))
    if linked_user is not None:
        linked_user.is_active = False
    db.commit()
    return success({"id": row.id}, message="Staff deleted")


@router.get("/academic-years")
def academic_years(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    rows = db.scalars(
        select(AcademicYear)
        .where(AcademicYear.school_id == current_user.school_id, AcademicYear.deleted_at.is_(None))
        .order_by(AcademicYear.start_date.desc())
    ).all()
    return success([academic_year_payload(row) for row in rows])


@router.post("/academic-years")
def create_academic_year(
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal_or_admin(current_user)
    is_current = bool(payload.get("is_current", False))
    if is_current:
        for row in db.scalars(select(AcademicYear).where(AcademicYear.school_id == current_user.school_id)).all():
            row.is_current = False
            if row.status == "active":
                row.status = "completed"
    row = AcademicYear(
        school_id=current_user.school_id,
        year_label=clean(payload.get("year_label")),
        start_date=parse_date(payload.get("start_date"), field_name="start_date"),
        end_date=parse_date(payload.get("end_date"), field_name="end_date"),
        is_current=is_current,
        status=clean(payload.get("status"), "active" if is_current else "upcoming"),
        created_by=current_user.id,
    )
    if not row.year_label:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="year_label is required")
    db.add(row)
    db.commit()
    db.refresh(row)
    return success(academic_year_payload(row), message="Academic year created")


@router.put("/academic-years/{academic_year_id}")
def update_academic_year(
    academic_year_id: str,
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal_or_admin(current_user)
    row = db.get(AcademicYear, academic_year_id)
    if row is None or row.school_id != current_user.school_id or row.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Academic year not found")
    if bool(payload.get("is_current", row.is_current)):
        for other in db.scalars(select(AcademicYear).where(AcademicYear.school_id == current_user.school_id)).all():
            if other.id != row.id:
                other.is_current = False
    for field in ["year_label", "status"]:
        if field in payload:
            setattr(row, field, clean(payload[field], getattr(row, field)))
    if "start_date" in payload:
        row.start_date = parse_date(payload.get("start_date"), field_name="start_date")
    if "end_date" in payload:
        row.end_date = parse_date(payload.get("end_date"), field_name="end_date")
    if "is_current" in payload:
        row.is_current = bool(payload["is_current"])
    row.updated_by = current_user.id
    db.commit()
    db.refresh(row)
    return success(academic_year_payload(row), message="Academic year updated")


@router.get("/academic-years/{academic_year_id}/terms")
def academic_year_terms(
    academic_year_id: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    year = db.get(AcademicYear, academic_year_id)
    if year is None or year.school_id != current_user.school_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Academic year not found")
    rows = db.scalars(
        select(AcademicTerm)
        .where(AcademicTerm.school_id == current_user.school_id, AcademicTerm.academic_year_id == academic_year_id)
        .order_by(AcademicTerm.sort_order)
    ).all()
    return success([term_payload(row) for row in rows])


@router.get("/grades")
def grades(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    rows = db.scalars(
        select(Grade)
        .where(Grade.school_id == current_user.school_id, Grade.deleted_at.is_(None))
        .order_by(Grade.grade_number)
    ).all()
    return success([grade_payload(row) for row in rows])


@router.get("/sections")
def sections(
    grade_id: str | None = None,
    academic_year_id: str | None = None,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    stmt = select(Section).where(
        Section.school_id == current_user.school_id,
        or_(
            current_user.is_principal,
            current_user.role == "admin",
            Section.id.in_(current_user.class_teacher_sections or ("",)),
        ),
    )
    if grade_id:
        stmt = stmt.where(Section.grade_id == grade_id)
    if academic_year_id:
        stmt = stmt.where(Section.academic_year_id == academic_year_id)
    rows = db.scalars(stmt.order_by(Section.name)).all()
    return success([section_payload(db, row) for row in rows])


@router.get("/subjects")
def subjects(
    department_id: str | None = None,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    stmt = select(Subject).where(Subject.school_id == current_user.school_id, Subject.deleted_at.is_(None))
    if department_id:
        stmt = stmt.where(Subject.department_id == department_id)
    rows = db.scalars(stmt.order_by(Subject.subject_name)).all()
    return success([subject_payload(row) for row in rows])


@router.post("/subjects")
def create_subject(
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal(current_user)
    row = find_or_create_subject(
        db,
        current_user,
        subject_name=clean(payload.get("subject_name") or payload.get("name")),
        subject_code=clean(payload.get("subject_code") or payload.get("code")),
        subject_type=clean(payload.get("subject_type"), "core"),
        subject_color=clean(payload.get("subject_color"), "#2563EB"),
    )
    row.department_id = clean(payload.get("department_id")) or row.department_id
    row.updated_by = current_user.id
    audit(db, current_user, module="subjects", action="upsert", entity_type="subject", entity_id=row.id)
    db.commit()
    db.refresh(row)
    return success(subject_payload(row), message="Subject saved")


@router.get("/grade-subjects")
def grade_subjects(
    grade_id: str | None = None,
    academic_year_id: str | None = None,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    stmt = select(GradeSubject).where(
        GradeSubject.school_id == current_user.school_id,
        GradeSubject.deleted_at.is_(None),
    )
    if grade_id:
        stmt = stmt.where(GradeSubject.grade_id == grade_id)
    if academic_year_id:
        stmt = stmt.where(GradeSubject.academic_year_id == academic_year_id)
    rows = db.scalars(stmt.order_by(GradeSubject.created_at.desc())).all()
    return success([grade_subject_payload(row) for row in rows])


@router.get("/staff-subjects")
def staff_subjects(
    grade_id: str | None = None,
    section_id: str | None = None,
    academic_year_id: str | None = None,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    stmt = select(StaffSubject).where(
        StaffSubject.school_id == current_user.school_id,
        StaffSubject.deleted_at.is_(None),
    )
    if grade_id:
        stmt = stmt.where(StaffSubject.grade_id == grade_id)
    if section_id:
        stmt = stmt.where(StaffSubject.section_id == section_id)
    if academic_year_id:
        stmt = stmt.where(StaffSubject.academic_year_id == academic_year_id)
    rows = db.scalars(stmt.order_by(StaffSubject.created_at.desc())).all()
    return success([staff_subject_payload(row) for row in rows])


@router.post("/principal/subjects/{subject_id}/mappings")
def save_principal_subject_mapping(
    subject_id: str,
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal(current_user)
    academic_year_id = clean(payload.get("academic_year_id"))
    grade_id = clean(payload.get("grade_id"))
    if not academic_year_id or not grade_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="academic_year_id and grade_id are required")
    subject = db.get(Subject, subject_id)
    if subject is None or subject.school_id != current_user.school_id or subject.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Subject not found")
    upsert_subject_mapping(
        db,
        current_user,
        academic_year_id=academic_year_id,
        grade_id=grade_id,
        section_id=clean(payload.get("section_id")),
        mapping={
            **payload,
            "subject_id": subject_id,
        },
    )
    audit(db, current_user, module="subjects", action="mapping", entity_type="subject", entity_id=subject_id)
    audit(db, current_user, module="class_hub", action="subject_mapping", entity_type="subject", entity_id=subject_id)
    db.commit()
    grade_row = db.scalar(
        select(GradeSubject).where(
            GradeSubject.school_id == current_user.school_id,
            GradeSubject.academic_year_id == academic_year_id,
            GradeSubject.grade_id == grade_id,
            GradeSubject.subject_id == subject_id,
            GradeSubject.deleted_at.is_(None),
        )
    )
    staff_row = db.scalar(
        select(StaffSubject).where(
            StaffSubject.school_id == current_user.school_id,
            StaffSubject.academic_year_id == academic_year_id,
            StaffSubject.grade_id == grade_id,
            StaffSubject.subject_id == subject_id,
            StaffSubject.section_id == (clean(payload.get("section_id")) or None),
            StaffSubject.deleted_at.is_(None),
        )
    )
    return success(
        {
            "grade_subject": grade_subject_payload(grade_row) if grade_row is not None else {},
            "staff_subject": staff_subject_payload(staff_row) if staff_row is not None else {},
        },
        message="Subject mapping saved",
    )


@router.get("/rooms")
def rooms(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    rows = db.scalars(
        select(Room)
        .where(Room.school_id == current_user.school_id, Room.deleted_at.is_(None))
        .order_by(Room.room_number)
    ).all()
    return success([room_payload(row) for row in rows])


@router.post("/rooms")
def create_room(
    payload: dict[str, Any],
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal_or_admin(current_user)
    row = Room(
        school_id=current_user.school_id,
        room_number=clean(payload.get("room_number")),
        room_type=clean(payload.get("room_type"), "classroom"),
        capacity=int(payload.get("capacity") or 0),
        block=clean(payload.get("block")),
        floor=int(payload.get("floor") or 0),
        created_by=current_user.id,
    )
    if not row.room_number:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="room_number is required")
    db.add(row)
    db.commit()
    db.refresh(row)
    return success(room_payload(row), message="Room created")


@router.get("/fees/structures")
def fee_structures(
    academic_year_id: str | None = None,
    grade_id: str | None = None,
    section_id: str | None = None,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    stmt = select(FeeStructure).where(
        FeeStructure.school_id == current_user.school_id,
        FeeStructure.deleted_at.is_(None),
    )
    if academic_year_id:
        stmt = stmt.where(FeeStructure.academic_year_id == academic_year_id)
    if grade_id:
        stmt = stmt.where(FeeStructure.grade_id == grade_id)
    if section_id:
        stmt = stmt.where(FeeStructure.section_id == section_id)
    rows = db.scalars(stmt.order_by(FeeStructure.category_name)).all()
    return success([fee_structure_payload(row) for row in rows])


@router.get("/fees/invoices")
def fee_invoices(page: int = 1, page_size: int = 100, current_user: CurrentUser = Depends(get_current_user)) -> dict[str, Any]:
    return page_response([], page=page, page_size=page_size)



