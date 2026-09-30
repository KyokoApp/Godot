"""Fetch selected user archive assets; gh auth required. Resize textures with Pillow."""
import subprocess,base64,json,pathlib,concurrent.futures
REV='bca3e575fc26311ef5a43c0263e772a6d9fced20'
ROOT='project/packs/build_mode/objects/nature/'
OUT=pathlib.Path(__file__).resolve().parents[1]/'project/assets/nature'
OUT.mkdir(parents=True,exist_ok=True)
names=['CommonTree_1','CommonTree_3','Pine_1','Bush_Common','Bush_Common_Flowers','Fern_1','Flower_3_Group','Rock_Medium_1','Rock_Medium_2','Pebble_Round_1','RockPath_Round_Wide']
def fetch(name):
 p=OUT/name
 if not p.exists():
  d=subprocess.check_output(['gh','api',f'repos/KyokoApp/Unity/contents/{ROOT}{name}?ref={REV}','--jq','.content'])
  if not d.strip():
   sha=subprocess.check_output(['gh','api',f'repos/KyokoApp/Unity/contents/{ROOT}{name}?ref={REV}','--jq','.sha']).decode().strip()
   d=subprocess.check_output(['gh','api',f'repos/KyokoApp/Unity/git/blobs/{sha}','--jq','.content'])
  p.write_bytes(base64.b64decode(d))
 return p
with concurrent.futures.ThreadPoolExecutor(max_workers=5) as ex:
 list(ex.map(fetch,[n+'.gltf' for n in names]))
deps=set()
for n in names:
 d=json.loads((OUT/(n+'.gltf')).read_text())
 for k in ['buffers','images']:
  deps.update(x['uri'] for x in d.get(k,[]))
 print(n, 'triangles',sum(d['accessors'][p['indices']]['count']//3 for m in d['meshes'] for p in m['primitives']))
with concurrent.futures.ThreadPoolExecutor(max_workers=5) as ex:
 list(ex.map(fetch,sorted(deps)))

from PIL import Image
for name in sorted(deps):
 if name.endswith('.png'):
  path=OUT/name
  image=Image.open(path)
  image.thumbnail((512,512),Image.Resampling.LANCZOS)
  image.save(path,optimize=True)
