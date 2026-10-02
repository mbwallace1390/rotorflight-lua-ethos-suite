-- Ink & Halo instrument layouts. Geometry and text caches belong to each box.
-- GPLv3
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local D = requireModule("widgets/dashboard/themes/inkhalo/common.lua")
local C = D.colors
local lcd, floor, min = lcd, math.floor, math.min
local M = {}
local EMPTY = {text="--", color=C.muted}

local function begin(c, x, y, w, h, phase)
    lcd.color(C.bg)
    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))
    D.title(c, x + 12, y + 4, w - 24, phase)
end

local function tile(c, slot, x, y, w, h, label, value, color, secondary, rail, maximum)
    local t = c[slot]
    if not t then t = {}; c[slot] = t end
    D.surface(x, y, w, h)
    D.text(t, "label", x + 12, y + 7, w - 24, 18, label, "FONT_XXS", C.muted, "left")
    D.text(t, "value", x + 12, y + 27, w - 24, h - 54, value, h < 110 and "FONT_L" or "FONT_XL", color, "left")
    if secondary then D.text(t, "secondary", x + 12, y + h - 25, w - 24, 16, secondary, "FONT_XXS", C.muted, "left") end
    if maximum then D.rail(x + 12, y + h - 7, w - 24, rail, maximum, color) end
end

function M.preflight(x, y, w, h, c)
    begin(c, x, y, w, h, "PRE-FLIGHT / TELEMETRY CHECK")
    local compact = h < 340
    local pad, gap, top = 12, 10, 34
    local heroH = compact and 126 or 212
    local heroY, heroW = y + top, w - pad * 2
    D.surface(x + pad, heroY, heroW, heroH)
    local arcW = min(460, heroW * 0.66)
    D.halo(c, x + (w - arcW) / 2, heroY + 12, arcW, compact and 22 or 40, C.cyan)
    D.text(c, "_prepare", x + pad + 16, heroY + (compact and 38 or 60), heroW - 32, 18, "PREPARE TO FLY", "FONT_XXS", C.muted, "center")
    local status = c.status == "READY" and "TELEMETRY READY" or c.status or "WAITING"
    D.text(c, "_status", x + pad + 16, heroY + (compact and 58 or 82), heroW - 32, compact and 34 or 58, status, compact and "FONT_XL" or "FONT_XXL", c.statusColor or C.muted, "center")
    D.text(c, "_statusSub", x + pad + 16, heroY + heroH - (compact and 25 or 49), heroW - 32, 18, c.statusSub or "CONNECT TELEMETRY", "FONT_XXS", C.muted, "center")
    if not compact then
        D.text(c, "_signals", x + pad + 16, heroY + heroH - 25, heroW - 32, 16, c.issueText or c.signalText or "0 / 5 SIGNALS", "FONT_XXS", C.muted, "center")
    end
    local cardY = heroY + heroH + gap
    local cardH = y + h - pad - cardY
    local cardW = (heroW - gap * 4) / 5
    local pack = c.voltage == nil and C.muted or (c.voltage <= 0 and C.red or C.white)
    local fuel = c.fuel == nil and C.muted or (c.fuel <= (c.fuelWarn or 25) and C.red or C.green)
    local bec = c.bec == nil and C.muted or (c.bec < (c.becMin or 6.5) and C.red or (c.bec < (c.becWarn or 7) and C.amber or C.white))
    local esc = c.esc == nil and C.muted or (c.esc >= (c.escMax or 150) and C.red or (c.esc >= (c.escWarn or 110) and C.amber or C.white))
    local link = c.link == nil and C.muted or (c.link < (c.linkWarn or 50) and C.amber or C.white)
    local cardX = x + pad
    tile(c, "_packCard", cardX, cardY, cardW, cardH, "PACK", c.voltageText, pack, "LIVE VOLTAGE")
    tile(c, "_fuelCard", cardX + cardW + gap, cardY, cardW, cardH, "SMART FUEL", c.fuelText, fuel, "RESERVE", c.fuel, 100)
    tile(c, "_becCard", cardX + (cardW + gap) * 2, cardY, cardW, cardH, "BEC", c.becText, bec, "SUPPLY")
    tile(c, "_escCard", cardX + (cardW + gap) * 3, cardY, cardW, cardH, "ESC TEMP", c.escText, esc, "THERMAL")
    tile(c, "_linkCard", cardX + (cardW + gap) * 4, cardY, cardW, cardH, "LINK", c.linkText, link, "QUALITY", c.link, 100)
end

function M.inflight(x, y, w, h, c)
    begin(c, x, y, w, h, "IN-FLIGHT / LIVE TELEMETRY")
    local compact = h < 340
    local pad, gap, top = 12, 10, 34
    local cardH = compact and 92 or 132
    local heroW, heroY = w - pad * 2, y + top
    local heroH = h - top - cardH - gap - pad
    D.surface(x + pad, heroY, heroW, heroH)
    local arcW = min(550, heroW * 0.75)
    D.halo(c, x + (w - arcW) / 2, heroY + 12, arcW, compact and 24 or 52, C.cyan)
    local rpmColor = c.rpm == nil and C.muted or (c.rpm > (c.rpmMax or 3000) and C.red or C.white)
    local labelY = heroY + (compact and 40 or 72)
    D.text(c, "_rpmTitle", x + w * 0.26, labelY, w * 0.48, 18, "HEADSPEED", "FONT_XXS", C.muted, "center")
    D.text(c, "_rpmValue", x + w * 0.26, labelY + 17, w * 0.48, compact and 48 or 74, c.rpmText, compact and "FONT_XXL" or "FONT_XXXXL", rpmColor, "center")
    D.text(c, "_rpmUnit", x + w * 0.40, labelY + (compact and 63 or 91), w * 0.20, 16, "RPM", "FONT_XXS", C.muted, "center")
    D.text(c, "_state", x + w * 0.25, heroY + heroH - 25, w * 0.5, 18, c.flightState or "STATE --", "FONT_XXS", c.flightStateColor or C.muted, "center")
    D.text(c, "_timeTitle", x + pad + 16, heroY + heroH - 55, heroW * 0.22, 16, "FLIGHT TIME", "FONT_XXS", C.muted, "left")
    D.text(c, "_time", x + pad + 16, heroY + heroH - 37, heroW * 0.22, 26, c.timer or "00:00", "FONT_STD", C.white, "left")
    D.text(c, "_rpmMax", x + w * 0.74, heroY + heroH - 52, w * 0.26 - pad - 16, 18, c.maxRpmText or "MAX --", "FONT_XXS", C.muted, "right")
    D.text(c, "_rpmLimit", x + w * 0.74, heroY + heroH - 30, w * 0.26 - pad - 16, 18, c.rpmLimitText or "LIMIT --", "FONT_XXS", C.muted, "right")
    local cardW, cardY = (heroW - gap * 3) / 4, heroY + heroH + gap
    local fuel = c.fuel == nil and C.muted or (c.fuel <= (c.fuelWarn or 25) and C.red or C.green)
    local esc = c.esc == nil and C.muted or (c.esc >= (c.escMax or 150) and C.red or (c.esc >= (c.escWarn or 110) and C.amber or C.white))
    tile(c, "_fuelCard", x + pad, cardY, cardW, cardH, "SMART FUEL", c.fuelText, fuel, c.usedText, c.fuel, 100)
    tile(c, "_escCard", x + pad + cardW + gap, cardY, cardW, cardH, "ESC TEMP", c.escText, esc, c.escWarnText)
    tile(c, "_currentCard", x + pad + (cardW + gap) * 2, cardY, cardW, cardH, "CURRENT", c.currentText, c.current == nil and C.muted or C.white, c.throttleLabelText)
    tile(c, "_packCard", x + pad + (cardW + gap) * 3, cardY, cardW, cardH, "PACK", c.voltageText, c.voltage == nil and C.muted or C.white, c.linkLabelText or "LINK --")
end

local function metric(c, index)
    return c.metrics and c.metrics[index] or EMPTY
end

local function reportTile(c, slot, x, y, w, h, label, primary, secondaryLabel, secondary)
    local t = c[slot]
    if not t then t = {}; c[slot] = t end
    D.surface(x, y, w, h)
    D.text(t, "label", x + 12, y + 6, w * 0.42 - 18, h - 12, label, "FONT_XXS", C.muted, "left")
    D.text(t, "primary", x + w * 0.42, y + 6, w * 0.58 - 12, h * 0.54, primary.text, h < 75 and "FONT_S" or "FONT_L", primary.color, "right")
    D.text(t, "secondaryLabel", x + w * 0.42, y + h - 21, w * 0.25, 15, secondaryLabel, "FONT_XXS", C.muted, "left")
    D.text(t, "secondary", x + w * 0.68, y + h - 21, w * 0.32 - 12, 15, secondary.text, "FONT_XXS", secondary.color, "right")
end

function M.postflight(x, y, w, h, c)
    begin(c, x, y, w, h, c.recorded and "POST-FLIGHT / RECORDED DATA" or "POST-FLIGHT / NO RECORDED TELEMETRY")
    local compact = h < 340
    local pad, gap, top = 12, 10, 34
    local heroW, heroY = w - pad * 2, y + top
    local heroH = compact and 98 or 172
    D.surface(x + pad, heroY, heroW, heroH)
    local arcW = min(380, heroW * 0.48)
    D.halo(c, x + (w - arcW) / 2, heroY + 10, arcW, compact and 18 or 34, C.cyan)
    D.text(c, "_timeTitle", x + w * 0.29, heroY + (compact and 33 or 55), w * 0.42, 18, "FLIGHT DURATION", "FONT_XXS", C.muted, "center")
    D.text(c, "_time", x + w * 0.29, heroY + (compact and 54 or 80), w * 0.42, compact and 32 or 64, c.time or "--:--", compact and "FONT_L" or "FONT_XXL", C.white, "center")
    D.text(c, "_rpmTitle", x + pad + 16, heroY + (compact and 18 or 45), heroW * 0.25, 18, "PEAK HEADSPEED", "FONT_XXS", C.muted, "left")
    D.text(c, "_rpm", x + pad + 16, heroY + (compact and 42 or 72), heroW * 0.25, compact and 28 or 48, metric(c, 1).text, compact and "FONT_L" or "FONT_XL", metric(c, 1).color, "left")
    D.text(c, "_rpmUnit", x + pad + 16, heroY + heroH - 22, heroW * 0.25, 16, "RPM / RECORDED MAX", "FONT_XXS", C.muted, "left")
    D.text(c, "_fuelTitle", x + w * 0.75, heroY + (compact and 18 or 45), w * 0.25 - pad - 16, 18, "MINIMUM FUEL", "FONT_XXS", C.muted, "right")
    D.text(c, "_fuel", x + w * 0.75, heroY + (compact and 42 or 72), w * 0.25 - pad - 16, compact and 28 or 48, metric(c, 10).text, compact and "FONT_L" or "FONT_XL", metric(c, 10).color, "right")
    local cardY, cardW = heroY + heroH + gap, (heroW - gap) / 2
    local cardH = (y + h - 40 - cardY - gap) / 2
    reportTile(c, "_currentReport", x + pad, cardY, cardW, cardH, "PEAK CURRENT", metric(c, 3), "AVG", metric(c, 4))
    reportTile(c, "_escReport", x + pad + cardW + gap, cardY, cardW, cardH, "PEAK ESC TEMP", metric(c, 5), "PEAK POWER", metric(c, 11))
    reportTile(c, "_packReport", x + pad, cardY + cardH + gap, cardW, cardH, "MINIMUM CELL", metric(c, 9), "USED", metric(c, 8))
    reportTile(c, "_linkReport", x + pad + cardW + gap, cardY + cardH + gap, cardW, cardH, "MINIMUM LINK", metric(c, 7), "MIN BEC", metric(c, 6))
    D.text(c, "_countLabel", x + pad, y + h - 31, 134, 20, "RECORDED FLIGHTS", "FONT_XXS", C.muted, "left")
    D.text(c, "_count", x + pad + 136, y + h - 31, 70, 20, c.count or "--", "FONT_XS", C.white, "left")
    D.text(c, "_totalLabel", x + w - 310, y + h - 31, 128, 20, "TOTAL AIRTIME", "FONT_XXS", C.muted, "right")
    D.text(c, "_total", x + w - 174, y + h - 31, 162, 20, c.total or "--:--", "FONT_XS", C.white, "right")
end

return M
