-- Meridian: small native LCD helpers, owned by this theme only. GPLv3.
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local utils = requireModule("widgets/dashboard/context.lua").widgets.dashboard.utils
local lcd, floor, min, max = lcd, math.floor, math.min, math.max
local M = {}
M.colors = {
    bg = lcd.RGB(3, 12, 18), panel = lcd.RGB(5, 17, 24), panel2 = lcd.RGB(12, 29, 39),
    white = lcd.RGB(232, 245, 255), cyan = lcd.RGB(127, 222, 240), muted = lcd.RGB(170, 197, 217),
    line = lcd.RGB(24, 52, 67), line2 = lcd.RGB(55, 106, 127),
    green = lcd.RGB(132, 224, 182), amber = lcd.RGB(244, 185, 94), red = lcd.RGB(255, 115, 125),
}
local C = M.colors
local FONT_FALLBACK = {FONT_XXXXL="FONT_XXL", FONT_XXL="FONT_XL", FONT_XL="FONT_L", FONT_L="FONT_STD", FONT_STD="FONT_S", FONT_S="FONT_XS", FONT_XS="FONT_XXS"}

-- One bounded cache per text slot; unchanged paints never measure again.
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
    local cut = min(9, floor(w / 2), floor(h / 2))
    local right, bottom = x + w - 1, y + h - 1
    lcd.color(C.panel)
    lcd.drawFilledRectangle(x + cut, y, w - cut * 2, h)
    lcd.drawFilledRectangle(x, y + cut, w, h - cut * 2)
    lcd.color(accent or C.cyan)
    lcd.drawLine(x + cut, y, right - cut, y)
    lcd.drawLine(right - cut, y, right, y + cut)
    lcd.drawLine(right, y + cut, right, bottom - cut)
    lcd.drawLine(right, bottom - cut, right - cut, bottom)
    lcd.drawLine(right - cut, bottom, x + cut, bottom)
    lcd.drawLine(x + cut, bottom, x, bottom - cut)
    lcd.drawLine(x, bottom - cut, x, y + cut)
    lcd.drawLine(x, y + cut, x + cut, y)
end

-- Fixed tick count and cached labels; values only change the rail's fill height.
function M.rail(c, x, y, w, h, value, low, high, steps, color, warning)
    if c.low ~= low or c.high ~= high or c.steps ~= steps then
        c.low, c.high, c.steps = low, high, steps
        c.labels = c.labels or {}
        for i = 0, steps do c.labels[i + 1] = tostring(floor(low + (high - low) * i / steps + 0.5)) end
    end
    local railX, railW = floor(x + w * 0.49), max(12, floor(w * 0.20))
    local top, height = floor(y + 8), max(12, floor(h - 16))
    lcd.color(C.line)
    lcd.drawFilledRectangle(railX, top, railW, height)
    if value ~= nil then
        local filled = floor(height * max(0, min(1, (value - low) / max(1, high - low))))
        lcd.color(color)
        lcd.drawFilledRectangle(railX + 2, top + height - filled, railW - 4, filled)
    end
    -- Twenty segments echo the approved concept without a per-frame point table.
    lcd.color(C.panel)
    for i = 1, 19 do
        local gy = top + floor(height * i / 20)
        lcd.drawLine(railX + 1, gy, railX + railW - 2, gy)
    end
    lcd.color(C.line2)
    lcd.drawRectangle(railX, top, railW, height)
    for i = 0, steps do
        local ty = top + floor(height * (1 - i / steps))
        lcd.color(C.cyan)
        lcd.drawLine(railX - 9, ty, railX - 3, ty)
        M.text(c, i + 1, x, ty - 7, railX - x - 14, 14, c.labels[i + 1], "FONT_XXS", C.muted, "right")
    end
    if warning ~= nil then
        local wy = top + floor(height * (1 - max(0, min(1, (warning - low) / max(1, high - low)))))
        lcd.color(C.amber)
        lcd.drawLine(railX - 2, wy, railX + railW + 7, wy)
        lcd.drawLine(railX - 2, wy + 1, railX + railW + 7, wy + 1)
    end
end

return M
