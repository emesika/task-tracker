#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -------- load .env (optional but recommended) --------
if [[ -f "${ROOT_DIR}/.env" ]]; then
  # export all .env vars for convenient use here
  set -a
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
  set +a
else
  echo "[db_up] Warning: .env not found in project root; using script defaults."
fi

# -------- Config (from .env with safe defaults) --------
NETWORK_NAME="${DB_NETWORK_NAME:-tasknet}"
VOLUME_NAME="${DB_VOLUME_NAME:-task_pg}"
CONTAINER_NAME="${DB_CONTAINER_NAME:-task-postgres}"
IMAGE="${DB_IMAGE:-docker.io/library/postgres:16-alpine}"

# DB settings passed to container
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-password}"
DB_NAME="${DB_NAME:-task_tracker_db}"
DB_PORT="${DB_PORT:-5432}"

# Optional: publish DB to host (set empty to skip)
HOST_PORT_MAP="${DB_HOST_PORT_MAP:-5432:5432}"

# Health check settings
HEALTH_INTERVAL="${DB_HEALTH_INTERVAL:-10s}"
HEALTH_TIMEOUT="${DB_HEALTH_TIMEOUT:-3s}"
HEALTH_RETRIES="${DB_HEALTH_RETRIES:-5}"

# -------- Helpers --------
log() { printf "[db_up] %s\n" "$*"; }

container_exists() { podman container exists "$1"; }
container_running() { [[ "$(podman inspect -f '{{.State.Running}}' "$1" 2>/dev/null || echo false)" == "true" ]]; }
network_exists() { podman network exists "$1"; }
volume_exists() { podman volume exists "$1"; }

wait_for_healthy() {
  local name="$1" tries=0 max_tries=40 status=""
  log "Waiting for container '$name' to report healthy..."
  while (( tries < max_tries )); do
    status="$(podman inspect -f '{{.State.Health.Status}}' "$name" 2>/dev/null || true)"
    if [[ "$status" == "healthy" ]]; then
      log "Container is healthy."
      return 0
    fi
    if [[ "$status" == "unhealthy" ]]; then
      log "Health status is 'unhealthy' (try $tries/$max_tries)."
    fi
    sleep 1
    ((tries++))
  done
  log "Timed out waiting for healthcheck. Current status: ${status:-unknown}"
  return 1
}

# -------- Step 1: Shared network --------
if network_exists "$NETWORK_NAME"; then
  log "Network '$NETWORK_NAME' already exists."
else
  log "Creating network '$NETWORK_NAME'..."
  podman network create "$NETWORK_NAME"
fi

# -------- Step 2: Persistent volume --------
if volume_exists "$VOLUME_NAME"; then
  log "Volume '$VOLUME_NAME' already exists."
else
  log "Creating volume '$VOLUME_NAME'..."
  podman volume create "$VOLUME_NAME"
fi

# -------- Step 3: DB container --------
if container_exists "$CONTAINER_NAME"; then
  if container_running "$CONTAINER_NAME"; then
    log "Container '$CONTAINER_NAME' already running."
  else
    log "Starting existing container '$CONTAINER_NAME'..."
    podman start "$CONTAINER_NAME"
  fi
else
  log "Creating and starting container '$CONTAINER_NAME'..."
  # Build port args (allow disabling host publish by setting HOST_PORT_MAP to empty)
  PORT_ARGS=()
  if [[ -n "${HOST_PORT_MAP}" ]]; then
    PORT_ARGS=(-p "${HOST_PORT_MAP}")
  fi

  podman run -d \
    --name "$CONTAINER_NAME" \
    --network "$NETWORK_NAME" \
    -e POSTGRES_USER="$DB_USER" \
    -e POSTGRES_PASSWORD="$DB_PASSWORD" \
    -e POSTGRES_DB="$DB_NAME" \
    -v "$VOLUME_NAME:/var/lib/postgresql/data:Z" \
    "${PORT_ARGS[@]}" \
    --health-cmd="pg_isready -U ${DB_USER} || exit 1" \
    --health-interval="$HEALTH_INTERVAL" \
    --health-timeout="$HEALTH_TIMEOUT" \
    --health-retries="$HEALTH_RETRIES" \
    "$IMAGE"
fi

# -------- Wait for health --------
wait_for_healthy "$CONTAINER_NAME" || {
  log "Warning: container did not become healthy in time. Check logs:"
  log "  podman logs -f $CONTAINER_NAME"
}

# -------- Summary --------
DB_HOST="$CONTAINER_NAME"
log "PostgreSQL connection info for the app container (on network '$NETWORK_NAME'):"
log "To shell into the DB container: podman exec -it $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c '\dt'"
