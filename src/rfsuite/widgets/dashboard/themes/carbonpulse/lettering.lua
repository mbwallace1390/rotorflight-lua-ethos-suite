-- Carbon Pulse lettering: condensed italic text drawn from glyph masks
-- (Barlow Condensed, SIL Open Font License 1.1; see gfx/FONT-LICENSE.txt) and
-- tinted with the current colour. Studio original. GPLv3.
--
-- ETHOS cannot load a font file, so each character is a mask from gfx/<set>/.
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
-- slots a paint.
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

-- Mask handles by set and byte, and the bytes whose mask failed to load, so a
-- missing file is not read again on every layout.
local MASKS, FAILED = {}, {}
for i = 1, #LADDER do MASKS[LADDER[i]], FAILED[LADDER[i]] = {}, {} end

if utils.registerImageCacheClearer then
    utils.registerImageCacheClearer(function()
        for i = 1, #LADDER do
            local masks, failed = MASKS[LADDER[i]], FAILED[LADDER[i]]
            for code in pairs(masks) do masks[code] = nil end
            for code in pairs(failed) do failed[code] = nil end
        end
    end)
end

-- quota: characters left this paint. paint: paint counter. A waiting slot
-- records the paint it started waiting; `oldest` is the earliest of those seen
-- on the previous paint and `seen` collects this paint's.
local quota, paint, overdraft, oldest, seen = 0, 0, 0, nil, nil

-- Start a paint with a layout allowance in characters. None means no layout
-- at all on this paint, past-quota slots included.
function M.frame(characters)
    quota = characters
    paint = paint + 1
    oldest, seen = seen, nil
    overdraft = characters > 0 and OVERDRAFT or 0
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
            m = lcd.loadMask(format("%s%s/%04x.png", ROOT, name, code))
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
-- w x h and whose masks load. Fills r.run with absolute x, mask pairs; false if
-- none fits. r.top is the highest index ever written, so no attempt leaves
-- stale entries.
local function layout(r, x, y, w, h, text, size, align)
    local run, len = r.run, #text
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
                    run[n + 1], run[n + 2] = pen + o, code
                    n = n + 2
                end
                pen = pen + a
            end
            if n > r.top then r.top = n end
            if n >= 0 then
                -- Align the ink, not the advances: italic glyphs overhang the
                -- last advance, and a few start left of the pen.
                local lead = n > 0 and run[1] < 0 and run[1] or 0
                local ink = pen + set.over - lead
                if ink <= w then
                    local ox = x
                    if align == "center" then ox = x + (w - ink) / 2
                    elseif align == "right" then ox = x + w - ink end
                    if realize(run, n, name, floor(ox + 0.5) - lead) then
                        for j = n + 1, r.top do run[j] = nil end
                        r.n, r.top, r.drawY = n, n, floor(y + (h - set.h) / 2 + 0.5)
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
    if not r then r = {run = {}, n = 0, top = 0}; runs[slot] = r end
    if r.text ~= text or r.x ~= x or r.y ~= y or r.w ~= w or r.h ~= h or r.size ~= size then
        local since = r.waiting
        if quota > 0 or (overdraft > 0 and since ~= nil and since == oldest) then
            if quota <= 0 then overdraft = overdraft - 1 end
            -- The key is written only once the run is complete, so a callback
            -- aborted mid-layout leaves the slot marked as not laid out.
            r.text, r.waiting = nil, nil
            local fallback = nil
            if not layout(r, x, y, w, h, text, size, align) then
                local run = r.run
                for j = 1, r.top do run[j] = nil end
                r.n, r.top, fallback = 0, 0, FALLBACK[size] or "FONT_XS"
            end
            r.fallback, r.x, r.y, r.w, r.h, r.size, r.text = fallback, x, y, w, h, size, text
        else
            if since == nil then since = paint; r.waiting = paint end
            if seen == nil or since < seen then seen = since end
            if r.text == nil or r.x ~= x or r.y ~= y or r.w ~= w or r.h ~= h or r.size ~= size then
                -- Not laid out for this box yet: blank until it is. A changed
                -- text in an unchanged box keeps its previous run meanwhile.
                return
            end
        end
    end
    if r.fallback then
        D.text(c, slot, r.x, r.y, r.w, r.h, r.text, r.fallback, color, align)
        return
    end
    setColor(color or WHITE)
    local run, dy, drawMask = r.run, r.drawY, lcd.drawMask
    for i = 1, r.n, 2 do drawMask(run[i], dy, run[i + 1]) end
end

return M
