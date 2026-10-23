-- Carbon Pulse lettering: condensed italic text drawn from glyph masks
-- (Barlow Condensed, SIL Open Font License 1.1; see gfx/FONT-LICENSE.txt) and
-- tinted with the current colour. Studio original. GPLv3.
--
-- ETHOS documents no font file format for lcd.loadFont, so each character is
-- a mask from gfx/<set>/.
-- A text is laid out once per slot when it, its box or its set changes; steady
-- paints only draw the cached run. Masks load once per character, after a set
-- is chosen, and are released with the Suite's other images (theme reload,
-- model change, widget close). A text with a character outside the sets, or
-- too wide for every set, falls back to the radio font.
--
-- Laying out costs about 25 instructions a character per set tried, so a cold
-- screen (startup, a phase change, a resize) would cost thousands at once. Each
-- paint therefore lays out about `quota` characters (M.frame), counting every
-- set tried. A slot past the quota keeps its previous run, or stays blank, and
-- waits. So that sustained changes ahead of it cannot starve it, the slots that
-- have waited longest may also be laid out past the quota, at most OVERDRAFT
-- slots a paint. Where ETHOS reports the share of the callback's instruction
-- limit already used (system.getInstructionsUsage), slots are also laid out
-- past the quota while that share is below SPARE percent, so a cold screen
-- needs fewer paints. The Suite repaints only when its data changes, so while
-- any slot waits M.pending() is true and state.lua's pacer box keeps the
-- Suite's wake passes, and so its repaints, going (layout.lua M.waiting).
-- While a screen's text is first laid out, its slots are held rather than
-- drawn (M.frame), and the paint that completes them draws them all
-- (M.reveal), so the text appears at once.
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local D = requireModule("widgets/dashboard/themes/carbonpulse/common.lua")
local SETS = requireModule("widgets/dashboard/themes/carbonpulse/glyphs.lua")
local utils = requireModule("widgets/dashboard/context.lua").widgets.dashboard.utils
local lcd, floor, byte, format, pairs = lcd, math.floor, string.byte, string.format, pairs
local setColor, WHITE = D.setColor, D.colors.white
local M = {}

local ROOT = "widgets/dashboard/themes/carbonpulse/gfx/"
-- Fitting order, largest first, and the radio font used when no set fits.
local LADDER = {"big", "mid", "small", "label", "tiny"}
local RANK = {big = 1, mid = 2, small = 3, label = 4, tiny = 5}
local FALLBACK = {big = "FONT_XXL", mid = "FONT_XL", small = "FONT_L", label = "FONT_XS", tiny = "FONT_XXS"}
local OVERDRAFT = 2
-- The share leaves room for the rest of the paint after the last slot laid
-- out: its other drawing and the Suite's header boxes and overlays.
local usage, SPARE = system and system.getInstructionsUsage, 50

-- Mask handles by set and byte, and the bytes whose mask failed to load, so a
-- missing file is not read again on every layout.
local MASKS, FAILED = {}, {}
for i = 1, #LADDER do MASKS[LADDER[i]], FAILED[LADDER[i]] = {}, {} end

-- quota: characters left this paint. paint: paint counter. A waiting slot
-- records the paint it started waiting; `oldest` is the earliest of those seen
-- on the previous paint and `seen` collects this paint's.
-- pending: some slot waited on this paint. blank: some slot had nothing to
-- draw. holding: slots go to `held` (heldCount of them), with their colours in
-- `heldColor`, instead of the screen.
local quota, paint, overdraft, oldest, seen, pending = 0, 0, 0, nil, nil, false
local blank, holding, held, heldColor, heldCount = false, false, {}, {}, 0

-- Forget the held slots. Each one refers to its masks, or a radio-font one to
-- its box cache, so a list left over from a paint that did not complete its
-- screen would keep them after the theme is gone.
function M.drop()
    for i = 1, heldCount do held[i] = nil end
    heldCount, holding = 0, false
end

if utils.registerImageCacheClearer then
    utils.registerImageCacheClearer(function()
        for i = 1, #LADDER do
            local masks, failed = MASKS[LADDER[i]], FAILED[LADDER[i]]
            for code in pairs(masks) do masks[code] = nil end
            for code in pairs(failed) do failed[code] = nil end
        end
        M.drop()
    end)
end

-- Start a paint with a layout allowance in characters. None means no layout
-- within the allowance, and no overdraft, on this paint. With `hold`, slots are
-- kept for M.reveal instead of drawn.
function M.frame(characters, hold)
    quota = characters
    paint = paint + 1
    oldest, seen, pending, blank, holding = seen, nil, false, false, hold == true
    overdraft = characters > 0 and OVERDRAFT or 0
    for i = 1, heldCount do held[i] = nil end
    heldCount = 0
end

-- True when a slot waited on this paint, so another frame is needed.
function M.pending()
    return pending
end

-- True when a slot had no run for its box on this paint.
function M.blank()
    return blank
end

-- Convert a chosen run's codes to mask handles and add the x origin.
-- false if a mask cannot load.
local function realize(run, n, name, ox)
    local masks = MASKS[name]
    for j = 1, n, 2 do
        local code = run[j + 1]
        local m = masks[code]
        if m == nil then
            local failed = FAILED[name]
            if failed[code] then return false end
            -- Not lazy: load now, in the paint that first draws it, so a missing
            -- or unreadable file fails here and the radio font takes over.
            m = lcd.loadMask(format("%s%s/%04x.png", ROOT, name, code), false)
            if not m then
                failed[code] = true
                return false
            end
            masks[code] = m
        end
        run[j], run[j + 1] = run[j] + ox, m
    end
    return true
end

-- Lay `text` out in the largest set from `size` down that has every byte, fits
-- w x h and whose masks load. Fills the slot record's array part, r[1] to
-- r[#r], with absolute x, mask pairs; false if none fits. Entries are written
-- in order and cleared from the end, so the array never has a hole and #r is
-- the end of the run, even after an aborted layout.
local function layout(r, x, y, w, h, text, size, align)
    local len = #text
    for rank = RANK[size] or 4, #LADDER do
        local name = LADDER[rank]
        local set = SETS[name]
        if set.h <= h then
            quota = quota - len
            local adv, off = set.adv, set.off
            local n, pen = 0, 0
            for i = 1, len do
                local code = byte(text, i)
                local a = adv[code]
                if not a then n = -1; break end
                local o = off[code]
                if o then
                    r[n + 1] = pen + o
                    r[n + 2] = code
                    n = n + 2
                end
                pen = pen + a
            end
            if n >= 0 then
                -- Align the ink, not the advances: italic glyphs overhang the
                -- last advance, and a few start left of the pen.
                local lead = n > 0 and r[1] < 0 and r[1] or 0
                local ink = pen + set.over - lead
                if ink <= w then
                    local ox = x
                    if align == "center" then ox = x + (w - ink) / 2
                    elseif align == "right" then ox = x + w - ink end
                    if realize(r, n, name, floor(ox + 0.5) - lead) then
                        for j = #r, n + 1, -1 do r[j] = nil end
                        r.drawY = floor(y + (h - set.h) / 2 + 0.5)
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- Draw text in the largest glyph set (from `size` down) that fits w x h.
-- Each slot keeps one alignment, as with D.text.
function M.text(c, slot, x, y, w, h, text, size, color, align)
    text = text or "--"
    local runs = c._lettering
    if not runs then runs = {}; c._lettering = runs end
    local r = runs[slot]
    if not r then r = {}; runs[slot] = r end
    if r.text ~= text or r.x ~= x or r.y ~= y or r.w ~= w or r.h ~= h or r.size ~= size then
        local since = r.waiting
        local allowed = quota > 0 or (usage and usage() < SPARE)
        if not allowed and overdraft > 0 and since ~= nil and since == oldest then
            overdraft, allowed = overdraft - 1, true
        end
        if allowed then
            -- The key is cleared first and its text written last, on its own,
            -- so a callback aborted mid-layout, or between these writes, leaves
            -- the slot marked as not laid out.
            r.text, r.waiting = nil, nil
            local fallback = nil
            if not layout(r, x, y, w, h, text, size, align) then
                for j = #r, 1, -1 do r[j] = nil end
                fallback = FALLBACK[size] or "FONT_XS"
            end
            r.fallback, r.x, r.y, r.w, r.h, r.size = fallback, x, y, w, h, size
            r.text = text
        else
            pending = true
            if since == nil then since = paint; r.waiting = paint end
            if seen == nil or since < seen then seen = since end
            if r.text == nil or r.x ~= x or r.y ~= y or r.w ~= w or r.h ~= h or r.size ~= size then
                -- Not laid out for this box yet: blank until it is. A changed
                -- text in an unchanged box keeps its previous run meanwhile.
                blank = true
                return
            end
        end
    end
    if holding then
        -- Only the radio font needs the box cache, slot and alignment back.
        if r.fallback then r.align, r.cache, r.slot = align, c, slot end
        heldCount = heldCount + 1
        held[heldCount], heldColor[heldCount] = r, color
        return
    end
    if r.fallback then
        D.text(c, slot, r.x, r.y, r.w, r.h, r.text, r.fallback, color, align)
        return
    end
    setColor(color or WHITE)
    local dy, drawMask = r.drawY, lcd.drawMask
    for i = 1, #r, 2 do drawMask(r[i], dy, r[i + 1]) end
end

-- Draw the slots held on this paint, in their order, and stop holding.
function M.reveal()
    local drawMask = lcd.drawMask
    for i = 1, heldCount do
        local r = held[i]
        held[i] = nil
        if r.fallback then
            D.text(r.cache, r.slot, r.x, r.y, r.w, r.h, r.text, r.fallback, heldColor[i], r.align)
        else
            setColor(heldColor[i] or WHITE)
            local dy = r.drawY
            for j = 1, #r, 2 do drawMask(r[j], dy, r[j + 1]) end
        end
    end
    heldCount, holding = 0, false
end

return M
