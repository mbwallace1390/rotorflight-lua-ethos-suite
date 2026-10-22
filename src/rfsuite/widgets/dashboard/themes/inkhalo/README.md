# Ink & Halo

Rotorflight dashboard companion to the native Ink & Halo ETHOS radio theme.
Ink-black surfaces, pale-blue elliptical halo, soft-white telemetry, and restrained outlined panels.

- Preflight shows five required telemetry checks. Missing readings prevent READY.
- Inflight places headspeed beneath the halo, with fuel, ESC temperature, current, and pack voltage below.
- Postflight presents recorded peaks and minima; it does not calculate a health score.
- Full 800 x 480 views reserve the native 44-pixel header, including the dynamic model name. Compact 784 x 294 views omit that header.
- Threshold settings use the Suite's active `inkhalo` dashboard preference scope. Temperature settings respect Celsius/Fahrenheit display units.

Ink & Halo is available through automatic discovery in All Themes and through
the supplied registrations in its individual Suite package. All Themes retains
the palette metadata used by its existing integration.

Desktop Lua-rendered previews approximate the radio's fonts. Physical-radio visual and instruction-budget acceptance is still required.

## Compatible installation

Use a complete All Themes package, or a stock Suite package containing this
theme's registrations. On a compatible All Themes installation, copy the
complete `inkhalo` folder under
`SCRIPTS:/rfsuite/widgets/dashboard/themes/`, then restart the Suite Lua session
or radio. Select **Ink & Halo** in **System → Settings → Dashboard → Themes**;
configure it in **Dashboard → Settings → Ink & Halo**. Both choices require at least
784 × 294 available pixels. Full-screen rendering is 800 × 480.

All Themes uses `system/inkhalo` and `dashboard.inkhalo`. Settings save
on the radio; they do not write flight-controller EEPROM. Preserve user
settings when updating. [Full theme guide](../../../../../../docs/dashboard/inkhalo.md)
and [submission standard](../../../../../../docs/theme-submissions.md).
