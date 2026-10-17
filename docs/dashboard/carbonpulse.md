# Carbon Pulse

Neon-blue chamfered panels over carbon fibre, a segmented headspeed arc with a
needle, bright green readings and condensed italic lettering.

## Select and configure

Select **System → Settings → Dashboard → Themes → Carbon Pulse**. Open
**System → Settings → Dashboard → Settings → Carbon Pulse** to adjust its display
limits and arc scale. Global choices and theme settings work offline while the
Suite background task runs. A model-specific selection requires a connected
flight controller with a known MCU ID.

This theme supports full 800 × 480 and compact 784 × 294 layouts. Both the theme
choice and configuration tile are hidden below 784 × 294, including 480 × 320
and 472 × 191 windows. The compact layout omits the native header; full screen
retains the dynamic model name, transmitter battery/RSSI, and centered title.

## Screens

- **Preflight:** a status pill, the flight timer with last flight, total time
  and flight count, bank and rate profiles, and a check panel with lamps for
  PACK, FUEL, BEC, ESC and LINK. Link, BEC, MCU temperature, throttle, pack
  voltage, fuel and ESC temperature surround it. The screen reports telemetry
  state; it is not a flight-clearance system.
- **Inflight:** the headspeed arc with the numeric headspeed in its centre, MCU
  temperature, throttle, altitude and flight state. The status pill is amber
  when armed and red for lost headspeed. Link, BEC, current, capacity used,
  pack voltage, fuel and ESC temperature surround it.
- **Postflight:** recorded results: flight time, average current, peak
  headspeed, peak MCU and ESC temperature, peak current, capacity used and
  maximum altitude, with minimum link, cell, BEC, pack voltage and fuel.
  Unavailable readings remain marked.

On the preflight screen the pill and flight state read ARM UNKNOWN until the
flight controller reports its arm state, unless the governor is running. With the
governor mode set to OFF or LIMIT, an armed model's flight state reads ARMED /
PASSTHRU.

See the [three phase previews](../dashboard-themes/Carbon%20Pulse/README.md).
They use simulated telemetry and desktop fonts: **Desktop preview, not radio capture**.

## Headspeed arc

The arc has 40 segments over 240°. Segments light up to the current headspeed as
a share of **Arc maximum** (default 3000 rpm, 500 to 6000). The last quarter of
the scale is shaded as a reference: amber from 75% and red from 90% of the arc
maximum, and the needle takes the colour of its zone. The numeric headspeed is
always shown in full, and the arc stays full above the maximum. The arc maximum
is a display scale only: it is not a governor setting, limit or warning, and it
does not change the flight controller.

## Saved settings

| Setting | Default and meaning |
| --- | --- |
| BEC critical | 6.5 V; flags voltage below this threshold. |
| BEC caution below | 7.0 V; cautions below this threshold, which stays above BEC critical. |
| Fuel warning | 25%; flags remaining fuel at or below this threshold. |
| ESC warning | 110°C / 230°F; cautions at or above this temperature. |
| ESC maximum | 150°C / 302°F; flags at or above this temperature, above ESC warning. |
| Arc maximum | 3000 rpm; the headspeed at a full arc. |
| Link warning | 50%; cautions below this percentage. |

The selection ID is `system/carbonpulse`. Theme instrument settings are stored in
`dashboard.carbonpulse` within `SCRIPTS:/rfsuite.user/settings.ini`. They are
shared by models using this theme. Global phase choices are saved in the same
file; model overrides are saved in `SCRIPTS:/rfsuite.user/models/<MCU ID>.ini`.

Save changes local radio files, not flight-controller EEPROM or controller
protection settings. Temperature fields use the selected display unit while
stored thresholds remain Celsius. Reload restores the form's loaded or last
saved values. Selecting a per-model appearance does not create per-model
instrument thresholds.

## Lettering

ETHOS documents no font file format for `lcd.loadFont`, so the theme draws each
character from a glyph mask in its `gfx/` folder and tints it with the text
colour. The masks are
rendered from Barlow Condensed in five sizes; with the carbon tile, `gfx/` holds
203 PNG files of about 76 KB, generated with `glyphs.lua` by an external MWRC
Theme Studio script that is not part of this repository. A mask is loaded the
first time its character is laid out, and the masks and tile are released with
the Suite's other images on a theme reload, a model change and when the widget
closes. A text with a character outside the glyph sets, or too wide for every
size, uses the radio font. Missing masks fall back to the radio font and a
missing carbon tile to a flat background.

Each paint lays out a limited amount of new text to keep within the radio's
per-callback instruction limit, more when the radio reports spare instructions
in that paint. After startup, a phase change or a resize, the panels draw on the
first frame and the lettering is laid out over the next few; it is then drawn all
at once, about 0.1 to 0.2 s after power-up or a theme selection, with or without
a link. The dashboard
repaints only when its data changes, and the radio ignores a repaint request
made during a paint. So while text is still waiting, an invisible pacer box in
the theme keeps the dashboard's wake pass from finishing, and the dashboard
schedules another wakeup and repaint, as for any box that has not woken. Once the
screen is complete the extra frames stop. After 20 held passes in a row, as while
two dashboards of different sizes paint in turn, it stops holding passes until a
paint completes the screen. After a resize the dashboard repaints once without
text; the text completes on the next telemetry update or screen change. Readings that have waited longest go first, so a changing
reading waits at most a few paints.

## Installation and verification

Install the complete matching Suite build containing this theme and its loader,
theme-picker, settings-tile, and settings-store registrations. Preserve the
radio's `rfsuite.user` directory and restart scripts or the radio after updating.
Copying the theme folder alone onto a stock build that does not register it is
insufficient.

The portable checks in `tests/themes/test_carbonpulse_registration.py` exercise
selection, save/reopen, model overrides, and minimum-size visibility against
production Suite modules. See `tests/themes/README.md` for commands and evidence
limits. Mask and bitmap rendering on the radio, file-loading time, real telemetry
transitions, and radio instruction/memory behaviour still need simulator and
physical-radio verification.

Source: `src/rfsuite/widgets/dashboard/themes/carbonpulse/`.

The theme code is GPLv3, consistent with the Suite. The glyph masks in
`gfx/big`, `gfx/mid`, `gfx/small`, `gfx/label` and `gfx/tiny`, and
`glyphs.lua`, are derived from Barlow Condensed, copyright 2017 The Barlow
Project Authors (https://github.com/jpt/barlow), and are distributed under the
SIL Open Font License 1.1 in `gfx/FONT-LICENSE.txt`.
