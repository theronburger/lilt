#!/usr/bin/env python3
"""Build the public demo soundtrack with Kokoro's measured word timings."""
import json
import os
from pathlib import Path
import shutil
import sys
import wave

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'Speech'))
os.environ.setdefault('HF_HUB_OFFLINE', '1')
from speech_renderer import Renderer, RATE

source = json.loads((ROOT / 'marketing/script.json').read_text())
cache = ROOT / 'work/marketing/audio'
renderer = Renderer(cache)
clips = {key: renderer.render(source[key], source['voice']) for key in ['reply', 'text']}
assets = ROOT / 'marketing/assets'
assets.mkdir(exist_ok=True)
for key, clip in clips.items():
    shutil.copyfile(cache / f"{clip['key']}.wav", assets / f'{key}.wav')

# Play through the second sentence, then demonstrate clicking “The controls”.
text = source['text']
seek_index = text.index('The controls')
seek_word = next(word for word in clips['text']['words'] if word['charIndex'] == seek_index)
first_end = next(word['endMs'] for word in clips['text']['words'] if text[word['charIndex']:word['charIndex'] + word['charLength']].strip('.,') == 'goes')
reading_start = 14000
seek_at = reading_start + first_end + 1300
seek_offset = seek_word['startMs']
reading_end = seek_at + clips['text']['durationMs'] - seek_offset
end_start = reading_end + 600
duration = end_start + 3600
segments = [
    {'clip': 'reply', 'at': 8800, 'from': 0, 'to': clips['reply']['durationMs']},
    {'clip': 'text', 'at': reading_start, 'from': 0, 'to': first_end},
    {'clip': 'text', 'at': seek_at, 'from': seek_offset, 'to': clips['text']['durationMs']},
]
public_clips = {name: {field: clip[field] for field in ['voice', 'durationMs', 'words']} for name, clip in clips.items()}
manifest = {**source, 'clips': public_clips, 'readingStart': reading_start, 'firstEnd': first_end,
            'seekAt': seek_at, 'seekOffset': seek_offset, 'readingEnd': reading_end,
            'endStart': end_start, 'durationMs': duration, 'segments': segments}
(assets / 'narration.json').write_text(json.dumps(manifest, indent=2) + '\n')
# The same cuts drive the browser highlights and the exported soundtrack.
pcm = bytearray(round(duration / 1000 * RATE) * 2)
for segment in segments:
    with wave.open(str(assets / f"{segment['clip']}.wav"), 'rb') as track:
        track.setpos(round(segment['from'] / 1000 * RATE))
        samples = track.readframes(round((segment['to'] - segment['from']) / 1000 * RATE))
    offset = round(segment['at'] / 1000 * RATE) * 2
    pcm[offset:offset + len(samples)] = samples
with wave.open(str(assets / 'soundtrack.wav'), 'wb') as track:
    track.setnchannels(1)
    track.setsampwidth(2)
    track.setframerate(RATE)
    track.writeframes(pcm)
print(f'{duration / 1000:.2f}s; real Kokoro timings; {len(clips["text"]["words"])} spoken words')

def stamp(milliseconds):
    ms = round(milliseconds)
    return f'{ms // 3600000:02}:{ms // 60000 % 60:02}:{ms // 1000 % 60:02}.{ms % 1000:03}'

captions = ['WEBVTT', '']
for segment in segments:
    clip = clips[segment['clip']]
    encoded_text = source[segment['clip']].encode('utf-16-le')
    groups, group = [], []
    for word in clip['words']:
        if word['startMs'] >= segment['to'] or word['endMs'] <= segment['from']:
            continue
        group.append(word)
        token = encoded_text[word['charIndex'] * 2:(word['charIndex'] + word['charLength']) * 2].decode('utf-16-le')
        if token == '.' or (len(group) >= 12 and token == ','):
            groups.append(group)
            group = []
    if group:
        groups.append(group)
    for group in groups:
        first, last = group[0], group[-1]
        line = encoded_text[first['charIndex'] * 2:(last['charIndex'] + last['charLength']) * 2].decode('utf-16-le')
        start = segment['at'] + max(segment['from'], first['startMs']) - segment['from']
        end = segment['at'] + min(segment['to'], last['endMs']) - segment['from']
        captions.extend([f'{stamp(start)} --> {stamp(end)}', line, ''])
output = ROOT / 'marketing/output'
output.mkdir(exist_ok=True)
(output / 'lilt-demo.vtt').write_text('\n'.join(captions))
