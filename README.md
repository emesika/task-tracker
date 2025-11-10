# task-tracker
A simple Task Tracker application demonstrating FlaskAPI and Uvicorn

Project Structure and Code Organization

The project is organized into a few focused modules. Here’s a breakdown of each file and its responsibilities:

main.py: The application entry point. It creates the FastAPI app object (including title, description, version). It defines the lifespan async context manager to handle startup/shutdown events (creating tables on startup, disposing the engine on shutdown). It then includes the routers (mounting the tasks router under its prefixes), and it also defines a simple root endpoint (GET /) that returns a welcome message. This file essentially ties everything together – it doesn’t contain business logic, but configures the app’s behavior.

database.py: Database configuration and utilities. This file sets up the async database engine and defines the schema using SQLAlchemy Core. It reads environment variables for DB credentials (DB_USER, DB_PASSWORD, etc.) and builds the DATABASE_URL. Then it creates the engine with create_async_engine and a MetaData object to hold table definitions. It defines the tasks_table schema (with columns id, title, description, completed) using sqlalchemy.Table. This file also provides the FastAPI dependency get_connection() which, as described, yields an AsyncConnection for use in route functions. In summary, database.py encapsulates all DB-related setup so other parts of the app can just use a connection or refer to the table definition.

pydantic_models.py: Pydantic model definitions for the API. It defines data schemas for tasks in different scenarios:

TaskBase with common fields (title, description).

TaskCreate inheriting from TaskBase (same fields, used for POST requests).

TaskUpdate allowing optional title, description, completed (all fields optional so you can send any subset to update).

Task model extending TaskBase with id and completed fields, representing a full task object as stored in the DB. This model is used as the response model for many endpoints. The ConfigDict(from_attributes=True) on Task is a Pydantic v2 feature that replaces orm_mode=True from v1; it lets Pydantic create a Task from attributes of another object (like a SQLAlchemy row or an ORM instance). This is why the code can return a DB row and still get a proper JSON response.

These models enforce types (e.g., title must be str, completed is bool) and can provide helpful errors. They also are used by FastAPI to generate documentation (e.g., the schema for a Task in the OpenAPI docs).

routers/tasks.py: (In the provided files this appears as tasks_router.py – it’s the same content.) This file defines the CRUD API endpoints for task management. It creates an APIRouter with prefix /tasks (and intended to have a tags=["Tasks"] for documentation grouping, though the tag list is left empty in the sample). Within this router, the following endpoints are defined:

POST /tasks/ – create_task: accepts a TaskCreate body, uses the DB connection to insert a new task, commits the transaction, and returns a Task model (including the new id and default completed=false). The response_model is Task, and FastAPI will produce a 201 Created status code.

GET /tasks/ – read_tasks: fetches a list of tasks with optional pagination (skip and limit query params). It executes a SELECT on the tasks table, then uses fetchall() to get a list of rows. It returns this list. (As noted, the response_model should be List[Task] to properly document the response; currently it’s just List, which is likely a minor oversight.)

GET /tasks/{task_id} – read_task: retrieves one task by ID. It SELECTs the task with matching id. If not found, it raises HTTPException(status_code=404), causing FastAPI to return a 404 JSON error. If found, it returns the row (which will be serialized to Task model in the response).

PUT /tasks/{task_id} – update_task: updates an existing task’s fields. It first calls await read_task(task_id, conn) to ensure the task exists (reusing the logic and raising 404 if not). Then it builds an update_data dict from the TaskUpdate body, excluding unset fields (so you can send partial updates). If the dict is empty, it means the client provided no fields, so it returns a 400 error. Otherwise it executes an UPDATE statement, commits, and then calls read_task again to fetch and return the updated record. This re-use of read_task ensures the response contains the latest data (and also shows a bit of code reuse, albeit by calling the endpoint function directly).

DELETE /tasks/{task_id} – delete_task: deletes a task by ID. It also calls await read_task(task_id, conn) first to check existence. Then it executes a DELETE statement and commits. The response is just None with status_code 204 (No Content). FastAPI knows to send a 204 with empty body in this case.

The router uses Depends(get_connection) on each route to automatically provide the conn. All the heavy lifting for database operations is done via the sqlalchemy queries; there are no raw SQL strings in the route code – making it easier to maintain and less error-prone. Each function is documented with a docstring, which FastAPI will include in the interactive docs.

File organization note: Having a dedicated routers/tasks.py module follows a common FastAPI project structure, where routers for different resources (tasks, users, etc.) live in a routers (or api) package. This keeps the main.py clean and each router focused. The include_router in main.py brings it all together. Also, by using relative imports (e.g. from .database import tasks_table), the code assumes these modules are part of a package (likely an app/ package); this implies there is an __init__.py making app a package, and the structure is in place for scalability.
