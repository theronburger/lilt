# Lilt demo film

The editable web app behind the README film and the website’s linked recorded demo. The website also reuses its original speech and word timings for a live interactive sample. This editor runs without a bundler or JavaScript dependencies.

The 33-second film follows the same basic setup as [Review Story’s demo](https://github.com/theronburger/review-story/tree/main/examples/checkout): too much text, a short chat, then the product. This is a new illustrated demo of Lilt, not a recording of someone’s desktop. All documents and dialogue are original public demo content. The audio is the real local Kokoro engine used by Lilt; every spoken highlight uses Kokoro’s measured word timings.

## Preview and edit

From the repository root:

```sh
python3 -m http.server 8766 --directory marketing
```

Open <http://localhost:8766>. The player supports pause, restart, and scrubbing to inspect any frame. The video itself is always 1920 × 1080, regardless of browser window size.

- `script.json`: dialogue, reading, and end card.
- `film.js`: layout and deterministic timeline. `draw(seconds)` renders any frame.
- `assets/narration.json`: measured voice timings and edit points.
- `assets/soundtrack.wav`: the exact soundtrack used in both preview and export.
- `assets/lilt-mark.svg`: the shared Lilt logo.

The scene timing is deliberate: incoming documents (0–5 seconds), chat (5–10.5), region selection (10.5–14), reading with a click-to-seek example (14–29.4), then the end card.

## Regenerate speech

Set up the app’s speech environment first with `scripts/setup.sh`. The generator uses the already-downloaded model locally; it does not call an AI provider.

```sh
.venv/bin/python marketing/scripts/narrate.py
```

The generator derives the cut and seek points from the actual words, rebuilds the soundtrack, and writes the public timing manifest. The video demonstrates jumping ahead to “The controls…”: the sound jumps to exactly the same point as the highlight. Cache identifiers and machine paths are not included in the public manifest.

## Render the video

1. Open the preview in a current Chromium browser.
2. Click **Export H.264**. The browser renders each frame using WebCodecs with explicit timestamps. It is independent of wall-clock speed and does not record your screen.
3. Click the generated download link and save `lilt-demo.h264`.
4. Run:

```sh
marketing/scripts/encode.sh ~/Downloads/lilt-demo.h264
```

Requires `ffmpeg` and `cwebp` on PATH (for example, `brew install ffmpeg webp`). This muxes the 30 fps video with the original soundtrack, generates a WebP poster, and creates the small looping GIF for GitHub. MP4 supports fast start for web playback. No browser extensions, remote render service, screen-recording permission, or credentials are required.

Outputs:

- `output/lilt-demo.mp4`: full narrated 1080p film; published as a release asset and on the website, not stored in Git.
- `output/lilt-demo-poster.webp`: static cover.
- `output/lilt-demo.gif`: small silent capture/highlighting preview for the README.
- `output/lilt-demo.vtt`: spoken captions for the recorded film.

The generated speech files in `assets/` are public marketing material, explicitly included so anyone can reproduce the export without installing the speech model. They contain no user captures or reading history.
