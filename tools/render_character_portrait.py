"""Small offline orthographic portrait of the actual GLB bind-pose mesh/textures.
For archives with a broken VRM thumbnail index. Requires numpy + Pillow.
This is an asset thumbnail generator, NOT a substitute for engine render tests.
"""
import argparse
import io
import json
import struct
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('model', type=Path)
parser.add_argument('output', type=Path)
parser.add_argument('--head', default='DEF-Head')
args = parser.parse_args()
raw = args.model.read_bytes()
length = struct.unpack_from('<I', raw, 12)[0]
data = json.loads(raw[20:20+length])
blob = raw[28+length:]
DTYPES = {5121: '<u1', 5123: '<u2', 5125: '<u4', 5126: '<f4'}
COUNTS = {'SCALAR':1, 'VEC2':2, 'VEC3':3, 'VEC4':4, 'MAT4':16}

def values(index):
    a = data['accessors'][index]
    v = data['bufferViews'][a['bufferView']]
    dtype = np.dtype(DTYPES[a['componentType']])
    width = COUNTS[a['type']]
    array = np.ndarray((a['count'], width), dtype=dtype, buffer=blob,
        offset=v.get('byteOffset',0)+a.get('byteOffset',0),
        strides=(v.get('byteStride',width*dtype.itemsize),dtype.itemsize)).copy()
    if a.get('normalized'):
        array = array.astype(float)/np.iinfo(dtype).max
    return array

parents = {c:i for i,n in enumerate(data['nodes']) for c in n.get('children',[])}
world = {}
def transform(i):
    if i in world:
        return world[i]
    n = data['nodes'][i]
    x,y,z,w = n.get('rotation',[0,0,0,1])
    matrix = np.eye(4)
    matrix[:3,:3] = np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
        [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
        [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]]) @ np.diag(n.get('scale',[1,1,1]))
    matrix[:3,3] = n.get('translation',[0,0,0])
    if 'matrix' in n:
        matrix = np.array(n['matrix']).reshape(4,4).T
    world[i] = transform(parents[i]) @ matrix if i in parents else matrix
    return world[i]

head = next(i for i,n in enumerate(data['nodes']) if n['name']==args.head)
center = transform(head)[:3,3] + np.array([0,.03,0])
SIZE = 384
SPAN = .42
rgba = np.zeros((SIZE,SIZE,4),dtype=float)
rgba[:,:,:3] = [.14,.16,.21]
rgba[:,:,3] = 1
z_buffer = np.full((SIZE,SIZE),np.inf)
textures = {}
for i,t in enumerate(data['textures']):
    v = data['bufferViews'][data['images'][t['source']]['bufferView']]
    start = v.get('byteOffset',0)
    image = Image.open(io.BytesIO(blob[start:start+v['byteLength']])).convert('RGBA')
    textures[i] = np.asarray(image,dtype=float)/255
triangles = []
for node_index,node in enumerate(data['nodes']):
    if 'mesh' not in node:
        continue
    skin_matrices = None
    if 'skin' in node:
        skin = data['skins'][node['skin']]
        binds = values(skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
        skin_matrices = np.array([transform(j) @ b for j,b in zip(skin['joints'],binds)])
    for primitive in data['meshes'][node['mesh']]['primitives']:
        attrs = primitive['attributes']
        p = values(attrs['POSITION'])
        p = np.column_stack([p,np.ones(len(p))])
        normals = values(attrs['NORMAL'])
        if skin_matrices is not None:
            joints = values(attrs['JOINTS_0']).astype(int)
            weights = values(attrs['WEIGHTS_0'])
            weights /= np.maximum(weights.sum(axis=1,keepdims=True),1e-9)
            blend = np.sum(skin_matrices[joints]*weights[:,:,None,None],axis=1)
            p = np.einsum('nij,nj->ni',blend,p)[:,:3]
            normals = np.einsum('nij,nj->ni',blend[:,:3,:3],normals)
        else:
            p = (transform(node_index) @ p.T).T[:,:3]
            normals = (transform(node_index)[:3,:3] @ normals.T).T
        screen = np.column_stack([(p[:,0]-center[0])/SPAN*SIZE+SIZE/2,
                                  (center[1]-p[:,1])/SPAN*SIZE+SIZE/2])
        uv = values(attrs['TEXCOORD_0'])
        material = data['materials'][primitive['material']]
        pbr = material['pbrMetallicRoughness']
        tex = textures[pbr['baseColorTexture']['index']]
        for ids in values(primitive['indices']).reshape(-1,3).astype(int):
            xy = screen[ids]
            if (xy[:,0].max()<0 or xy[:,0].min()>=SIZE or
                    xy[:,1].max()<0 or xy[:,1].min()>=SIZE):
                continue
            triangles.append((p[ids,2].mean(),xy,p[ids,2],uv[ids],normals[ids],tex,material))
# Far-to-near alpha compositing with a per-pixel opaque depth buffer.
for _,xy,z,uv,normals,tex,material in sorted(triangles,key=lambda t:-t[0]):
    x0,y0 = np.maximum(np.floor(xy.min(axis=0)).astype(int),0)
    x1,y1 = np.minimum(np.ceil(xy.max(axis=0)).astype(int),SIZE-1)
    if x1<x0 or y1<y0:
        continue
    x,y = np.meshgrid(np.arange(x0,x1+1)+.5,np.arange(y0,y1+1)+.5)
    a,b,c = xy
    d = (b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
    if abs(d)<1e-8:
        continue
    w0 = ((b[1]-c[1])*(x-c[0])+(c[0]-b[0])*(y-c[1]))/d
    w1 = ((c[1]-a[1])*(x-c[0])+(a[0]-c[0])*(y-c[1]))/d
    w = np.stack([w0,w1,1-w0-w1],axis=-1)
    depth = w @ z
    hit = (w.min(axis=-1)>=-1e-5)&(depth<=z_buffer[y0:y1+1,x0:x1+1]+1e-5)
    coords = w @ uv
    tx = np.clip((coords[:,:,0]*tex.shape[1]).astype(int),0,tex.shape[1]-1)
    ty = np.clip((coords[:,:,1]*tex.shape[0]).astype(int),0,tex.shape[0]-1)
    sample = tex[ty,tx].copy()*material['pbrMetallicRoughness'].get('baseColorFactor',[1,1,1,1])
    mode = material.get('alphaMode','OPAQUE')
    if mode=='MASK':
        hit &= sample[:,:,3]>=material.get('alphaCutoff',.5)
        sample[:,:,3] = 1
    elif mode=='OPAQUE':
        sample[:,:,3] = 1
    alpha = sample[:,:,3]*hit
    light = w @ normals
    light /= np.maximum(np.linalg.norm(light,axis=-1,keepdims=True),1e-9)
    shade = .78+.22*np.clip(light @ np.array([-.3,.4,-.866]),0,1)
    color = sample[:,:,:3]*shade[:,:,None]
    target = rgba[y0:y1+1,x0:x1+1]
    target[:,:,:3] = color*alpha[:,:,None]+target[:,:,:3]*(1-alpha[:,:,None])
    if mode!='BLEND':
        tile = z_buffer[y0:y1+1,x0:x1+1]
        tile[hit] = depth[hit]
image = Image.fromarray(np.uint8(np.clip(rgba,0,1)*255)).resize((192,192),Image.Resampling.LANCZOS)
mask = Image.new('L',(192,192))
ImageDraw.Draw(mask).ellipse((0,0,191,191),fill=255)
image.putalpha(mask)
image.save(args.output)
print('Rendered model portrait:',args.output)
