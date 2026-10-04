import { initializeDemo } from './demo.js';

initializeDemo();

const transcript = document.querySelector('#demo-transcript');
for (const link of document.querySelectorAll('a[href="#demo-transcript"]')) {
  link.addEventListener('click', () => { transcript.open = true; });
}
