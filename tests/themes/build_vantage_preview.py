from pathlib import Path
import base64
import json
import math
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[2]
out = root / 'artifacts/vantage'
renders = out / 'renders'
theme = root / 'src/rfsuite/widgets/dashboard/themes/vantage'
out.mkdir(parents=True, exist_ok=True)

# A small vector instrument emblem, rasterized once for the theme picker.
icon = Image.new('RGBA', (192, 192), '#080e14')
d = ImageDraw.Draw(icon)
for angle in range(135, 406, 15):
    a = math.radians(angle)
    inner, outer = (69, 83) if angle % 45 == 0 else (76, 83)
    color = '#89dcf1' if angle < 345 else '#f5b95e'
    d.line((96+inner*math.cos(a), 94+inner*math.sin(a),
            96+outer*math.cos(a), 94+outer*math.sin(a)), fill=color, width=3)
d.line((57, 66, 96, 126, 135, 66), fill='#e7f2f6', width=9)
d.line((69, 66, 96, 108, 123, 66), fill='#89dcf1', width=3)
icon.resize((64, 64), Image.Resampling.LANCZOS).save(theme / 'icon.png')

results = json.loads((renders / 'results.json').read_text())
assert len(results) == 72 and all(row['ok'] and not row.get('overflow') for row in results)
images = {p.stem: 'data:image/png;base64,' + base64.b64encode(p.read_bytes()).decode()
          for p in renders.glob('*.png')}
page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Vantage — Rotorflight // Ethos | MWRC</title><style>
*{box-sizing:border-box}body{margin:0;background:#080e14;color:#e7f2f6;font:16px system-ui,sans-serif}
main{max-width:1680px;margin:auto;padding:36px}h1{font-size:52px;font-weight:600;letter-spacing:-2px;margin:0}
.intro{display:flex;justify-content:space-between;align-items:center;gap:20px;border-bottom:1px solid #283b48;padding-bottom:26px}
.signature{font-size:12px;color:#829caa;margin-left:8px}p{line-height:1.6;color:#829caa;max-width:760px}
.emblem{width:86px;height:86px;image-rendering:auto}nav{display:flex;gap:20px;flex-wrap:wrap;margin:24px 0}
label{font-size:13px;color:#829caa}select{display:block;margin-top:6px;background:#111b24;color:#e7f2f6;border:1px solid #476171;padding:10px;font:inherit}
.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:24px}.card{background:#111b24;border:1px solid #283b48}
.card:first-child{grid-column:1/-1;max-width:100%;display:grid;grid-template-columns:300px 1fr}
.copy{padding:22px}.card h2{font-size:24px;font-weight:500;margin:0 0 10px}.card p{font-size:14px;margin:0}
.card img{display:block;width:100%;align-self:center}.note{font-size:12px;margin-top:28px}
@media(max-width:850px){main{padding:20px}.grid{grid-template-columns:1fr}.card:first-child{display:block}h1{font-size:42px}}
</style><main><div class="intro"><div><h1>VANTAGE</h1><p>Rotorflight // Ethos <span class="signature">| MWRC</span></p></div><img class="emblem" src="ICON_DATA" alt="Vantage rotor instrument emblem"></div>
<p>A precision cockpit in graphite and ice blue. A clear launch checklist, a sweeping rotor-speed instrument, and a flight report built around the readings that matter.</p>
<nav><label>Screen size<select id="size"><option>800x480</option><option>784x294</option></select></label>
<label>Radio appearance<select id="mode"><option value="dark16">Legacy dark</option><option value="dark26">Native dark</option><option value="light26">Native light</option></select></label></nav>
<div class="grid" id="gallery"></div><p class="note">Desktop previews use simulated telemetry and approximate radio fonts. Actual-radio testing remains. Vantage is a new theme folder; suite core and the existing six themes are unchanged by this addition.</p>
</main><script>const images=IMAGE_DATA;const phases=[['inflight','Flight deck','The rotor-speed dial is the focal point. Fuel, temperature, power, and radio health stay within one glance.'],['preflight','Launch checklist','Five required signals, explicit missing-data states, and a prominent pack and fuel readout.'],['postflight','Flight report','Recorded duration and peak/minimum readings, with clear labels for flight history.']];
function show(){let size=document.getElementById('size').value,mode=document.getElementById('mode').value;document.getElementById('gallery').replaceChildren(...phases.map(([key,title,description])=>{let card=document.createElement('section');card.className='card';let copy=document.createElement('div');copy.className='copy';let h=document.createElement('h2');h.textContent=title;let p=document.createElement('p');p.textContent=description;let img=document.createElement('img');img.src=images[`vantage-${key}-${size}-${mode}`];img.alt=`Vantage ${key} desktop preview`;copy.append(h,p);card.append(copy,img);return card;}));}document.querySelectorAll('select').forEach(el=>el.addEventListener('change',show));show();</script></html>'''
page = page.replace('IMAGE_DATA', json.dumps(images)).replace('ICON_DATA',
    'data:image/png;base64,' + base64.b64encode((theme/'icon.png').read_bytes()).decode())
(out/'preview-gallery.html').write_text(page, encoding='utf-8')
contact = Image.new('RGB', (840, 1630), '#080e14')
draw = ImageDraw.Draw(contact)
font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 25)
small = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 13)
draw.text((20, 14), 'VANTAGE / Rotorflight // Ethos', fill='#e7f2f6', font=font)
for i, (phase, label) in enumerate((('preflight', 'Launch checklist'), ('inflight', 'Flight deck'), ('postflight', 'Flight report'))):
    y = 62 + i*515
    draw.text((20,y), label, fill='#89dcf1', font=small)
    contact.paste(Image.open(renders/f'vantage-{phase}-800x480-dark16.png'), (20,y+22))
draw.text((20,1610),'Desktop preview · simulated telemetry · radio testing required',fill='#829caa',font=small)
contact.save(out/'vantage-three-screens.png')
print('Vantage icon and preview gallery built from 72 passing render cases.')
