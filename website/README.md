# Lilt website

Static HTML, CSS and a small interactive demo. No build step, external fonts, analytics, or client dependencies.

```sh
npm run dev
npm run check
```

The preview serves `public/` at http://localhost:4179. Deploy that directory with Cloudflare Workers static assets using `wrangler deploy` from this folder and the existing account credentials. Do not put tokens into this directory.

The opening document pile and chat lead to a real sound confirmation. Sending the prefilled reply starts the sample; visitors can also continue muted, click words to seek, change speed, or pause. The sample is prepared public content, not a capture of the visitor’s screen. Its 190 KB audio file is loaded as a local blob before enabling Send, so word seeking also works on static hosts without HTTP byte-range support. Its highlights follow the audio position and measured Kokoro timings.

To regenerate the web audio assets from the full original reading, install `ffmpeg` (including `ffprobe`) and run from this folder:

```sh
python3 scripts/prepare-reading.py
npm run check
```

This reads `../marketing/assets/text.wav` and `narration.json`, then writes `public/assets/demo-reading.m4a` and `demo-reading.json`. The JSON schema is `{text, duration, words: [{text, start, end}]}`; all times are seconds. Punctuation is attached to its word without dropping its measured interval. The AAC file retains the full recording and has a zero-based playback timeline; use `audio.currentTime` directly. Encoding is reproducible with the same FFmpeg version, although encoded bytes may vary across encoder versions. No model download, provider call, or credentials are needed. To change the spoken passage itself, regenerate speech first using the [marketing instructions](../marketing/README.md).

`npm run check` checks local assets and imported demo modules, section links, the sound gate, readable transcript, fallback film, and completeness of word timings against the original recording manifest. Playback, seeking, touch controls and reduced motion still need a browser check.

The recorded film remains linked as a fallback. After rendering, copy `lilt-demo.mp4` from `../marketing/output/` into `public/assets/`. Its poster and `lilt-demo.vtt` captions (named `demo-captions.vtt` here) can be kept alongside it for video distribution. The live sample does not use the film’s edited soundtrack. Keep all files below Cloudflare’s 25 MiB asset limit.

The original logo, favicon and social image are editable SVGs under `public/assets/`. The social image also has a PNG export for link previews. The blue mark is three rounded strokes forming an L and sound bars.
