#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -------- load .env --------
if [[ ! -f "${ROOT_DIR}/.env" ]]; then
  echo "[run_app] Missing .env in project root. Create it first." >&2
  exit 1
fi

# Build app
podman build --no-cache -t task-app -f Containerfile

# Export everything from .env for convenience in this script
set -a
# shellcheck disable=SC1091
source "${ROOT_DIR}/.env"
set +a

log() { printf "[run_app] %s\n" "$*"; }
container_exists() { podman container exists "$1"; }
container_running() { [[ "$(podman inspect -f '{{.State.Running}}' "$1" 2>/dev/null || echo false)" == "true" ]]; }
network_exists() { podman network exists "$1"; }

wait_for_container_healthy() {
  local container="$1"
  local timeout="${APP_HEALTHY_STATUS_TIMEOUT:-30}"
  local elapsed=0

  echo "[run_app] Waiting for container '$container' to become healthy (timeout: ${timeout}s)..."

  while (( elapsed < timeout )); do
    status="$(podman inspect -f '{{.State.Health.Status}}' "$container" 2>/dev/null || echo "unknown")"

    if [[ "$status" == "healthy" ]]; then
      echo "[run_app] ✅ Container '$container' is healthy!"
      return 0
    fi

    if [[ "$status" == "unhealthy" ]]; then
      echo "[run_app] ❌ Container '$container' became unhealthy!"
      return 1
    fi

    sleep 1
    ((elapsed++))
  done

  echo "[run_app] ❌ Timeout waiting for container '$container' to become healthy"
  return 1
}

# -------- sanity defaults --------
: "${NETWORK_NAME:=tasknet}"
: "${IMAGE_TAG:=task-app:latest}"
: "${CONTAINER_NAME:=task-app}"
: "${CONTAINERFILE:=Containerfile}"
: "${HOST_PORT:=8000}"
: "${CONTAINER_PORT:=8000}"
: "${DB_USER:=postgres}"
: "${DB_PASSWORD:=password}"
: "${DB_HOST:=task-postgres}"
: "${DB_PORT:=5432}"
: "${DB_NAME:=task_tracker_db}"
: "${HEALTH_INTERVAL:=10s}"
: "${HEALTH_TIMEOUT:=3s}"
: "${HEALTH_RETRIES:=5}"

# -------- ensure network --------
if network_exists "$NETWORK_NAME"; then
  log "Network '$NETWORK_NAME' exists."
else
  log "Creating network '$NETWORK_NAME'..."
  podman network create "$NETWORK_NAME"
fi

# -------- build image (cached if unchanged) --------
log "Building image '${IMAGE_TAG}' from ${CONTAINERFILE}..."
podman build -t "${IMAGE_TAG}" -f "${CONTAINERFILE}" "${ROOT_DIR}"

# -------- (re)run container --------
if container_exists "$CONTAINER_NAME"; then
  if container_running "$CONTAINER_NAME"; then
    log "Container '$CONTAINER_NAME' already running. Recreating..."
    podman rm -f "$CONTAINER_NAME"
  else
    log "Removing stopped container '$CONTAINER_NAME'..."
    podman rm "$CONTAINER_NAME"
  fi
fi

log "Starting '${CONTAINER_NAME}' on network '${NETWORK_NAME}'..."
podman run -d \
  --name "$CONTAINER_NAME" \
  --network "$NETWORK_NAME" \
  -p "${HOST_PORT}:${CONTAINER_PORT}" \
  --env-file "${ROOT_DIR}/.env" \
  --health-cmd="curl -fsS http://localhost:${CONTAINER_PORT}/ > /dev/null || exit 1" \
  --health-interval="$HEALTH_INTERVAL" \
  --health-timeout="$HEALTH_TIMEOUT" \
  --health-retries="$HEALTH_RETRIES" \
  "${IMAGE_TAG}"

log "Container started."
log "Logs:    podman logs -f ${CONTAINER_NAME}"
log "Open:    http://localhost:${HOST_PORT}"

# Wait for health status
wait_for_container_healthy "$CONTAINER_NAME" || exit 1
