#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift test
python3 -m unittest discover -s Speech -p 'test_*.py'
python3 -m unittest discover -s scripts -p 'test_*.py'
python3 -m py_compile Speech/*.py scripts/*.py
python3 - <<'PY'
import json, pathlib, plistlib, re
root = pathlib.Path('.')
version = (root / 'VERSION').read_text().strip()
assert re.fullmatch(r'\d+\.\d+\.\d+', version), 'VERSION must be a plain semantic version'
for path in (root / 'Resources').glob('*.json'):
    json.loads(path.read_text())
for path in (root / 'Resources').glob('*.plist'):
    plistlib.loads(path.read_bytes())
PY
git diff --check
