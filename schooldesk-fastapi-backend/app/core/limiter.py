from __future__ import annotations

from slowapi import Limiter
from slowapi.util import get_remote_address

# In testing mode the limiter key is always "test" and shared across all requests
# so a 99999/min limit effectively disables enforcement while still registering hits


def _limiter_key(request: Request | None = None) -> str:
    try:
        from app.core.config import get_settings

        settings = get_settings()
    except Exception:
        return "unknown"
    if settings.environment == "testing":
        return "test"
    if request is None:
        return "default"
    return get_remote_address(request)


# Module-level limiter – imported by auth.py, goals.py, and main.py
limiter = Limiter(key_func=_limiter_key)

# Override limit value when in testing so limits never fire
_shared_limit_lit = "99999/minute"


def _limit_for_auth(request: Request | None = None) -> str:
    """Return rate limit string: tight in production, effectively disabled in testing."""
    try:
        from app.core.config import get_settings

        settings = get_settings()
    except Exception:
        return "10/minute"
    if settings.environment == "testing":
        return "99999/minute"
    return "10/minute"


def _limit_for_reads(request: Request | None = None) -> str:
    """Return rate limit string for read (GET) operations."""
    try:
        from app.core.config import get_settings

        settings = get_settings()
    except Exception:
        return "100/minute"
    if settings.environment == "testing":
        return "99999/minute"
    return "100/minute"


def _limit_for_writes(request: Request | None = None) -> str:
    """Return rate limit string for write (POST/PUT/DELETE) operations."""
    try:
        from app.core.config import get_settings

        settings = get_settings()
    except Exception:
        return "30/minute"
    if settings.environment == "testing":
        return "99999/minute"
    return "30/minute"


def get_limiter() -> Limiter:
    return limiter