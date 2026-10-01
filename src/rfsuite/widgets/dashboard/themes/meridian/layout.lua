-- Meridian's twin rails and continuous instrument strip. GPLv3.
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local D = requireModule("widgets/dashboard/themes/meridian/common.lua")
local C = D.colors
local lcd, floor, min = lcd, math.floor, math.min
local M = {}
local EMPTY = {text="--", color=C.muted}

local function slot(c, name)
    local view = c._view
    if not view then view = {}; c._view = view end
    local value = view[name]
    if not value then value = {}; view[name] = value end
    return value
end

local function begin(c, x, y, w, h, phase)
    lcd.color(C.bg)
    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))
    D.text(c, "brand", x + 14, y + 2, 166, 24, "M E R I D I A N", "FONT_XS", C.cyan, "left")
    D.text(c, "phase", x + w - 208, y + 2, 194, 24, phase, "FONT_XXS", C.cyan, "right")
    lcd.color(C.line2)
    lcd.drawLine(floor(x + 174), floor(y + 14), floor(x + w - 210), floor(y + 14))
end

local function railPanel(c, name, x, y, w, h, title, text, value, low, high, steps, color, note, warning)
    local r = slot(c, name)
    local compact = h < 250
    -- Keep native 12px tick labels separated on the shorter compact rails.
    if compact then steps = steps == 5 and 2 or 3 end
    D.surface(x, y, w, h)
    D.text(r, "title", x + 7, y + 9, w - 14, 18, title, "FONT_XS", C.muted, "center")
    D.text(r, "value", x + 7, y + 31, w - 14, compact and 38 or 52, text, compact and "FONT_L" or "FONT_XXL", value == nil and C.muted or color, "center")
    local railY = y + (compact and 73 or 89)
    D.rail(slot(r, "axis"), x + 14, railY, w - 28, y + h - 28 - railY, value, low, high, steps, color, warning)
    D.text(r, "note", x + 7, y + h - 24, w - 14, 17, note, "FONT_XXS", warning and C.amber or C.muted, "center")
end

local function stripItem(c, name, x, y, w, h, title, text, color, divider)
    local item = slot(c, name)
    D.text(item, "title", x + 8, y + 6, w - 16, 17, title, "FONT_XXS", C.muted, "center")
    D.text(item, "value", x + 8, y + 25, w - 16, h - 29, text, h < 62 and "FONT_STD" or "FONT_XL", color or C.white, "center")
    if divider then
        lcd.color(C.line2)
        lcd.drawLine(floor(x), floor(y + 12), floor(x), floor(y + h - 10))
    end
end

local function liveRails(c, x, y, w, h, side)
    local fuelColor = c.fuel == nil and C.muted or (c.fuel <= (c.fuelWarn or 25) and C.amber or C.green)
    local escColor = c.esc == nil and C.muted or (c.esc >= (c.escMax or 120) and C.red or (c.esc >= (c.escWarn or 110) and C.amber or C.cyan))
    railPanel(c, "fuelRail", x, y, side, h, "FUEL", c.fuelText, c.fuel, 0, 100, 5, fuelColor, c.usedText or "LIVE RESERVE")
    railPanel(c, "escRail", x + w - side, y, side, h, "ESC TEMP", c.escText, c.esc, c.escUnit == "°F" and 32 or 0, c.escMax or 120, 6, escColor, c.escWarnText or "THERMAL", c.escWarn)
end

function M.inflight(x, y, w, h, c)
    begin(c, x, y, w, h, "IN-FLIGHT")
    local compact = h < 340
    local pad, gap, top = 12, 10, 32
    local stripH, side = compact and 58 or 68, floor(w * 0.20)
    local bodyY, bodyH, bodyW = y + top, h - top - stripH - gap - pad, w - pad * 2
    liveRails(c, x + pad, bodyY, bodyW, bodyH, side)
    local centerX, centerW = x + pad + side + gap, bodyW - 2 * (side + gap)
    local labelY = bodyY + (compact and 15 or 39)
    D.text(c, "rpmTitle", centerX, labelY, centerW, 25, "HEADSPEED", "FONT_S", C.muted, "center")
    D.text(c, "rpm", centerX, labelY + 29, centerW, compact and 70 or 100, c.rpmText, "FONT_XXXXL", c.rpm == nil and C.muted or C.white, "center")
    D.text(c, "rpmUnit", centerX, labelY + (compact and 104 or 134), centerW, 24, "RPM", "FONT_S", C.muted, "center")
    D.text(c, "flightState", centerX, bodyY + bodyH - 34, centerW, 24, c.flightState or "STATE --", "FONT_S", c.flightStateColor or C.muted, "center")
    local stripY, itemW = bodyY + bodyH + gap, bodyW / 4
    D.surface(x + pad, stripY, bodyW, stripH)
    stripItem(c, "time", x + pad, stripY, itemW, stripH, "FLIGHT TIME", c.timer or "--:--")
    stripItem(c, "current", x + pad + itemW, stripY, itemW, stripH, "CURRENT", c.currentText, nil, true)
    stripItem(c, "bec", x + pad + itemW * 2, stripY, itemW, stripH, "BEC", c.becText, c.becColor, true)
    stripItem(c, "link", x + pad + itemW * 3, stripY, itemW, stripH, "LINK", c.linkText, c.linkColor, true)
end

local function check(c, name, x, y, w, label, present)
    local r = slot(c, name)
    lcd.color(present and C.green or C.amber)
    lcd.drawRectangle(floor(x), floor(y + 5), 7, 7)
    if present then lcd.drawFilledRectangle(floor(x + 2), floor(y + 7), 3, 3) end
    D.text(r, "label", x + 17, y, w * 0.58 - 17, 18, label, "FONT_XXS", C.muted, "left")
    D.text(r, "state", x + w * 0.58, y, w * 0.42, 18, present and "PRESENT" or "MISSING", "FONT_XXS", present and C.green or C.amber, "right")
end

function M.preflight(x, y, w, h, c)
    begin(c, x, y, w, h, "PRE-FLIGHT")
    local compact = h < 340
    local pad, gap, top = 12, 10, 32
    local stripH, side = compact and 58 or 68, floor(w * 0.20)
    local bodyY, bodyH, bodyW = y + top, h - top - stripH - gap - pad, w - pad * 2
    liveRails(c, x + pad, bodyY, bodyW, bodyH, side)
    local centerX, centerW = x + pad + side + gap, bodyW - 2 * (side + gap)
    D.text(c, "prepare", centerX, bodyY + 5, centerW, 20, "TELEMETRY CHECK", "FONT_XS", C.muted, "center")
    local status = c.status == "READY" and "TELEMETRY READY" or c.status or "WAITING"
    D.text(c, "status", centerX, bodyY + 30, centerW, compact and 30 or 53, status, compact and "FONT_L" or "FONT_XL", c.statusColor or C.muted, "center")
    D.text(c, "statusSub", centerX + 4, bodyY + (compact and 64 or 89), centerW - 8, compact and 14 or 19, c.issueText or c.statusSub or "CONNECT TELEMETRY", "FONT_XXS", C.muted, "center")
    local step = compact and 19 or 30
    local rowY = bodyY + bodyH - step * 5 - (compact and 2 or 7)
    local rowX, rowW = centerX + centerW * 0.12, centerW * 0.76
    check(c, "checkPack", rowX, rowY, rowW, "PACK VOLTAGE", c.voltage ~= nil)
    check(c, "checkFuel", rowX, rowY + step, rowW, "FUEL", c.fuel ~= nil)
    check(c, "checkBec", rowX, rowY + step * 2, rowW, "BEC SUPPLY", c.bec ~= nil)
    check(c, "checkEsc", rowX, rowY + step * 3, rowW, "ESC TEMP", c.esc ~= nil)
    check(c, "checkLink", rowX, rowY + step * 4, rowW, "RADIO LINK", c.link ~= nil)
    local stripY, itemW = bodyY + bodyH + gap, bodyW / 4
    D.surface(x + pad, stripY, bodyW, stripH)
    stripItem(c, "pack", x + pad, stripY, itemW, stripH, "PACK", c.voltageText)
    stripItem(c, "bec", x + pad + itemW, stripY, itemW, stripH, "BEC", c.becText, c.becColor, true)
    stripItem(c, "link", x + pad + itemW * 2, stripY, itemW, stripH, "LINK", c.linkText, c.linkColor, true)
    stripItem(c, "signals", x + pad + itemW * 3, stripY, itemW, stripH, "TELEMETRY", c.signalText, nil, true)
end

local function metric(c, index)
    return c.metrics and c.metrics[index] or EMPTY
end

function M.postflight(x, y, w, h, c)
    begin(c, x, y, w, h, "POST-FLIGHT / RECORDED")
    local compact = h < 340
    local pad, gap, top = 12, 10, 32
    local stripH, side = compact and 58 or 68, floor(w * 0.20)
    local bodyY, bodyH, bodyW = y + top, h - top - stripH - gap - pad, w - pad * 2
    local fuel, esc = metric(c, 8), metric(c, 3)
    railPanel(c, "fuelRail", x + pad, bodyY, side, bodyH, "MIN FUEL", fuel.text, fuel.value, 0, 100, 5, fuel.color, "RECORDED MIN")
    railPanel(c, "escRail", x + pad + bodyW - side, bodyY, side, bodyH, "PEAK ESC TEMP", esc.text, esc.value, c.escUnit == "°F" and 32 or 0, c.escMax or 120, 6, esc.color, "RECORDED PEAK")
    local centerX, centerW = x + pad + side + gap, bodyW - 2 * (side + gap)
    D.text(c, "timeTitle", centerX, bodyY + (compact and 7 or 24), centerW, 24, "FLIGHT DURATION", "FONT_S", C.muted, "center")
    D.text(c, "duration", centerX, bodyY + (compact and 36 or 57), centerW, compact and 58 or 90, c.time or "--:--", "FONT_XXXXL", C.white, "center")
    D.text(c, "recorded", centerX, bodyY + (compact and 88 or 162), centerW, 18, c.recorded and "RECORDED TELEMETRY" or "NO RECORDED TELEMETRY", "FONT_XXS", c.recorded and C.cyan or C.muted, "center")
    D.text(c, "used", centerX, bodyY + bodyH - (compact and 66 or 99), centerW, 18, c.usedText or "USED --", "FONT_XS", C.muted, "center")
    D.text(c, "count", centerX, bodyY + bodyH - (compact and 45 or 67), centerW, 18, c.countText or "FLIGHTS --", "FONT_XXS", C.muted, "center")
    D.text(c, "total", centerX, bodyY + bodyH - (compact and 24 or 35), centerW, 18, c.totalText or "TOTAL --:--", "FONT_XXS", C.muted, "center")
    local stripY, itemW = bodyY + bodyH + gap, bodyW / 4
    D.surface(x + pad, stripY, bodyW, stripH)
    stripItem(c, "cell", x + pad, stripY, itemW, stripH, "MIN CELL", metric(c, 7).text, metric(c, 7).color)
    stripItem(c, "current", x + pad + itemW, stripY, itemW, stripH, "PEAK CURRENT", metric(c, 1).text, metric(c, 1).color, true)
    stripItem(c, "bec", x + pad + itemW * 2, stripY, itemW, stripH, "MIN BEC", metric(c, 4).text, metric(c, 4).color, true)
    stripItem(c, "link", x + pad + itemW * 3, stripY, itemW, stripH, "MIN LINK", metric(c, 5).text, metric(c, 5).color, true)
end

return M
