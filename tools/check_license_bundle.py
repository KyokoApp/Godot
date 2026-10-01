"""Validate the single consolidated, exportable license and provenance bundle."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = ROOT / "project/licenses/LICENSES.txt"
RETIRED_NOTICE_FILES = [
    ROOT / "LICENSE",
    ROOT / "docs/CREDITS.md",
    *[path for path in (ROOT / "project/licenses").glob("*.txt")
      if path.name != "LICENSES.txt"],
    ROOT / "Universal Animation Library 2[Standard]/License.txt",
]
REQUIRED_TEXT = [
    "A-SEKAI — ORIGINAL WORK RIGHTS NOTICE",
    "Universal Animation Library [Standard]",
    "CC0 1.0 Universal",
    "Copyright (c) 2020-present GDQuest",
    "Copyright (c) 2023 - present Marcel Bankmann",
    "Hatsune Miku -NXZ-",
    "I permit it as long as you include my license in your project.",
    "Kanna — archived character model",
    "Redistribution_Prohibited",
    "Permission-account credit: Naxzed",
]

if not BUNDLE.is_file():
    raise SystemExit(f"Missing consolidated notice: {BUNDLE.relative_to(ROOT)}")
leftovers = [path.relative_to(ROOT).as_posix() for path in RETIRED_NOTICE_FILES if path.exists()]
if leftovers:
    raise SystemExit("Separate notice files remain: " + ", ".join(leftovers))
notice_entries = sorted(path.name for path in BUNDLE.parent.iterdir())
if notice_entries != ["LICENSES.txt"]:
    raise SystemExit("project/licenses/ must contain only LICENSES.txt")

presets = (ROOT / "project/export_presets.cfg").read_text(encoding="utf-8")
if presets.count("licenses/LICENSES.txt") != 2:
    raise SystemExit("Both APK and PCK export presets must include LICENSES.txt")

bundle = BUNDLE.read_text(encoding="utf-8")
missing = [text for text in REQUIRED_TEXT if text not in bundle]
if missing:
    raise SystemExit("Required notice/permission text missing from LICENSES.txt: " + "; ".join(missing))

print("Consolidated license/credits/permissions bundle: OK")
