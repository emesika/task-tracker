# main.py
from contextlib import asynccontextmanager

from fastapi import FastAPI

from .database import engine, metadata
from .tasks_router import router as tasks_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    On startup: create tables if not exist.
    On shutdown: dispose the DB engine/pool.
    """
    # Startup
    async with engine.begin() as conn:
        await conn.run_sync(metadata.create_all)

    yield

    # Shutdown
    await engine.dispose()


app = FastAPI(
    title="Task Tracker API",
    description="A complete API for managing tasks, built with FastAPI and SQLAlchemy Core (async).",
    version="1.0.0",
    lifespan=lifespan,
)

# Routers
app.include_router(tasks_router)


@app.get("/", tags=["Root"])
def read_root() -> dict[str, str]:
    """Simple welcome endpoint for the API root."""
    return {"message": "Welcome to the Task Tracker API"}

