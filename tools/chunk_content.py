#!/usr/bin/env python3
"""Stable, file-aligned blocks of the exact exported PCK (not overlay patches)."""
import hashlib
import json
import struct
from pathlib import Path

MAX_BLOCK = 1024 * 1024


def entries(data):
    """Read unencrypted Godot PCK v2/v3 directory; preserve every byte including gaps."""
    magic, version, major, minor, patch, flags = struct.unpack_from('<6I', data)
    if magic != 0x43504447 or version not in (2, 3) or flags & ~2:
        raise ValueError('Unsupported/encrypted PCK')
    base = struct.unpack_from('<Q', data, 24)[0]
    cursor = struct.unpack_from('<Q', data, 32)[0] if version == 3 else 96
    count = struct.unpack_from('<I', data, cursor)[0]
    cursor += 4
    result = {}
    for _ in range(count):
        length = struct.unpack_from('<I', data, cursor)[0]
        path = data[cursor + 4:cursor + 4 + length].rstrip(b"\0").decode()
        cursor += 4 + length
        offset, size = struct.unpack_from('<QQ', data, cursor)
        file_flags = struct.unpack_from('<I', data, cursor + 32)[0]
        cursor += 36
        if file_flags:
            raise ValueError('Encrypted/removed entry unsupported')
        if size:
            start = base + offset
            if start < 0 or start + size > len(data):
                raise ValueError('Invalid PCK file range')
            result[path] = (start, start + size)
    return result


def file_ranges(data):
    return entries(data).values()


def split(data):
    # Pin boundaries of large resources: changing a script cannot shift model blocks.
    cuts = {0, len(data)}
    for start, end in file_ranges(data):
        if end - start >= 65536:
            cuts.update(range(start, end, MAX_BLOCK))
            cuts.add(end)
    ordered = sorted(cuts)
    for start, end in zip(ordered, ordered[1:]):
        for offset in range(start, end, MAX_BLOCK):
            yield data[offset:min(offset + MAX_BLOCK, end)]


def build(pack, output, version):
    data = Path(pack).read_bytes()
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    chunks = []
    for block in split(data):
        sha = hashlib.sha256(block).hexdigest()
        (output / f'{sha}.bin').write_bytes(block)
        chunks.append({'sha256': sha, 'bytes': len(block)})
    manifest = dict(schema=2, engine='4.5.2', min_launcher=2, version=version,
                    bytes=len(data), sha256=hashlib.sha256(data).hexdigest(), chunks=chunks)
    return manifest


def main():
    import subprocess
    import shutil
    root = Path(__file__).resolve().parents[1]
    version = subprocess.check_output(['git', 'rev-parse', '--short', 'HEAD'],
                                      cwd=root, text=True).strip()
    manifest = build(root / 'build/content.pck', root / 'build/chunks', version)
    text = json.dumps(manifest, separators=(',', ':')) + '\n'
    (root / 'build/content-v2.json').write_text(text)
    seed = root / 'project/bootstrap'
    seed.mkdir(exist_ok=True)
    (seed / 'base.json').write_text(text)
    shutil.copyfile(root / 'build/content.pck', seed / 'base.pck')
    print(f"Incremental index: {len(manifest['chunks'])} blocks, {manifest['bytes']} bytes")


if __name__ == '__main__':
    main()
