from __future__ import annotations

from datetime import date

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.models.auth import Permission, Role, RolePermission, School, Section, User, UserRole
from app.models.catalog import (
    AcademicTerm,
    AcademicYear,
    Grade,
    GradeSubject,
    LeaveBalance,
    LeaveType,
    Room,
    Staff,
    StaffSubject,
    Subject,
)

DEFAULT_SCHOOL_ID = "00000000-0000-4000-8000-000000000001"

ROLE_PERMISSIONS: dict[str, set[str]] = {
    "principal": {"goals.read", "goals.manage", "tasks.read", "tasks.manage", "tasks.update_own"},
    "admin": {"goals.read", "tasks.read", "tasks.update_own"},
    "teacher": {"goals.read", "tasks.read", "tasks.update_own"},
    "parent": set(),
}

PERMISSION_DESCRIPTIONS = {
    "goals.read": "Read visible operational goals",
    "goals.manage": "Create, update, activate, archive, and complete goals",
    "tasks.read": "Read visible operational tasks",
    "tasks.manage": "Create, assign, close, reopen, and archive operational tasks",
    "tasks.update_own": "Update progress, comments, blockers, evidence, and checklist items on assigned tasks",
}

USERS = [
    ("user-principal", "principal", "Principal User", "principal", None, None, "principal123"),
    ("user-admin", "admin", "Admin User", "admin", "staff", "staff-admin", "admin123"),
    ("user-teacher", "teacher", "Teacher User", "teacher", "staff", "staff-teacher-1", "teacher123"),
    ("user-teacher-other", "teacher2", "Other Teacher", "teacher", "staff", "staff-teacher-2", "teacher123"),
    ("user-parent", "parent", "Parent User", "parent", "guardian", "guardian-parent", "parent123"),
]


def seed_defaults(db: Session) -> None:
    school = db.get(School, DEFAULT_SCHOOL_ID)
    if school is None:
        school = School(
            id=DEFAULT_SCHOOL_ID,
            name="SchoolDesk Local School",
            school_type="school",
            affiliation_board="",
            email="",
            phone="",
            city="",
            state="",
            principal_name="Principal User",
            registration_number="",
            logo_url="",
        )
        db.add(school)
    else:
        school.school_type = school.school_type or "school"
        school.principal_name = school.principal_name or "Principal User"

    permissions: dict[str, Permission] = {}
    for code, description in PERMISSION_DESCRIPTIONS.items():
        permission = db.scalar(select(Permission).where(Permission.code == code))
        if permission is None:
            permission = Permission(code=code, description=description)
            db.add(permission)
            db.flush()
        permissions[code] = permission

    roles: dict[str, Role] = {}
    for role_name, codes in ROLE_PERMISSIONS.items():
        role = db.scalar(
            select(Role).where(Role.school_id == DEFAULT_SCHOOL_ID, Role.name == role_name)
        )
        if role is None:
            role = Role(school_id=DEFAULT_SCHOOL_ID, name=role_name)
            db.add(role)
            db.flush()
        roles[role_name] = role
        for code in codes:
            exists = db.scalar(
                select(RolePermission).where(
                    RolePermission.role_id == role.id,
                    RolePermission.permission_id == permissions[code].id,
                )
            )
            if exists is None:
                db.add(RolePermission(role_id=role.id, permission_id=permissions[code].id))

    for user_id, username, full_name, role_name, linked_type, linked_id, password in USERS:
        user = db.get(User, user_id)
        if user is None:
            user = User(
                id=user_id,
                school_id=DEFAULT_SCHOOL_ID,
                username=username,
                full_name=full_name,
                role=role_name,
                linked_type=linked_type,
                linked_id=linked_id,
                password_hash=hash_password(password),
            )
            db.add(user)
            db.flush()
        role = roles[role_name]
        exists = db.scalar(select(UserRole).where(UserRole.user_id == user.id, UserRole.role_id == role.id))
        if exists is None:
            db.add(UserRole(user_id=user.id, role_id=role.id))

    academic_year = db.get(AcademicYear, "academic-year-current")
    if academic_year is None:
        academic_year = AcademicYear(
            id="academic-year-current",
            school_id=DEFAULT_SCHOOL_ID,
            year_label="2026-2027",
            start_date=date(2026, 4, 1),
            end_date=date(2027, 3, 31),
            is_current=True,
            status="active",
            created_by="user-principal",
        )
        db.add(academic_year)
        db.flush()

    for term_id, term_name, start_date, end_date, sort_order in [
        ("term-current-1", "Term 1", date(2026, 4, 1), date(2026, 9, 30), 1),
        ("term-current-2", "Term 2", date(2026, 10, 1), date(2027, 3, 31), 2),
    ]:
        term = db.get(AcademicTerm, term_id)
        if term is None:
            db.add(
                AcademicTerm(
                    id=term_id,
                    school_id=DEFAULT_SCHOOL_ID,
                    academic_year_id="academic-year-current",
                    term_name=term_name,
                    start_date=start_date,
                    end_date=end_date,
                    sort_order=sort_order,
                    status="active",
                    created_by="user-principal",
                )
            )

    grades = [
        ("grade-1", 1, "Grade 1"),
        ("grade-2", 2, "Grade 2"),
    ]
    for grade_id, grade_number, grade_name in grades:
        grade = db.get(Grade, grade_id)
        if grade is None:
            db.add(
                Grade(
                    id=grade_id,
                    school_id=DEFAULT_SCHOOL_ID,
                    grade_number=grade_number,
                    grade_name=grade_name,
                    created_by="user-principal",
                )
            )

    subjects = [
        ("subject-english", "English", "ENG", "#2563EB"),
        ("subject-math", "Mathematics", "MATH", "#16A34A"),
        ("subject-science", "Science", "SCI", "#DC2626"),
    ]
    for subject_id, subject_name, subject_code, subject_color in subjects:
        subject = db.get(Subject, subject_id)
        if subject is None:
            db.add(
                Subject(
                    id=subject_id,
                    school_id=DEFAULT_SCHOOL_ID,
                    subject_name=subject_name,
                    subject_code=subject_code,
                    subject_type="core",
                    subject_color=subject_color,
                    created_by="user-principal",
                )
            )

    rooms = [
        ("room-101", "101", "classroom", 40, "A", 1),
        ("room-102", "102", "classroom", 40, "A", 1),
    ]
    for room_id, room_number, room_type, capacity, block, floor in rooms:
        room = db.get(Room, room_id)
        if room is None:
            db.add(
                Room(
                    id=room_id,
                    school_id=DEFAULT_SCHOOL_ID,
                    room_number=room_number,
                    room_type=room_type,
                    capacity=capacity,
                    block=block,
                    floor=floor,
                    created_by="user-principal",
                )
            )

    staff_rows = [
        ("staff-admin", "ADM001", "Admin", "User", "Administrator", "admin"),
        ("staff-teacher-1", "TCH001", "Teacher", "User", "Class Teacher", "teacher"),
        ("staff-teacher-2", "TCH002", "Other", "Teacher", "Teacher", "teacher"),
    ]
    for staff_id, staff_code, first_name, last_name, designation, role_name in staff_rows:
        staff = db.get(Staff, staff_id)
        if staff is None:
            db.add(
                Staff(
                    id=staff_id,
                    school_id=DEFAULT_SCHOOL_ID,
                    staff_code=staff_code,
                    first_name=first_name,
                    last_name=last_name,
                    designation=designation,
                    employment_type="full_time",
                    status="active",
                    gender="unspecified",
                    join_date=date(2026, 1, 1),
                    created_by="user-principal",
                )
            )

    leave_types = [
        ("leave-type-casual", "Casual Leave", "Short personal leave", 12),
        ("leave-type-sick", "Sick Leave", "Medical leave", 12),
    ]
    for leave_type_id, leave_name, description, max_days in leave_types:
        leave_type = db.get(LeaveType, leave_type_id)
        if leave_type is None:
            db.add(
                LeaveType(
                    id=leave_type_id,
                    school_id=DEFAULT_SCHOOL_ID,
                    leave_name=leave_name,
                    description=description,
                    max_days_per_year=max_days,
                    applicable_to="staff",
                    created_by="user-principal",
                )
            )
    db.flush()

    for balance_id, staff_id, leave_type_id in [
        ("leave-balance-teacher-casual", "staff-teacher-1", "leave-type-casual"),
        ("leave-balance-teacher-sick", "staff-teacher-1", "leave-type-sick"),
        ("leave-balance-admin-casual", "staff-admin", "leave-type-casual"),
    ]:
        balance = db.get(LeaveBalance, balance_id)
        if balance is None:
            db.add(
                LeaveBalance(
                    id=balance_id,
                    school_id=DEFAULT_SCHOOL_ID,
                    staff_id=staff_id,
                    leave_type_id=leave_type_id,
                    academic_year_id="academic-year-current",
                    total_entitled=12,
                    used_days=0,
                    remaining_days=12,
                    created_by="user-principal",
                )
            )

    sections = [
        ("section-a", "Grade 1 - A", "grade-1", "academic-year-current", "staff-teacher-1", "room-101", 40),
        ("section-b", "Grade 1 - B", "grade-1", "academic-year-current", "staff-teacher-2", "room-102", 40),
    ]
    for section_id, name, grade_id, academic_year_id, class_teacher_id, room_id, capacity in sections:
        section = db.get(Section, section_id)
        if section is None:
            db.add(
                Section(
                    id=section_id,
                    school_id=DEFAULT_SCHOOL_ID,
                    name=name,
                    grade_id=grade_id,
                    academic_year_id=academic_year_id,
                    class_teacher_id=class_teacher_id,
                    room_id=room_id,
                    capacity=capacity,
                )
            )
        else:
            section.grade_id = section.grade_id or grade_id
            section.academic_year_id = section.academic_year_id or academic_year_id
            section.room_id = section.room_id or room_id
            section.capacity = section.capacity or capacity
    db.flush()

    for mapping_id, subject_id, periods in [
        ("grade-subject-1-eng", "subject-english", 5),
        ("grade-subject-1-math", "subject-math", 5),
        ("grade-subject-1-sci", "subject-science", 4),
    ]:
        mapping = db.get(GradeSubject, mapping_id)
        if mapping is None:
            db.add(
                GradeSubject(
                    id=mapping_id,
                    school_id=DEFAULT_SCHOOL_ID,
                    academic_year_id="academic-year-current",
                    grade_id="grade-1",
                    subject_id=subject_id,
                    periods_per_week=periods,
                    max_marks=100,
                    pass_marks=35,
                    is_mandatory=True,
                    created_by="user-principal",
                )
            )

    for mapping_id, section_id, subject_id, staff_id in [
        ("staff-subject-a-eng", "section-a", "subject-english", "staff-teacher-1"),
        ("staff-subject-a-math", "section-a", "subject-math", "staff-teacher-1"),
        ("staff-subject-b-eng", "section-b", "subject-english", "staff-teacher-2"),
        ("staff-subject-b-math", "section-b", "subject-math", "staff-teacher-2"),
    ]:
        mapping = db.get(StaffSubject, mapping_id)
        if mapping is None:
            db.add(
                StaffSubject(
                    id=mapping_id,
                    school_id=DEFAULT_SCHOOL_ID,
                    academic_year_id="academic-year-current",
                    grade_id="grade-1",
                    section_id=section_id,
                    subject_id=subject_id,
                    staff_id=staff_id,
                    is_primary=True,
                    created_by="user-principal",
                )
            )

    db.commit()
