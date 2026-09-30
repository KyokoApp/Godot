#!/usr/bin/env python3
"""Publish only immutable, commit-specific content URLs after CI gates pass."""
import hashlib
import json
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parent.parent
pack = root / "build/content.pck"
version = subprocess.check_output(
    ["git", "rev-parse", "--short", "HEAD"], cwd=root, text=True
).strip()
manifest = {
    "schema": 1,
    "version": version,
    "engine": "4.5.2",
    "min_launcher": 1,
    "bytes": pack.stat().st_size,
    "sha256": hashlib.sha256(pack.read_bytes()).hexdigest(),
    "url": f"https://github.com/KyokoApp/Godot/releases/download/build-{version}/content.pck",
}
(root / "build/content.json").write_text(json.dumps(manifest, indent=2) + "\n")
