#!/usr/bin/env bash
set -euo pipefail

# Auto-detect CPU cores (fallback to 1)
CPU_CORES="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"

# If UVICORN_WORKERS is set in the environment (e.g., via --env-file .env), use it.
# Otherwise, pick a sensible default = min(CPU_CORES, 4)
WORKERS="${UVICORN_WORKERS:-$(( CPU_CORES < 4 ? CPU_CORES : 4 ))}"

echo "[run] CPU cores: ${CPU_CORES}, starting Uvicorn workers: ${WORKERS}"

# Start FastAPI with multiple workers; each worker runs its own async loop.
exec /opt/venv/bin/python -m uvicorn src.main:app --host 0.0.0.0 --port 8000 --workers "${WORKERS}"
