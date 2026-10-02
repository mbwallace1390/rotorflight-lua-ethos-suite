"""Embed the actual Ink & Halo Lua renders in the phase/layout preview."""
import argparse
import base64
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--renders', default='artifacts/inkhalo/renders')
parser.add_argument('--output', required=True)
args = parser.parse_args()
renders = ROOT / args.renders
results = json.loads((renders / 'results.json').read_text(encoding='utf-8'))
assert results and all(row['ok'] and not row.get('overflow') for row in results)
images = {}
for phase in ('preflight', 'inflight', 'postflight'):
    for size in ('800x480', '784x294'):
        file = renders / f'inkhalo-{phase}-{size}-dark26.png'
        images[f'{phase}-{size}'] = 'data:image/png;base64,' + base64.b64encode(file.read_bytes()).decode('ascii')
fragment = Path(__file__).with_name('inkhalo-preview.fragment.html').read_text(encoding='utf-8')
fragment = fragment.replace('__INKHALO_IMAGES__', json.dumps(images, separators=(',', ':')))
fragment = fragment.replace('__INKHALO_HERO__', images['inflight-800x480'])
assert '__INKHALO_' not in fragment
assert len(fragment.encode('utf-8')) < 1_000_000
output = Path(args.output)
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(fragment, encoding='utf-8')
print(f'Built six-view preview: {output} ({output.stat().st_size:,} bytes)')
