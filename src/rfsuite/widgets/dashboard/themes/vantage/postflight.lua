-- VANTAGE flight report. Historical telemetry and lifecycle adapted from Aegis.
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

        -- Keep the shared Rotorflight / Ethos title and discreet builder mark while
        -- keeping the radio's native header surface and battery/RSSI widgets.
        for _, headerBox in ipairs(boxes) do
            if headerBox.subtype == "craftname" then headerBox.font = nil end
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


-- Historical values remain independent of the current connection and battery.
local function stat(telemetry, source, statType, alias)
    local stats = telemetry and telemetry.sensorStats
    local data = stats and stats[source]
    local value = tonumber(data and data[statType])
    if value == nil and alias then
        data = stats and stats[alias]
        value = tonumber(data and data[statType])
    end
    return value
end

local function updateMetric(metric, value, decimals, suffix, color)
    if metric.value ~= value or metric.suffix ~= suffix or metric.text == nil then
        metric.value, metric.suffix = value, suffix
        metric.text = fmt(value, decimals, suffix)
    end
    metric.color = value == nil and C.muted or color
end

local function duration(seconds, total)
    if seconds == nil or seconds < 0 then return "--:--" end
    seconds = floor(seconds)
    if total then
        return format("%02d:%02d:%02d", floor(seconds / 3600), floor(seconds / 60) % 60, seconds % 60)
    end
    return format("%02d:%02d", floor(seconds / 60), seconds % 60)
end

local function postflightWakeup(box, telemetry)
    telemetry = telemetry or (rfsuite.tasks and rfsuite.tasks.telemetry)
    local c = box._cache
    if not c then
        c = {metrics = {{}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}}}
        box._cache = c
    end
    local m = c.metrics
    local rpm = stat(telemetry, "rpm", "max", "headspeed")
    local rpmAvg = stat(telemetry, "rpm", "avg", "headspeed")
    local current = stat(telemetry, "current", "max")
    local currentAvg = stat(telemetry, "current", "avg")
    local bec = stat(telemetry, "bec_voltage", "min", "bec")
    -- Keep the same percentage source priority as the live flight screens.
    local link = stat(telemetry, "vfr", "min")
    if link == nil or link < 0 or link > 100 then link = stat(telemetry, "rssi", "min") end
    if link ~= nil and (link < 0 or link > 100) then link = nil end
    local used = stat(telemetry, "consumption", "max", "smartconsumption")
    -- A recorded per-cell sample never depends on today's pack voltage/cell count.
    local cell = stat(telemetry, "cell_voltage", "min")
    local fuel = stat(telemetry, "smartfuel", "min", "fuel")
    if fuel ~= nil and (fuel < 0 or fuel > 100) then fuel = nil end
    local watts = stat(telemetry, "watts", "max")
    local thermal = telemetry and telemetry.getSensorStats and telemetry.getSensorStats("temp_esc")
    local esc = tonumber(thermal and thermal.max)
    local escWarn, escMax = getThemeValue("esc_warn"), getThemeValue("esc_max")
    local escUnit = "°C"
    if telemetry and telemetry.getSensor then
        local value, precision, unit, warning, maximum = telemetry.getSensor("temp_esc", escWarn, escMax)
        escUnit = unit or escUnit
        escWarn, escMax = tonumber(warning) or escWarn, tonumber(maximum) or escMax
    end
    local rpmColor = rpm and rpm > getThemeValue("rpm_max") and C.amber or C.cyan
    local escColor = esc and (esc >= escMax and C.red or (esc >= escWarn and C.amber or C.white)) or C.muted
    local becColor = bec and (bec < getThemeValue("bec_min") and C.red or (bec < getThemeValue("bec_warn") and C.amber or C.white)) or C.muted
    local linkColor = link and link < getThemeValue("link_warn") and C.amber or C.white
    local fuelColor = fuel and fuel <= getThemeValue("fuel_warn") and C.amber or C.white
    updateMetric(m[1], rpm, 0, "", rpmColor)
    updateMetric(m[2], rpmAvg, 0, " RPM", C.white)
    updateMetric(m[3], current, 1, " A", C.white)
    updateMetric(m[4], currentAvg, 1, " A", C.muted)
    updateMetric(m[5], esc, 0, escUnit, escColor)
    updateMetric(m[6], bec, 2, " V", becColor)
    updateMetric(m[7], link, 0, "%", linkColor)
    updateMetric(m[8], used, 0, " mAh", C.white)
    updateMetric(m[9], cell, 2, " V", C.white)
    updateMetric(m[10], fuel, 0, "%", fuelColor)
    updateMetric(m[11], watts, 0, " W", C.white)

    local session = rfsuite.session or {}
    local general = session.modelPreferences and session.modelPreferences.general
    local seconds = tonumber(session.timer and session.timer.live)
    if seconds == nil or seconds <= 0 then seconds = tonumber(general and general.lastflighttime) end
    if seconds == nil or seconds <= 0 then seconds = nil end
    if c._seconds ~= seconds or c.time == nil then
        c._seconds, c.time = seconds, duration(seconds, false)
    end
    local count = tonumber(general and general.flightcount)
    if c._count ~= count or c.count == nil then
        c._count, c.count = count, fmt(count, 0)
    end
    local total = tonumber(general and general.totalflighttime)
    if c._total ~= total or c.total == nil then
        c._total, c.total = total, duration(total, true)
    end
    local craft = session.craftName
    if type(craft) ~= "string" or craft == "" then craft = model and model.name and model.name() or "AIRFRAME" end
    local narrow = (box._dashboardRectW or 800) < 600
    if c._craft ~= craft or c._narrow ~= narrow then
        c._craft, c._narrow = craft, narrow
        local limit = narrow and 12 or 24
        c.craft = #craft > limit and craft:sub(1, limit - 3) .. "..." or craft
    end
    c.recorded = false
    for i = 1, #m do
        if m[i].value ~= nil then c.recorded = true; break end
    end
    return c
end

local function surface(x, y, w, h, fill)
    x, y, w, h = floor(x), floor(y), max(1, floor(w)), max(1, floor(h))
    lcd.color(fill or C.panel)
    lcd.drawFilledRectangle(x, y, w, h)
    lcd.color(C.line)
    lcd.drawRectangle(x, y, w, h)
end

local EMPTY_METRIC = {text = "--", color = C.muted}
local function metricAt(c, index)
    return c and c.metrics and c.metrics[index] or EMPTY_METRIC
end

local function drawReportRow(x, y, w, h, title, primaryLabel, primary, secondaryLabel, secondary)
    surface(x, y, w, h, C.panel)
    local small = h < 66
    local labelFont = small and "FONT_XXS" or "FONT_XS"
    local valueFont = small and "FONT_S" or "FONT_L"
    drawTextAligned(x + 12, y + 10, w * 0.30 - 18, title, labelFont, C.cyan, "left")
    local primaryX = x + w * 0.34
    local secondaryX = x + w * 0.69
    drawTextAligned(primaryX, y + 7, w * 0.32 - 12, primaryLabel, "FONT_XXS", C.muted, "left")
    drawTextAligned(primaryX, y + (small and 23 or 29), w * 0.32 - 12, primary.text, valueFont, primary.color, "left")
    drawTextAligned(secondaryX, y + 7, w * 0.29 - 10, secondaryLabel, "FONT_XXS", C.muted, "left")
    drawTextAligned(secondaryX, y + (small and 23 or 29), w * 0.29 - 10, secondary.text, small and "FONT_XS" or "FONT_S", secondary.color, "left")
end

local function drawSecondary(x, y, w, h, label, metric)
    drawTextAligned(x + 10, y + 4, w - 20, label, "FONT_XXS", C.muted, "left")
    drawTextAligned(x + 10, y + (h < 40 and 18 or 20), w - 20, metric.text, h < 43 and "FONT_XS" or "FONT_S", metric.color, "left")
end

local function postflightPaint(x, y, w, h, box, cache)
    local c = cache or box._cache
    lcd.color(C.bg)
    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))
    local compact = h < 330
    local pad, gap = compact and 10 or 12, compact and 8 or 10
    local topH = compact and 26 or 32
    drawTextAligned(x + pad, y + 6, w * 0.54, "VANTAGE / FLIGHT REPORT", compact and "FONT_XS" or "FONT_S", C.cyan, "left")
    drawTextAligned(x + w * 0.62, y + 8, w * 0.38 - pad, c and c.recorded and "RECORDED TELEMETRY" or "NO RECORDED TELEMETRY", "FONT_XXS", C.muted, "right")
    local contentY = y + topH + pad
    local contentH = h - topH - pad * 2
    local sideW = floor(w * 0.255)
    local sideX = x + pad
    local reportX = sideX + sideW + gap
    local reportW = w - pad * 2 - sideW - gap
    surface(sideX, contentY, sideW, contentH, C.panel2)
    lcd.color(C.amber)
    lcd.drawFilledRectangle(sideX, contentY, sideW, 2)
    drawTextAligned(sideX + 12, contentY + 12, sideW - 24, "FLIGHT DURATION", "FONT_XXS", C.muted, "left")
    drawTextAligned(sideX + 12, contentY + 33, sideW - 24, c and c.time or "--:--", compact and "FONT_XL" or "FONT_XXXXL", C.white, "left")
    local modelY = contentY + floor(contentH * (compact and 0.35 or 0.34))
    drawTextAligned(sideX + 12, modelY, sideW - 24, "AIRFRAME", "FONT_XXS", C.muted, "left")
    drawTextAligned(sideX + 12, modelY + 19, sideW - 24, c and c.craft or "--", "FONT_XS", C.white, "left")
    local countY = contentY + floor(contentH * 0.57)
    drawTextAligned(sideX + 12, countY, sideW - 24, "RECORDED FLIGHTS", "FONT_XXS", C.muted, "left")
    drawTextAligned(sideX + 12, countY + 18, sideW - 24, c and c.count or "--", compact and "FONT_STD" or "FONT_XL", C.cyan, "left")
    local totalY = contentY + floor(contentH * 0.80)
    drawTextAligned(sideX + 12, totalY, sideW - 24, "TOTAL AIRTIME", "FONT_XXS", C.muted, "left")
    drawTextAligned(sideX + 12, totalY + 18, sideW - 24, c and c.total or "--:--", compact and "FONT_XS" or "FONT_STD", C.white, "left")

    local heroH = floor(contentH * 0.26)
    local rowH = floor(contentH * 0.18)
    surface(reportX, contentY, reportW, heroH, C.panel2)
    local rpm = metricAt(c, 1)
    drawTextAligned(reportX + 15, contentY + 10, reportW * 0.64, "PEAK HEADSPEED", "FONT_XXS", C.muted, "left")
    drawTextAligned(reportX + 14, contentY + (compact and 27 or 30), reportW * 0.58, rpm.text, compact and "FONT_XL" or "FONT_XXXXL", rpm.color, "left")
    drawTextAligned(reportX + reportW * 0.58, contentY + 10, reportW * 0.42 - 15, "AVERAGE RPM", "FONT_XXS", C.muted, "right")
    local average = metricAt(c, 2)
    drawTextAligned(reportX + reportW * 0.58, contentY + (compact and 30 or 42), reportW * 0.42 - 15, average.text, compact and "FONT_S" or "FONT_L", C.white, "right")
    local rowY = contentY + heroH + gap
    drawReportRow(reportX, rowY, reportW, rowH, "CURRENT", "PEAK", metricAt(c, 3), "AVERAGE", metricAt(c, 4))
    rowY = rowY + rowH + gap
    drawReportRow(reportX, rowY, reportW, rowH, "POWERTRAIN", "PEAK ESC", metricAt(c, 5), "PEAK POWER", metricAt(c, 11))
    local footerY = rowY + rowH + gap
    local footerH = contentY + contentH - footerY
    surface(reportX, footerY, reportW, footerH, C.panel)
    local columnW, halfH = reportW / 3, footerH / 2
    lcd.color(C.line)
    lcd.drawLine(reportX, footerY + halfH, reportX + reportW, footerY + halfH)
    lcd.drawLine(reportX + columnW, footerY, reportX + columnW, footerY + footerH)
    lcd.drawLine(reportX + columnW * 2, footerY, reportX + columnW * 2, footerY + halfH)
    drawSecondary(reportX, footerY, columnW, halfH, "CAPACITY USED", metricAt(c, 8))
    drawSecondary(reportX + columnW, footerY, columnW, halfH, "MINIMUM CELL", metricAt(c, 9))
    drawSecondary(reportX + columnW * 2, footerY, columnW, halfH, "MINIMUM FUEL", metricAt(c, 10))
    drawSecondary(reportX, footerY + halfH, columnW, halfH, "MINIMUM LINK", metricAt(c, 7))
    drawSecondary(reportX + columnW, footerY + halfH, columnW * 2, halfH, "MINIMUM BEC", metricAt(c, 6))
end

local boxes_cache
local function boxes()
    if not boxes_cache then
        boxes_cache = {{col = 1, row = 1, colspan = 12, rowspan = 12,
            type = "func", subtype = "func", wakeup = postflightWakeup,
            paint = postflightPaint, bgcolor = "transparent"}}
    end
    return boxes_cache
end

return {layout = {cols = 12, rows = 12, padding = 0}, boxes = boxes,
    header_boxes = header_boxes, header_layout = header_layout,
    screenBorderStyle = {enabled = false},
    scheduler = {spread_scheduling = true, spread_scheduling_paint = false, spread_ratio = 0.85}}
