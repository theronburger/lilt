#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SIGNING_IDENTITY:?Set a persistent release SIGNING_IDENTITY}"
test "$(uname -m)" = arm64 || { echo 'Releases currently support Apple Silicon only.'; exit 1; }
CONFIGURATION=release BUILD_FLAVOR=production scripts/build.sh
python3 scripts/check-portable.py dist/Lilt.app
version="$(tr -d '[:space:]' < VERSION)"
archive="dist/lilt_${version}_macos_arm64.zip"
ditto -c -k --sequesterRsrc --keepParent dist/Lilt.app "$archive"
python3 scripts/generate-sbom.py "dist/lilt_${version}_macos_arm64.sbom.cdx.json"
(cd dist && shasum -a 256 "lilt_${version}_macos_arm64.zip" "lilt_${version}_macos_arm64.sbom.cdx.json" > checksums.txt)
echo "Built $archive"
