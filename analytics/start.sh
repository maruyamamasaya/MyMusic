#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [ ! -d .venv ]; then
  python3 -m venv .venv
fi

. .venv/bin/activate
python -m pip install -q -r requirements.txt

if [ "${MYMUSIC_ANALYTICS_NO_BROWSER:-0}" != "1" ]; then
  (sleep 1; python -m webbrowser http://127.0.0.1:8766) &
fi

exec python -m uvicorn app.main:app --host 127.0.0.1 --port 8766
