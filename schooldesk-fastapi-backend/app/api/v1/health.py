from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from redis import Redis, RedisError
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.config import Settings, get_settings
from app.core.database import get_db

router = APIRouter(tags=["health"])


@router.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "schooldesk-fastapi-backend"}


@router.get("/health/db")
def health_db(db: Session = Depends(get_db)) -> dict[str, str]:
    db.execute(text("SELECT 1"))
    return {"status": "ok", "database": "connected"}


@router.get("/health/redis")
def health_redis(settings: Settings = Depends(get_settings)) -> dict[str, str]:
    if not settings.redis_health_enabled:
        return {"status": "ok", "redis": "disabled"}
    client = Redis.from_url(settings.redis_url, socket_connect_timeout=2, socket_timeout=2)
    try:
        if not client.ping():
            raise HTTPException(status_code=503, detail="Redis ping failed")
    except RedisError as exc:
        raise HTTPException(status_code=503, detail=f"Redis unavailable: {exc}") from exc
    finally:
        client.close()
    return {"status": "ok", "redis": "connected"}
