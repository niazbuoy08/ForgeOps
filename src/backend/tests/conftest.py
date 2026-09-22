import os

os.environ.setdefault("DB_HOST", "localhost")
os.environ.setdefault("DB_NAME", "test.db")

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.main as main_module
from app.database import Base, get_db
from app.main import app

# Use an in-memory SQLite database for fast, isolated unit tests instead of
# requiring a real PostgreSQL instance.
TEST_ENGINE = create_engine(
    "sqlite:///:memory:",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=TEST_ENGINE)


@pytest.fixture(autouse=True)
def _setup_database():
    Base.metadata.create_all(bind=TEST_ENGINE)
    yield
    Base.metadata.drop_all(bind=TEST_ENGINE)


@pytest.fixture()
def client(monkeypatch):
    def override_get_db():
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db
    # The app's startup event calls init_db(), which otherwise targets the
    # real PostgreSQL engine built from env vars. Tables for the test run
    # are already created against TEST_ENGINE above, so make startup a no-op.
    monkeypatch.setattr(main_module, "init_db", lambda: None)

    from fastapi.testclient import TestClient

    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()
