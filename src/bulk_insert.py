import os
import argparse
import asyncio
from typing import List, Dict

try:
    # load .env if present (safe on host)
    from dotenv import load_dotenv  # python-dotenv
    load_dotenv()
except Exception:
    pass  # optional dependency

def set_env_overrides(args) -> None:
    """
    Override DB_* env for database.py before importing it.
    This way we reuse your project's async engine and tasks_table.
    """
    if args.host: os.environ["DB_HOST"] = args.host
    if args.port: os.environ["DB_PORT"] = str(args.port)
    if args.user: os.environ["DB_USER"] = args.user
    if args.password is not None: os.environ["DB_PASSWORD"] = args.password
    if args.name: os.environ["DB_NAME"] = args.name

def make_random_tasks(n: int) -> List[Dict]:
    import random
    words = ["alpha", "bravo", "charlie", "delta", "echo", "foxtrot", "golf", "hotel"]
    def w(): return random.choice(words)
    def phrase(): return f"{w().title()} {w()} {random.randint(1, 9999)}"
    return [{"title": phrase(), "description": f"{phrase()} {phrase()}", "completed": False} for _ in range(n)]

async def bulk_insert(n: int) -> int:
    # Import AFTER env overrides so database.py builds its engine correctly
    from sqlalchemy import insert
    from database import engine, tasks_table

    rows = make_random_tasks(n)
    async with engine.begin() as conn:
        stmt = insert(tasks_table).values(rows).returning(tasks_table.c.id)
        res = await conn.execute(stmt)
        created = res.scalars().all()
        # engine.begin() auto-commits on success
        return len(created)

async def main() -> None:
    parser = argparse.ArgumentParser(description="Async bulk insert N random tasks")
    parser.add_argument("N", type=int, help="Number of tasks to insert")
    parser.add_argument("--host", help="DB host (default: env DB_HOST or 'localhost' when run on host)")
    parser.add_argument("--port", type=int, help="DB port (default: env DB_PORT or 5432)")
    parser.add_argument("--user", help="DB user (default: env DB_USER or 'postgres')")
    parser.add_argument("--password", help="DB password (default: env DB_PASSWORD or 'password')")
    parser.add_argument("--name", help="DB name (default: env DB_NAME or 'task_tracker_db')")
    args = parser.parse_args()

    # If running on the host, 'localhost' is usually the right default
    if not os.getenv("DB_HOST") and not args.host:
        args.host = "localhost"

    set_env_overrides(args)

    try:
        count = await bulk_insert(args.N)
        print(f"Inserted {count} tasks successfully.")
    except Exception as e:
        # Helpful diagnostics
        host = os.getenv("DB_HOST", "<unset>")
        port = os.getenv("DB_PORT", "<unset>")
        name = os.getenv("DB_NAME", "<unset>")
        user = os.getenv("DB_USER", "<unset>")
        print(
            "Bulk insert failed.\n"
            f"DB_HOST={host} DB_PORT={port} DB_NAME={name} DB_USER={user}\n"
            f"Hint: when running on host, use --host localhost (or set DB_HOST=localhost)\n"
            f"Original error: {e}"
        )
        raise

if __name__ == "__main__":
    asyncio.run(main())
