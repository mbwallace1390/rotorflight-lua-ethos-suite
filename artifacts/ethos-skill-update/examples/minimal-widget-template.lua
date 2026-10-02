-- Standalone Ethos widget; select a numeric telemetry source in Configure.
-- This is not a Rotorflight Suite dashboard phase module.
local WIDGET_KEY = "mytmpl"
local floor = math.floor
local format = string.format
local huge = math.huge

local function create()
    return {source = nil, displayValue = nil, displayText = "--"}
end

local function configure(widget)
    local line = form.addLine("Telemetry source")
    form.addSourceField(line, nil,
        function() return widget.source end,
        function(value)
            -- The selected Source belongs to this widget instance.
            widget.source = value
        end)
end

local function read(widget)
    -- Source objects are serialized by Ethos storage in widget read/write.
    widget.source = storage.read("source")
end

local function write(widget)
    storage.write("source", widget.source)
end

local function wakeup(widget)
    local value = nil
    local source = widget.source
    if source and source:state() then
        local raw = source:value()
        if type(raw) == "number" and raw == raw and raw ~= huge and raw ~= -huge then
            -- Quantize before change detection, avoiding reformatting jitter.
            value = floor(raw + 0.5)
        end
    end
    if value ~= widget.displayValue then
        -- Freshness changes also clear an obsolete displayed reading.
        widget.displayValue = value
        widget.displayText = value ~= nil and format("%.0f", value) or "--"
        lcd.invalidate()
    end
end

local function paint(widget)
    local w, h = lcd.getWindowSize()
    lcd.font(FONT_XL)
    lcd.drawText(w / 2, h / 2, widget.displayText, CENTERED + VCENTERED)
end

local function init()
    system.registerWidget({key = WIDGET_KEY, name = "My Widget", create = create,
        configure = configure, read = read, write = write, wakeup = wakeup, paint = paint})
end

return {init = init}
