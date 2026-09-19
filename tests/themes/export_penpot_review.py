"""Export executed Lua dashboards as editable Penpot geometry and text.

Uses the existing desktop LCD fixture, so fonts and telemetry are illustrative.
The SVG contains vector geometry; separate text records become native editable
Penpot text, because Penpot imports SVG text as opaque SVG elements.
"""
from pathlib import Path
import argparse
import hashlib
import html
import json
import math

from render_themes import Radio, THEMES, PHASES, ROOT


class VectorRadio(Radio):
    def __init__(self, *args, **kwargs):
        self.geometry = []
        self.editable_text = []
        self.capture = False
        super().__init__(*args, **kwargs)

    def lcd(self, op, *args):
        if self.capture:
            color = '#%02X%02X%02X' % self.color
            if op in ('drawText', 'drawNumber'):
                x, y, value = args[:3]
                self.editable_text.append(dict(x=x, y=y, text=str(value), size=self.font, color=color))
            elif op in ('drawRectangle', 'drawFilledRectangle'):
                x, y, w, h = args[:4]
                if w > 0 and h > 0:
                    pen = args[4] if len(args) > 4 and args[4] else 1
                    style = f'fill="{color}"' if op == 'drawFilledRectangle' else f'fill="none" stroke="{color}" stroke-width="{pen}"'
                    self.geometry.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" {style}/>')
            elif op == 'drawLine':
                x1, y1, x2, y2 = args[:4]
                pen = args[4] if len(args) > 4 and args[4] else 1
                self.geometry.append(f'<path d="M{x1},{y1} L{x2},{y2}" fill="none" stroke="{color}" stroke-width="{pen}"/>')
            elif op in ('drawCircle', 'drawFilledCircle'):
                x, y, radius = args[:3]
                if radius > 0:
                    style = f'fill="{color}"' if op == 'drawFilledCircle' else f'fill="none" stroke="{color}"'
                    self.geometry.append(f'<circle cx="{x}" cy="{y}" r="{radius}" {style}/>')
            elif op in ('drawTriangle', 'drawFilledTriangle'):
                points = ' '.join(f'{args[i]},{args[i+1]}' for i in (0, 2, 4))
                style = f'fill="{color}"' if op == 'drawFilledTriangle' else f'fill="none" stroke="{color}"'
                self.geometry.append(f'<polygon points="{points}" {style}/>')
            elif op == 'drawAnnulusSector':
                x, y, inner, outer, start, end = args[:6]
                # Match the fixture's clockwise, top-origin arc convention.
                sweep = (end - start) % 360 or 360
                radius = (inner + outer) / 2
                pieces = max(1, math.ceil(sweep / 180))
                for i in range(pieces):
                    a = math.radians(start - 90 + sweep*i/pieces)
                    b = math.radians(start - 90 + sweep*(i+1)/pieces)
                    x1, y1 = x+radius*math.cos(a), y+radius*math.sin(a)
                    x2, y2 = x+radius*math.cos(b), y+radius*math.sin(b)
                    self.geometry.append(f'<path d="M{x1:.3f},{y1:.3f} A{radius:.3f},{radius:.3f} 0 0 1 {x2:.3f},{y2:.3f}" fill="none" stroke="{color}" stroke-width="{max(1, outer-inner)}"/>')
            elif op == 'drawPoint':
                self.geometry.append(f'<rect x="{args[0]}" y="{args[1]}" width="1" height="1" fill="{color}"/>')
        return super().lcd(op, *args)

    def vector_frame(self, theme, phase):
        state, widget = self.render(theme, phase)
        definition = self.load(f'widgets/dashboard/themes/{theme}/init.lua')
        self.texts.clear()
        self.geometry.clear()
        self.editable_text.clear()
        self.capture = True
        ready = self.engine.paint(widget, definition, state, phase, self.width, self.height)
        self.capture = False
        assert ready and not self.errors, self.errors
        assert self.editable_text and self.geometry
        opening = f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.width}" height="{self.height}" viewBox="0 0 {self.width} {self.height}">'
        geometry_svg = opening + ''.join(self.geometry) + '</svg>'
        text_svg = ''.join(f'<text x="{t["x"]}" y="{t["y"]+t["size"]*0.8}" font-family="Arial, sans-serif" font-size="{t["size"]}" fill="{t["color"]}">{html.escape(t["text"])}</text>' for t in self.editable_text)
        return geometry_svg, opening + ''.join(self.geometry) + text_svg + '</svg>', self.editable_text


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', default='build/theme-design-20260916')
    parser.add_argument('--themes', nargs='+', default=list(dict.fromkeys((*THEMES, 'vantage'))))
    args = parser.parse_args()
    out = ROOT / args.output
    out.mkdir(parents=True, exist_ok=True)
    index = []
    for theme in args.themes:
        screens = []
        for width, height in ((800, 480), (784, 294)):
            for phase in PHASES:
                radio = VectorRadio(width, height)
                geometry, svg, texts = radio.vector_frame(theme, phase)
                key = f'{theme}-{phase}-{width}x{height}'
                radio.image.save(out/f'{key}.png')
                (out/f'{key}.svg').write_text(svg, encoding='utf-8')
                source = ROOT/f'src/rfsuite/widgets/dashboard/themes/{theme}/{phase}.lua'
                screens.append(dict(key=key, theme=theme, phase=phase, width=width, height=height,
                    geometry=geometry, texts=texts, source_sha256=hashlib.sha256(source.read_bytes()).hexdigest()))
                index.append(dict(key=key, source_sha256=screens[-1]['source_sha256'], text_count=len(texts), geometry_count=len(radio.geometry)))
        (out/f'{theme}-penpot.json').write_text(json.dumps(screens, separators=(',', ':')), encoding='utf-8')
        print(f'{theme}: {len(screens)} editable screen payloads', flush=True)
    (out/'index.json').write_text(json.dumps(index, indent=2), encoding='utf-8')
    print(f'Exported {len(index)} screens from actual Lua paint callbacks; desktop font approximation.')


if __name__ == '__main__':
    main()
