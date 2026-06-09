from __future__ import annotations

from datetime import date
from decimal import Decimal
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import and_, select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import utcnow
from app.dependencies.auth import CurrentUser, get_current_user, require_principal_or_admin
from app.api.v1 import app_records
from app.models.catalog import GradeSubject, Student
from app.models.exam import Exam, ExamMark
from app.models.goal_task import AuditLog
from app.models.guardian import Guardian

router = APIRouter(prefix="/api/v1", tags=["examinations"])


# ---- Pydantic Schemas ----

class ExamCreate(BaseModel):
    academic_year_id: str
    term_id: str | None = None
    exam_name: str
    exam_date: date
    description: str = ""
    weight: float = 1.0
    is_practical: bool = False
    status: str = "scheduled"


class ExamUpdate(BaseModel):
    term_id: str | None = None
    exam_name: str | None = None
    exam_date: date | None = None
    description: str | None = None
    weight: float | None = None
    is_practical: bool | None = None
    status: str | None = None


class ExamMarkCreateUpdate(BaseModel):
    exam_id: str
    student_id: str
    grade_subject_id: str
    marks_obtained: float


# ---- Helpers ----

def exam_payload(e: Exam) -> dict[str, Any]:
    return {
        "id": e.id,
        "academic_year_id": e.academic_year_id,
        "term_id": e.term_id,
        "exam_name": e.exam_name,
        "exam_date": e.exam_date.isoformat() if e.exam_date else None,
        "description": e.description,
        "weight": float(e.weight),
        "is_practical": e.is_practical,
        "status": e.status,
        "is_active": e.is_active,
        "created_at": e.created_at.isoformat() if e.created_at else None,
        "updated_at": e.updated_at.isoformat() if e.updated_at else None,
    }


def exam_mark_payload(em: ExamMark, grade_subject: GradeSubject | None = None) -> dict[str, Any]:
    result = {
        "id": em.id,
        "exam_id": em.exam_id,
        "student_id": em.student_id,
        "grade_subject_id": em.grade_subject_id,
        "marks_obtained": float(em.marks_obtained),
        "is_active": em.is_active,
        "created_at": em.created_at.isoformat() if em.created_at else None,
        "updated_at": em.updated_at.isoformat() if em.updated_at else None,
    }
    if grade_subject:
        max_marks = float(grade_subject.max_marks)
        pass_marks = float(grade_subject.pass_marks)
        percentage = (float(em.marks_obtained) / max_marks * 100) if max_marks > 0 else 0.0
        result.update({
            "max_marks": max_marks,
            "pass_marks": pass_marks,
            "percentage": round(percentage, 2),
            "result": "PASS" if float(em.marks_obtained) >= pass_marks else "FAIL",
        })
    return result


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


# ---- Exam Endpoints ----

@router.get("/exams")
def list_exams(
    academic_year_id: str | None = Query(None),
    term_id: str | None = Query(None),
    status_filter: str | None = Query(None, alias="status"),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    if current_user.role not in {"principal", "admin"}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Principal or Admin access required")

    stmt = select(Exam).where(
        Exam.school_id == current_user.school_id,
        Exam.deleted_at.is_(None),
    )
    if academic_year_id:
        stmt = stmt.where(Exam.academic_year_id == academic_year_id)
    if term_id:
        stmt = stmt.where(Exam.term_id == term_id)
    if status_filter:
        stmt = stmt.where(Exam.status == status_filter)

    exams = db.scalars(stmt.order_by(Exam.exam_date.desc())).all()
    return {"success": True, "data": [exam_payload(e) for e in exams], "message": "Exams retrieved"}


@router.post("/exams")
def create_exam(
    payload: ExamCreate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal_or_admin(current_user)

    exam = Exam(
        school_id=current_user.school_id,
        academic_year_id=payload.academic_year_id,
        term_id=payload.term_id,
        exam_name=payload.exam_name,
        exam_date=payload.exam_date,
        description=payload.description,
        weight=Decimal(str(payload.weight)),
        is_practical=payload.is_practical,
        status=payload.status,
        created_by=current_user.id,
        updated_by=current_user.id,
    )
    db.add(exam)
    db.flush()
    record_audit(db, current_user, action="create", module="examinations", entity_type="exam", entity_id=exam.id, new_value=exam.exam_name)
    db.commit()
    db.refresh(exam)
    return {"success": True, "data": exam_payload(exam), "message": "Exam created"}


@router.get("/exams/schedules")
def list_exam_schedules(
    page: int = Query(1, ge=1),
    page_size: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    return app_records.list_or_get_records("exams/schedules", page, page_size, db, current_user)


@router.get("/exams/report-cards")
def list_exam_report_cards(
    page: int = Query(1, ge=1),
    page_size: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    return app_records.list_or_get_records("exams/report-cards", page, page_size, db, current_user)


@router.get("/exams/grading-scale")
def list_exam_grading_scale(
    page: int = Query(1, ge=1),
    page_size: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    return app_records.list_or_get_records("exams/grading-scale", page, page_size, db, current_user)


@router.get("/exams/types")
def list_exam_types(
    page: int = Query(1, ge=1),
    page_size: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    return app_records.list_or_get_records("exams/types", page, page_size, db, current_user)


@router.get("/exams/{exam_id}")
def get_exam(
    exam_id: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    if current_user.role not in {"principal", "admin"}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Principal or Admin access required")

    exam = db.scalar(
        select(Exam).where(
            Exam.id == exam_id,
            Exam.school_id == current_user.school_id,
            Exam.deleted_at.is_(None),
        )
    )
    if exam is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Exam not found")
    return {"success": True, "data": exam_payload(exam), "message": "Exam retrieved"}


@router.put("/exams/{exam_id}")
def update_exam(
    exam_id: str,
    payload: ExamUpdate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal_or_admin(current_user)

    exam = db.scalar(
        select(Exam).where(
            Exam.id == exam_id,
            Exam.school_id == current_user.school_id,
            Exam.deleted_at.is_(None),
        )
    )
    if exam is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Exam not found")

    old_value = exam_payload(exam)
    for field, value in payload.model_dump(exclude_unset=True).items():
        if field == "weight" and value is not None:
            value = Decimal(str(value))
        if field == "exam_date" and value is not None:
            value = date.fromisoformat(value) if isinstance(value, str) else value
        setattr(exam, field, value)
    exam.updated_by = current_user.id
    db.flush()
    record_audit(db, current_user, action="update", module="examinations", entity_type="exam", entity_id=exam.id, old_value=str(old_value), new_value=exam_payload(exam))
    db.commit()
    db.refresh(exam)
    return {"success": True, "data": exam_payload(exam), "message": "Exam updated"}


@router.delete("/exams/{exam_id}")
def delete_exam(
    exam_id: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    require_principal_or_admin(current_user)

    exam = db.scalar(
        select(Exam).where(
            Exam.id == exam_id,
            Exam.school_id == current_user.school_id,
            Exam.deleted_at.is_(None),
        )
    )
    if exam is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Exam not found")

    exam.deleted_at = utcnow()
    exam.is_active = False
    exam.updated_by = current_user.id
    record_audit(db, current_user, action="delete", module="examinations", entity_type="exam", entity_id=exam.id, old_value=exam.exam_name)
    db.commit()
    return {"success": True, "data": None, "message": "Exam deleted"}


@router.get("/exams/{exam_id}/results")
def get_exam_results(
    exam_id: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    """Get all marks for an exam with percentage and PASS/FAIL."""
    if current_user.role not in {"principal", "admin"}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Principal or Admin access required")

    exam = db.scalar(
        select(Exam).where(
            Exam.id == exam_id,
            Exam.school_id == current_user.school_id,
            Exam.deleted_at.is_(None),
        )
    )
    if exam is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Exam not found")

    marks = db.scalars(
        select(ExamMark).where(
            ExamMark.exam_id == exam_id,
            ExamMark.school_id == current_user.school_id,
            ExamMark.deleted_at.is_(None),
        )
    ).all()

    results = []
    for mark in marks:
        grade_subject = db.get(GradeSubject, mark.grade_subject_id)
        results.append(exam_mark_payload(mark, grade_subject))

    return {"success": True, "data": results, "message": "Exam results retrieved"}


# ---- Exam Mark Endpoints ----

@router.get("/exam-marks")
def list_exam_marks(
    exam_id: str | None = Query(None),
    student_id: str | None = Query(None),
    grade_subject_id: str | None = Query(None),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    """List exam marks with role-based filtering."""
    # Principal/admin see all
    if current_user.role in {"principal", "admin"}:
        pass
    # Teacher: filter by their subjects/sections
    elif current_user.role == "teacher":
        # Get students in teacher's sections
        section_ids = current_user.class_teacher_sections
        if section_ids:
            student_ids_stmt = select(Student.id).where(
                Student.school_id == current_user.school_id,
                Student.current_section_id.in_(section_ids),
                Student.deleted_at.is_(None),
            )
            student_ids = tuple(db.scalars(student_ids_stmt).all())
            if not student_ids:
                return {"success": True, "data": [], "message": "No students in your sections"}
        else:
            student_ids = ()
    # Parent/guardian: see only their children's marks
    elif current_user.role in {"parent", "guardian"}:
        child_stmt = select(Guardian.student_id).where(
            Guardian.school_id == current_user.school_id,
            Guardian.user_id == current_user.id,
            Guardian.deleted_at.is_(None),
        )
        student_ids = tuple(db.scalars(child_stmt).all())
        if not student_ids:
            return {"success": True, "data": [], "message": "No linked children found"}
    else:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

    stmt = select(ExamMark).where(
        ExamMark.school_id == current_user.school_id,
        ExamMark.deleted_at.is_(None),
    )
    if exam_id:
        stmt = stmt.where(ExamMark.exam_id == exam_id)
    if student_id:
        stmt = stmt.where(ExamMark.student_id == student_id)
    if grade_subject_id:
        stmt = stmt.where(ExamMark.grade_subject_id == grade_subject_id)

    # Apply role-based filtering for teacher/parent
    if current_user.role in {"teacher"} and section_ids:
        stmt = stmt.where(ExamMark.student_id.in_(student_ids))
    elif current_user.role in {"parent", "guardian"}:
        stmt = stmt.where(ExamMark.student_id.in_(student_ids))

    marks = db.scalars(stmt.order_by(ExamMark.created_at.desc())).all()
    results = []
    for mark in marks:
        grade_subject = db.get(GradeSubject, mark.grade_subject_id)
        results.append(exam_mark_payload(mark, grade_subject))
    return {"success": True, "data": results, "message": "Exam marks retrieved"}


@router.post("/exam-marks")
def create_update_exam_mark(
    payload: ExamMarkCreateUpdate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    """Create or update (upsert) an exam mark."""
    require_principal_or_admin(current_user)

    # Validate grade_subject exists and get max_marks
    grade_subject = db.get(GradeSubject, payload.grade_subject_id)
    if grade_subject is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Grade subject not found")

    if payload.marks_obtained < 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Marks cannot be negative")

    # Check if mark already exists (upsert)
    existing = db.scalar(
        select(ExamMark).where(
            ExamMark.exam_id == payload.exam_id,
            ExamMark.student_id == payload.student_id,
            ExamMark.grade_subject_id == payload.grade_subject_id,
            ExamMark.school_id == current_user.school_id,
            ExamMark.deleted_at.is_(None),
        )
    )

    if existing:
        existing.marks_obtained = Decimal(str(payload.marks_obtained))
        existing.updated_by = current_user.id
        db.flush()
        record_audit(db, current_user, action="update", module="examinations", entity_type="exam_mark", entity_id=existing.id)
        db.commit()
        db.refresh(existing)
        return {"success": True, "data": exam_mark_payload(existing, grade_subject), "message": "Exam mark updated"}
    else:
        exam_mark = ExamMark(
            school_id=current_user.school_id,
            exam_id=payload.exam_id,
            student_id=payload.student_id,
            grade_subject_id=payload.grade_subject_id,
            marks_obtained=Decimal(str(payload.marks_obtained)),
            created_by=current_user.id,
            updated_by=current_user.id,
        )
        db.add(exam_mark)
        db.flush()
        record_audit(db, current_user, action="create", module="examinations", entity_type="exam_mark", entity_id=exam_mark.id)
        db.commit()
        db.refresh(exam_mark)
        return {"success": True, "data": exam_mark_payload(exam_mark, grade_subject), "message": "Exam mark created"}


@router.get("/students/{student_id}/exam-marks")
def get_student_exam_marks(
    student_id: str,
    exam_id: str | None = Query(None),
    grade_subject_id: str | None = Query(None),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    """Get all exam marks for a student."""
    # Check access permissions
    if current_user.role not in {"principal", "admin"}:
        if current_user.role == "teacher":
            # Teacher can only see marks for students in their sections
            student = db.scalar(
                select(Student).where(
                    Student.id == student_id,
                    Student.school_id == current_user.school_id,
                    Student.deleted_at.is_(None),
                )
            )
            if student is None or student.current_section_id not in current_user.class_teacher_sections:
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Student not in your sections")
        elif current_user.role in {"parent", "guardian"}:
            # Parent can only see their children's marks
            child_stmt = select(Guardian.student_id).where(
                Guardian.school_id == current_user.school_id,
                Guardian.user_id == current_user.id,
                Guardian.deleted_at.is_(None),
            )
            child_ids = tuple(db.scalars(child_stmt).all())
            if student_id not in child_ids:
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your child's record")
        else:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

    stmt = select(ExamMark).where(
        ExamMark.student_id == student_id,
        ExamMark.school_id == current_user.school_id,
        ExamMark.deleted_at.is_(None),
    )
    if exam_id:
        stmt = stmt.where(ExamMark.exam_id == exam_id)
    if grade_subject_id:
        stmt = stmt.where(ExamMark.grade_subject_id == grade_subject_id)

    marks = db.scalars(stmt.order_by(ExamMark.created_at.desc())).all()
    results = []
    for mark in marks:
        grade_subject = db.get(GradeSubject, mark.grade_subject_id)
        results.append(exam_mark_payload(mark, grade_subject))
    return {"success": True, "data": results, "message": "Student exam marks retrieved"}


@router.get("/exam-marks/analyze/{exam_id}")
def analyze_exam(
    exam_id: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
) -> dict[str, Any]:
    """Get exam statistics: average, pass %, fail %."""
    if current_user.role not in {"principal", "admin"}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Principal or Admin access required")

    exam = db.scalar(
        select(Exam).where(
            Exam.id == exam_id,
            Exam.school_id == current_user.school_id,
            Exam.deleted_at.is_(None),
        )
    )
    if exam is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Exam not found")

    marks = db.scalars(
        select(ExamMark).where(
            ExamMark.exam_id == exam_id,
            ExamMark.school_id == current_user.school_id,
            ExamMark.deleted_at.is_(None),
        )
    ).all()

    if not marks:
        return {
            "success": True,
            "data": {
                "exam_id": exam_id,
                "total_students": 0,
                "avg_marks": 0.0,
                "pass_count": 0,
                "fail_count": 0,
                "pass_percentage": 0.0,
                "fail_percentage": 0.0,
            },
            "message": "No marks found for this exam",
        }

    total = len(marks)
    pass_count = 0
    fail_count = 0
    total_marks = Decimal("0")

    for mark in marks:
        grade_subject = db.get(GradeSubject, mark.grade_subject_id)
        if grade_subject:
            if float(mark.marks_obtained) >= float(grade_subject.pass_marks):
                pass_count += 1
            else:
                fail_count += 1
        total_marks += mark.marks_obtained

    avg_marks = float(total_marks) / total if total > 0 else 0.0
    pass_pct = (pass_count / total * 100) if total > 0 else 0.0
    fail_pct = (fail_count / total * 100) if total > 0 else 0.0

    return {
        "success": True,
        "data": {
            "exam_id": exam_id,
            "exam_name": exam.exam_name,
            "total_students": total,
            "avg_marks": round(avg_marks, 2),
            "pass_count": pass_count,
            "fail_count": fail_count,
            "pass_percentage": round(pass_pct, 2),
            "fail_percentage": round(fail_pct, 2),
        },
        "message": "Exam analysis retrieved",
    }
