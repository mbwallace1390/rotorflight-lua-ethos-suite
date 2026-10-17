-- Carbon Pulse: neon chamfered panels on the header's dark face, with a segmented
-- headspeed arc and condensed italic lettering. Studio original visual frame;
-- telemetry roles are adapted from Studio Stratus 98. GPLv3.
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local D = requireModule("widgets/dashboard/themes/carbonpulse/common.lua")
local L = requireModule("widgets/dashboard/themes/carbonpulse/lettering.lua")
local T = L.text
local C = D.colors
local lcd, floor, min, max = lcd, math.floor, math.min, math.max
local sin, cos, rad = math.sin, math.cos, math.rad
local M = {}

-- Characters laid out per paint (see lettering.lua). None on a paint that also
-- builds the geometry: that paint is already the most expensive one. CONTINUED
-- on the paint after one that left text waiting, on an engine that delivers the
-- frames to finish it (state.lua), whatever started its pass: a pacer pass, a
-- data event or a connect. The allowance bounds its cost, and radios without
-- system.getInstructionsUsage finish sooner.
local QUOTA, CONTINUED = 48, 144
-- Wake passes kept open in a row (see M.waiting); a cold screen needs about 3.
-- Past MAX_PACED nothing is kept open until a paint completes the screen, so
-- text that cannot finish (two dashboards of different sizes painting in turn)
-- cannot keep the radio repainting.
local MAX_PACED = 20
local paced = 0
-- Paints a screen's text may be held before it is drawn as it is laid out
-- (see begin), so text that cannot finish is still shown.
local MAX_HELD = 10

local DIM = {[C.green] = lcd.RGB(16, 64, 34), [C.amber] = lcd.RGB(70, 54, 8), [C.red] = lcd.RGB(72, 20, 16)}
local BRIGHT = {[C.green] = C.zoneGreen, [C.amber] = C.zoneAmber, [C.red] = C.zoneRed}
-- 40 segments put the 75% and 90% zone edges exactly on segment edges.
local SEGMENTS, SWEEP, START = 40, 240, 240
local PHASE = {preflight = "PREFLIGHT", inflight = "INFLIGHT", postflight = "RECORDED"}
local CHECKS = {"PACK", "FUEL", "BEC", "ESC", "LINK"}
-- Calm states draw an outlined pill; every other state is an armed one.
local PILL = {["TELEMETRY OFFLINE"] = "OFFLINE", ["DISARMED"] = "DISARMED", ["ARM UNKNOWN"] = "ARM UNKNOWN"}
-- Text-cache slot names are constants so paint never builds strings.
local RIGHT_L, RIGHT_V = {"right1L", "right2L", "right3L"}, {"right1V", "right2V", "right3V"}

-- Chamfered outline (top-left and bottom-right corners cut): six segments
-- appended to four parallel arrays {x1, y1, x2, y2}, written inline because a
-- helper call per segment would add to the geometry paint, the heaviest one.
local function outline(l, n, x, y, w, h, cut)
    local r, b = x + w - 1, y + h - 1
    local x1, y1, x2, y2 = l[1], l[2], l[3], l[4]
    x1[n + 1], y1[n + 1], x2[n + 1], y2[n + 1] = x + cut, y, r, y
    x1[n + 2], y1[n + 2], x2[n + 2], y2[n + 2] = r, y, r, b - cut
    x1[n + 3], y1[n + 3], x2[n + 3], y2[n + 3] = r, b - cut, r - cut, b
    x1[n + 4], y1[n + 4], x2[n + 4], y2[n + 4] = r - cut, b, x, b
    x1[n + 5], y1[n + 5], x2[n + 5], y2[n + 5] = x, b, x, y + cut
    x1[n + 6], y1[n + 6], x2[n + 6], y2[n + 6] = x, y + cut, x + cut, y
    return n + 6
end

local function frame(g, key, x, y, w, h)
    local p = g[key]
    if not p then p = {}; g[key] = p end
    p.x, p.y, p.w, p.h = x, y, w, h
    g.neonCount = outline(g.neon, g.neonCount, x, y, w, h, g.cut)
    g.glowCount = outline(g.glow, g.glowCount, x - 1, y - 1, w + 2, h + 2, g.cut + 1)
    return p
end

-- Every position, cached for the last box size and shared by the three phases,
-- so a phase change does not rebuild it. Returns the geometry and whether this
-- call rebuilt it. neon and glow are outline segments with a one-pixel outer
-- glow; a1/a2 are arc segment angles and runs the arc's zone runs.
local G = {neon = {{}, {}, {}, {}}, glow = {{}, {}, {}, {}}, a1 = {}, a2 = {}, runs = {}}
local function geometry(x, y, w, h)
    local g = G
    if g.x == x and g.y == y and g.w == w and g.h == h then return g, false end
    g.x, g.y, g.w, g.h, g.version = x, y, w, h, (g.version or 0) + 1
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    local k = h < 340
    g.compact = k
    g.label = k and "tiny" or "label"
    local m, gap = k and 6 or 8, k and 6 or 8
    g.cut = k and 7 or 10
    g.neonCount, g.glowCount = 0, 0
    local sideW = floor(w * (k and 0.235 or 0.245))
    local bottomH = k and 52 or 76
    local mainY = y + m
    local mainH = h - 2 * m - bottomH - gap
    local leftX = x + m
    local rightX = x + w - m - sideW
    local centerX = leftX + sideW + gap
    local centerW = rightX - gap - centerX
    local bottomY = mainY + mainH + gap
    local pillH = k and 30 or 40
    local linkH = k and 42 or 60
    g.pill = frame(g, "pillBox", leftX, mainY, sideW, pillH)
    g.left = frame(g, "leftBox", leftX, mainY + pillH + gap, sideW, mainH - pillH - gap)
    g.center = frame(g, "centerBox", centerX, mainY, centerW, mainH)
    g.link = frame(g, "linkBox", rightX, mainY, sideW, linkH)
    g.right = frame(g, "rightBox", rightX, mainY + linkH + gap, sideW, mainH - linkH - gap)
    g.mark = frame(g, "markBox", leftX, bottomY, sideW, bottomH)
    g.battery = frame(g, "batteryBox", centerX, bottomY, centerW, bottomH)
    g.esc = frame(g, "escBox", rightX, bottomY, sideW, bottomH)
    for k = 1, 4 do
        local neon, glow = g.neon[k], g.glow[k]
        for i = g.neonCount + 1, #neon do neon[i] = nil end
        for i = g.glowCount + 1, #glow do glow[i] = nil end
    end
    -- Headspeed arc: 240 degrees clockwise from the lower left, split at the top
    -- so no sector crosses 360. Segment zones match the readout colours.
    local cp = g.center
    local radius = floor(min(centerW * 0.40, mainH * (k and 0.44 or 0.42)))
    g.arcR, g.arcInner = radius, radius - (k and 9 or 14)
    g.arcX, g.arcY = cp.x + floor(centerW / 2), cp.y + floor(mainH * (k and 0.56 or 0.54))
    local a1, a2, runs = g.a1, g.a2, g.runs
    local step = SWEEP / SEGMENTS
    local n, previous = 0, nil
    for i = 1, SEGMENTS do
        local from, to = START + (i - 1) * step + 0.6, START + i * step - 0.6
        if from >= 360 then from, to = from - 360, to - 360 end
        a1[i], a2[i] = from, to
        -- A segment's zone is that of its start, the rule state.lua uses for the
        -- needle, so the needle always matches the segment it points into.
        local f = (i - 1) / SEGMENTS
        local zone = f >= 0.9 and C.red or (f >= 0.75 and C.amber or C.green)
        -- Contiguous runs {first, last, zone, ...} so paint sets each colour once.
        if zone ~= previous then
            runs[n + 1], runs[n + 2], runs[n + 3] = i, i, zone
            n, previous = n + 3, zone
        else
            runs[n - 1] = i
        end
    end
    for i = n + 1, #runs do runs[i] = nil end
    g.needleFraction = nil
    return g, true
end

-- Needle triangle for the current fraction; recomputed only when it moves.
local function needle(g, fraction)
    if g.needleFraction == fraction then return end
    g.needleFraction = fraction
    local a = rad(START + SWEEP * fraction)
    local dx, dy = sin(a), -cos(a)
    local tip, base = g.arcInner - 3, g.arcInner - (g.compact and 15 or 22)
    local half = g.compact and 5 or 7
    local cx, cy = g.arcX, g.arcY
    g.n1x, g.n1y = floor(cx + dx * tip + 0.5), floor(cy + dy * tip + 0.5)
    g.n2x, g.n2y = floor(cx + dx * base - dy * half + 0.5), floor(cy + dy * base + dx * half + 0.5)
    g.n3x, g.n3y = floor(cx + dx * base + dy * half + 0.5), floor(cy + dy * base - dx * half + 0.5)
end

-- One flat fill in the header's face colour, so the body matches the header. It
-- starts at the top of the window: the header boxes paint over it afterwards
-- (the engine adds them after the theme box), and the engine rounds the header
-- down to whole cells, which leaves a strip at its right end. Until the screen
-- of cache c has had all its text laid out at this geometry, the lettering is
-- held and drawn at once by the paint that completes it (finish);
-- the panels draw at once. Held only where the Suite delivers the frames that
-- complete it (c._paced, state.lua); elsewhere text draws as it is laid out.
local function begin(x, y, w, h, c)
    local g, rebuilt = geometry(x, y, w, h)
    D.frame()
    local hold = c._paced == true and c._complete ~= g.version and (c._held or 0) < MAX_HELD
    c._holding = hold
    L.frame(rebuilt and 0 or (c._paced == true and c._continuing == true and CONTINUED or QUOTA), hold)
    D.fill(C.bg, x, 0, w, y + h)
    return g
end

-- A paint records whether it left lettering waiting; M.waiting reads it.
local function finish(g, c)
    local complete = not L.blank()
    if c._holding then
        if complete then
            L.reveal()
            c._held = 0
        else
            L.drop()
            c._held = (c._held or 0) + 1
        end
    end
    if complete then c._complete = g.version end
    D.segments(C.glow, g.glow, g.glowCount)
    D.segments(C.neon, g.neon, g.neonCount)
    c._settled = not L.pending()
end

-- Whether the screen of cache c still needs frames, for state.lua's pacer box.
-- The Suite repaints only when its data changes, and ETHOS ignores an
-- lcd.invalidate() made during paint, so the frames that finish deferred
-- lettering come from the Suite's own wake passes, kept open while this is
-- true. True when the last paint left lettering waiting, when c has not been
-- painted, or when the box has another size, as its next paint rebuilds the
-- geometry and lays out no text. Called from the theme box's wakeup, where the
-- engine has set the box's rectangle.
function M.waiting(c, box)
    local g = G
    if c._settled == true and g.x == box._dashboardRectX and g.y == box._dashboardRectY
            and g.w == box._dashboardRectW and g.h == box._dashboardRectH then
        paced = 0
        return false
    end
    paced = paced + 1
    return paced <= MAX_PACED
end

-- Status pill: outlined when calm, filled for armed states: dark text on amber,
-- white on red as for every other critical state.
local function pill(c, g, label, color, filled)
    local p = g.pill
    if filled then
        D.fill(color, p.x, p.y, p.w, p.h)
        D.triangle(C.bg, p.x, p.y, p.x + g.cut, p.y, p.x, p.y + g.cut)
        local r, b = p.x + p.w - 1, p.y + p.h - 1
        D.triangle(C.bg, r, b, r - g.cut, b, r, b - g.cut)
    end
    T(c, "pill", p.x + 8, p.y, p.w - 16, p.h, label, g.compact and "small" or "label",
        filled and (color == C.red and C.white or C.bg) or color, "center")
end

local function flightPill(c, g)
    local label = PILL[c.flightState]
    if label then
        pill(c, g, label, c.flightStateColor, false)
    else
        pill(c, g, c.flightStateColor == C.red and "LOST HEADSPEED" or "ARMED", c.flightStateColor, true)
    end
end

-- Label above a value, centred in a slot.
local function stat(c, g, slotL, slotV, x, y, w, h, label, value, color)
    local lh = g.compact and 14 or 18
    T(c, slotL, x, y, w, lh, label, g.label, C.label, "center")
    T(c, slotV, x, y + lh, w, h - lh, value, g.compact and "small" or "mid", color or C.value, "center")
end

-- Label at the left, value at the right of one row.
local function row(c, g, slotL, slotV, x, y, w, h, label, value, color)
    local lw = floor(w * 0.45)
    T(c, slotL, x, y, lw, h, label, g.label, C.label)
    T(c, slotV, x + lw, y, w - lw, h, value, "label", color or C.white, "right")
end

local function timerPanel(c, g, title)
    local p, k = g.left, g.compact
    local px, pw = p.x + 8, p.w - 16
    local y = p.y + (k and 4 or 8)
    T(c, "timerLabel", px, y, pw, k and 14 or 18, title, g.label, C.label, "center")
    y = y + (k and 14 or 20)
    T(c, "timer", px, y, pw, k and 38 or 56, c.timer, k and "mid" or "big", C.value, "center")
    y = y + (k and 38 or 58)
    local rh = k and 16 or 26
    row(c, g, "lastL", "lastV", px, y, pw, rh, "LAST", c.lastText)
    row(c, g, "totalL", "totalV", px, y + rh, pw, rh, "TOTAL", c.totalText)
    row(c, g, "flightsL", "flightsV", px, y + 2 * rh, pw, rh, "FLIGHTS", c.flightsText)
    return y + 3 * rh
end

local function profiles(c, g, y)
    local p, k = g.left, g.compact
    local half = floor((p.w - 16) / 2)
    local h = p.y + p.h - (k and 4 or 8) - y
    if h < (k and 30 or 40) then return end
    stat(c, g, "bankL", "bankV", p.x + 8, y, half, h, "BANK", c.pidText, c.pid and C.value or C.muted)
    stat(c, g, "rateL", "rateV", p.x + 8 + half, y, half, h, "RATE", c.rateText, c.rate and C.value or C.muted)
end

-- Headspeed arc with zone colours, bright where lit, and a needle.
local function gauge(c, g)
    local a1, a2, runs = g.a1, g.a2, g.runs
    local lit = floor((c.rpmFraction or 0) * SEGMENTS + 0.5)
    local cx, cy, inner, outer = g.arcX, g.arcY, g.arcInner, g.arcR
    local sector, setColor = lcd.drawAnnulusSector, D.setColor
    -- Per zone run, in segment order: the lit part bright, the rest dim.
    for r = 1, #runs, 3 do
        local first, last, z = runs[r], runs[r + 1], runs[r + 2]
        local split = lit < last and lit or last
        if split >= first then
            setColor(BRIGHT[z])
            for i = first, split do sector(cx, cy, inner, outer, a1[i], a2[i]) end
        end
        if split < last then
            setColor(DIM[z])
            for i = (split < first and first or split + 1), last do sector(cx, cy, inner, outer, a1[i], a2[i]) end
        end
    end
    if c.rpm ~= nil then
        needle(g, c.rpmFraction or 0)
        D.triangle(c.rpmZone or C.green, g.n1x, g.n1y, g.n2x, g.n2y, g.n3x, g.n3y)
    end
end

local function centerReadouts(c, g, aLabel, aValue, aColor, bLabel, bValue, bColor, unit, altLabel, state, stateColor)
    local p, k = g.center, g.compact
    local inset = k and 8 or 14
    local cornerW = floor(p.w * 0.30)
    T(c, "cornerAL", p.x + inset, p.y + 4, cornerW, k and 14 or 18, aLabel, g.label, C.label)
    T(c, "cornerAV", p.x + inset, p.y + (k and 18 or 22), cornerW, k and 18 or 26, aValue, "label", aColor)
    T(c, "cornerBL", p.x + p.w - inset - cornerW, p.y + 4, cornerW, k and 14 or 18, bLabel, g.label, C.label, "right")
    T(c, "cornerBV", p.x + p.w - inset - cornerW, p.y + (k and 18 or 22), cornerW, k and 18 or 26, bValue, "label", bColor, "right")
    local vw = floor(g.arcInner * 1.5)
    local vh = k and 44 or 70
    local vy = g.arcY - floor(vh * 0.75)
    T(c, "rpm", g.arcX - floor(vw / 2), vy, vw, vh, c.rpmText, k and "mid" or "big", c.rpm and C.value or C.muted, "center")
    T(c, "rpmUnit", g.arcX - 60, vy + vh, 120, k and 14 or 18, unit, g.label, C.label, "center")
    -- Altitude in a small framed box under the reading.
    local bw, bh = k and 120 or 160, k and 20 or 28
    local bx, by = g.arcX - floor(bw / 2), vy + vh + (k and 16 or 22)
    if by + bh <= p.y + p.h - (k and 20 or 30) then
        D.rect(C.glow, bx, by, bw, 1)
        D.rect(C.glow, bx, by + bh - 1, bw, 1)
        D.rect(C.glow, bx, by, 1, bh)
        D.rect(C.glow, bx + bw - 1, by, 1, bh)
        T(c, "altL", bx + 6, by, floor(bw * 0.35), bh, altLabel, g.label, C.label)
        T(c, "altV", bx + floor(bw * 0.35), by, floor(bw * 0.65) - 6, bh, c.altText, "label", C.white, "right")
    end
    T(c, "state", p.x + inset, p.y + p.h - (k and 18 or 26), p.w - 2 * inset, k and 14 or 20,
        state, g.label, stateColor, "center")
end

local function rightStack(c, g, l1, v1, c1, l2, v2, c2, l3, v3, c3)
    local p = g.right
    local h = floor((p.h - 8) / 3)
    local x, w, y = p.x + 6, p.w - 12, p.y + 4
    stat(c, g, RIGHT_L[1], RIGHT_V[1], x, y, w, h, l1, v1, c1)
    stat(c, g, RIGHT_L[2], RIGHT_V[2], x, y + h, w, h, l2, v2, c2)
    stat(c, g, RIGHT_L[3], RIGHT_V[3], x, y + 2 * h, w, h, l3, v3, c3)
end

local function bottom(c, g, phase, packLabel, fuelLabel, escLabel)
    local k = g.compact
    local mp = g.mark
    T(c, "brand", mp.x + 6, mp.y + 4, mp.w - 12, floor(mp.h / 2) - 2, "CARBON PULSE", "label", C.label, "center")
    T(c, "phase", mp.x + 6, mp.y + floor(mp.h / 2), mp.w - 12, floor(mp.h / 2) - 4, PHASE[phase], g.label, C.muted, "center")
    -- Battery: icon fill shows fuel only when it is known.
    local bp = g.battery
    local iw, ih = k and 18 or 24, bp.h - (k and 16 or 24)
    local ix, iy = bp.x + (k and 10 or 16), bp.y + floor((bp.h - ih) / 2) + 2
    D.rect(C.label, ix + floor(iw / 2) - 3, iy - 3, 6, 3)
    D.rect(C.label, ix, iy, iw, 2)
    D.rect(C.label, ix, iy + ih - 2, iw, 2)
    D.rect(C.label, ix, iy, 2, ih)
    D.rect(C.label, ix + iw - 2, iy, 2, ih)
    if c.fuel ~= nil then
        local fh = floor((ih - 6) * max(0, min(100, c.fuel)) / 100)
        if fh > 0 then D.fill(c.fuelValueColor, ix + 3, iy + ih - 3 - fh, iw - 6, fh) end
    end
    local tx = ix + iw + (k and 10 or 16)
    local tw = bp.x + bp.w - (k and 8 or 14) - tx
    local half = floor(tw * 0.55)
    local lh = k and 14 or 16
    T(c, "packL", tx, bp.y + 2, half, lh, packLabel, g.label, C.label)
    T(c, "packV", tx, bp.y + 2 + lh, half, bp.h - 4 - lh, c.voltageText, k and "mid" or "big", c.voltage and C.value or C.muted)
    T(c, "fuelL", tx + half, bp.y + 2, tw - half, lh, fuelLabel, g.label, C.label, "right")
    T(c, "fuelV", tx + half, bp.y + 2 + lh, tw - half, bp.h - 4 - lh, c.fuelText, k and "mid" or "big", c.fuelValueColor, "right")
    local ep = g.esc
    stat(c, g, "escL", "escV", ep.x + 6, ep.y + 4, ep.w - 12, ep.h - 8, escLabel, c.escText, c.escValueColor)
end

local function checkLamps(c, g, y)
    local p, k = g.center, g.compact
    local pack = c.voltage ~= nil and (c.voltage > 0 and C.green or C.amber) or C.muted
    local inset = k and 10 or 18
    local w = floor((p.w - 2 * inset) / 5)
    for i = 1, 5 do
        local color
        if i == 1 then color = pack elseif i == 2 then color = c.fuelColor
        elseif i == 3 then color = c.becColor elseif i == 4 then color = c.escColor
        else color = c.linkColor end
        if color == C.white then color = C.green end
        local xx = p.x + inset + (i - 1) * w
        D.rect(color or C.muted, xx + 4, y, w - 8, k and 4 or 6)
        -- The label size reuses glyphs the screen already loads.
        T(c, CHECKS[i], xx, y + (k and 6 or 10), w, k and 14 or 18, CHECKS[i], g.label, color or C.muted, "center")
    end
end

function M.preflight(x, y, w, h, c)
    local g = begin(x, y, w, h, c)
    local k = g.compact
    flightPill(c, g)
    profiles(c, g, timerPanel(c, g, "FLIGHT TIMER") + (k and 2 or 6))
    local p = g.center
    local inset = k and 10 or 18
    T(c, "checkLabel", p.x + inset, p.y + 6, p.w - 2 * inset, k and 14 or 18, "PREFLIGHT CHECK", g.label, C.label, "center")
    T(c, "status", p.x + inset, p.y + (k and 24 or 40), p.w - 2 * inset, k and 40 or 64, c.status, k and "small" or "mid", c.statusColor, "center")
    T(c, "issue", p.x + inset, p.y + (k and 68 or 112), p.w - 2 * inset, k and 18 or 26, c.issue, "label", c.issues > 0 and C.amber or C.muted, "center")
    T(c, "coverage", p.x + inset, p.y + (k and 88 or 142), p.w - 2 * inset, k and 18 or 24, c.coverage, g.label, C.white, "center")
    T(c, "flightState", p.x + inset, p.y + (k and 108 or 176), p.w - 2 * inset, k and 18 or 26, c.flightState, "label", c.flightStateColor, "center")
    checkLamps(c, g, p.y + p.h - (k and 28 or 44))
    stat(c, g, "linkL", "linkV", g.link.x + 6, g.link.y + 2, g.link.w - 12, g.link.h - 4, "LINK", c.linkText, c.linkValueColor)
    rightStack(c, g, "BEC", c.becText, c.becValueColor, "MCU", c.mcuText, c.mcu and C.value or C.muted,
        "THROTTLE", c.throttleText, c.throttle and C.value or C.muted)
    bottom(c, g, "preflight", "PACK", "FUEL", "ESC")
    finish(g, c)
end

function M.inflight(x, y, w, h, c)
    local g = begin(x, y, w, h, c)
    flightPill(c, g)
    profiles(c, g, timerPanel(c, g, "FLIGHT TIMER") + (g.compact and 2 or 6))
    gauge(c, g)
    centerReadouts(c, g, "MCU", c.mcuText, c.mcu and C.value or C.muted, "THROTTLE", c.throttleText,
        c.throttle and C.value or C.muted, "RPM", "ALT", c.flightState, c.flightStateColor)
    stat(c, g, "linkL", "linkV", g.link.x + 6, g.link.y + 2, g.link.w - 12, g.link.h - 4, "LINK", c.linkText, c.linkValueColor)
    rightStack(c, g, "BEC", c.becText, c.becValueColor, "CURRENT", c.currentText, c.current and C.value or C.muted,
        "USED", c.consumedText, c.consumed and C.value or C.muted)
    bottom(c, g, "inflight", "PACK", "FUEL", "ESC")
    finish(g, c)
end

function M.postflight(x, y, w, h, c)
    local g = begin(x, y, w, h, c)
    pill(c, g, "RECORDED", C.neon, false)
    local y2 = timerPanel(c, g, "FLIGHT TIME")
    local p, k = g.left, g.compact
    local rh = k and 16 or 26
    if y2 + rh <= p.y + p.h - 4 then
        row(c, g, "avgCurrentL", "avgCurrentV", p.x + 8, y2 + (k and 2 or 6), p.w - 16, rh, "AVG CURRENT", c.averageCurrentText)
    end
    gauge(c, g)
    centerReadouts(c, g, "PEAK MCU", c.mcuText, c.mcu and C.value or C.muted, "MIN LINK", c.linkText,
        c.linkValueColor, "PEAK RPM", "MAX ALT", c.recorded and "RECORDED SAMPLES" or "NO RECORDED SAMPLES",
        c.recorded and C.label or C.muted)
    stat(c, g, "linkL", "linkV", g.link.x + 6, g.link.y + 2, g.link.w - 12, g.link.h - 4, "MIN CELL", c.cellText, c.cell and C.value or C.muted)
    rightStack(c, g, "MIN BEC", c.becText, c.becValueColor, "PEAK CURRENT", c.currentText, c.current and C.value or C.muted,
        "USED", c.consumedText, c.consumed and C.value or C.muted)
    bottom(c, g, "postflight", "MIN PACK", "MIN FUEL", "PEAK ESC")
    finish(g, c)
end

return M
