#!/usr/bin/env python3
"""Package the original public Kokoro reading for the interactive website."""
import json
import math
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import wave

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'marketing/assets'
OUTPUT = ROOT / 'website/public/assets'


def require(condition, message):
    if not condition:
        raise ValueError(message)


def main():
    for tool in ('ffmpeg', 'ffprobe'):
        require(shutil.which(tool), f'{tool} is required on PATH')
    manifest = json.loads((SOURCE / 'narration.json').read_text())
    text = manifest['text']
    clip = manifest['clips']['text']
    intervals = clip['words']
    encoded = text.encode('utf-16-le')
    words, used = [], set()
    for token in re.finditer(r'\S+', text):
        # App/Kokoro mappings use UTF-16, including when the text has emoji.
        start = len(text[:token.start()].encode('utf-16-le')) // 2
        end = start + len(token.group().encode('utf-16-le')) // 2
        covered = [(index, word) for index, word in enumerate(intervals)
                   if start <= word['charIndex'] and word['charIndex'] + word['charLength'] <= end]
        require(covered, f'No measured timing for {token.group()!r}')
        reconstructed = ''.join(encoded[word['charIndex'] * 2:
                                        (word['charIndex'] + word['charLength']) * 2].decode('utf-16-le')
                                for _, word in covered)
        require(reconstructed == token.group(), f'Incomplete timing coverage for {token.group()!r}')
        used.update(index for index, _ in covered)
        # Attach punctuation to its display word, preserving its measured time.
        words.append({'text': token.group(), 'start': covered[0][1]['startMs'] / 1000,
                      'end': covered[-1][1]['endMs'] / 1000})
    require(used == set(range(len(intervals))), 'Some source timings are unused')
    require(' '.join(word['text'] for word in words) == text, 'Display words do not reproduce the text')
    with wave.open(str(SOURCE / 'text.wav')) as audio:
        duration = audio.getnframes() / audio.getframerate()
        sample_rate = audio.getframerate()
    require(math.isclose(duration, clip['durationMs'] / 1000, abs_tol=1 / sample_rate),
            'The recording and timing manifest have different durations')
    previous_end = 0
    for word in words:
        require(previous_end <= word['start'] < word['end'] <= duration,
                f'Invalid or overlapping timing: {word}')
        previous_end = word['end']
    reading = {'text': text, 'duration': duration, 'words': words}
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='lilt-reading-') as directory:
        audio_path = Path(directory) / 'demo-reading.m4a'
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
                        '-i', str(SOURCE / 'text.wav'), '-vn', '-c:a', 'aac', '-b:a', '96k',
                        '-ar', '24000', '-ac', '1', '-movflags', '+faststart', '-map_metadata', '-1',
                        str(audio_path)], check=True)
        probe = json.loads(subprocess.check_output([
            'ffprobe', '-v', 'error', '-show_entries', 'format=duration:stream=start_time',
            '-of', 'json', str(audio_path)], text=True))
        require(math.isclose(float(probe['format']['duration']), duration, abs_tol=1 / sample_rate),
                'Encoded audio has a different duration')
        require(float(probe['streams'][0]['start_time']) == 0, 'Encoded audio must start at zero')
        shutil.copyfile(audio_path, OUTPUT / audio_path.name)
    (OUTPUT / 'demo-reading.json').write_text(json.dumps(reading, ensure_ascii=False, indent=2) + '\n')
    print(f'{len(words)} words, {duration:.3f}s, {(OUTPUT / "demo-reading.m4a").stat().st_size:,} audio bytes')


if __name__ == '__main__':
    main()
