-- Vantage / flight: graphite cockpit, live telemetry and a calibrated rotor dial.
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local rfsuite = requireModule("widgets/dashboard/context.lua")
local lcd = lcd
local math = math
local floor = math.floor
local min = math.min
local max = math.max
local sin = math.sin
local cos = math.cos
local rad = math.rad
local rawNumber = tonumber
local function tonumber(value)
    local number = rawNumber(value)
    if number and number == number and number > -math.huge and number < math.huge then return number end
    return nil
end
local tostring = tostring
local type = type
local format = string.format

local utils = rfsuite.widgets.dashboard.utils
local headeropts = utils.getHeaderOptions()
-- The Suite caches its native palette; each theme owns its presentation copy.
local colorMode = {}
for key, value in pairs(utils.themeColors()) do colorMode[key] = value end
local header_layout = utils.standardHeaderLayout(headeropts)
local header_boxes_cache = nil
local last_txbatt_type = nil
local C

local function header_boxes()
    local txbatt_type = 0
    if rfsuite and rfsuite.preferences and rfsuite.preferences.general then
        txbatt_type = rfsuite.preferences.general.txbatt_type or 0
    end

    if header_boxes_cache == nil or last_txbatt_type ~= txbatt_type then
        local boxes = utils.standardHeaderBoxes(i18n, colorMode, headeropts, txbatt_type)

        -- Replace the stock Rotorflight logo with the MWRC-style title while
        -- keeping the radio's native header surface and battery/RSSI widgets.
        for _, headerBox in ipairs(boxes) do
            if headerBox.subtype == "craftname" then headerBox.font = "FONT_S" end
            if headerBox.type == "image" then
                headerBox.type = "func"
                headerBox.subtype = "func"
                headerBox.bgcolor = "transparent"
                headerBox.paint = function(x, y, w, h)
                    lcd.color(C.panel)
                    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))
                    -- Fit the title beside a discreet builder signature, then reuse the measurements.
                    if headerBox._titleWidth ~= w then
                        local titleFont = utils.resolveFont("FONT_S", nil)
                        local markFont = utils.resolveFont("FONT_XXS", nil)
                        if type(titleFont) ~= "number" or type(markFont) ~= "number" then return end
                        lcd.font(markFont)
                        local mw, mh = lcd.getTextSize("| MWRC")
                        local available = w - 28 - mw
                        lcd.font(titleFont)
                        local tw, th = lcd.getTextSize("Rotorflight // Ethos")
                        if tw > available then
                            titleFont = utils.resolveFont("FONT_XS", nil) or titleFont
                            lcd.font(titleFont)
                            tw, th = lcd.getTextSize("Rotorflight // Ethos")
                        end
                        if tw > available then
                            titleFont = utils.resolveFont("FONT_XXS", nil) or titleFont
                            lcd.font(titleFont)
                            tw, th = lcd.getTextSize("Rotorflight // Ethos")
                        end
                        -- The complete header reads Rotorflight // Ethos | MWRC.
                        headerBox._titleWidth = w
                        headerBox._titleFont = titleFont
                        headerBox._titleHeight = th
                        headerBox._titleTextWidth = tw
                        headerBox._markFont = markFont
                        headerBox._markHeight = mh
                    end
                    lcd.font(headerBox._titleFont)
                    lcd.color(C.cyan)
                    lcd.drawText(floor(x + 10), floor(y + (h - headerBox._titleHeight) / 2), "Rotorflight // Ethos")
                    lcd.font(headerBox._markFont)
                    lcd.color(C.muted)
                    lcd.drawText(floor(x + 18 + headerBox._titleTextWidth), floor(y + (h - headerBox._markHeight) / 2), "| MWRC")
                end
            end
        end

        header_boxes_cache = boxes
        last_txbatt_type = txbatt_type
    end
    return header_boxes_cache
end

local DEFAULTS = {
    rpm_max = 3000,
    bec_min = 6.5,
    bec_warn = 7.0,
    esc_warn = 110,
    esc_max = 150,
    fuel_warn = 25,
    link_warn = 50
}

C = {
    bg = lcd.RGB(8, 14, 20),
    panel = lcd.RGB(17, 27, 36),
    panel2 = lcd.RGB(22, 35, 46),
    line = lcd.RGB(40, 59, 72),
    line2 = lcd.RGB(71, 97, 113),
    white = lcd.RGB(231, 242, 246),
    muted = lcd.RGB(130, 156, 170),
    cyan = lcd.RGB(137, 220, 241),
    green = lcd.RGB(98, 215, 159),
    amber = lcd.RGB(245, 185, 94),
    red = lcd.RGB(255, 105, 112),
    violet = lcd.RGB(124, 156, 207)
}

-- Keep telemetry contrast stable when the transmitter uses a light system theme.
colorMode.bgcolor = C.bg
colorMode.tbbgcolor = C.panel
colorMode.tbtextcolor = C.white
colorMode.cntextcolor = C.white
colorMode.rssitextcolor = C.white
colorMode.rssifillcolor = C.cyan or C.turquoise
colorMode.rssifillbgcolor = C.line
colorMode.txbgfillcolor = C.line
colorMode.txfillcolor = C.green or C.emerald

local function getThemeValue(key)
    -- The rewritten Suite binds preferences to the active dashboard theme.
    local value = tonumber(rfsuite.widgets.dashboard.getPreference(key))

    return value or DEFAULTS[key]
end

local function sensor(telemetry, name, alias1, alias2)
    telemetry = telemetry or (rfsuite.tasks and rfsuite.tasks.telemetry)
    if not (telemetry and telemetry.getSensor) then return nil end
    local value = tonumber((telemetry.getSensor(name)))
    if value ~= nil then return value end
    if alias1 then
        value = tonumber((telemetry.getSensor(alias1)))
        if value ~= nil then return value end
    end
    if alias2 then
        value = tonumber((telemetry.getSensor(alias2)))
        if value ~= nil then return value end
    end
    return nil
end

local function temperatureSensor(telemetry, warning, maximum)
    telemetry = telemetry or (rfsuite.tasks and rfsuite.tasks.telemetry)
    if not (telemetry and telemetry.getSensor) then
        return nil, "°C", warning, maximum
    end

    local value, _, unit, displayWarning, displayMaximum = telemetry.getSensor("temp_esc", warning, maximum)
    return tonumber(value), unit or "°C", tonumber(displayWarning) or warning, tonumber(displayMaximum) or maximum
end


local GOVERNOR_LABELS = {
    [0] = "OFF",
    [1] = "IDLE",
    [2] = "SPOOLUP",
    [3] = "RECOVERY",
    [4] = "ACTIVE",
    [5] = "THR OFF",
    [6] = "LOST HS",
    [7] = "AUTOROT",
    [8] = "BAILOUT",
    [100] = "GOV DISABLED",
    [101] = "DISARMED"
}

local GOVERNOR_COLORS = {
    [0] = C.amber,
    [1] = C.amber,
    [2] = C.red,
    [3] = C.amber,
    [4] = C.red,
    [5] = C.green,
    [6] = C.red,
    [7] = C.amber,
    [8] = C.red,
    [100] = C.muted,
    [101] = C.green
}

-- Armed labels are immutable; wakeup never concatenates governor text.
local ARMED_GOVERNOR_LABELS = {}
for code, label in pairs(GOVERNOR_LABELS) do
    ARMED_GOVERNOR_LABELS[code] = "ARMED / " .. label
end

local function getFlightState(telemetry)
    local armflags = sensor(telemetry, "armflags")
    local governor = sensor(telemetry, "governor")
    local armed = nil

    if rfsuite.utils and rfsuite.utils.armFlagsToIsArmed then
        armed = rfsuite.utils.armFlagsToIsArmed(armflags)
    end

    if armed == nil and armflags == nil and governor == nil then
        local session = rfsuite and rfsuite.session
        if session and session.telemetryState then armed = session.isArmed == true end
    end

    if armed == false then return "DISARMED", C.green end

    local governorCode = governor and floor(governor + 0.5) or nil
    local governorLabel = governorCode and GOVERNOR_LABELS[governorCode] or nil
    local governorColor = governorCode and GOVERNOR_COLORS[governorCode] or nil

    if governorCode == 101 then return "DISARMED", C.green end
    if armed == true then
        if governorLabel and governorCode ~= 100 then
            return ARMED_GOVERNOR_LABELS[governorCode], governorColor or C.red
        end
        return "ARMED", C.red
    end
    if governorLabel then return governorLabel, governorColor or C.cyan end
    return "STATE --", C.muted
end

local function fmt(value, decimals, suffix, missing)
    if value == nil then return missing or "--" end
    local text
    if decimals == 1 then
        text = format("%.1f", value)
    elseif decimals == 2 then
        text = format("%.2f", value)
    else
        text = tostring(floor(value + 0.5))
    end
    return text .. (suffix or "")
end

local function cacheText(c, textKey, valueKey, unitKey, value, decimals, suffix, prefix)
    suffix = suffix or ""
    local scale = decimals == 2 and 100 or (decimals == 1 and 10 or 1)
    value = value and floor(value * scale + 0.5) / scale or nil
    if c[valueKey] ~= value or c[unitKey] ~= suffix or c[textKey] == nil then
        c[valueKey] = value
        c[unitKey] = suffix
        c[textKey] = (prefix or "") .. fmt(value, decimals, suffix)
    end
end

local function resolveFont(name)
    return utils.resolveFont(name, nil)
end

local FONT_FALLBACK = {
    FONT_XXXXL = "FONT_XXL", FONT_XXL = "FONT_XL", FONT_XL = "FONT_L", FONT_L = "FONT_STD",
    FONT_STD = "FONT_S", FONT_S = "FONT_XS", FONT_XS = "FONT_XXS"
}

local function drawTextAligned(x, y, w, text, fontName, color, align)
    local font = resolveFont(fontName)
    if type(font) ~= "number" then return 0, 0 end
    lcd.font(font)
    lcd.color(color)
    local tw, th = lcd.getTextSize(text)
    -- Step down through native fonts when narrow cards cannot fit a reading.
    local nextFont = FONT_FALLBACK[fontName]
    while tw > w and nextFont do
        local smaller = resolveFont(nextFont)
        if type(smaller) == "number" then
            lcd.font(smaller)
            tw, th = lcd.getTextSize(text)
        end
        nextFont = FONT_FALLBACK[nextFont]
    end
    local tx = x
    if align == "center" then
        tx = x + (w - tw) / 2
    elseif align == "right" then
        tx = x + w - tw
    end
    lcd.drawText(floor(tx + 0.5), floor(y + 0.5), text)
    return tw, th
end

local layout = {cols = 12, rows = 12, padding = 0}
local screenBorderStyle = {enabled = false}

local function updateFlightTime(c)
    local session = rfsuite and rfsuite.session
    local seconds = session and session.timer and tonumber(session.timer.live) or 0
    seconds = floor(max(0, seconds))
    if c._timerSecond ~= seconds then
        c._timerSecond = seconds
        c.timer = format("%02d:%02d", floor(seconds / 60), seconds % 60)
    end
end

local function inflightWakeup(box, telemetry)
    local c = box._cache or {}
    box._cache = c

    local escWarnC = getThemeValue("esc_warn")
    local escMaxC = getThemeValue("esc_max")

    c.rpm = sensor(telemetry, "rpm", "headspeed", "erpm")
    local rpmStats = telemetry and telemetry.sensorStats and telemetry.sensorStats.rpm
    c.maxRpm = tonumber(rpmStats and rpmStats.max)
    if c.rpm ~= nil and (c.maxRpm == nil or c.rpm > c.maxRpm) then
        c.maxRpm = c.rpm
    end
    c.throttle = sensor(telemetry, "throttle_percent", "throttle")
    c.esc, c.escUnit, c.escWarn, c.escMax = temperatureSensor(telemetry, escWarnC, escMaxC)
    c.fuel = sensor(telemetry, "smartfuel")
    c.current = sensor(telemetry, "current")
    c.voltage = sensor(telemetry, "voltage")
    c.bec = sensor(telemetry, "bec_voltage", "bec")
    c.link = sensor(telemetry, "vfr")
    -- Only percentage readings can populate the link instrument.
    if c.link == nil or c.link < 0 or c.link > 100 then c.link = sensor(telemetry, "rssi") end
    if c.link ~= nil and (c.link < 0 or c.link > 100) then c.link = nil end
    c.consumed = sensor(telemetry, "smartconsumption", "consumption")
    c.flightState, c.flightStateColor = getFlightState(telemetry)
    updateFlightTime(c)

    -- Cache theme thresholds here (wakeup runs at a bounded rate) instead of
    -- calling getThemeValue() from paint(), which runs on every invalidate.
    c.fuelWarn = getThemeValue("fuel_warn")
    c.becMin = getThemeValue("bec_min")
    c.becWarn = getThemeValue("bec_warn")
    c.linkWarn = getThemeValue("link_warn")
    c.rpmMax = getThemeValue("rpm_max")

    cacheText(c, "rpmText", "_rpmTextValue", "_rpmTextUnit", c.rpm, 0, "")
    cacheText(c, "maxRpmText", "_maxRpmTextValue", "_maxRpmTextUnit", c.maxRpm, 0, " RPM", "MAX ")
    cacheText(c, "rpmLimitText", "_rpmLimitTextValue", "_rpmLimitTextUnit", c.rpmMax, 0, " RPM", "LIMIT ")
    cacheText(c, "escText", "_escTextValue", "_escTextUnit", c.esc, 0, c.escUnit)
    cacheText(c, "throttleText", "_throttleTextValue", "_throttleTextUnit", c.throttle, 0, "%")
    cacheText(c, "fuelText", "_fuelTextValue", "_fuelTextUnit", c.fuel, 0, "%")
    cacheText(c, "voltageText", "_voltageTextValue", "_voltageTextUnit", c.voltage, 1, " V")
    cacheText(c, "escWarnText", "_escWarnTextValue", "_escWarnTextUnit", c.escWarn, 0, c.escUnit, "WARN ")
    cacheText(c, "throttleLabelText", "_throttleLabelValue", "_throttleLabelUnit", c.throttle, 0, "%", "THROTTLE ")
    cacheText(c, "usedText", "_usedValue", "_usedUnit", c.consumed, 0, " mAh", "USED ")
    cacheText(c, "currentText", "_currentTextValue", "_currentTextUnit", c.current, 1, " A")
    cacheText(c, "becText", "_becTextValue", "_becTextUnit", c.bec, 1, " V")
    cacheText(c, "linkText", "_linkTextValue", "_linkTextUnit", c.link, 0, "%")
    cacheText(c, "consumedText", "_consumedTextValue", "_consumedTextUnit", c.consumed, 0, " mAh")

    return c
end

-- The 270-degree sweep is computed once. Resize work updates the existing
-- geometry buffer; ordinary paint only selects colors and issues LCD strokes.
local ARC_SEGMENTS = 40
local ARC_UNITS = {}
for i = 0, ARC_SEGMENTS - 1 do
    local angle = rad(135 + 270 * i / ARC_SEGMENTS)
    local finish = rad(135 + 270 * (i + 0.78) / ARC_SEGMENTS)
    ARC_UNITS[i + 1] = {cos(angle), sin(angle), cos(finish), sin(finish)}
end
local INDEX_COS, INDEX_SIN = {}, {}
for i = 0, ARC_SEGMENTS do
    local angle = rad(135 + 270 * i / ARC_SEGMENTS)
    INDEX_COS[i + 1], INDEX_SIN[i + 1] = cos(angle), sin(angle)
end

local function dialGeometry(c, cx, cy, radius)
    if c._dialX == cx and c._dialY == cy and c._dialRadius == radius then return end
    c._dialX, c._dialY, c._dialRadius = cx, cy, radius
    local strokes = c._dialStrokes or {}
    c._dialStrokes = strokes
    local n = 1
    for i = 1, ARC_SEGMENTS do
        local u = ARC_UNITS[i]
        -- Parallel chords form a narrow instrument band without image assets.
        for inset = 0, 4, 2 do
            local r = radius - inset
            strokes[n], strokes[n + 1] = floor(cx + u[1] * r), floor(cy + u[2] * r)
            strokes[n + 2], strokes[n + 3] = floor(cx + u[3] * r), floor(cy + u[4] * r)
            n = n + 4
        end
    end
    local ticks = c._dialTicks or {}
    c._dialTicks = ticks
    n = 1
    for i = 1, ARC_SEGMENTS + 1 do
        local tickLength = (i - 1) % 5 == 0 and 13 or 6
        local inner, outer = radius - 12 - tickLength, radius - 12
        local ux, uy = INDEX_COS[i], INDEX_SIN[i]
        ticks[n], ticks[n + 1] = floor(cx + ux * inner), floor(cy + uy * inner)
        ticks[n + 2], ticks[n + 3] = floor(cx + ux * outer), floor(cy + uy * outer)
        n = n + 4
    end
end

local function drawDial(c, cx, cy, radius, color)
    dialGeometry(c, cx, cy, radius)
    local fraction = c.rpm and max(0, min(1, c.rpm / max(1, c.rpmMax))) or 0
    local active = floor(ARC_SEGMENTS * fraction + 0.5)
    local strokes = c._dialStrokes
    local n = 1
    for i = 1, ARC_SEGMENTS do
        lcd.color(i <= active and color or C.line)
        for _ = 1, 3 do
            lcd.drawLine(strokes[n], strokes[n + 1], strokes[n + 2], strokes[n + 3])
            n = n + 4
        end
    end
    local ticks = c._dialTicks
    n = 1
    for i = 1, ARC_SEGMENTS + 1 do
        lcd.color((i - 1) % 5 == 0 and C.muted or C.line2)
        lcd.drawLine(ticks[n], ticks[n + 1], ticks[n + 2], ticks[n + 3])
        n = n + 4
    end
    if c.rpm ~= nil then
        -- A short bright radial index marks measured RPM without crossing digits.
        local ux, uy = INDEX_COS[active + 1], INDEX_SIN[active + 1]
        local inner, outer = radius - 29, radius + 4
        lcd.color(color)
        lcd.drawLine(floor(cx + ux * inner), floor(cy + uy * inner), floor(cx + ux * outer), floor(cy + uy * outer))
        lcd.drawFilledCircle(floor(cx + ux * (outer - 3)), floor(cy + uy * (outer - 3)), 3)
    end
end

local function drawRail(x, y, w, value, maximum, color, segmented)
    local fraction = value and max(0, min(1, value / max(1, maximum))) or 0
    lcd.color(C.line)
    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), 3)
    if fraction > 0 then
        lcd.color(color)
        lcd.drawFilledRectangle(floor(x), floor(y), floor(w * fraction), 3)
    end
    if segmented then
        -- Ten evenly spaced breaks identify the fuel bar's percentage scale.
        lcd.color(C.panel2)
        for i = 1, 9 do
            lcd.drawFilledRectangle(floor(x + w * i / 10), floor(y), 3, 3)
        end
    end
end

local function drawInstrument(x, y, w, h, title, value, subtitle, color, railValue, railMax, compact)
    lcd.color(C.panel)
    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))
    lcd.color(C.line)
    lcd.drawLine(floor(x), floor(y), floor(x + w - 1), floor(y))
    drawTextAligned(x + 12, y + 9, w * 0.50 - 12, title, compact and "FONT_XXS" or "FONT_XS", C.muted, "left")
    drawTextAligned(x + w * 0.43, y + 8, w * 0.57 - 13, value or "--", compact and "FONT_L" or "FONT_XL", color, "right")
    drawTextAligned(x + 12, y + h - 26, w - 24, subtitle or "--", "FONT_XXS", C.muted, "left")
    drawRail(x + 12, y + h - 8, w - 24, railValue, railMax, color, false)
end

local function drawPowerStrip(x, y, w, h, c, compact)
    lcd.color(C.panel)
    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))
    lcd.color(C.line2)
    lcd.drawLine(floor(x), floor(y), floor(x + w - 1), floor(y))
    local cellW = floor(w / 3)
    local becColor = c.bec and (c.bec < c.becMin and C.red or (c.bec < c.becWarn and C.amber or C.green)) or C.muted
    local linkColor = c.link and (c.link < c.linkWarn and C.amber or C.cyan) or C.muted
    local labelFont = compact and "FONT_XXS" or "FONT_XS"
    local valueFont = compact and "FONT_STD" or "FONT_L"
    local labelY = y + (h - (compact and 12 or 16)) / 2
    local valueY = y + (h - (compact and 24 or 28)) / 2
    drawTextAligned(x + 14, labelY, cellW * 0.49 - 14, "PACK", labelFont, C.muted, "left")
    drawTextAligned(x + cellW * 0.39, valueY, cellW * 0.61 - 14, c.voltageText or "--", valueFont, c.voltage == nil and C.muted or C.white, "right")
    drawTextAligned(x + cellW + 14, labelY, cellW * 0.49 - 14, "BEC", labelFont, C.muted, "left")
    drawTextAligned(x + cellW * 1.39, valueY, cellW * 0.61 - 14, c.becText or "--", valueFont, becColor, "right")
    drawTextAligned(x + cellW * 2 + 14, labelY, cellW * 0.49 - 14, "LINK", labelFont, C.muted, "left")
    drawTextAligned(x + cellW * 2.39, valueY, w - cellW * 2.39 - 14, c.linkText or "--", valueFont, linkColor, "right")
    lcd.color(C.line)
    for i = 1, 2 do
        lcd.drawLine(floor(x + cellW * i), floor(y + 10), floor(x + cellW * i), floor(y + h - 11))
    end
end

local function inflightPaint(x, y, w, h, box, c, telemetry)
    c = c or box._cache or {}
    box._cache = c
    -- Initial paint can precede wakeup. Populate only the missing thresholds.
    if c.escMax == nil or c.escWarn == nil then
        local _, unit, warning, maximum = temperatureSensor(telemetry, getThemeValue("esc_warn"), getThemeValue("esc_max"))
        c.escUnit, c.escWarn, c.escMax = unit, warning, maximum
    end
    c.fuelWarn = c.fuelWarn or getThemeValue("fuel_warn")
    c.becMin = c.becMin or getThemeValue("bec_min")
    c.becWarn = c.becWarn or getThemeValue("bec_warn")
    c.linkWarn = c.linkWarn or getThemeValue("link_warn")
    c.rpmMax = c.rpmMax or getThemeValue("rpm_max")

    local compact = h < 340
    local pad, gap = 12, 10
    local stripH = compact and 44 or 52
    local bodyY = y + 39
    local bodyH = max(120, h - 39 - stripH - gap - pad)
    local leftX = x + pad
    local availableW = w - pad * 2
    local leftW = floor((availableW - gap) * 0.58)
    local rightX = leftX + leftW + gap
    local rightW = availableW - leftW - gap

    lcd.color(C.bg)
    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))
    lcd.color(C.cyan)
    lcd.drawFilledRectangle(floor(x + pad), floor(y + 10), 3, 17)
    drawTextAligned(x + pad + 12, y + 6, 122, "VANTAGE", "FONT_S", C.white, "left")
    drawTextAligned(x + pad + 124, y + 10, 144, "FLIGHT TELEMETRY", "FONT_XXS", C.muted, "left")
    drawTextAligned(x + w - 230, y + 11, 133, "FLIGHT TIME", "FONT_XXS", C.muted, "right")
    drawTextAligned(x + w - 91, y + 5, 79, c.timer or "00:00", "FONT_STD", C.white, "right")

    lcd.color(C.panel)
    lcd.drawFilledRectangle(floor(leftX), floor(bodyY), floor(leftW), floor(bodyH))
    lcd.color(C.line2)
    lcd.drawLine(floor(leftX), floor(bodyY), floor(leftX + 29), floor(bodyY))
    lcd.drawLine(floor(leftX), floor(bodyY), floor(leftX), floor(bodyY + 16))
    lcd.drawLine(floor(leftX + leftW - 30), floor(bodyY), floor(leftX + leftW - 1), floor(bodyY))
    lcd.drawLine(floor(leftX + leftW - 1), floor(bodyY), floor(leftX + leftW - 1), floor(bodyY + 16))

    local radius = floor(min(leftW * 0.42, bodyH * 0.445))
    local cx = leftX + leftW / 2
    local cy = bodyY + radius + 7
    local rpmColor = c.rpm == nil and C.muted or (c.rpm > c.rpmMax and C.red or C.cyan)
    drawDial(c, cx, cy, radius, rpmColor)
    drawTextAligned(cx - radius * 0.63, cy - (compact and 47 or 61), radius * 1.26, "HEADSPEED", "FONT_XXS", C.muted, "center")
    drawTextAligned(cx - radius * 0.72, cy - (compact and 29 or 39), radius * 1.44, c.rpmText or "--", compact and "FONT_XXL" or "FONT_XXXXL", c.rpm == nil and C.muted or C.white, "center")
    drawTextAligned(cx - radius * 0.6, cy + (compact and 24 or 32), radius * 1.2, "RPM", "FONT_XXS", C.muted, "center")
    drawTextAligned(leftX + 15, cy + radius * 0.68, leftW - 30, c.flightState or "STATE --", "FONT_XXS", c.flightStateColor or C.muted, "center")
    drawTextAligned(leftX + 13, bodyY + bodyH - 21, leftW * 0.51 - 15, c.maxRpmText or "MAX --", "FONT_XXS", c.maxRpm == nil and C.muted or C.white, "left")
    drawTextAligned(leftX + leftW * 0.51, bodyY + bodyH - 21, leftW * 0.49 - 13, c.rpmLimitText or "LIMIT --", "FONT_XXS", C.muted, "right")

    local fuelH = floor((bodyH - gap * 2) * 0.40)
    local engineH = floor((bodyH - fuelH - gap * 2) / 2)
    local fuelColor = c.fuel == nil and C.muted or (c.fuel <= c.fuelWarn and C.red or (c.fuel <= 50 and C.amber or C.green))
    local escColor = c.esc == nil and C.muted or (c.esc >= c.escMax and C.red or (c.esc >= c.escWarn and C.amber or C.cyan))
    lcd.color(C.panel2)
    lcd.drawFilledRectangle(floor(rightX), floor(bodyY), floor(rightW), fuelH)
    lcd.color(fuelColor)
    lcd.drawFilledRectangle(floor(rightX), floor(bodyY), 3, fuelH)
    drawTextAligned(rightX + 13, bodyY + 10, rightW * 0.55 - 13, "FUEL RESERVE", compact and "FONT_XXS" or "FONT_XS", C.muted, "left")
    drawTextAligned(rightX + rightW * 0.48, bodyY + (compact and 8 or 21), rightW * 0.52 - 13, c.fuelText or "--", compact and "FONT_XL" or "FONT_XXL", fuelColor, "right")
    drawTextAligned(rightX + 13, bodyY + fuelH - 29, rightW - 26, c.usedText or "USED --", "FONT_XXS", C.muted, "left")
    drawRail(rightX + 13, bodyY + fuelH - 10, rightW - 26, c.fuel, 100, fuelColor, true)

    local escY = bodyY + fuelH + gap
    drawInstrument(rightX, escY, rightW, engineH, "ESC TEMP", c.escText, c.escWarnText, escColor, c.esc, c.escMax, compact)
    local loadY = escY + engineH + gap
    local loadH = bodyY + bodyH - loadY
    drawInstrument(rightX, loadY, rightW, loadH, "CURRENT", c.currentText, c.throttleLabelText, c.current == nil and C.muted or C.violet, c.throttle, 100, compact)
    drawPowerStrip(leftX, bodyY + bodyH + gap, availableW, stripH, c, compact)
end

local boxes_cache = nil

local function boxes()
    if boxes_cache == nil then
        boxes_cache = {{
        col = 1, row = 1, colspan = 12, rowspan = 12,
        type = "func", subtype = "func",
        wakeup = inflightWakeup,
        paint = inflightPaint,
        bgcolor = "transparent"
        }}
    end
    return boxes_cache
end

return {
    layout = layout,
    boxes = boxes,
    header_boxes = header_boxes,
    header_layout = header_layout,
    screenBorderStyle = screenBorderStyle,
    scheduler = {spread_scheduling = true, spread_scheduling_paint = false, spread_ratio = 0.85}
}
