from __future__ import annotations

import pytest
from fastapi import HTTPException

from app.api.v1.health import health_redis
from app.core.cache import get_cache
from app.core.config import Settings
from app.models import Base


def test_database_url_accepts_postgres_aliases(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("SCHOOLDESK_DATABASE_URL", raising=False)
    monkeypatch.setenv("DATABASE_URL", "postgres://school:secret@postgres:5432/schooldesk?sslmode=disable")

    settings = Settings(jwt_secret_key="test-secret-key-for-schooldesk-fastapi")

    assert settings.database_url == "postgresql+psycopg://school:secret@postgres:5432/schooldesk?sslmode=disable"


def test_schooldesk_database_url_overrides_legacy_database_url(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DATABASE_URL", "postgres://legacy:legacy@postgres:5432/legacy")
    monkeypatch.setenv("SCHOOLDESK_DATABASE_URL", "postgresql://schooldesk:secret@postgres:5432/schooldesk")

    settings = Settings(jwt_secret_key="test-secret-key-for-schooldesk-fastapi")

    assert settings.database_url == "postgresql+psycopg://schooldesk:secret@postgres:5432/schooldesk"


def test_redis_url_accepts_legacy_env_name(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("SCHOOLDESK_REDIS_URL", raising=False)
    monkeypatch.setenv("REDIS_URL", "redis://redis:6379/3")

    settings = Settings(jwt_secret_key="test-secret-key-for-schooldesk-fastapi")

    assert settings.redis_url == "redis://redis:6379/3"


def test_all_database_models_are_registered_for_migrations() -> None:
    expected_tables = {
        "academic_terms",
        "academic_years",
        "app_records",
        "approval_requests",
        "audit_logs",
        "exam_marks",
        "exams",
        "fee_structures",
        "goal_key_results",
        "goals",
        "grade_subjects",
        "grades",
        "guardians",
        "leave_applications",
        "leave_balances",
        "leave_types",
        "notification_logs",
        "permissions",
        "role_permissions",
        "roles",
        "rooms",
        "schools",
        "sections",
        "staff",
        "staff_attendance",
        "staff_subjects",
        "student_attendance",
        "student_leave_applications",
        "students",
        "subjects",
        "task_checklist_items",
        "task_comments",
        "tasks",
        "timetable_slots",
        "user_roles",
        "users",
        "vps_fees",
    }

    assert expected_tables.issubset(set(Base.metadata.tables))


def test_cache_reinitializes_when_redis_url_changes() -> None:
    first = get_cache("redis://localhost:1/0")
    second = get_cache("redis://localhost:2/0")

    assert first is not second
    assert second.redis_url == "redis://localhost:2/0"


def test_redis_health_disabled_is_explicit() -> None:
    settings = Settings(
        redis_health_enabled=False,
        jwt_secret_key="test-secret-key-for-schooldesk-fastapi",
    )

    assert health_redis(settings) == {"status": "ok", "redis": "disabled"}


def test_redis_health_unavailable_returns_503() -> None:
    settings = Settings(
        redis_url="redis://localhost:1/0",
        redis_health_enabled=True,
        jwt_secret_key="test-secret-key-for-schooldesk-fastapi",
    )

    with pytest.raises(HTTPException) as exc:
        health_redis(settings)

    assert exc.value.status_code == 503
    assert "Redis unavailable" in str(exc.value.detail)
