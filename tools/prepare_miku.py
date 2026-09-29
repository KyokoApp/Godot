"""Convert the supplied VRM to a self-contained mobile GLB, preserving mesh/rig.

No animation/plugin dependency is imported. Metadata remains in asset.extras;
only base-color textures are used by the lightweight runtime material preset.
Requires Pillow. Source upload is intentionally not deleted by this tool.
"""
import argparse
import copy
import hashlib
import io
import json
import struct
import subprocess
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
parser.add_argument('--skin', choices=['miku', 'kanna'], default='miku')
args = parser.parse_args()
OUT = ROOT / 'project/assets/characters' / args.skin
source = args.source.read_bytes()
assert source[:4] == b'glTF'
json_size = struct.unpack_from('<I', source, 12)[0]
data = json.loads(source[20:20 + json_size])
binary_start = 20 + json_size
binary_size, binary_type = struct.unpack_from('<II', source, binary_start)
assert binary_type == 0x004E4942
binary = source[binary_start + 8:binary_start + 8 + binary_size]
vrm = data['extensions']['VRM']
OUT.mkdir(parents=True, exist_ok=True)

def image_bytes(index):
    view = data['bufferViews'][data['images'][index]['bufferView']]
    return binary[view.get('byteOffset', 0):view.get('byteOffset', 0) + view['byteLength']]

# Kanna archive thumbnail index points to a BODY ATLAS; never display it as a face.
if args.skin == "miku":
    # The portrait is the author's embedded model thumbnail, not unrelated fan art.
    portrait_index = data['textures'][vrm['meta']['texture']]['source']
    portrait = Image.open(io.BytesIO(image_bytes(portrait_index))).convert('RGBA')
    portrait = ImageOps.fit(portrait, (192, 192), method=Image.Resampling.LANCZOS)
    mask = Image.new('L', (192, 192))
    ImageDraw.Draw(mask).ellipse((0, 0, 191, 191), fill=255)
    portrait.putalpha(mask)
    portrait.save(OUT / 'portrait.png')

result = copy.deepcopy(data)
result.pop('extensions', None)
result['extensionsUsed'] = ['KHR_texture_transform']
result.pop('extensionsRequired', None)
result['asset']['extras'] = {
    'source_sha256': hashlib.sha256(source).hexdigest(),
    'original_vrm_meta': vrm['meta'],
    'permissions': 'See licenses/' + ('Miku-Naxzed-Permission.txt' if args.skin == 'miku'
                                    else 'Kanna-Permission.txt') + '; not a free asset license.',
    'changes': 'Base color maps <=1024px; lit materials; no VRM spring-bone simulation.',
}
textures = []
images = []
image_payloads = []
texture_map = {}
for material in result['materials']:
    material.pop('extensions', None)
    material.pop('normalTexture', None)
    material.pop('occlusionTexture', None)
    material.pop('emissiveTexture', None)
    material['emissiveFactor'] = [0, 0, 0]
    pbr = material['pbrMetallicRoughness']
    pbr.pop('metallicRoughnessTexture', None)
    pbr['metallicFactor'] = 0
    pbr['roughnessFactor'] = 1
    tex = pbr.get('baseColorTexture')
    if not tex:
        continue
    old = tex['index']
    if old not in texture_map:
        texture_map[old] = len(textures)
        texture = copy.deepcopy(data['textures'][old])
        image = Image.open(io.BytesIO(image_bytes(texture['source']))).convert('RGBA')
        image.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
        png = io.BytesIO()
        image.save(png, format='PNG', optimize=True)
        image_payloads.append(png.getvalue())
        texture['source'] = len(images)
        textures.append(texture)
        images.append({'mimeType': 'image/png'})
    tex['index'] = texture_map[old]
result['textures'] = textures
result['images'] = images

# Compact the buffer, excluding old texture blobs, without rewriting geometry.
used_views = set()
for accessor in result['accessors']:
    if 'bufferView' in accessor:
        used_views.add(accessor['bufferView'])
    if 'sparse' in accessor:
        for name in ['indices', 'values']:
            used_views.add(accessor['sparse'][name]['bufferView'])
new_binary = bytearray()
new_views = []
view_map = {}

def append_view(payload, original=None):
    new_binary.extend(b'\0' * (-len(new_binary) % 4))
    view = copy.deepcopy(original) if original else {}
    view.update(buffer=0, byteOffset=len(new_binary), byteLength=len(payload))
    new_views.append(view)
    new_binary.extend(payload)
    return len(new_views) - 1

for old in sorted(used_views):
    view = data['bufferViews'][old]
    offset = view.get('byteOffset', 0)
    view_map[old] = append_view(binary[offset:offset + view['byteLength']], view)
for accessor in result['accessors']:
    if 'bufferView' in accessor:
        accessor['bufferView'] = view_map[accessor['bufferView']]
    if 'sparse' in accessor:
        for name in ['indices', 'values']:
            part = accessor['sparse'][name]
            part['bufferView'] = view_map[part['bufferView']]
for image, payload in zip(images, image_payloads):
    image['bufferView'] = append_view(payload)
result['bufferViews'] = new_views
result['buffers'] = [{'byteLength': len(new_binary)}]
encoded = json.dumps(result, separators=(',', ':')).encode()
encoded += b' ' * (-len(encoded) % 4)
new_binary.extend(b'\0' * (-len(new_binary) % 4))
output = struct.pack('<4sII', b'glTF', 2, 28 + len(encoded) + len(new_binary))
output += struct.pack('<II', len(encoded), 0x4E4F534A) + encoded
output += struct.pack('<II', len(new_binary), 0x004E4942) + new_binary
(OUT / (args.skin + '.glb')).write_bytes(output)

human = {h['bone']: data['nodes'][h['node']]['name']
         for h in vrm['humanoid']['humanBones']}
pairs = [('pelvis', 'hips'), ('spine_01', 'spine'), ('spine_02', 'chest'),
         ('spine_03', 'upperChest'), ('neck_01', 'neck'), ('Head', 'head')]
for short, long in [('l', 'left'), ('r', 'right')]:
    for src, dst in [('clavicle', 'Shoulder'), ('upperarm', 'UpperArm'),
                     ('lowerarm', 'LowerArm'), ('hand', 'Hand'),
                     ('thigh', 'UpperLeg'), ('calf', 'LowerLeg'),
                     ('foot', 'Foot'), ('ball', 'Toes')]:
        pairs.append((src + '_' + short, long + dst))
    for src, dst in [('thumb', 'Thumb'), ('index', 'Index'), ('middle', 'Middle'),
                     ('ring', 'Ring'), ('pinky', 'Little')]:
        for number, joint in enumerate(['Proximal', 'Intermediate', 'Distal'], 1):
            pairs.append((f'{src}_{number:02}_{short}', long + dst + joint))
if args.skin == 'kanna':
    # The archive's tested Kanna mapping includes this Rigify helper.
    assert any(n['name'] == 'DEF-Upper Chest' for n in data['nodes'])
    human['upperChest'] = 'DEF-Upper Chest'
    pairs = [(src, dst) for src, dst in pairs if dst in human]
assert all(dst in human for _, dst in pairs)
rig = 'extends RefCounted\n## Generated from supplied VRM humanoid metadata.\n\nconst PAIRS := [\n'
rig += ''.join(f'\t["{src}", "{human[dst]}"],\n' for src, dst in pairs) + ']\n'
(ROOT / 'project/src/game/animation' / (args.skin + '_rig.gd')).write_text(rig)
if args.skin == 'kanna':
    subprocess.run([sys.executable, str(ROOT/'tools/render_character_portrait.py'),
                    str(OUT/'kanna.glb'), str(OUT/'portrait.png')], check=True)
print(f'{args.skin}: {len(source):,} -> {len(output):,} bytes, {len(images)} maps, {len(pairs)} bones')
