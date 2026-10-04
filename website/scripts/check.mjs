import { readFile, stat } from 'node:fs/promises';
import { resolve } from 'node:path';
import assert from 'node:assert/strict';

const root = resolve(import.meta.dirname, '../public');
const html = await readFile(resolve(root, 'index.html'), 'utf8');
const paths = [...html.matchAll(/(?:src|href|poster)="(\/[^"#]*)"/g)].map(match => match[1]);
const checked = new Set();
async function checkAsset(path) {
  if (path === '/' || checked.has(path)) return;
  checked.add(path);
  const info = await stat(resolve(root, `.${path}`));
  assert(info.isFile(), `${path} must be a file`);
  assert(info.size < 25 * 1024 * 1024, `${path} exceeds Cloudflare's static asset limit`);
  if (path.endsWith('.js')) {
    const source = await readFile(resolve(root, `.${path}`), 'utf8');
    const references = [
      ...source.matchAll(/\b(?:from\s*|import\s*)['"]([^'"]+)['"]/g),
      ...source.matchAll(/\b(?:fetch|import)\(\s*['"]([^'"]+)['"]/g),
    ];
    for (const [, reference] of references) {
      if (!reference.startsWith('.') && !reference.startsWith('/')) continue;
      await checkAsset(new URL(reference, `https://lilt.invalid${path}`).pathname);
    }
  }
}
for (const path of new Set(paths)) await checkAsset(path);
assert(checked.has('/demo.js'), 'The live demo module must be imported by the page');
assert(checked.has('/assets/demo-reading.json'), 'The live demo must load its word timings');
assert(checked.has('/assets/demo-reading.m4a'), 'The full reading audio must be included');
const ids = new Set([...html.matchAll(/id="([^"]+)"/g)].map(match => match[1]));
for (const [, id] of html.matchAll(/href="#([^"]+)"/g)) assert(ids.has(id), `Missing anchor #${id}`);
assert.equal([...html.matchAll(/<h1\b/g)].length, 1, 'There must be exactly one h1');
assert(!/<(?:audio|video)\b[^>]*\bautoplay\b/i.test(html), 'Audio must wait for the visitor');
const gate = html.match(/<form\b[^>]*id="sound-confirmation"[^>]*>([\s\S]*?)<\/form>/)?.[1];
assert(gate && /<button\b[^>]*type="submit"/.test(gate), 'The sound gate must have a real Send action');
assert(/<p\b[^>]*>[^<]+<\/p>/.test(gate), 'The sound gate must contain a prefilled reply');
assert(ids.has('start-silent'), 'The visitor must be able to continue without sound');
assert(ids.has('demo-transcript') && ids.has('transcript-content'), 'Keep the readable demo transcript');
assert(/href="\/assets\/lilt-demo\.mp4"/.test(html), 'Keep the recorded film linked as a fallback');
assert(html.includes('Apple-notarized'), 'Early release installation detail is required');

const reading = JSON.parse(await readFile(resolve(root, 'assets/demo-reading.json'), 'utf8'));
const source = JSON.parse(await readFile(resolve(root, '../../marketing/assets/narration.json'), 'utf8'));
assert.equal(reading.text, source.text, 'The live sample must retain the full recorded text');
assert.equal(reading.duration, source.clips.text.durationMs / 1000, 'The full recording duration must match');
assert(Number.isFinite(reading.duration) && reading.duration > 0);
assert(Array.isArray(reading.words) && reading.words.length > 0);
assert.equal(reading.words.map(word => word.text).join(' '), reading.text, 'All words must reconstruct the sample');
assert(html.includes(reading.text), 'The visible sample and transcript must contain the recorded text');
let previousEnd = 0;
let sourceIntervals = 0;
const tokens = [...reading.text.matchAll(/\S+/gu)];
assert.equal(reading.words.length, tokens.length);
for (const [index, word] of reading.words.entries()) {
  assert(Number.isFinite(word.start) && Number.isFinite(word.end), `Word ${index} needs numeric times`);
  assert(word.start >= previousEnd && word.start < word.end && word.end <= reading.duration,
    `Word ${index} must be ordered and inside the audio duration`);
  const token = tokens[index];
  const intervals = source.clips.text.words.filter(item => item.charIndex >= token.index
    && item.charIndex + item.charLength <= token.index + token[0].length);
  assert(intervals.length, `Word ${index} needs measured Kokoro timings`);
  assert.equal(intervals.map(item => source.text.slice(item.charIndex, item.charIndex + item.charLength)).join(''), word.text);
  assert.equal(word.start, intervals[0].startMs / 1000);
  assert.equal(word.end, intervals.at(-1).endMs / 1000);
  sourceIntervals += intervals.length;
  previousEnd = word.end;
}
assert.equal(sourceIntervals, source.clips.text.words.length, 'Every source timing interval must be included');
console.log(`Website checked: ${checked.size} local assets, anchors, sound gate, transcript, fallback film, ${reading.words.length} measured words (${reading.duration}s), release notice.`);
