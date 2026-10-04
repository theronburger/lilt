export async function initializeDemo() {
  const scene = document.querySelector('#demo');
  const chat = document.querySelector('#demo-chat');
  const confirmation = document.querySelector('#sound-confirmation');
  const send = confirmation.querySelector('button');
  const silent = document.querySelector('#start-silent');
  const replay = document.querySelector('#replay-intro');
  const text = document.querySelector('#reading-text');
  const audio = document.querySelector('#reading-audio');
  const controls = document.querySelector('#reader-controls');
  const play = document.querySelector('#play-reading');
  const progress = document.querySelector('#reading-progress');
  const speed = document.querySelector('#reading-speed');
  const sound = document.querySelector('#reading-sound');
  const hint = document.querySelector('#reader-hint');
  const status = document.querySelector('#reader-status');
  const caption = document.querySelector('#demo-caption');
  const loadStatus = document.querySelector('#demo-load-status');
  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
  let phaseTimer;
  let animationFrame;
  let activeWord = -1;
  let started = false;
  let words;

  scene.classList.add('demo-enhanced');
  const setPhase = phase => {
    scene.dataset.phase = phase;
    document.querySelector('#reading-window').setAttribute('aria-hidden', String(!['reading', 'capturing'].includes(phase)));
  };
  function showChat() {
    clearTimeout(phaseTimer);
    setPhase('waiting');
    chat.hidden = false;
  }
  function showIntro() {
    clearTimeout(phaseTimer);
    if (reducedMotion.matches) return showChat();
    setPhase('intro');
    chat.hidden = true;
    phaseTimer = setTimeout(showChat, 3600);
  }

  const visibility = new IntersectionObserver(([entry]) => {
    if (entry.isIntersecting && !started) {
      started = true;
      showIntro();
    } else if (!entry.isIntersecting && !audio.paused) {
      audio.pause();
      status.textContent = 'Paused. Press Play when you’re ready.';
    }
  });
  visibility.observe(scene);
  reducedMotion.addEventListener('change', () => {
    if (reducedMotion.matches && scene.dataset.phase === 'intro') showChat();
  });

  loadStatus.textContent = 'Loading the sample…';
  try {
    const [response, recording] = await Promise.all([
      fetch('/assets/demo-reading.json'), fetch(audio.dataset.src),
    ]);
    if (!response.ok || !recording.ok) throw new Error('Reading unavailable');
    const [reading, audioBlob] = await Promise.all([response.json(), recording.blob()]);
    words = reading.words;
    if (!words?.length || words.map(word => word.text).join(' ') !== text.textContent.trim()) {
      throw new Error('Reading timings do not match the passage');
    }
    progress.max = reading.duration;
    // A complete short clip stays seekable on static hosts without byte-range support.
    audio.src = URL.createObjectURL(audioBlob);
    audio.load();
    loadStatus.textContent = '';
  } catch {
    showChat();
    loadStatus.textContent = 'The interactive sample couldn’t load. You can still watch the recorded demo below.';
    const fallback = document.createElement('a');
    fallback.href = '/assets/lilt-demo.mp4';
    fallback.textContent = 'Watch the recorded demo';
    fallback.className = 'quiet-button';
    loadStatus.append(document.createElement('br'), fallback);
    return;
  }

  const wordButtons = words.map((word, index) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'word';
    button.textContent = word.text;
    button.dataset.word = index;
    button.tabIndex = index === 0 ? 0 : -1;
    button.disabled = true;
    button.setAttribute('aria-label', `Read from “${word.text}”`);
    return button;
  });
  text.replaceChildren(...wordButtons.flatMap((button, index) => index ? [' ', button] : [button]));
  send.disabled = false;
  silent.disabled = false;
  const resize = new ResizeObserver(() => {
    const height = document.querySelector('#reading-window').offsetHeight + 195;
    scene.style.minHeight = `max(var(--demo-min-height, 550px), ${height}px)`;
  });
  resize.observe(document.querySelector('#reading-window'));

  function updatePosition() {
    const current = audio.currentTime;
    const index = words.findIndex(word => current >= word.start && current < word.end);
    if (index !== activeWord) {
      wordButtons[activeWord]?.classList.remove('current');
      wordButtons[index]?.classList.add('current');
      activeWord = index;
    }
    progress.value = current;
    progress.setAttribute('aria-valuetext', `${Math.floor(current)} of ${Math.ceil(Number(progress.max))} seconds`);
  }
  function animatePosition() {
    updatePosition();
    if (!audio.paused) animationFrame = requestAnimationFrame(animatePosition);
  }
  function showAudioError() {
    status.textContent = 'The sample audio couldn’t load. Press Play to retry, or ';
    const fallback = document.createElement('a');
    fallback.href = '/assets/lilt-demo.mp4';
    fallback.textContent = 'watch the recorded demo';
    status.append(fallback, '.');
  }
  function playAudio() {
    status.textContent = '';
    // Keep play() in the user gesture, before the capture animation or any await.
    audio.play().catch(error => {
      if (error.name === 'AbortError') return;
      if (audio.error) showAudioError();
      else status.textContent = 'Your browser paused the audio. Press Play to start.';
    });
  }
  function updateSound() {
    controls.dataset.muted = audio.muted;
    sound.setAttribute('aria-label', audio.muted ? 'Turn on sound' : 'Mute reading');
    sound.setAttribute('aria-pressed', String(audio.muted));
  }
  function beginReading(muted, keyboard) {
    clearTimeout(phaseTimer);
    audio.muted = muted;
    updateSound();
    chat.hidden = true;
    controls.hidden = false;
    hint.hidden = false;
    replay.hidden = false;
    wordButtons.forEach(button => { button.disabled = false; });
    caption.textContent = 'A sample passage. A real Kokoro voice. Try the controls.';
    setPhase(reducedMotion.matches ? 'reading' : 'capturing');
    if (!reducedMotion.matches) phaseTimer = setTimeout(() => setPhase('reading'), 550);
    playAudio();
    (keyboard ? play : document.querySelector('#reading-window')).focus({ preventScroll: true });
  }
  confirmation.addEventListener('submit', event => {
    event.preventDefault();
    beginReading(false, send.matches(':focus-visible'));
  });
  silent.addEventListener('click', () => beginReading(true, silent.matches(':focus-visible')));
  play.addEventListener('click', () => {
    if (audio.paused) {
      if (audio.error) audio.load();
      if (audio.ended) audio.currentTime = 0;
      playAudio();
    } else audio.pause();
  });
  progress.addEventListener('input', () => {
    audio.currentTime = Number(progress.value);
    updatePosition();
  });
  progress.addEventListener('keydown', event => {
    const delta = { ArrowLeft: -1, ArrowDown: -1, ArrowRight: 1, ArrowUp: 1 }[event.key];
    if (delta === undefined) return;
    event.preventDefault();
    audio.currentTime = Math.max(0, Math.min(Number(progress.max), audio.currentTime + delta));
    updatePosition();
  });
  speed.addEventListener('change', () => { audio.playbackRate = Number(speed.value); });
  sound.addEventListener('click', () => {
    audio.muted = !audio.muted;
    updateSound();
  });
  text.addEventListener('click', event => {
    const button = event.target.closest('[data-word]');
    if (!button || button.disabled) return;
    audio.currentTime = words[Number(button.dataset.word)].start;
    updatePosition();
    playAudio();
  });
  text.addEventListener('keydown', event => {
    const index = wordButtons.indexOf(event.target);
    if (index < 0) return;
    const target = { ArrowLeft: index - 1, ArrowRight: index + 1, Home: 0, End: words.length - 1 }[event.key];
    if (target === undefined) return;
    event.preventDefault();
    wordButtons.forEach(button => { button.tabIndex = -1; });
    const next = wordButtons[Math.max(0, Math.min(words.length - 1, target))];
    next.tabIndex = 0;
    next.focus({ preventScroll: true });
  });
  audio.addEventListener('play', () => {
    controls.dataset.playing = 'true';
    play.setAttribute('aria-label', 'Pause reading');
    cancelAnimationFrame(animationFrame);
    animatePosition();
  });
  audio.addEventListener('pause', () => {
    controls.dataset.playing = 'false';
    play.setAttribute('aria-label', 'Play reading');
    cancelAnimationFrame(animationFrame);
    updatePosition();
  });
  audio.addEventListener('seeked', updatePosition);
  audio.addEventListener('ended', () => {
    status.textContent = 'That’s Lilt. Replay, or pick a word to hear it again.';
    play.setAttribute('aria-label', 'Replay reading');
  });
  audio.addEventListener('error', () => {
    if (scene.dataset.phase === 'reading' || scene.dataset.phase === 'capturing') {
      showAudioError();
    }
  });
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
      audio.pause();
      if (scene.dataset.phase === 'intro') showChat();
    }
  });
  replay.addEventListener('click', () => {
    audio.pause();
    audio.currentTime = 0;
    updatePosition();
    status.textContent = '';
    controls.hidden = true;
    hint.hidden = true;
    replay.hidden = true;
    wordButtons.forEach(button => { button.disabled = true; });
    caption.textContent = 'A short, interactive demo. Sound starts when you’re ready.';
    showChat();
    send.focus({ preventScroll: true });
  });
  updatePosition();
}
