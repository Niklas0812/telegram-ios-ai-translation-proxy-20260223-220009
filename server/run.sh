#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

export PYTHONPATH="$REPO_ROOT/server:${PYTHONPATH:-}"
PORT="${PROXY_PORT:-$(python3 - <<'PY'
import json
from pathlib import Path
cfg = Path('config/proxy.config.json')
if not cfg.exists():
    print(8080)
else:
    data = json.loads(cfg.read_text())
    print(data.get('server', {}).get('port', 8080))
PY
)}"

exec python3 -m uvicorn app.main:app --app-dir server --host "${BIND_HOST:-0.0.0.0}" --port "$PORT"
