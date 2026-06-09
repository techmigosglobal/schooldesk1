from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any

import jwt
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings, get_settings
from app.core.database import get_db
from app.core.logging_config import get_logger
from app.core.security import create_access_token, decode_access_token, hash_password, verify_password
from app.dependencies.auth import CurrentUser, get_current_user
from app.models.auth import Role, User
from app.schemas.auth import ChangePasswordRequest, CurrentUserResponse, LoginRequest, RefreshRequest

logger = get_logger(__name__)

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


def _success(data: Any = None, message: str = "Operation completed successfully") -> dict[str, Any]:
    return {"success": True, "message": message, "data": data, "meta": {}}


def _role_id(db: Session, user: User) -> str:
    role = db.scalar(select(Role).where(Role.school_id == user.school_id, Role.name == user.role.lower()))
    return role.id if role is not None else user.role.lower()


def _user_payload(db: Session, user: User) -> dict[str, Any]:
    return {
        "id": user.id,
        "username": user.username,
        "name": user.full_name,
        "email": "",
        "phone": "",
        "avatar": "",
        "school_id": user.school_id,
        "role_id": _role_id(db, user),
        "role_name": user.role.lower(),
        "linked_type": user.linked_type or "",
        "linked_id": user.linked_id or "",
        "is_active": user.is_active,
    }


def _login_payload(db: Session, settings: Settings, user: User) -> dict[str, Any]:
    token = create_access_token(settings, user_id=user.id, role=user.role)
    expires_at = int(
        (datetime.now(UTC) + timedelta(minutes=settings.access_token_expire_minutes)).timestamp()
    )
    return {
        "token": token,
        "refresh_token": token,
        "expires_at": expires_at,
        "user": _user_payload(db, user),
    }


@router.post("/login")
def login(
    payload: LoginRequest,
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings),
) -> dict[str, Any]:
    user = db.scalar(select(User).where(User.username == payload.username.strip()))
    if user is None or not user.is_active or not verify_password(payload.password, user.password_hash):
        logger.warning("login_failed", username=payload.username.strip())
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    logger.info("login_success", user_id=user.id, username=user.username)
    data = _login_payload(db, settings, user)
    response = _success(data=data, message="Login successful")
    response["access_token"] = data["token"]
    response["token_type"] = "bearer"
    return response


@router.post("/refresh")
def refresh(
    payload: RefreshRequest,
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings),
) -> dict[str, Any]:
    try:
        decoded = decode_access_token(settings, payload.refresh_token)
    except jwt.PyJWTError as exc:
        logger.warning("refresh_failed", error="invalid_token")
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token") from exc
    user = db.get(User, decoded.get("sub"))
    if user is None or not user.is_active:
        logger.warning("refresh_failed", error="inactive_user")
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Inactive or missing user")
    logger.info("refresh_success", user_id=user.id)
    return _success(
        data=_login_payload(db, settings, user),
        message="Session refreshed",
    )


@router.post("/logout")
def logout(current_user: CurrentUser = Depends(get_current_user)) -> dict[str, Any]:
    return _success(data={"user_id": current_user.id}, message="Logged out")


@router.get("/profile")
def profile(
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    user = db.get(User, current_user.id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing user")
    return _success(data=_user_payload(db, user))


@router.patch("/profile")
def update_profile(
    payload: dict[str, Any],
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    user = db.get(User, current_user.id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing user")
    name = str(payload.get("name") or payload.get("full_name") or "").strip()
    if name:
        user.full_name = name
        db.commit()
        db.refresh(user)
    return _success(data=_user_payload(db, user), message="Profile updated")


@router.post("/password")
def change_password(
    payload: ChangePasswordRequest,
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    user = db.get(User, current_user.id)
    if user is None or not verify_password(payload.current_password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Current password is incorrect")
    user.password_hash = hash_password(payload.new_password)
    db.commit()
    return _success(message="Password updated")


@router.get("/me", response_model=CurrentUserResponse)
def me(current_user: CurrentUser = Depends(get_current_user)) -> CurrentUserResponse:
    return CurrentUserResponse(
        id=current_user.id,
        school_id=current_user.school_id,
        username=current_user.username,
        full_name=current_user.full_name,
        role=current_user.role,
        linked_type=current_user.linked_type,
        linked_id=current_user.linked_id,
        permissions=sorted(current_user.permissions),
        class_teacher_sections=list(current_user.class_teacher_sections),
    )
