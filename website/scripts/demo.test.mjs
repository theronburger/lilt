import test from 'node:test';
import assert from 'node:assert/strict';
import { initializeDemo } from '../public/demo.js';

const reading = {
  text: 'Read this aloud.', duration: 3,
  words: [{ text: 'Read', start: 0.2, end: 1 }, { text: 'this', start: 1, end: 2 },
    { text: 'aloud.', start: 2, end: 2.8 }],
};

// Only the DOM/media surface used by the demo, with controlled time and gestures.
class Element {
  constructor() {
    this.dataset = {}; this.style = {}; this.children = []; this.attributes = {};
    this.listeners = new Map(); this.textContent = ''; this.hidden = false;
    this.classList = { add() {}, remove() {} }; this.offsetHeight = 200;
  }
  addEventListener(name, listener) {
    this.listeners.set(name, [...(this.listeners.get(name) || []), listener]);
  }
  emit(name, properties = {}) {
    const event = { target: this, preventDefault() {}, ...properties };
    for (const listener of this.listeners.get(name) || []) listener(event);
  }
  setAttribute(name, value) { this.attributes[name] = value; }
  querySelector() { return this.children[0]; }
  replaceChildren(...children) { this.children = children; }
  append(...children) { this.children.push(...children); }
  closest() { return this.dataset.word === undefined ? null : this; }
  matches() { return false; }
  focus() { this.focused = true; }
}

async function setup(t, { reduced = false, brokenJSON = false } = {}) {
  const elements = new Map();
  const get = id => {
    if (!elements.has(id)) elements.set(id, new Element());
    return elements.get(id);
  };
  const document = new Element();
  document.querySelector = selector => get(selector.slice(1));
  document.createElement = () => new Element();
  const send = new Element(); send.disabled = true;
  get('sound-confirmation').children = [send];
  get('start-silent').disabled = true;
  get('reading-text').textContent = reading.text;
  const audio = get('reading-audio');
  Object.assign(audio, { currentTime: 0, paused: true, ended: false, muted: false, calls: [] });
  audio.dataset.src = '/assets/demo-reading.m4a';
  audio.load = () => {};
  t.mock.method(URL, 'createObjectURL', () => 'blob:prepared-reading');
  let gesture = false, intersection, timerId = 0;
  const timers = new Map();
  audio.play = () => {
    audio.calls.push({ time: audio.currentTime, muted: audio.muted, gesture });
    audio.paused = false; audio.ended = false; audio.emit('play');
    return Promise.resolve();
  };
  audio.pause = () => { audio.paused = true; audio.emit('pause'); };
  const motion = new Element(); motion.matches = reduced;
  const globals = {
    document, matchMedia: () => motion,
    fetch: async () => ({ ok: true, blob: async () => new Blob(['audio']), json: async () => {
      if (brokenJSON) throw new SyntaxError('Invalid JSON');
      return reading;
    } }),
    IntersectionObserver: class { constructor(callback) { intersection = callback; } observe() {} },
    ResizeObserver: class { constructor(callback) { this.callback = callback; } observe() { this.callback(); } },
    requestAnimationFrame: () => 1, cancelAnimationFrame() {},
    setTimeout: callback => { timers.set(++timerId, callback); return timerId; },
    clearTimeout: id => timers.delete(id),
  };
  const original = Object.fromEntries(Object.keys(globals).map(key => [key, Object.getOwnPropertyDescriptor(globalThis, key)]));
  Object.assign(globalThis, globals);
  t.after(() => {
    for (const [key, descriptor] of Object.entries(original)) {
      if (descriptor) Object.defineProperty(globalThis, key, descriptor);
      else delete globalThis[key];
    }
  });
  await initializeDemo();
  return {
    get, audio, send, document, motion,
    visible: value => intersection([{ isIntersecting: value }]),
    advance: () => { const pending = [...timers.values()]; timers.clear(); pending.forEach(callback => callback()); },
    act: (id, event = 'click', properties) => {
      gesture = true;
      try { get(id).emit(event, properties); } finally { gesture = false; }
    },
    words: () => get('reading-text').children.filter(child => child instanceof Element),
  };
}

test('intro and waiting gate stay silent until an explicit Send gesture', async t => {
  const h = await setup(t);
  h.visible(true);
  assert.equal(h.get('demo').dataset.phase, 'intro');
  h.advance(); h.advance();
  assert.equal(h.get('demo').dataset.phase, 'waiting');
  assert.equal(h.audio.calls.length, 0);
  assert(h.words().every(word => word.disabled));
  h.act('sound-confirmation', 'submit');
  assert.deepEqual(h.audio.calls, [{ time: 0, muted: false, gesture: true }]);
  assert.equal(h.get('demo').dataset.phase, 'capturing');
  h.advance();
  assert.equal(h.get('demo').dataset.phase, 'reading');
});

test('reduced motion opens the gate immediately and skips the capture transition', async t => {
  const h = await setup(t, { reduced: true });
  h.visible(true);
  assert.equal(h.get('demo').dataset.phase, 'waiting');
  assert.equal(h.audio.calls.length, 0);
  h.act('sound-confirmation', 'submit');
  assert.equal(h.get('demo').dataset.phase, 'reading');
  assert.equal(h.audio.calls.length, 1);
});

test('continue without sound plays the sample muted', async t => {
  const h = await setup(t);
  h.act('start-silent');
  assert.deepEqual(h.audio.calls, [{ time: 0, muted: true, gesture: true }]);
  assert.equal(h.get('reading-sound').attributes['aria-pressed'], 'true');
});

test('clicking a word after playback ends resumes there, even before ended state clears', async t => {
  const h = await setup(t);
  h.act('sound-confirmation', 'submit');
  h.audio.currentTime = reading.duration; h.audio.paused = true; h.audio.ended = true;
  h.audio.emit('ended');
  h.act('reading-text', 'click', { target: h.words()[1] });
  assert.equal(h.audio.currentTime, reading.words[1].start);
  assert.deepEqual(h.audio.calls.at(-1), { time: 1, muted: false, gesture: true });
});

test('replay pauses, clears position and disables word playback until the gate is sent again', async t => {
  const h = await setup(t);
  h.act('sound-confirmation', 'submit'); h.audio.currentTime = 1.5;
  h.act('replay-intro'); h.advance();
  assert.equal(h.audio.paused, true);
  assert.equal(h.audio.currentTime, 0);
  assert.equal(h.get('demo').dataset.phase, 'waiting');
  assert.equal(h.get('reader-controls').hidden, true);
  assert.equal(h.get('demo-chat').hidden, false);
  assert(h.words().every(word => word.disabled));
  h.act('reading-text', 'click', { target: h.words()[1] });
  assert.equal(h.audio.calls.length, 1);
});

test('invalid timing JSON leaves a recorded-film fallback and no enabled sound action', async t => {
  const h = await setup(t, { brokenJSON: true });
  assert.equal(h.audio.calls.length, 0);
  assert.equal(h.send.disabled, true);
  assert.equal(h.get('start-silent').disabled, true);
  assert(h.get('demo-load-status').children.some(child => child.href === '/assets/lilt-demo.mp4'));
});

test('leaving the viewport or hiding the tab pauses without automatic resumption', async t => {
  const h = await setup(t);
  h.visible(true); h.advance(); h.act('sound-confirmation', 'submit');
  h.visible(false);
  assert.equal(h.audio.paused, true);
  h.visible(true);
  assert.equal(h.audio.calls.length, 1);
  h.act('play-reading');
  h.document.hidden = true; h.document.emit('visibilitychange');
  assert.equal(h.audio.paused, true);
  h.document.hidden = false; h.document.emit('visibilitychange');
  assert.equal(h.audio.calls.length, 2);
});
