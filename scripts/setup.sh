#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v uv >/dev/null || { echo 'Install uv first: https://docs.astral.sh/uv/'; exit 1; }
uv venv --python 3.12 .venv
uv pip install --python .venv/bin/python -r Speech/requirements.lock

.venv/bin/python scripts/generate-voice-previews.py
