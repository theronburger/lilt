#!/usr/bin/env python3
"""Sign nested native code before sealing the app bundle."""
import pathlib
import subprocess
import sys

bundle = pathlib.Path(sys.argv[1]).resolve()
identity = sys.argv[2]
root = pathlib.Path(__file__).resolve().parents[1]
magic = {b'\xfe\xed\xfa\xce', b'\xce\xfa\xed\xfe', b'\xfe\xed\xfa\xcf', b'\xcf\xfa\xed\xfe', b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca'}

def sign(path, entitlements=None, preserve=False):
    command = ['codesign', '--force', '--options', 'runtime', '--timestamp', '--sign', identity]
    if entitlements:
        command += ['--entitlements', str(entitlements)]
    elif preserve:
        command += ['--preserve-metadata=identifier,entitlements,flags']
    subprocess.run(command + [str(path)], check=True, stdout=subprocess.DEVNULL)

paths = sorted(bundle.rglob('*'), key=lambda p: len(p.parts), reverse=True)
for path in paths:
    if path.is_symlink() or not path.is_file():
        continue
    with path.open('rb') as file:
        native = file.read(4) in magic
    if native:
        is_python = '/Python/bin/python' in str(path)
        sign(path, root / 'Resources/Python.entitlements' if is_python else None,
             preserve='/Frameworks/Sparkle.framework/' in str(path))
for path in paths:
    if path.is_dir() and not path.is_symlink() and path.suffix in {'.app', '.xpc', '.framework'}:
        sign(path, preserve=True)
sign(bundle, root / 'Resources/Lilt.entitlements')
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(bundle)], check=True)
