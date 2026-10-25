-- Cinder drawing primitives. All per-instrument caches belong to the caller. GPLv3.
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local utils = requireModule("widgets/dashboard/context.lua").widgets.dashboard.utils
local lcd = lcd
local floor, min, max = math.floor, math.min, math.max
local M = {}
M.colors = {
    bg = lcd.RGB(12, 12, 11), panel = lcd.RGB(19, 18, 16), panel2 = lcd.RGB(31, 27, 23),
    white = lcd.RGB(242, 234, 215), muted = lcd.RGB(177, 164, 148),
    copper = lcd.RGB(224, 153, 101), line = lcd.RGB(64, 49, 38), edge = lcd.RGB(121, 85, 61),
    green = lcd.RGB(160, 208, 169), amber = lcd.RGB(233, 184, 108), red = lcd.RGB(239, 128, 117),
}
local C = M.colors
local SMALLER = {FONT_XXXXL="FONT_XXL", FONT_XXL="FONT_XL", FONT_XL="FONT_L", FONT_L="FONT_STD", FONT_STD="FONT_S", FONT_S="FONT_XS", FONT_XS="FONT_XXS"}

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
        while (tw > w or th > h) and SMALLER[name] do
            name = SMALLER[name]
            font = utils.resolveFont(name, nil)
            lcd.font(font)
            tw, th = lcd.getTextSize(text)
        end
        fit.font, fit.tw, fit.th = font, tw, th
    end
    local tx = x
    if align == "center" then tx = x + (w - fit.tw) / 2
    elseif align == "right" then tx = x + w - fit.tw end
    lcd.font(fit.font)
    lcd.color(color or C.white)
    lcd.drawText(floor(tx + 0.5), floor(y + (h - fit.th) / 2 + 0.5), text)
end

function M.panel(x, y, w, h, hero)
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    local cut = hero and 16 or 7
    cut = min(cut, floor(w / 4), floor(h / 4))
    local right, bottom = x + w - 1, y + h - 1
    lcd.color(C.panel)
    lcd.drawFilledRectangle(x + cut, y, w - cut * 2, h)
    lcd.drawFilledRectangle(x, y + cut, w, h - cut * 2)
    lcd.color(hero and C.copper or C.edge)
    lcd.drawLine(x + cut, y, right - cut, y)
    lcd.drawLine(right - cut, y, right, y + cut)
    lcd.drawLine(right, y + cut, right, bottom - cut)
    lcd.drawLine(right, bottom - cut, right - cut, bottom)
    lcd.drawLine(right - cut, bottom, x + cut, bottom)
    lcd.drawLine(x + cut, bottom, x, bottom - cut)
    lcd.drawLine(x, bottom - cut, x, y + cut)
    lcd.drawLine(x, y + cut, x + cut, y)
    if hero then
        -- Short double etch at opposing corners; fixed geometry, no texture assets.
        lcd.color(C.edge)
        lcd.drawLine(x + 4, y + cut + 4, x + cut + 4, y + 4)
        lcd.drawLine(x + cut + 4, y + 4, x + cut + 55, y + 4)
        lcd.drawLine(right - 4, bottom - cut - 4, right - cut - 4, bottom - 4)
        lcd.drawLine(right - cut - 4, bottom - 4, right - cut - 55, bottom - 4)
    end
end

function M.bar(x, y, w, value, upper, color)
    lcd.color(C.line)
    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), 4)
    if value ~= nil then
        local fill = floor(w * max(0, min(1, value / max(1, upper))))
        if fill > 0 then
            lcd.color(color)
            lcd.drawFilledRectangle(floor(x), floor(y), fill, 4)
        end
    end
end

function M.title(c, x, y, w, phase)
    M.text(c, "brand", x, y, 124, 24, "CINDER", "FONT_S", C.copper)
    lcd.color(C.edge)
    lcd.drawLine(floor(x + 125), floor(y + 18), floor(x + 132), floor(y + 11))
    lcd.drawLine(floor(x + 132), floor(y + 11), floor(x + w - 240), floor(y + 11))
    M.text(c, "phase", x + w - 228, y, 228, 24, phase, "FONT_XS", C.muted, "right")
end

return M
