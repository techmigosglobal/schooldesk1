from __future__ import annotations

from functools import lru_cache

from pydantic import AliasChoices, Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="SCHOOLDESK_",
        env_file=(".env", ".env.local"),
        env_file_encoding="utf-8",
        extra="ignore",
        populate_by_name=True,
    )

    environment: str = "local"
    database_url: str = Field(
        default="sqlite+pysqlite:///./schooldesk_fastapi.db",
        validation_alias=AliasChoices("SCHOOLDESK_DATABASE_URL", "DATABASE_URL"),
    )
    redis_url: str = Field(
        default="redis://localhost:6380/0",
        validation_alias=AliasChoices("SCHOOLDESK_REDIS_URL", "REDIS_URL"),
    )
    redis_health_enabled: bool = True
    jwt_secret_key: str = Field(default="change-this-local-secret", min_length=16)
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    seed_on_start: bool = True
    cors_allow_origins: str = ""
    cors_allow_origin_regex: str | None = (
        r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"
    )

    @field_validator("database_url")
    @classmethod
    def normalize_database_url(cls, value: str) -> str:
        if value.startswith("postgres://"):
            return f"postgresql+psycopg://{value.removeprefix('postgres://')}"
        if value.startswith("postgresql://"):
            return f"postgresql+psycopg://{value.removeprefix('postgresql://')}"
        return value

    @property
    def cors_origin_list(self) -> list[str]:
        return [
            origin.strip()
            for origin in self.cors_allow_origins.split(",")
            if origin.strip()
        ]


@lru_cache
def get_settings() -> Settings:
    return Settings()
