# database.py
from typing import AsyncGenerator

from pydantic_settings import BaseSettings
from pydantic import Field
import sqlalchemy
from sqlalchemy.ext.asyncio import create_async_engine, AsyncConnection


class Settings(BaseSettings):
    db_user: str = Field(default="postgres", alias="DB_USER")
    db_password: str = Field(default="password", alias="DB_PASSWORD")
    db_host: str = Field(default="localhost", alias="DB_HOST")
    db_name: str = Field(default="task_tracker_db", alias="DB_NAME")
    db_port: int = Field(default=5432, alias="DB_PORT")

    @property
    def database_url(self) -> str:
        return (
            f"postgresql+asyncpg://{self.db_user}:{self.db_password}"
            f"@{self.db_host}:{self.db_port}/{self.db_name}"
        )

settings = Settings()

# Async engine + connection pool
engine = create_async_engine(settings.database_url, echo=True)

# SQLAlchemy Core metadata & table
metadata = sqlalchemy.MetaData()

tasks_table = sqlalchemy.Table(
    "tasks",
    metadata,
    sqlalchemy.Column("id", sqlalchemy.Integer, primary_key=True),
    sqlalchemy.Column("title", sqlalchemy.String, nullable=False),
    sqlalchemy.Column("description", sqlalchemy.String, nullable=True),
    sqlalchemy.Column("completed", sqlalchemy.Boolean, nullable=False, server_default=sqlalchemy.text("false")),
)

async def get_connection() -> AsyncGenerator[AsyncConnection, None]:
    """
    FastAPI dependency that yields a single database connection
    for the duration of a request, and guarantees cleanup afterwards.
    """
    async with engine.connect() as conn:
        yield conn
