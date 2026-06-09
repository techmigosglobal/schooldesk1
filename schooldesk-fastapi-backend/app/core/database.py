from __future__ import annotations

from collections.abc import Generator
from pathlib import Path

from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.config import Settings, get_settings
from app.models.base import Base

engine: Engine | None = None
SessionLocal: sessionmaker[Session] | None = None


def configure_database(settings: Settings | None = None) -> None:
    global engine, SessionLocal
    settings = settings or get_settings()
    connect_args: dict[str, object] = {}
    engine_kwargs: dict[str, object] = {"future": True}
    if settings.database_url.startswith("sqlite"):
        connect_args["check_same_thread"] = False
        if settings.database_url.endswith(":memory:"):
            engine_kwargs["poolclass"] = StaticPool
    engine = create_engine(
        settings.database_url,
        connect_args=connect_args,
        **engine_kwargs,
    )
    SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)


def is_sqlite() -> bool:
    """Check if the current database is SQLite (development mode)."""
    if engine is None:
        return False
    return "sqlite" in str(engine.url).lower()


def is_postgresql() -> bool:
    """Check if the current database is PostgreSQL (production mode)."""
    if engine is None:
        return False
    return "postgresql" in str(engine.url).lower()


def run_alembic_migrations() -> None:
    """
    Run pending Alembic migrations.

    This is used for PostgreSQL in production. For SQLite in development,
    use create_schema() instead which uses Base.metadata.create_all().
    """
    from alembic.config import Config
    from alembic import command

    # Get the alembic.ini path relative to the project root
    project_root = Path(__file__).parent.parent.parent
    alembic_ini = project_root / "alembic.ini"

    if not alembic_ini.exists():
        raise FileNotFoundError(f"alembic.ini not found at {alembic_ini}")

    # Create Alembic configuration
    alembic_cfg = Config(str(alembic_ini))

    # Run migrations
    command.upgrade(alembic_cfg, "head")


def create_schema() -> None:
    """
    Create all database tables.

    For SQLite (development): Uses SQLAlchemy's Base.metadata.create_all()
    which is simpler and doesn't require running migrations.

    For PostgreSQL (production): This function runs Alembic migrations
    instead. It is recommended to run migrations manually using
    `alembic upgrade head` for production deployments.

    Note: This function is called automatically on app startup for
    development. In production, use Alembic migrations directly.
    """
    if engine is None:
        configure_database()

    assert engine is not None

    if is_postgresql():
        # For PostgreSQL, run Alembic migrations
        # In production, prefer running: alembic upgrade head
        run_alembic_migrations()
    else:
        # For SQLite (development), use Base.metadata.create_all
        Base.metadata.create_all(bind=engine)


def get_db() -> Generator[Session, None, None]:
    if SessionLocal is None:
        configure_database()
    assert SessionLocal is not None
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()