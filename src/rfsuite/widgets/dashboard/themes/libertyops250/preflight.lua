local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local rfsuite = requireModule("widgets/dashboard/context.lua")
local lcd = lcd
local system = system
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
local header_layout = utils.standardHeaderLayout(headeropts)
local header_boxes_cache
local last_txbatt_type

local C = {
    bg = lcd.RGB(2, 5, 10),
    panel = lcd.RGB(5, 10, 18),
    panel2 = lcd.RGB(8, 16, 28),
    line = lcd.RGB(24, 76, 146),
    lineDim = lcd.RGB(15, 40, 72),
    white = lcd.RGB(238, 243, 252),
    muted = lcd.RGB(138, 153, 175),
    blue = lcd.RGB(42, 111, 214),
    blueBright = lcd.RGB(64, 145, 255),
    green = lcd.RGB(83, 210, 104),
    greenDim = lcd.RGB(24, 67, 34),
    amber = lcd.RGB(255, 167, 45),
    red = lcd.RGB(227, 58, 66),
    redDim = lcd.RGB(75, 15, 20),
    gold = lcd.RGB(216, 178, 83)
}

-- Liberty Ops uses a fixed cockpit palette. Keeping the header palette local
-- avoids a full ETHOS theme-signature rebuild during dashboard loading.
local colorMode = {
    bgcolor = C.bg,
    tbbgcolor = C.bg,
    titlecolor = C.white,
    cntextcolor = C.white,
    tbtextcolor = C.white,
    txbgfillcolor = C.lineDim,
    txaccentcolor = C.line,
    txfillcolor = C.green,
    fillwarncolor = C.amber,
    rssitextcolor = C.white,
    rssifillcolor = C.green,
    rssifillbgcolor = C.lineDim
}

local DEFAULTS = {
    rpm_min = 0,
    rpm_max = 3000,
    bec_min = 3.0,
    bec_warn = 6.0,
    bec_max = 13.0,
    esctemp_warn = 90,
    esctemp_max = 140
}
local suiteVersion = rfsuite and rfsuite.config and rfsuite.config.version or {}
local SUITE_VERSION = format("RF%d.%d.%d", tonumber(suiteVersion.major) or 0, tonumber(suiteVersion.minor) or 0, tonumber(suiteVersion.revision) or 0)

local function getThemeValue(key)
    -- Preferences belong to the Suite's active dashboard theme.
    local value = tonumber(rfsuite.widgets.dashboard.getPreference(key))
    return value or DEFAULTS[key]
end

local function fmt(value, decimals, suffix, missing)
    if value == nil then return missing or "--" end
    if decimals == 1 then return format("%.1f", value) .. (suffix or "") end
    if decimals == 2 then return format("%.2f", value) .. (suffix or "") end
    return tostring(floor(value + 0.5)) .. (suffix or "")
end

local function updateFormatted(cache, keyField, textField, value, decimals, suffix, missing)
    local multiplier = decimals == 2 and 100 or (decimals == 1 and 10 or 1)
    local key = value ~= nil and floor(value * multiplier + 0.5) or false
    if cache[keyField] ~= key or cache[textField] == nil then
        cache[keyField] = key
        cache[textField] = fmt(value, decimals, suffix, missing)
    end
    return key
end

local fontCache = {}
local function font(name)
    local cached = fontCache[name]
    if cached ~= nil then return cached or nil end
    local resolved = utils.resolveFont(name, nil)
    fontCache[name] = resolved or false
    return resolved
end

local FONT_FALLBACK = {FONT_XXL="FONT_XL", FONT_XL="FONT_L", FONT_L="FONT_STD", FONT_STD="FONT_S", FONT_S="FONT_XS", FONT_XS="FONT_XXS"}
local function drawText(x, y, w, text, fontName, color, align)
    local f = font(fontName)
    if type(f) ~= "number" then return 0, 0 end
    lcd.font(f)
    lcd.color(color)
    local tw, th = lcd.getTextSize(text)
    local nextFont = FONT_FALLBACK[fontName]
    while tw > w and nextFont do
        local smaller = font(nextFont)
        if type(smaller) == "number" then lcd.font(smaller); tw, th = lcd.getTextSize(text) end
        nextFont = FONT_FALLBACK[nextFont]
    end
    local tx = x
    if align == "center" then tx = x + (w - tw) / 2 end
    if align == "right" then tx = x + w - tw end
    lcd.drawText(floor(tx + 0.5), floor(y + 0.5), text)
    return tw, th
end

local HEADER_LABEL = "Rotorflight // Ethos"
local HEADER_SIGNATURE = " | MWRC"
local function paintHeaderLogo(x, y, w, h)
    local signatureFont = FONT_XXS or FONT_XS
    lcd.font(signatureFont)
    local signatureW, signatureH = lcd.getTextSize(HEADER_SIGNATURE)
    lcd.font(FONT_S)
    local labelW, labelH = lcd.getTextSize(HEADER_LABEL)
    -- Fit the group without giving the builder signature equal visual weight.
    if labelW + signatureW > w - 20 then
        lcd.font(FONT_XS)
        labelW, labelH = lcd.getTextSize(HEADER_LABEL)
    end
    if labelW + signatureW > w - 20 then
        lcd.font(FONT_XXS or FONT_XS)
        labelW, labelH = lcd.getTextSize(HEADER_LABEL)
    end
    local groupX = x + max(10, floor((w - labelW - signatureW) / 2))
    lcd.color(C.gold)
    lcd.drawText(groupX, y + max(0, floor((h - labelH) / 2)), HEADER_LABEL)
    lcd.font(signatureFont)
    lcd.color(C.muted)
    lcd.drawText(groupX + labelW, y + max(0, floor((h - signatureH) / 2)), HEADER_SIGNATURE)
end

local function header_boxes()
    local txbatt_type = 0
    if rfsuite and rfsuite.preferences and rfsuite.preferences.general then
        txbatt_type = rfsuite.preferences.general.txbatt_type or 0
    end

    if header_boxes_cache == nil or last_txbatt_type ~= txbatt_type then
        local boxes = utils.standardHeaderBoxes(i18n, colorMode, headeropts, txbatt_type)
        for _, box in ipairs(boxes) do
            if box.subtype == "craftname" then box.font = "FONT_S" end
            box.bgcolor = "transparent"
            if box.type == "image" then
                box.type = "func"
                box.subtype = "func"
                box.paint = function(x, y, w, h)
                    lcd.color(C.panel)
                    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))
                    paintHeaderLogo(x, y, w, h)
                end
            end
        end
        header_boxes_cache = boxes
        last_txbatt_type = txbatt_type
    end
    return header_boxes_cache
end

local function drawPanel(x, y, w, h, title, accent)
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    lcd.color(C.panel)
    lcd.drawFilledRectangle(x, y, w, h)
    lcd.color(C.lineDim)
    lcd.drawRectangle(x, y, w, h, 1)
    lcd.color(C.line)
    lcd.drawLine(x + 2, y + 2, x + w - 3, y + 2)
    lcd.drawLine(x + 2, y + 2, x + 2, y + h - 3)
    lcd.color(accent or C.blue)
    lcd.drawFilledRectangle(x + 3, y + 3, 3, max(1, h - 6))
    if title then drawText(x + 13, y + 8, w - 24, title, "FONT_XS", C.muted, "left") end
end

local function drawMiniBar(x, y, w, h, percent, color)
    percent = max(0, min(1, percent or 0))
    lcd.color(C.lineDim)
    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))
    if percent > 0 then
        lcd.color(color)
        lcd.drawFilledRectangle(floor(x), floor(y), floor(w * percent), floor(h))
    end
end

-- Tiny dashboard stars are intentionally drawn as three crossed strokes.
-- This preserves the star appearance while avoiding per-frame tables,
-- trigonometry, and hundreds of line operations on ETHOS.
local function drawStar(cx, cy, r, color)
    cx, cy, r = floor(cx), floor(cy), max(2, floor(r))
    lcd.color(color)
    lcd.drawLine(cx, cy - r, cx, cy + r)
    lcd.drawLine(cx - r, cy - 1, cx + r, cy + 1)
    lcd.drawLine(cx - r, cy + 1, cx + r, cy - 1)
end

local function drawHeliIcon(cx, cy, s, color)
    lcd.color(color)
    lcd.drawLine(cx - s, cy, cx + s, cy)
    lcd.drawLine(cx, cy - floor(s * 0.55), cx, cy + floor(s * 0.45))
    lcd.drawLine(cx - floor(s * 0.45), cy + floor(s * 0.15), cx + floor(s * 0.35), cy + floor(s * 0.15))
    lcd.drawLine(cx + floor(s * 0.35), cy + floor(s * 0.15), cx + floor(s * 0.7), cy + floor(s * 0.35))
    lcd.drawLine(cx - floor(s * 0.45), cy + floor(s * 0.15), cx - floor(s * 0.75), cy + floor(s * 0.35))
    lcd.drawLine(cx - floor(s * 0.25), cy + floor(s * 0.45), cx + floor(s * 0.35), cy + floor(s * 0.45))
end

local function governorColor(text)
    if text == "ACTIVE" then return C.green end
    if text == "IDLE" or text == "SPOOLUP" or text == "RECOVERY" then return C.amber end
    if text == "DISARMED" or text == "OFF" then return C.red end
    return C.muted
end

local function wakeup(box, telemetry)
    local c = box._cache or {}
    box._cache = c
    local getSensor = telemetry and telemetry.getSensor

    c.rpm = getSensor and tonumber((getSensor("rpm"))) or nil
    c.throttle = getSensor and tonumber((getSensor("throttle_percent"))) or nil
    c.rate = getSensor and tonumber((getSensor("rate_profile"))) or nil
    c.pid = getSensor and tonumber((getSensor("pid_profile"))) or nil
    c.voltage = getSensor and tonumber((getSensor("voltage"))) or nil
    c.fuel = getSensor and tonumber((getSensor("smartfuel"))) or nil
    c.consumed = getSensor and tonumber((getSensor("smartconsumption"))) or nil
    c.bec = getSensor and tonumber((getSensor("bec_voltage"))) or nil
    local escWarn = getThemeValue("esctemp_warn")
    local escMax = getThemeValue("esctemp_max")
    local escValue, _, escUnit, presentedEscWarn, presentedEscMax
    if getSensor then
        escValue, _, escUnit, presentedEscWarn, presentedEscMax = getSensor("temp_esc", escWarn, escMax)
    end
    c.esc = tonumber(escValue)
    c.escWarn = tonumber(presentedEscWarn) or escWarn
    c.escMax = tonumber(presentedEscMax) or escMax
    escUnit = escUnit or "°C"
    if c.escUnit ~= escUnit or c.escSuffix == nil then
        c.escUnit = escUnit
        c.escSuffix = " " .. escUnit
        c._escTextKey = nil
    end
    c.link = getSensor and tonumber((getSensor("vfr"))) or nil

    if c.link == nil and getSensor then c.link = tonumber((getSensor("rssi"))) end
    local govRaw = getSensor and tonumber((getSensor("governor")))
    if govRaw == nil then
        c.governor = "WAITING"
    else
        c.governor = rfsuite.utils.getGovernorState(govRaw)
    end

    c.govColor = governorColor(c.governor)
    c.fuelColor = c.fuel and (c.fuel <= 25 and C.red or (c.fuel <= 50 and C.amber or C.green)) or C.muted
    c.becColor = c.bec and (c.bec < getThemeValue("bec_min") and C.red or (c.bec < getThemeValue("bec_warn") and C.amber or C.green)) or C.muted
    c.escColor = c.esc and (c.esc >= c.escMax and C.red or (c.esc >= c.escWarn and C.amber or C.green)) or C.muted
    c.linkColor = c.link and (c.link < 50 and C.amber or C.green) or C.muted

    updateFormatted(c, "_rpmTextKey", "rpmText", c.rpm, 0, "", "--")
    updateFormatted(c, "_throttleTextKey", "throttleText", c.throttle, 0, "", "--")
    local rateKey = updateFormatted(c, "_rateTextKey", "rateText", c.rate, 0, "", "-")
    local pidKey = updateFormatted(c, "_pidTextKey", "pidText", c.pid, 0, "", "-")
    updateFormatted(c, "_voltageTextKey", "voltageText", c.voltage, 1, " V", "--")
    updateFormatted(c, "_fuelTextKey", "fuelText", c.fuel, 0, "%", "--")
    updateFormatted(c, "_consumedTextKey", "consumedText", c.consumed, 0, " mAh", "--")
    updateFormatted(c, "_becTextKey", "becText", c.bec, 1, " V", "--")
    updateFormatted(c, "_escTextKey", "escText", c.esc, 0, c.escSuffix, "--")
    updateFormatted(c, "_linkTextKey", "linkText", c.link, 0, "%", "--")
    if c._modeRateKey ~= rateKey or c._modePidKey ~= pidKey then
        c._modeRateKey = rateKey
        c._modePidKey = pidKey
        c.modeText = "R" .. c.rateText .. " / P" .. c.pidText
    end

    return c
end

local function drawBadgePanel(x, y, w, h)
    drawPanel(x, y, w, h, nil, C.blue)
    drawHeliIcon(floor(x + 42), floor(y + 30), 18, C.white)
    drawText(x + 70, y + 10, w - 82, "ROTORFLIGHT", "FONT_S", C.white, "left")
    drawText(x + 70, y + 33, w - 82, SUITE_VERSION, "FONT_XS", C.muted, "left")
    drawText(x + 10, y + 78, w - 20, "LIBERTY OPS", "FONT_STD", C.white, "center")
    drawText(x + 10, y + 108, w - 20, "250", "FONT_XXL", C.white, "center")

    local cx = x + w / 2
    local cy = y + h - 30
    local rx = w * 0.95
    local ry = 42
    drawStar(cx - 0.31 * rx, cy - 0.34 * ry, 3, C.red)
    drawStar(cx - 0.27 * rx, cy - 0.52 * ry, 3, C.white)
    drawStar(cx - 0.20 * rx, cy - 0.67 * ry, 3, C.blueBright)
    drawStar(cx - 0.11 * rx, cy - 0.77 * ry, 3, C.red)
    drawStar(cx,             cy - 0.80 * ry, 3, C.white)
    drawStar(cx + 0.11 * rx, cy - 0.77 * ry, 3, C.blueBright)
    drawStar(cx + 0.20 * rx, cy - 0.67 * ry, 3, C.red)
    drawStar(cx + 0.27 * rx, cy - 0.52 * ry, 3, C.white)
    drawStar(cx + 0.31 * rx, cy - 0.34 * ry, 3, C.blueBright)
    drawStar(cx + 0.27 * rx, cy - 0.16 * ry, 3, C.red)
    drawStar(cx + 0.18 * rx, cy - 0.02 * ry, 3, C.white)
    drawStar(cx,             cy + 0.04 * ry, 3, C.blueBright)
    drawStar(cx - 0.18 * rx, cy - 0.02 * ry, 3, C.red)
end

local function drawFooterStars(x, y, w, h)
    drawStar(x + 0.20 * w, y + 0.25 * h, 3, C.white)
    drawStar(x + 0.40 * w, y + 0.25 * h, 3, C.white)
    drawStar(x + 0.60 * w, y + 0.25 * h, 3, C.white)
    drawStar(x + 0.80 * w, y + 0.25 * h, 3, C.white)
    drawStar(x + 0.10 * w, y + 0.50 * h, 3, C.white)
    drawStar(x + 0.30 * w, y + 0.50 * h, 3, C.white)
    drawStar(x + 0.50 * w, y + 0.50 * h, 3, C.white)
    drawStar(x + 0.70 * w, y + 0.50 * h, 3, C.white)
    drawStar(x + 0.90 * w, y + 0.50 * h, 3, C.white)
    drawStar(x + 0.20 * w, y + 0.75 * h, 3, C.white)
    drawStar(x + 0.40 * w, y + 0.75 * h, 3, C.white)
    drawStar(x + 0.60 * w, y + 0.75 * h, 3, C.white)
    drawStar(x + 0.80 * w, y + 0.75 * h, 3, C.white)
end

local function drawFooterBanner(x, y, w, h)
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    local cantonW = floor(w * 0.40)

    lcd.color(lcd.RGB(5, 13, 35))
    lcd.drawFilledRectangle(x, y, w, h)

    -- Blue canton with the 13 original-colony stars.
    lcd.color(lcd.RGB(9, 27, 70))
    lcd.drawFilledRectangle(x, y, cantonW, h)
    drawFooterStars(x + 8, y + 3, cantonW - 16, h - 16)

    -- Red and white flag stripes on the right side.
    local stripeH = max(3, floor(h / 7))
    for i = 0, 6 do
        lcd.color((i % 2 == 0) and C.red or C.white)
        lcd.drawFilledRectangle(x + cantonW, y + i * stripeH, w - cantonW, stripeH)
    end

    -- Keep the flag continuous.  A small text shadow provides contrast without
    -- covering the canton or stripes with a large black rectangle.
    local titleY = y + floor(h * 0.20)
    drawText(x + 1, titleY + 1, w, "AMERICA 250", "FONT_L", C.bg, "center")
    drawText(x, titleY, w, "AMERICA 250", "FONT_L", C.white, "center")

    local subtitleY = y + h - 17
    drawText(x + 1, subtitleY + 1, w, "13 ORIGINAL COLONIES  |  250 YEARS OF LIBERTY", "FONT_XXS", C.bg, "center")
    drawText(x, subtitleY, w, "13 ORIGINAL COLONIES  |  250 YEARS OF LIBERTY", "FONT_XXS", C.white, "center")
end

local function drawCompactMetric(x, y, w, h, title, value, accent)
    drawPanel(x, y, w, h, title, accent)
    drawText(x + 13, y + 27, w - 26, value or "--", "FONT_L", C.white, "left")
end

local function paintCompact(x, y, w, h, c)
    local pad, gap = 10, 8
    drawText(x + pad, y + 7, w * 0.55, "LIBERTY OPS // PRE-FLIGHT", "FONT_S", C.gold, "left")
    drawText(x + w * 0.60, y + 7, w * 0.40 - pad, c.governor or "WAITING", "FONT_S", c.govColor or C.muted, "right")
    local top, bottom = y + 36, y + h - 28
    local badgeW = floor(w * 0.24)
    local cardX = x + pad + badgeW + gap
    local cardW = floor((w - pad * 2 - badgeW - gap * 3) / 3)
    local cardH = floor((bottom - top - gap) / 2)
    drawPanel(x + pad, top, badgeW, bottom - top, nil, C.gold)
    drawText(x + pad + 10, top + 12, badgeW - 20, "LIBERTY OPS", "FONT_S", C.white, "center")
    drawText(x + pad + 10, top + 36, badgeW - 20, "250", "FONT_XXL", C.gold, "center")
    drawText(x + pad + 10, bottom - 42, badgeW - 20, "1776  /  2026", "FONT_XS", C.muted, "center")
    drawText(x + pad + 10, bottom - 23, badgeW - 20, c.modeText or "R- / P-", "FONT_XS", C.blueBright, "center")
    drawCompactMetric(cardX, top, cardW, cardH, "HEADSPEED RPM", c.rpmText, C.blueBright)
    drawCompactMetric(cardX + cardW + gap, top, cardW, cardH, "PACK VOLTAGE", c.voltageText, C.green)
    drawCompactMetric(cardX + (cardW + gap) * 2, top, cardW, cardH, "SMART FUEL", c.fuelText, c.fuelColor)
    local row2 = top + cardH + gap
    drawCompactMetric(cardX, row2, cardW, cardH, "BEC POWER", c.becText, c.becColor)
    drawCompactMetric(cardX + cardW + gap, row2, cardW, cardH, "ESC TEMP", c.escText, c.escColor)
    drawCompactMetric(cardX + (cardW + gap) * 2, row2, cardW, cardH, "RADIO LINK", c.linkText, c.linkColor)
    drawText(x + pad, y + h - 20, w - pad * 2, "RF SUITE TOOLS  /  RADIO TOOLS MENU", "FONT_XXS", C.muted, "center")
end

local function paint(x, y, w, h, box, c)
    c = c or box._cache or {}
    box._cache = c
    lcd.color(C.bg)
    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))
    if h < 340 then return paintCompact(x, y, w, h, c) end

    local pad = 10
    local footerH = min(58, floor(h * 0.145))
    local navH = 24
    local bottomGap = 6
    local footerY = y + h - footerH - 4
    local navY = footerY - navH - bottomGap
    local contentY = y + 6
    local contentH = navY - contentY - 8
    local tileH = 48
    local tileGap = 7
    local upperH = contentH - tileH - tileGap
    local leftW = floor(w * 0.27)
    local gap = 8
    local rightW = floor(w * 0.20)
    local modeW = floor(w * 0.20)
    local governorW = w - pad * 2 - leftW - rightW - modeW - gap * 3

    local leftX = x + pad
    local govX = leftX + leftW + gap
    local modeX = govX + governorW + gap
    local powerX = modeX + modeW + gap

    drawBadgePanel(leftX, contentY, leftW, upperH)

    drawPanel(govX, contentY, governorW, upperH, "GOVERNOR", c.govColor or C.muted)
    drawText(govX + 12, contentY + 45, governorW - 24, "RPM", "FONT_XS", C.muted, "center")
    drawText(govX + 10, contentY + 72, governorW - 20, c.rpmText or "--", "FONT_XXL", C.white, "center")
    lcd.color(C.lineDim)
    lcd.drawLine(floor(govX + 14), floor(contentY + upperH * 0.60), floor(govX + governorW - 14), floor(contentY + upperH * 0.60))
    drawText(govX + 12, contentY + upperH * 0.65, governorW - 24, "THR %", "FONT_XS", C.muted, "center")
    drawText(govX + 12, contentY + upperH * 0.76, governorW - 24, c.throttleText or "--", "FONT_XL", C.white, "center")
    drawMiniBar(govX + 14, contentY + upperH - 18, governorW - 28, 6, (c.throttle or 0) / 100, C.green)

    drawPanel(modeX, contentY, modeW, upperH, "FLIGHT MODE", C.blue)
    drawText(modeX + 10, contentY + 48, modeW - 20, c.modeText or "R- / P-", "FONT_L", C.white, "center")
    lcd.color(C.lineDim)
    lcd.drawLine(floor(modeX + 12), floor(contentY + upperH * 0.48), floor(modeX + modeW - 12), floor(contentY + upperH * 0.48))
    drawText(modeX + 10, contentY + upperH * 0.55, modeW - 20, "GOVERNOR", "FONT_XS", C.muted, "center")
    drawText(modeX + 10, contentY + upperH * 0.68, modeW - 20, c.governor or "WAITING", "FONT_STD", c.govColor or C.muted, "center")

    drawPanel(powerX, contentY, rightW, floor(upperH * 0.42), "VOLTAGE", C.green)
    drawText(powerX + 12, contentY + 44, rightW - 24, c.voltageText or "--", "FONT_XL", C.white, "center")
    drawMiniBar(powerX + 14, contentY + floor(upperH * 0.42) - 17, rightW - 28, 6, c.voltage and min(1, c.voltage / 60) or 0, C.green)

    local fuelY = contentY + floor(upperH * 0.42) + gap
    local fuelH = contentH - floor(upperH * 0.42) - gap
    drawPanel(powerX, fuelY, rightW, fuelH, "SMART FUEL", c.fuelColor or C.muted)
    drawText(powerX + 12, fuelY + 35, rightW - 24, c.fuelText or "--", "FONT_XL", c.fuelColor or C.muted, "center")
    drawText(powerX + 12, fuelY + 79, rightW - 24, "USED", "FONT_XS", C.muted, "center")
    drawText(powerX + 12, fuelY + 99, rightW - 24, c.consumedText or "--", "FONT_STD", C.white, "center")
    drawMiniBar(powerX + 14, fuelY + fuelH - 18, rightW - 28, 6, c.fuel and c.fuel / 100 or 0, c.fuelColor or C.muted)

    local tilesY = contentY + upperH + tileGap
    local tileW = floor((w - pad * 2 - tileGap * 3) / 4)
    local tx1 = x + pad
    local tx2 = tx1 + tileW + tileGap
    local tx3 = tx2 + tileW + tileGap
    local tx4 = tx3 + tileW + tileGap
    drawPanel(tx1, tilesY, tileW, tileH, "BEC", c.becColor)
    drawText(tx1 + 12, tilesY + 20, tileW - 24, c.becText or "--", "FONT_STD", C.white, "right")
    drawPanel(tx2, tilesY, tileW, tileH, "ESC TEMP", c.escColor)
    drawText(tx2 + 12, tilesY + 20, tileW - 24, c.escText or "--", "FONT_STD", C.white, "right")
    drawPanel(tx3, tilesY, tileW, tileH, "LINK", c.linkColor)
    drawText(tx3 + 12, tilesY + 20, tileW - 24, c.linkText or "--", "FONT_STD", C.white, "right")
    drawPanel(tx4, tilesY, tileW, tileH, "PACK", C.blueBright)
    drawText(tx4 + 12, tilesY + 20, tileW - 24, c.voltageText or "--", "FONT_STD", C.white, "right")

    drawText(x + pad, navY + 3, w - pad * 2, "RF SUITE TOOLS  /  OPEN FROM THE RADIO TOOLS MENU", "FONT_XXS", C.muted, "center")

    -- Fully Lua-drawn flag footer with a visible blue canton and 13 stars.
    drawFooterBanner(x + pad, footerY, w - pad * 2, footerH)
end

local layout = {
    cols = 12,
    rows = 12,
    padding = 0,
    selectcolor = C.blueBright,
    selectborder = 2
}
local screenBorderStyle = {enabled = false}
local boxes_cache

local function boxes()
    if boxes_cache == nil then
        local mainBox = {
            col = 1, row = 1, colspan = 12, rowspan = 12,
            type = "func", subtype = "func",
            wakeup = wakeup,
            paint = paint,
            bgcolor = "transparent"
        }
        boxes_cache = {mainBox}
    end
    return boxes_cache
end

return {
    layout = layout,
    boxes = boxes,
    header_boxes = header_boxes,
    header_layout = header_layout,
    screenBorderStyle = screenBorderStyle,
    scheduler = {spread_scheduling = true, spread_scheduling_paint = false, spread_ratio = 0.82}
}
