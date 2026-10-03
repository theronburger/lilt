const demoVideo = document.querySelector('#demo-video');
for (const button of document.querySelectorAll('[data-play-demo]')) {
  button.addEventListener('click', () => {
    document.querySelector('#demo').scrollIntoView({ block: 'center', behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' });
    demoVideo.focus({ preventScroll: true });
    demoVideo.play().catch(() => {});
  });
}
const transcript = document.querySelector('#demo-transcript');
for (const link of document.querySelectorAll('a[href="#demo-transcript"]')) {
  link.addEventListener('click', () => { transcript.open = true; });
}
