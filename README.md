<p align="center"><img src="website/public/assets/lilt-mark.svg" width="64" height="64" alt="Lilt"></p>

# Lilt

Capture some text. Listen to it. Follow the words where they are.

Lilt is a small macOS app that reads a selected part of your screen aloud with Kokoro. It keeps the original screenshot, highlights each spoken word, and lets you click a word to jump there.

[Website](https://lilt.theronburger.workers.dev) · [Download for Mac](https://github.com/theronburger/lilt/releases/latest) · [Watch the demo](https://github.com/theronburger/lilt/releases/download/v0.1.0/lilt-demo.mp4) · [Build from source](#development)

https://github.com/user-attachments/assets/8e649a07-40fb-48f8-bee2-bee2ad528366

## Install

Requires an **Apple Silicon Mac with macOS 15 or later**. Liquid Glass controls use macOS 26; older versions use the standard blur material.

1. Download the ZIP from [Releases](https://github.com/theronburger/lilt/releases/latest), unzip it, and move **Lilt.app** into Applications.
2. Open Lilt. This early release uses a persistent self-signed certificate and **is not Apple-notarized**. If macOS blocks it, use **System Settings → Privacy & Security → Open Anyway** after attempting to open the app.
3. Allow Lilt in **Screen & System Audio Recording** when you first capture. The setup guide gives you the app to drag into the list.

The speech runtime, model, and voice previews are included. No Python setup or account is needed to read locally. New versions arrive through **Check for Updates…** in the app, using signed Sparkle updates.

## Use it

- **⇧⌘L** captures a region. **⌥⌘L** reads the clipboard. Both shortcuts are configurable.
- The screenshot floats above your other windows. Hover for play/pause, seeking, and speed.
- Click a word to jump to it. Press Space to pause or resume.
- Choose from 28 English Kokoro voices, each with an instant preview.
- Replay readings from History, export text or WAV audio, or delete them. History expires after a week by default; change that in Settings.

Apple Vision recognizes text locally. For screenshots containing interface clutter, optional AI filtering can keep the main passage and omit buttons, status messages, and decorative symbols. Bring your own provider key and model using Chat Completions or Responses. The reading prompt is editable. Experimental pronunciation hints can help with names and acronyms.

## What leaves your Mac

OCR, speech, screenshots, and history stay local by default. There are no analytics or accounts.

Enabling AI filtering sends **only the region you capture** to the HTTPS provider you configure. Provider charges and data policies apply. API keys can stay in memory for the session or be saved explicitly in macOS Keychain. Sparkle contacts the public update feed to check for releases; automatic checks can be switched off.

## Development

You need Xcode and [uv](https://docs.astral.sh/uv/). Source builds are named **Lilt Dev**, with separate settings and history.

```sh
git clone https://github.com/theronburger/lilt.git
cd lilt
./scripts/setup.sh
./scripts/build.sh --install
open "$HOME/Applications/Lilt Dev.app"
```

Packaged development builds require a persistent code-signing certificate. Create **Lilt Local Development** in Keychain Access using Certificate Assistant → Create a Certificate → Code Signing, or pass your own `SIGNING_IDENTITY`. Keep that identity between builds to preserve Screen Recording permission. `swift build` and `swift test` work without a certificate.

```sh
swift test
.venv/bin/python -m unittest discover -s Speech -p 'test_*.py'
```

Native SwiftUI and AppKit handle the interface and capture. Vision supplies word boxes. A persistent local Kokoro worker produces speech and real token timings; those timings drive highlighting and seeking. Text ranges use UTF-16 throughout.

See [development notes](docs/development.md), [contributing](CONTRIBUTING.md), [the release runbook](docs/RELEASING.md), and [the editable demo source](marketing/README.md).

## Scope

The current release supports English voices and one selected text region at a time. Dense columns, tables, and code can need a tighter selection. AI filtering depends on the selected provider and can omit or misread text. Pronunciation hints are experimental; they do not add general emotion or prosody control.

Lilt’s original source is free under the [MIT licence](LICENSE). Bundled speech components retain their own licences, including Apache 2.0, GPL, and LGPL. Each release includes corresponding source for the copyleft components. See [licensing](docs/LICENSING.md) and the app’s About page for details.
