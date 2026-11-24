#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Whitelist public files. Never copy .build, local manifests, DICOMs or SDK binaries."""
from pathlib import Path
import hashlib
import plistlib
import zipfile

root = Path(__file__).resolve().parent.parent
bundle = root / '.build' / 'IsiXLeberQuant.isixplugin'
with (root / 'Info.plist').open('rb') as stream:
    version = plistlib.load(stream)['CFBundleShortVersionString']
with (bundle / 'Contents' / 'Info.plist').open('rb') as stream:
    assert plistlib.load(stream)['CFBundleShortVersionString'] == version, 'Rebuild before packaging'
output = root / 'dist'
output.mkdir(exist_ok=True)
files = ['README.md', 'LICENSE', 'ACKNOWLEDGEMENTS.md', 'REFERENCES.md',
         'THIRD_PARTY_NOTICES.md', 'CONTRIBUTING.md', 'SECURITY.md', 'CHANGELOG.md',
         'CITATION.cff', 'Info.plist', 'build.sh', 'test.sh', 'install.sh',
         'verify-sdk.rb', '.gitignore', '.gitattributes']
directories = ['Sources', 'Tests', 'Resources', 'LICENSES', 'Docs', 'scripts', '.github']
for directory in directories:
    files.extend(str(p.relative_to(root)) for p in (root / directory).rglob('*')
                 if p.is_file() and p.name != '.DS_Store' and not p.name.startswith('._')
                 and '__pycache__' not in p.parts)
checksums = []
for kind in ['source', 'arm64']:
    name = f'Liver-IronLoad-v{version}-{kind}.zip'
    archive = output / name
    prefix = f'Liver-IronLoad-v{version}'
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as stream:
        for file in sorted(files):
            stream.write(root / file, f'{prefix}/{file}')
        if kind == 'arm64':
            for file in sorted(bundle.rglob('*')):
                if file.is_file() and not file.name.startswith('._'):
                    stream.write(file, f'{prefix}/{bundle.name}/{file.relative_to(bundle)}')
    checksums.append(f'{hashlib.sha256(archive.read_bytes()).hexdigest()}  {name}')
    print(archive)
(output / 'SHA256SUMS.txt').write_text('\n'.join(checksums) + '\n')
