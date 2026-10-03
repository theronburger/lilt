import { readFile, stat } from 'node:fs/promises';
import { resolve } from 'node:path';
import assert from 'node:assert/strict';

const root = resolve(import.meta.dirname, '../public');
const html = await readFile(resolve(root, 'index.html'), 'utf8');
const paths = [...html.matchAll(/(?:src|href|poster)="(\/[^"#]*)"/g)].map(match => match[1]);
for (const path of new Set(paths)) {
  if (path === '/') continue;
  const info = await stat(resolve(root, `.${path}`));
  assert(info.isFile(), `${path} must be a file`);
  assert(info.size < 25 * 1024 * 1024, `${path} exceeds Cloudflare's static asset limit`);
}
const ids = new Set([...html.matchAll(/id="([^"]+)"/g)].map(match => match[1]));
for (const [, id] of html.matchAll(/href="#([^"]+)"/g)) assert(ids.has(id), `Missing anchor #${id}`);
assert.equal([...html.matchAll(/<h1\b/g)].length, 1, 'There must be exactly one h1');
assert(html.includes('kind="captions"'), 'The demo must have captions');
assert(!html.includes('autoplay'), 'The demo must not autoplay');
assert(html.includes('Apple-notarized'), 'Early release installation detail is required');
console.log(`Website checked: ${new Set(paths).size} local assets, section anchors, captions, release notice.`);
