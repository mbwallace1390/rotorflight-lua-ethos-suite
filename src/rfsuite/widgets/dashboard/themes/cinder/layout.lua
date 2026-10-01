-- Cinder: asymmetric instruments, etched copper and warm cream. GPLv3.
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local D = requireModule("widgets/dashboard/themes/cinder/common.lua")
local C = D.colors
local lcd, floor = lcd, math.floor
local M = {}

local function begin(c, x, y, w, h, phase)
    lcd.color(C.bg)
    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))
    D.title(c, x + 12, y + 3, w - 24, phase)
    local g = c.geometry
    if not g then g = {}; c.geometry = g end
    if g.x ~= x or g.y ~= y or g.w ~= w or g.h ~= h then
        g.x, g.y, g.w, g.h = x, y, w, h
        g.compact = h < 340
        g.left, g.top = x + 12, y + 34
        g.gap = g.compact and 8 or 10
        g.heroW = floor((w - 24 - g.gap) * 0.57)
        g.right = g.left + g.heroW + g.gap
        g.rightW = w - 24 - g.heroW - g.gap
        g.heroH = h - 34 - (g.compact and 37 or 47)
        g.cardH = (g.heroH - g.gap * 3) / 4
        g.footerY = g.top + g.heroH + (g.compact and 8 or 12)
        g.footerH = y + h - g.footerY - 5
    end
    return g
end

local function readout(c, slot, x, y, w, h, label, value, color, barValue, barTop)
    local card = c[slot]
    if not card then card = {}; c[slot] = card end
    D.panel(x, y, w, h)
    local compact = h < 66
    local pad = compact and 12 or 17
    D.text(card, "label", x + pad, y + 5, w * 0.48 - pad, h - 17,
        label, "FONT_XS", C.muted)
    D.text(card, "value", x + w * 0.38, y + 3, w * 0.62 - pad, h - 15,
        value, compact and "FONT_L" or "FONT_XL", color or C.white, "right")
    if barTop then
        -- Normal thermal fill keeps the copper etch; warnings retain their semantic color.
        D.bar(x + pad, y + h - 11, w - pad * 2, barValue, barTop,
            color == C.white and C.copper or color or C.copper)
    else
        lcd.color(C.edge)
        lcd.drawLine(floor(x + pad), floor(y + h - 9), floor(x + w - pad), floor(y + h - 9))
    end
end

local function footerItem(c, slot, x, y, w, h, label, value, color)
    local item = c[slot]
    if not item then item = {}; c[slot] = item end
    D.text(item, "label", x + 4, y, w * 0.35, h, label, "FONT_XXS", C.muted)
    D.text(item, "value", x + w * 0.35, y, w * 0.65 - 10, h,
        value, "FONT_S", color or C.white, "right")
end

local function footer(c, g, historical)
    local x, y, w, h = g.left, g.footerY, g.w - 24, g.footerH
    local third = w / 3
    lcd.color(C.edge)
    lcd.drawLine(floor(x), floor(y + 4), floor(x + 7), floor(y - 3))
    lcd.drawLine(floor(x + 7), floor(y - 3), floor(x + w - 7), floor(y - 3))
    lcd.drawLine(floor(x + w - 7), floor(y - 3), floor(x + w), floor(y + 4))
    lcd.drawLine(floor(x + third), floor(y + 4), floor(x + third), floor(y + h - 4))
    lcd.drawLine(floor(x + third * 2), floor(y + 4), floor(x + third * 2), floor(y + h - 4))
    footerItem(c, "footer1", x + 4, y, third - 10, h,
        historical and "AVG A" or "USED", historical and c.averageCurrentText or c.consumedText)
    footerItem(c, "footer2", x + third + 12, y, third - 20, h,
        historical and "MIN BEC" or "BEC", c.becText, c.becColor)
    footerItem(c, "footer3", x + third * 2 + 12, y, third - 20, h,
        historical and "MIN LINK" or "LINK", c.linkText, c.linkColor)
end

local function stateStrip(c, x, y, w, text, color)
    D.text(c, "state", x + 16, y, w - 32, 24, text, "FONT_XS", color, "center")
    lcd.color(C.edge)
    lcd.drawLine(floor(x + 18), floor(y + 27), floor(x + w - 18), floor(y + 27))
end

function M.inflight(x, y, w, h, c)
    local g = begin(c, x, y, w, h, "INFLIGHT")
    local left, top, width, height = g.left, g.top, g.heroW, g.heroH
    local compact = g.compact
    D.panel(left, top, width, height, true)
    D.text(c, "rpmLabel", left + 24, top + (compact and 10 or 22), width - 48, 22,
        "HEADSPEED", "FONT_XS", C.muted)
    D.text(c, "rpmValue", left + 24, top + (compact and 33 or 53), width - 48,
        compact and 62 or 109, c.rpmText, "FONT_XXXXL", c.rpm == nil and C.muted or C.white)
    D.text(c, "rpmUnit", left + 24, top + (compact and 90 or 149), width - 48, 20,
        "RPM", "FONT_XS", C.muted)
    stateStrip(c, left, top + (compact and 113 or 183), width, c.flightState, c.flightStateColor)
    D.text(c, "timeLabel", left + 24, top + (compact and 150 or 234), width - 48, 18,
        "FLIGHT TIME", "FONT_XS", C.muted)
    D.text(c, "time", left + 24, top + (compact and 171 or 259), width - 48,
        compact and 44 or 66, c.timer, compact and "FONT_XL" or "FONT_XXXXL", C.white)
    readout(c, "fuelCard", g.right, top, g.rightW, g.cardH, "FUEL", c.fuelText, c.fuelColor, c.fuel, 100)
    readout(c, "escCard", g.right, top + g.cardH + g.gap, g.rightW, g.cardH,
        "ESC TEMP", c.escText, c.escColor, c.escBar, 200)
    readout(c, "currentCard", g.right, top + (g.cardH + g.gap) * 2, g.rightW, g.cardH,
        "CURRENT", c.currentText)
    readout(c, "packCard", g.right, top + (g.cardH + g.gap) * 3, g.rightW, g.cardH,
        "PACK", c.voltageText)
    footer(c, g, false)
end

function M.preflight(x, y, w, h, c)
    local g = begin(c, x, y, w, h, "PREFLIGHT")
    local left, top, width, height = g.left, g.top, g.heroW, g.heroH
    local compact = g.compact
    D.panel(left, top, width, height, true)
    D.text(c, "checkLabel", left + 22, top + (compact and 12 or 27), width - 44, 24,
        "TELEMETRY CHECK", "FONT_XS", C.muted)
    D.text(c, "status", left + 22, top + (compact and 45 or 79), width - 44,
        compact and 38 or 56, c.status, "FONT_XL", c.statusColor)
    D.text(c, "coverage", left + 22, top + (compact and 86 or 143), width - 44, 24,
        c.coverage, "FONT_XS", C.white)
    D.text(c, "issue", left + 22, top + (compact and 116 or 178), width - 44, 24,
        c.issue, "FONT_XS", c.issues > 0 and C.amber or C.muted)
    stateStrip(c, left, top + (compact and 149 or 240), width, c.flightState, c.flightStateColor)
    D.text(c, "checkScope", left + 22, top + height - 31, width - 44, 19,
        "TELEMETRY CHECKS ONLY", "FONT_XXS", C.muted)
    readout(c, "fuelCard", g.right, top, g.rightW, g.cardH, "FUEL", c.fuelText, c.fuelColor, c.fuel, 100)
    readout(c, "escCard", g.right, top + g.cardH + g.gap, g.rightW, g.cardH,
        "ESC TEMP", c.escText, c.escColor, c.escBar, 200)
    readout(c, "becCard", g.right, top + (g.cardH + g.gap) * 2, g.rightW, g.cardH,
        "BEC", c.becText, c.becColor)
    readout(c, "packCard", g.right, top + (g.cardH + g.gap) * 3, g.rightW, g.cardH,
        "PACK", c.voltageText)
    footer(c, g, false)
end

function M.postflight(x, y, w, h, c)
    local g = begin(c, x, y, w, h, "POSTFLIGHT / RECORDED")
    local left, top, width, height = g.left, g.top, g.heroW, g.heroH
    local compact = g.compact
    D.panel(left, top, width, height, true)
    D.text(c, "timeLabel", left + 24, top + (compact and 12 or 25), width - 48, 22,
        "FLIGHT DURATION", "FONT_XS", C.muted)
    D.text(c, "time", left + 24, top + (compact and 39 or 60), width - 48,
        compact and 61 or 90, c.timer, "FONT_XXXXL", C.white)
    stateStrip(c, left, top + (compact and 107 or 184), width,
        c.recorded and "RECORDED TELEMETRY" or "NO RECORDED TELEMETRY", c.recorded and C.copper or C.muted)
    D.text(c, "usedLabel", left + 24, top + (compact and 144 or 236), width - 48, 20,
        "CAPACITY USED", "FONT_XS", C.muted)
    D.text(c, "used", left + 24, top + (compact and 169 or 263), width - 48,
        compact and 41 or 53, c.consumedText, compact and "FONT_L" or "FONT_XL", C.white)
    readout(c, "fuelCard", g.right, top, g.rightW, g.cardH, "MIN FUEL", c.fuelText, c.fuelColor, c.fuel, 100)
    readout(c, "escCard", g.right, top + g.cardH + g.gap, g.rightW, g.cardH,
        "PEAK ESC", c.escText, c.escColor, c.escBar, 200)
    readout(c, "currentCard", g.right, top + (g.cardH + g.gap) * 2, g.rightW, g.cardH,
        "PEAK AMPS", c.currentText)
    readout(c, "cellCard", g.right, top + (g.cardH + g.gap) * 3, g.rightW, g.cardH,
        "MIN CELL", c.cellText)
    footer(c, g, true)
end

return M
