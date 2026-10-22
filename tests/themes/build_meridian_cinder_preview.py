"""Render Meridian/Cinder with the actual Suite Lua engine and build a gallery.

Desktop fonts approximate the transmitter; these are not radio screenshots.
"""
import argparse
import itertools
import json
from pathlib import Path

import render_themes as renderer


ROOT = Path(__file__).resolve().parents[2]
THEMES = ("meridian", "cinder")
SIZES = ((800, 480), (784, 294))
MODES = ("dark26", "light26", "dark16")
SCENARIOS = ("connected", "offline", "missing", "warnings")


def render(renders):
    renders.mkdir(parents=True, exist_ok=True)
    results = []
    for theme, phase, size, mode, scenario in itertools.product(
            THEMES, renderer.PHASES, SIZES, MODES, SCENARIOS):
        width, height = size
        row = dict(theme=theme, phase=phase, size=f"{width}x{height}",
                   mode=mode, scenario=scenario)
        radio = renderer.Radio(width, height, dark=mode != "light26", themed=mode != "dark16")
        original_widget = radio.widget

        def preview_widget(*args, **kwargs):
            widget = original_widget(*args, **kwargs)
            widget.craftName = "MY HELI"
            return widget

        radio.widget = preview_widget
        radio.lua.execute("model.name = function() return 'MY HELI' end; "
                          "model.getInfo = function() return {name='MY HELI'} end")
        try:
            radio.render(theme, phase, scenario)
            overflow = [text for text in radio.texts if text[0] < -1 or text[1] < -1
                        or text[0] + text[4] > width + 2 or text[1] + text[3] > height + 2]
            row.update(ok=not overflow, overflow=overflow)
            if scenario == "connected":
                radio.image.save(renders / f"{theme}-{phase}-{width}x{height}-{mode}.png")
        except Exception as error:
            row.update(ok=False, error=str(error))
        results.append(row)
    (renders / "results.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
    failed = [row for row in results if not row["ok"]]
    print(f"{len(results) - len(failed)}/{len(results)} render cases passed; "
          f"{len(THEMES) * len(renderer.PHASES) * len(SIZES) * len(MODES)} previews saved")
    if failed:
        raise RuntimeError(json.dumps(failed, indent=2))


def gallery(renders, output):
    results = json.loads((renders / "results.json").read_text(encoding="utf-8"))
    if not results or any(not row["ok"] or row.get("overflow") for row in results):
        raise RuntimeError("Gallery requires passing render results with no text overflow")
    output.parent.mkdir(parents=True, exist_ok=True)
    images = {}
    for theme, phase, size, mode in itertools.product(THEMES, renderer.PHASES, SIZES, MODES):
        dimensions = f"{size[0]}x{size[1]}"
        image = renders / f"{theme}-{phase}-{dimensions}-{mode}.png"
        if not image.is_file():
            raise FileNotFoundError(image)
        images[f"{theme}-{phase}-{dimensions}-{mode}"] = image.relative_to(output.parent).as_posix()
    page = """<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Meridian &amp; Cinder — MWRC</title>
<style>
*{box-sizing:border-box}body{margin:0;padding:28px;background:#111318;color:#eef2f5;font:16px Arial,sans-serif}
main{max-width:1100px;margin:auto}h1{font-size:26px;font-weight:500;margin:0 0 8px}p{color:#b4bdc8;line-height:1.5}
.controls{display:flex;flex-wrap:wrap;align-items:end;gap:14px;margin:24px 0 18px}
label{display:grid;gap:7px;font-size:13px;color:#bac6d2}select{font:16px Arial;padding:10px 32px 10px 12px;background:#1a2029;color:#f4f6f9;border:1px solid #485666;border-radius:6px}
select:focus-visible{outline:2px solid #8ddcec;outline-offset:3px}
figure{margin:0;padding:12px;border:1px solid #414954;background:#080a0e;border-radius:8px}
img{display:block;max-width:100%;height:auto;margin:auto}figcaption{color:#b4bdc8;font-size:13px;text-align:center;margin-top:12px}
.note{font-size:13px;color:#a5afbd;margin-top:18px}a{color:#a9d6ec}
</style>
<main><h1>Meridian &amp; Cinder</h1><p>Two new Rotorflight themes. Explore each screen and display size.</p>
<div class="controls">
<label>Theme<select id="theme"><option value="meridian">Meridian</option><option value="cinder">Cinder</option></select></label>
<label>Screen<select id="phase"><option value="preflight">Preflight</option><option value="inflight" selected>Inflight</option><option value="postflight">Postflight</option></select></label>
<label>Display<select id="size"><option value="800x480">Full screen · 800 × 480</option><option value="784x294">Compact widget · 784 × 294</option></select></label>
<label>Radio appearance<select id="mode"><option value="dark26">ETHOS 26 · Dark</option><option value="light26">ETHOS 26 · Light</option><option value="dark16">ETHOS 1.6 · Dark</option></select></label>
</div><figure><img id="screen" width="800" height="480" alt="Meridian inflight dashboard"><figcaption id="caption"></figcaption></figure>
<p class="note">Rendered from the implemented themes. Desktop fonts approximate the radio. MY HELI is sample model data; the radio uses your selected model. RPM has no fixed limit or redline.</p>
</main><script>
const images=__IMAGES__, controls=['theme','phase','size','mode'].map(id=>document.getElementById(id));
function show(){const [theme,phase,size,mode]=controls.map(el=>el.value),image=document.getElementById('screen');
image.src=images[[theme,phase,size,mode].join('-')]; const [width,height]=size.split('x').map(Number);image.width=width;image.height=height;
image.alt=theme+' '+phase+' dashboard';document.getElementById('caption').textContent=controls.map(el=>el.selectedOptions[0].textContent).join(' · ');}
controls.forEach(el=>el.addEventListener('change',show));show();
</script></html>"""
    output.write_text(page.replace("__IMAGES__", json.dumps(images)), encoding="utf-8")
    print(f"Gallery: {output}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--renders", default="artifacts/meridian-cinder/renders")
    parser.add_argument("--output", default="artifacts/meridian-cinder/preview-gallery.html")
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args()
    renders, output = ROOT / args.renders, ROOT / args.output
    if args.render:
        render(renders)
    gallery(renders, output)


if __name__ == "__main__":
    main()
