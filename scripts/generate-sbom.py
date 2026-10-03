#!/usr/bin/env python3
"""Inventory exact shipped Python packages, Swift pins, and model/runtime assets."""
import json
import pathlib
import subprocess
import sys
import uuid

root = pathlib.Path(__file__).resolve().parents[1]
code = "import importlib.metadata,json; print(json.dumps([{'name':d.metadata['Name'],'version':d.version} for d in importlib.metadata.distributions()]))"
packages = json.loads(subprocess.check_output([str(root / 'work/portable-runtime/python/bin/python3'), '-I', '-c', code], text=True))
components = [{'type': 'library', 'name': p['name'], 'version': p['version'], 'purl': f"pkg:pypi/{p['name'].lower().replace('_', '-')}@{p['version']}"} for p in packages]
for pin in json.loads((root / 'Package.resolved').read_text())['pins']:
    components.append({'type': 'library', 'name': pin['identity'], 'version': pin['state']['version'],
                       'externalReferences': [{'type': 'vcs', 'url': pin['location'] + '/tree/' + pin['state']['revision']}]})
lock = json.loads((root / 'Resources/runtime-lock.json').read_text())
components += [{'type': 'application', 'name': 'CPython', 'version': lock['python_version'], 'hashes': [{'alg': 'SHA-256', 'content': lock['python_sha256']}],
                'externalReferences': [{'type': 'distribution', 'url': lock['python_url']}]},
               {'type': 'data', 'name': lock['model_repository'], 'version': lock['model_revision'],
                'externalReferences': [{'type': 'distribution', 'url': 'https://huggingface.co/' + lock['model_repository'] + '/tree/' + lock['model_revision']}]}]
document = {'bomFormat': 'CycloneDX', 'specVersion': '1.6', 'serialNumber': 'urn:uuid:' + str(uuid.uuid4()), 'version': 1,
            'metadata': {'component': {'type': 'application', 'name': 'Lilt', 'version': (root / 'VERSION').read_text().strip()}},
            'components': sorted(components, key=lambda c: c['name'].lower())}
pathlib.Path(sys.argv[1]).write_text(json.dumps(document, indent=2) + '\n')
