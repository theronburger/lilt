#!/usr/bin/env python3
"""Build a relocatable, offline speech runtime from pinned public dependencies."""
import hashlib
import json
import pathlib
import platform
import shutil
import subprocess
import tarfile
import urllib.request

root = pathlib.Path(__file__).resolve().parents[1]
lock = json.loads((root / 'Resources/runtime-lock.json').read_text())
directory = root / 'work/portable-runtime'
runtime = directory / 'python'
model = directory / 'Kokoro'
stamp = directory / 'prepared.sha256'
fingerprint = hashlib.sha256(b''.join((root / name).read_bytes() for name in
    ['Resources/runtime-lock.json', 'Resources/source-lock.json', 'Speech/requirements.lock', 'Speech/voices.json', 'scripts/prepare-runtime.py', 'scripts/prepare-espeak.py'])).hexdigest()
if platform.machine() != 'arm64' or platform.system() != 'Darwin':
    raise SystemExit('The portable runtime currently supports Apple Silicon macOS only.')
if stamp.exists() and stamp.read_text() == fingerprint:
    print(f'Portable runtime is ready: {directory}')
    raise SystemExit(0)
directory.mkdir(parents=True, exist_ok=True)
archive = directory / 'python.tar.gz'
if not archive.exists() or hashlib.sha256(archive.read_bytes()).hexdigest() != lock['python_sha256']:
    print('Downloading pinned Python runtime…', flush=True)
    urllib.request.urlretrieve(lock['python_url'], archive)
if hashlib.sha256(archive.read_bytes()).hexdigest() != lock['python_sha256']:
    raise SystemExit('Python archive checksum does not match runtime-lock.json.')
shutil.rmtree(runtime, ignore_errors=True)
with tarfile.open(archive) as source:
    source.extractall(directory, filter='data')
python = runtime / 'bin/python3'
subprocess.run(['uv', 'pip', 'install', '--python', str(python), '--no-deps', '-r', str(root / 'Speech/requirements.lock')], check=True)
subprocess.run(['uv', 'pip', 'check', '--python', str(python)], check=True)
subprocess.run([str(python), str(root / 'scripts/prepare-espeak.py'), str(runtime)], check=True)
model.mkdir(exist_ok=True)
code = '''
import json, pathlib, shutil, sys
from huggingface_hub import hf_hub_download
root, destination, repository, revision = sys.argv[1:]
voices = json.loads((pathlib.Path(root) / 'Speech/voices.json').read_text())
for name in ['config.json', 'kokoro-v1_0.pth'] + ['voices/' + voice['id'] + '.pt' for voice in voices]:
    source = hf_hub_download(repo_id=repository, filename=name, revision=revision)
    target = pathlib.Path(destination) / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
'''
subprocess.run([str(python), '-I', '-c', code, str(root), str(model), lock['model_repository'], lock['model_revision']], check=True)
stamp.write_text(fingerprint)
print(f'Portable runtime is ready: {directory}')
