from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from app.config import get_settings

settings = get_settings()

engine = create_engine(settings.database_url, pool_pre_ping=True, pool_size=5, max_overflow=10)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db() -> None:
    """Create tables if they do not exist.

    For this portfolio project a simple create_all() is used instead of a
    full migration framework (e.g. Alembic) to keep the demo focused. In a
    real production system, replace this with versioned migrations.
    """
    from app import models  # noqa: F401  (ensure models are registered)

    Base.metadata.create_all(bind=engine)
