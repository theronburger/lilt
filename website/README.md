# Lilt website

Static HTML, CSS and a small playback script. No build step, external fonts, analytics, or client dependencies.

```sh
npm run dev
npm run check
```

The preview serves `public/` at http://localhost:4179. Deploy that directory with Cloudflare Workers static assets using `wrangler deploy` from this folder and the existing account credentials. Do not put tokens into this directory.

The film, poster and captions come from `../marketing/output/`. After rendering, copy `lilt-demo.mp4`, `lilt-demo-poster.webp`, and `lilt-demo.vtt` (named `demo-captions.vtt` here) into `public/assets/`. See the marketing README for the editable web animation and rendering instructions. Keep all files below Cloudflare’s 25 MiB asset limit.

The original logo, favicon and social image are editable SVGs under `public/assets/`. The social image also has a PNG export for link previews. The blue mark is three rounded strokes forming an L and sound bars.
