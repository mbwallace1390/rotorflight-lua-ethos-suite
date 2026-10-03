-- Ink & Halo: Rotorflight dashboard companion to the native ETHOS theme.
-- GPLv3
return {
    key = "inkhalo",
    name = "Ink & Halo",
    preflight = "preflight.lua", inflight = "inflight.lua", postflight = "postflight.lua",
    configure = "configure.lua",
    standalone = false,
    minResolution = {x = 784, y = 294},
}
