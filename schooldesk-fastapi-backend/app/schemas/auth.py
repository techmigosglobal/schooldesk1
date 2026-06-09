from __future__ import annotations

from pydantic import BaseModel, Field


class LoginRequest(BaseModel):
    username: str = Field(min_length=1, max_length=80)
    password: str = Field(min_length=1, max_length=128)


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=1)


class ChangePasswordRequest(BaseModel):
    current_password: str = Field(min_length=1, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)


class CurrentUserResponse(BaseModel):
    id: str
    school_id: str
    username: str
    full_name: str
    role: str
    linked_type: str | None = None
    linked_id: str | None = None
    permissions: list[str]
    class_teacher_sections: list[str]
