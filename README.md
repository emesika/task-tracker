Here is a reformatted version of your `README.md` file, designed for clarity, organization, and readability.

-----

# 📝 Task Tracker API

A high-performance task management API built with FastAPI and SQLAlchemy Core, designed for asynchronous operations.

-----

## 🚀 Installation

1.  **Clone the repository:**

    ```bash
    git clone https://github.com/emesika/task-tracker.git
    cd task-tracker
    ```

2.  **Set up the environment and install dependencies:**
    (This assumes you have [PDM](https://pdm.fming.dev/) installed.)

    ```bash
    pdm use python3.12
    pdm venv create --force
    pdm venv activate
    pdm install
    ```

3.  **Activate the environment (if not already active):**

    ```bash
    source .venv/bin/activate
    ```

-----

## ⚙️ Environment Variables
    
    
    source .env

-----

> **Note:** For the benchmark script, DB_HOST should be `localhost`.

-----

## 🏃 Running the Application

### Main Application (via Docker)

These scripts will clean up old containers, run a new database container, and run the application container.

1.  **Source your environment variables:**

    ```bash
    source .env
    ```

2.  **Run the helper scripts in order:**

    ```bash
    ./cleanup_task_tracker_env.sh
    ./run_db_container.sh
    ./run_task_tracker_app_container.sh
    ```

### Benchmark Script

This script runs locally to insert a specified number of tasks (e.g., 10,000) for performance testing.

1.  **Source your environment variables:**

    ```bash
    source .env
    ```

2.  **Export `DB_HOST` for local connection:**

    ```bash
    export DB_HOST=localhost
    ```

3.  **Run the benchmark script:**

    ```bash
    # Usage: python3 benchmark.py <number_of_tasks>
    python3 benchmark.py 10000
    ```

-----

## 📚 API Documentation

Once the main application is running, the interactive API documentation is available at:

  * **Swagger UI:** [http://localhost:8000/docs](https://www.google.com/search?q=http://localhost:8000/docs)
  * **ReDoc:** [http://localhost:8000/redoc](https://www.google.com/search?q=http://localhost:8000/redoc)

-----

## 🏗️ Project Structure and Code Organization

The project is organized into a few focused modules. Here’s a breakdown of each file and its responsibilities:

### `main.py` - Application Entry Point

This file ties everything together, configures the app, and includes the necessary routers.

  * **Responsibilities:**
      * Creates the main `FastAPI` app instance (setting title, description, version).
      * Defines a `lifespan` async context manager to handle startup/shutdown events (creating tables on startup, disposing the engine on shutdown).
      * Includes the routers (e.g., mounting the tasks router).
      * Defines a simple root endpoint (`GET /`) for a welcome message.

### `database.py` - Database Configuration

This file encapsulates all database-related setup and utilities.

  * **Responsibilities:**
      * Reads environment variables (`DB_USER`, `DB_PASSWORD`, etc.) to build the `DATABASE_URL`.
      * Creates the `async_engine` and a `MetaData` object.
      * Defines the `tasks_table` schema using `sqlalchemy.Table` (with columns: `id`, `title`, `description`, `completed`).
      * Provides the FastAPI dependency `get_connection()` to yield an `AsyncConnection` for use in route functions.

### `pydantic_models.py` - Pydantic Data Schemas

This file defines the data shapes for API validation and serialization.

  * **Responsibilities:**
      * **`TaskBase`**: Defines common fields (`title`, `description`).
      * **`TaskCreate`**: Inherits from `TaskBase` for use in `POST` requests.
      * **`TaskUpdate`**: Defines optional fields for `PUT` requests (partial updates).
      * **`Task`**: Extends `TaskBase` with `id` and `completed` fields; used as the response model.
      * Uses `ConfigDict(from_attributes=True)` (Pydantic v2) to allow models to be created from database row attributes (replaces `orm_mode`).

### `tasks_router.py` - Task API Endpoints

This file defines all the CRUD (Create, Read, Update, Delete) API endpoints for task management.

  * **Responsibilities:**
      * Creates an `APIRouter` with the `/tasks` prefix.
      * Uses `Depends(get_connection)` on each route to automatically provide a database connection.
      * Defines the following endpoints:
          * **`POST /tasks/` (create\_task):** Creates a new task.
          * **`GET /tasks/` (read\_tasks):** Fetches a list of tasks with optional pagination (`skip`, `limit`).
          * **`GET /tasks/{task_id}` (read\_task):** Retrieves a single task by ID; raises `404` if not found.
          * **`PUT /tasks/{task_id}` (update\_task):** Updates an existing task; supports partial updates and raises `404` if not found.
          * **`DELETE /tasks/{task_id}` (delete\_task):** Deletes a task by ID; raises `404` if not found and returns `204 No Content` on success.

> ### A Note on File Organization
>
> This project follows a common FastAPI structure to ensure scalability and separation of concerns:
>
>   * `main.py` is kept minimal, acting as the app assembler.
>   * Business logic for different resources (e.g., "tasks") is split into modules within a `tasks_router.py`.
>   * Database setup is encapsulated in `database.py`.
>   * Data schemas are centralized in `pydantic_models.py`.
