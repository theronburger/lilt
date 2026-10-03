#!/usr/bin/env python3
"""Package exact corresponding sources beside each binary release."""
import hashlib
import json
import pathlib
import re
import tarfile
import urllib.request

root = pathlib.Path(__file__).resolve().parents[1]
version = (root / 'VERSION').read_text().strip()
if not re.fullmatch(r'\d+\.\d+\.\d+', version):
    raise SystemExit('Invalid release version')
items = json.loads((root / 'Resources/source-lock.json').read_text())
requirements = (root / 'Speech/requirements.lock').read_text()
cache = root / 'work/source-downloads'
cache.mkdir(parents=True, exist_ok=True)
for item in items:
    if pathlib.Path(item['file']).name != item['file'] or not item['url'].startswith('https://'):
        raise SystemExit('Invalid source archive location')
    if item['name'] != 'espeak-ng' and f"{item['name']}=={item['version']}" not in requirements.splitlines():
        raise SystemExit(f"Update source-lock.json for {item['name']}")
    path = cache / item['file']
    if not path.exists():
        urllib.request.urlretrieve(item['url'], path)
    if hashlib.sha256(path.read_bytes()).hexdigest() != item['sha256']:
        raise SystemExit(f"Source checksum mismatch: {item['name']}")

name = f'lilt_{version}_corresponding-source'
output = root / 'dist' / f'{name}.tar.gz'
output.parent.mkdir(exist_ok=True)

def clean_metadata(member):
    member.uid = member.gid = 0
    member.uname = member.gname = ''
    return member

with tarfile.open(output, 'w:gz') as archive:
    for item in items:
        archive.add(cache / item['file'], arcname=f"{name}/upstream/{item['file']}", filter=clean_metadata)
    archive.add(root / 'Resources/source-lock.json', arcname=f'{name}/SOURCE_MANIFEST.json', filter=clean_metadata)
    source_files = [root / p for p in ['LICENSE', 'README.md', 'Package.swift', 'Package.resolved', 'VERSION', 'docs/LICENSING.md', 'docs/RELEASING.md', 'packaging/homebrew/lilt.rb.template']]
    for directory in ['Sources', 'Speech', 'Resources', 'scripts']:
        source_files.extend(p for p in (root / directory).rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix != '.pyc')
    for path in sorted(set(source_files)):
        archive.add(path, arcname=f'{name}/lilt/{path.relative_to(root)}', recursive=False, filter=clean_metadata)
print(f'Packaged corresponding source: {output.name} ({output.stat().st_size:,} bytes)')
