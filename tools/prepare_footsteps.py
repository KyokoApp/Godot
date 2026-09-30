"""Convert pinned Kenney recordings to small mono positional SFX.
Requires numpy, soundfile. Sources cached outside Git; fetch via gh API.
"""
import base64
import pathlib
import subprocess
import numpy as np
import soundfile as sf

SOURCE = "iree-gd/iree.gd"
REV = "9db7d7069a9ad75c77e9b5657d1ae5bdf615a6bc"
CACHE = pathlib.Path.home() / ".cache/audio_source"
OUT = pathlib.Path(__file__).resolve().parents[1] / "project/assets/audio"
CACHE.mkdir(parents=True, exist_ok=True)
OUT.mkdir(parents=True, exist_ok=True)


def read(kind, index):
    name = f"footstep_{kind}_{index:03}.ogg"
    path = CACHE / name
    if not path.exists():
        data = subprocess.check_output([
            "gh", "api", f"repos/{SOURCE}/contents/sample/assets/audio/impact/{name}?ref={REV}",
            "--jq", ".content"])
        path.write_bytes(base64.b64decode(data))
    audio, rate = sf.read(path)
    assert rate == 44100
    mono = audio.mean(axis=1)[::2]
    active = np.flatnonzero(abs(mono) > 0.012)
    mono = mono[max(0, active[0] - 80):min(len(mono), active[-1] + 160)]
    return mono


def write(name, data):
    data = data.copy()
    fade = min(110, len(data) // 4)
    data[:fade] *= np.linspace(0, 1, fade)
    data[-fade:] *= np.linspace(1, 0, fade)
    data *= 0.65 / max(abs(data).max(), 1e-9)
    sf.write(OUT / name, data, 22050, subtype="PCM_16")


for i in range(4):
    grass, stone = read("grass", i), read("concrete", i)
    write(f"step_grass_{i}.wav", grass)
    write(f"step_stone_{i}.wav", stone)
    # Dry packed-earth foley approximation: dull heel contact plus dry crunch.
    dirt = np.zeros(max(len(grass), len(stone)))
    dirt[:len(grass)] += grass * 0.55
    dirt[:len(stone)] += stone * 0.28
    dirt = np.convolve(dirt, np.ones(5) / 5, mode="same")
    write(f"step_dirt_{i}.wav", dirt)
