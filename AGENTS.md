# Lilt

Native macOS reader: SwiftUI for ordinary controls, AppKit for capture and windows, Vision for OCR, Kokoro in a local Python helper.

## Working here

- Build: `scripts/build.sh`; install: `scripts/build.sh --install`.
- Development builds are **Lilt Dev** (`app.lilt.reader.dev`), including optimized builds. Never label an ad-hoc development build as production Lilt.
- Launch only `~/Applications/Lilt Dev.app` after installation. The installer removes the duplicate dist app.
- Keep development preferences and history separate from production. Current early-prototype data was copied into the development location without deleting the original.
- Packaged builds must use a persistent signing certificate; ad-hoc signing is rejected. The installer checks the new app against the installed signing requirement. Never weaken designated requirements or change the system privacy database. Local development defaults to `Lilt Local Development`; initial public releases use the separate persistent `Lilt Release` identity until Developer ID signing and notarization are available. Keep private signing material out of Git and release assets.
- Tests: `swift test` and `.venv/bin/python -m unittest discover -s Speech -p 'test_*.py'`.
- Set up speech with `scripts/setup.sh`. Keep dependency changes reproducible in `Speech/requirements.txt`.
- Use standard native controls. Keep custom interface code focused on capture and reading.
- Audio position is the source of truth for highlighting. Use real word timings, never character-count estimates.
- Text ranges use UTF-16 offsets. Preserve mappings when normalizing or splitting text.
- OCR and speech stay local by default. Optional AI filtering was explicitly approved: only send the selected screenshot when the user enables the toggle and configures an endpoint/key. Never embed keys in source, preferences, logs or fixtures. Keep session keys in memory and persist only through the explicit Keychain action.
- Do not commit captures, history, generated audio, model files, private text, or runtime paths.
- Keep scratch work in `work/`. `.venv`, `.build`, `dist`, and `work` are ignored.
- Do not interrupt a running reading to install or test changes. Coordinate restarts or leave updates for the next launch.

The installed development app depends on this checkout's `.venv`. Production builds bundle a pinned standalone Python runtime, speech dependencies, Kokoro weights, and voice previews. Follow `docs/RELEASING.md` for signed Sparkle publishing. Do not describe self-signed releases as Apple-notarized.

The public marketing demo uses synthetic documents and its own generated audio under `marketing/`; these intentional public assets are distinct from private reading history and captures.
