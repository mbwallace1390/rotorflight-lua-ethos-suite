--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — [https://www.gnu.org/licenses/gpl-3.0.en.html](https://www.gnu.org/licenses/gpl-3.0.en.html)
]] --

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local rfsuite = requireModule("widgets/dashboard/context.lua")
local lcd = lcd

local floor = math.floor
local min = math.min
local max = math.max
local rawTonumber = tonumber
local function tonumber(value)
    local number = rawTonumber(value)
    if number == nil or number ~= number or number > 1000000000 or number < -1000000000 then return nil end
    return number
end
local ipairs = ipairs

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
    bg = lcd.RGB(2, 5, 10),
    panel = lcd.RGB(8, 16, 28),
    cyan = lcd.RGB(64, 145, 255),
    amber = lcd.RGB(216, 178, 83),
    red = lcd.RGB(227, 58, 66),
    green = lcd.RGB(83, 210, 104),
    orange = lcd.RGB(227, 112, 59),
    magenta = lcd.RGB(216, 178, 83),
    white = lcd.RGB(230, 240, 255),
    dim = lcd.RGB(24, 46, 75)
}

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

local theme_section = "system/libertyops250"

local THEME_DEFAULTS = {rpm_min = 0, rpm_max = 3000, bec_min = 3.0, bec_warn = 6.0, bec_max = 13.0, esctemp_warn = 90, esctemp_max = 140}

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
    ls_full = {font = "FONT_XL", titlefont = "FONT_XS", titlepaddingtop = 5, thickness = 24, tilefont = "FONT_XXL", tiletitlespacing = 4, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, gaugepaddingtop = 7, gaugepaddingbottom = 13, iconsize = 32, iconpadleft = 12, iconvalueshift = 38},
    ls_std = {font = "FONT_L", titlefont = "FONT_XS", titlepaddingtop = 2, thickness = 18, tilefont = "FONT_XL", tiletitlespacing = 4, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, gaugepaddingtop = 1, gaugepaddingbottom = 10, iconsize = 26, iconpadleft = 9, iconvalueshift = 31},
    ms_full = {font = "FONT_L", titlefont = "FONT_XS", titlepaddingtop = 2, thickness = 16, tilefont = "FONT_XL", tiletitlespacing = 4, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, gaugepaddingtop = 1, gaugepaddingbottom = 9, iconsize = 32, iconpadleft = 12, iconvalueshift = 38},
    ms_std = {font = "FONT_S", titlefont = "FONT_XS", titlepaddingtop = 0, thickness = 12, tilefont = "FONT_L", tiletitlespacing = 3, tilevaluepaddingtop = 2, tilevaluepaddingbottom = 0, gaugepaddingtop = 1, gaugepaddingbottom = 7, iconsize = 26, iconpadleft = 9, iconvalueshift = 31},
    ss_full = {font = "FONT_L", titlefont = "FONT_XS", titlepaddingtop = 2, thickness = 16, tilefont = "FONT_XL", tiletitlespacing = 4, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, gaugepaddingtop = 1, gaugepaddingbottom = 9, iconsize = 32, iconpadleft = 12, iconvalueshift = 38},
    ss_std = {font = "FONT_S", titlefont = "FONT_XXS", titlepaddingtop = -11, thickness = 12, tilefont = "FONT_S", tiletitlespacing = 0, tilevaluepaddingtop = 0, tilevaluepaddingbottom = 0, gaugepaddingtop = 1, gaugepaddingbottom = 7, iconsize = 26, iconpadleft = 9, iconvalueshift = 31}
}

local lastScreenW = nil
local boxes_cache = nil
local header_boxes_cache = nil
local last_txbatt_type = nil
local themeconfig = nil

local layout = {cols = 12, rows = 12, padding = 0}
local screenBorderStyle = {
    enabled = false,
    bordercolor = colorMode.accentcolor or colorMode.rssifillbgcolor,
    borderwidth = 5,
    inset = 0
}

local header_layout = utils.standardHeaderLayout(headeropts)
local topbarShiftY = 0
if header_layout and header_layout.height then
    header_layout.height = header_layout.height + topbarShiftY
end

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

-- Each statistic card owns a small reusable cache and rejects corrupt samples.
local function wakeStatTile(box, telemetry)
    local cache = box._cache
    if not cache then
        cache = {text = "--", percent = 0, color = box.fillcolor or rc.cyan}
        box._cache = cache
    end
    local statSource = box.source == "rssi" and "vfr" or box.source
    local stats = telemetry and telemetry.getSensorStats and telemetry.getSensorStats(statSource)
    local value = tonumber(stats and stats[box.stattype or "max"])
    if box.source == "rssi" then
        -- Prefer recorded VFR; the Suite's RSSI fallback can return minLink in dB.
        -- Only an explicit RSSI statistic is safe as a percentage fallback.
        if value == nil or value < 0 or value > 100 then
            local allStats = telemetry and telemetry.sensorStats
            local fallback = allStats and allStats.rssi
            value = tonumber(fallback and fallback[box.stattype or "max"])
        end
        if value ~= nil and (value < 0 or value > 100) then value = nil end
    end
    local unit = box.unit
    local minimum, maximum, thresholds = box.min or 0, box.max or 100, box.thresholds
    if telemetry and telemetry.getSensor then
        local live, precision, sensorUnit, sensorMin, sensorMax, sensorThresholds = telemetry.getSensor(box.source, minimum, maximum, thresholds)
        if unit == nil then unit = sensorUnit end
        minimum = tonumber(sensorMin) or minimum
        maximum = tonumber(sensorMax) or maximum
        thresholds = sensorThresholds or thresholds
    end
    local decimals = box.decimals or 0
    local multiplier = decimals == 2 and 100 or (decimals == 1 and 10 or 1)
    local key = false
    if value ~= nil then key = floor(value * multiplier + 0.5) end
    unit = unit or ""
    if cache.valueKey ~= key or cache.unit ~= unit then
        -- Reformat only the displayed precision or unit changes.
        cache.valueKey, cache.unit = key, unit
        if value == nil then
            cache.text = "--"
        elseif decimals == 2 then
            cache.text = string.format("%.2f", value) .. unit
        elseif decimals == 1 then
            cache.text = string.format("%.1f", value) .. unit
        else
            cache.text = tostring(floor(value + 0.5)) .. unit
        end
    end
    local color = box.fillcolor or rc.cyan
    if value ~= nil and thresholds then
        for i = 1, #thresholds do
            local threshold = thresholds[i]
            color = threshold.fillcolor or color
            if value <= threshold.value then break end
        end
    end
    cache.color = color
    local span = maximum - minimum
    cache.percent = value ~= nil and span > 0 and max(0, min(1, (value - minimum) / span)) or 0
    return cache
end

local function paintStatTile(x, y, w, h, box, cache)
    if not cache then return end
    -- A compact card keeps the value above a thin rail at every radio height.
    x, y, w, h = x + 5, y + 2, max(1, w - 10), max(1, h - 5)
    lcd.color(rc.bg)
    lcd.drawFilledRectangle(x, y, w, h)
    lcd.color(rc.dim)
    lcd.drawRectangle(x, y, w, h)
    lcd.color(box.titlecolor or rc.cyan)
    lcd.drawFilledRectangle(x, y, 2, h)
    local compact = h < 65 or w < 190
    lcd.font(compact and (FONT_XXS or FONT_XS) or FONT_XS)
    local titleW, titleH = lcd.getTextSize(box.title or "")
    lcd.color(box.titlecolor or rc.cyan)
    lcd.drawText(x + max(6, floor((w - titleW) / 2)), y + 4, box.title or "")
    lcd.font(compact and FONT_S or FONT_XL)
    local valueW, valueH = lcd.getTextSize(cache.text)
    if valueW > w - 12 then
        lcd.font(FONT_XS)
        valueW, valueH = lcd.getTextSize(cache.text)
    end
    lcd.color(rc.white)
    lcd.drawText(x + max(6, floor((w - valueW) / 2)), y + max(titleH + 5, floor((h - valueH) * 0.62)), cache.text)
    if h >= 50 then
        lcd.color(rc.dim)
        lcd.drawFilledRectangle(x + 9, y + h - 7, max(1, w - 18), 3)
        local fill = floor((w - 18) * cache.percent)
        if fill > 0 then
            lcd.color(cache.color)
            lcd.drawFilledRectangle(x + 9, y + h - 7, fill, 3)
        end
    end
end

local function buildBoxes(W)
    local opts = themeOptions[getThemeOptionKey(W)] or themeOptions.ls_full

    local function makeGaugeTileBg(bordercolor)
        return {
            color = rc.panel,
            bordercolor = bordercolor,
            borderwidth = 2,
            roundradius = 6,
            inset = 5,
            contentpadding = 1
        }
    end

    local cyanTileBg = makeGaugeTileBg(rc.cyan)
    local greenTileBg = makeGaugeTileBg(rc.green)
    local amberTileBg = makeGaugeTileBg(rc.amber)
    local orangeTileBg = makeGaugeTileBg(rc.orange)
    local magentaTileBg = makeGaugeTileBg(rc.magenta)


    return {
        {col = 1, row = 1, colspan = layout.cols, rowspan = layout.rows,
            type = "func", subtype = "func", paint = paintBackdrop, bgcolor = "transparent"},

        -- Flight Timers
        {
            col = 5, row = 1, colspan = 4, rowspan = 3,
            type = "func", subtype = "func", summaryKind = "flight", wakeup = wakeFlightSummary, paint = paintFlightSummary, title = "Flight Time", titlepos = "top",
            titlealign = "center", valuealign = "center", font = opts.tilefont, titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing, titlepaddingtop = opts.titlepaddingtop + 11,
            valuepaddingtop = opts.tilevaluepaddingtop, valuepaddingbottom = opts.tilevaluepaddingbottom,
            bgcolor = "transparent", titlecolor = rc.cyan, textcolor = rc.white
        },
        {
            col = 9, row = 1, colspan = 4, rowspan = 3,
            type = "func", subtype = "func", summaryKind = "total", wakeup = wakeFlightSummary, paint = paintFlightSummary, title = "Total Flight Time", titlepos = "top",
            titlealign = "center", valuealign = "center", font = opts.tilefont, titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing, titlepaddingtop = opts.titlepaddingtop + 11,
            valuepaddingtop = opts.tilevaluepaddingtop, valuepaddingbottom = opts.tilevaluepaddingbottom,
            bgcolor = "transparent", titlecolor = rc.cyan, textcolor = rc.white
        },
        {
            col = 1, row = 1, colspan = 4, rowspan = 3,
            type = "func", subtype = "func", summaryKind = "count", wakeup = wakeFlightSummary, paint = paintFlightSummary, title = "Flights", titlepos = "top",
            titlealign = "center", valuealign = "center", font = opts.tilefont, titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing, titlepaddingtop = opts.titlepaddingtop + 11,
            valuepaddingtop = opts.tilevaluepaddingtop, valuepaddingbottom = opts.tilevaluepaddingbottom,
            bgcolor = "transparent", titlecolor = rc.cyan, textcolor = rc.white, transform = "floor"
        },

        -- Stat Gauges
        {
            col = 1, row = 10, colspan = 4, rowspan = 3,
            type = "func", subtype = "func", wakeup = wakeStatTile, paint = paintStatTile, source = "altitude", stattype = "max", title = "Max Altitude", unit = "m",
            min = 0, max = 450, titlepos = "top", titlealign = "center", valuealign = "center",
            font = opts.font, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingtop = opts.titlepaddingtop + 11,
            valuepaddingleft = opts.iconvalueshift,
            thickness = math.max(4, opts.thickness - 4), gaugepadding = 12, gaugepaddingtop = opts.gaugepaddingtop, gaugepaddingbottom = opts.gaugepaddingbottom, gaugepaddingleft = 13, gaugepaddingright = 13,
            bgcolor = cyanTileBg, fillcolor = rc.cyan, textcolor = rc.white, titlecolor = rc.cyan, transform = "floor"
        },
        {
            col = 5, row = 10, colspan = 4, rowspan = 3,
            type = "func", subtype = "func", wakeup = wakeStatTile, paint = paintStatTile, source = "watts", stattype = "max", title = "Max Watts", unit = "W",
            min = 0, max = 10000, titlepos = "top", titlealign = "center", valuealign = "center",
            font = opts.font, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingtop = opts.titlepaddingtop + 11,
            valuepaddingleft = opts.iconvalueshift,
            thickness = math.max(4, opts.thickness - 4), gaugepadding = 12, gaugepaddingtop = opts.gaugepaddingtop, gaugepaddingbottom = opts.gaugepaddingbottom, gaugepaddingleft = 13, gaugepaddingright = 13,
            bgcolor = greenTileBg, fillcolor = rc.green, textcolor = rc.white, titlecolor = rc.green, transform = "floor"
        },
        {
            col = 5, row = 7, colspan = 4, rowspan = 3,
            type = "func", subtype = "func", wakeup = wakeStatTile, paint = paintStatTile, source = "current", stattype = "max", title = "Max Amps", unit = "A",
            min = 0, max = 300, titlepos = "top", titlealign = "center", valuealign = "center",
            font = opts.font, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingtop = opts.titlepaddingtop + 11,
            valuepaddingleft = opts.iconvalueshift,
            thickness = math.max(4, opts.thickness - 4), gaugepadding = 12, gaugepaddingtop = opts.gaugepaddingtop, gaugepaddingbottom = opts.gaugepaddingbottom, gaugepaddingleft = 13, gaugepaddingright = 13,
            bgcolor = cyanTileBg, fillcolor = rc.cyan, textcolor = rc.white, titlecolor = rc.cyan, transform = "floor"
        },
        {
            col = 1, row = 4, colspan = 4, rowspan = 3,
            type = "func", subtype = "func", wakeup = wakeStatTile, paint = paintStatTile, source = "rpm", stattype = "max", title = "Peak headspeed", unit = " RPM",
            min = 0, max = 5500, titlepos = "top", titlealign = "center", valuealign = "center",
            font = opts.font, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingtop = opts.titlepaddingtop + 11,
            valuepaddingleft = opts.iconvalueshift,
            thickness = math.max(4, opts.thickness - 4), gaugepadding = 12, gaugepaddingtop = opts.gaugepaddingtop, gaugepaddingbottom = opts.gaugepaddingbottom, gaugepaddingleft = 13, gaugepaddingright = 13,
            bgcolor = magentaTileBg, fillcolor = rc.magenta, textcolor = rc.white, titlecolor = rc.magenta, transform = "floor"
        },
        {
            col = 1, row = 7, colspan = 4, rowspan = 3,
            type = "func", subtype = "func", wakeup = wakeStatTile, paint = paintStatTile, source = "rssi", stattype = "min", title = "Link Min", unit = "%",
            min = 0, max = 100, titlepos = "top", titlealign = "center", valuealign = "center",
            font = opts.font, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingtop = opts.titlepaddingtop + 11,
            valuepaddingleft = opts.iconvalueshift,
            thickness = math.max(4, opts.thickness - 4), gaugepadding = 12, gaugepaddingtop = opts.gaugepaddingtop, gaugepaddingbottom = opts.gaugepaddingbottom, gaugepaddingleft = 13, gaugepaddingright = 13,
            bgcolor = cyanTileBg, fillcolor = rc.cyan, textcolor = rc.white, titlecolor = rc.cyan,
            thresholds = {
                {value = 45, fillcolor = rc.red},
                {value = 75, fillcolor = rc.amber},
                {value = 100, fillcolor = rc.cyan}
            },
            transform = "floor"
        },
        {
            col = 9, row = 4, colspan = 4, rowspan = 3,
            type = "func", subtype = "func", wakeup = wakeStatTile, paint = paintStatTile, source = "smartconsumption", stattype = "max", title = "Used capacity", unit = "mAh",
            min = 0, max = 5000, titlepos = "top", titlealign = "center", valuealign = "center",
            font = opts.font, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingtop = opts.titlepaddingtop + 11,
            valuepaddingleft = opts.iconvalueshift,
            thickness = math.max(4, opts.thickness - 4), gaugepadding = 12, gaugepaddingtop = opts.gaugepaddingtop, gaugepaddingbottom = opts.gaugepaddingbottom, gaugepaddingleft = 13, gaugepaddingright = 13,
            bgcolor = amberTileBg, fillcolor = rc.amber, textcolor = rc.white, titlecolor = rc.amber,
            thresholds = {
                {value = 2250, fillcolor = rc.amber},
                {value = 4000, fillcolor = rc.red},
                {value = math.huge, fillcolor = rc.red}
            },
            transform = "floor"
        },
        {
            col = 5, row = 4, colspan = 4, rowspan = 3,
            type = "func", subtype = "func", wakeup = wakeStatTile, paint = paintStatTile, source = "smartfuel", stattype = "min", title = "Fuel reserve", unit = "%",
            min = 0, max = 100, titlepos = "top", titlealign = "center", valuealign = "center",
            font = opts.font, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingtop = opts.titlepaddingtop + 11,
            valuepaddingleft = opts.iconvalueshift,
            thickness = math.max(4, opts.thickness - 4), gaugepadding = 12, gaugepaddingtop = opts.gaugepaddingtop, gaugepaddingbottom = opts.gaugepaddingbottom, gaugepaddingleft = 13, gaugepaddingright = 13,
            bgcolor = greenTileBg, fillcolor = rc.green, textcolor = rc.white, titlecolor = rc.green,
            thresholds = {
                {value = 25, fillcolor = rc.red},
                {value = 50, fillcolor = rc.amber},
                {value = 100, fillcolor = rc.green}
            },
            transform = "floor"
        },
        {
            col = 9, row = 10, colspan = 4, rowspan = 3,
            -- Use the captured cell minimum; current pack/cell-count data can be gone after disconnect.
            type = "func", subtype = "func", wakeup = wakeStatTile, paint = paintStatTile, source = "cell_voltage", stattype = "min", title = "Minimum cell", unit = "V",
            min = 3.2, max = 4.35, gaugevalue = "display", titlepos = "top", titlealign = "center", valuealign = "center",
            font = opts.font, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingtop = opts.titlepaddingtop + 11,
            valuepaddingleft = opts.iconvalueshift,
            thickness = math.max(4, opts.thickness - 4), gaugepadding = 12, gaugepaddingtop = opts.gaugepaddingtop, gaugepaddingbottom = opts.gaugepaddingbottom, gaugepaddingleft = 13, gaugepaddingright = 13,
            bgcolor = cyanTileBg, fillcolor = rc.cyan, textcolor = rc.white, titlecolor = rc.cyan,
            thresholds = {
                {value = 3.70, fillcolor = rc.red},
                {value = 3.85, fillcolor = rc.amber},
                {value = 4.35, fillcolor = rc.cyan}
            },
            decimals = 2
        },
        {
            col = 9, row = 7, colspan = 4, rowspan = 3,
            type = "func", subtype = "func", wakeup = wakeStatTile, paint = paintStatTile, source = "temp_esc", stattype = "max", title = "Peak ESC temp",
            min = 0, max = getThemeValue("esctemp_max"), titlepos = "top", titlealign = "center", valuealign = "center",
            font = opts.font, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingtop = opts.titlepaddingtop + 11,
            valuepaddingleft = opts.iconvalueshift,
            thickness = math.max(4, opts.thickness - 4), gaugepadding = 12, gaugepaddingtop = opts.gaugepaddingtop, gaugepaddingbottom = opts.gaugepaddingbottom, gaugepaddingleft = 13, gaugepaddingright = 13,
            bgcolor = orangeTileBg, fillcolor = rc.orange, textcolor = rc.white, titlecolor = rc.orange,
            thresholds = {
                {value = getThemeValue("esctemp_warn"), fillcolor = rc.orange},
                {value = getThemeValue("esctemp_max"), fillcolor = rc.amber},
                {value = math.huge, fillcolor = rc.red}
            },
            transform = "floor"
        },

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

return {layout = layout, boxes = boxes, header_boxes = header_boxes, header_layout = header_layout, screenBorderStyle = screenBorderStyle, scheduler = {spread_scheduling = true, spread_scheduling_paint = false, spread_ratio = 0.5}}
