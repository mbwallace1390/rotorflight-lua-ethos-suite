from pathlib import Path


def patch_mwrc(path: Path) -> None:
    text = path.read_text()
    if 'HEADER_WATERMARK = "MWRC"' in text:
        return
    text = text.replace(
        'local HEADER_TEXT_3 = "ROTORFLIGHT"',
        'local HEADER_TEXT_3 = "ROTORFLIGHT"\nlocal HEADER_WATERMARK = "MWRC"',
        1,
    )
    if 'local headerTextWidth3 = nil' not in text:
        text = text.replace(
            'local headerTextWidth2 = nil',
            'local headerTextWidth2 = nil\nlocal headerTextWidth3 = nil',
            1,
        )
    text = text.replace(
        'local headerTextWidth3 = nil',
        'local headerTextWidth3 = nil\nlocal headerWatermarkWidth = nil',
        1,
    )
    if 'headerTextWidth3 = lcd.getTextSize(HEADER_TEXT_3)' not in text:
        text = text.replace(
            '        headerTextWidth2 = lcd.getTextSize(HEADER_TEXT_2)',
            '        headerTextWidth2 = lcd.getTextSize(HEADER_TEXT_2)\n        headerTextWidth3 = lcd.getTextSize(HEADER_TEXT_3)',
            1,
        )
    anchor = '    lcd.drawText(x + 5 + headerTextWidth1 + headerTextWidth2, y + 4, HEADER_TEXT_3)'
    mark = '''

    local watermarkX = x + 5 + headerTextWidth1 + headerTextWidth2 + headerTextWidth3 + 10
    lcd.color(rc.amber)
    lcd.drawLine(watermarkX - 5, y + 9, watermarkX - 5, y + 25)
    lcd.font(FONT_XS or FONT_XXS or 0)
    if headerWatermarkWidth == nil then headerWatermarkWidth = lcd.getTextSize(HEADER_WATERMARK) end
    lcd.color(rc.cyan)
    lcd.drawText(watermarkX, y + 8, HEADER_WATERMARK)'''
    if anchor not in text:
        raise RuntimeError(f'MWRC header anchor missing: {path}')
    path.write_text(text.replace(anchor, anchor + mark, 1))


def patch_aegis(path: Path) -> None:
    lines = path.read_text().splitlines()
    if any('local watermarkText = "MWRC"' in line for line in lines):
        return
    start = next(i for i, line in enumerate(lines) if 'local t1, t2, t3 = "ETHOS ", "// ", "ROTORFLIGHT"' in line)
    end = next(i for i in range(start, len(lines)) if 'lcd.drawText(tx + tw1 + tw2, ty, t3)' in lines[i])
    ind = lines[start][:len(lines[start]) - len(lines[start].lstrip())]
    raw = [
        'local t1, t2, t3 = "ETHOS ", "// ", "ROTORFLIGHT"',
        'local tw1, th = lcd.getTextSize(t1)', 'local tw2 = lcd.getTextSize(t2)', 'local tw3 = lcd.getTextSize(t3)',
        'local watermarkFont = utils.resolveFont("FONT_XS", nil)', 'local watermarkText = "MWRC"',
        'local watermarkWidth, watermarkHeight = 0, 0', 'if type(watermarkFont) == "number" then',
        '    lcd.font(watermarkFont)', '    watermarkWidth, watermarkHeight = lcd.getTextSize(watermarkText)',
        '    lcd.font(font)', 'end', 'local titleW = tw1 + tw2 + tw3',
        'local totalW = titleW + (watermarkWidth > 0 and 14 or 0) + watermarkWidth',
        'local tx = floor(x + (w - totalW) / 2)', 'local ty = floor(y + (h - th) / 2)', '',
        'lcd.color(C.cyan)', 'lcd.drawText(tx, ty, t1)', 'lcd.color(C.amber)',
        'lcd.drawText(tx + tw1, ty, t2)', 'lcd.color(C.white)', 'lcd.drawText(tx + tw1 + tw2, ty, t3)',
        'if watermarkWidth > 0 then', '    local dividerX = tx + titleW + 6', '    lcd.color(C.line2)',
        '    lcd.drawLine(dividerX, y + 7, dividerX, y + h - 7)', '    lcd.font(watermarkFont)',
        '    lcd.color(C.cyan)', '    lcd.drawText(dividerX + 7, floor(y + (h - watermarkHeight) / 2), watermarkText)', 'end',
    ]
    lines[start:end + 1] = [ind + line if line else '' for line in raw]
    path.write_text('\n'.join(lines) + '\n')


for name in ('preflight.lua', 'inflight.lua', 'postflight.lua'):
    patch_mwrc(Path('src/rfsuite/widgets/dashboard/themes/mwrc') / name)
    patch_aegis(Path('src/rfsuite/widgets/dashboard/themes/aegis') / name)
