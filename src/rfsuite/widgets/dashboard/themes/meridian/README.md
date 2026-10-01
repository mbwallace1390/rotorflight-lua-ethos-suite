# Meridian

A navy-black flight dashboard with ice-cyan clipped frames, a mint fuel rail,
an ice-blue ESC-temperature rail, and a large central headspeed readout.
The continuous bottom strip carries flight time, current, BEC supply, and link.

- Preflight checks pack voltage, fuel, BEC, ESC temperature, and link. A missing
  reading prevents telemetry-ready status; warnings remain visible.
- Inflight displays live headspeed as a number only, with no configured RPM
  threshold, comparison, or scale.
- Postflight explicitly labels recorded fuel, temperature, current, cell,
  BEC, and link history. Duration/count/total retain the current flight after
  disconnect and reset when the model changes. Missing history stays unavailable.
- Full 800x480 uses the native 44-pixel header with a dynamic, bounded model
  name and the centered Rotorflight // Ethos title plus smaller MWRC signature.
  Compact 784x294 omits the native header and retains the same instrument order.
- Settings use the active `meridian` dashboard preferences. BEC, fuel, thermal,
  and link thresholds are configurable. Temperature thresholds are stored in
  Celsius and presented in the selected Celsius/Fahrenheit display units.

This folder owns its helpers and palette metadata; it has no dependency on
another custom theme. Meridian registration is included in the current
`radio-all-themes` source changes: select **System > Settings > Dashboard >
Themes**, then configure its warnings under **Dashboard > Settings > Meridian**.
Both choices are hidden when the available screen is smaller than 784x294.

Thresholds are saved locally on the radio in Meridian's settings section and
apply to models using this theme. Selecting a per-model theme is a separate
option; it requires a connected flight controller with a known MCU ID. These
display settings do not write flight-controller EEPROM.

The separate Meridian branch scope is this theme plus the four existing
loader/settings registrations. Its `appTheme` metadata is available to an
optional compatible Theme Bridge; the theme does not require or install Bridge.
This work targets the theme branches and leaves `main`/`master` unchanged.
Registration in source does not itself indicate that a release was published.

Validation uses the actual Suite Lua engine with desktop LCD metrics. Physical
radio checks remain necessary for native fonts and memory/instruction budgets.
GPLv3, consistent with the Suite and the maintained theme telemetry foundation.
