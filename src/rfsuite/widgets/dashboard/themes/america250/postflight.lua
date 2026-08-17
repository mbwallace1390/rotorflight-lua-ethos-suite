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

local utils = rfsuite.widgets.dashboard.utils
local headeropts = utils.getHeaderOptions()
local colorMode = utils.themeColors()
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

        -- Keep the native ETHOS header widgets, but replace the stock logo
        -- with the shared America 250 / MWRC title treatment.
        for _, headerBox in ipairs(boxes) do
            if headerBox.type == "image" then
                headerBox.type = "func"
                headerBox.subtype = "func"
                headerBox.bgcolor = "transparent"
                headerBox.paint = function(x, y, w, h)
                    local headerBg = colorMode.tbbgcolor or colorMode.bgcolor
                    if type(headerBg) == "number" then
                        lcd.color(headerBg)
                        lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))
                    end

                    local font = utils.resolveFont("FONT_L", nil)
                    if type(font) ~= "number" then return end
                    lcd.font(font)

                    local t1, t2, t3 = "ETHOS ", "// ", "ROTORFLIGHT"
                    local tw1, th = lcd.getTextSize(t1)
                    local tw2 = lcd.getTextSize(t2)
                    local tw3 = lcd.getTextSize(t3)

                    local watermarkFont = utils.resolveFont("FONT_XS", nil)
                    local watermarkText = "MWRC"
                    local watermarkWidth, watermarkHeight = 0, 0
                    if type(watermarkFont) == "number" then
                        lcd.font(watermarkFont)
                        watermarkWidth, watermarkHeight = lcd.getTextSize(watermarkText)
                        lcd.font(font)
                    end

                    local titleW = tw1 + tw2 + tw3
                    local dividerGap = watermarkWidth > 0 and 14 or 0
                    local totalW = titleW + dividerGap + watermarkWidth
                    local tx = floor(x + (w - totalW) / 2)
                    local ty = floor(y + (h - th) / 2)

                    lcd.color(C.white)
                    lcd.drawText(tx, ty, t1)
                    lcd.color(C.amber)
                    lcd.drawText(tx + tw1, ty, t2)
                    lcd.color(C.white)
                    lcd.drawText(tx + tw1 + tw2, ty, t3)

                    if watermarkWidth > 0 then
                        local dividerX = tx + titleW + 6
                        lcd.color(C.line2)
                        lcd.drawLine(dividerX, y + 7, dividerX, y + h - 7)
                        lcd.font(watermarkFont)
                        lcd.color(C.red)
                        lcd.drawText(dividerX + 7, floor(y + (h - watermarkHeight) / 2), watermarkText)
                    end
                end
            end
        end

        header_boxes_cache = boxes
        last_txbatt_type = txbatt_type
    end
    return header_boxes_cache
end

local THEME_SECTION = "system/america250"
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
    bg = lcd.RGB(4, 14, 31),
    panel = lcd.RGB(8, 24, 47),
    panel2 = lcd.RGB(12, 34, 61),
    line = lcd.RGB(68, 91, 116),
    line2 = lcd.RGB(153, 126, 72),
    white = lcd.RGB(240, 231, 207),
    muted = lcd.RGB(160, 174, 187),
    cyan = lcd.RGB(49, 120, 198),
    cyanDim = lcd.RGB(19, 55, 94),
    green = lcd.RGB(86, 188, 125),
    greenDim = lcd.RGB(26, 79, 51),
    amber = lcd.RGB(216, 170, 78),
    amberDim = lcd.RGB(92, 61, 18),
    red = lcd.RGB(184, 48, 49),
    redDim = lcd.RGB(83, 24, 29),
    violet = lcd.RGB(184, 194, 207),
    violetDim = lcd.RGB(70, 80, 94)
}

-- Cached red -> parchment white -> patriotic blue gradient. It is created
-- once when the theme loads so postflight painting only replays draw calls.
local PATRIOTIC_GRADIENT = {}
local GRADIENT_STEPS = 18

local function lerp(a, b, t)
    return floor(a + (b - a) * t + 0.5)
end

local function buildPatrioticGradient()
    local red = {184, 48, 49}
    local white = {240, 231, 207}
    local blue = {49, 120, 198}

    for i = 0, GRADIENT_STEPS - 1 do
        local t = i / max(1, GRADIENT_STEPS - 1)
        local a, b, localT
        if t <= 0.5 then
            a, b, localT = red, white, t * 2
        else
            a, b, localT = white, blue, (t - 0.5) * 2
        end

        PATRIOTIC_GRADIENT[i + 1] = lcd.RGB(
            lerp(a[1], b[1], localT),
            lerp(a[2], b[2], localT),
            lerp(a[3], b[3], localT)
        )
    end
end

buildPatrioticGradient()

local function drawPatrioticGradient(x, y, w, h, reverse)
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    if w <= 0 or h <= 0 then return end

    local lastX = x
    for i = 1, GRADIENT_STEPS do
        local nextX = x + floor(i * w / GRADIENT_STEPS)
        local colorIndex = reverse and (GRADIENT_STEPS - i + 1) or i
        lcd.color(PATRIOTIC_GRADIENT[colorIndex])
        lcd.drawFilledRectangle(lastX, y, max(1, nextX - lastX), h)
        lastX = nextX
    end
end

local function drawPatrioticTitleRail(x, y, w)
    drawPatrioticGradient(x, y, w, 4)
end

local function drawPatrioticTitle(x, y, w)
    local font = utils.resolveFont("FONT_STD", nil)
    if type(font) ~= "number" then return end
    lcd.font(font)

    local a, b, c, d = "AMERICA ", "250", "  //  ", "MISSION DEBRIEF"
    local aw = lcd.getTextSize(a)
    local bw = lcd.getTextSize(b)
    local cw = lcd.getTextSize(c)
    local dw = lcd.getTextSize(d)
    local total = aw + bw + cw + dw
    local tx = x + max(0, (w - total) / 2)

    lcd.color(C.red)
    lcd.drawText(floor(tx), floor(y), a)
    lcd.color(C.white)
    lcd.drawText(floor(tx + aw), floor(y), b)
    lcd.color(C.amber)
    lcd.drawText(floor(tx + aw + bw), floor(y), c)
    lcd.color(C.cyan)
    lcd.drawText(floor(tx + aw + bw + cw), floor(y), d)
end

local function getThemeValue(key)
    local session = rfsuite and rfsuite.session
    local prefs = session and session.modelPreferences and session.modelPreferences[THEME_SECTION]
    local value = prefs and tonumber(prefs[key])

    if key == "bec_warn" and value == 8 then value = 7.0 end
    return value or DEFAULTS[key]
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

    if align == "center" then
        tx = x + (w - tw) / 2
    elseif align == "right" then
        tx = x + w - tw
    end

    lcd.drawText(floor(tx + 0.5), floor(y + 0.5), text)
    return tw, th
end

local function drawCenteredDotLine(x, y, w, leftText, rightText, fontName, textColor, dotColor)
    local font = resolveFont(fontName)
    if type(font) ~= "number" then return end
    lcd.font(font)

    local leftW, textH = lcd.getTextSize(leftText)
    local rightW = lcd.getTextSize(rightText)
    local dotSize = 3
    local gap = 7
    local totalW = leftW + gap + dotSize + gap + rightW
    local tx = floor(x + (w - totalW) / 2 + 0.5)
    local ty = floor(y + 0.5)

    lcd.color(textColor)
    lcd.drawText(tx, ty, leftText)

    local dotX = tx + leftW + gap
    local dotY = floor(y + (textH - dotSize) / 2 + 0.5)
    lcd.color(dotColor or textColor)
    lcd.drawFilledRectangle(dotX, dotY, dotSize, dotSize)

    lcd.color(textColor)
    lcd.drawText(dotX + dotSize + gap, ty, rightText)
end

local function drawCenteredTripleDotLine(x, y, w, leftText, middleText, rightText, fontName, textColor, dotColor)
    local font = resolveFont(fontName)
    if type(font) ~= "number" then return end
    lcd.font(font)

    local leftW, textH = lcd.getTextSize(leftText)
    local middleW = lcd.getTextSize(middleText)
    local rightW = lcd.getTextSize(rightText)
    local dotSize = 3
    local gap = 7
    local totalW = leftW + middleW + rightW + dotSize * 2 + gap * 4
    local tx = floor(x + (w - totalW) / 2 + 0.5)
    local ty = floor(y + 0.5)
    local dotY = floor(y + (textH - dotSize) / 2 + 0.5)

    lcd.color(textColor)
    lcd.drawText(tx, ty, leftText)

    local dot1X = tx + leftW + gap
    lcd.color(dotColor or textColor)
    lcd.drawFilledRectangle(dot1X, dotY, dotSize, dotSize)

    local middleX = dot1X + dotSize + gap
    lcd.color(textColor)
    lcd.drawText(middleX, ty, middleText)

    local dot2X = middleX + middleW + gap
    lcd.color(dotColor or textColor)
    lcd.drawFilledRectangle(dot2X, dotY, dotSize, dotSize)

    lcd.color(textColor)
    lcd.drawText(dot2X + dotSize + gap, ty, rightText)
end

local function drawPanel(x, y, w, h, accent, title)
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)

    lcd.color(C.panel)
    lcd.drawFilledRectangle(x, y, w, h)
    lcd.color(C.line)
    lcd.drawRectangle(x, y, w, h, 1)
    lcd.color(C.line2)
    lcd.drawRectangle(x + 2, y + 2, max(1, w - 4), max(1, h - 4), 1)

    drawPatrioticGradient(x + 3, y + 3, max(1, w - 6), 3)

    lcd.color(accent or C.cyan)
    lcd.drawFilledRectangle(x + 3, y + 6, 3, max(1, h - 9))

    if title then
        drawTextAligned(x + 13, y + 8, w - 24, title, "FONT_XXS", C.muted, "left")
    end
end

local function drawShield(cx, cy, w, h, color)
    local top = cy - h * 0.50
    local left = cx - w * 0.50
    local right = cx + w * 0.50
    local shoulder = cy - h * 0.18
    local lower = cy + h * 0.20
    local tip = cy + h * 0.52

    lcd.color(color)
    lcd.drawLine(floor(left), floor(top), floor(right), floor(top))
    lcd.drawLine(floor(left), floor(top), floor(left), floor(shoulder))
    lcd.drawLine(floor(right), floor(top), floor(right), floor(shoulder))
    lcd.drawLine(floor(left), floor(shoulder), floor(cx - w * 0.34), floor(lower))
    lcd.drawLine(floor(right), floor(shoulder), floor(cx + w * 0.34), floor(lower))
    lcd.drawLine(floor(cx - w * 0.34), floor(lower), floor(cx), floor(tip))
    lcd.drawLine(floor(cx + w * 0.34), floor(lower), floor(cx), floor(tip))
end

local STAR_UNIT = {}
for i = 0, 9 do
    local a = rad(-90 + i * 36)
    STAR_UNIT[i + 1] = {cos(a), sin(a)}
end

local function drawStar(cx, cy, outerRadius, innerRadius, color)
    -- Stream vertices to avoid allocating eleven temporary tables per call.
    innerRadius = innerRadius or outerRadius * 0.45
    lcd.color(color)
    local firstx, firsty, px, py
    for i = 0, 9 do
        local radius = (i % 2 == 0) and outerRadius or innerRadius
        local u = STAR_UNIT[i + 1]
        local sx = floor(cx + u[1] * radius)
        local sy = floor(cy + u[2] * radius)
        if i == 0 then firstx, firsty = sx, sy else lcd.drawLine(px, py, sx, sy) end
        px, py = sx, sy
    end
    lcd.drawLine(px, py, firstx, firsty)
end

local function starColor(index)
    local phase = (index - 1) % 3
    if phase == 0 then return C.red end
    if phase == 1 then return C.white end
    return C.cyan
end

local function drawAnniversaryStars(cx, yTop, yBottom)
    for i = 1, 7 do
        drawStar(cx - 54 + (i - 1) * 18, yTop, 3, 1.35, starColor(i))
    end
    for i = 1, 6 do
        drawStar(cx - 45 + (i - 1) * 18, yBottom, 3, 1.35, starColor(i + 7))
    end
end

local function drawProgress(x, y, w, h, percent, accent)
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    percent = max(0, min(1, percent or 0))

    lcd.color(C.line)
    lcd.drawRectangle(x, y, w, h, 1)

    local fillW = floor((w - 4) * percent)
    if fillW <= 0 then return end

    if accent == C.red or accent == C.amber then
        lcd.color(accent)
        lcd.drawFilledRectangle(x + 2, y + 2, fillW, max(1, h - 4))
    else
        drawPatrioticGradient(x + 2, y + 2, fillW, max(1, h - 4))
    end
end

local layout = {cols = 12, rows = 12, padding = 0}
local screenBorderStyle = {enabled = false}

local function stat(telemetry, source, statType, alias1, alias2)
    telemetry = telemetry or (rfsuite.tasks and rfsuite.tasks.telemetry)
    local stats = telemetry and telemetry.sensorStats
    local data = stats and stats[source]
    local value = data and data[statType]

    if value ~= nil then return tonumber(value) end

    if alias1 then
        data = stats and stats[alias1]
        value = data and data[statType]
        if value ~= nil then return tonumber(value) end
    end

    if alias2 then
        data = stats and stats[alias2]
        value = data and data[statType]
        if value ~= nil then return tonumber(value) end
    end

    return nil
end

local function temperatureStat(telemetry, warning, maximum)
    telemetry = telemetry or (rfsuite.tasks and rfsuite.tasks.telemetry)
    local stats = telemetry and telemetry.getSensorStats and telemetry.getSensorStats("temp_esc")
    local value = stats and tonumber(stats.max) or nil
    local unit = "°C"
    local displayWarning = warning
    local displayMaximum = maximum

    if telemetry and telemetry.getSensor then
        local _, _, localizedUnit, localizedWarning, localizedMaximum = telemetry.getSensor("temp_esc", warning, maximum)
        unit = localizedUnit or unit
        displayWarning = tonumber(localizedWarning) or displayWarning
        displayMaximum = tonumber(localizedMaximum) or displayMaximum
    end

    return value, unit, displayWarning, displayMaximum
end

local function ensureCards(c)
    if c.cards then return c.cards end
    c.cards = {
        {"MAX HEADSPEED", "--", C.muted, 0, "FONT_STD"},
        {"MAX ESC TEMP", "--", C.muted, 0, "FONT_STD"},
        {"PEAK CURRENT", "--", C.muted, 0, "FONT_STD"},
        {"MIN BEC", "--", C.muted, 0, "FONT_STD"},
        {"MIN LINK", "--", C.muted, 0, "FONT_STD"},
        {"FUEL REMAINING", "--", C.muted, 0, "FONT_STD"},
        {"CONSUMED", "--", C.muted, 0, "FONT_STD"},
        {"PEAK POWER", "--", C.muted, 0, "FONT_STD"},
        {"MIN PACK / ALT", "--  /  --", C.muted, 0, "FONT_S"}
    }
    return c.cards
end

local function updateCard(card, value, decimals, suffix, color, percent)
    if card._value ~= value or card._suffix ~= suffix then
        card._value = value
        card._suffix = suffix
        card[2] = fmt(value, decimals, suffix)
    end
    card[3] = color
    card[4] = percent or 0
end

local function updatePackAltitudeCard(card, voltage, altitude, color, percent)
    if card._voltage ~= voltage or card._altitude ~= altitude then
        card._voltage = voltage
        card._altitude = altitude
        card[2] = fmt(voltage, 1, " V") .. "  /  " .. fmt(altitude, 0, " m")
    end
    card[3] = color
    card[4] = percent or 0
end

local function postflightWakeup(box, telemetry)
    local c = box._cache or {}
    box._cache = c

    c.rpmMax = getThemeValue("rpm_max")
    local escWarnC = getThemeValue("esc_warn")
    local escMaxC = getThemeValue("esc_max")
    c.becMin = getThemeValue("bec_min")
    c.becWarn = getThemeValue("bec_warn")
    c.fuelWarn = getThemeValue("fuel_warn")
    c.linkWarn = getThemeValue("link_warn")

    c.rpm = stat(telemetry, "rpm", "max", "headspeed", "erpm")
    if c.rpm and c.rpm <= 0 then c.rpm = nil end
    c.esc, c.escUnit, c.escWarn, c.escMax = temperatureStat(telemetry, escWarnC, escMaxC)
    c.current = stat(telemetry, "current", "max")
    c.watts = stat(telemetry, "watts", "max")
    c.bec = stat(telemetry, "bec_voltage", "min", "bec")
    c.link = stat(telemetry, "vfr", "min")
    c.fuel = stat(telemetry, "smartfuel", "min")
    c.consumed = stat(telemetry, "smartconsumption", "max", "consumption")
    c.voltage = stat(telemetry, "voltage", "min")
    c.altitude = stat(telemetry, "altitude", "max")

    local session = rfsuite and rfsuite.session

    -- The standard Rotorflight watts widget derives max power from the maximum
    -- recorded voltage and current when a dedicated watts statistic is absent.
    if c.watts == nil and c.current ~= nil then
        local maxVoltage = stat(telemetry, "voltage", "max")
        if maxVoltage ~= nil then c.watts = maxVoltage * c.current end
    end
    local seconds = session and session.timer and tonumber(session.timer.live) or 0
    seconds = floor(max(0, seconds))
    if c._timeSecond ~= seconds then
        c._timeSecond = seconds
        c.time = format("%02d:%02d", floor(seconds / 60), seconds % 60)
    end

    local faults = 0
    local cautions = 0

    if c.esc and c.esc >= c.escMax then
        faults = faults + 1
    elseif c.esc and c.esc >= c.escWarn then
        cautions = cautions + 1
    end

    if c.bec and c.bec < c.becMin then
        faults = faults + 1
    elseif c.bec and c.bec < c.becWarn then
        cautions = cautions + 1
    end

    if c.fuel and c.fuel <= c.fuelWarn then cautions = cautions + 1 end
    if c.link and c.link < c.linkWarn then cautions = cautions + 1 end
    if c.rpm and c.rpm > c.rpmMax * 1.05 then cautions = cautions + 1 end

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

    if available == 0 then
        c.grade = "NO DATA"
        c.gradeColor = C.muted
        c.gradeSub = "NO FLIGHT TELEMETRY"
    elseif faults > 0 then
        c.grade = "SYSTEM INSPECTION"
        c.gradeColor = C.red
        c.gradeSub = "CRITICAL LIMIT EXCEEDED"
    elseif cautions > 0 then
        c.grade = "MISSION REVIEW"
        c.gradeColor = C.amber
        c.gradeSub = tostring(cautions) .. " ITEM" .. (cautions == 1 and "" or "S") .. " FLAGGED"
    else
        c.grade = "MISSION COMPLETE"
        c.gradeColor = C.green
        c.gradeSub = "FLIGHT DATA WITHIN LIMITS"
    end

    local rpmColor = c.rpm == nil and C.muted or (c.rpm > c.rpmMax * 1.05 and C.amber or C.cyan)
    local escColor = c.esc and (c.esc >= c.escMax and C.red or (c.esc >= c.escWarn and C.amber or C.green)) or C.muted
    local becColor = c.bec and (c.bec < c.becMin and C.red or (c.bec < c.becWarn and C.amber or C.cyan)) or C.muted
    local fuelColor = c.fuel == nil and C.muted or (c.fuel <= c.fuelWarn and C.amber or C.green)
    local linkColor = c.link == nil and C.muted or (c.link < c.linkWarn and C.amber or C.cyan)
    local currentColor = c.current ~= nil and C.violet or C.muted
    local consumedColor = c.consumed ~= nil and C.amber or C.muted
    local wattsColor = c.watts ~= nil and C.violet or C.muted
    local packAltitudeColor = (c.voltage ~= nil or c.altitude ~= nil) and C.cyan or C.muted

    local cards = ensureCards(c)
    updateCard(cards[1], c.rpm, 0, " RPM", rpmColor, c.rpm and c.rpm / c.rpmMax or 0)
    updateCard(cards[2], c.esc, 0, c.escUnit, escColor, c.esc and c.esc / c.escMax or 0)
    updateCard(cards[3], c.current, 1, " A", currentColor, c.current and c.current / 150 or 0)
    updateCard(cards[4], c.bec, 2, " V", becColor, c.bec and c.bec / 15 or 0)
    updateCard(cards[5], c.link, 0, "%", linkColor, c.link and c.link / 100 or 0)
    updateCard(cards[6], c.fuel, 0, "%", fuelColor, c.fuel and c.fuel / 100 or 0)
    updateCard(cards[7], c.consumed, 0, " mAh", consumedColor, c.consumed and c.consumed / 5000 or 0)
    updateCard(cards[8], c.watts, 0, " W", wattsColor, c.watts and c.watts / 5000 or 0)
    updatePackAltitudeCard(cards[9], c.voltage, c.altitude, packAltitudeColor, c.voltage and c.voltage / 60 or 0)

    return c
end

local function drawReportCard(x, y, w, h, title, value, accent, percent, valueFont)
    drawPanel(x, y, w, h, accent, title)

    local valueColor = accent == C.muted and C.muted or ((accent == C.red or accent == C.amber) and accent or C.white)
    drawTextAligned(x + 13, y + 17, w - 26, value, valueFont or "FONT_STD", valueColor, "left")
    drawProgress(x + 13, y + h - 8, w - 26, 5, percent, accent)
end

local EMPTY_CARDS = {}

local function postflightPaint(x, y, w, h, box, c, telemetry)
    x, y = utils.applyOffset(x, y, box)
    c = c or box._cache or {}

    -- Safety net: if paint() runs before the first wakeup() cycle has
    -- populated the cache (e.g. very first frame), fall back to a live
    -- lookup so we never compare a number against a nil threshold.
    if c.escMax == nil or c.escWarn == nil then
        local escWarnC = getThemeValue("esc_warn")
        local escMaxC = getThemeValue("esc_max")
        local _, unit, displayWarn, displayMax = temperatureStat(telemetry, escWarnC, escMaxC)
        c.escUnit, c.escWarn, c.escMax = unit, displayWarn, displayMax
    end
    c.becMin = c.becMin or getThemeValue("bec_min")
    c.becWarn = c.becWarn or getThemeValue("bec_warn")
    c.fuelWarn = c.fuelWarn or getThemeValue("fuel_warn")
    c.linkWarn = c.linkWarn or getThemeValue("link_warn")
    c.rpmMax = c.rpmMax or getThemeValue("rpm_max")

    lcd.color(C.bg)
    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))

    local pad = 12
    local topY = y + 6

    drawPatrioticTitleRail(x, y + 1, w)
    drawPatrioticTitle(x + pad, topY, w - 300)
    drawTextAligned(x + w - 292, topY + 2, 280, "FLIGHT SUMMARY", "FONT_STD", C.cyan, "right")
    drawPatrioticTitleRail(x + pad, y + 34, w - pad * 2)

    local summaryY = y + 44
    local summaryH = 68
    local summaryX = x + pad
    local summaryW = w - pad * 2
    local gradeColor = c.gradeColor or C.muted

    drawPanel(summaryX, summaryY, summaryW, summaryH, gradeColor, nil)

    local leftX = summaryX + 18
    local leftW = floor(summaryW * 0.35)
    drawTextAligned(leftX, summaryY + 11, leftW, "FLIGHT RESULT", "FONT_XXS", C.muted, "left")
    drawTextAligned(leftX, summaryY + 25, leftW, c.grade or "NO DATA", "FONT_STD", gradeColor, "left")
    drawTextAligned(leftX, summaryY + 48, leftW, c.gradeSub or "NO FLIGHT TELEMETRY", "FONT_XXS", C.white, "left")

    local centerX = summaryX + summaryW * 0.51
    local centerY = summaryY + summaryH * 0.50
    drawShield(centerX, centerY + 1, 86, 50, C.line2)
    drawAnniversaryStars(centerX, summaryY + 12, summaryY + summaryH - 10)
    drawTextAligned(centerX - 50, summaryY + 17, 100, "250", "FONT_L", C.amber, "center")
    drawCenteredDotLine(centerX - 50, summaryY + 42, 100, "1776", "2026", "FONT_XXS", C.white, C.amber)

    local timeX = summaryX + summaryW - 220
    local timeW = 198
    drawTextAligned(timeX, summaryY + 10, timeW, c.time or "00:00", "FONT_XL", C.white, "right")
    drawTextAligned(timeX, summaryY + 48, timeW, "FLIGHT TIME", "FONT_XXS", C.muted, "right")

    local gridY = summaryY + summaryH + 8
    local footerReserve = 20
    local gridH = h - (gridY - y) - footerReserve
    local cols = 3
    local rows = 3
    local gap = 8
    local cardW = floor((w - pad * 2 - gap * (cols - 1)) / cols)
    local cardH = floor((gridH - gap * (rows - 1)) / rows)

    local cards = c.cards or EMPTY_CARDS

    for i = 1, #cards do
        local row = floor((i - 1) / cols)
        local col = (i - 1) % cols
        local card = cards[i]
        local cx = x + pad + col * (cardW + gap)
        local cy = gridY + row * (cardH + gap)
        drawReportCard(cx, cy, cardW, cardH, card[1], card[2], card[3], card[4], card[5])
    end

    drawCenteredTripleDotLine(
        x + pad, y + h - 18, w - pad * 2,
        "13 ORIGINAL COLONIES", "MISSION DEBRIEF", "MWRC",
        "FONT_XXS", C.line2, C.amber
    )
end

local boxes_cache = nil

local function boxes()
    if boxes_cache == nil then
        boxes_cache = {{
            col = 1, row = 1, colspan = 12, rowspan = 12,
            type = "func", subtype = "func",
            wakeup = postflightWakeup,
            paint = postflightPaint,
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
