from __future__ import annotations

from pathlib import Path

from fastapi.testclient import TestClient

from app.core.config import Settings
from app.main import create_app
from app.models.catalog import (
    FeeStructure,
    Grade,
    GradeSubject,
    LeaveApplication,
    LeaveBalance,
    StaffSubject,
    StudentLeaveApplication,
)
from app.models.goal_task import ApprovalRequest, AuditLog, NotificationLog


def make_test_client(tmp_path: Path, **overrides: object) -> TestClient:
    settings = Settings(
        database_url=f"sqlite+pysqlite:///{tmp_path / 'schooldesk-test.db'}",
        redis_health_enabled=False,
        seed_on_start=True,
        jwt_secret_key="test-secret-key-for-schooldesk-fastapi",
        **overrides,
    )
    return TestClient(create_app(settings))


def login(client: TestClient, username: str, password: str) -> str:
    response = client.post("/api/v1/auth/login", json={"username": username, "password": password})
    assert response.status_code == 200, response.text
    return response.json()["data"]["token"]


def headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_health_and_seeded_auth(tmp_path: Path) -> None:
    with make_test_client(tmp_path) as client:
        assert client.get("/health").json()["status"] == "ok"
        assert client.get("/health/db").json()["status"] == "ok"
        assert client.get("/health/redis").json()["redis"] == "disabled"

        token = login(client, "principal", "principal123")
        response = client.get("/api/v1/auth/me", headers=headers(token))
        profile = client.get("/api/v1/auth/profile", headers=headers(token))

    assert response.status_code == 200
    payload = response.json()
    assert payload["role"] == "principal"
    assert "goals.manage" in payload["permissions"]
    assert "tasks.manage" in payload["permissions"]
    assert profile.status_code == 200
    assert profile.json()["data"]["role_name"] == "principal"


def test_local_flutter_web_cors_preflight_is_allowed(tmp_path: Path) -> None:
    with make_test_client(tmp_path) as client:
        response = client.options(
            "/api/v1/auth/login",
            headers={
                "Origin": "http://127.0.0.1:9173",
                "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": "content-type",
            },
        )

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://127.0.0.1:9173"
    assert "POST" in response.headers["access-control-allow-methods"]


def test_unimplemented_route_returns_fastapi_not_found_without_gateway(tmp_path: Path) -> None:
    with make_test_client(tmp_path) as client:
        token = login(client, "principal", "principal123")
        response = client.get("/api/v1/unported-module", headers=headers(token))

    assert response.status_code == 404
    assert response.json()["detail"] == "Not Found"


def test_flutter_dashboard_smoke_contracts_return_backend_empty_states(tmp_path: Path) -> None:
    with make_test_client(tmp_path) as client:
        principal = login(client, "principal", "principal123")
        teacher = login(client, "teacher", "teacher123")
        parent = login(client, "parent", "parent123")

        principal_dashboard = client.get("/api/v1/dashboard/principal", headers=headers(principal))
        school = client.get("/api/v1/schools/current", headers=headers(principal))
        teacher_dashboard = client.get("/api/v1/dashboard/teacher", headers=headers(teacher))
        announcements = client.get("/api/v1/announcements", headers=headers(teacher))
        children = client.get("/api/v1/me/students", headers=headers(parent))
        parent_dashboard = client.get("/api/v1/dashboard/parent", headers=headers(parent))
        students = client.get("/api/v1/students?page=1&page_size=20", headers=headers(principal))
        staff = client.get("/api/v1/staff?page=1&page_size=20", headers=headers(principal))

    assert principal_dashboard.status_code == 200
    assert principal_dashboard.json()["data"]["metrics"]["total_students"] == 0
    assert school.status_code == 200
    assert school.json()["data"]["name"] == "SchoolDesk Local School"
    assert teacher_dashboard.status_code == 200
    assert "metrics" in teacher_dashboard.json()["data"]
    assert announcements.status_code == 200
    assert announcements.json()["data"] == []
    assert children.status_code == 200
    assert children.json()["data"] == []
    assert parent_dashboard.status_code == 200
    assert parent_dashboard.json()["data"]["children"] == []
    assert students.status_code == 200
    assert students.json()["total"] == 0
    assert staff.status_code == 200
    assert staff.json()["total"] >= 3


def test_catalog_staff_and_student_contracts_are_db_backed(tmp_path: Path) -> None:
    with make_test_client(tmp_path) as client:
        principal = login(client, "principal", "principal123")
        teacher = login(client, "teacher", "teacher123")

        school_update = client.patch(
            "/api/v1/schools/current",
            headers=headers(principal),
            json={"city": "Pune", "state": "Maharashtra", "principal_name": "Dr Principal"},
        )
        assert school_update.status_code == 200, school_update.text
        assert school_update.json()["data"]["city"] == "Pune"

        years = client.get("/api/v1/academic-years", headers=headers(principal))
        assert years.status_code == 200
        assert years.json()["data"][0]["year_label"] == "2026-2027"
        year_id = years.json()["data"][0]["id"]

        terms = client.get(f"/api/v1/academic-years/{year_id}/terms", headers=headers(principal))
        assert terms.status_code == 200
        assert [row["term_name"] for row in terms.json()["data"]] == ["Term 1", "Term 2"]

        grades = client.get("/api/v1/grades", headers=headers(principal))
        subjects = client.get("/api/v1/subjects", headers=headers(principal))
        sections = client.get("/api/v1/sections", headers=headers(principal))
        rooms = client.get("/api/v1/rooms", headers=headers(principal))
        staff = client.get("/api/v1/staff?page=1&page_size=10", headers=headers(principal))

        assert grades.status_code == 200
        assert grades.json()["data"][0]["grade_number"] == 1
        assert subjects.status_code == 200
        assert {row["subject_code"] for row in subjects.json()["data"]} >= {"ENG", "MATH", "SCI"}
        assert sections.status_code == 200
        assert sections.json()["data"][0]["grade_id"] == "grade-1"
        assert rooms.status_code == 200
        assert rooms.json()["data"][0]["room_number"] == "101"
        assert staff.status_code == 200
        assert staff.json()["total"] >= 3

        room_create = client.post(
            "/api/v1/rooms",
            headers=headers(principal),
            json={"room_number": "201", "room_type": "lab", "capacity": 32, "block": "B", "floor": 2},
        )
        assert room_create.status_code == 200, room_create.text
        assert room_create.json()["data"]["room_type"] == "lab"

        staff_create = client.post(
            "/api/v1/staff",
            headers=headers(principal),
            json={
                "staff_code": "TCH900",
                "username": "teacher900",
                "password": "teacher900pass",
                "first_name": "New",
                "last_name": "Teacher",
                "designation": "Teacher",
                "account_role": "Teacher",
                "join_date": "2026-06-01",
            },
        )
        assert staff_create.status_code == 200, staff_create.text
        staff_id = staff_create.json()["data"]["id"]
        assert login(client, "teacher900", "teacher900pass")

        staff_update = client.put(
            f"/api/v1/staff/{staff_id}",
            headers=headers(principal),
            json={
                "first_name": "Updated",
                "last_name": "Teacher",
                "designation": "Senior Teacher",
            },
        )
        assert staff_update.status_code == 200, staff_update.text
        assert staff_update.json()["data"]["designation"] == "Senior Teacher"

        student_create = client.post(
            "/api/v1/students",
            headers=headers(principal),
            json={
                "student_code": "STU900",
                "admission_number": "ADM900",
                "first_name": "Asha",
                "last_name": "Rao",
                "date_of_birth": "2018-05-01",
                "gender": "female",
                "current_section_id": "section-a",
                "admission_date": "2026-06-01",
            },
        )
        assert student_create.status_code == 200, student_create.text
        student_id = student_create.json()["data"]["id"]
        assert student_create.json()["data"]["current_section"]["section_name"] == "Grade 1 - A"

        enrollments = client.get(f"/api/v1/students/{student_id}/enrollments", headers=headers(principal))
        assert enrollments.status_code == 200
        assert enrollments.json()["data"][0]["section_id"] == "section-a"

        student_update = client.put(
            f"/api/v1/students/{student_id}",
            headers=headers(principal),
            json={"first_name": "Asha", "last_name": "Raman", "gender": "female", "status": "active"},
        )
        assert student_update.status_code == 200
        assert student_update.json()["data"]["last_name"] == "Raman"

        teacher_room_create = client.post(
            "/api/v1/rooms",
            headers=headers(teacher),
            json={"room_number": "301"},
        )
        assert teacher_room_create.status_code == 403

        student_delete = client.delete(f"/api/v1/students/{student_id}", headers=headers(principal))
        assert student_delete.status_code == 200
        missing_student = client.get(f"/api/v1/students/{student_id}", headers=headers(principal))
        assert missing_student.status_code == 404


def test_principal_class_hub_setup_and_csv_contracts_are_db_backed(tmp_path: Path) -> None:
    with make_test_client(tmp_path) as client:
        principal = login(client, "principal", "principal123")
        admin = login(client, "admin", "admin123")

        overview = client.get("/api/v1/principal/classes", headers=headers(principal))
        assert overview.status_code == 200, overview.text
        assert overview.json()["data"]["summary"]["total_classes"] == 2
        assert overview.json()["data"]["classes"][0]["section_id"]

        admin_overview = client.get("/api/v1/principal/classes", headers=headers(admin))
        assert admin_overview.status_code == 403

        grade_subjects = client.get("/api/v1/grade-subjects", headers=headers(principal))
        staff_subjects = client.get("/api/v1/staff-subjects", headers=headers(principal))
        assert grade_subjects.status_code == 200
        assert len(grade_subjects.json()["data"]) >= 3
        assert staff_subjects.status_code == 200
        assert len(staff_subjects.json()["data"]) >= 4

        create_class = client.post(
            "/api/v1/principal/classes",
            headers=headers(principal),
            json={
                "academic_year_id": "academic-year-current",
                "grade_name": "Grade 3",
                "grade_number": 3,
                "section_name": "Grade 3 - A",
                "capacity": 36,
                "class_teacher_id": "staff-teacher-1",
                "room_number": "303",
                "room_type": "classroom",
                "subject_mappings": [
                    {
                        "subject_name": "Social Studies",
                        "subject_code": "SST",
                        "periods_per_week": 4,
                        "teacher_id": "staff-teacher-1",
                    }
                ],
                "fee_items": [
                    {
                        "category_name": "Tuition",
                        "frequency": "term",
                        "amount": 12000,
                        "due_day": 10,
                    }
                ],
            },
        )
        assert create_class.status_code == 200, create_class.text
        section_id = create_class.json()["data"]["section"]["id"]
        grade_id = create_class.json()["data"]["grade"]["id"]

        fees = client.get(
            f"/api/v1/fees/structures?academic_year_id=academic-year-current&grade_id={grade_id}",
            headers=headers(principal),
        )
        assert fees.status_code == 200
        assert fees.json()["data"][0]["category_name"] == "Tuition"

        save_mapping = client.post(
            "/api/v1/principal/subjects/subject-english/mappings",
            headers=headers(principal),
            json={
                "academic_year_id": "academic-year-current",
                "grade_id": grade_id,
                "section_id": section_id,
                "teacher_id": "staff-teacher-1",
                "periods_per_week": 5,
            },
        )
        assert save_mapping.status_code == 200, save_mapping.text
        assert save_mapping.json()["data"]["grade_subject"]["subject_id"] == "subject-english"

        update_class = client.put(
            f"/api/v1/principal/classes/{section_id}",
            headers=headers(principal),
            json={
                "academic_year_id": "academic-year-current",
                "grade_id": grade_id,
                "section_name": "Grade 3 - A",
                "capacity": 40,
                "class_teacher_id": "staff-teacher-1",
            },
        )
        assert update_class.status_code == 200
        assert update_class.json()["data"]["section"]["capacity"] == 40

        valid_csv = (
            "grade_name,grade_number,section_name,capacity,room_number,year_label,"
            "class_teacher_staff_code,subject_names,subject_codes,subject_teacher_staff_codes,"
            "periods_per_week,fee_categories,fee_amounts\n"
            "Grade 4,4,Grade 4 - A,38,404,2026-2027,TCH001,English;Mathematics,ENG;MATH,TCH001;TCH001,5;5,Tuition;Books,15000;2000\n"
        )
        dry_run = client.post(
            "/api/v1/principal/classes/import/dry-run",
            headers=headers(principal),
            json={"csv_text": valid_csv},
        )
        assert dry_run.status_code == 200, dry_run.text
        assert dry_run.json()["data"]["can_import"] is True
        assert dry_run.json()["data"]["summary"]["classes_to_create"] == 1

        imported = client.post(
            "/api/v1/principal/classes/import",
            headers=headers(principal),
            json={"csv_text": valid_csv},
        )
        assert imported.status_code == 200, imported.text
        assert imported.json()["data"]["summary"]["created_classes"] == 1

        invalid_csv = "grade_name,section_name,year_label\n,Missing Grade,2026-2027\n"
        invalid_dry_run = client.post(
            "/api/v1/principal/classes/import/dry-run",
            headers=headers(principal),
            json={"csv_text": invalid_csv},
        )
        assert invalid_dry_run.status_code == 200
        assert invalid_dry_run.json()["data"]["can_import"] is False

        from app.core import database

        assert database.SessionLocal is not None
        with database.SessionLocal() as db:
            assert db.query(Grade).filter(Grade.grade_name == "Grade 4").count() == 1
            assert db.query(GradeSubject).count() >= 5
            assert db.query(StaffSubject).count() >= 5
            assert db.query(FeeStructure).count() >= 3
            assert db.query(AuditLog).filter(AuditLog.module == "class_hub").count() >= 4


def test_admin_principal_approval_workflow_is_db_backed_and_safe(tmp_path: Path) -> None:
    with make_test_client(tmp_path) as client:
        principal = login(client, "principal", "principal123")
        admin = login(client, "admin", "admin123")
        parent = login(client, "parent", "parent123")

        create_response = client.post(
            "/api/v1/approvals",
            headers=headers(admin),
            json={
                "module": "students",
                "operation_type": "create",
                "entity_type": "student",
                "status": "draft",
                "title": "Create student Asha",
                "details": "Admin requested student creation for Principal review.",
                "payload_json": {"student_code": "STU-APPROVAL"},
            },
        )
        assert create_response.status_code == 200, create_response.text
        approval_id = create_response.json()["data"]["id"]
        assert create_response.json()["data"]["status"] == "draft"

        parent_list = client.get("/api/v1/approvals", headers=headers(parent))
        assert parent_list.status_code == 403

        submit_response = client.post(f"/api/v1/approvals/{approval_id}/submit", headers=headers(admin))
        assert submit_response.status_code == 200
        assert submit_response.json()["data"]["status"] == "pending"

        principal_list = client.get("/api/v1/approvals", headers=headers(principal))
        assert principal_list.status_code == 200
        assert [row["id"] for row in principal_list.json()["data"]] == [approval_id]

        change_response = client.post(
            f"/api/v1/approvals/{approval_id}/request-changes",
            headers=headers(principal),
            json={"note": "Add parent link evidence."},
        )
        assert change_response.status_code == 200
        assert change_response.json()["data"]["status"] == "changes_requested"

        update_response = client.put(
            f"/api/v1/approvals/{approval_id}",
            headers=headers(admin),
            json={"details": "Evidence added.", "payload_json": {"student_code": "STU-APPROVAL", "parent_link": "ready"}},
        )
        assert update_response.status_code == 200
        resubmit_response = client.post(f"/api/v1/approvals/{approval_id}/submit", headers=headers(admin))
        assert resubmit_response.status_code == 200
        assert resubmit_response.json()["data"]["status"] == "pending"

        approve_response = client.post(
            f"/api/v1/approvals/{approval_id}/approve",
            headers=headers(principal),
            json={"note": "Looks complete."},
        )
        assert approve_response.status_code == 200
        assert approve_response.json()["data"]["status"] == "approved"

        class_approval = client.post(
            "/api/v1/class-approvals",
            headers=headers(admin),
            json={
                "class_name": "Grade 9",
                "operation_type": "create",
                "details": "Principal approval required before class is active.",
            },
        )
        assert class_approval.status_code == 200, class_approval.text
        class_approval_id = class_approval.json()["data"]["id"]

        apply_response = client.post(f"/api/v1/approvals/{approval_id}/apply", headers=headers(principal))
        assert apply_response.status_code == 200
        assert apply_response.json()["data"]["status"] == "applied"
        assert "no sensitive school mutation" in apply_response.json()["data"]["apply_note"]

        alias_list = client.get("/api/v1/class-approvals", headers=headers(principal))
        assert alias_list.status_code == 200
        assert [row["id"] for row in alias_list.json()["data"]] == [class_approval_id]

        from app.core import database

        assert database.SessionLocal is not None
        with database.SessionLocal() as db:
            assert db.query(ApprovalRequest).count() == 2
            assert db.query(Grade).filter(Grade.grade_name == "Grade 9").count() == 0
            assert db.query(AuditLog).filter(AuditLog.module == "approvals").count() >= 7
            assert db.query(NotificationLog).filter(NotificationLog.reference_type == "approval").count() >= 2


def test_leave_compatibility_contracts_are_db_backed_and_principal_decided(tmp_path: Path) -> None:
    with make_test_client(tmp_path) as client:
        principal = login(client, "principal", "principal123")
        admin = login(client, "admin", "admin123")
        teacher = login(client, "teacher", "teacher123")
        parent = login(client, "parent", "parent123")

        principal_staff_leaves = client.get("/api/v1/leave/applications", headers=headers(principal))
        principal_student_leaves = client.get("/api/v1/student-leave/applications", headers=headers(principal))
        leave_types = client.get("/api/v1/leave/types", headers=headers(teacher))
        parent_staff_leave_types = client.get("/api/v1/leave/types", headers=headers(parent))

        assert principal_staff_leaves.status_code == 200
        assert principal_staff_leaves.json()["data"] == []
        assert principal_student_leaves.status_code == 200
        assert principal_student_leaves.json()["data"] == []
        assert leave_types.status_code == 200
        assert leave_types.json()["data"][0]["leave_name"] in {"Casual Leave", "Sick Leave"}
        assert parent_staff_leave_types.status_code == 403

        submit_staff_leave = client.post(
            "/api/v1/leave/applications",
            headers=headers(teacher),
            json={
                "staff_id": "staff-teacher-1",
                "leave_type_id": "leave-type-casual",
                "from_date": "2026-06-10",
                "to_date": "2026-06-11",
                "reason": "Family function",
            },
        )
        assert submit_staff_leave.status_code == 200, submit_staff_leave.text
        staff_leave_id = submit_staff_leave.json()["data"]["id"]
        assert submit_staff_leave.json()["data"]["status"] == "pending"
        assert submit_staff_leave.json()["data"]["total_days"] == 2

        admin_approve = client.put(
            f"/api/v1/leave/applications/{staff_leave_id}/approve",
            headers=headers(admin),
            json={"status": "approved"},
        )
        assert admin_approve.status_code == 403

        principal_approve = client.put(
            f"/api/v1/leave/applications/{staff_leave_id}/approve",
            headers=headers(principal),
            json={"status": "approved"},
        )
        assert principal_approve.status_code == 200, principal_approve.text
        assert principal_approve.json()["data"]["status"] == "approved"

        duplicate_approve = client.put(
            f"/api/v1/leave/applications/{staff_leave_id}/approve",
            headers=headers(principal),
            json={"status": "approved"},
        )
        assert duplicate_approve.status_code == 409

        student_create = client.post(
            "/api/v1/students",
            headers=headers(principal),
            json={
                "student_code": "STU-LEAVE",
                "admission_number": "ADM-LEAVE",
                "first_name": "Leave",
                "last_name": "Student",
                "date_of_birth": "2018-05-01",
                "gender": "female",
                "current_section_id": "section-a",
                "admission_date": "2026-06-01",
            },
        )
        assert student_create.status_code == 200, student_create.text
        student_id = student_create.json()["data"]["id"]

        submit_student_leave = client.post(
            "/api/v1/student-leave/applications",
            headers=headers(parent),
            json={
                "student_id": student_id,
                "leave_type": "Sick Leave",
                "from_date": "2026-06-12",
                "to_date": "2026-06-12",
                "reason": "Fever",
            },
        )
        assert submit_student_leave.status_code == 200, submit_student_leave.text
        student_leave_id = submit_student_leave.json()["data"]["id"]

        reject_without_reason = client.put(
            f"/api/v1/student-leave/applications/{student_leave_id}/decision",
            headers=headers(principal),
            json={"status": "rejected"},
        )
        assert reject_without_reason.status_code == 400

        reject_with_reason = client.put(
            f"/api/v1/student-leave/applications/{student_leave_id}/decision",
            headers=headers(principal),
            json={"status": "rejected", "rejection_reason": "Insufficient medical details"},
        )
        assert reject_with_reason.status_code == 200
        assert reject_with_reason.json()["data"]["rejection_reason"] == "Insufficient medical details"

        from app.core import database

        assert database.SessionLocal is not None
        with database.SessionLocal() as db:
            assert db.query(LeaveApplication).count() == 1
            assert db.query(StudentLeaveApplication).count() == 1
            balance = db.get(LeaveBalance, "leave-balance-teacher-casual")
            assert balance is not None
            assert float(balance.used_days) == 2
            assert db.query(AuditLog).filter(AuditLog.module.in_(["leave", "student_leave"])).count() >= 4
            assert db.query(NotificationLog).filter(NotificationLog.reference_type == "leave").count() >= 4


def test_principal_creates_goal_and_role_scoped_task_visibility(tmp_path: Path) -> None:
    with make_test_client(tmp_path) as client:
        principal = login(client, "principal", "principal123")
        teacher = login(client, "teacher", "teacher123")
        other_teacher = login(client, "teacher2", "teacher123")
        parent = login(client, "parent", "parent123")

        goal_response = client.post(
            "/api/v1/goals",
            headers=headers(principal),
            json={
                "title": "Improve attendance",
                "description": "Raise section attendance consistency.",
                "priority": "high",
                "key_results": [{"title": "95 percent attendance", "target_value": "95", "unit": "%"}],
            },
        )
        assert goal_response.status_code == 201, goal_response.text
        goal_id = goal_response.json()["id"]

        activate_response = client.post(f"/api/v1/goals/{goal_id}/activate", headers=headers(principal))
        assert activate_response.status_code == 200
        assert activate_response.json()["status"] == "active"

        task_response = client.post(
            f"/api/v1/goals/{goal_id}/tasks",
            headers=headers(principal),
            json={
                "title": "Collect attendance blockers",
                "description": "Class teacher should identify blockers for section A.",
                "priority": "urgent",
                "scope_type": "section",
                "scope_id": "section-a",
                "assigned_section_id": "section-a",
                "checklist_items": [{"title": "Call absent students"}, {"title": "Share blocker report"}],
            },
        )
        assert task_response.status_code == 201, task_response.text
        task = task_response.json()
        assert task["goal_id"] == goal_id
        assert task["assigned_section_id"] == "section-a"
        assert len(task["checklist_items"]) == 2

        teacher_tasks = client.get("/api/v1/tasks/my", headers=headers(teacher))
        assert teacher_tasks.status_code == 200
        assert [row["id"] for row in teacher_tasks.json()] == [task["id"]]

        other_tasks = client.get("/api/v1/tasks/my", headers=headers(other_teacher))
        assert other_tasks.status_code == 200
        assert other_tasks.json() == []

        parent_tasks = client.get("/api/v1/tasks", headers=headers(parent))
        assert parent_tasks.status_code == 403


def test_assignee_updates_progress_and_principal_closes_without_approval_side_effect(tmp_path: Path) -> None:
    with make_test_client(tmp_path) as client:
        principal = login(client, "principal", "principal123")
        teacher = login(client, "teacher", "teacher123")

        task_response = client.post(
            "/api/v1/tasks",
            headers=headers(principal),
            json={
                "title": "Prepare section readiness report",
                "description": "Operational task, not homework.",
                "priority": "normal",
                "scope_type": "staff",
                "scope_id": "staff-teacher-1",
                "assigned_staff_id": "staff-teacher-1",
                "checklist_items": [{"title": "Review timetable"}, {"title": "Submit notes"}],
            },
        )
        assert task_response.status_code == 201, task_response.text
        task = task_response.json()
        checklist_id = task["checklist_items"][0]["id"]

        progress_response = client.patch(
            f"/api/v1/tasks/{task['id']}/progress",
            headers=headers(teacher),
            json={
                "status": "in_progress",
                "progress_percent": 40,
                "evidence_url": "https://example.test/evidence/report.pdf",
            },
        )
        assert progress_response.status_code == 200, progress_response.text
        assert progress_response.json()["progress_percent"] == 40

        checklist_response = client.patch(
            f"/api/v1/tasks/{task['id']}/checklist/{checklist_id}",
            headers=headers(teacher),
            json={"completed": True},
        )
        assert checklist_response.status_code == 200
        assert checklist_response.json()["checklist_items"][0]["completed_by"] == "user-teacher"

        comment_response = client.post(
            f"/api/v1/tasks/{task['id']}/comments",
            headers=headers(teacher),
            json={"body": "Readiness report is being prepared."},
        )
        assert comment_response.status_code == 201
        assert len(comment_response.json()["comments"]) == 1

        complete_response = client.post(f"/api/v1/tasks/{task['id']}/complete", headers=headers(principal))
        assert complete_response.status_code == 200
        assert complete_response.json()["status"] == "completed"
        assert complete_response.json()["progress_percent"] == 100

        reopen_response = client.post(f"/api/v1/tasks/{task['id']}/reopen", headers=headers(principal))
        assert reopen_response.status_code == 200
        assert reopen_response.json()["status"] == "reopened"

        archive_response = client.post(f"/api/v1/tasks/{task['id']}/archive", headers=headers(principal))
        assert archive_response.status_code == 200
        assert archive_response.json()["status"] == "archived"

        from app.core import database

        assert database.SessionLocal is not None
        with database.SessionLocal() as db:
            assert db.query(ApprovalRequest).count() == 0
            assert db.query(AuditLog).count() >= 6
            assert db.query(NotificationLog).count() >= 1
