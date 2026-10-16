-- Carbon Pulse live instruments. Entry point adapted from Studio Stratus 98. GPLv3.
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
return requireModule("widgets/dashboard/themes/carbonpulse/state.lua").create("inflight")
