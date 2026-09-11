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
local pi = math.pi
local rawNumber = tonumber
local function tonumber(value)
    local number = rawNumber(value)
    if number and number == number and number > -math.huge and number < math.huge then return number end
    return nil
end
local tostring = tostring
local type = type
local format = string.format
local ipairs = ipairs

local utils = rfsuite.widgets.dashboard.utils
local headeropts = utils.getHeaderOptions()
-- This theme owns its header geometry; leave the Suite defaults unchanged.
headeropts.height = math.max(headeropts.height or 0, 44)
-- The Suite caches its native palette; each theme owns its presentation copy.
local colorMode = {}
for key, value in pairs(utils.themeColors()) do colorMode[key] = value end
local header_layout = utils.standardHeaderLayout(headeropts)

local C = {
    bg = lcd.RGB(20, 15, 30),
    panel = lcd.RGB(37, 27, 51),
    line = lcd.RGB(104, 75, 119),
    line2 = lcd.RGB(151, 107, 160),
    white = lcd.RGB(246, 239, 255),
    muted = lcd.RGB(190, 166, 199),
    gold = lcd.RGB(255, 199, 91),
    goldDim = lcd.RGB(112, 77, 28),
    turquoise = lcd.RGB(58, 238, 216),
    turquoiseDim = lcd.RGB(16, 86, 79),
    emerald = lcd.RGB(81, 241, 139),
    emeraldDim = lcd.RGB(22, 91, 52),
    fuchsia = lcd.RGB(255, 78, 203),
    fuchsiaDim = lcd.RGB(105, 26, 78),
    violet = lcd.RGB(187, 107, 255),
    violetDim = lcd.RGB(67, 34, 99),
    coral = lcd.RGB(255, 104, 112),
    amber = lcd.RGB(255, 166, 62),
    red = lcd.RGB(255, 74, 96)
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

local DEFAULTS = {
    rpm_max = 3000,
    bec_min = 6.5,
    bec_warn = 7.0,
    esc_warn = 110,
    esc_max = 150,
    fuel_warn = 25,
    link_warn = 50,
    current_warn = 120,
    watts_warn = 3500
}

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function getThemeValue(key)
    -- The rewritten Suite binds preferences to the active dashboard theme.
    local value = tonumber(rfsuite.widgets.dashboard.getPreference(key))
    return value or DEFAULTS[key]
end

local function readSensor(telemetry, name)
    local value, _, unit = telemetry.getSensor(name)
    value = tonumber(value)
    if value ~= nil then return value, unit end
    return nil, nil
end

local function sensor(telemetry, name, alias1, alias2)
    telemetry = telemetry or (rfsuite.tasks and rfsuite.tasks.telemetry)
    if not (telemetry and telemetry.getSensor) then return nil end
    local value, unit = readSensor(telemetry, name)
    if value ~= nil then return value, unit end
    if alias1 then
        value, unit = readSensor(telemetry, alias1)
        if value ~= nil then return value, unit end
    end
    if alias2 then
        value, unit = readSensor(telemetry, alias2)
        if value ~= nil then return value, unit end
    end
    return nil
end

local function readStat(telemetry, source, statType)
    local data
    if (source == "temp_esc" or source == "temp_mcu") and telemetry.getSensorStats then
        data = telemetry.getSensorStats(source)
    else
        local stats = telemetry.sensorStats
        data = stats and stats[source]
    end
    local value = tonumber(data and data[statType])
    if value ~= nil then return value, data and data.unit end
    return nil, nil
end

local function stat(telemetry, source, statType, alias1, alias2)
    telemetry = telemetry or (rfsuite.tasks and rfsuite.tasks.telemetry)
    if not telemetry then return nil end
    local value, unit = readStat(telemetry, source, statType)
    if value ~= nil then return value, unit end
    if alias1 then
        value, unit = readStat(telemetry, alias1, statType)
        if value ~= nil then return value, unit end
    end
    if alias2 then
        value, unit = readStat(telemetry, alias2, statType)
        if value ~= nil then return value, unit end
    end
    return nil
end

local function temperatureUnitLabel(unit)
    if unit == nil then
        local general = rfsuite and rfsuite.preferences and rfsuite.preferences.general
        unit = tonumber(general and general.temperature_unit)
    end
    if unit == 1 then return "°F" end
    if unit == 0 then return "°C" end
    if type(unit) == "string" and unit ~= "" then return unit end
    return "°C"
end

local function temperatureThreshold(value, unit)
    if unit == 1 or unit == "°F" or unit == "F" then return value * 1.8 + 32 end
    return value
end

local function fmt(value, decimals, suffix, missing)
    if value == nil then return missing or "--" end
    local text
    if decimals == 1 then text = format("%.1f", value)
    elseif decimals == 2 then text = format("%.2f", value)
    else text = tostring(floor(value + 0.5)) end
    return text .. (suffix or "")
end

local function roundedKey(value, decimals)
    if value == nil then return false end
    local multiplier = decimals == 2 and 100 or (decimals == 1 and 10 or 1)
    return floor(value * multiplier + 0.5)
end

local function updateFormatted(cache, keyField, textField, value, decimals, suffix)
    local key = roundedKey(value, decimals)
    if cache[keyField] ~= key or cache[textField] == nil then
        cache[keyField] = key
        cache[textField] = fmt(value, decimals, suffix)
    end
    return key
end

local function resolveFont(name)
    return utils.resolveFont(name, nil)
end

local FONT_FALLBACK = {
    FONT_XXL = "FONT_XL", FONT_XL = "FONT_L", FONT_L = "FONT_STD",
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
    if align == "center" then tx = x + (w - tw) / 2
    elseif align == "right" then tx = x + w - tw end
    lcd.drawText(floor(tx + 0.5), floor(y + 0.5), text)
    return tw, th
end

local function drawDiamond(cx, cy, radius, color, innerColor)
    cx, cy, radius = floor(cx), floor(cy), floor(radius)
    lcd.color(color)
    lcd.drawLine(cx, cy - radius, cx + radius, cy)
    lcd.drawLine(cx + radius, cy, cx, cy + radius)
    lcd.drawLine(cx, cy + radius, cx - radius, cy)
    lcd.drawLine(cx - radius, cy, cx, cy - radius)
    if innerColor and radius > 4 then
        local r = floor(radius * 0.55)
        lcd.color(innerColor)
        lcd.drawLine(cx, cy - r, cx + r, cy)
        lcd.drawLine(cx + r, cy, cx, cy + r)
        lcd.drawLine(cx, cy + r, cx - r, cy)
        lcd.drawLine(cx - r, cy, cx, cy - r)
    end
end

local PETAL_T_SIN = {}
for i = 0, 8 do
    PETAL_T_SIN[i + 1] = sin(pi * i / 8)
end

local PETAL_ANGLE_CACHE = {}
local function getPetalAngleUnit(angleDeg)
    local u = PETAL_ANGLE_CACHE[angleDeg]
    if not u then
        local a = rad(angleDeg)
        local ax, ay = cos(a), sin(a)
        u = { ax, ay, -ay, ax }
        PETAL_ANGLE_CACHE[angleDeg] = u
    end
    return u
end

local function drawPetal(cx, cy, length, width, angleDeg, color)
    local u = getPetalAngleUnit(angleDeg)
    local ax, ay, px, py = u[1], u[2], u[3], u[4]
    local lastLx, lastLy, lastRx, lastRy
    lcd.color(color)
    for i = 0, 8 do
        local t = i / 8
        local centerDist = length * t
        local side = PETAL_T_SIN[i + 1] * width
        local ccx = cx + ax * centerDist
        local ccy = cy + ay * centerDist
        local lx = floor(ccx + px * side)
        local ly = floor(ccy + py * side)
        local rx = floor(ccx - px * side)
        local ry = floor(ccy - py * side)
        if lastLx then
            lcd.drawLine(lastLx, lastLy, lx, ly)
            lcd.drawLine(lastRx, lastRy, rx, ry)
        end
        lastLx, lastLy, lastRx, lastRy = lx, ly, rx, ry
    end
end

local function drawLattice(x, y, w, h)
    local step = 42
    lcd.color(C.line)
    for sx = floor(x - h), floor(x + w), step do
        lcd.drawLine(sx, floor(y + h), sx + floor(h), floor(y))
    end
    for sx = floor(x), floor(x + w + h), step do
        lcd.drawLine(sx, floor(y), sx - floor(h), floor(y + h))
    end
end

local function drawPanel(x, y, w, h, accent, title)
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    lcd.color(C.panel)
    lcd.drawFilledRectangle(x, y, w, h)
    lcd.color(C.line2)
    lcd.drawRectangle(x, y, w, h, 1)
    lcd.color(accent or C.gold)
    lcd.drawFilledRectangle(x, y, 3, h)
    drawDiamond(x + 8, y + 8, 5, accent or C.gold, C.line2)
    drawDiamond(x + w - 8, y + h - 8, 5, accent or C.gold, C.line2)
    if title then drawTextAligned(x + 16, y + 7, w - 30, title, "FONT_XXS", C.muted, "left") end
end

local function drawMetric(x, y, w, h, title, value, accent, subtitle)
    drawPanel(x, y, w, h, accent, title)
    local compact = h < 75
    drawTextAligned(x + 13, y + (compact and 21 or 27), w - 26, value, compact and "FONT_S" or "FONT_L", value == "--" and C.muted or C.white, "left")
    if subtitle and h >= 88 then
        drawTextAligned(x + 13, y + h - 21, w - 26, subtitle, "FONT_XXS", C.muted, "left")
    end
end

local function drawProgress(x, y, w, h, percent, color)
    percent = clamp(percent or 0, 0, 1)
    lcd.color(C.line2)
    lcd.drawRectangle(floor(x), floor(y), floor(w), floor(h), 1)
    if percent > 0 then
        lcd.color(color)
        lcd.drawFilledRectangle(floor(x + 2), floor(y + 2), floor((w - 4) * percent), max(1, floor(h - 4)))
    end
end

local function drawGemLine(x, y, w, count, percent, activeColor, dimColor)
    percent = clamp(percent or 0, 0, 100)
    local active = percent > 0 and max(1, min(count, floor(percent * count / 100 + 0.999))) or 0
    local spacing = w / count
    for i = 0, count - 1 do
        local cx = x + spacing * (i + 0.5)
        drawDiamond(cx, y, min(8, spacing * 0.34), i < active and activeColor or dimColor, i < active and C.white or nil)
    end
end

local HEADER_LABEL = "Rotorflight // Ethos"
local HEADER_SIGNATURE = "| MWRC"
local headerTitleCache = {}
local function drawHeaderTitle(x, y, w, h)
    lcd.color(C.panel)
    lcd.drawFilledRectangle(math.floor(x), math.floor(y), math.floor(w), math.floor(h))
    local cache = headerTitleCache
    -- Measure only when the header geometry changes; keep the builder mark smaller.
    if cache._titleWidth ~= w or cache._titleLayoutHeight ~= h then
        local titleFont = utils.resolveFont("FONT_L", nil)
        local markFont = utils.resolveFont("FONT_XS", nil)
        if type(titleFont) ~= "number" or type(markFont) ~= "number" then return end
        lcd.font(markFont)
        local mw, mh = lcd.getTextSize(HEADER_SIGNATURE)
        lcd.font(titleFont)
        local tw, th = lcd.getTextSize(HEADER_LABEL)
        if tw + mw + 24 > w or th > h - 4 then
            titleFont = utils.resolveFont("FONT_STD", nil) or titleFont
            lcd.font(titleFont)
            tw, th = lcd.getTextSize(HEADER_LABEL)
        end
        if tw + mw + 24 > w or th > h - 4 then
            titleFont = utils.resolveFont("FONT_S", nil) or titleFont
            lcd.font(titleFont)
            tw, th = lcd.getTextSize(HEADER_LABEL)
        end
        -- Narrow header slots retain the same hierarchy with the smallest pair.
        if tw + mw + 24 > w or th > h - 4 then
            titleFont = utils.resolveFont("FONT_XS", nil) or titleFont
            markFont = utils.resolveFont("FONT_XXS", nil) or markFont
            lcd.font(markFont)
            mw, mh = lcd.getTextSize(HEADER_SIGNATURE)
            lcd.font(titleFont)
            tw, th = lcd.getTextSize(HEADER_LABEL)
        end
        cache._titleWidth = w
        cache._titleLayoutHeight = h
        cache._titleFont = titleFont
        cache._titleHeight = th
        cache._titleTextWidth = tw
        cache._markFont = markFont
        cache._markHeight = mh
        cache._titleGroupWidth = tw + 8 + mw
    end
    local screenW = lcd.getWindowSize()
    local groupX = math.floor((screenW - cache._titleGroupWidth) / 2 + 0.5)
    lcd.font(cache._titleFont)
    lcd.color(C.gold)
    lcd.drawText(groupX, math.floor(y + (h - cache._titleHeight) / 2), HEADER_LABEL)
    lcd.font(cache._markFont)
    lcd.color(C.muted)
    lcd.drawText(groupX + cache._titleTextWidth + 8, math.floor(y + (h - cache._markHeight) / 2), HEADER_SIGNATURE)
end

local header_boxes_cache = nil
local last_txbatt_type = nil
local function header_boxes()
    local txbatt_type = 0
    if rfsuite and rfsuite.preferences and rfsuite.preferences.general then
        txbatt_type = rfsuite.preferences.general.txbatt_type or 0
    end
    if header_boxes_cache == nil or last_txbatt_type ~= txbatt_type then
        local boxes = utils.standardHeaderBoxes(i18n, colorMode, headeropts, txbatt_type)
        for _, b in ipairs(boxes) do
            if b.subtype == "craftname" then b.font = nil end
            b.bgcolor = C.bg
            if b.type == "image" then
                b.type = "func"
                b.subtype = "func"
                b.paint = drawHeaderTitle
            end
        end
        header_boxes_cache = boxes
        last_txbatt_type = txbatt_type
    end
    return header_boxes_cache
end

local STATE_LABELS = {
    [0] = "ARMED / OFF",
    [1] = "ARMED / IDLE",
    [2] = "ARMED / SPOOLUP",
    [3] = "ARMED / RECOVERY",
    [4] = "ARMED / ACTIVE",
    [5] = "ARMED / THR CUT",
    [6] = "ARMED / LINK LOST",
    [7] = "ARMED / AUTOROT",
    [8] = "ARMED / BAILOUT",
    [100] = "GOVERNOR OFF",
    [101] = "DISARMED"
}
local STATE_COLORS = {
    [0] = C.amber, [1] = C.amber, [2] = C.fuchsia, [3] = C.amber,
    [4] = C.emerald, [5] = C.emerald, [6] = C.red, [7] = C.amber,
    [8] = C.red, [100] = C.muted, [101] = C.turquoise
}

local function getFlightState(telemetry)
    local armflags = sensor(telemetry, "armflags")
    local governor = sensor(telemetry, "governor")
    local armed = nil
    if rfsuite.utils and rfsuite.utils.armFlagsToIsArmed then armed = rfsuite.utils.armFlagsToIsArmed(armflags) end
    if armed == nil and armflags == nil and governor == nil then
        local session = rfsuite and rfsuite.session
        if session and session.telemetryState then armed = session.isArmed == true end
    end
    if armed == false then return "DISARMED", C.turquoise end
    local code = governor and floor(governor + 0.5) or nil
    if code == 101 then return "DISARMED", C.turquoise end
    if armed == true then
        if code and STATE_LABELS[code] then return STATE_LABELS[code], STATE_COLORS[code] or C.red end
        return "ARMED", C.red
    end
    if code and STATE_LABELS[code] then return STATE_LABELS[code], STATE_COLORS[code] or C.turquoise end
    return "STATE --", C.muted
end

local layout = {cols = 12, rows = 12, padding = 0}
local screenBorderStyle = {enabled = false}

local function preflightWakeup(box, telemetry)
    local c = box._cache or {}
    box._cache = c
    c.fuel = sensor(telemetry, "smartfuel")
    c.bec = sensor(telemetry, "bec_voltage", "bec")
    local escUnit
    c.esc, escUnit = sensor(telemetry, "temp_esc", "esc_temp")
    local resolvedEscUnit = temperatureUnitLabel(escUnit)
    if c.escUnit ~= resolvedEscUnit then
        c.escUnit = resolvedEscUnit
        c._escTextKey = nil
    end
    c.link = sensor(telemetry, "vfr", "rssi")
    c.rate = sensor(telemetry, "rate_profile")
    c.pid = sensor(telemetry, "pid_profile")
    c.voltage = sensor(telemetry, "voltage")
    c.flightState, c.flightColor = getFlightState(telemetry)

    updateFormatted(c, "_becTextKey", "becText", c.bec, 1, " V")
    updateFormatted(c, "_linkTextKey", "linkText", c.link, 0, "%")
    updateFormatted(c, "_fuelTextKey", "fuelText", c.fuel, 0, "%")
    updateFormatted(c, "_escTextKey", "escText", c.esc, 0, c.escUnit)

    local rateKey = roundedKey(c.rate, 0)
    if c._ratesTextKey ~= rateKey or c.ratesText == nil then
        c._ratesTextKey = rateKey
        c.ratesText = "RATES  " .. fmt(c.rate, 0, "")
    end
    local pidKey = roundedKey(c.pid, 0)
    if c._pidTextKey ~= pidKey or c.pidText == nil then
        c._pidTextKey = pidKey
        c.pidText = "PID     " .. fmt(c.pid, 0, "")
    end
    local voltageKey = roundedKey(c.voltage, 1)
    if c._packTextKey ~= voltageKey or c.packText == nil then
        c._packTextKey = voltageKey
        c.packText = "PACK   " .. fmt(c.voltage, 1, " V")
    end

    -- Settings are stored in Celsius; compare against the sensor's presented unit.
    c.fuelWarn = getThemeValue("fuel_warn")
    c.becMin = getThemeValue("bec_min")
    c.becWarn = getThemeValue("bec_warn")
    c.escMax = temperatureThreshold(getThemeValue("esc_max"), c.escUnit)
    c.escWarn = temperatureThreshold(getThemeValue("esc_warn"), c.escUnit)
    c.linkWarn = getThemeValue("link_warn")

    local available, faults, warnings = 0, 0, 0
    local issue = nil
    if c.fuel ~= nil then
        available = available + 1
        if c.fuel <= c.fuelWarn then faults = faults + 1; issue = issue or ("FUEL " .. fmt(c.fuel,0,"%") .. " AT RESERVE") end
    end
    if c.bec ~= nil then
        available = available + 1
        if c.bec < c.becMin then faults = faults + 1; issue = issue or ("BEC " .. fmt(c.bec,1,"V") .. " CRITICAL")
        elseif c.bec < c.becWarn then warnings = warnings + 1; issue = issue or ("BEC " .. fmt(c.bec,1,"V") .. " LOW") end
    end
    if c.esc ~= nil then
        available = available + 1
        if c.esc >= c.escMax then faults = faults + 1; issue = issue or ("ESC " .. fmt(c.esc,0,c.escUnit) .. " AT LIMIT")
        elseif c.esc >= c.escWarn then warnings = warnings + 1; issue = issue or ("ESC " .. fmt(c.esc,0,c.escUnit) .. " HOT") end
    end
    if c.link ~= nil then
        available = available + 1
        if c.link < c.linkWarn then warnings = warnings + 1; issue = issue or ("LINK " .. fmt(c.link,0,"%") .. " LOW") end
    end

    c.issue = issue
    if available == 0 then c.status, c.statusSub, c.statusColor = "AWAITING SIGNAL", "CONNECT TELEMETRY", C.muted
    elseif faults > 0 then c.status, c.statusSub, c.statusColor = "DO NOT LAUNCH", issue or "CRITICAL CHECK", C.red
    elseif warnings > 0 then c.status, c.statusSub, c.statusColor = "PAUSE & REVIEW", issue or "CHECK SYSTEMS", C.amber
    elseif available < 4 then c.status, c.statusSub, c.statusColor = "PARTIAL DATA", "CHECK MISSING SENSORS", C.amber
    else c.status, c.statusSub, c.statusColor = "READY TO BLOOM", "ALL SYSTEMS NOMINAL", C.emerald end

    return c
end

local function preflightPaint(x, y, w, h, box, c)
    c = c or box._cache or {}
    box._cache = c

    -- Safety net: if paint() runs before the first wakeup() cycle has
    -- populated the cache (e.g. very first frame), fall back to a live
    -- lookup so we never compare a number against a nil threshold.
    c.fuelWarn = c.fuelWarn or getThemeValue("fuel_warn")
    c.becMin = c.becMin or getThemeValue("bec_min")
    c.becWarn = c.becWarn or getThemeValue("bec_warn")
    c.escUnit = c.escUnit or "°C"
    c.escMax = c.escMax or temperatureThreshold(getThemeValue("esc_max"), c.escUnit)
    c.escWarn = c.escWarn or temperatureThreshold(getThemeValue("esc_warn"), c.escUnit)
    c.linkWarn = c.linkWarn or getThemeValue("link_warn")

    lcd.color(C.bg); lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))
    drawLattice(x, y, w, h)

    drawTextAligned(x + 14, y + 7, w * 0.52, "ZAFIRA // PRE-FLIGHT", "FONT_STD", C.gold, "left")
    drawTextAligned(x + w - 300, y + 8, 286, c.status or "AWAITING SIGNAL", "FONT_STD", c.statusColor or C.muted, "right")

    local bodyY, bodyH = y + 43, h - 55
    local sideW = floor(w * 0.245)
    local leftX, rightX = x + 12, x + w - sideW - 12
    local centerX = leftX + sideW + 12
    local centerW = w - sideW * 2 - 48
    local cardH = floor((bodyH - 10) / 2)

    local becColor = c.bec and (c.bec < c.becMin and C.red or (c.bec < c.becWarn and C.amber or C.turquoise)) or C.muted
    local escColor = c.esc and (c.esc >= c.escMax and C.red or (c.esc >= c.escWarn and C.amber or C.emerald)) or C.muted
    local linkColor = c.link and (c.link < c.linkWarn and C.amber or C.turquoise) or C.muted
    local fuel = c.fuel or 0
    local fuelColor = c.fuel and (fuel <= c.fuelWarn and C.red or (fuel <= 50 and C.amber or C.emerald)) or C.muted

    drawMetric(leftX, bodyY, sideW, cardH, "SAPPHIRE BEC", c.becText or "--", becColor, "regulated power")
    drawProgress(leftX + 14, bodyY + cardH - 36, sideW - 28, 9, c.bec and c.bec / 15 or 0, becColor)
    drawMetric(leftX, bodyY + cardH + 10, sideW, cardH, "TURQUOISE LINK", c.linkText or "--", linkColor, "radio clarity")
    drawProgress(leftX + 14, bodyY + bodyH - 36, sideW - 28, 9, c.link and c.link / 100 or 0, linkColor)

    drawPanel(centerX, bodyY, centerW, bodyH, c.statusColor or C.gold, nil)
    local cx = centerX + centerW * 0.5
    local cy = bodyY + bodyH * (bodyH < 260 and 0.26 or 0.35)
    local petalL = min(centerW, bodyH) * (bodyH < 260 and 0.20 or 0.26)
    for i = 0, 7 do drawPetal(cx, cy, petalL, petalL * 0.22, i * 45, i % 2 == 0 and C.fuchsia or C.turquoise) end
    drawDiamond(cx, cy, petalL * 0.62, C.gold, C.violet)
    drawDiamond(cx, cy, petalL * 0.40, c.statusColor or C.gold, C.white)
    lcd.color(C.panel)
    lcd.drawFilledRectangle(floor(centerX + 14), floor(cy - 23), floor(centerW - 28), 63)
    drawTextAligned(centerX + 14, cy - 22, centerW - 28, c.status or "WAITING", "FONT_L", C.white, "center")
    drawTextAligned(centerX + 12, cy + 15, centerW - 24, c.statusSub or "CONNECT TELEMETRY", "FONT_XXS", c.statusColor or C.muted, "center")

    local gemY = bodyY + bodyH - 82
    drawTextAligned(centerX + 18, gemY - 27, centerW - 36, "SMART FUEL JEWELS", "FONT_XXS", C.muted, "left")
    drawTextAligned(centerX + 18, gemY - 28, centerW - 36, c.fuelText or "--", "FONT_S", c.fuel and C.white or C.muted, "right")
    drawGemLine(centerX + 20, gemY, centerW - 40, 12, fuel, fuelColor, C.line2)
    drawPanel(centerX + 48, gemY + 20, centerW - 96, 29, c.flightColor or C.turquoise, nil)
    drawTextAligned(centerX + 58, gemY + 25, centerW - 116, c.flightState or "STATE --", "FONT_XXS", c.flightColor or C.muted, "center")

    drawMetric(rightX, bodyY, sideW, cardH, "EMBER ESC", c.escText or "--", escColor, "thermal balance")
    drawProgress(rightX + 14, bodyY + cardH - 36, sideW - 28, 9, c.esc and c.esc / c.escMax or 0, escColor)
    drawPanel(rightX, bodyY + cardH + 10, sideW, cardH, C.violet, "FLIGHT TALISMAN")
    drawTextAligned(rightX + 16, bodyY + cardH + 10 + floor(cardH * 0.3), sideW - 32, c.ratesText or "RATES  --", "FONT_XS", c.rate and C.white or C.muted, "left")
    drawTextAligned(rightX + 16, bodyY + cardH + 10 + floor(cardH * 0.54), sideW - 32, c.pidText or "PID     --", "FONT_XS", c.pid and C.white or C.muted, "left")
    drawTextAligned(rightX + 16, bodyY + cardH + 10 + floor(cardH * 0.78), sideW - 32, c.packText or "PACK   --", "FONT_XS", c.voltage and C.white or C.muted, "left")
end

local boxes_cache
local function boxes()
    if not boxes_cache then boxes_cache = {{col=1,row=1,colspan=12,rowspan=12,type="func",subtype="func",wakeup=preflightWakeup,paint=preflightPaint,bgcolor="transparent"}} end
    return boxes_cache
end
return {layout=layout,boxes=boxes,header_boxes=header_boxes,header_layout=header_layout,screenBorderStyle=screenBorderStyle,scheduler={spread_scheduling=true,spread_scheduling_paint=false,spread_ratio=0.85}}
