"""Collect licence notices from the exact installed Python runtime, without imports."""
import importlib.metadata
from pathlib import Path
import sys

with Path(sys.argv[1]).open('a', encoding='utf-8') as output:
    output.write('\n\n' + sys.argv[2] + '\n' + '=' * 72 + '\n')
    for dist in sorted(importlib.metadata.distributions(), key=lambda d: d.metadata['Name'].lower()):
        output.write(f'\n{dist.metadata["Name"]} {dist.version}\n')
        files = [f for f in dist.files or [] if '.dist-info/' in str(f)
                 and f.name.lower().startswith(('license', 'licence', 'copying', 'notice'))]
        if files:
            for file in files:
                output.write(str(file) + '\n' + dist.locate_file(file).read_text(errors='replace') + '\n')
        else:
            output.write(dist.metadata.get('License-Expression') or dist.metadata.get('License') or 'Licence not supplied in package metadata.')
            output.write('\n')
