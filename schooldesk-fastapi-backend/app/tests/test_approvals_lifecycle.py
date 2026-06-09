from __future__ import annotations

from collections.abc import Iterator
from pathlib import Path

import pytest
from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.api.v1 import approvals as approvals_api
from app.core import database
from app.core.config import Settings
from app.dependencies.auth import CurrentUser
from app.models.auth import User
from app.models.goal_task import AuditLog, NotificationLog
from app.seed.defaults import seed_defaults


@pytest.fixture
def db_session(tmp_path: Path) -> Iterator[Session]:
    settings = Settings(
        database_url=f"sqlite+pysqlite:///{tmp_path / 'schooldesk-approvals-test.db'}",
        redis_health_enabled=False,
        seed_on_start=False,
        jwt_secret_key="test-secret-key-for-schooldesk-fastapi",
    )
    database.configure_database(settings)
    database.create_schema()
    assert database.SessionLocal is not None
    with database.SessionLocal() as db:
        seed_defaults(db)
    with database.SessionLocal() as db:
        yield db


def current_user(db: Session, user_id: str, *, school_id: str | None = None, role: str | None = None) -> CurrentUser:
    user = db.get(User, user_id)
    if user is None:
        return CurrentUser(
            id=user_id,
            school_id=school_id or "missing-school",
            username=user_id,
            full_name=user_id,
            role=role or "principal",
            linked_type=None,
            linked_id=None,
            permissions=frozenset(),
            class_teacher_sections=(),
        )
    return CurrentUser(
        id=user.id,
        school_id=school_id or user.school_id,
        username=user.username,
        full_name=user.full_name,
        role=(role or user.role).lower(),
        linked_type=user.linked_type,
        linked_id=user.linked_id,
        permissions=frozenset(),
        class_teacher_sections=(),
    )


def assert_http_error(status_code: int, detail: str, func, *args, **kwargs) -> None:
    with pytest.raises(HTTPException) as exc:
        func(*args, **kwargs)
    assert exc.value.status_code == status_code
    assert exc.value.detail == detail


def test_approval_detail_patch_lifecycle_and_guardrails(db_session: Session) -> None:
    db = db_session
    principal = current_user(db, "user-principal")
    admin = current_user(db, "user-admin")
    parent = current_user(db, "user-parent")
    guardian = current_user(db, "user-guardian", school_id=principal.school_id, role="guardian")
    other_principal = current_user(db, "user-other-principal", school_id="other-school", role="principal")

    registered_routes = {
        (route.path, method)
        for route in approvals_api.router.routes
        for method in getattr(route, "methods", set())
    }
    assert ("/api/v1/approvals/{approval_id}", "GET") in registered_routes
    assert ("/api/v1/approvals/{approval_id}", "PATCH") in registered_routes

    create_response = approvals_api.create_approval(
        {
            "module": "students",
            "operation_type": "create",
            "entity_type": "student",
            "status": "draft",
            "title": "Create guarded student",
            "details": "Initial draft.",
            "payload_json": {"student_code": "STU-GUARD"},
        },
        db,
        admin,
    )
    approval_id = create_response["data"]["id"]
    assert create_response["data"]["status"] == "draft"

    detail_response = approvals_api.approval_detail(approval_id, db, admin)
    assert detail_response["data"]["id"] == approval_id

    patch_response = approvals_api.update_approval(
        approval_id,
        {
            "details": "Patched draft details.",
            "payload_json": {"student_code": "STU-GUARD", "ready": True},
        },
        db,
        admin,
    )
    assert patch_response["data"]["details"] == "Patched draft details."

    principal_create = approvals_api.create_approval(
        {
            "module": "staff",
            "operation_type": "update",
            "status": "submitted",
            "title": "Principal-owned request",
        },
        db,
        principal,
    )
    principal_approval_id = principal_create["data"]["id"]

    admin_list = approvals_api.approvals(db=db, current_user=admin)
    assert [row["id"] for row in admin_list["data"]] == [approval_id]
    assert_http_error(
        403,
        "Approval request is outside your scope",
        approvals_api.approval_detail,
        principal_approval_id,
        db,
        admin,
    )

    for denied_user in (parent, guardian):
        assert_http_error(
            403,
            "Principal or Admin access required",
            approvals_api.approvals,
            db=db,
            current_user=denied_user,
        )
        assert_http_error(403, "Approval access denied", approvals_api.approval_detail, approval_id, db, denied_user)

    assert_http_error(
        404,
        "Approval request not found",
        approvals_api.approval_detail,
        approval_id,
        db,
        other_principal,
    )
    assert approvals_api.approvals(db=db, current_user=other_principal)["data"] == []

    for action, payload in [
        (approvals_api.approve_approval, {"note": "Admin should not approve."}),
        (approvals_api.reject_approval, {"reason": "Admin should not reject."}),
        (approvals_api.request_changes, {"note": "Admin should not request changes."}),
    ]:
        assert_http_error(403, "Principal approval authority required", action, approval_id, payload, db, admin)
    assert_http_error(
        403,
        "Principal approval authority required",
        approvals_api.apply_approval,
        approval_id,
        db,
        admin,
    )

    submit_response = approvals_api.submit_approval(approval_id, db, admin)
    assert submit_response["data"]["status"] == "pending"

    assert_http_error(400, "note is required", approvals_api.request_changes, approval_id, {}, db, principal)
    assert_http_error(400, "reason is required", approvals_api.reject_approval, approval_id, {}, db, principal)
    assert_http_error(
        400,
        "reason is required",
        approvals_api.alias_update,
        "account-approvals",
        approval_id,
        {"status": "rejected"},
        db,
        principal,
    )

    change_response = approvals_api.request_changes(approval_id, {"note": "Attach the guardian proof."}, db, principal)
    assert change_response["data"]["status"] == "changes_requested"

    resubmit_response = approvals_api.submit_approval(approval_id, db, admin)
    assert resubmit_response["data"]["status"] == "pending"

    approve_response = approvals_api.approve_approval(approval_id, {"note": "Evidence complete."}, db, principal)
    assert approve_response["data"]["status"] == "approved"

    assert_http_error(
        403,
        "Principal approval authority required",
        approvals_api.apply_approval,
        approval_id,
        db,
        admin,
    )

    apply_response = approvals_api.apply_approval(approval_id, db, principal)
    assert apply_response["data"]["status"] == "applied"
    assert "no sensitive school mutation" in apply_response["data"]["apply_note"]

    assert_http_error(
        409,
        "Approval request has already been applied",
        approvals_api.apply_approval,
        approval_id,
        db,
        principal,
    )

    audit_actions = {
        row.action
        for row in db.query(AuditLog)
        .filter(AuditLog.module == "approvals", AuditLog.entity_id == approval_id)
        .all()
    }
    notification_titles = {
        row.title
        for row in db.query(NotificationLog)
        .filter(NotificationLog.reference_type == "approval", NotificationLog.reference_id == approval_id)
        .all()
    }

    assert {"create", "update", "submit", "request_changes", "approve", "apply_mark"} <= audit_actions
    assert {
        "Approval requested: Create guarded student",
        "Approval submitted",
        "Approval changes requested",
        "Approval approved",
        "Approval applied",
    } <= notification_titles
