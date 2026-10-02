---
title: Settings
sidebar_label: Settings
sidebar_position: 20
---

# Settings

Open a theme's instrument settings from its tile. These settings control the
dashboard's warning presentation; the active theme is selected separately on
the [Themes](theme.md) page.

## Where to find it

*System* → *Settings* → *Dashboard* → *Settings*

Available offline while the Suite background task is running. A theme tile
appears only if the installed theme is discovered, its metadata identifies a
present configuration module, and the available window meets its minimum size.
Meridian and Cinder require at least 784 × 294. A theme without configuration
controls can still appear on the Themes page.

## Settings

The controls depend on the selected theme. Meridian and Cinder provide:

| Setting | What it does |
| --- | --- |
| BEC critical | Flags BEC voltage below this value. Range: 2.0–14.8 V; default: 6.5 V. Kept below the caution threshold. |
| BEC caution below | Cautions below this voltage; remains at least 0.1 V above BEC critical. Default: 7.0 V; upper bound: 15.0 V. |
| Fuel warning | Flags remaining fuel at or below this percentage. Range: 1–99%; default: 25%. |
| ESC warning | Cautions at or above this temperature. Default: 110°C / 230°F; kept below ESC maximum. |
| ESC maximum | Flags this temperature and above. Meridian default: 120°C / 248°F; Cinder default: 150°C / 302°F. Upper bound: 200°C / 392°F. |
| Link warning | Cautions when the valid percentage link reading falls below this threshold. Range: 1–99%; default: 50%. |

## Notes

- This All Themes build discovers system themes under
  `SCRIPTS:/rfsuite/widgets/dashboard/themes/` and user themes under
  `SCRIPTS:/rfsuite.user/dashboard/`. User tiles are marked **(User)**; same-name
  system and user themes keep separate settings. Keep the supplied theme's
  folder and helper paths intact.
- Fully restart the radio or Suite Lua session after adding, updating or removing
  a theme. The installed-theme catalog is cached; reopening the page alone does
  not rescan the folders. The [Themes page](theme.md) explains installation and
  selection.
- Save writes the selected theme's values into its own section in
  `SCRIPTS:/rfsuite.user/settings.ini` on the radio. These settings are shared by
  models using that theme; they do not write flight-controller EEPROM or change
  the FC's protection limits.
- Bastion's source folder is now `bastion`, while its saved thresholds remain in
  `dashboard.aegis`. Installing the matching current branch preserves those
  values and the legacy theme selection; no settings migration is required.
- Reload discards unsaved form edits and restores the values loaded for the page
  or last saved during this visit.
- Temperature fields follow the unit selected in **System → Settings → General**.
  Stored thresholds remain Celsius, so switching units does not reinterpret the
  saved temperature.
- Meridian and Cinder have no RPM threshold or redline setting. Headspeed is a
  live numeric readout. Missing telemetry stays unavailable; completing the
  displayed preflight checks is not an aircraft safety certification.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)
- [Meridian](../../../dashboard/meridian.md)
- [Cinder](../../../dashboard/cinder.md)

*Documented against RFSuite Ethos 2.3.1, All Themes source, 2026-10-02.*

If a discovered configuration module fails to load or build its form, the theme grid stays available and shows **Loading failed**. No settings are saved by that failed open.
