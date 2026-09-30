"""Prepare the pet-only CC0 crackle loop (stdlib only, source cached outside Git)."""
import array
import base64
import hashlib
import math
import pathlib
import subprocess
import sys
import wave

CACHE = pathlib.Path.home() / ".cache/pet-fire-source.wav"
REV = "c74798f0bc905dc8aad6a429c683fe746373194d"
if not CACHE.exists():
    data = subprocess.check_output([
        "gh", "api", "repos/pawelkwaczynski/coffee-paladin/contents/sounds/critical.wav?ref=" + REV,
        "--jq", ".content"])
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    CACHE.write_bytes(base64.b64decode(data))
assert hashlib.sha256(CACHE.read_bytes()).hexdigest() == (
    "7cd334b23351add2bf7c8e4f544844a9bf29b9050125090650a58cd48dff6889")
with wave.open(str(CACHE)) as wav:
    assert (wav.getnchannels(), wav.getsampwidth(), wav.getframerate()) == (1, 2, 44100)
    raw = array.array("h", wav.readframes(wav.getnframes()))
if sys.byteorder != "little":
    raw.byteswap()
# Adjacent-pair averaging for downsampling; remove DC, retain crackle transients.
source = [(raw[i] + raw[i + 1]) / 65536.0 for i in range(0, len(raw) - 1, 2)]
mean = sum(source) / len(source)
source = [v - mean for v in source]
fade = 4410
result = []
for rate in [1.0, 0.96, 1.035]:
    take = []
    for i in range(int((len(source) - 1) / rate)):
        pos = i * rate
        j = int(pos)
        take.append(source[j] * (1 - pos + j) + source[j + 1] * (pos - j))
    if result:
        for i in range(fade):
            t = i / fade
            result[-fade + i] = result[-fade + i] * (1 - t) + take[i] * t
        result.extend(take[fade:])
    else:
        result = take
# Circular crossfade avoids a pop at the loop boundary.
for i in range(fade):
    t = i / fade
    result[i] = result[i] * t + result[-fade + i] * (1 - t)
result = result[:-fade]
gain = 0.72 / max(abs(v) for v in result)
pcm = array.array("h", [int(v * gain * 32767) for v in result])
if sys.byteorder != "little":
    pcm.byteswap()
output = pathlib.Path(__file__).resolve().parents[1] / "project/assets/audio/pet_crackle.wav"
with wave.open(str(output), "wb") as wav:
    wav.setparams((1, 2, 22050, 0, "NONE", "not compressed"))
    wav.writeframes(pcm.tobytes())
print(output, len(result) / 22050, "seconds")
