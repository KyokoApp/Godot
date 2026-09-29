#!/usr/bin/env python3
"""Gate the real exported seed, APK layout, block reconstruction and script-only delta."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import zipfile
from chunk_content import build

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / 'build/content-v2.json').read_text())
pack = (root / 'build/content.pck').read_bytes()
joined = b''.join((root / 'build/chunks' / (c['sha256'] + '.bin')).read_bytes()
                  for c in manifest['chunks'])
assert joined == pack
print('[incremental-export] blocks reassembled')
with zipfile.ZipFile(root / 'build/asekai.apk') as apk:
    seed = apk.getinfo('assets/bootstrap/base.pck')
    assert seed.compress_type == zipfile.ZIP_STORED, 'Seed must support efficient Android seeks'
    print('[incremental-export] APK seed ZIP method:', seed.compress_type)
    assert apk.read(seed) == pack, 'APK seed differs from published content'
    assert json.loads(apk.read('assets/bootstrap/base.json')) == manifest
    assert not any(n.startswith('assets/src/game/') for n in apk.namelist()), 'Duplicate gameplay: ' + str([n for n in apk.namelist() if n.startswith('assets/src/game/')][:10])
    assert not any(n.startswith('assets/assets/') for n in apk.namelist()), 'Duplicate large assets: ' + str([n for n in apk.namelist() if n.startswith('assets/assets/')][:10])
    apk.extractall(root / 'build/apk-test')

# Export same commit again and then a tiny gameplay change. Never publish these test builds.
script = root / 'project/src/game/main.gd'
original = script.read_text()
try:
    with tempfile.TemporaryDirectory(dir=root / 'build') as tmp:
        test_pack = Path(tmp) / 'probe.pck'
        def export():
            subprocess.run([str(root / 'godot'), '--headless', '--path', str(root / 'project'),
                            '--export-pack', 'Content', str(test_pack)], check=True,
                           timeout=120)
        export()
        print('[incremental-export] repeat sha:', hashlib.sha256(test_pack.read_bytes()).hexdigest(), 'original:', manifest['sha256'])
        assert test_pack.read_bytes() == pack, 'Repeat export is not deterministic'
        script.write_text(original.replace('const MOVE_SPEED := 5.0', 'const MOVE_SPEED := 5.01'))
        export()
        changed = build(test_pack, root / 'build/probe-chunks', 'abcdef1')
        (root / 'build/probe.json').write_text(json.dumps(changed))
        old = {c['sha256'] for c in manifest['chunks']}
        delta = sum(c['bytes'] for c in changed['chunks'] if c['sha256'] not in old)
        assert 0 < delta < 4 * 1024 * 1024, f'Script-only delta unexpectedly large: {delta}'
        print(f'[incremental-export] script-only delta: {delta} / {len(pack)} bytes')
finally:
    script.write_text(original)
subprocess.run([str(root / 'godot'), '--headless', '--path', str(root / 'build/apk-test/assets'),
                '--script', str(root / 'tools/test_launcher.gd')], check=True, timeout=120)
subprocess.run([str(root / 'godot'), '--headless', '--path', str(root / 'build/apk-test/assets'),
                '--script', str(root / 'tools/test_incremental_launcher.gd'), '--',
                str(root / 'build/probe.json'), str(root / 'build/probe-chunks')],
               check=True, timeout=120)
print('[incremental-export] HASIL: OK')
