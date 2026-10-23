-- Carbon Pulse palette, cached radio-font text fitting and drawing helpers.
-- Text fitter and colour cache adapted from Studio Stratus 98 (from Studio
-- Sector and MWRC Cinder). GPLv3.
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local utils = requireModule("widgets/dashboard/context.lua").widgets.dashboard.utils
local lcd = lcd
local floor = math.floor
local M = {}

-- One near-black face for the header and body, neon-blue frames and bright
-- readouts; alarm hues stay distinct.
M.colors = {
    bg = lcd.RGB(9, 13, 19),
    panel = lcd.RGB(9, 13, 19), head = lcd.RGB(9, 13, 19),
    neon = lcd.RGB(30, 144, 255), glow = lcd.RGB(16, 78, 150),
    label = lcd.RGB(143, 200, 255), white = lcd.RGB(234, 242, 255), muted = lcd.RGB(93, 107, 122),
    value = lcd.RGB(57, 255, 106), track = lcd.RGB(28, 38, 50),
    green = lcd.RGB(57, 255, 106), amber = lcd.RGB(255, 196, 0), red = lcd.RGB(255, 59, 48),
    zoneGreen = lcd.RGB(40, 200, 90), zoneAmber = lcd.RGB(240, 190, 20), zoneRed = lcd.RGB(240, 60, 40),
}
M.colors.accent, M.colors.text = M.colors.neon, M.colors.white
local C = M.colors

-- Font ladder, smallest first. FONT_XXXL is not part of the dashboard set.
local NAMES = {"FONT_XXS", "FONT_XS", "FONT_S", "FONT_STD", "FONT_L", "FONT_XL", "FONT_XXL", "FONT_XXXXL"}
local RANK = {}
for i = 1, #NAMES do RANK[NAMES[i]] = i end
-- Resolved font handles by rank; the radio's font constants never change.
local FONTS = {}

local function rankFont(rank)
    local font = utils.resolveFont(NAMES[rank], nil)
    FONTS[rank] = font
    return font
end

------------------------------------------------------------------------
-- Per-frame colour/font de-duplication. Every theme draw shares this state,
-- so consecutive identical lcd.color/lcd.font calls are skipped.
-- frame() forgets the last values at the start of each paint because the
-- engine draws the native header between our paints.
------------------------------------------------------------------------
local lastColor, lastFont = nil, nil
local drawRect = nil

function M.frame()
    lastColor, lastFont = nil, nil
    drawRect = lcd.drawFilledRectangle
end

local function setColor(color)
    if color ~= lastColor then
        lcd.color(color)
        lastColor = color
    end
end
M.setColor = setColor

-- Resolve the largest rank (from `requested` down) whose text fits w x h.
-- Measured only when text, box or requested font changes; the result is
-- cached in the slot so steady paints never call getTextSize.
local function fitSlot(c, slot, w, h, text, requested)
    local fits = c._textFits
    if not fits then fits = {}; c._textFits = fits end
    local fit = fits[slot]
    if not fit then fit = {}; fits[slot] = fit end
    if fit.text ~= text or fit.width ~= w or fit.height ~= h or fit.requested ~= requested then
        -- The key is written after measuring, so a callback aborted mid-measure
        -- leaves the slot unmeasured rather than paired with the old result. A
        -- new measurement also invalidates the draw position cached by M.text.
        fit.text, fit.x = nil, nil
        local rank = RANK[requested] or 4
        local font = FONTS[rank] or rankFont(rank)
        lcd.font(font)
        local tw, th = lcd.getTextSize(text)
        while (tw > w or th > h) and rank > 1 do
            -- Step one font down until the text fits the box.
            rank = rank - 1
            font = FONTS[rank] or rankFont(rank)
            lcd.font(font)
            tw, th = lcd.getTextSize(text)
        end
        -- The measuring calls above changed the lcd font behind the cache.
        lastFont = font
        fit.rank, fit.font, fit.tw, fit.th = rank, font, tw or 0, th or 0
        fit.text, fit.width, fit.height, fit.requested = text, w, h, requested
    end
    return fit
end

-- Draw text in the largest font (from `requested` down) that fits w x h.
-- The rounded draw position is cached with the fit until the text, box or
-- requested font changes; each slot keeps one alignment.
function M.text(c, slot, x, y, w, h, text, requested, color, align)
    text = text or "--"
    local fits = c._textFits
    local fit = fits and fits[slot]
    if not fit or fit.text ~= text or fit.x ~= x or fit.y ~= y or fit.width ~= w
        or fit.height ~= h or fit.requested ~= requested then
        fit = fitSlot(c, slot, w, h, text, requested)
        -- The box key is cleared first and its x written last, so a callback
        -- aborted between these writes leaves a key that matches no box, and
        -- the next paint places the text again for whichever box it asks.
        fit.x = nil
        local tx = x
        if align == "center" then tx = x + (w - fit.tw) / 2
        elseif align == "right" then tx = x + w - fit.tw end
        fit.drawX, fit.drawY = floor(tx + 0.5), floor(y + (h - fit.th) / 2 + 0.5)
        fit.y = y
        fit.x = x
    end
    local font = fit.font
    if font ~= lastFont then
        lcd.font(font)
        lastFont = font
    end
    color = color or C.white
    if color ~= lastColor then
        lcd.color(color)
        lastColor = color
    end
    lcd.drawText(fit.drawX, fit.drawY, text)
end

-- Filled rectangle through the colour cache; floored and never negative.
function M.fill(color, x, y, w, h)
    w, h = floor(w), floor(h)
    if w <= 0 or h <= 0 then return end
    setColor(color)
    lcd.drawFilledRectangle(floor(x), floor(y), w, h)
end

------------------------------------------------------------------------
-- Exact-geometry fast path for fixed decorations whose coordinates are whole
-- pixels with positive sizes: the result matches M.fill without the per-call
-- flooring and size checks. Needs frame() first.
------------------------------------------------------------------------
function M.rect(color, x, y, w, h)
    if color ~= lastColor then
        lcd.color(color)
        lastColor = color
    end
    drawRect(x, y, w, h)
end

-- Draw n segments in one colour from four parallel arrays {x1, y1, x2, y2},
-- built once per geometry, so paint does no address arithmetic per segment.
function M.segments(color, l, n)
    if color ~= lastColor then
        lcd.color(color)
        lastColor = color
    end
    local drawLine, x1, y1, x2, y2 = lcd.drawLine, l[1], l[2], l[3], l[4]
    for i = 1, n do drawLine(x1[i], y1[i], x2[i], y2[i]) end
end

-- Filled triangle through the colour cache.
function M.triangle(color, x1, y1, x2, y2, x3, y3)
    if color ~= lastColor then
        lcd.color(color)
        lastColor = color
    end
    lcd.drawFilledTriangle(x1, y1, x2, y2, x3, y3)
end

return M
