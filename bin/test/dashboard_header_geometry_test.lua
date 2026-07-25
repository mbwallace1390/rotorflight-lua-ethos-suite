--[[
  Header box geometry in dashboard.renderLayout().

  Header boxes sit on their own grid -- header_layout's cols/rows/padding over
  the header strip -- not the body grid. The rects stored in dashboard.boxRects
  drive onpress hit-testing and the partial-invalidate rects in
  wakeup_protected, so they have to agree with where the boxes are actually
  painted.

  They did not. The rect pass sized header boxes with the body grid while the
  paint pass used the header grid, which on an 800x480 screen with a 40px
  header produced 141px-tall boxes, x coordinates past the screen edge, and a
  negative width on the last box. These assertions fail on every header box
  against that code.
]] --

local mock = dofile("bin/test/lib/ethos_mock.lua")
local t = dofile("bin/test/lib/t.lua")

mock.install()
local dashboard = mock.loadDashboard()

local SCREEN_W, SCREEN_H = 800, 480
local HEADER_H = 40
local BODY_BOXES = 12

mock.setWindowSize(SCREEN_W, SCREEN_H)

-- Shapes mirror utils.standardHeaderBoxes(): a 7-column header strip carrying a
-- spanning craft-name box, a logo, a battery readout and an RSSI gauge, over a
-- body grid with entirely different dimensions.
local headerBoxes = {
    {col = 1, row = 1, colspan = 2, type = "text"},
    {col = 3, row = 1, colspan = 3, type = "image"},
    {col = 6, row = 1, type = "text"},
    {col = 7, row = 1, type = "gauge"},
}

local config = {
    layout = {cols = 4, rows = 3, padding = 4},
    header_layout = {height = HEADER_H, cols = 7, rows = 1},
    boxes = mock.gridBoxes(BODY_BOXES),
    header_boxes = headerBoxes,
}

dashboard.renderLayout(nil, config)

t.group("header rects are usable as hit-test and invalidate regions")

local rightEdge = 0
for i = 1, #headerBoxes do
    local r = dashboard.boxRects[BODY_BOXES + i]
    t.check(string.format("rect %d exists", i), r ~= nil, "nil")
    if r then
        t.check(string.format("rect %d is header height", i), r.h == HEADER_H,
            string.format("h=%s want %d", tostring(r.h), HEADER_H))
        t.check(string.format("rect %d has positive width", i), r.w > 0,
            "w=" .. tostring(r.w))
        t.check(string.format("rect %d fits on screen horizontally", i),
            r.x >= 0 and (r.x + r.w) <= SCREEN_W,
            string.format("x=%s w=%s screen=%d", tostring(r.x), tostring(r.w), SCREEN_W))
        t.check(string.format("rect %d sits inside the header strip", i),
            r.y >= 0 and (r.y + r.h) <= HEADER_H,
            string.format("y=%s h=%s strip=%d", tostring(r.y), tostring(r.h), HEADER_H))
        t.check(string.format("rect %d is flagged as header", i), r.isHeader == true,
            tostring(r.isHeader))
        rightEdge = math.max(rightEdge, r.x + r.w)
    end
end

t.check("rightmost header box reaches the screen edge", rightEdge == SCREEN_W,
    "rightEdge=" .. tostring(rightEdge))

t.group("header geometry has a single source")
t.check("_headerGeoms populated", #(dashboard._headerGeoms or {}) == #headerBoxes,
    "#=" .. tostring(#(dashboard._headerGeoms or {})))
t.check("_headerGeomsPaint no longer exists", dashboard._headerGeomsPaint == nil,
    "second copy still present")

t.group("header boxes do not overlap each other")
for i = 1, #headerBoxes - 1 do
    local a = dashboard.boxRects[BODY_BOXES + i]
    local b = dashboard.boxRects[BODY_BOXES + i + 1]
    if a and b then
        t.check(string.format("rect %d ends at or before rect %d starts", i, i + 1),
            (a.x + a.w) <= b.x + 0.001,
            string.format("%s+%s vs %s", tostring(a.x), tostring(a.w), tostring(b.x)))
    end
end

return t.failures()
