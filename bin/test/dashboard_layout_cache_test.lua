--[[
  dashboard.renderLayout() caching.

  renderLayout runs on every paint. Two things it used to rebuild each time are
  now gated on a structural check: the box-type signature (which costs a
  table.sort) and the per-box geometry pass.

  These tests pin both halves of that contract -- that the caches hold across
  steady-state paints, and that they are actually dropped when something they
  depend on changes. A cache that never invalidates would pass the first half
  and silently break the dashboard on theme or resolution changes.
]] --

local mock = dofile("bin/test/lib/ethos_mock.lua")
local t = dofile("bin/test/lib/t.lua")

mock.install()
local dashboard = mock.loadDashboard()

local boxes = mock.gridBoxes(12)
local headerBoxes = mock.gridBoxes(4)
local config = {
    layout = {cols = 4, rows = 3, padding = 4},
    header_layout = {height = 40, cols = 7, rows = 1},
    boxes = boxes,
    header_boxes = headerBoxes,
}

--- Digest of every rect, so a cached pass can be proved to produce byte-identical
--- geometry rather than merely "some" geometry.
local function digest()
    local out = {}
    for i, r in ipairs(dashboard.boxRects) do
        out[i] = string.format("%d:%s,%s,%s,%s,%s", i, r.x, r.y, r.w, r.h, tostring(r.isHeader))
    end
    return table.concat(out, "|")
end

t.group("warm-up")
dashboard.renderLayout(nil, config)
t.eq("rect count (12 body + 4 header)", #dashboard.boxRects, 16)
local baseline = digest()

t.group("steady state holds the caches")
mock.resetCounts()
for _ = 1, 20 do dashboard.renderLayout(nil, config) end
t.eq("box-type signature sorts over 20 paints", mock.counts.sort, 0)
t.eq("object reloads over 20 paints", mock.counts.loadAllObjects, 0)
t.check("geometry identical to warm-up", digest() == baseline, "geometry drifted")
t.eq("rect count stable", #dashboard.boxRects, 16)

t.group("resolution change invalidates geometry")
mock.setWindowSize(640, 480)
dashboard.renderLayout(nil, config)
t.check("geometry recomputed at new size", digest() ~= baseline, "geometry did not change")
mock.setWindowSize(800, 480)
dashboard.renderLayout(nil, config)
t.check("geometry restored at original size", digest() == baseline, "geometry did not return")

t.group("swapping the boxes table invalidates both caches")
config.boxes = mock.gridBoxes(8)
mock.resetCounts()
dashboard.renderLayout(nil, config)
t.check("signature rebuilt", mock.counts.sort >= 1, "sorts=" .. mock.counts.sort)
t.eq("rect count follows new box count", #dashboard.boxRects, 12)

t.group("externally clearing boxRects forces a rebuild")
-- Every invalidation path in dashboard.lua clears boxRects; the geometry cache
-- keys on its length so those paths keep working without knowing it exists.
config.boxes = boxes
dashboard.renderLayout(nil, config)
for i = #dashboard.boxRects, 1, -1 do dashboard.boxRects[i] = nil end
dashboard.renderLayout(nil, config)
t.eq("rects rebuilt", #dashboard.boxRects, 16)
t.check("geometry matches original", digest() == baseline, "geometry drifted")

t.group("steady state again after all that churn")
mock.resetCounts()
for _ = 1, 10 do dashboard.renderLayout(nil, config) end
t.eq("sorts", mock.counts.sort, 0)
t.eq("object reloads", mock.counts.loadAllObjects, 0)

return t.failures()
