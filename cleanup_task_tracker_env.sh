#!/usr/bin/env bash
set -euo pipefail

# Load .env if exists (so names can come from env)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${ROOT_DIR}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
  set +a
fi

# Defaults if not defined in .env
APP_CONTAINER="${CONTAINER_NAME:-task-app}"
DB_CONTAINER="${DB_CONTAINER_NAME:-task-postgres}"
NETWORK="${NETWORK_NAME:-tasknet}"
VOLUME="${VOLUME_NAME:-task_pg}"

log() { printf "[cleanup] %s\n" "$*"; }

log "Stopping containers..."
podman stop "$APP_CONTAINER" "$DB_CONTAINER" 2>/dev/null || true

log "Removing containers..."
podman rm -f "$APP_CONTAINER" "$DB_CONTAINER" 2>/dev/null || true

log "Removing network..."
podman network rm "$NETWORK" 2>/dev/null || true

log "Removing volume..."
podman volume rm "$VOLUME" 2>/dev/null || true

# Optional: prune container images/layers
if [[ "${CLEAN_BUILDER_CACHE:-false}" == "true" ]]; then
  log "Pruning unused Podman images & build cache..."
  podman image prune -f || true
  podman builder prune -f || true
fi

log "Cleanup done ✅"
