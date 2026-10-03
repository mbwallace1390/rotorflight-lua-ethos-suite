-- Cinder: matte charcoal instruments with etched copper edges. GPLv3.
return {
    key = "cinder", name = "Cinder",
    preflight = "preflight.lua", inflight = "inflight.lua", postflight = "postflight.lua",
    configure = "configure.lua", standalone = false,
    minResolution = {x = 784, y = 294},
}
