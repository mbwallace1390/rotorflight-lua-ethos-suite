# Zafira

A dark violet dashboard with turquoise accents and clearly separated flight instruments.

## Selection and installation

Select **System → Settings → Dashboard → Themes → Zafira**. Configure its
instrument warnings under **System → Settings → Dashboard → Settings → Zafira**.
The selector and settings tile require at least 784 × 294 available pixels;
480 × 320 and 472 × 191 windows cannot select this theme. The full layout is
800 × 480. Global selections and warning settings work offline while the Suite
background task runs; a per-model theme override requires a connected controller
with a known MCU ID.

Install a complete matching All Themes package first. To update just this theme
on a compatible All Themes installation, copy the complete `zafira` folder to
`SCRIPTS:/rfsuite/widgets/dashboard/themes/`, preserving helpers and assets, then
fully restart the Suite Lua session or radio. Stock Suite releases need their
own registration entries; copying a folder into one does not add those entries.

## Screens and settings

Preflight presents live readiness telemetry, inflight presents operating
measurements, and postflight presents recorded flight results. Missing readings
remain unavailable; recorded results are historical. The native full-screen
header retains the current model and transmitter indicators, with the centered
Rotorflight // Ethos title and smaller MWRC signature.

The All Themes saved selection is `system/zafira` and the warning section
is `dashboard.zafira` in `SCRIPTS:/rfsuite.user/settings.ini`. Warning
settings apply to models using this theme. Model-specific theme choices are
stored separately in the model's local INI. Save does not write flight-controller
EEPROM or change controller protection limits. Existing warning controls and
defaults are retained; temperature thresholds are stored in Celsius and displayed
in the selected units.

## Previews and validation

See the three phase views in the [dashboard gallery](../dashboard-themes/README.md).
They are desktop previews rendered from the actual Lua modules, not radio
captures. Desktop integration checks cover selection, saved settings and layout;
physical-radio font fitting, real telemetry and memory/instruction budgets still
need device validation. Preflight status describes telemetry checks, not aircraft
safety. Palette metadata supports the existing All Themes integration without
requiring a separate Bridge installation to use the dashboard.

Source: `src/rfsuite/widgets/dashboard/themes/zafira/`.
Related controller documentation: [Rotorflight](https://www.rotorflight.org/docs/).
Documented against RFSuite Ethos 2.3.1, All Themes source, 2026-10-02.
