#!/usr/bin/env python3
"""Reject unstable signatures and accidental identity changes before installation."""
import os
import pathlib
import subprocess
import sys


def run(*args):
    return subprocess.run(args, capture_output=True, text=True)


def requirement(bundle):
    result = run('codesign', '-d', '-r-', str(bundle))
    if result.returncode:
        raise ValueError(f'Cannot read signing requirement: {bundle}')
    for line in (result.stdout + result.stderr).splitlines():
        if 'designated =>' in line:
            return line.split('designated =>', 1)[1].strip()
    raise ValueError(f'No signing requirement: {bundle}')


def stable(bundle):
    result = run('codesign', '-dv', str(bundle))
    if result.returncode or 'Signature=adhoc' in result.stderr:
        return False
    return 'cdhash ' not in requirement(bundle)


def check(candidate, installed):
    if not stable(candidate):
        raise ValueError('Refusing an unstable app signature; use a persistent code-signing certificate.')
    if not installed.exists() or not stable(installed):
        print('Certificate-signed app ready. Migrating from ad-hoc signing requires one new Screen Recording grant.')
        return
    result = run('codesign', '--verify', '--strict', '-R=' + requirement(installed), str(candidate))
    if result.returncode:
        if os.environ.get('ALLOW_SIGNING_IDENTITY_CHANGE') != '1':
            raise ValueError('Signing identity changed. Installation stopped to preserve permissions. '
                             'For an intentional certificate migration only, set ALLOW_SIGNING_IDENTITY_CHANGE=1.')
        print('Explicit signing-identity migration: macOS may require a new permission grant.')
    else:
        print('Verified: update satisfies the installed app’s signing requirement.')


if __name__ == '__main__':
    try:
        check(pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]))
    except ValueError as error:
        sys.exit(str(error))
