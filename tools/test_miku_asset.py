"""Offline asset/mapping gate. Does NOT replace Godot import/render tests.
Run with Pillow + numpy; source upload is retained until engine gates pass.
"""
import hashlib
import io
import json
import struct
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]

def load(path):
    raw = path.read_bytes()
    magic, version, size = struct.unpack_from('<4sII', raw)
    assert magic == b'glTF' and version == 2 and size == len(raw)
    count, kind = struct.unpack_from('<II', raw, 12)
    assert kind == 0x4E4F534A
    data = json.loads(raw[20:20+count])
    length, kind = struct.unpack_from('<II', raw, 20+count)
    assert kind == 0x004E4942
    return data, raw[28+count:28+count+length], raw

source, old_bin, original = load(ROOT/'868295879255555982.vrm')
model, binary, packed = load(ROOT/'project/assets/characters/miku/miku.glb')
assert model['asset']['extras']['source_sha256'] == hashlib.sha256(original).hexdigest()
assert model['nodes'] == source['nodes']
assert model['skins'] == source['skins']
assert model['meshes'] == source['meshes']
assert len(packed) < 12 * 1024**2

def view(data, blob, idx):
    item = data['bufferViews'][idx]
    start = item.get('byteOffset', 0)
    assert start >= 0 and start+item['byteLength'] <= len(blob)
    return blob[start:start+item['byteLength']]

for before, after in zip(source['accessors'], model['accessors']):
    if 'bufferView' in before:
        assert view(source, old_bin, before['bufferView']) == view(model, binary, after['bufferView'])
    if 'sparse' in before:
        for name in ['indices', 'values']:
            assert view(source, old_bin, before['sparse'][name]['bufferView']) == view(
                model, binary, after['sparse'][name]['bufferView'])
for material in model['materials']:
    assert not material.get('extensions')
    pbr = material['pbrMetallicRoughness']
    assert pbr['metallicFactor'] == 0
    texture = model['textures'][pbr['baseColorTexture']['index']]
    image = model['images'][texture['source']]
    png = Image.open(io.BytesIO(view(model, binary, image['bufferView'])))
    assert max(png.size) <= 1024 and png.mode == 'RGBA'

# Rest-space compatibility: source/target left sides have opposite X signs.
ual, _, _ = load(ROOT/'project/assets/mannequin/UAL1_Standard.glb')
def globals_for(data):
    nodes = data['nodes']
    parents = {child: i for i, n in enumerate(nodes) for child in n.get('children', [])}
    cache = {}
    def matrix(index):
        if index in cache:
            return cache[index]
        node = nodes[index]
        x,y,z,w = node.get('rotation', [0,0,0,1])
        rotation = np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
                             [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
                             [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
        local = np.eye(4)
        local[:3,:3] = rotation @ np.diag(node.get('scale', [1,1,1]))
        local[:3,3] = node.get('translation', [0,0,0])
        cache[index] = matrix(parents[index]) @ local if index in parents else local
        return cache[index]
    return {n['name']: matrix(i) for i, n in enumerate(nodes)}
src, dst = globals_for(ual), globals_for(model)
assert src['upperarm_l'][0,3] > 0 and dst['J_Bip_L_UpperArm'][0,3] < 0
assert src['Head'][1,3] > 1.4 and dst['J_Bip_C_Head'][1,3] > 1.2
rig_text = (ROOT/'project/src/game/animation/miku_rig.gd').read_text()
import re
pairs = re.findall(r'\["([^"]+)", "([^"]+)"\]', rig_text)
assert len(pairs) == 52
assert len({b for _, b in pairs}) == 52
for a, b in pairs:
    assert a in src and b in dst
    # At rest, (Q * src_pose * src_rest^-1 * Q^-1) * dst_rest == dst_rest.
    yaw = np.diag([-1,1,-1])
    result = yaw @ src[a][:3,:3] @ np.linalg.inv(src[a][:3,:3]) @ yaw @ dst[b][:3,:3]
    assert np.allclose(result, dst[b][:3,:3], atol=1e-5)
assert (ROOT/'project/licenses/Miku-Naxzed-Permission.txt').exists()
print('Miku asset OK: geometry/skin byte-identical; 52 bones; 24 maps <=1024; rest-space correction OK')

# Exercise the same rest-delta mapping with actual sampled UAL animation data.
ual, ual_bin, _ = load(ROOT/'project/assets/mannequin/UAL1_Standard.glb')
def accessor(data, blob, index):
    item = data['accessors'][index]
    assert item['componentType'] == 5126 and 'sparse' not in item
    count = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}[item['type']]
    raw = view(data, blob, item['bufferView'])
    return np.frombuffer(raw, '<f4', item['count']*count,
                         offset=item.get('byteOffset', 0)).reshape((-1, count))

def sampled(clip, time):
    result = json.loads(json.dumps(ual))
    animation = next(a for a in ual['animations'] if a['name'] == clip)
    for channel in animation['channels']:
        sampler = animation['samplers'][channel['sampler']]
        times = accessor(ual, ual_bin, sampler['input']).ravel()
        values = accessor(ual, ual_bin, sampler['output'])
        left = max(0, min(len(times)-2, np.searchsorted(times, time, side='right')-1))
        amount = np.clip((time-times[left])/max(times[left+1]-times[left], 1e-6), 0, 1)
        a, b = values[left].copy(), values[left+1].copy()
        path = channel['target']['path']
        if path == 'rotation' and np.dot(a,b) < 0:
            b = -b
        value = a * (1-amount) + b * amount
        if path == 'rotation':
            value /= np.linalg.norm(value)
        result['nodes'][channel['target']['node']][path] = value.tolist()
    return result

parents = {c:i for i,n in enumerate(model['nodes']) for c in n.get('children', [])}
indices = {n['name']:i for i,n in enumerate(model['nodes'])}
yaw = np.diag([-1,1,-1])
ratio = dst['J_Bip_C_Hips'][1,3]/src['pelvis'][1,3]
def transferred(animated):
    pose = globals_for(animated)
    desired = {b: yaw @ pose[a][:3,:3] @ np.linalg.inv(src[a][:3,:3]) @ yaw @ dst[b][:3,:3]
               for a,b in pairs}
    cache = {}
    def matrix(index):
        if index in cache:
            return cache[index]
        node = model['nodes'][index]
        parent = matrix(parents[index]) if index in parents else np.eye(4)
        local = np.eye(4)
        local[:3,3] = node.get('translation', [0,0,0])
        if node['name'] == 'J_Bip_C_Hips':
            target = dst[node['name']][:3,3] + yaw @ (pose['pelvis'][:3,3]-src['pelvis'][:3,3])*ratio
            local[:3,3] = np.linalg.inv(parent[:3,:3]) @ (target-parent[:3,3])
        # VRM supplied bones have identity local rotations/scales.
        assert node.get('rotation', [0,0,0,1]) == [0,0,0,1]
        assert node.get('scale', [1,1,1]) == [1,1,1]
        if node['name'] in desired:
            local[:3,:3] = np.linalg.inv(parent[:3,:3]) @ desired[node['name']]
        cache[index] = parent @ local
        return cache[index]
    return {name:matrix(index) for name,index in indices.items()}
for clip in ['Idle_Loop', 'Walk_Loop', 'Jog_Fwd_Loop']:
    a, b = transferred(sampled(clip,.1)), transferred(sampled(clip,.35))
    assert sum(not np.allclose(a[n],b[n],atol=1e-5) for n in a) > 15
    for t in [.1,.2,.35]:
        pose = transferred(sampled(clip,t))
        assert pose['J_Bip_C_Head'][1,3] > 1.0, (clip, 'head not upright')
        source_pose = globals_for(sampled(clip,t))
        normalized_source = source_pose['Head'][1,3]/src['Head'][1,3]
        normalized_target = pose['J_Bip_C_Head'][1,3]/dst['J_Bip_C_Head'][1,3]
        assert abs(normalized_source-normalized_target) < .08, (clip, 'head height distorted')
        for foot in ['J_Bip_L_Foot','J_Bip_R_Foot']:
            assert -.12 < pose[foot][1,3] < .65, (clip, 'foot out of range')

base = sampled('Jog_Fwd_Loop', .2)
cast = sampled('Spell_Simple_Shoot', .2)
cast_base = json.loads(json.dumps(base))
ual_parents = {c:i for i,n in enumerate(ual['nodes']) for c in n.get('children', [])}
spine = next(i for i,n in enumerate(ual['nodes']) if n['name']=='spine_01')
for index in range(len(ual['nodes'])):
    ancestor = index
    while ancestor >= 0 and ancestor != spine:
        ancestor = ual_parents.get(ancestor,-1)
    if ancestor == spine:
        cast_base['nodes'][index]['rotation'] = cast['nodes'][index]['rotation']
a,b = transferred(base), transferred(cast_base)
for bone in ['J_Bip_C_Hips','J_Bip_L_Foot','J_Bip_R_Foot','J_Bip_L_UpperLeg']:
    assert np.allclose(a[bone],b[bone],atol=1e-5), ('cast moved leg',bone)
assert np.linalg.norm(a['J_Bip_R_Hand']-b['J_Bip_R_Hand']) > .1
print('Miku motion math OK: idle/walk/jog upright; casting changes hand, not hips/legs')
