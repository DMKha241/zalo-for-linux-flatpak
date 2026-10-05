"""Run with python3 scripts/test-release.py (requires PyYAML). No GitHub requests."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

import yaml

ROOT = Path(__file__).resolve().parents[1]
workflow = yaml.safe_load((ROOT / '.github/workflows/build.yml').read_text())
script = workflow['jobs']['release']['steps'][-1]['run']
MOCK_GH = '''#!/usr/bin/env python3
import hashlib, json, os, pathlib, sys
p = pathlib.Path(os.environ['RELEASE_TEST_STATE'])
s = json.loads(p.read_text())
a = sys.argv[1:]
s['calls'].append(a)
if a[:2] == ['release', 'view']:
    if not s['exists']: sys.exit(1)
elif a[:2] == ['release', 'create']:
    s['exists'] = True
elif a[0] == 'api':
    print(json.dumps({'assets': s['assets']}))
elif a[:2] == ['release', 'download']:
    name = a[a.index('--pattern') + 1]
    directory = pathlib.Path(a[a.index('--dir') + 1])
    asset = next(x for x in s['assets'] if x['name'] == name)
    (directory / name).write_text(asset['content'])
elif a[:2] == ['release', 'delete-asset']:
    s['assets'] = [x for x in s['assets'] if x['name'] != a[3]]
elif a[:2] == ['release', 'upload']:
    f = pathlib.Path(a[3])
    s['assets'].append({'name': f.name, 'digest': 'sha256:' + hashlib.sha256(f.read_bytes()).hexdigest()})
else:
    raise AssertionError(a)
p.write_text(json.dumps(s))
'''


def check(exists=True, fallback=False):
    with tempfile.TemporaryDirectory(prefix='zalo-release-test-') as directory:
        p = Path(directory)
        (p / 'dist').mkdir()
        (p / 'gh').write_text(MOCK_GH)
        (p / 'gh').chmod(0o755)
        names = [f'Zalo-26.10.10-dcf2e3e-{arch}.flatpak' for arch in ['x64', 'aarch64']]
        for name in names:
            (p / 'dist' / name).write_text('new bundle')
        digest = 'sha256:' + hashlib.sha256(b'new bundle').hexdigest()
        old = 'Zalo-26.10.10-aaaaaaa-x64.flatpak'
        assets = [
            {'name': names[0], 'digest': 'sha256:wrong'},
            {'name': names[1], 'digest': None if fallback else digest, 'content': 'new bundle'},
            {'name': old, 'digest': digest},
            {'name': 'notes.txt', 'digest': None},
        ] if exists else []
        state = p / 'state.json'
        state.write_text(json.dumps({'exists': exists, 'assets': assets, 'calls': []}))
        env = dict(os.environ, PATH=f'{p}:{os.environ["PATH"]}', RELEASE_TEST_STATE=str(state),
                   GH_REPO='test/zalo', ZALO_VERSION='26.10.10', GITHUB_SHA='packaging-commit')
        subprocess.run(['bash', '-euo', 'pipefail', '-c', script], cwd=p, env=env, check=True)
        result = json.loads(state.read_text())
        calls = result['calls']
        uploads = [Path(a[3]).name for a in calls if a[:2] == ['release', 'upload']]
        deletes = [a[3] for a in calls if a[:2] == ['release', 'delete-asset']]
        assert set(uploads) == set([names[0]] if exists else names), uploads
        assert deletes == ([names[0], old] if exists else []), deletes
        assert {x['name'] for x in result['assets']} == set(names + (['notes.txt'] if exists else []))
        assert any(a[:2] == ['release', 'create'] for a in calls) == (not exists)
        assert any(a[:2] == ['release', 'download'] for a in calls) == fallback


check()
check(fallback=True)
check(exists=False)
print('PASS: replace changed SHA, remove old commit, preserve matching SHA and other assets, create release, digest fallback')
