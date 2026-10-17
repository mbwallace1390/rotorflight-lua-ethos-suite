# Cinder

A matte charcoal Rotorflight dashboard with warm cream readings, thin copper
frames, and a sage fuel bar. The asymmetric inflight layout places headspeed
and flight time on the left, with fuel, ESC temperature, current, and pack
voltage stacked on the right.

- Preflight distinguishes complete, incomplete, disconnected, and warning
  telemetry checks. Missing readings do not produce a ready indication.
- Inflight headspeed is a live number only. There is no RPM limit, redline,
  comparison, gauge scale, or RPM threshold setting.
- Postflight explicitly presents recorded duration, capacity used, fuel,
  temperature, current, cell voltage, BEC, and link results. Missing history
  remains unavailable; valid zero history is retained. Changing models clears
  the previous aircraft's retained results.
- Full 800 × 480 screens have the native 44-pixel header at the top edge,
  a dynamic model name, and centered `Rotorflight // Ethos | MWRC` branding
  with the MWRC signature smaller. Compact 784 × 294 widgets omit that header.
- Configuration uses Cinder's own active dashboard preferences. Fuel, BEC,
  temperature, and link warnings are configurable. Temperature thresholds
  remain stored in Celsius while respecting the chosen display unit.

All helpers belong to this folder; it has no dependency on another custom
theme. Its `init.lua` includes Theme Bridge palette metadata.

Cinder registration is included in the current `radio-all-themes` source
changes. Select **System > Settings > Dashboard > Themes**, then configure its
warnings under **Dashboard > Settings > Cinder**. Both choices are hidden when
the available screen is smaller than 784x294.

Thresholds are saved locally on the radio in Cinder's settings section and
apply to models using this theme. A per-model theme selection is separate and
requires a connected flight controller with a known MCU ID. These display
settings do not write flight-controller EEPROM.



## Compatible installation

Use a complete All Themes package, or a stock Suite package containing this
theme's registrations. On a compatible All Themes installation, copy the
complete `cinder` folder under
`SCRIPTS:/rfsuite/widgets/dashboard/themes/`, then restart the Suite Lua session
or radio. Select **Cinder** in **System → Settings → Dashboard → Themes**;
configure it in **Dashboard → Settings → Cinder**. Both choices require at least
784 × 294 available pixels. Full-screen rendering is 800 × 480.

All Themes uses `system/cinder` and `dashboard.cinder`. Settings save
on the radio; they do not write flight-controller EEPROM. Preserve user
settings when updating. [Full theme guide](../../../../../../docs/dashboard/cinder.md)
and [submission standard](../../../../../../docs/theme-submissions.md).
