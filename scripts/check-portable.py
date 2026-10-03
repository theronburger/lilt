#!/usr/bin/env python3
"""Exercise the shipped worker from a relocated app with an empty model cache."""
import json
import os
import pathlib
import plistlib
import shutil
import subprocess
import sys
import tempfile

source = pathlib.Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory(prefix='lilt-portable-') as temporary:
    temporary = pathlib.Path(temporary)
    bundle = (temporary / 'Moved Lilt.app').resolve()
    shutil.copytree(source, bundle, symlinks=True)
    resources = bundle / 'Contents/Resources'
    config = json.loads((resources / 'runtime.json').read_text())
    assert not pathlib.Path(config['python']).is_absolute(), 'Release embeds a machine-specific Python path'
    assert 'LiltSourcePath' not in plistlib.loads((bundle / 'Contents/Info.plist').read_bytes())
    for link in resources.rglob('*'):
        if link.is_symlink():
            assert link.resolve().is_relative_to(bundle), f'External symlink: {link}'
        elif link.is_file():
            with link.open('rb') as file:
                native = file.read(4) in {b'\xfe\xed\xfa\xcf', b'\xcf\xfa\xed\xfe', b'\xca\xfe\xba\xbe'}
            if native:
                libraries = subprocess.check_output(['otool', '-L', str(link)], text=True).splitlines()[1:]
                for library in libraries:
                    if not library.startswith('\t'):
                        continue
                    dependency = library.strip().split(' (', 1)[0]
                    install_names = subprocess.check_output(['otool', '-D', str(link)], text=True).splitlines()[1:] if not dependency.startswith(('@', '/usr/lib/', '/System/Library/')) else []
                    if dependency in install_names:
                        continue
                    assert dependency.startswith(('@', '/usr/lib/', '/System/Library/')), f'External library: {link.name}: {dependency}'
    environment = {**os.environ, 'HOME': str(temporary), 'HF_HOME': str(temporary / 'empty-cache'),
                   'HF_HUB_OFFLINE': '1', 'TRANSFORMERS_OFFLINE': '1',
                   'LILT_MODEL_DIRECTORY': str(resources / config['model']), 'TOKENIZERS_PARALLELISM': 'false'}
    text = 'Lilt reads this sentence entirely on your Mac.'
    requests = ''.join(json.dumps({'id': voice, 'text': text, 'voice': voice}) + '\n' for voice in ('af_heart', 'bf_emma'))
    command = [str(resources / config['python']), '-I', '-B', '-u', str(resources / 'Speech/worker.py'), str(temporary / 'audio')]
    result = subprocess.run(command, input=requests, capture_output=True, text=True, cwd=temporary, env=environment, timeout=120)
    if result.returncode:
        raise SystemExit(result.stderr)
    events = [json.loads(line) for line in result.stdout.splitlines()]
    failures = [event for event in events if event['type'] == 'error']
    assert not failures, failures
    for voice in ('af_heart', 'bf_emma'):
        chunks = [event['chunk'] for event in events if event['id'] == voice and event['type'] == 'chunk']
        assert chunks and chunks[0]['words'], events
        assert all(0 <= word['charIndex'] < len(text) for chunk in chunks for word in chunk['words'])
        assert any(event['id'] == voice and event['type'] == 'complete' for event in events), events
    print('Portable offline synthesis passed: relocated app, empty cache, American and British voices.')
