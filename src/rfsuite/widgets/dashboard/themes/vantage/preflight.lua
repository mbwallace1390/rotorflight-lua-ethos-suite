-- Vantage: a five-signal preflight checklist with a dedicated power instrument.
-- Theme-owned presentation; telemetry, lifecycle and preferences remain Suite-owned.
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local rfsuite = requireModule("widgets/dashboard/context.lua")
local lcd = lcd
local math = math
local floor = math.floor
local min = math.min
local max = math.max
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
-- This theme owns its header geometry; leave the Suite defaults unchanged.
headeropts.height = math.max(headeropts.height or 0, 44)
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
            if headerBox.subtype == "craftname" then headerBox.font = nil end
            if headerBox.type == "image" then
                headerBox.type = "func"
                headerBox.subtype = "func"
                headerBox.bgcolor = "transparent"
                headerBox.paint = function(x, y, w, h)
                    lcd.color(C.panel)
                    lcd.drawFilledRectangle(math.floor(x), math.floor(y), math.floor(w), math.floor(h))
                    local cache = headerBox
                    -- Measure only when the header geometry changes; keep the builder mark smaller.
                    if cache._titleWidth ~= w or cache._titleLayoutHeight ~= h then
                        local titleFont = utils.resolveFont("FONT_L", nil)
                        local markFont = utils.resolveFont("FONT_XS", nil)
                        if type(titleFont) ~= "number" or type(markFont) ~= "number" then return end
                        lcd.font(markFont)
                        local mw, mh = lcd.getTextSize("| MWRC")
                        lcd.font(titleFont)
                        local tw, th = lcd.getTextSize("Rotorflight // Ethos")
                        if tw + mw + 24 > w or th > h - 4 then
                            titleFont = utils.resolveFont("FONT_STD", nil) or titleFont
                            lcd.font(titleFont)
                            tw, th = lcd.getTextSize("Rotorflight // Ethos")
                        end
                        if tw + mw + 24 > w or th > h - 4 then
                            titleFont = utils.resolveFont("FONT_S", nil) or titleFont
                            lcd.font(titleFont)
                            tw, th = lcd.getTextSize("Rotorflight // Ethos")
                        end
                        -- Narrow header slots retain the same hierarchy with the smallest pair.
                        if tw + mw + 24 > w or th > h - 4 then
                            titleFont = utils.resolveFont("FONT_XS", nil) or titleFont
                            markFont = utils.resolveFont("FONT_XXS", nil) or markFont
                            lcd.font(markFont)
                            mw, mh = lcd.getTextSize("| MWRC")
                            lcd.font(titleFont)
                            tw, th = lcd.getTextSize("Rotorflight // Ethos")
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
                    lcd.color(C.cyan)
                    lcd.drawText(groupX, math.floor(y + (h - cache._titleHeight) / 2), "Rotorflight // Ethos")
                    lcd.font(cache._markFont)
                    lcd.color(C.muted)
                    lcd.drawText(groupX + cache._titleTextWidth + 8, math.floor(y + (h - cache._markHeight) / 2), "| MWRC")
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
    violet = lcd.RGB(124, 156, 207),
}

-- Keep telemetry contrast stable when the transmitter uses a light system theme.
colorMode.bgcolor = C.bg
colorMode.tbbgcolor = C.panel
colorMode.tbtextcolor = C.white
colorMode.cntextcolor = C.white
colorMode.rssitextcolor = C.white
colorMode.rssifillcolor = C.cyan
colorMode.rssifillbgcolor = C.line
colorMode.txbgfillcolor = C.line
colorMode.txfillcolor = C.green

local function getThemeValue(key)
    -- The rewritten Suite binds preferences to the active dashboard theme.
    local value = tonumber(rfsuite.widgets.dashboard.getPreference(key))

    value = value or DEFAULTS[key]
    if key == "fuel_warn" or key == "link_warn" then return max(1, min(99, value)) end
    if key == "bec_min" then return max(2, min(14.8, value)) end
    if key == "bec_warn" then return max(2.1, min(15, value)) end
    if key == "esc_warn" then return max(0, min(199, value)) end
    if key == "esc_max" then return max(1, min(200, value)) end
    return value
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
            return "ARMED / " .. governorLabel, governorColor or C.red
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

local function cacheText(c, textKey, valueKey, unitKey, value, decimals, suffix)
    suffix = suffix or ""
    local scale = decimals == 2 and 100 or (decimals == 1 and 10 or 1)
    value = value and floor(value * scale + 0.5) / scale or nil
    if c[valueKey] ~= value or c[unitKey] ~= suffix or c[textKey] == nil then
        c[valueKey] = value
        c[unitKey] = suffix
        c[textKey] = fmt(value, decimals, suffix)
    end
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
    if align == "center" then
        tx = x + (w - tw) / 2
    elseif align == "right" then
        tx = x + w - tw
    end
    lcd.drawText(floor(tx + 0.5), floor(y + 0.5), text)
    return tw, th
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
        drawTextAligned(x + 12, y + 7, w - 22, title, "FONT_XS", C.muted, "left")
    end
end


local function drawSegments(x, y, w, h, percent, count, activeColor, emptyColor)
    count = count or 10
    percent = max(0, min(100, percent or 0))
    local gap = 4
    local segW = floor((w - gap * (count - 1)) / count)
    if segW < 2 then return end
    local active = percent > 0 and max(1, min(count, floor(percent * count / 100 + 0.999))) or 0
    for i = 1, count do
        local sx = x + (i - 1) * (segW + gap)
        if i <= active then
            lcd.color(activeColor)
            lcd.drawFilledRectangle(floor(sx), floor(y), segW, floor(h))
        else
            lcd.color(emptyColor or C.line)
            lcd.drawRectangle(floor(sx), floor(y), segW, floor(h), 1)
        end
    end
end

local layout = {cols = 12, rows = 12, padding = 0}
local screenBorderStyle = {enabled = false}

local function preflightWakeup(box, telemetry)
    local c = box._cache or {}
    box._cache = c

    c.fuelWarn = getThemeValue("fuel_warn")
    c.becMin = getThemeValue("bec_min")
    c.becWarn = max(c.becMin + 0.1, getThemeValue("bec_warn"))
    local escWarnC = getThemeValue("esc_warn")
    local escMaxC = max(escWarnC + 1, getThemeValue("esc_max"))
    c.linkWarn = getThemeValue("link_warn")

    c.fuel = sensor(telemetry, "smartfuel")
    c.bec = sensor(telemetry, "bec_voltage", "bec")
    c.esc, c.escUnit, c.escWarn, c.escMax = temperatureSensor(telemetry, escWarnC, escMaxC)
    c.link = sensor(telemetry, "vfr")
    -- Only percentage readings can populate the link instrument.
    if c.link == nil or c.link < 0 or c.link > 100 then c.link = sensor(telemetry, "rssi") end
    if c.link ~= nil and (c.link < 0 or c.link > 100) then c.link = nil end
    c.rate = sensor(telemetry, "rate_profile")
    c.pid = sensor(telemetry, "pid_profile")
    c.voltage = sensor(telemetry, "voltage")
    c.flightState, c.flightStateColor = getFlightState(telemetry)

    local available = 0
    local faults = 0
    local warnings = 0
    local firstIssue

    if c.fuel ~= nil then
        available = available + 1
        if c.fuel <= c.fuelWarn then
            faults = faults + 1
            if firstIssue == nil then firstIssue = "SMART FUEL " .. fmt(c.fuel, 0, "%") .. " AT RESERVE" end
        end
    end
    if c.bec ~= nil then
        available = available + 1
        if c.bec < c.becMin then
            faults = faults + 1
            if firstIssue == nil then firstIssue = "BEC " .. fmt(c.bec, 1, "V") .. " BELOW " .. fmt(c.becMin, 1, "V") end
        elseif c.bec < c.becWarn then
            warnings = warnings + 1
            if firstIssue == nil then firstIssue = "BEC " .. fmt(c.bec, 1, "V") .. " BELOW " .. fmt(c.becWarn, 1, "V") end
        end
    end
    if c.esc ~= nil then
        available = available + 1
        if c.esc >= c.escMax then
            faults = faults + 1
            if firstIssue == nil then firstIssue = "ESC " .. fmt(c.esc, 0, c.escUnit) .. " AT LIMIT" end
        elseif c.esc >= c.escWarn then
            warnings = warnings + 1
            if firstIssue == nil then firstIssue = "ESC " .. fmt(c.esc, 0, c.escUnit) .. " ABOVE WARNING" end
        end
    end
    if c.link ~= nil then
        available = available + 1
        if c.link < c.linkWarn then
            warnings = warnings + 1
            if firstIssue == nil then firstIssue = "LINK " .. fmt(c.link, 0, "%") .. " BELOW " .. fmt(c.linkWarn, 0, "%") end
        end
    end

    if c.voltage ~= nil then
        available = available + 1
        if c.voltage <= 0 then
            faults = faults + 1
            firstIssue = firstIssue or "CHECK PACK VOLTAGE"
        end
    end

    -- A check is complete only when every required instrument has a live reading.
    if c._available ~= available then
        c._available = available
        c.signalText = tostring(available) .. " / 5 SIGNALS"
    end
    local issueCount = faults + warnings
    c.issueText = firstIssue
    if issueCount > 1 and c.issueText then
        c.issueText = c.issueText .. "  +" .. tostring(issueCount - 1) .. " MORE"
    end

    if available == 0 then
        c.status = "WAITING"
        c.statusColor = C.muted
        c.statusSub = "CONNECT TELEMETRY"
        c.issueText = nil
    elseif faults > 0 then
        c.status = "CHECK"
        c.statusColor = C.red
        c.statusSub = tostring(issueCount) .. " ITEM" .. (issueCount == 1 and "" or "S") .. " FLAGGED"
    elseif warnings > 0 then
        c.status = "CAUTION"
        c.statusColor = C.amber
        c.statusSub = tostring(issueCount) .. " ITEM" .. (issueCount == 1 and "" or "S") .. " TO REVIEW"
    elseif available < 5 then
        -- Missing channels cannot establish that every monitored system is ready.
        c.status = "PARTIAL DATA"
        c.statusColor = C.amber
        c.statusSub = "CHECK MISSING SENSORS"
        c.issueText = nil
    else
        c.status = "READY"
        c.statusColor = C.green
        c.statusSub = "TELEMETRY CHECKS COMPLETE"
        c.issueText = nil
    end

    cacheText(c, "becText", "_becTextValue", "_becTextUnit", c.bec, 1, " V")
    cacheText(c, "linkText", "_linkTextValue", "_linkTextUnit", c.link, 0, "%")
    cacheText(c, "fuelText", "_fuelTextValue", "_fuelTextUnit", c.fuel, 0, "%")
    cacheText(c, "escText", "_escTextValue", "_escTextUnit", c.esc, 0, c.escUnit)
    cacheText(c, "rateText", "_rateTextValue", "_rateTextUnit", c.rate, 0, "")
    cacheText(c, "pidText", "_pidTextValue", "_pidTextUnit", c.pid, 0, "")
    cacheText(c, "voltageText", "_voltageTextValue", "_voltageTextUnit", c.voltage, 1, " V")

    if c._profileRate ~= c.rateText or c._profilePid ~= c.pidText then
        c._profileRate, c._profilePid = c.rateText, c.pidText
        c.profileText = "RATES " .. c.rateText .. "  /  PID " .. c.pidText
    end
    return c
end

local function drawChecklistRow(x, y, w, h, label, value, color)
    local compact = h < 35
    local fontName = compact and "FONT_XXS" or "FONT_XS"
    local textY = y + floor((h - (compact and 16 or 20)) / 2)
    lcd.color(C.line)
    lcd.drawLine(floor(x), floor(y + h - 1), floor(x + w), floor(y + h - 1))
    lcd.color(color)
    local indicatorY = floor(y + (h - 7) / 2)
    if color == C.muted then
        lcd.drawRectangle(floor(x + 2), indicatorY, 7, 7, 1)
    else
        lcd.drawFilledRectangle(floor(x + 2), indicatorY, 7, 7)
    end
    drawTextAligned(x + 20, textY, w * 0.58 - 20, label, fontName, C.muted, "left")
    drawTextAligned(x + w * 0.58, textY - (compact and 1 or 0), w * 0.42, value or "--", compact and "FONT_XS" or "FONT_S", color, "right")
end

local function drawReadout(x, y, w, h, title, value, accent, compact)
    drawPanel(x, y, w, h, accent, nil)
    drawTextAligned(x + 12, y + 9, w - 24, title, "FONT_XXS", C.muted, "left")
    drawTextAligned(x + 12, y + (compact and 26 or 35), w - 24, value or "--", compact and "FONT_L" or "FONT_XL", accent == C.muted and C.muted or C.white, "left")
    if not compact then
        lcd.color(accent)
        lcd.drawLine(floor(x + 12), floor(y + h - 16), floor(x + w - 12), floor(y + h - 16))
    end
end

local function preflightPaint(x, y, w, h, box, c, telemetry)
    c = c or box._cache or {}
    box._cache = c
    c.fuelWarn = c.fuelWarn or getThemeValue("fuel_warn")
    c.becMin = c.becMin or getThemeValue("bec_min")
    c.becWarn = c.becWarn or max(c.becMin + 0.1, getThemeValue("bec_warn"))
    if c.escMax == nil or c.escWarn == nil then
        local escWarnC = getThemeValue("esc_warn")
        local escMaxC = max(escWarnC + 1, getThemeValue("esc_max"))
        local _, unit, displayWarn, displayMax = temperatureSensor(telemetry, escWarnC, escMaxC)
        c.escUnit, c.escWarn, c.escMax = unit, displayWarn, displayMax
    end
    c.linkWarn = c.linkWarn or getThemeValue("link_warn")

    lcd.color(C.bg)
    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))
    local compact = h < 340
    local pad, gap = 12, 12
    local topH = compact and 33 or 42
    drawTextAligned(x + pad, y + 7, w * 0.42, "VANTAGE", "FONT_STD", C.cyan, "left")
    drawTextAligned(x + w * 0.43, y + 11, w * 0.57 - pad, "01  /  PRE-FLIGHT", "FONT_XXS", C.muted, "right")
    local bodyY, bodyH = y + topH, h - topH - pad
    local leftW = floor((w - pad * 2 - gap) * 0.42)
    local leftX, rightX = x + pad, x + pad + leftW + gap
    local rightW = w - pad * 2 - gap - leftW
    local statusColor = c.statusColor or C.muted
    local packColor = c.voltage and (c.voltage > 0 and C.cyan or C.red) or C.muted
    local fuelColor = c.fuel and (c.fuel <= c.fuelWarn and C.red or (c.fuel <= 50 and C.amber or C.green)) or C.muted
    local becColor = c.bec and (c.bec < c.becMin and C.red or (c.bec < c.becWarn and C.amber or C.green)) or C.muted
    local escColor = c.esc and (c.esc >= c.escMax and C.red or (c.esc >= c.escWarn and C.amber or C.green)) or C.muted
    local linkColor = c.link and (c.link < c.linkWarn and C.amber or C.green) or C.muted

    -- The status and five checklist rows share one stable instrument surface.
    drawPanel(leftX, bodyY, leftW, bodyH, statusColor, nil)
    local statusH = compact and 84 or 126
    lcd.color(C.panel2)
    lcd.drawFilledRectangle(floor(leftX + 4), floor(bodyY + 1), floor(leftW - 5), statusH - 1)
    drawTextAligned(leftX + 15, bodyY + 10, leftW - 30, "LAUNCH CHECKLIST", "FONT_XXS", C.muted, "left")
    drawTextAligned(leftX + 15, bodyY + (compact and 30 or 38), leftW - 30, c.status or "WAITING", compact and "FONT_XL" or "FONT_XXL", statusColor, "left")
    if not compact then
        drawTextAligned(leftX + 15, bodyY + 94, leftW - 30, c.issueText or c.statusSub or "CONNECT TELEMETRY", "FONT_XXS", C.muted, "left")
    end
    local footerH = compact and 21 or 34
    local rowY = bodyY + statusH
    local rowH = (bodyH - statusH - footerH) / 5
    drawChecklistRow(leftX + 14, rowY, leftW - 28, rowH, "PACK VOLTAGE", c.voltageText, packColor)
    drawChecklistRow(leftX + 14, rowY + rowH, leftW - 28, rowH, "BEC SUPPLY", c.becText, becColor)
    drawChecklistRow(leftX + 14, rowY + rowH * 2, leftW - 28, rowH, "ESC THERMAL", c.escText, escColor)
    drawChecklistRow(leftX + 14, rowY + rowH * 3, leftW - 28, rowH, "RADIO LINK", c.linkText, linkColor)
    drawChecklistRow(leftX + 14, rowY + rowH * 4, leftW - 28, rowH, "FUEL RESERVE", c.fuelText, fuelColor)
    drawTextAligned(leftX + 15, bodyY + bodyH - footerH + (compact and 4 or 10), leftW - 30, c.signalText or "0 / 5 SIGNALS", "FONT_XXS", C.muted, "left")

    -- Pack voltage and reserve get the largest readings in the power instrument.
    local stateH = compact and 28 or 36
    local readoutH = compact and 74 or 120
    local powerH = bodyH - readoutH - stateH - gap * 2
    drawPanel(rightX, bodyY, rightW, powerH, C.cyan, nil)
    local dividerX = rightX + rightW * 0.57
    drawTextAligned(rightX + 15, bodyY + 11, rightW * 0.57 - 30, "PACK VOLTAGE", "FONT_XXS", C.muted, "left")
    drawTextAligned(dividerX + 15, bodyY + 11, rightW * 0.43 - 30, "SMART FUEL", "FONT_XXS", C.muted, "left")
    local readingY = bodyY + (compact and 31 or 40)
    drawTextAligned(rightX + 15, readingY, rightW * 0.57 - 30, c.voltageText or "--", compact and "FONT_XL" or "FONT_XXL", packColor == C.muted and C.muted or C.white, "left")
    drawTextAligned(dividerX + 15, readingY, rightW * 0.43 - 30, c.fuelText or "--", compact and "FONT_XL" or "FONT_XXL", fuelColor, "left")
    lcd.color(C.line)
    lcd.drawLine(floor(dividerX), floor(bodyY + 13), floor(dividerX), floor(bodyY + powerH - 37))
    drawSegments(rightX + 15, bodyY + powerH - 24, rightW - 30, compact and 9 or 12, c.fuel or 0, 16, fuelColor, C.line)
    if not compact then
        drawTextAligned(rightX + 15, bodyY + powerH - 48, rightW - 30, "RESERVE / LIVE ESTIMATE", "FONT_XXS", C.muted, "left")
    end

    local readoutY = bodyY + powerH + gap
    local readoutW = (rightW - gap * 2) / 3
    drawReadout(rightX, readoutY, readoutW, readoutH, "BEC SUPPLY", c.becText, becColor, compact)
    drawReadout(rightX + readoutW + gap, readoutY, readoutW, readoutH, "ESC TEMP", c.escText, escColor, compact)
    drawReadout(rightX + (readoutW + gap) * 2, readoutY, readoutW, readoutH, "RADIO LINK", c.linkText, linkColor, compact)
    local stateY = readoutY + readoutH + gap
    lcd.color(C.panel2)
    lcd.drawFilledRectangle(floor(rightX), floor(stateY), floor(rightW), stateH)
    drawTextAligned(rightX + 12, stateY + (compact and 7 or 10), rightW * 0.56 - 18, c.flightState or "STATE --", "FONT_XXS", c.flightStateColor or C.muted, "left")
    drawTextAligned(rightX + rightW * 0.56, stateY + (compact and 7 or 10), rightW * 0.44 - 12, c.profileText or "RATES --  /  PID --", "FONT_XXS", C.muted, "right")
end

local boxes_cache = nil

local function boxes()
    if boxes_cache == nil then
        boxes_cache = {{
        col = 1, row = 1, colspan = 12, rowspan = 12,
        type = "func", subtype = "func",
        wakeup = preflightWakeup,
        paint = preflightPaint,
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
