# Contributing

Small, focused pull requests are welcome. For a substantial change, open an issue first so we can agree on the problem and scope.

## Build and check

Follow the [README](README.md#development) to install the pinned speech runtime and build Lilt Dev. Run `swift test` and the Python tests before submitting. Test actual capture and playback when changing window behavior, OCR alignment, or speech timing. Use synthetic text and images in fixtures.

Keep native controls where macOS already supplies them. Preserve UTF-16 text ranges and real audio timings. A change to the speech pipeline must retain word-to-screenshot alignment, including repeated words and punctuation.

Do not commit API keys, screenshots of private content, reading history, generated user audio, model caches, signing material, or machine-specific runtime paths. Scratch work belongs in ignored `work/`. Public demo assets must use invented content and live in `marketing/`.

## Pull requests

Describe the user-visible problem, the change, and how it was checked. Use a Conventional Commit title such as `fix: preserve the capture position after resizing` or `feat: add an export format`. Dependency changes should update their lockfile. Keep an unrelated cleanup out of a behavior change.

Release builds and the website have separate documented build steps. See [the release runbook](docs/RELEASING.md), [website source](website/), and [video source](marketing/README.md).

## Security reports

Use [private vulnerability reporting](https://github.com/theronburger/lilt/security/advisories/new) instead of a public issue. Please do not include real keys or captured private text.
