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
    space = lcd.RGB(3, 5, 12),
    void = lcd.RGB(0, 0, 3),
    panel = lcd.RGB(13, 17, 34),
    panel2 = lcd.RGB(13, 18, 34),
    line = lcd.RGB(37, 57, 87),
    line2 = lcd.RGB(75, 101, 140),
    white = lcd.RGB(228, 240, 255),
    muted = lcd.RGB(157, 178, 208),
    cyan = lcd.RGB(58, 236, 255),
    cyanDim = lcd.RGB(16, 74, 92),
    violet = lcd.RGB(170, 97, 255),
    violetDim = lcd.RGB(53, 27, 89),
    blue = lcd.RGB(58, 111, 255),
    blueDim = lcd.RGB(18, 38, 91),
    green = lcd.RGB(98, 255, 165),
    greenDim = lcd.RGB(21, 87, 59),
    amber = lcd.RGB(255, 190, 70),
    amberDim = lcd.RGB(94, 64, 17),
    red = lcd.RGB(255, 72, 110),
    redDim = lcd.RGB(90, 19, 38),
    magenta = lcd.RGB(255, 74, 235)
}

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

local STARFIELD = {
    {2,6,1},{7,18,1},{11,9,2},{15,29,1},{19,14,1},{23,5,1},{27,24,2},{31,12,1},
    {35,32,1},{39,20,1},{43,7,2},{47,27,1},{51,16,1},{55,4,1},{59,31,2},{63,11,1},
    {67,23,1},{71,6,1},{75,18,2},{79,29,1},{83,13,1},{87,2,1},{91,24,2},{95,9,1},
    {5,38,1},{13,44,2},{21,36,1},{29,48,1},{37,40,2},{45,50,1},{53,37,1},{61,46,2},
    {69,39,1},{77,49,1},{85,35,2},{93,45,1},{9,58,1},{18,67,2},{26,56,1},{34,71,1},
    {42,62,2},{50,75,1},{58,59,1},{66,69,2},{74,55,1},{82,73,1},{90,61,2},{97,76,1},
    {4,85,1},{12,94,2},{24,82,1},{32,91,1},{40,79,2},{48,96,1},{56,84,1},{64,93,2},
    {72,81,1},{80,97,1},{88,86,2},{96,92,1}
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

local function drawStars(x, y, w, h)
    for i = 1, #STARFIELD do
        local s = STARFIELD[i]
        local sx = floor(x + w * s[1] / 100)
        local sy = floor(y + h * s[2] / 100)
        local size = s[3]
        lcd.color(size == 2 and C.line2 or C.line)
        lcd.drawFilledRectangle(sx, sy, size, size)
    end
end

local function drawPanel(x, y, w, h, accent, title)
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    lcd.color(C.panel)
    lcd.drawFilledRectangle(x, y, w, h)
    lcd.color(C.line)
    lcd.drawRectangle(x, y, w, h, 1)
    lcd.color(accent or C.cyan)
    lcd.drawFilledRectangle(x, y, 3, h)
    if title then
        drawTextAligned(x + 11, y + 7, w - 20, title, "FONT_XXS", C.muted, "left")
    end
end

local function drawNode(x, y, w, h, title, value, accent, subtitle)
    drawPanel(x, y, w, h, accent, title)
    local compact = h < 75
    drawTextAligned(x + 13, y + (compact and 21 or 27), w - 26, value, compact and "FONT_S" or "FONT_L", value == "--" and C.muted or C.white, "left")
    if subtitle and h >= 88 then
        drawTextAligned(x + 13, y + h - 21, w - 26, subtitle, "FONT_XXS", C.muted, "left")
    end
end

local HEX_UNIT = {}
for i = 0, 5 do
    local a = rad(30 + i * 60)
    HEX_UNIT[i + 1] = {cos(a), sin(a)}
end

local function drawHex(cx, cy, radius, color)
    local first = HEX_UNIT[1]
    local firstx = floor(cx + first[1] * radius)
    local firsty = floor(cy + first[2] * radius)
    local px, py = firstx, firsty
    lcd.color(color)
    for i = 2, #HEX_UNIT do
        local u = HEX_UNIT[i]
        local x = floor(cx + u[1] * radius)
        local y = floor(cy + u[2] * radius)
        lcd.drawLine(px, py, x, y)
        px, py = x, y
    end
    lcd.drawLine(px, py, firstx, firsty)
end

local RING_UNIT_CACHE = {}
local function getRingUnit(count, startAngle, sweep)
    local byCount = RING_UNIT_CACHE[count]
    if not byCount then byCount = {}; RING_UNIT_CACHE[count] = byCount end
    local byStart = byCount[startAngle]
    if not byStart then byStart = {}; byCount[startAngle] = byStart end
    local unit = byStart[sweep]
    if not unit then
        unit = {}
        for i = 0, count - 1 do
            local a = rad(startAngle + sweep * i / count)
            unit[i + 1] = {cos(a), sin(a)}
        end
        byStart[sweep] = unit
    end
    return unit
end

local function drawRingSegments(cx, cy, radius, count, percent, activeColor, dimColor, thickness, startAngle, sweep, unit)
    count = count or 24
    percent = clamp(percent or 0, 0, 100)
    thickness = thickness or 8
    startAngle = startAngle or 0
    sweep = sweep or 360
    local active = percent > 0 and max(1, min(count, floor(percent * count / 100 + 0.999))) or 0
    unit = unit or getRingUnit(count, startAngle, sweep)
    for i = 0, count - 1 do
        local u = unit[i + 1]
        local r1 = radius - thickness
        local r2 = radius
        local x1 = floor(cx + u[1] * r1)
        local y1 = floor(cy + u[2] * r1)
        local x2 = floor(cx + u[1] * r2)
        local y2 = floor(cy + u[2] * r2)
        lcd.color(i < active and activeColor or dimColor)
        lcd.drawLine(x1, y1, x2, y2)
    end
end

local ORBIT_UNIT_CACHE = {}
local function getOrbitUnit(segments)
    local unit = ORBIT_UNIT_CACHE[segments]
    if not unit then
        unit = {}
        for i = 0, segments do
            local a = rad(360 * i / segments)
            unit[i + 1] = {cos(a), sin(a)}
        end
        ORBIT_UNIT_CACHE[segments] = unit
    end
    return unit
end

local function drawOrbit(cx, cy, rx, ry, color, segments, unit)
    segments = segments or 48
    local lastx, lasty
    unit = unit or getOrbitUnit(segments)
    lcd.color(color)
    for i = 1, #unit do
        local u = unit[i]
        local x = floor(cx + u[1] * rx)
        local y = floor(cy + u[2] * ry)
        if lastx then lcd.drawLine(lastx, lasty, x, y) end
        lastx, lasty = x, y
    end
end

local function drawOrbitalMarker(cx, cy, rx, ry, angle, color, size)
    local a = rad(angle)
    local x = floor(cx + cos(a) * rx)
    local y = floor(cy + sin(a) * ry)
    size = size or 6
    lcd.color(color)
    lcd.drawFilledRectangle(x - floor(size/2), y - floor(size/2), size, size)
end

local function drawProgress(x, y, w, h, percent, color)
    percent = clamp(percent or 0, 0, 1)
    lcd.color(C.line)
    lcd.drawRectangle(floor(x), floor(y), floor(w), floor(h), 1)
    if percent > 0 then
        lcd.color(color)
        lcd.drawFilledRectangle(floor(x + 2), floor(y + 2), floor((w - 4) * percent), max(1, floor(h - 4)))
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
    lcd.color(C.violet)
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
            b.bgcolor = C.space
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

local function updateFlightTime(cache)
    local session = rfsuite and rfsuite.session
    local seconds = session and session.timer and tonumber(session.timer.live) or 0
    seconds = floor(max(0, seconds))
    if cache._timerSecond ~= seconds or cache.flightTimeText == nil then
        cache._timerSecond = seconds
        cache.time = format("%02d:%02d", floor(seconds / 60), seconds % 60)
        cache.flightTimeText = "FLIGHT TIME " .. cache.time
    end
end

local STATE_LABELS = {
    [0] = "OFFLINE",
    [1] = "IDLE",
    [2] = "IGNITION",
    [3] = "RECOVERY",
    [4] = "STABLE ORBIT",
    [5] = "THRUST CUT",
    [6] = "SIGNAL LOST",
    [7] = "AUTOROTATION",
    [8] = "BAILOUT",
    [100] = "GOV DISABLED",
    [101] = "COLD"
}
local STATE_COLORS = {
    [0] = C.amber,[1] = C.amber,[2] = C.magenta,[3] = C.amber,[4] = C.green,
    [5] = C.green,[6] = C.red,[7] = C.amber,[8] = C.red,[100] = C.muted,[101] = C.cyan
}

local function getReactorState(telemetry)
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
    if armed == false then return "COLD", C.cyan end
    local code = governor and floor(governor + 0.5) or nil
    if code == 101 then return "COLD", C.cyan end
    if armed == true then
        if code and STATE_LABELS[code] then return STATE_LABELS[code], STATE_COLORS[code] or C.red end
        return "ARMED", C.red
    end
    if code and STATE_LABELS[code] then return STATE_LABELS[code], STATE_COLORS[code] or C.cyan end
    return "STATE --", C.muted
end

local layout = {cols = 12, rows = 12, padding = 0}
local screenBorderStyle = {enabled = false}
local ORBIT_UNIT_64 = getOrbitUnit(64)
local INTEGRITY_RING_UNIT = getRingUnit(32, 0, 360)

local function postflightWakeup(box, telemetry)
    local c = box._cache or {}
    box._cache = c
    c.rpm = stat(telemetry, "rpm", "max", "headspeed", "erpm")
    local escUnit
    c.esc, escUnit = stat(telemetry, "temp_esc", "max", "esc_temp")
    local resolvedEscUnit = temperatureUnitLabel(escUnit)
    -- Rebuild the display suffix only when the temperature unit changes.
    if c.escUnit ~= resolvedEscUnit or c.escSuffix == nil then
        c.escUnit = resolvedEscUnit
        c.escSuffix = " " .. resolvedEscUnit
        c._escTextKey = nil
    end
    c.current = stat(telemetry, "current", "max")
    c.watts = stat(telemetry, "watts", "max")
    c.bec = stat(telemetry, "bec_voltage", "min", "bec")
    c.link = stat(telemetry, "vfr", "min", "rssi")
    c.fuel = stat(telemetry, "smartfuel", "min")
    c.consumed = stat(telemetry, "smartconsumption", "max", "consumption")
    c.voltage = stat(telemetry, "voltage", "min")
    c.altitude = stat(telemetry, "altitude", "max")
    updateFlightTime(c)

    updateFormatted(c, "_rpmTextKey", "rpmText", c.rpm, 0, " RPM")
    updateFormatted(c, "_currentTextKey", "currentText", c.current, 1, " A")
    updateFormatted(c, "_becTextKey", "becText", c.bec, 2, " V")
    updateFormatted(c, "_escTextKey", "escText", c.esc, 0, c.escSuffix)
    updateFormatted(c, "_wattsTextKey", "wattsText", c.watts, 0, " W")
    updateFormatted(c, "_linkTextKey", "linkText", c.link, 0, "%")

    local fuelKey = roundedKey(c.fuel, 0)
    local consumedKey = roundedKey(c.consumed, 0)
    local voltageKey = roundedKey(c.voltage, 1)
    local altitudeKey = roundedKey(c.altitude, 0)
    if c._summaryFuelKey ~= fuelKey or c._summaryConsumedKey ~= consumedKey or
        c._summaryVoltageKey ~= voltageKey or c._summaryAltitudeKey ~= altitudeKey or c.summaryText == nil then
        c._summaryFuelKey = fuelKey
        c._summaryConsumedKey = consumedKey
        c._summaryVoltageKey = voltageKey
        c._summaryAltitudeKey = altitudeKey
        c.summaryText = "ENERGY " .. fmt(c.fuel, 0, "%") .. "    CONSUMED " .. fmt(c.consumed, 0, " mAh") ..
            "    PACK " .. fmt(c.voltage, 1, " V") .. "    ALT " .. fmt(c.altitude, 0, " m")
    end

    c.escMax = temperatureThreshold(getThemeValue("esc_max"), c.escUnit)
    c.escWarn = temperatureThreshold(getThemeValue("esc_warn"), c.escUnit)
    c.becMin = getThemeValue("bec_min")
    c.becWarn = getThemeValue("bec_warn")
    c.fuelWarn = getThemeValue("fuel_warn")
    c.linkWarn = getThemeValue("link_warn")
    c.currentWarn = getThemeValue("current_warn")
    c.wattsWarn = getThemeValue("watts_warn")
    c.rpmMax = getThemeValue("rpm_max")

    local available = 0
    if c.rpm ~= nil then available = available + 1 end
    if c.esc ~= nil then available = available + 1 end
    if c.current ~= nil then available = available + 1 end
    if c.watts ~= nil then available = available + 1 end
    if c.bec ~= nil then available = available + 1 end
    if c.link ~= nil then available = available + 1 end
    if c.fuel ~= nil then available = available + 1 end
    if c.consumed ~= nil then available = available + 1 end
    if c.voltage ~= nil then available = available + 1 end
    if c.altitude ~= nil then available = available + 1 end

    local faults, cautions = 0, 0
    if c.esc and c.esc >= c.escMax then faults = faults + 1 elseif c.esc and c.esc >= c.escWarn then cautions = cautions + 1 end
    if c.bec and c.bec < c.becMin then faults = faults + 1 elseif c.bec and c.bec < c.becWarn then cautions = cautions + 1 end
    if c.fuel and c.fuel <= c.fuelWarn then cautions = cautions + 1 end
    if c.link and c.link < c.linkWarn then cautions = cautions + 1 end
    if c.current and c.current >= c.currentWarn then cautions = cautions + 1 end
    if c.watts and c.watts >= c.wattsWarn then cautions = cautions + 1 end
    if c.rpm and c.rpm > c.rpmMax * 1.05 then cautions = cautions + 1 end

    if available == 0 then
        c.mission = "NO FLIGHT DATA"
        c.missionColor = C.muted
        c.integrity = nil
        c.missionSub = "NO RECORDED TELEMETRY"
    elseif faults > 0 then
        c.mission = "SYSTEM INSPECTION"
        c.missionColor = C.red
        c.integrity = max(15, 55 - faults * 20 - cautions * 8)
        c.missionSub = "CRITICAL LIMIT EXCEEDED"
    elseif cautions > 0 then
        c.mission = "MISSION REVIEW"
        c.missionColor = C.amber
        c.integrity = max(55, 100 - cautions * 10)
        c.missionSub = cautions == 1 and "1 ANOMALY" or (tostring(cautions) .. " ANOMALIES")
    else
        c.mission = "MISSION NOMINAL"
        c.missionColor = C.green
        c.integrity = 100
        c.missionSub = "ALL SYSTEMS WITHIN LIMITS"
    end

    updateFormatted(c, "_integrityTextKey", "integrityText", c.integrity, 0, "%")

    return c
end

local function postflightPaint(x, y, w, h, box, c)
    c = c or box._cache or {}
    box._cache = c

    -- Safety net: if paint() runs before the first wakeup() cycle has
    -- populated the cache (e.g. very first frame), fall back to a live
    -- lookup so we never compare a number against a nil threshold.
    c.escUnit = c.escUnit or "°C"
    c.escSuffix = c.escSuffix or " °C"
    c.escMax = c.escMax or temperatureThreshold(getThemeValue("esc_max"), c.escUnit)
    c.escWarn = c.escWarn or temperatureThreshold(getThemeValue("esc_warn"), c.escUnit)
    c.becMin = c.becMin or getThemeValue("bec_min")
    c.becWarn = c.becWarn or getThemeValue("bec_warn")
    c.fuelWarn = c.fuelWarn or getThemeValue("fuel_warn")
    c.linkWarn = c.linkWarn or getThemeValue("link_warn")
    c.currentWarn = c.currentWarn or getThemeValue("current_warn")
    c.wattsWarn = c.wattsWarn or getThemeValue("watts_warn")
    c.rpmMax = c.rpmMax or getThemeValue("rpm_max")

    lcd.color(C.space)
    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))
    drawStars(x, y, w, h)

    drawTextAligned(x + 14, y + 8, w * 0.45, "SINGULARITY // MISSION DEBRIEF", "FONT_STD", C.violet, "left")
    drawTextAligned(x + w - 280, y + 8, 266, c.mission or "NO FLIGHT DATA", "FONT_STD", c.missionColor or C.muted, "right")

    local cx = x + w * 0.5
    local cy = y + h * 0.48
    local radius = min(w, h) * 0.19
    drawOrbit(cx, cy, radius * 1.65, radius * 0.70, C.line, 64, ORBIT_UNIT_64)
    drawOrbit(cx, cy, radius * 1.10, radius * 1.20, C.line, 64, ORBIT_UNIT_64)
    drawRingSegments(cx, cy, radius * 1.02, 32, c.integrity or 0, c.missionColor or C.muted, C.line, 11, 0, 360, INTEGRITY_RING_UNIT)
    drawHex(cx, cy, radius * 0.72, C.line2)
    drawHex(cx, cy, radius * 0.48, c.missionColor or C.muted)
    drawTextAligned(cx - radius, cy - (h < 330 and 27 or 45), radius * 2, c.integrityText or "--", h < 330 and "FONT_XL" or "FONT_XXL", c.integrity and C.white or C.muted, "center")
    drawTextAligned(cx - radius, cy + 12, radius * 2, "SYSTEM INTEGRITY", "FONT_XS", C.muted, "center")
    if h >= 330 then drawTextAligned(cx - radius, cy + 42, radius * 2, c.missionSub or "NO RECORDED TELEMETRY", "FONT_XXS", c.missionColor or C.muted, "center") end
    drawTextAligned(cx - radius, cy + radius * 1.28, radius * 2, c.flightTimeText or "FLIGHT TIME 00:00", "FONT_S", C.cyan, "center")

    local nw = floor(w * 0.19)
    local nh = floor((h - 82) / 3)
    local leftX = x + 14
    local rightX = x + w - nw - 14
    local y1 = y + 55
    local y2 = y1 + nh + 7
    local y3 = y2 + nh + 7

    local escColor = c.esc and (c.esc >= c.escMax and C.red or (c.esc >= c.escWarn and C.amber or C.green)) or C.muted
    local becColor = c.bec and (c.bec < c.becMin and C.red or (c.bec < c.becWarn and C.amber or C.cyan)) or C.muted
    local linkColor = c.link and (c.link < c.linkWarn and C.amber or C.cyan) or C.muted
    local fuelColor = c.fuel and (c.fuel <= c.fuelWarn and C.amber or C.green) or C.muted
    local rpmColor = c.rpm and (c.rpm > c.rpmMax * 1.05 and C.amber or C.violet) or C.muted
    local currentColor = c.current and (c.current >= c.currentWarn and C.red or C.cyan) or C.muted
    local wattsColor = c.watts and (c.watts >= c.wattsWarn and C.red or C.magenta) or C.muted

    drawNode(leftX, y1, nw, nh, "MAX HEADSPEED", c.rpmText or "--", rpmColor, "ORBITAL VELOCITY")
    drawNode(leftX, y2, nw, nh, "PEAK CURRENT", c.currentText or "--", currentColor, "REACTOR LOAD")
    drawNode(leftX, y3, nw, nh, "MIN BEC", c.becText or "--", becColor, "POWER CORE")

    drawNode(rightX, y1, nw, nh, "MAX ESC TEMP", c.escText or "--", escColor, "THERMAL PLUME")
    drawNode(rightX, y2, nw, nh, "PEAK POWER", c.wattsText or "--", wattsColor, "ENERGY RELEASE")
    drawNode(rightX, y3, nw, nh, "MIN LINK", c.linkText or "--", linkColor, "SIGNAL CONSTELLATION")

    drawTextAligned(cx - radius * 2.1, y + h - 46, radius * 4.2, c.summaryText or "ENERGY --    CONSUMED --    PACK --    ALT --", "FONT_XS", fuelColor, "center")
end

local boxes_cache
local function boxes()
    if not boxes_cache then boxes_cache = {{col=1,row=1,colspan=12,rowspan=12,type="func",subtype="func",wakeup=postflightWakeup,paint=postflightPaint,bgcolor="transparent"}} end
    return boxes_cache
end

return {layout=layout,boxes=boxes,header_boxes=header_boxes,header_layout=header_layout,screenBorderStyle=screenBorderStyle,scheduler={spread_scheduling=true,spread_scheduling_paint=false,spread_ratio=0.85}}
