#!/usr/bin/env bash
# Start the backend. Models are loaded on demand by the router.
set -e
cd "$(dirname "$0")"
exec .venv/bin/python -m uvicorn app.server:app --host 127.0.0.1 --port 8000
