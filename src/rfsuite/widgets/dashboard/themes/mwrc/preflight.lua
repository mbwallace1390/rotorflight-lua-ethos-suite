--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local rfsuite = requireModule("widgets/dashboard/context.lua")
local lcd = lcd
local rawTonumber = tonumber
local function tonumber(value)
    local number = rawTonumber(value)
    if number == nil or number ~= number or number > 1000000000 or number < -1000000000 then return nil end
    return number
end
local tostring = tostring
local type = type
local ipairs = ipairs
local clock = os.clock
local format = string.format
local math = math
local floor = math.floor
local min = math.min
local max = math.max
local cos = math.cos
local sin = math.sin
local rad = math.rad

local utils = rfsuite.widgets.dashboard.utils

local FIT_FONTS = {FONT_XL="FONT_L", FONT_L="FONT_STD", FONT_STD="FONT_S", FONT_S="FONT_XS", FONT_XS="FONT_XXS"}
local function fitInstrumentText(box, cacheName, text, fontName, width)
    local fit = box[cacheName]
    if not fit then fit = {}; box[cacheName] = fit end
    if fit.text ~= text or fit.width ~= width or fit.requestedFont ~= fontName then
        fit.text, fit.width, fit.requestedFont = text, width, fontName
        local font = utils.resolveFont(fontName, nil)
        lcd.font(font)
        local tw, th = lcd.getTextSize(text)
        while tw > width and FIT_FONTS[fontName] do
            fontName = FIT_FONTS[fontName]
            font = utils.resolveFont(fontName, nil)
            lcd.font(font)
            tw, th = lcd.getTextSize(text)
        end
        fit.font, fit.w, fit.h = font, tw, th
    end
    lcd.font(fit.font)
    return fit.w, fit.h
end

-- Format recorded summaries locally so malformed durations cannot reach %d.
local function wakeFlightSummary(box)
    local session = rfsuite.session
    local general = session and session.modelPreferences and session.modelPreferences.general
    local modelName = model and model.name and model.name() or ""
    if box._summaryModel ~= modelName then
        -- A different radio model must never inherit the previous flight's summary.
        box._summaryModel, box._summaryLastValue = modelName, nil
    end
    local connected = session and session.isConnected and session.telemetryState
    local postflight = rfsuite.flightmode and rfsuite.flightmode.current == "postflight"
    local raw
    if box.summaryKind == "flight" then
        raw = session and session.timer and session.timer.live
        if raw == nil or (not connected and raw == 0) then
            if postflight and not connected and box._summaryLastValue ~= nil then
                raw = box._summaryLastValue
            else
                raw = general and general.lastflighttime
            end
        end
    elseif box.summaryKind == "total" then
        raw = general and general.totalflighttime
    else
        raw = general and general.flightcount
    end
    local value = tonumber(raw)
    if value and value < 0 then value = nil end
    -- Offline preflight has no verified count; the context's default zero is not a sample.
    if box.summaryKind == "count" and not connected and not postflight then value = nil end
    -- The context clears live summaries to zero on disconnect; retain only known history.
    if postflight and not connected and (raw == nil or raw == 0) and box._summaryLastValue ~= nil then
        value = box._summaryLastValue
    end
    box._summaryLastValue = value
    local key = value and math.floor(value) or false
    local cache = box._cache or {}
    if cache.key ~= key or cache.text == nil then
        cache.key = key
        if value == nil then cache.text = "--"
        elseif box.summaryKind == "flight" then
            cache.text = string.format("%02d:%02d", math.floor(value / 60), math.floor(value % 60))
        elseif box.summaryKind == "total" then
            cache.text = string.format("%02d:%02d:%02d", math.floor(value / 3600), math.floor(value / 60) % 60, math.floor(value % 60))
        else cache.text = tostring(math.floor(value)) end
    end
    return cache
end

local function paintFlightSummary(x, y, w, h, box, cache)
    local title = box.title or ""
    local tw, th = fitInstrumentText(box, "_titleFit", title, box.titlefont or "FONT_XS", w - 16)
    local bottom = box.titlepos == "bottom"
    local titleY = bottom and y + h - th - 8 or y + 8
    lcd.color(box.titlecolor)
    lcd.drawText(math.floor(x + (w - tw) / 2), math.floor(titleY), title)
    local text = cache and cache.text or "--"
    local vw, vh = fitInstrumentText(box, "_valueFit", text, box.font or "FONT_XL", w - 16)
    local valueY = bottom and y + math.max(2, (h - th - 16 - vh) / 2) or y + th + 12 + math.max(0, (h - th - 20 - vh) / 2)
    lcd.color(box.textcolor)
    lcd.drawText(math.floor(x + (w - vw) / 2), math.floor(valueY), text)
end

-- Keep the live craft/model name readable inside its native header slot.
local function paintModelName(x, y, w, h, box)
    local value = rfsuite.session and rfsuite.session.craftName
    if type(value) ~= "string" or value:match("^%s*$") then
        value = model and model.name and model.name() or "--"
    end
    if type(value) ~= "string" or value == "" then value = "--" end
    if box._modelValue ~= value or box._modelWidth ~= w then
        local text = value
        local font = utils.resolveFont("FONT_S", nil)
        lcd.font(font)
        local tw, th = lcd.getTextSize(text)
        if tw > w - 10 then
            font = utils.resolveFont("FONT_XS", nil)
            lcd.font(font)
            tw, th = lcd.getTextSize(text)
        end
        if tw > w - 10 then
            -- Shorten whole UTF-8 characters, only when name or geometry changes.
            local cut = #text
            repeat
                while cut > 1 and text:byte(cut) >= 128 and text:byte(cut) < 192 do cut = cut - 1 end
                cut = cut - 1
                text = value:sub(1, cut)
                tw, th = lcd.getTextSize(text .. "...")
            until tw <= w - 10 or cut == 0
            text = text .. "..."
        end
        box._modelValue, box._modelWidth = value, w
        box._modelText, box._modelFont, box._modelHeight = text, font, th
    end
    utils.drawBoxBackground(x, y, w, h, box.bgcolor)
    lcd.font(box._modelFont)
    lcd.color(box.textcolor)
    lcd.drawText(math.floor(x + 5), math.floor(y + (h - box._modelHeight) / 2), box._modelText)
end

local headeropts = utils.getHeaderOptions()
-- This theme owns its header geometry; leave the Suite defaults unchanged.
headeropts.height = math.max(headeropts.height or 0, 44)

-- Pre-cached Render Colors for Zero-Lag Performance
local rc = {
    strobeBright = lcd.RGB(255, 30, 30),
    strobeDark = lcd.RGB(60, 0, 0),
    amber = lcd.RGB(255, 170, 0),
    red = lcd.RGB(255, 0, 60),
    cyan = lcd.RGB(0, 240, 255),
    green = lcd.RGB(57, 255, 20),
    dim = lcd.RGB(30, 45, 60),
    bg = lcd.RGB(5, 8, 14),
    panel = lcd.RGB(12, 18, 28),
    white = lcd.RGB(230, 240, 255),
    orange = lcd.RGB(255, 105, 0),
    tick = lcd.RGB(64, 86, 110),
    cyanDim = lcd.RGB(0, 42, 52),
    amberDim = lcd.RGB(64, 38, 0)
}

-- Force Cyberpunk Neon Palette
local colorMode = {
    bgcolor = rc.bg,
    tbbgcolor = rc.panel,
    headerbgcolor = "transparent",
    titlecolor = rc.cyan,
    textcolor = rc.white,
    fillcolor = rc.green,
    fillwarncolor = rc.amber,
    fillcritcolor = rc.red,
    accentcolor = rc.cyan,
    cntextcolor = rc.white, tbtextcolor = rc.white, rssitextcolor = rc.white,
    txbgfillcolor = rc.dim, txaccentcolor = rc.cyan, txfillcolor = rc.green,
    rssifillcolor = rc.green, rssifillbgcolor = rc.dim,
    fillbgcolor = rc.dim
}




local theme_section = "system/mwrc"

local THEME_DEFAULTS = {rpm_min = 0, rpm_max = 3000, bec_min = 6.5, bec_warn = 8.0, bec_max = 12.0, esctemp_warn = 110, esctemp_max = 150}

local function getThemeValue(key)
    if key == "throttle_max" then return 100 end
    if key == "tx_min" or key == "tx_warn" or key == "tx_max" then
        local general = rfsuite.preferences and rfsuite.preferences.general
        local value = tonumber(general and general[key])
        if value ~= nil then return value end
    end
    -- The rewritten dashboard installs the selected theme's preferences here.
    local value = tonumber(rfsuite.widgets.dashboard.getPreference(key))
    return value or THEME_DEFAULTS[key]
end

local function getThemeOptionKey(W)
    return utils.getDashboardThemeOptionKey(W)
end

local themeOptions = {
    ls_full = {arctitlefont = "FONT_STD", tilefont = "FONT_XL", govfont = "FONT_XL", titlefont = "FONT_XS", tiletitlespacing = 4, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, flightvaluepaddingtop = 3, flightvaluepaddingbottom = 0, thickness = 32, titlepaddingbottom = 25},
    ls_std = {arctitlefont = "FONT_STD", tilefont = "FONT_STD", govfont = "FONT_STD", titlefont = "FONT_XS", tiletitlespacing = 4, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, flightvaluepaddingtop = 2, flightvaluepaddingbottom = 0, thickness = 18, titlepaddingbottom = 18},
    ms_full = {arctitlefont = "FONT_S", tilefont = "FONT_STD", govfont = "FONT_STD", titlefont = "FONT_XS", tiletitlespacing = 4, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, flightvaluepaddingtop = 2, flightvaluepaddingbottom = 0, thickness = 19, titlepaddingbottom = 16},
    ms_std = {arctitlefont = "FONT_S", tilefont = "FONT_S", govfont = "FONT_S", titlefont = "FONT_XS", tiletitlespacing = 3, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 2, tilevaluepaddingbottom = 0, flightvaluepaddingtop = 2, flightvaluepaddingbottom = 0, thickness = 14, titlepaddingbottom = 10},
    ss_full = {arctitlefont = "FONT_S", tilefont = "FONT_STD", govfont = "FONT_STD", titlefont = "FONT_XS", tiletitlespacing = 4, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, flightvaluepaddingtop = 2, flightvaluepaddingbottom = 0, thickness = 25, titlepaddingbottom = 15},
    ss_std = {arctitlefont = "FONT_S", tilefont = "FONT_S", govfont = "FONT_S", titlefont = "FONT_XS", tiletitlespacing = 3, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 2, tilevaluepaddingbottom = 0, flightvaluepaddingtop = 2, flightvaluepaddingbottom = 0, thickness = 14, titlepaddingbottom = 15}
}

local lastScreenW = nil
local boxes_cache = nil
local header_boxes_cache = nil
local themeconfig = nil
local last_txbatt_type = nil

local layout = {cols = 7, rows = 12, padding = 0}

local header_layout = utils.standardHeaderLayout(headeropts)
local topbarShiftY = 0
if header_layout and header_layout.height then
    header_layout.height = header_layout.height + topbarShiftY
end

-- Completely Disabled Outer Screen Border
local screenBorderStyle = {
    enabled = false,
    bordercolor = colorMode.accentcolor,
    backgroundcolor = colorMode.bgcolor,
    borderwidth = 6,
    inset = -1
}

local HEADER_LABEL = "Rotorflight // Ethos"
local HEADER_SIGNATURE = "| MWRC"
local headerTitleCache = {}
local function paintHeaderLogo(x, y, w, h)
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
    lcd.color(rc.cyan)
    lcd.drawText(groupX, math.floor(y + (h - cache._titleHeight) / 2), HEADER_LABEL)
    lcd.font(cache._markFont)
    lcd.color(rc.tick or rc.dim)
    lcd.drawText(groupX + cache._titleTextWidth + 8, math.floor(y + (h - cache._markHeight) / 2), HEADER_SIGNATURE)
end

local function header_boxes()
    local txbatt_type = 0
    if rfsuite and rfsuite.preferences and rfsuite.preferences.general then txbatt_type = rfsuite.preferences.general.txbatt_type or 0 end

    if header_boxes_cache == nil or last_txbatt_type ~= txbatt_type then
        local boxes = utils.standardHeaderBoxes(i18n, colorMode, headeropts, txbatt_type)
        local headerBgColor = rc.bg
        for _, box in ipairs(boxes) do
            box.bgcolor = headerBgColor
            box.yoffset = (box.yoffset or 0) + topbarShiftY

            if box.subtype == "craftname" then
                box.type, box.subtype = "func", "func"
                box.paint = paintModelName
            end
            if box.type == "image" then
                box.type = "func"
                box.subtype = "func"
                box.paint = paintHeaderLogo
            end
        end
        header_boxes_cache = boxes
        last_txbatt_type = txbatt_type
    end
    return header_boxes_cache
end

local function getStrobeColor(baseColor, isCritical)
    if isCritical then
        if floor(clock() * 6) % 2 == 0 then
            return rc.strobeBright
        else
            return rc.strobeDark
        end
    end
    return baseColor
end


local ARC_START = 155
local ARC_SWEEP = 230
local ARC_TICK_COUNT = 18
local ARC_TICKS = {}
for i = 0, ARC_TICK_COUNT do
    local angle = rad(ARC_START + (ARC_SWEEP * i / ARC_TICK_COUNT))
    ARC_TICKS[i + 1] = {c = cos(angle), s = sin(angle)}
end

local function drawArcSweep(cx, cy, radius, thickness, startAngle, sweep, color)
    if sweep <= 0 or radius <= 0 or thickness <= 0 then return end
    if sweep > 360 then sweep = 360 end

    local finish = startAngle + sweep
    if finish <= 360 then
        utils.drawArc(cx, cy, radius, thickness, startAngle, finish, color)
    else
        utils.drawArc(cx, cy, radius, thickness, startAngle, 360, color)
        utils.drawArc(cx, cy, radius, thickness, 0, finish - 360, color)
    end
end

local function formatGaugeValue(value, decimals)
    if decimals == 1 then
        return format("%.1f", value)
    elseif decimals == 2 then
        return format("%.2f", value)
    end
    return tostring(floor(value + 0.5))
end

-- =========================================================================
-- MODERN SEGMENTED SMART FUEL GAUGE
-- No solid inactive background: empty cells are outlines only.
-- =========================================================================
local FUEL_SEGMENT_COUNT = 10

local function getFuelSegmentColor(value)
    if value <= 25 then return rc.red end
    if value <= 50 then return rc.amber end
    return rc.green
end

local function wakeSegmentedFuel(box, telemetry)
    local cache = box._cache
    if type(cache) ~= "table" or cache._mode ~= "segmented_fuel" then
        cache = {
            _mode = "segmented_fuel",
            source = box.source or "smartfuel",
            value = 0,
            valueKey = false,
            valueText = "--%",
            activeSegments = 0,
            color = rc.dim,
            hasValue = false
        }
        box._cache = cache
    end

    local raw = nil
    if telemetry and telemetry.getSensor then
        raw = tonumber((telemetry.getSensor(cache.source)))
    end

    if raw ~= nil then
        local value = max(0, min(100, raw))
        local valueKey = floor(value + 0.5)

        if cache.valueKey ~= valueKey then
            cache.value = value
            cache.valueKey = valueKey
            cache.valueText = tostring(valueKey) .. "%"
            cache.activeSegments = valueKey > 0
                and max(1, min(FUEL_SEGMENT_COUNT, floor((valueKey / 100) * FUEL_SEGMENT_COUNT + 0.999)))
                or 0
            cache.color = getFuelSegmentColor(valueKey)
        end
        cache.hasValue = true
    elseif cache.hasValue then
        cache.hasValue = false
        cache.value = 0
        cache.valueKey = false
        cache.valueText = "--%"
        cache.activeSegments = 0
        cache.color = rc.dim
    end

    return cache
end

local function paintSegmentedFuel(x, y, w, h, box, cache)
    cache = cache or box._cache
    if not cache then return end

    local segmentCount = box.segmentcount or FUEL_SEGMENT_COUNT
    local gap = box.segmentgap or 3
    local paddingX = box.gaugepaddingleft or 7
    local capGap = 3
    local capW = max(3, min(6, floor(w * 0.025)))

    local valueFont = utils.resolveFont(box.font or "FONT_L", nil)
    local titleFont = utils.resolveFont(box.titlefont or "FONT_XS", nil)

    local valueText = cache.valueText or "--%"
    local valueH = 0
    if type(valueFont) == "number" then
        lcd.font(valueFont)
        local valueW
        valueW, valueH = lcd.getTextSize(valueText)
        lcd.color(box.textcolor or rc.white)
        lcd.drawText(floor(x + (w - valueW) / 2), y + (box.valuepaddingtop or 0), valueText)
    end

    local titleH = 0
    local titleY = y + h
    if type(titleFont) == "number" and box.title then
        lcd.font(titleFont)
        local titleW
        titleW, titleH = lcd.getTextSize(box.title)
        titleY = y + h - titleH - (box.titlepaddingbottom or 1)
        lcd.color(box.titlecolor or rc.cyan)
        lcd.drawText(floor(x + (w - titleW) / 2), titleY, box.title)
    end

    local availableTop = y + valueH + (box.gaugepaddingtop or 5)
    local availableBottom = titleY - (box.gaugepaddingbottom or 5)
    local availableH = max(8, availableBottom - availableTop)
    local segmentH = min(box.segmentheight or 20, availableH)
    local segmentY = floor(availableTop + (availableH - segmentH) / 2)

    local bodyW = w - (paddingX * 2) - capW - capGap
    local segmentW = floor((bodyW - gap * (segmentCount - 1)) / segmentCount)
    if segmentW < 2 then return end

    local active = min(segmentCount, cache.activeSegments or 0)
    local activeColor = cache.color or rc.green
    local startX = x + paddingX

    for i = 1, segmentCount do
        local sx = floor(startX + (i - 1) * (segmentW + gap))
        if i <= active then
            lcd.color(activeColor)
            lcd.drawFilledRectangle(sx, segmentY, segmentW, segmentH)
        else
            lcd.color(box.emptycolor or rc.dim)
            lcd.drawRectangle(sx, segmentY, segmentW, segmentH, 1)
        end
    end

    -- Minimal battery terminal and two small technical end marks.
    local capX = floor(startX + bodyW + capGap)
    local capH = max(5, floor(segmentH * 0.42))
    lcd.color(active > 0 and activeColor or (box.emptycolor or rc.dim))
    lcd.drawFilledRectangle(capX, floor(segmentY + (segmentH - capH) / 2), capW, capH)

    lcd.drawLine(startX - 3, segmentY, startX + 1, segmentY)
    lcd.drawLine(startX - 3, segmentY, startX - 3, segmentY + 4)
    lcd.drawLine(capX + capW + 3, segmentY + segmentH, capX + capW - 1, segmentY + segmentH)
    lcd.drawLine(capX + capW + 3, segmentY + segmentH, capX + capW + 3, segmentY + segmentH - 4)
end

local function wakeAesGauge(box, telemetry)
    local cache = box._cache
    if type(cache) ~= "table" or cache._mode ~= "neon_arc" then
        cache = {
            _mode = "neon_arc",
            source = box.source,
            value = nil,
            valueKey = false,
            maxKey = false,
            valText = "--",
            maxText = "",
            rangeText = "",
            color = box.accentcolor or colorMode.fillcolor,
            pct = 0,
            activeTicks = 0,
            hasValue = false,
            unit = box.unit or ""
        }
        box._cache = cache
    end

    local val = nil
    local unit = box.unit or ""
    local minValue = box.min or 0
    local maxValue = box.max or 100
    local thresholds = box.thresholds
    -- Present the value, range, unit, and thresholds in one unit system.
    if telemetry and telemetry.getSensor then
        local sensorPrecision, sensorUnit, sensorMin, sensorMax, sensorThresholds
        val, sensorPrecision, sensorUnit, sensorMin, sensorMax, sensorThresholds = telemetry.getSensor(cache.source, minValue, maxValue, thresholds)
        val = tonumber(val)
        if box.unit == nil and sensorUnit ~= nil then unit = sensorUnit end
        if sensorMin ~= nil then minValue = sensorMin end
        if sensorMax ~= nil then maxValue = sensorMax end
        if sensorThresholds ~= nil then thresholds = sensorThresholds end
    end

    local decimals = box.decimals or 0
    cache.unit = unit
    -- Rebuild the range label only when its presented form changes.
    if cache.rangeMin ~= minValue or cache.rangeMax ~= maxValue or cache.rangeDecimals ~= decimals or cache.rangeUnit ~= unit then
        cache.rangeText = "RANGE " .. formatGaugeValue(minValue, decimals) .. "–" .. formatGaugeValue(maxValue, decimals) .. unit
        cache.rangeMin = minValue
        cache.rangeMax = maxValue
        cache.rangeDecimals = decimals
        cache.rangeUnit = unit
    end
    if val == nil then
        if cache.hasValue then
            cache.hasValue = false
            cache.value = nil
            cache.valueKey = false
            cache.valText = "--"
            cache.pct = 0
            cache.activeTicks = 0
            cache.color = box.accentcolor or colorMode.fillcolor
            if box.arcmax then
                cache.maxKey = false
                cache.maxUnit = nil
                cache.maxText = ""
            end
        end
        return cache
    end
    cache.hasValue = true
    cache.value = val

    local multiplier = decimals == 2 and 100 or (decimals == 1 and 10 or 1)
    local valueKey = floor(val * multiplier + 0.5)
    if cache.valueKey ~= valueKey then
        cache.valText = formatGaugeValue(val, decimals)
        cache.valueKey = valueKey
    end

    if box.arcmax then
        -- Dashboard stats reset per flight and already follow the temperature unit preference.
        local stats = telemetry and telemetry.getSensorStats and telemetry.getSensorStats(cache.source)
        local maxVal = tonumber(stats and stats.max) or val
        local maxKey = floor(maxVal * multiplier + 0.5)
        if cache.maxKey ~= maxKey or cache.maxUnit ~= unit then
            cache.maxText = "MAX " .. formatGaugeValue(maxVal, decimals) .. (unit == "RPM" and " RPM" or unit)
            cache.maxKey = maxKey
            cache.maxUnit = unit
        end
    end

    local activeColor = box.accentcolor or colorMode.fillcolor
    if thresholds then
        for _, threshold in ipairs(thresholds) do
            activeColor = threshold.fillcolor or activeColor
            if val <= threshold.value then break end
        end
    end
    cache.color = activeColor

    local span = maxValue - minValue
    local pct = span > 0 and ((val - minValue) / span) or 0
    cache.pct = max(0, min(1, pct))
    cache.activeTicks = floor(cache.pct * ARC_TICK_COUNT + 0.5)

    return cache
end

-- Multi-layer neon arc with glow rail, active ticks and a bright sweep marker.
local function paintAesGauge(x, y, w, h, box, cache)
    if not cache or cache._mode ~= "neon_arc" then return end

    local radius = floor(min(w * 0.44, h * 0.39))
    if radius < 12 then return end

    local cx = floor(x + w * 0.5)
    local cy = floor(y + h * 0.50)
    local thickness = floor(max(5, min(box.thickness or 14, radius * 0.28)))
    local pct = cache.pct or 0
    local activeSweep = ARC_SWEEP * pct
    local activeColor = cache.color or box.accentcolor or colorMode.fillcolor
    local isCritical = activeColor == colorMode.fillcritcolor or activeColor == rc.red
    local drawColor = getStrobeColor(activeColor, isCritical) or activeColor
    local glowColor = box.glowcolor or rc.dim
    local trackColor = box.trackcolor or rc.panel
    local tickColor = box.tickcolor or rc.tick

    -- Soft outer glow, dark body and inner technical rail.
    drawArcSweep(cx, cy, radius, thickness + 7, ARC_START, ARC_SWEEP, glowColor)
    drawArcSweep(cx, cy, radius, thickness + 2, ARC_START, ARC_SWEEP, trackColor)
    drawArcSweep(cx, cy, radius - floor(thickness * 0.52) - 2, 2, ARC_START, ARC_SWEEP, tickColor)

    if pct > 0 then
        drawArcSweep(cx, cy, radius, thickness + 5, ARC_START, activeSweep, glowColor)
        drawArcSweep(cx, cy, radius, thickness, ARC_START, activeSweep, drawColor)
        drawArcSweep(cx, cy, radius + floor(thickness * 0.5) - 1, 2, ARC_START, activeSweep, drawColor)
    end

    -- Scale ticks. Major ticks are longer; completed ticks inherit the active color.
    local tickOuter = radius - floor(thickness * 0.55) - 4
    for i = 0, ARC_TICK_COUNT do
        local vector = ARC_TICKS[i + 1]
        local major = (i % 3) == 0
        local tickLength = major and 9 or 5
        local tickInner = tickOuter - tickLength
        lcd.color(i <= cache.activeTicks and drawColor or tickColor)
        lcd.drawLine(
            floor(cx + vector.c * tickInner),
            floor(cy + vector.s * tickInner),
            floor(cx + vector.c * tickOuter),
            floor(cy + vector.s * tickOuter)
        )
    end

    -- Bright endpoint marker gives the active sweep a precise instrument look.
    if pct > 0 then
        local endAngle = rad(ARC_START + activeSweep)
        local ec, es = cos(endAngle), sin(endAngle)
        local markerInner = radius - floor(thickness * 0.62)
        local markerOuter = radius + floor(thickness * 0.62)
        lcd.color(rc.white)
        lcd.drawLine(
            floor(cx + ec * markerInner),
            floor(cy + es * markerInner),
            floor(cx + ec * markerOuter),
            floor(cy + es * markerOuter)
        )
    end

    -- Small endpoint blocks and lower data rail.
    local startVector = ARC_TICKS[1]
    local endVector = ARC_TICKS[#ARC_TICKS]
    lcd.color(tickColor)
    lcd.drawFilledRectangle(floor(cx + startVector.c * radius) - 2, floor(cy + startVector.s * radius) - 2, 4, 4)
    lcd.drawFilledRectangle(floor(cx + endVector.c * radius) - 2, floor(cy + endVector.s * radius) - 2, 4, 4)
    local railY = floor(cy + radius * 0.58)
    lcd.drawLine(floor(cx - radius * 0.46), railY, floor(cx + radius * 0.46), railY)

    local titleFont = utils.resolveFont(box.titlefont or "FONT_S", nil)
    if type(titleFont) == "number" and box.title then
        lcd.font(titleFont)
        lcd.color(box.titlecolor or colorMode.titlecolor)
        local titleW, titleH = fitInstrumentText(box, "_titleFit", box.title, box.titlefont or "FONT_S", w - 20)
        local titleX = floor(cx - titleW / 2)
        local titleY = y + 8
        lcd.drawText(titleX, titleY, box.title)
        lcd.color(drawColor)
        local underlineY = titleY + titleH + 2
        lcd.drawLine(titleX, underlineY, titleX + titleW, underlineY)
    end

    local valueFont = utils.resolveFont(box.font or "FONT_XL", nil)
    if type(valueFont) == "number" then
        lcd.font(valueFont)
        lcd.color(colorMode.textcolor)
        local valueW, valueH = fitInstrumentText(box, "_valueFit", cache.valText, box.font or "FONT_XL", w - 32)
        local valueY = floor(cy - valueH * 0.55)
        lcd.drawText(floor(cx - valueW / 2), valueY, cache.valText)

        local unit = cache.unit
        if unit and unit ~= "" then
            local unitFont = utils.resolveFont(box.unitfont or "FONT_XS", nil)
            if type(unitFont) == "number" then
                lcd.font(unitFont)
                lcd.color(drawColor)
                local unitW = lcd.getTextSize(unit)
                lcd.drawText(floor(cx - unitW / 2), valueY + valueH - 1, unit)
            end
        end
    end

    local footer = box.arcmax and cache.maxText or cache.rangeText
    if footer and footer ~= "" then
        local footerFont = utils.resolveFont(box.maxfont or "FONT_XS", nil)
        if type(footerFont) == "number" then
            lcd.font(footerFont)
            lcd.color(box.maxtextcolor or colorMode.fillwarncolor)
            local footerW, footerH = fitInstrumentText(box, "_footerFit", footer, box.maxfont or "FONT_XS", w - 20)
            lcd.drawText(floor(cx - footerW / 2), y + h - footerH - 3, footer)
        end
    end
end


local function paintBackdrop(x, y, w, h)
    -- Theme-owned surface is painted before instrument and header boxes.
    local screenW, screenH = lcd.getWindowSize()
    lcd.color(rc.bg)
    lcd.drawFilledRectangle(0, 0, screenW, screenH)
    lcd.color(rc.panel)
    lcd.drawFilledRectangle(x + 4, y + 4, math.max(1, w - 8), math.max(1, h - 8))
    lcd.color(rc.dim)
    lcd.drawRectangle(x + 4, y + 4, math.max(1, w - 8), math.max(1, h - 8))
    lcd.color(rc.cyan)
    lcd.drawFilledRectangle(x + 4, y + 4, math.max(1, math.floor(w * 0.12)), 2)
end

local function buildBoxes(W)
    local opts = themeOptions[getThemeOptionKey(W)] or themeOptions.ls_full

    return {
        {col = 1, row = 1, colspan = layout.cols, rowspan = layout.rows,
            type = "func", subtype = "func", paint = paintBackdrop, bgcolor = "transparent"},
        {
            col = 1, row = 1, colspan = 3, rowspan = 9,
            type = "image", subtype = "model", imagewidth = 280, imageheight = 300, imagealign = "center",
            bgcolor = "transparent"
        },
        {
            col = 4, row = 9, rowspan = 2, yoffset = -15,
            type = "text", subtype = "telemetry", source = "rate_profile", title = "RATES", titlepos = "bottom",
            font = opts.tilefont, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingbottom = opts.tiletitlepaddingbottom, valuepaddingtop = opts.tilevaluepaddingtop, valuepaddingbottom = opts.tilevaluepaddingbottom,
            bgcolor = "transparent", titlecolor = colorMode.titlecolor, transform = "floor",
            thresholds = {{value = 1.5, textcolor = rc.cyan}, {value = 2.5, textcolor = rc.amber}, {value = 6, textcolor = rc.green}}
        },
        {
            col = 5, row = 9, rowspan = 2, yoffset = -15,
            type = "text", subtype = "telemetry", source = "pid_profile", title = "PROFILE", titlepos = "bottom",
            font = opts.tilefont, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingbottom = opts.tiletitlepaddingbottom, valuepaddingtop = opts.tilevaluepaddingtop, valuepaddingbottom = opts.tilevaluepaddingbottom,
            bgcolor = "transparent", titlecolor = colorMode.titlecolor, transform = "floor",
            thresholds = {{value = 1.5, textcolor = rc.cyan}, {value = 2.5, textcolor = rc.amber}, {value = 6, textcolor = rc.green}}
        },
        {
            col = 6, row = 9, colspan = 2, rowspan = 2, xoffset = -5, yoffset = -15,
            type = "func", subtype = "func", summaryKind = "count", wakeup = wakeFlightSummary, paint = paintFlightSummary, title = "FLIGHTS", titlepos = "bottom",
            font = opts.tilefont, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingbottom = opts.tiletitlepaddingbottom, valuepaddingtop = opts.flightvaluepaddingtop, valuepaddingbottom = opts.flightvaluepaddingbottom,
            bgcolor = "transparent", titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor
        },

        -- Modern segmented Smart Fuel battery
        {
            col = 1, row = 10, colspan = 3, rowspan = 3, xoffset = 4, yoffset = -1,
            type = "func", subtype = "func",
            source = "smartfuel",
            wakeup = wakeSegmentedFuel,
            paint = paintSegmentedFuel,
            title = "SMART FUEL",
            font = "FONT_XL",
            titlefont = opts.titlefont,
            titlecolor = rc.cyan,
            textcolor = rc.white,
            segmentcount = 10,
            segmentgap = 4,
            segmentheight = 20,
            gaugepaddingleft = 10,
            gaugepaddingtop = 4,
            gaugepaddingbottom = 4,
            bgcolor = "transparent"
        },

        {
            col = 4, colspan = 2, row = 1, rowspan = 7, xoffset = 0, yoffset = 0,
            type = "func", subtype = "func", wakeup = wakeAesGauge, paint = paintAesGauge,
            bgcolor = "transparent",
            source = "bec_voltage", title = "BEC VOLT", titlepos = "bottom", decimals = 1, unit = "V", accentcolor = rc.cyan, glowcolor = rc.cyanDim,
            titlepaddingbottom = opts.titlepaddingbottom, valuepaddingtop = 30, font = "FONT_XL", titlefont = opts.arctitlefont, min = getThemeValue("bec_min"), max = getThemeValue("bec_max"),
            thickness = math.max(3, math.floor(opts.thickness * 0.4)),
            thresholds = {{value = getThemeValue("bec_min"), fillcolor = rc.red}, {value = getThemeValue("bec_warn"), fillcolor = rc.amber}, {value = getThemeValue("bec_max"), fillcolor = rc.cyan}, {value = 100, fillcolor = rc.red}}
        },
        {
            col = 4, row = 11, colspan = 2, rowspan = 2, yoffset = -10,
            type = "text", subtype = "blackbox", title = "BLACKBOX", titlepos = "bottom",
            font = opts.tilefont, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingbottom = opts.tiletitlepaddingbottom, valuepaddingtop = opts.tilevaluepaddingtop, valuepaddingbottom = opts.tilevaluepaddingbottom, decimals = 0,
            bgcolor = "transparent", titlecolor = colorMode.titlecolor, transform = "floor",
            thresholds = {{value = 80, textcolor = colorMode.textcolor}, {value = 90, textcolor = rc.amber}, {value = 100, textcolor = rc.red}}
        },
        {
            col = 6, colspan = 2, row = 1, rowspan = 7, xoffset = 0, yoffset = 0,
            type = "func", subtype = "func", wakeup = wakeAesGauge, paint = paintAesGauge,
            bgcolor = "transparent",
            source = "temp_esc", title = "ESC TEMP", titlepos = "bottom", accentcolor = rc.orange, glowcolor = rc.amberDim,
            font = "FONT_XL", titlefont = opts.arctitlefont, min = 0, max = getThemeValue("esctemp_max"),
            thickness = math.max(3, math.floor(opts.thickness * 0.4)),
            thresholds = {{value = getThemeValue("esctemp_warn"), fillcolor = rc.orange}, {value = getThemeValue("esctemp_max"), fillcolor = rc.amber}, {value = 10000, fillcolor = rc.red}}
        },
        {
            col = 6, row = 11, colspan = 2, rowspan = 2, xoffset = -5, yoffset = -10,
            type = "text", subtype = "governor", title = "GOVERNOR", titlepos = "bottom",
            font = opts.govfont, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingbottom = opts.tiletitlepaddingbottom, valuepaddingtop = opts.tilevaluepaddingtop, valuepaddingbottom = opts.tilevaluepaddingbottom,
            bgcolor = "transparent", titlecolor = colorMode.titlecolor,
            thresholds = {
                {value = "DISARMED", textcolor = rc.green}, {value = "OFF", textcolor = rc.amber}, {value = "IDLE", textcolor = rc.amber}, {value = "SPOOLUP", textcolor = rc.red}, {value = "RECOVERY", textcolor = rc.amber}, {value = "ACTIVE", textcolor = rc.red},
                {value = "THR OFF", textcolor = rc.green}
            }
        }
    }
end

local function boxes()
    local config = rfsuite.preferences and rfsuite.preferences.dashboard
    local W = lcd.getWindowSize()
    if boxes_cache == nil or themeconfig ~= config or lastScreenW ~= W then
        boxes_cache = buildBoxes(W)
        themeconfig = config
        lastScreenW = W
    end
    return boxes_cache
end

return {layout = layout, boxes = boxes, header_boxes = header_boxes, header_layout = header_layout, screenBorderStyle = screenBorderStyle, scheduler = {spread_scheduling = true, spread_scheduling_paint = false, spread_ratio = 0.8}}
