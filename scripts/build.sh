#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
project_root="$PWD"
configuration="${CONFIGURATION:-debug}"
flavor="${BUILD_FLAVOR:-development}"
signing_identity="${SIGNING_IDENTITY:-}"
if [ -z "$signing_identity" ] && [ -f work/signing-identity ]; then
    signing_identity="$(cat work/signing-identity)"
fi
if [ -z "$signing_identity" ]; then
    signing_identity="Lilt Local Development"
fi
if [ "$signing_identity" = "-" ]; then
    echo "Lilt bundles require a persistent signing certificate; ad-hoc signing breaks Screen Recording after updates."
    echo "Use swift build/test for unpackaged checks, or set SIGNING_IDENTITY to a code-signing certificate."
    exit 1
fi
if ! security find-identity -v -p codesigning | grep -F -- "$signing_identity" >/dev/null; then
    echo "No valid code-signing identity found for: $signing_identity"
    echo "Create a Code Signing certificate named Lilt Local Development in Keychain Access, or set SIGNING_IDENTITY to an Apple signing certificate."
    exit 1
fi
case "$flavor" in
    development) app_name="Lilt Dev"; bundle_id="app.lilt.reader.dev" ;;
    production)
        app_name="Lilt"; bundle_id="app.lilt.reader"
        if [ -z "${SIGNING_IDENTITY:-}" ]; then
            echo "Production builds require an explicit persistent SIGNING_IDENTITY."
            exit 1
        fi
        python3 scripts/prepare-runtime.py
        ;;
    *) echo "BUILD_FLAVOR must be development or production"; exit 1 ;;
esac
swift build -c "$configuration"
binary_dir="$(swift build -c "$configuration" --show-bin-path)"
bundle="$project_root/dist/$app_name.app"
# Always assemble a clean bundle; removed tools and fixtures must not survive rebuilds.
rm -rf "$bundle"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources/Speech"
cp "$binary_dir/Lilt" "$bundle/Contents/MacOS/Lilt"
mkdir -p "$bundle/Contents/Frameworks"
ditto "$binary_dir/Sparkle.framework" "$bundle/Contents/Frameworks/Sparkle.framework"
install_name_tool -add_rpath '@executable_path/../Frameworks' "$bundle/Contents/MacOS/Lilt"
# SwiftPM localization resources used by the native shortcut recorder.
for resource_bundle in "$binary_dir"/*.bundle; do
    [ -d "$resource_bundle" ] || continue
    cp -R "$resource_bundle" "$bundle/Contents/Resources/"
done
mkdir -p "$bundle/Contents/Resources/Licenses"
cp Resources/Licenses/*.txt "$bundle/Contents/Resources/Licenses/"
cp LICENSE "$bundle/Contents/Resources/Licenses/Lilt.txt"
cp .build/checkouts/KeyboardShortcuts/license "$bundle/Contents/Resources/Licenses/KeyboardShortcuts.txt"
cp .build/artifacts/sparkle/Sparkle/LICENSE "$bundle/Contents/Resources/Licenses/Sparkle.txt"
notices="$bundle/Contents/Resources/ThirdPartyNotices.txt"
cat "$bundle/Contents/Resources/Licenses/"*.txt > "$notices"
speech_python="$project_root/.venv/bin/python"
if [ "$flavor" = "production" ]; then
    speech_python="$project_root/work/portable-runtime/python/bin/python3"
    ditto work/portable-runtime/python "$bundle/Contents/Resources/Python"
    ditto work/portable-runtime/Kokoro "$bundle/Contents/Resources/Kokoro"
    LILT_MODEL_DIRECTORY="$project_root/work/portable-runtime/Kokoro" "$speech_python" scripts/generate-voice-previews.py
    find "$bundle/Contents/Resources/Python" -type d -name __pycache__ -prune -exec rm -rf {} +
fi
"$speech_python" scripts/collect-notices.py "$notices" "Speech runtime"
cp Resources/Info.plist "$bundle/Contents/Info.plist"
cp Speech/worker.py Speech/speech_renderer.py Speech/voices.json "$bundle/Contents/Resources/Speech/"
python3 - <<'PREVIEWS'
import json,pathlib,sys
voices=json.loads(pathlib.Path('Speech/voices.json').read_text())
missing=[v['id'] for v in voices if not pathlib.Path('work/voice-previews',v['id']+'.wav').is_file()]
if missing:
    sys.exit('Missing voice previews. Run .venv/bin/python scripts/generate-voice-previews.py first.')
PREVIEWS
mkdir -p "$bundle/Contents/Resources/Voices"
cp work/voice-previews/*.wav "$bundle/Contents/Resources/Voices/"
python3 - "$project_root" "$bundle" "$app_name" "$bundle_id" "$flavor" "$signing_identity" <<'PY'
import hashlib, json, pathlib, plistlib, subprocess, sys, urllib.parse
root, bundle = map(pathlib.Path, sys.argv[1:3])
name, identifier, flavor, signing_identity = sys.argv[3:]
plist_path = bundle / 'Contents/Info.plist'
info = plistlib.loads(plist_path.read_bytes())
fingerprint = hashlib.sha256()
files = [root / 'Package.swift'] + [p for folder in ('Sources', 'Speech', 'Resources') for p in (root / folder).rglob('*') if p.suffix in ('.swift', '.py', '.plist', '.lock', '.json', '.txt')]
for path in sorted(files):
    fingerprint.update(str(path.relative_to(root)).encode())
    fingerprint.update(path.read_bytes())
info.update(CFBundleName=name, CFBundleDisplayName=name, CFBundleIdentifier=identifier,
            LiltBuildFlavor=flavor, LiltSigningIdentity=signing_identity, LiltBuildID=fingerprint.hexdigest()[:10],
            LiltGitRevision='No commits yet',
            CFBundleShortVersionString=(root / 'VERSION').read_text().strip(), CFBundleVersion=(root / 'VERSION').read_text().strip(),
            NSScreenCaptureUsageDescription=f'{name} captures the area you select and reads its text aloud. Text and audio stay on your Mac.')
if flavor == 'development':
    info['LiltSourcePath'] = str(root)
else:
    import base64
    public_key = (root / 'Resources/SparklePublicKey.txt').read_text().strip()
    if len(base64.b64decode(public_key, validate=True)) != 32:
        raise SystemExit('Resources/SparklePublicKey.txt must contain a valid Ed25519 public key.')
    info.update(SUPublicEDKey=public_key, SUFeedURL='https://github.com/theronburger/lilt/releases/latest/download/appcast.xml',
                SUEnableAutomaticChecks=True, SUAutomaticallyUpdate=False, SURequireSignedFeed=True, SUVerifyUpdateBeforeExtraction=True,
                LiltRepositoryURL='https://github.com/theronburger/lilt')
revision = subprocess.run(['git', 'rev-parse', '--short', 'HEAD'], cwd=root, capture_output=True, text=True)
if revision.returncode == 0:
    dirty = subprocess.run(['git', 'status', '--porcelain'], cwd=root, capture_output=True, text=True).stdout.strip()
    info['LiltGitRevision'] = revision.stdout.strip() + (' · modified' if dirty else '')
remote = subprocess.run(['git', 'remote', 'get-url', 'origin'], cwd=root, capture_output=True, text=True)
if remote.returncode == 0:
    value = remote.stdout.strip()
    if value.startswith('git@') and ':' in value:
        host, path = value[4:].split(':', 1)
        value = f'https://{host}/{path}'
    parts = urllib.parse.urlsplit(value)
    if parts.scheme == 'https' and parts.hostname and not parts.username and not parts.query and not parts.fragment:
        info['LiltRepositoryURL'] = value.removesuffix('.git')
plist_path.write_bytes(plistlib.dumps(info))
runtime = {'python': str(root / '.venv/bin/python')} if flavor == 'development' else {'python': 'Python/bin/python3', 'model': 'Kokoro'}
(bundle / 'Contents/Resources/runtime.json').write_text(json.dumps(runtime))
PY
if [ ! -f "$bundle/Contents/Resources/Lilt.icns" ]; then
    mkdir -p work/Lilt.iconset
    swift scripts/icon.swift work/Lilt.iconset
    iconutil -c icns work/Lilt.iconset -o "$bundle/Contents/Resources/Lilt.icns"
fi
python3 scripts/sign-bundle.py "$bundle" "$signing_identity"
python3 scripts/check-signing.py "$bundle" "$HOME/Applications/$app_name.app"
if [ "${1:-}" = "--install" ]; then
    if pgrep -f "$HOME/Applications/$app_name.app/Contents/MacOS/Lilt" >/dev/null; then
        echo "Quit $app_name before installing. The completed build is in dist."
        exit 1
    fi
    mkdir -p "$HOME/Applications"
    python3 - "$bundle" "$HOME/Applications/$app_name.app" <<'PY'
import os, pathlib, shutil, sys, tempfile
source, destination = map(pathlib.Path, sys.argv[1:])
with tempfile.TemporaryDirectory(prefix='.lilt-install-', dir=destination.parent) as staging:
    staged = pathlib.Path(staging) / destination.name
    previous = pathlib.Path(staging) / 'previous.app'
    shutil.copytree(source, staged, symlinks=True)
    if destination.exists():
        os.rename(destination, previous)
    try:
        os.rename(staged, destination)
    except BaseException:
        if previous.exists():
            os.rename(previous, destination)
        raise
shutil.rmtree(source)
PY
    echo "Installed $HOME/Applications/$app_name.app (build copy removed to keep one runnable installation)"
else
    echo "Built $bundle"
fi
