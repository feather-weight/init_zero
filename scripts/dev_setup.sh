#!/usr/bin/env bash
set -euo pipefail

echo "[setup] Installing backend dependencies..."
python3 -m pip install -r backend/requirements.txt

echo "[setup] Installing frontend dependencies..."
cd frontend && npm install && cd - >/dev/null

echo "[setup] Done."
