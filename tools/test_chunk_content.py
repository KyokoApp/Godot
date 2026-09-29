#!/usr/bin/env python3
"""No network: real format fixtures plus optional two-export reuse measurement."""
import hashlib
import struct
import tempfile
import unittest
from pathlib import Path
from chunk_content import build, split


def fake_pack(script):
    # V3, directory at end. Large resource moves after script but bytes stay identical.
    model = bytes(range(256)) * 10000
    payloads = [script, model, b'end']
    header = bytearray(104)
    struct.pack_into('<6I', header, 0, 0x43504447, 3, 4, 5, 2, 2)
    struct.pack_into('<QQ', header, 24, 104, 104 + sum(map(len, payloads)))
    directory = bytearray(struct.pack('<I', len(payloads)))
    offset = 0
    for i, data in enumerate(payloads):
        path = f'res://file{i}'.encode()
        directory += struct.pack('<I', len(path)) + path
        directory += struct.pack('<QQ', offset, len(data))
        directory += hashlib.md5(data).digest() + struct.pack('<I', 0)
        offset += len(data)
    return bytes(header) + b''.join(payloads) + directory


class Chunks(unittest.TestCase):
    def test_stable_large_file_and_complete_reconstruction(self):
        old = fake_pack(b'old script')
        new = fake_pack(b'new, longer script')
        before = list(split(old))
        after = list(split(new))
        self.assertEqual(b''.join(after), new)
        self.assertLess(sum(len(x) for x in after if x not in before), 1024)
        self.assertTrue(all(0 < len(x) <= 1048576 for x in after))
        self.assertEqual(before, list(split(old)))

    def test_manifest_and_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            pack = Path(tmp) / 'content.pck'
            pack.write_bytes(fake_pack(b'hello'))
            manifest = build(pack, Path(tmp) / 'chunks', 'abcdef1')
            joined = b''.join((Path(tmp) / 'chunks' / (c['sha256'] + '.bin')).read_bytes()
                              for c in manifest['chunks'])
            self.assertEqual(joined, pack.read_bytes())
            self.assertEqual(hashlib.sha256(joined).hexdigest(), manifest['sha256'])

    def test_invalid(self):
        with self.assertRaises((ValueError, struct.error)):
            list(split(b'not a pack'))


if __name__ == '__main__':
    unittest.main()
