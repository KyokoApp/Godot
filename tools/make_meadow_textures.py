"""Original procedural textures, deterministic. Requires Pillow only."""
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

out = Path(__file__).resolve().parents[1] / "project/assets/nature"
rng = random.Random(8624)
card = Image.new("L", (256, 128))
draw = ImageDraw.Draw(card)
for i in range(35):
    x = (i + 0.5) * 256 / 35
    height = rng.randrange(40, 118)
    width = rng.randrange(3, 7)
    lean = rng.randrange(-8, 9)
    draw.polygon([(x-width, 127), (x+width, 127), (x+lean, 127-height)], fill=255)
card.save(out / "grass_cards.png")
# Seamless repeated short-blade pattern used only on green terrain, not roads/rocks.
cover = Image.new("L", (256, 256), 120)
draw = ImageDraw.Draw(cover)
for i in range(2800):
    x, y = rng.randrange(256), rng.randrange(256)
    color = rng.randrange(60, 210)
    for ox in [-256, 0, 256]:
        for oy in [-256, 0, 256]:
            draw.line((x+ox, y+oy, x+ox+3, y+oy-8), fill=color, width=1)
cover.filter(ImageFilter.GaussianBlur(0.5)).save(out / "meadow_cover.png")
