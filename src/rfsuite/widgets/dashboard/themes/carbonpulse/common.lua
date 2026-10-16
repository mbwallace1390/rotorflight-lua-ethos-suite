-- Carbon Pulse palette, cached text fitting and flat line lists.
-- Text fitter and colour cache adapted from Studio Stratus 98 (from Studio
-- Sector and MWRC Cinder). GPLv3.
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local utils = requireModule("widgets/dashboard/context.lua").widgets.dashboard.utils
local lcd = lcd
local floor = math.floor
local M = {}

-- Near-black carbon, neon-blue frames and bright readouts; alarm hues stay distinct.
M.colors = {
    bg = lcd.RGB(7, 10, 15),
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
M.NAMES = NAMES
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

-- Rank of the font a text would use in a box (no drawing). Used to step a
-- group of readouts to one shared size.
function M.fit(c, slot, w, h, text, requested)
    return fitSlot(c, slot, w, h, text or "--", requested).rank
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
        local tx = x
        if align == "center" then tx = x + (w - fit.tw) / 2
        elseif align == "right" then tx = x + w - fit.tw end
        fit.x, fit.y = x, y
        fit.drawX, fit.drawY = floor(tx + 0.5), floor(y + (h - fit.th) / 2 + 0.5)
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

-- Measure a static string at geometry time only (never in steady paint).
function M.measure(text, fontName)
    local font = utils.resolveFont(fontName, nil)
    lcd.font(font)
    lastFont = font
    local tw = lcd.getTextSize(text)
    return tw or 0
end

-- Width of the last fitted text in a slot (0 before the first draw).
function M.textWidth(c, slot)
    local fits = c._textFits
    local fit = fits and fits[slot]
    return fit and fit.tw or 0
end

-- Filled rectangle through the colour cache; floored and never negative.
function M.fill(color, x, y, w, h)
    w, h = floor(w), floor(h)
    if w <= 0 or h <= 0 then return end
    setColor(color)
    lcd.drawFilledRectangle(floor(x), floor(y), w, h)
end

------------------------------------------------------------------------
-- Exact-geometry fast path. Callers use these only after proving that every
-- rectangle of the frame is whole-pixel with a positive size, so the result
-- matches M.fill without per-rectangle flooring or size checks. Both need
-- frame() first.
------------------------------------------------------------------------
function M.rect(color, x, y, w, h)
    if color ~= lastColor then
        lcd.color(color)
        lastColor = color
    end
    drawRect(x, y, w, h)
end

-- Draw a flat list of segments {x1, y1, x2, y2, ...} in one colour. Lists are
-- built once per geometry, so paint performs no arithmetic per segment.
function M.lines(color, list, count)
    if color ~= lastColor then
        lcd.color(color)
        lastColor = color
    end
    local drawLine = lcd.drawLine
    for i = 1, count or #list, 4 do
        drawLine(list[i], list[i + 1], list[i + 2], list[i + 3])
    end
end

-- Filled triangle through the colour cache.
function M.triangle(color, x1, y1, x2, y2, x3, y3)
    if color ~= lastColor then
        lcd.color(color)
        lastColor = color
    end
    lcd.drawFilledTriangle(x1, y1, x2, y2, x3, y3)
end

-- Annulus sector through the colour cache; angles are degrees clockwise from
-- the top and never cross 360 (callers split segments at the top).
function M.sector(color, x, y, inner, outer, a1, a2)
    if color ~= lastColor then
        lcd.color(color)
        lastColor = color
    end
    lcd.drawAnnulusSector(x, y, inner, outer, a1, a2)
end

return M
