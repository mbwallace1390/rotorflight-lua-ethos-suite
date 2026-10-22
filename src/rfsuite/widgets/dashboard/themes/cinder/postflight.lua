-- Cinder recorded-flight report. GPLv3.
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
return requireModule("widgets/dashboard/themes/cinder/state.lua").create("postflight")
