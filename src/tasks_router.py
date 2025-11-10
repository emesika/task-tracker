# tasks_router.py
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy import select, insert, update, delete
from sqlalchemy.ext.asyncio import AsyncConnection

from .database import tasks_table, get_connection
from .pydantic_models import Task, TaskCreate, TaskUpdate

router = APIRouter(
    prefix="/tasks",
    tags=["Tasks"],
    responses={404: {"description": "Task not found"}},
)

# ---------- Helpers ----------

async def get_task_by_id(conn: AsyncConnection, task_id: int) -> Optional[Task]:
    """
    Fetch a single task row by id and return as Pydantic Task, or None if not found.
    """
    stmt = select(tasks_table).where(tasks_table.c.id == task_id)
    result = await conn.execute(stmt)
    row = result.mappings().first()
    if row is None:
        return None
    return Task.model_validate(row)  # mappings() returns a dict-like row


# ---------- Routes ----------

@router.post("/", response_model=Task, status_code=201)
async def create_task(task: TaskCreate, conn: AsyncConnection = Depends(get_connection)) -> Task:
    """
    Create a new task and return the created row.
    """
    stmt = (
        insert(tasks_table)
        .values(title=task.title, description=task.description, completed=False)
        .returning(tasks_table)
    )
    result = await conn.execute(stmt)
    await conn.commit()

    row = result.mappings().first()
    return Task.model_validate(row)


@router.get("/", response_model=list[Task])
async def read_tasks(
    skip: int = 0,
    limit: int = 10,
    conn: AsyncConnection = Depends(get_connection),
) -> list[Task]:
    """
    Retrieve a paginated list of tasks.
    """
    stmt = (
        select(tasks_table)
        .order_by(tasks_table.c.id.asc())
        .offset(skip)
        .limit(limit)
    )
    result = await conn.execute(stmt)
    rows = result.mappings().all()
    return [Task.model_validate(row) for row in rows]


@router.get("/{task_id}", response_model=Task)
async def read_task(task_id: int, conn: AsyncConnection = Depends(get_connection)) -> Task:
    """
    Retrieve a single task by its ID.
    """
    task = await get_task_by_id(conn, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    return task


@router.put("/{task_id}", response_model=Task)
async def update_task(
    task_id: int,
    payload: TaskUpdate,
    conn: AsyncConnection = Depends(get_connection),
) -> Task:
    """
    Update an existing task's title, description, or completed flag.
    """
    # Ensure it exists
    current = await get_task_by_id(conn, task_id)
    if current is None:
        raise HTTPException(status_code=404, detail="Task not found")

    update_data = payload.model_dump(exclude_unset=True)
    if not update_data:
        raise HTTPException(status_code=400, detail="No update data provided")

    stmt = (
        update(tasks_table)
        .where(tasks_table.c.id == task_id)
        .values(**update_data)
        .returning(tasks_table)
    )
    result = await conn.execute(stmt)
    await conn.commit()

    row = result.mappings().first()
    return Task.model_validate(row)


@router.delete("/{task_id}", status_code=204)
async def delete_task(task_id: int, conn: AsyncConnection = Depends(get_connection)) -> Response:
    """
    Delete a task by its ID.
    """
    # Ensure it exists
    current = await get_task_by_id(conn, task_id)
    if current is None:
        raise HTTPException(status_code=404, detail="Task not found")

    stmt = delete(tasks_table).where(tasks_table.c.id == task_id)
    await conn.execute(stmt)
    await conn.commit()

    return Response(status_code=204)
