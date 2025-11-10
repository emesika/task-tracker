# pydantic_models.py
from typing import Optional
from pydantic import BaseModel, ConfigDict


class TaskBase(BaseModel):
    title: str
    description: Optional[str] = None


class TaskCreate(TaskBase):
    """Payload for creating a task."""
    pass


class TaskUpdate(BaseModel):
    """Payload for updating (partial) fields."""
    title: Optional[str] = None
    description: Optional[str] = None
    completed: Optional[bool] = None


class Task(TaskBase):
    """Full Task representation."""
    id: int
    completed: bool

    # Pydantic v2: allow building from attribute-based objects / rows
    model_config = ConfigDict(from_attributes=True)

