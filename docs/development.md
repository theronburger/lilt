# Development notes

Implementation and behavior details for contributors. See the [README](../README.md) for installation and the [release runbook](RELEASING.md) for publishing.

## Use

- Launch Lilt. It lives in the menu bar.
- Press **⇧⌘L**, then drag over a block of text. Escape cancels.
- The captured image stays near its original position, inside a borderless rounded window. Hover to reveal a separate Liquid Glass playback bar (blur on older macOS) beneath it. Words highlight directly on the screenshot. Speech begins when the first audio chunk is ready.
- Click a word to jump to it. Space pauses or resumes. Drag an empty part of the capture or the control bar to move the window.
- Paste text from the main window, or press **⌥⌘L** to read the clipboard immediately.
- Open **History & Settings** to replay readings, choose a voice, adjust speed, or change text size.

Capture requires macOS Screen Recording permission. Settings → Capture → Screen Recording permission opens System Settings; if permission is missing, a floating card offers the installed app as a draggable file. The card follows System Settings and closes on a grant, dismissal, closing Settings, or after three minutes. The interaction pattern was informed by [AskForPermission](https://github.com/riko2chen/AskForPermission); Lilt checks only Screen Recording through public APIs. Enable **Lilt Dev** in **System Settings → Privacy & Security → Screen & System Audio Recording**. macOS may require quitting and reopening the app afterward. Accessibility permission is not required for the shortcut or OCR.

## Develop

Requires macOS 15+, Xcode with its command-line tools, and [uv](https://docs.astral.sh/uv/). This initial build targets Apple Silicon with the pinned Kokoro runtime.

```sh
./scripts/setup.sh
./scripts/build.sh --install
open "$HOME/Applications/Lilt Dev.app"
```

Open `Package.swift` in Xcode to work on the source. Launch the packaged app to run speech: the build script supplies its bundle resources and runtime configuration.

Development builds are always named **Lilt Dev**, with bundle ID `app.lilt.reader.dev`, even when `CONFIGURATION=release` enables optimizations. `scripts/build.sh` produces `dist/Lilt Dev.app`. `--install` moves the result into `~/Applications/Lilt Dev.app` and removes the build copy, leaving one canonical runnable app. Launch that installed path.

The menu bar and sidebar identify the development app. **About** shows its version, build fingerprint, Git revision, source repository and dependency licences. The source button opens the local checkout; a repository link appears when Git has an HTTPS remote. Lilt uses the MIT licence. Development data uses `~/Library/Application Support/Lilt Dev`; production data uses `Lilt`.

Local OCR uses Apple's built-in Vision framework. The earlier FastVLM experiment was removed because its model licence excludes product development. Kokoro weights are Apache 2.0; Python runtime and native dependency notices are collected from the exact installed packages at build time.

Packaged builds require a persistent signing certificate. Ad-hoc signing is rejected because it ties Screen Recording permission to one exact binary. `swift build` and `swift test` still work without a certificate.

For local development before Apple account activation, use Keychain Access → Certificate Assistant → Create a Certificate: name **Lilt Local Development**, identity **Self Signed Root**, type **Code Signing**. Keep that identity in your login keychain. This identity is only for local development. Public releases have a separate persistent publisher certificate and bundle identifier. Do not recreate it between builds. If macOS does not list it as a valid code-signing identity, trust this certificate for Code Signing in your user keychain only. No system-wide or TLS trust is needed; keep the default certificate-bound designated requirement.

The build script defaults to that certificate name. To select an Apple certificate, pass `SIGNING_IDENTITY` (prefer its SHA-1 fingerprint from `security find-identity -v -p codesigning`). You can save the non-secret development identity selector in ignored `work/signing-identity`. Private keys remain in Keychain; never export them into the repository.

Before installation, the new bundle must satisfy the currently installed certificate-signed app’s designated requirement. An accidental signing-identity change stops installation. An intentional migration can use `ALLOW_SIGNING_IDENTITY_CHANGE=1`; macOS may then require a new grant. The first migration from the old ad-hoc app also requires a fresh grant: quit Lilt Dev, remove its stale Screen Recording entry, add `~/Applications/Lilt Dev.app`, and reopen. Do not reset unrelated app permissions.

`BUILD_FLAVOR=production` uses **Lilt** and `app.lilt.reader`, packages the speech runtime and model, and requires an explicit persistent publisher signing identity. Initial public releases are self-signed, not Apple-notarized. Sparkle verifies both the archive and update feed with Ed25519. See the release runbook for build and signing requirements.

The development app uses this checkout's `.venv`, so keep the checkout in place. Its first synthesis may download Kokoro models and voice files. Production packaging includes a standalone runtime, model, and voices; synthesis runs locally without those downloads.

## Checks

```sh
swift test
.venv/bin/python -m unittest discover -s Speech -p 'test_*.py'
```

Swift tests cover OCR word boxes on a rendered image, capture placement and scaling, legacy history decoding, screenshot persistence, native audio completion and seeking, word seeking across chunks, timing gaps, UTF-16 text ranges, history persistence and audio cleanup. Python tests cover chunk boundaries, repeated words and alignment errors.

## Structure

- `Sources/Lilt`: native SwiftUI screens, AppKit selection and window handling, Vision OCR, native playback, local speech process.
- `Sources/LiltCore`: readings, word timing, seek calculations and file persistence.
- `Speech`: persistent Kokoro worker and renderer. Audio and timings share one contract; another engine can implement it without changing the reader.
- `Resources`: app bundle metadata.

The renderer is adapted from the author's Review Story tooling. Kokoro's token timestamps drive highlighting and seeking; elapsed wall time is never used to estimate the spoken word. UTF-16 offsets match native text layout, including text containing emoji.

**Settings → AI text filtering → AI pronunciation hints** is an optional experiment, off by default. When enabled alongside AI filtering, the same screenshot parsing request returns faithful text plus sparse Kokoro/Misaki phoneme hints for names, acronyms and context-dependent words. It does not add another provider round trip, but produces extra tokens. Hints are validated against the selected English accent and exact occurrences of the original words. Invalid hints are ignored; malformed output shows an error and can be retried with the option off. The renderer changes only matched tokens' phonemes, retaining their original text and real timings for highlighting and seeking. Hints are saved with the reading and included in its audio cache key. They apply to new captures; existing audio and voice previews stay unchanged. This can help pronunciation; it does not give Kokoro general emotion or prosody control.

Development readings, captured crops and audio are stored in `~/Library/Application Support/Lilt Dev`. Only the selected crop is saved; the full-screen selection snapshots are transient. New captured readings reopen as images; older captures without a saved image and pasted text use the text reader. Deleting a reading removes its crop. There are no analytics. OCR and speech stay local by default; optional AI filtering sends the selected screenshot to your configured endpoint. History expires after seven days by default; Settings offers one day, one week, one month or never. The current reading is protected. Automatic expiry removes associated captures and unreferenced audio. Speech-model caches are managed separately by Hugging Face.

## Library and playback

Right-click a history row to export its text or completed audio as a single WAV at its original speed. Voice previews pause the reader and do not create history entries. Both global shortcuts can be changed in Settings → Capture: click the shortcut field and press the desired keys. The recorder warns about system shortcuts, blocks duplicate Lilt actions and app menu conflicts, and checks for registrations held by other apps. macOS cannot report every shortcut implemented by another app. Clear a shortcut with the field’s × button to disable it.

## First-version limits

- All 28 English Kokoro voices are available, with bundled instant previews. Kokoro’s other 26 voices lack the token timings required by the current renderer; multilingual reading is not enabled.
- Select a single text block on one display. Complex columns, tables and code need improved reading-order handling.
- Speech is generated in short chunks. Clicking text that is not ready pauses and waits for that chunk; generation currently stays sequential.
- The progress bar covers generated audio and grows until generation finishes.
- Screen capture has been exercised on this Mac. Mixed-scale, multiple-display and full-screen Space combinations still need broader testing.


## Optional AI text filtering

In Settings, choose Responses or Chat Completions and enter the provider’s API base URL and model, use **Add key…**, then enable **Filter interface text with AI**. The default is off. The key dialog offers explicit secure Keychain storage (or session-only use); settings show whether a key is saved without exposing it. **Change…** replaces a key and **Remove…** confirms removal. Saved keys are scoped to the HTTPS provider origin, so changing the API path does not lose the key. Changing the endpoint clears the session key but does not change the filtering toggle. **Test connection** sends a small generated sample image and reports latency without modifying configuration.

Keychain reads during settings refresh, capture and connection testing are non-interactive. An authorized key is cached in memory until quit; if macOS needs approval, the app shows **Unlock saved key** rather than opening a password prompt automatically. Unlock, Save and Remove are explicit Keychain actions. A self-signed development certificate preserves the app’s designated requirement for Screen Recording, but macOS Keychain partitions non-Apple developer signatures by executable hash. Rebuilds can therefore require another explicit unlock. An Apple Development/Developer ID identity provides the stable team identity needed across updates. ACLs and partition protections are not weakened.

**Edit reading prompt…** opens `reading-prompt.txt` in Lilt's Application Support folder using the default text editor. The file is created from the default prompt once and reread on every AI capture; app updates preserve user edits. Empty prompts produce an explicit error. The default omits decorative arrows and icon glyphs without spelling their names, while preserving meaningful notation and original prose.

The model receives only the selected capture and returns plain reading text. Vision still supplies the word boxes. Lilt aligns the returned words to those boxes and refuses low-confidence mappings, incomplete responses, and refusals. No result is silently substituted after an AI error; turn the toggle off to return to local Vision OCR. Requests allow 30 seconds without network data and 60 seconds total. The connection test uses a representative sample paragraph and the configured reading prompt. The adapter supports Responses and Chat Completions, including OpenRouter, but not Anthropic’s native Messages API. Use https://openrouter.ai/api/v1 as the OpenRouter base URL. Full request URLs are rejected with an explanation; the selected API format determines the request route.

Uploads target a 1600-pixel long edge while preserving small OCR words at 16 pixels or more. Lilt compares the original PNG, resized PNG and quality-85 JPEG; it uses JPEG only when it saves at least 20% over lossless. The original image and word positions remain unchanged locally. OpenRouter requests disable reasoning and use temperature zero for extraction. **Race three requests** is optional and off by default: the first complete, alignable response wins, the others are cancelled, and cancellation of capture cancels all requests. This can cost up to three requests; matching word boxes cannot detect every omission or unwanted interface label.

Provider benchmarks belong in standalone tools with explicit temporary credentials and synthetic fixtures. The optional live Swift test requires `LILT_TEST_ENDPOINT`, `LILT_TEST_MODEL`, `LILT_TEST_API_KEY`, and `LILT_FILTER_FIXTURES`; ordinary tests make no provider requests.

## Local capture engine

Apple Vision supplies local reading text and word positions in one recognition pass. It runs on the Mac and needs no downloaded OCR model or separate helper. With AI filtering disabled, the recognized words go straight to Kokoro. Vision reads visible text, including interface labels; select the desired passage tightly, or enable AI filtering to remove interface clutter. Cloud filtering still extracts directly from the selected image and aligns the result to Vision's boxes.
