"""Package only the six user themes and Theme Bridge; generate review artifacts."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import base64
import hashlib
import html
import json
import subprocess

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
THEMES = {'aegis':'Aegis', 'america250':'America 250', 'libertyops250':'Liberty Ops 250',
          'mwrc':'MWRC', 'singularity':'Singularity', 'zafira':'Zafira'}
OUT = ROOT / 'artifacts/theme-refresh'
PREVIEWS = ROOT / 'artifacts/theme-previews'


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    results = json.loads((PREVIEWS/'results.json').read_text())
    assert len(results) == 432 and all(r['ok'] for r in results), 'render matrix incomplete'
    assert not any(r.get('overflow') for r in results), 'text outside supported screen bounds'
    base = subprocess.check_output(['git','rev-parse','origin/radio-all-themes'], cwd=ROOT, text=True).strip()
    changed = subprocess.check_output(['git','-c','core.safecrlf=false','diff','--name-only',base,'--','src'], cwd=ROOT, text=True).splitlines()
    prefix = 'src/rfsuite/widgets/dashboard/themes/'
    allowed = [prefix + name + '/' for name in (*THEMES, 'vantage')]
    assert all(path == 'src/rfsuite/app/theme_bridge.lua' or any(path.startswith(p) for p in allowed) for path in changed), 'suite core changed'
    files = [ROOT/'src/rfsuite/app/theme_bridge.lua']
    for name in THEMES:
        files.extend(sorted((ROOT/prefix/name).rglob('*')))
    files = [path for path in files if path.is_file()]
    entries = {}
    for file in files:
        name = 'scripts/' + file.relative_to(ROOT/'src').as_posix()
        content = file.read_bytes()
        assert '@i18n(' not in content.decode('utf-8',errors='ignore'), f'unexpanded translation: {name}'
        entries[name] = content
    manifest = {name:hashlib.sha256(content).hexdigest() for name,content in entries.items()}
    readme = f'''# User theme refresh — September 7, 2026

This update contains Aegis, America 250, Liberty Ops 250, MWRC, Singularity,
Zafira, and Theme Bridge. It targets the rewritten `radio-all-themes` branch,
verified at `{base}`. Suite core files are unchanged from that branch.

## Install

1. Back up your radio's six theme folders and `scripts/rfsuite/app/theme_bridge.lua`.
2. Close Rotorflight Suite. Merge this ZIP's `scripts` folder into the radio's
   scripts folder, replacing the included theme files and Theme Bridge.
3. Restart the scripts/radio and select your theme in Suite Settings → Dashboard.

This is a manual overlay, not a complete suite installer. It needs the existing
all-themes branch registrations and bridge hooks. Stock upstream `master` does
not include those registrations; installing this overlay onto stock master alone
does not make the themes selectable. No core patch is included.

## Rewrite integration points

- `main.lua` starts separate background tasks, the app tool, and the dashboard.
  Shared updates travel through `lib/bus.lua`; themes cannot depend on the old
  global suite object.
- Theme files load the local `widgets/dashboard/context.lua` facade. The unchanged
  engine consumes phase layouts and boxes; custom drawing uses cached func boxes.
- Theme configuration is hosted by `app/pages/settings_dashboard_settings.lua`.
  It calls `configure()` and `write()`; instruments read active preferences through
  `dashboard.getPreference()`.
- Theme Bridge uses each theme's small `init.lua` / `appTheme` palette and the
  current flight-state tracker. It avoids loading full dashboard pages for app chrome.

## Changes

- Saved instrument limits now use the rewritten suite's active theme preferences.
- User-entered BEC limits are preserved; Celsius/Fahrenheit settings round-trip.
- Missing/nonfinite readings show placeholders; incomplete preflight readings do
  not claim readiness. Liberty Ops no longer crashes on missing telemetry.
- Six visual identities retain their original character with improved headers,
  contrast, fitted text, compact layouts, and clearer instrument/report cards.
- All six themes use `Rotorflight // Ethos | MWRC` in their top header across
  preflight, in-flight, and postflight. MWRC is a smaller, muted builder signature;
  the main title fits narrower windows while retaining this subtle branding.
- The automatic model-name field remains intact: telemetry supplies the craft name,
  with the selected Ethos model name as the suite's existing fallback.
- Theme palettes are private and cannot alter the suite's cached native palette.
- Liberty Ops' old nonfunctional shortcut buttons are replaced with radio Tools
  menu guidance; the current engine does not dispatch those theme callbacks.
- Theme Bridge preserves phase on same-model reconnect, keeps its tracker state
  private, and rebuilds its canvas when the available screen size changes.

## Verified

432 render cases passed using the unchanged real suite engine/context and a
desktop LCD fixture: six themes × three phases × two sizes (800×480, 784×294)
× four data scenarios × three legacy/native dark/light API modes.
Behavioral tests cover theme settings, units, missing/corrupt data, private
palettes, and historical per-cell voltage after connection loss.
Seven bridge tests pass; three reproduce the original bridge defects.
Core source scope and the ZIP file list/hashes are checked by the bundle builder.

Desktop previews use approximate font metrics and simulated data. They are not
radio screenshots. On the radio, check both window sizes, saved limit changes,
flight-phase transitions, connect/loss/reconnect, C/F temperatures, model changes,
and repeated app opens for readability, instruction-budget errors, and RAM use.

Companion Ethos/Rotorflight skill corrections are provided separately in
`artifacts/ethos-skill-update`. Their two standalone examples passed Lua 5.2
regression checks. Apply these corrections to an existing skill installation;
they are separate from the radio theme overlay.

Vantage is supplied separately in `src/rfsuite/widgets/dashboard/themes/vantage`.
It is a new theme folder; its registration in the suite's fixed picker is outside
this update. The six-theme ZIP continues to contain only the original six themes
and Theme Bridge.
'''
    (OUT/'README.md').write_text(readme, encoding='utf-8')
    (OUT/'manifest.json').write_text(json.dumps({'base':base,'files':manifest},indent=2),encoding='utf-8')
    zip_path = OUT/'rotorflight-user-themes-refresh-2026-09-07.zip'
    with ZipFile(zip_path,'w',ZIP_DEFLATED) as archive:
        for name,content in entries.items(): archive.writestr(name,content)
        archive.writestr('README.md',readme)
        archive.writestr('manifest.json',json.dumps({'base':base,'files':manifest},indent=2))
    with ZipFile(zip_path) as archive:
        assert archive.testzip() is None
        assert set(archive.namelist()) == set(entries) | {'README.md','manifest.json'}
        for name,digest in manifest.items():
            assert hashlib.sha256(archive.read(name)).hexdigest() == digest

    # Self-contained gallery: no server, network, or separate assets needed.
    data = {}
    for image in PREVIEWS.glob('*.png'):
        data[image.stem] = 'data:image/png;base64,' + base64.b64encode(image.read_bytes()).decode('ascii')
    page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Rotorflight — Six theme refresh</title><style>
*{box-sizing:border-box}body{margin:0;background:#090d13;color:#e9f0fa;font:16px system-ui,sans-serif}
main{max-width:1740px;margin:auto;padding:36px}h1{font-size:36px;letter-spacing:-1px;margin:8px 0}
.kicker{color:#6bdef0;font-size:13px;letter-spacing:3px}p{color:#a9b8cb;line-height:1.5}
nav{display:flex;gap:12px;flex-wrap:wrap;margin:26px 0}label{color:#a9b8cb;font-size:13px}
select{display:block;background:#18202d;color:#eef3fa;border:1px solid #3e4b60;border-radius:6px;padding:10px;margin-top:5px;font:inherit}
.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:22px}.card{background:#101721;border:1px solid #263447;border-radius:10px;overflow:hidden}
.card h2{margin:0;padding:15px 18px;font-size:18px}.card img{width:100%;display:block;background:#000}
footer{margin-top:24px;color:#8394aa;font-size:13px}@media(max-width:850px){.grid{grid-template-columns:1fr}main{padding:18px}h1{font-size:28px}}
</style><main><div class="kicker">ROTORFLIGHT / PERSONAL THEMES</div><h1>Six identities. A clearer view.</h1>
<p>Updated for the rewritten all-themes suite. Desktop renders from the real theme code and unchanged suite engine; simulated data and approximate fonts.</p>
<nav><label>Flight screen<select id="phase"><option value="preflight">Preflight</option><option value="inflight" selected>In flight</option><option value="postflight">Postflight</option></select></label>
<label>Window<select id="size"><option>800x480</option><option>784x294</option></select></label>
<label>Radio appearance API<select id="mode"><option value="dark16">Legacy dark</option><option value="dark26">Native dark</option><option value="light26">Native light</option></select></label></nav>
<div class="grid" id="gallery"></div><footer>Radio acceptance testing is still required. Suite core unchanged. September 7, 2026.</footer>
</main><script>const themes=THEMES_DATA;const images=IMAGES_DATA;
function show(){const phase=document.getElementById('phase').value,size=document.getElementById('size').value,mode=document.getElementById('mode').value;
document.getElementById('gallery').replaceChildren(...Object.entries(themes).map(([key,name])=>{const card=document.createElement('section');card.className='card';const title=document.createElement('h2');title.textContent=name;const img=document.createElement('img');img.src=images[`${key}-${phase}-${size}-${mode}`];img.alt=`${name} ${phase} desktop preview`;card.append(title,img);return card}));}
document.querySelectorAll('select').forEach(el=>el.addEventListener('change',show));show();</script></html>'''
    page = page.replace('THEMES_DATA',json.dumps(THEMES)).replace('IMAGES_DATA',json.dumps(data))
    (OUT/'preview-gallery.html').write_text(page,encoding='utf-8')
    contact=Image.new('RGB',(1640,1630),'#090d13')
    draw=ImageDraw.Draw(contact)
    heading=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',28)
    label=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',22)
    draw.text((20,15),'Rotorflight | Six theme refresh',font=heading,fill='#e9f0fa')
    for i,(key,name) in enumerate(THEMES.items()):
        x=20+(i%2)*810;y=70+(i//2)*510
        draw.text((x,y),name,font=label,fill='#e9f0fa')
        contact.paste(Image.open(PREVIEWS/f'{key}-inflight-800x480-dark16.png'),(x,y+29))
    draw.text((20,1610),'Desktop previews · simulated data · radio testing required',fill='#9eaec2')
    contact.save(OUT/'six-themes.png')
    print(f'Packaged {len(entries)} theme/bridge files; suite core unchanged; archive hashes verified.')
    print(zip_path)


if __name__=='__main__': main()
