--[[
  utils.standardHeaderBoxes() argument compatibility.

  The function's first parameter used to be an unused i18n table. It now takes
  (colorMode, headeropts, txbatt_type), but out-of-tree user themes reach it
  through rfsuite.widgets.dashboard.utils and may still call it with the old
  (i18n, colorMode, headeropts, txbatt_type) shape, so both must work and must
  produce the same boxes.

  These tests exist specifically to stop a future cleanup from deleting the
  shift shim: without it, a legacy caller silently gets colorMode where
  headeropts belongs, which yields boxes with wrong fonts and nil colours
  rather than an error.
]] --

local mock = dofile("bin/test/lib/ethos_mock.lua")
local t = dofile("bin/test/lib/t.lua")

mock.install()

local utils = assert(mock.realloadfile("src/rfsuite/widgets/dashboard/lib/utils.lua"))()

-- Minimal stand-ins carrying the fields standardHeaderBoxes actually reads.
-- tbbgcolor is what distinguishes a colorMode from a legacy leading argument.
local colorMode = {
    tbbgcolor = 11, tbtextcolor = 12, titlecolor = 13, cntextcolor = 14,
    rssitextcolor = 15, rssifillcolor = 16, rssifillbgcolor = 17,
    txbgfillcolor = 18, txaccentcolor = 19, txfillcolor = 20,
}
local headeropts = {
    height = 40, font = "FONT_L", txbattfont = "FONT_XS",
    barpaddingleft = 1, barpaddingright = 2, barpaddingbottom = 3, barpaddingtop = 4,
    valuepaddingleft = 5, valuepaddingbottom = 6,
}

--- Flatten the returned box list to a comparable string.
local function digest(boxes)
    local out = {}
    for i, b in ipairs(boxes) do
        out[i] = string.format("%d:%s/%s/col%s/span%s/bg%s",
            i, tostring(b.type), tostring(b.subtype),
            tostring(b.col), tostring(b.colspan), tostring(b.bgcolor))
    end
    return table.concat(out, "|")
end

t.group("current form: (colorMode, headeropts, txbatt_type)")
local current = utils.standardHeaderBoxes(colorMode, headeropts, 0)
t.check("returns a box list", type(current) == "table" and #current > 0,
    "got " .. tostring(current))
t.check("boxes carry the colorMode background", current[1].bgcolor == colorMode.tbbgcolor,
    "bgcolor=" .. tostring(current[1].bgcolor))

t.group("legacy form: (i18n, colorMode, headeropts, txbatt_type)")
-- nil first argument is what every in-tree caller used to pass.
local legacyNil = utils.standardHeaderBoxes(nil, colorMode, headeropts, 0)
t.check("nil leading arg produces identical boxes", digest(legacyNil) == digest(current),
    "digest mismatch")

-- A theme that defined its own i18n helper would pass a function or a table.
local legacyFn = utils.standardHeaderBoxes(function() end, colorMode, headeropts, 0)
t.check("function leading arg produces identical boxes", digest(legacyFn) == digest(current),
    "digest mismatch")

local legacyTbl = utils.standardHeaderBoxes({get = function() end}, colorMode, headeropts, 0)
t.check("table leading arg produces identical boxes", digest(legacyTbl) == digest(current),
    "digest mismatch")

t.group("txbatt_type is read from the right position in both forms")
for _, variant in ipairs({0, 1, 2}) do
    local cur = digest(utils.standardHeaderBoxes(colorMode, headeropts, variant))
    local leg = digest(utils.standardHeaderBoxes(nil, colorMode, headeropts, variant))
    t.check("txbatt_type=" .. variant .. " matches across both forms", cur == leg,
        "digest mismatch")
end

-- The three txbatt_type variants must not all collapse to the same box set,
-- or the check above would pass even if the argument were being dropped.
local d0 = digest(utils.standardHeaderBoxes(colorMode, headeropts, 0))
local d1 = digest(utils.standardHeaderBoxes(colorMode, headeropts, 1))
t.check("txbatt_type actually changes the boxes", d0 ~= d1,
    "type 0 and 1 produced identical output")

return t.failures()
