import logging
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from prometheus_fastapi_instrumentator import Instrumentator
from sqlalchemy import text
from sqlalchemy.orm import Session

from app import crud, schemas
from app.config import get_settings
from app.database import get_db, init_db
from app.logging_config import configure_logging

configure_logging()
logger = logging.getLogger("app")

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("starting up", extra={"environment": settings.environment, "version": settings.app_version})
    init_db()
    yield


app = FastAPI(title=settings.app_name, version=settings.app_version, lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in settings.cors_allowed_origins.split(",")],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Exposes /metrics in Prometheus text format (http_requests_total,
# http_request_duration_seconds, ...) - scraped by the backend ServiceMonitor,
# see kubernetes/helm/backend/templates/servicemonitor.yaml.
Instrumentator().instrument(app).expose(app, include_in_schema=False)


@app.get("/health", response_model=schemas.HealthOut, tags=["health"])
def health() -> schemas.HealthOut:
    """Liveness endpoint - does not touch the database."""
    return schemas.HealthOut(
        status="ok", environment=settings.environment, version=settings.app_version
    )


@app.get("/api/health", response_model=schemas.ApiHealthOut, tags=["health"])
def api_health(db: Session = Depends(get_db)) -> schemas.ApiHealthOut:
    """Readiness endpoint - verifies database connectivity."""
    try:
        db.execute(text("SELECT 1"))
        db_status = "ok"
    except Exception:  # noqa: BLE001
        logger.exception("database health check failed")
        db_status = "unavailable"

    return schemas.ApiHealthOut(
        status="ok" if db_status == "ok" else "degraded",
        environment=settings.environment,
        version=settings.app_version,
        database=db_status,
    )


@app.get("/api/items", response_model=list[schemas.ItemOut], tags=["items"])
def read_items(db: Session = Depends(get_db)) -> list[schemas.ItemOut]:
    return crud.list_items(db)


@app.post("/api/items", response_model=schemas.ItemOut, status_code=status.HTTP_201_CREATED, tags=["items"])
def create_item(item: schemas.ItemCreate, db: Session = Depends(get_db)) -> schemas.ItemOut:
    return crud.create_item(db, item)


@app.get("/api/items/{item_id}", response_model=schemas.ItemOut, tags=["items"])
def read_item(item_id: int, db: Session = Depends(get_db)) -> schemas.ItemOut:
    db_item = crud.get_item(db, item_id)
    if db_item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
    return db_item


@app.delete("/api/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["items"])
def delete_item(item_id: int, db: Session = Depends(get_db)) -> None:
    if not crud.delete_item(db, item_id):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
