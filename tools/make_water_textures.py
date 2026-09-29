"""Original periodic height/normal maps; no third-party demo images. Requires Pillow."""
from pathlib import Path
from math import sin, cos, tau, sqrt
from PIL import Image

SIZE = 128
out = Path(__file__).resolve().parents[1] / 'project/assets/water'
out.mkdir(parents=True, exist_ok=True)
height = []
for y in range(SIZE):
    row = []
    for x in range(SIZE):
        h = .5 + .18*sin(tau*(3*x+2*y)/SIZE) + .12*cos(tau*(5*x-4*y)/SIZE)
        h += .06*sin(tau*11*x/SIZE + sin(tau*3*y/SIZE))
        row.append(h)
    height.append(row)
image = Image.new('RGB', (SIZE, SIZE))
normal = Image.new('RGB', (SIZE, SIZE))
for y in range(SIZE):
    for x in range(SIZE):
        value = round(height[y][x]*255)
        image.putpixel((x,y),(value,value,value))
        dx = (height[y][(x+1)%SIZE]-height[y][(x-1)%SIZE])*2
        dy = (height[(y+1)%SIZE][x]-height[(y-1)%SIZE][x])*2
        length = sqrt(dx*dx+dy*dy+1)
        normal.putpixel((x,y), tuple(round((n/length*.5+.5)*255) for n in (-dx,-dy,1)))
image.save(out/'wave_height.png')
normal.save(out/'wave_normal.png')
