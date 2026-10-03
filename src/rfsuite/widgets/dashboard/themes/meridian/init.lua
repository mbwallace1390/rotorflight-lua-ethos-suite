-- Meridian: twin-rail Rotorflight telemetry dashboard.
-- GPLv3
return {
    key = "meridian",
    name = "Meridian",
    preflight = "preflight.lua", inflight = "inflight.lua", postflight = "postflight.lua",
    configure = "configure.lua",
    standalone = false,
    minResolution = {x = 784, y = 294},
}
