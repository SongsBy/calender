#!/usr/bin/env bash
# Render Docker Command: bash scripts/render-start.sh
set -euo pipefail

cd "$(dirname "$0")/.."
bash scripts/prestart.sh
exec fastapi run --host 0.0.0.0 --port "${PORT:-10000}" --workers 1
