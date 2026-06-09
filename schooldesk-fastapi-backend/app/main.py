from __future__ import annotations

import traceback
import uuid
from contextlib import asynccontextmanager
from collections.abc import AsyncIterator

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, RedirectResponse
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

from app.api.v1.router import router
from app.core.config import Settings, get_settings
from app.core import database
from app.core.cache import get_cache
from app.core.limiter import limiter
from app.core.logging_config import configure_logging, get_logger
from app.seed.defaults import seed_defaults


def create_app(settings: Settings | None = None) -> FastAPI:
    app_settings = settings or get_settings()

    # Configure structured logging
    configure_logging(app_settings.environment)
    logger = get_logger(__name__)

    database.configure_database(app_settings)

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        # Initialize cache on startup
        cache = get_cache(app_settings.redis_url)
        logger.info("application_startup", environment=app_settings.environment)
        # For SQLite (development): create schema using Base.metadata
        # For PostgreSQL (production): use Alembic migrations instead
        #   Run: alembic upgrade head
        if not database.is_postgresql():
            database.create_schema()
        if app_settings.seed_on_start:
            assert database.SessionLocal is not None
            with database.SessionLocal() as db:
                seed_defaults(db)
        yield
        logger.info("application_shutdown")

    app = FastAPI(
        title="SchoolDesk FastAPI Backend",
        version="0.1.0",
        description="Independent FastAPI backend for SchoolDesk modules.",
        lifespan=lifespan,
    )

    # Add rate limiter to app state
    app.state.limiter = limiter

    app.dependency_overrides[get_settings] = lambda: app_settings
    app.add_middleware(
        CORSMiddleware,
        allow_origins=app_settings.cors_origin_list,
        allow_origin_regex=app_settings.cors_allow_origin_regex,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Request ID middleware
    @app.middleware("http")
    async def add_request_id(request: Request, call_next):
        request_id = str(uuid.uuid4())
        request.state.request_id = request_id
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        return response

    # Security headers middleware
    @app.middleware("http")
    async def security_headers(request: Request, call_next):
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        return response

    @app.get("/", include_in_schema=False)
    @app.get("/api/v1", include_in_schema=False)
    def docs_root_redirect() -> RedirectResponse:
        return RedirectResponse(url="/docs")

    @app.get("/api/docs", include_in_schema=False)
    @app.get("/api/v1/docs", include_in_schema=False)
    def api_docs_redirect() -> RedirectResponse:
        return RedirectResponse(url="/docs")

    @app.get("/api/openapi.json", include_in_schema=False)
    @app.get("/api/v1/openapi.json", include_in_schema=False)
    def api_openapi_redirect() -> RedirectResponse:
        return RedirectResponse(url="/openapi.json")

    # Rate limit exception handler
    @app.exception_handler(RateLimitExceeded)
    async def rate_limit_handler(request: Request, exc: RateLimitExceeded):
        client_ip = get_remote_address(request) if app_settings.environment != "testing" else "test"
        logger.warning("rate_limit_exceeded", path=request.url.path, ip=client_ip)
        return JSONResponse(
            {"detail": "Rate limit exceeded", "retry_after": str(exc.detail)},
            status_code=429,
        )

    # Global exception handler
    @app.exception_handler(Exception)
    async def global_exception_handler(request: Request, exc: Exception):
        logger.error(
            "unhandled_exception",
            path=request.url.path,
            method=request.method,
            error=str(exc),
            traceback=traceback.format_exc(),
        )
        return JSONResponse(
            status_code=500,
            content={"detail": "Internal server error", "success": False},
        )

    app.include_router(router)
    return app


app = create_app()