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
local tonumber = tonumber
local tostring = tostring
local type = type
local format = string.format
local ipairs = ipairs

local utils = rfsuite.widgets.dashboard.utils
local headeropts = utils.getHeaderOptions()
local colorMode = utils.themeColors()
local header_layout = utils.standardHeaderLayout(headeropts)

local C = {
    space = lcd.RGB(3, 5, 12),
    void = lcd.RGB(0, 0, 3),
    panel = lcd.RGB(8, 12, 24),
    panel2 = lcd.RGB(13, 18, 34),
    line = lcd.RGB(37, 57, 87),
    line2 = lcd.RGB(75, 101, 140),
    white = lcd.RGB(228, 240, 255),
    muted = lcd.RGB(122, 147, 177),
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

local THEME_SECTION = "system/singularity"
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
    local session = rfsuite and rfsuite.session
    local prefs = session and session.modelPreferences and session.modelPreferences[THEME_SECTION]
    local value = prefs and tonumber(prefs[key])
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

local function resolveFont(name)
    return utils.resolveFont(name, nil)
end

local function drawTextAligned(x, y, w, text, fontName, color, align)
    local font = resolveFont(fontName)
    if type(font) ~= "number" then return 0, 0 end
    lcd.font(font)
    lcd.color(color)
    local tw, th = lcd.getTextSize(text)
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
    drawTextAligned(x + 11, y + 28, w - 22, value, "FONT_L", C.white, "left")
    if subtitle then drawTextAligned(x + 11, y + h - 22, w - 22, subtitle, "FONT_XXS", C.muted, "left") end
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

local function drawHeaderTitle(x, y, w, h)
    lcd.color(C.space)
    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))
    local t1, t2, t3 = "ETHOS ", "// ", "ROTORFLIGHT"
    local font = resolveFont("FONT_L")
    if type(font) ~= "number" then return end
    lcd.font(font)
    local w1, th = lcd.getTextSize(t1)
    local w2 = lcd.getTextSize(t2)
    local w3 = lcd.getTextSize(t3)

    local watermarkFont = resolveFont("FONT_XS")
    local watermarkText = "MWRC"
    local watermarkWidth, watermarkHeight = 0, 0
    if type(watermarkFont) == "number" then
        lcd.font(watermarkFont)
        watermarkWidth, watermarkHeight = lcd.getTextSize(watermarkText)
        lcd.font(font)
    end

    local titleWidth = w1 + w2 + w3
    local dividerGap = watermarkWidth > 0 and 14 or 0
    local total = titleWidth + dividerGap + watermarkWidth
    local tx = floor(x + (w - total) / 2)
    local ty = floor(y + (h - th) / 2)
    lcd.color(C.violet)
    lcd.drawText(tx, ty, t1)
    lcd.color(C.cyan)
    lcd.drawText(tx + w1, ty, t2)
    lcd.color(C.white)
    lcd.drawText(tx + w1 + w2, ty, t3)

    if watermarkWidth > 0 then
        local dividerX = tx + titleWidth + 6
        lcd.color(C.line2)
        lcd.drawLine(dividerX, y + 7, dividerX, y + h - 7)
        lcd.font(watermarkFont)
        lcd.color(C.magenta)
        lcd.drawText(dividerX + 7, floor(y + (h - watermarkHeight) / 2), watermarkText)
    end
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

local function flightTimeText()
    local session = rfsuite and rfsuite.session
    local seconds = session and session.timer and tonumber(session.timer.live) or 0
    seconds = max(0, seconds)
    return format("%02d:%02d", floor(seconds / 60), floor(seconds % 60))
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
local RPM_RING_UNIT = getRingUnit(36, 145, 250)
local FUEL_RING_UNIT = getRingUnit(30, 0, 360)

local function inflightWakeup(box, telemetry)
    local c = box._cache or {maxRpm = 0}
    box._cache = c
    c.rpm = sensor(telemetry, "rpm", "headspeed", "erpm") or 0
    c.maxRpm = stat(telemetry, "rpm", "max", "headspeed", "erpm") or c.rpm
    c.throttle = sensor(telemetry, "throttle_percent", "throttle") or 0
    local escUnit
    c.esc, escUnit = sensor(telemetry, "temp_esc", "esc_temp")
    local resolvedEscUnit = temperatureUnitLabel(escUnit)
    -- Rebuild the display suffix only when the temperature unit changes.
    if c.escUnit ~= resolvedEscUnit or c.escSuffix == nil then
        c.escUnit = resolvedEscUnit
        c.escSuffix = " " .. resolvedEscUnit
    end
    c.fuel = sensor(telemetry, "smartfuel")
    c.current = sensor(telemetry, "current")
    c.watts = sensor(telemetry, "watts")
    c.bec = sensor(telemetry, "bec_voltage", "bec")
    c.link = sensor(telemetry, "vfr")
    c.consumed = sensor(telemetry, "smartconsumption", "consumption")
    c.reactorState, c.reactorColor = getReactorState(telemetry)
    c.timer = flightTimeText()

    -- Cache theme-configured thresholds here (wakeup runs on a rate-limited
    -- cycle) instead of calling getThemeValue() from paint(), which runs on
    -- every invalidate.
    c.escMax = temperatureThreshold(getThemeValue("esc_max"), c.escUnit)
    c.escWarn = temperatureThreshold(getThemeValue("esc_warn"), c.escUnit)
    c.rpmMax = getThemeValue("rpm_max")
    c.fuelWarn = getThemeValue("fuel_warn")
    c.currentWarn = getThemeValue("current_warn")
    c.wattsWarn = getThemeValue("watts_warn")
    c.becMin = getThemeValue("bec_min")
    c.becWarn = getThemeValue("bec_warn")
    c.linkWarn = getThemeValue("link_warn")
    return c
end

local function drawThermalPlume(x, y, w, h, value, maximum, color, suffix)
    drawPanel(x, y, w, h, color, "THERMAL PLUME")
    local pct = maximum > 0 and clamp((value or 0) / maximum, 0, 1) or 0
    local baseY = y + h - 28
    local center = x + w * 0.5
    for i = 0, 7 do
        local bh = floor((h - 68) * pct * (0.48 + i / 15))
        local bw = 5 + (i % 3) * 2
        local bx = floor(center - 32 + i * 9)
        lcd.color(i < 3 and C.cyanDim or color)
        lcd.drawFilledRectangle(bx, floor(baseY - bh), bw, bh)
    end
    drawTextAligned(x + 10, y + 30, w - 20, fmt(value,0,suffix), "FONT_L", C.white, "center")
end

local function drawThrustArray(x, y, w, h, throttle)
    drawPanel(x, y, w, h, C.cyan, "THRUST ARRAY")
    local pct = clamp((throttle or 0) / 100, 0, 1)
    local bars = 10
    local gap = 4
    local bw = floor((w - 24 - gap * (bars - 1)) / bars)
    for i = 0, bars - 1 do
        local bh = 14 + i * 5
        local bx = x + 12 + i * (bw + gap)
        local by = y + h - 20 - bh
        lcd.color(i < floor(pct * bars + 0.999) and C.cyan or C.line)
        lcd.drawFilledRectangle(floor(bx), floor(by), bw, bh)
    end
    drawTextAligned(x + 10, y + 30, w - 20, fmt(throttle,0,"%"), "FONT_L", C.white, "center")
end

local function inflightPaint(x, y, w, h, box, c)
    c = c or box._cache or {}

    -- Safety net: if paint() runs before the first wakeup() cycle has
    -- populated the cache (e.g. very first frame), fall back to a live
    -- lookup so we never compare a number against a nil threshold.
    c.escUnit = c.escUnit or "°C"
    c.escSuffix = c.escSuffix or " °C"
    c.escMax = c.escMax or temperatureThreshold(getThemeValue("esc_max"), c.escUnit)
    c.escWarn = c.escWarn or temperatureThreshold(getThemeValue("esc_warn"), c.escUnit)
    c.rpmMax = c.rpmMax or getThemeValue("rpm_max")
    c.fuelWarn = c.fuelWarn or getThemeValue("fuel_warn")
    c.currentWarn = c.currentWarn or getThemeValue("current_warn")
    c.wattsWarn = c.wattsWarn or getThemeValue("watts_warn")
    c.becMin = c.becMin or getThemeValue("bec_min")
    c.becWarn = c.becWarn or getThemeValue("bec_warn")
    c.linkWarn = c.linkWarn or getThemeValue("link_warn")

    lcd.color(C.space)
    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))
    drawStars(x, y, w, h)

    drawTextAligned(x + 14, y + 8, w * 0.45, "SINGULARITY // FLIGHT", "FONT_STD", C.violet, "left")
    drawTextAligned(x + w * 0.35, y + 3, w * 0.30, c.timer or "00:00", "FONT_XL", C.white, "center")
    drawTextAligned(x + w - 250, y + 9, 236, c.reactorState or "STATE --", "FONT_STD", c.reactorColor or C.muted, "right")

    local bodyY = y + 44
    local bodyH = h - 56
    local sideW = floor(w * 0.21)
    local leftX = x + 12
    local rightX = x + w - sideW - 12
    local centerX = leftX + sideW + 12
    local centerW = w - sideW * 2 - 48

    local halfH = floor((bodyH - 10) / 2)
    local escColor = c.esc and (c.esc >= c.escMax and C.red or (c.esc >= c.escWarn and C.amber or C.green)) or C.muted
    drawThermalPlume(leftX, bodyY, sideW, halfH, c.esc, c.escMax, escColor, c.escSuffix)
    drawThrustArray(leftX, bodyY + halfH + 10, sideW, halfH, c.throttle)

    drawPanel(centerX, bodyY, centerW, bodyH, C.violet, nil)
    local cx = centerX + centerW * 0.5
    local cy = bodyY + bodyH * 0.47
    local radius = min(centerW, bodyH) * 0.40
    local rpmMax = c.rpmMax
    local rpmPct = rpmMax > 0 and clamp((c.rpm or 0) / rpmMax * 100, 0, 100) or 0
    local fuel = c.fuel or 0
    local fuelColor = c.fuel and (fuel <= c.fuelWarn and C.red or (fuel <= 50 and C.amber or C.green)) or C.muted
    local rpmColor = (c.rpm or 0) > rpmMax and C.red or C.violet

    drawOrbit(cx, cy, radius * 1.12, radius * 0.54, C.line, 64, ORBIT_UNIT_64)
    drawOrbit(cx, cy, radius * 0.78, radius * 1.10, C.line, 64, ORBIT_UNIT_64)
    drawRingSegments(cx, cy, radius * 1.05, 36, rpmPct, rpmColor, C.line, 13, 145, 250, RPM_RING_UNIT)
    drawRingSegments(cx, cy, radius * 0.86, 30, fuel, fuelColor, C.line, 10, 0, 360, FUEL_RING_UNIT)
    drawHex(cx, cy, radius * 0.62, C.line2)
    drawHex(cx, cy, radius * 0.44, c.reactorColor or C.muted)
    drawHex(cx, cy, radius * 0.26, C.violet)

    drawTextAligned(cx - radius, cy - 58, radius * 2, fmt(c.rpm,0,""), "FONT_XXL", C.white, "center")
    drawTextAligned(cx - radius, cy - 2, radius * 2, "HEADSPEED", "FONT_XS", C.muted, "center")
    drawTextAligned(cx - radius, cy + 24, radius * 2, c.reactorState or "STATE --", "FONT_S", c.reactorColor or C.muted, "center")
    drawTextAligned(cx - radius, cy + 52, radius * 2, "EVENT HORIZON", "FONT_XXS", C.violet, "center")
    drawTextAligned(centerX + 18, bodyY + bodyH - 34, centerW - 36, "MAX " .. fmt(c.maxRpm,0," RPM"), "FONT_XS", C.amber, "left")
    drawTextAligned(centerX + 18, bodyY + bodyH - 34, centerW - 36, "ENERGY " .. fmt(c.fuel,0,"%"), "FONT_XS", fuelColor, "right")

    local currentColor = c.current and c.current >= c.currentWarn and C.red or C.cyan
    local wattsColor = c.watts and c.watts >= c.wattsWarn and C.red or C.violet
    local becColor = c.bec and (c.bec < c.becMin and C.red or (c.bec < c.becWarn and C.amber or C.cyan)) or C.muted
    local linkColor = c.link and (c.link < c.linkWarn and C.amber or C.cyan) or C.muted

    local nodeH = floor((bodyH - 30) / 4)
    drawNode(rightX, bodyY, sideW, nodeH, "REACTOR LOAD", fmt(c.current,1," A"), currentColor, fmt(c.watts,0," W"))
    drawNode(rightX, bodyY + nodeH + 10, sideW, nodeH, "POWER CORE", fmt(c.bec,1," V"), becColor, "BEC STABILITY")
    drawNode(rightX, bodyY + (nodeH + 10) * 2, sideW, nodeH, "SIGNAL CONSTELLATION", fmt(c.link,0,"%"), linkColor, "LINK LOCK")
    drawNode(rightX, bodyY + (nodeH + 10) * 3, sideW, nodeH, "MATTER CONSUMED", fmt(c.consumed,0," mAh"), wattsColor, "FLIGHT ENERGY")
end

local boxes_cache
local function boxes()
    if not boxes_cache then boxes_cache = {{col=1,row=1,colspan=12,rowspan=12,type="func",subtype="func",wakeup=inflightWakeup,paint=inflightPaint,bgcolor="transparent"}} end
    return boxes_cache
end

return {layout=layout,boxes=boxes,header_boxes=header_boxes,header_layout=header_layout,screenBorderStyle=screenBorderStyle,scheduler={spread_scheduling=true,spread_scheduling_paint=false,spread_ratio=0.85}}
