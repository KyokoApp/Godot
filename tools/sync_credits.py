"""Keep the offline, exportable credits in sync with the repository notices."""
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAIRS = {
    ROOT / 'docs/CREDITS.md': ROOT / 'project/licenses/CREDITS.txt',
    ROOT / 'LICENSE': ROOT / 'project/licenses/A-Sekai-Rights.txt',
}
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
for source, target in PAIRS.items():
    if args.check:
        if not target.exists() or target.read_bytes() != source.read_bytes():
            raise SystemExit(f'Out of sync: {target}; run python3 tools/sync_credits.py')
    else:
        target.write_bytes(source.read_bytes())
print('Credits and rights notices: OK')
