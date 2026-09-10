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
local HEADER_SIGNATURE = " | MWRC"
local function drawHeaderTitle(x, y, w, h)
    lcd.color(C.panel)
    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))
    local signatureFont = utils.resolveFont("FONT_XXS", nil)
    if type(signatureFont) ~= "number" then return end
    lcd.font(signatureFont)
    local sw, sh = lcd.getTextSize(HEADER_SIGNATURE)
    local fontName = "FONT_S"
    local titleFont = utils.resolveFont(fontName, nil)
    if type(titleFont) ~= "number" then return end
    lcd.font(titleFont)
    local tw, th = lcd.getTextSize(HEADER_LABEL)
    -- Reserve room for the smaller builder signature when fitting the title.
    while (tw + sw > w - 20 or th > h) and FONT_FALLBACK[fontName] do
        fontName = FONT_FALLBACK[fontName]
        local smaller = utils.resolveFont(fontName, nil)
        if type(smaller) == "number" then
            lcd.font(smaller)
            tw, th = lcd.getTextSize(HEADER_LABEL)
        end
    end
    local tx = floor(x + (w - tw - sw) / 2)
    lcd.color(C.gold)
    lcd.drawText(tx, floor(y + (h - th) / 2), HEADER_LABEL)
    lcd.font(signatureFont)
    lcd.color(C.muted)
    lcd.drawText(tx + tw, floor(y + (h - sh) / 2), HEADER_SIGNATURE)
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
            if b.subtype == "craftname" then b.font = "FONT_S" end
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

local function updateFlightTime(cache)
    local session = rfsuite and rfsuite.session
    local seconds = session and session.timer and tonumber(session.timer.live) or 0
    seconds = floor(max(0, seconds))
    if cache._timerSecond ~= seconds or cache.timer == nil then
        cache._timerSecond = seconds
        cache.timer = format("%02d:%02d", floor(seconds / 60), seconds % 60)
    end
end

local function inflightWakeup(box, telemetry)
    local c = box._cache or {}
    box._cache = c
    c.rpm = sensor(telemetry, "rpm", "headspeed", "erpm")
    c.maxRpm = stat(telemetry, "rpm", "max", "headspeed", "erpm") or c.rpm
    c.throttle = sensor(telemetry, "throttle_percent", "throttle")
    local escUnit
    c.esc, escUnit = sensor(telemetry, "temp_esc", "esc_temp")
    local resolvedEscUnit = temperatureUnitLabel(escUnit)
    if c.escUnit ~= resolvedEscUnit then
        c.escUnit = resolvedEscUnit
        c._escTextKey = nil
    end
    c.fuel = sensor(telemetry, "smartfuel")
    c.current = sensor(telemetry, "current")
    c.watts = sensor(telemetry, "watts")
    c.bec = sensor(telemetry, "bec_voltage", "bec")
    c.link = sensor(telemetry, "vfr", "rssi")
    c.consumed = sensor(telemetry, "smartconsumption", "consumption")
    c.flightState, c.flightColor = getFlightState(telemetry)
    updateFlightTime(c)

    updateFormatted(c, "_escTextKey", "escText", c.esc, 0, c.escUnit)
    updateFormatted(c, "_throttleTextKey", "throttleText", c.throttle, 0, "%")
    updateFormatted(c, "_rpmTextKey", "rpmText", c.rpm, 0, "")
    updateFormatted(c, "_currentTextKey", "currentText", c.current, 1, " A")
    updateFormatted(c, "_wattsTextKey", "wattsText", c.watts, 0, " W")
    updateFormatted(c, "_becTextKey", "becText", c.bec, 1, " V")
    updateFormatted(c, "_linkTextKey", "linkText", c.link, 0, "%")
    updateFormatted(c, "_consumedTextKey", "consumedText", c.consumed, 0, " mAh")

    local maxRpmKey = roundedKey(c.maxRpm, 0)
    if c._maxRpmTextKey ~= maxRpmKey or c.maxRpmText == nil then
        c._maxRpmTextKey = maxRpmKey
        c.maxRpmText = "MAX " .. fmt(c.maxRpm, 0, " RPM")
    end
    local fuelKey = roundedKey(c.fuel, 0)
    if c._fuelTextKey ~= fuelKey or c.fuelText == nil then
        c._fuelTextKey = fuelKey
        c.fuelText = "FUEL " .. fmt(c.fuel, 0, "%")
    end

    -- Cache theme thresholds here (wakeup runs at a bounded rate) instead of
    -- calling getThemeValue() from paint(), which runs on every invalidate.
    c.escMax = temperatureThreshold(getThemeValue("esc_max"), c.escUnit)
    c.escWarn = temperatureThreshold(getThemeValue("esc_warn"), c.escUnit)
    c.fuelWarn = getThemeValue("fuel_warn")
    c.rpmMax = getThemeValue("rpm_max")
    c.currentWarn = getThemeValue("current_warn")
    c.wattsWarn = getThemeValue("watts_warn")
    c.becMin = getThemeValue("bec_min")
    c.becWarn = getThemeValue("bec_warn")
    c.linkWarn = getThemeValue("link_warn")

    return c
end

local function drawEmberColumn(x, y, w, h, value, maximum, valueText, color)
    drawPanel(x, y, w, h, color, "EMBER COLUMN")
    local pct = maximum > 0 and clamp((value or 0) / maximum, 0, 1) or 0
    local baseY = y + h - 27
    local active = floor(9 * pct + 0.999)
    for i = 0, 8 do
        local step = max(3, (h - 60) / 8)
        local cy = baseY - i * step
        drawDiamond(x + 28, cy, min(6, max(2, (h - 60) / 18)), i < active and color or C.line2, i < active and C.gold or nil)
    end
    drawTextAligned(x + 48, y + 31, w - 60, valueText, "FONT_L", value and C.white or C.muted, "left")
end

local function drawThrustRibbon(x, y, w, h, throttle, valueText, color)
    drawPanel(x, y, w, h, color, "THRUST RIBBON")
    local pct = clamp((throttle or 0) / 100, 0, 1)
    local active = floor(10 * pct + 0.999)
    for i = 0, 9 do
        local bh = max(2, (h - 72) * (0.20 + i * 0.08))
        local bx = x + 16 + i * floor((w - 34) / 10)
        local by = y + h - 24 - bh
        lcd.color(i < active and (i % 2 == 0 and C.turquoise or C.fuchsia) or C.line)
        lcd.drawFilledRectangle(floor(bx), floor(by), 6, bh)
    end
    drawTextAligned(x + 16, y + 27, w - 32, valueText, "FONT_L", throttle and C.white or C.muted, "center")
end

local FEATHER_COUNT = 25
local FEATHER_UNIT = {}
for i = 0, FEATHER_COUNT - 1 do
    local angle = 150 + 240 * i / (FEATHER_COUNT - 1)
    local a = rad(angle)
    FEATHER_UNIT[i + 1] = {
        cos(a),
        sin(a),
        0.88 + 0.08 * sin(pi * i / (FEATHER_COUNT - 1)),
    }
end

local function drawPlumeGauge(cx, cy, radius, rpm, maximum, color)
    local pct = maximum > 0 and clamp((rpm or 0) / maximum, 0, 1) or 0
    local feathers = FEATHER_COUNT
    local active = floor(feathers * pct + 0.5)
    for i = 0, feathers - 1 do
        local u = FEATHER_UNIT[i + 1]
        local ca, sa, outerMod = u[1], u[2], u[3]
        local inner = radius * 0.58
        local outer = radius * outerMod
        local x1, y1 = cx + ca * inner, cy + sa * inner
        local x2, y2 = cx + ca * outer, cy + sa * outer
        local featherColor = i < active and (i % 3 == 0 and C.gold or color) or C.line
        lcd.color(featherColor)
        lcd.drawLine(floor(x1), floor(y1), floor(x2), floor(y2))
        drawDiamond(x2, y2, i < active and 5 or 3, featherColor, i < active and C.white or nil)
    end
    drawPetal(cx, cy + radius * 0.48, radius * 0.52, radius * 0.11, 270, C.fuchsia)
    drawPetal(cx, cy + radius * 0.48, radius * 0.52, radius * 0.11, 250, C.turquoise)
    drawPetal(cx, cy + radius * 0.48, radius * 0.52, radius * 0.11, 290, C.gold)
end

local function inflightPaint(x, y, w, h, box, c)
    c = c or box._cache or {}
    box._cache = c

    -- Safety net: if paint() runs before the first wakeup() cycle has
    -- populated the cache (e.g. very first frame), fall back to a live
    -- lookup so we never compare a number against a nil threshold.
    c.escUnit = c.escUnit or "°C"
    c.escMax = c.escMax or temperatureThreshold(getThemeValue("esc_max"), c.escUnit)
    c.escWarn = c.escWarn or temperatureThreshold(getThemeValue("esc_warn"), c.escUnit)
    c.fuelWarn = c.fuelWarn or getThemeValue("fuel_warn")
    c.rpmMax = c.rpmMax or getThemeValue("rpm_max")
    c.currentWarn = c.currentWarn or getThemeValue("current_warn")
    c.wattsWarn = c.wattsWarn or getThemeValue("watts_warn")
    c.becMin = c.becMin or getThemeValue("bec_min")
    c.becWarn = c.becWarn or getThemeValue("bec_warn")
    c.linkWarn = c.linkWarn or getThemeValue("link_warn")

    lcd.color(C.bg); lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))
    drawLattice(x, y, w, h)

    drawTextAligned(x + 14, y + 7, w * 0.46, "ZAFIRA // FLIGHT", "FONT_STD", C.gold, "left")
    drawTextAligned(x + w * 0.35, y + 2, w * 0.30, c.timer or "00:00", "FONT_XL", C.white, "center")
    drawTextAligned(x + w - 300, y + 8, 286, c.flightState or "STATE --", "FONT_STD", c.flightColor or C.muted, "right")

    local bodyY, bodyH = y + 43, h - 55
    local sideW = floor(w * 0.205)
    local leftX, rightX = x + 12, x + w - sideW - 12
    local centerX = leftX + sideW + 12
    local centerW = w - sideW * 2 - 48
    local halfH = floor((bodyH - 10) / 2)

    local escColor = c.esc and (c.esc >= c.escMax and C.red or (c.esc >= c.escWarn and C.amber or C.emerald)) or C.muted
    local throttleColor = c.throttle and C.turquoise or C.muted
    drawEmberColumn(leftX, bodyY, sideW, halfH, c.esc, c.escMax, c.escText or "--", escColor)
    drawThrustRibbon(leftX, bodyY + halfH + 10, sideW, halfH, c.throttle, c.throttleText or "--", throttleColor)

    drawPanel(centerX, bodyY, centerW, bodyH, C.gold, nil)
    local cx, cy = centerX + centerW * 0.5, bodyY + bodyH * 0.49
    local radius = min(centerW, bodyH) * 0.43
    local rpmMax = c.rpmMax
    local rpmColor = c.rpm and (c.rpm > rpmMax and C.red or C.violet) or C.muted
    local fuel = c.fuel or 0
    local fuelColor = c.fuel and (fuel <= c.fuelWarn and C.red or (fuel <= 50 and C.amber or C.emerald)) or C.muted
    drawPlumeGauge(cx, cy, radius, c.rpm, rpmMax, rpmColor)
    drawDiamond(cx, cy, radius * 0.42, C.gold, C.fuchsia)
    drawDiamond(cx, cy, radius * 0.27, c.flightColor or C.turquoise, C.white)
    lcd.color(C.panel)
    lcd.drawFilledRectangle(floor(cx - radius * 0.62), floor(cy - 44), floor(radius * 1.24), 108)
    drawTextAligned(cx - radius, cy - 44, radius * 2, c.rpmText or "--", "FONT_XXL", c.rpm and C.white or C.muted, "center")
    drawTextAligned(cx - radius, cy + 6, radius * 2, "HEADSPEED RPM", "FONT_XS", C.muted, "center")
    drawTextAligned(cx - radius, cy + 35, radius * 2, c.flightState or "STATE --", "FONT_XS", c.flightColor or C.muted, "center")

    local gemsY = bodyY + bodyH - 54
    drawGemLine(centerX + 42, gemsY, centerW - 84, 12, fuel, fuelColor, C.line2)
    drawTextAligned(centerX + 18, bodyY + bodyH - 30, centerW - 36, c.maxRpmText or "MAX --", "FONT_XXS", c.maxRpm and C.gold or C.muted, "left")
    drawTextAligned(centerX + 18, bodyY + bodyH - 30, centerW - 36, c.fuelText or "FUEL --", "FONT_XXS", fuelColor, "right")

    local currentColor = c.current and (c.current >= c.currentWarn and C.red or C.fuchsia) or C.muted
    local wattsColor = c.watts and (c.watts >= c.wattsWarn and C.red or C.violet) or C.muted
    local becColor = c.bec and (c.bec < c.becMin and C.red or (c.bec < c.becWarn and C.amber or C.turquoise)) or C.muted
    local linkColor = c.link and (c.link < c.linkWarn and C.amber or C.turquoise) or C.muted
    local consumedColor = c.consumed and C.gold or C.muted
    local nodeH = floor((bodyH - 30) / 4)
    drawMetric(rightX, bodyY, sideW, nodeH, "RUBY CURRENT", c.currentText or "--", currentColor, c.wattsText or "--")
    drawMetric(rightX, bodyY + nodeH + 10, sideW, nodeH, "SAPPHIRE BEC", c.becText or "--", becColor, "power clarity")
    drawMetric(rightX, bodyY + (nodeH + 10) * 2, sideW, nodeH, "TURQUOISE LINK", c.linkText or "--", linkColor, "radio clarity")
    drawMetric(rightX, bodyY + (nodeH + 10) * 3, sideW, nodeH, "GOLD CONSUMED", c.consumedText or "--", consumedColor, "flight energy")
end

local boxes_cache
local function boxes()
    if not boxes_cache then boxes_cache = {{col=1,row=1,colspan=12,rowspan=12,type="func",subtype="func",wakeup=inflightWakeup,paint=inflightPaint,bgcolor="transparent"}} end
    return boxes_cache
end
return {layout=layout,boxes=boxes,header_boxes=header_boxes,header_layout=header_layout,screenBorderStyle=screenBorderStyle,scheduler={spread_scheduling=true,spread_scheduling_paint=false,spread_ratio=0.85}}
