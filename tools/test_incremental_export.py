#!/usr/bin/env python3
"""Gate the real exported seed, APK layout, block reconstruction and script-only delta."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import zipfile
from chunk_content import build, entries

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / 'build/content-v2.json').read_text())
pack = (root / 'build/content.pck').read_bytes()
joined = b''.join((root / 'build/chunks' / (c['sha256'] + '.bin')).read_bytes()
                  for c in manifest['chunks'])
assert joined == pack
payload = {path if path.startswith('res://') else 'res://' + path for path in entries(pack)}
# Script export mode 2 stores scenes as optimized .scn files and leaves a .remap
# alias at the original path, rather than storing the editable .tscn itself.
main_scene_paths = {'res://src/game/main.tscn', 'res://src/game/main.tscn.remap'}
assert main_scene_paths & payload, 'World-only scene missing from content PCK'
assert 'res://src/game/blue_flame.gdshader' in payload, 'Blue flame shader missing from content PCK'


def exported_path_variants(path):
    """Include Godot bytecode/remap aliases, not only source filenames."""
    variants = {path}
    if path.endswith('.gd'):
        variants.update({path + '.remap', path[:-3] + '.gdc'})
    elif path.endswith('.tscn'):
        variants.add(path + '.remap')
    else:
        variants.add(path + '.import')
    return variants


for removed in (
    'res://src/game/legacy_main.gd', 'res://src/game/legacy_main.tscn',
    'res://src/game/ui/rune_button.gd', 'res://src/game/player.gd',
    'res://src/game/mannequin.gd', 'res://src/game/world/run_zone.gd',
    'res://src/game/survival/buff_system.gd', 'res://assets/audio/fire_loop.wav',
    'res://assets/mannequin/UAL1_Standard.glb',
):
    leaked = exported_path_variants(removed) & payload
    assert not leaked, 'Legacy gameplay residue in content PCK: ' + ', '.join(sorted(leaked))
print('[incremental-export] blocks reassembled; world-only payload verified')
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
                           timeout=120, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        export()
        print('[incremental-export] repeat sha:', hashlib.sha256(test_pack.read_bytes()).hexdigest(), 'original:', manifest['sha256'])
        # Godot's small export metadata may change; imported asset bytes must not.
        from chunk_content import entries, split
        repeat = test_pack.read_bytes()
        before_files, after_files = entries(pack), entries(repeat)
        assert before_files.keys() == after_files.keys(), 'Repeat export changed file set'
        changed_paths = [p for p in before_files
                         if pack[slice(*before_files[p])] != repeat[slice(*after_files[p])]]
        print('[incremental-export] changed on repeat:', changed_paths)
        allowed = {'res://.godot/uid_cache.bin', 'res://.godot/global_script_class_cache.cfg',
                   '.godot/uid_cache.bin', '.godot/global_script_class_cache.cfg'}
        assert set(changed_paths) <= allowed, 'Unexpected repeat changes: ' + str(changed_paths)
        known = {hashlib.sha256(b).hexdigest() for b in split(pack)}
        churn = sum(len(b) for b in split(repeat) if hashlib.sha256(b).hexdigest() not in known)
        assert churn <= 1024 * 1024, f'Export metadata churn too large: {churn}'
        print('[incremental-export] unchanged export metadata delta:', churn)
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
print('[incremental-export] HASIL: OK')
