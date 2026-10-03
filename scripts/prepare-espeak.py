#!/usr/bin/env python3
"""Build pinned eSpeak with paths large enough for macOS app translocation."""
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys
import tarfile
import urllib.request

root = pathlib.Path(__file__).resolve().parents[1]
runtime = pathlib.Path(sys.argv[1]).resolve()
source = next(item for item in json.loads((root / 'Resources/source-lock.json').read_text()) if item['name'] == 'espeak-ng')
archive = root / 'work/source-downloads' / source['file']
archive.parent.mkdir(parents=True, exist_ok=True)
if not archive.exists():
    urllib.request.urlretrieve(source['url'], archive)
if hashlib.sha256(archive.read_bytes()).hexdigest() != source['sha256']:
    raise SystemExit('eSpeak source checksum does not match source-lock.json.')
directory = root / 'work/espeak-build'
shutil.rmtree(directory, ignore_errors=True)
directory.mkdir()
with tarfile.open(archive) as package:
    package.extractall(directory, filter='data')
checkout = next(path for path in directory.iterdir() if path.is_dir())
build = directory / 'build'
cmake = ['uvx', '--from', 'cmake==4.4.3', 'cmake']
subprocess.run(cmake + ['-S', str(checkout), '-B', str(build), '-DBUILD_SHARED_LIBS=ON',
    '-DUSE_LIBPCAUDIO=OFF', '-DUSE_LIBSONIC=OFF', '-DUSE_ASYNC=OFF', '-DCOMPILE_INTONATIONS=OFF',
    '-DCMAKE_BUILD_TYPE=Release', '-DCMAKE_OSX_DEPLOYMENT_TARGET=15.0',
    '-DCMAKE_C_FLAGS=-DN_PATH_HOME=4096', '-DCMAKE_POLICY_VERSION_MINIMUM=3.5'], check=True)
subprocess.run(cmake + ['--build', str(build), '--target', 'espeak-ng', '--parallel', '4'], check=True)
library = next(path for path in build.rglob('libespeak-ng*.dylib') if not path.is_symlink())
target = runtime / 'lib/python3.12/site-packages/espeakng_loader/libespeak-ng.dylib'
shutil.copyfile(library, target)
subprocess.run(['install_name_tool', '-id', '@rpath/libespeak-ng.dylib', str(target)], check=True)
subprocess.run(['codesign', '--force', '--sign', '-', str(target)], check=True)
print('Built eSpeak with N_PATH_HOME=4096 (upstream defaults to 160 on macOS).')
