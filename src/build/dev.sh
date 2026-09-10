#!/usr/bin/env bash
# Run the Tauri shell against the live dev servers — no freezing, fast reload.
#
# The backend still has to be started by hand in another terminal:
#   .venv/bin/python -m uvicorn app.server:app --port 8000
#
# The shell will fail to spawn its sidecar (there isn't one yet) and fall
# back to the fixed port, which is what you want while iterating.
set -e
cd "$(dirname "$0")/.."
cd src-tauri && cargo tauri dev
