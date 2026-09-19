-- Ink & Halo: bounded drawing helpers shared only by this dashboard theme.
-- GPLv3
local lcd = lcd
local floor, min, max = math.floor, math.min, math.max
local M = {}
M.colors = {
    bg = lcd.RGB(8, 11, 16), panel = lcd.RGB(13, 16, 23), panel2 = lcd.RGB(23, 29, 40),
    white = lcd.RGB(244, 247, 252), cyan = lcd.RGB(189, 215, 255), muted = lcd.RGB(181, 191, 206),
    line = lcd.RGB(40, 49, 63), line2 = lcd.RGB(84, 100, 122),
    green = lcd.RGB(141, 201, 164), amber = lcd.RGB(230, 199, 134), red = lcd.RGB(242, 147, 156),
    violet = lcd.RGB(189, 215, 255),
}
local C = M.colors
local HALO_INNER = lcd.RGB(64, 78, 101)
local HALO_OUTER = lcd.RGB(29, 37, 50)
local FONT_FALLBACK = {FONT_XXXXL="FONT_XXL", FONT_XXL="FONT_XL", FONT_XL="FONT_L", FONT_L="FONT_STD", FONT_STD="FONT_S", FONT_S="FONT_XS", FONT_XS="FONT_XXS"}
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local utils = requireModule("widgets/dashboard/context.lua").widgets.dashboard.utils

-- A bounded slot cache avoids repeated font measurements on unchanged frames.
function M.text(c, slot, x, y, w, h, text, requested, color, align)
    text = text or "--"
    local fits = c._textFits
    if not fits then fits = {}; c._textFits = fits end
    local fit = fits[slot]
    if not fit then fit = {}; fits[slot] = fit end
    if fit.text ~= text or fit.width ~= w or fit.height ~= h or fit.requested ~= requested then
        fit.text, fit.width, fit.height, fit.requested = text, w, h, requested
        local name = requested
        local font = utils.resolveFont(name, nil)
        lcd.font(font)
        local tw, th = lcd.getTextSize(text)
        while (tw > w or th > h) and FONT_FALLBACK[name] do
            name = FONT_FALLBACK[name]
            font = utils.resolveFont(name, nil)
            lcd.font(font)
            tw, th = lcd.getTextSize(text)
        end
        fit.font, fit.tw, fit.th = font, tw, th
    end
    lcd.font(fit.font)
    lcd.color(color or C.white)
    local tx = x
    if align == "center" then tx = x + (w - fit.tw) / 2
    elseif align == "right" then tx = x + w - fit.tw end
    lcd.drawText(floor(tx + 0.5), floor(y + (h - fit.th) / 2 + 0.5), text)
end

function M.surface(x, y, w, h, accent)
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    local r = min(6, floor(w / 2), floor(h / 2))
    local half = floor(r / 2)
    local right, bottom = x + w - 1, y + h - 1
    -- Three overlapping fills and eight strokes relieve the corners without assets.
    lcd.color(C.panel)
    lcd.drawFilledRectangle(x + r, y, w - r * 2, h)
    lcd.drawFilledRectangle(x, y + r, w, h - r * 2)
    lcd.drawFilledRectangle(x + half, y + half, w - half * 2, h - half * 2)
    lcd.color(accent or C.line2)
    lcd.drawLine(x + r, y, right - r, y)
    lcd.drawLine(right - r, y, right, y + r)
    lcd.drawLine(right, y + r, right, bottom - r)
    lcd.drawLine(right, bottom - r, right - r, bottom)
    lcd.drawLine(right - r, bottom, x + r, bottom)
    lcd.drawLine(x + r, bottom, x, bottom - r)
    lcd.drawLine(x, bottom - r, x, y + r)
    lcd.drawLine(x, y + r, x + r, y)
end

-- The native radio theme's ellipse crest, expressed as a fixed 40-segment arc.
local HALO_UNITS = {}
for i = 0, 40 do
    local u = -1 + i / 20
    HALO_UNITS[i * 2 + 1] = u
    HALO_UNITS[i * 2 + 2] = 1 - math.sqrt(max(0, 1 - u * u))
end
function M.halo(c, x, y, w, h, color)
    local g = c._halo
    if not g then g = {points={}}; c._halo = g end
    if g.x ~= x or g.y ~= y or g.w ~= w or g.h ~= h then
        g.x, g.y, g.w, g.h = x, y, w, h
        for i = 1, #HALO_UNITS, 2 do
            g.points[i] = floor(x + w / 2 + HALO_UNITS[i] * w / 2)
            g.points[i + 1] = floor(y + HALO_UNITS[i + 1] * h)
        end
    end
    local p = g.points
    -- Two fixed dim falloff bands soften the same cached crest; no animation.
    lcd.color(HALO_OUTER)
    for i = 1, #p - 2, 2 do
        lcd.drawLine(p[i], p[i + 1] - 2, p[i + 2], p[i + 3] - 2)
        lcd.drawLine(p[i], p[i + 1] + 2, p[i + 2], p[i + 3] + 2)
    end
    lcd.color(HALO_INNER)
    for i = 1, #p - 2, 2 do
        lcd.drawLine(p[i], p[i + 1] - 1, p[i + 2], p[i + 3] - 1)
        lcd.drawLine(p[i], p[i + 1] + 1, p[i + 2], p[i + 3] + 1)
    end
    lcd.color(color or C.cyan)
    for i = 1, #p - 2, 2 do lcd.drawLine(p[i], p[i + 1], p[i + 2], p[i + 3]) end
end

function M.rail(x, y, w, value, maximum, color)
    lcd.color(C.line)
    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), 2)
    if value ~= nil then
        lcd.color(color or C.cyan)
        lcd.drawFilledRectangle(floor(x), floor(y), floor(w * max(0, min(1, value / max(1, maximum)))), 2)
    end
end

function M.title(c, x, y, w, right)
    M.text(c, "_brand", x, y, w * 0.5, 24, "INK & HALO", "FONT_S", C.cyan, "left")
    M.text(c, "_phase", x + w * 0.5, y, w * 0.5, 24, right, "FONT_XXS", C.muted, "right")
end

return M
