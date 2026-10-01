---
title: Themes
sidebar_label: Themes
sidebar_position: 10
---

# Themes

Choose the dashboard appearance for all models or override it for the connected
flight controller. A separate choice can be saved for each flight phase.

## Where to find it

*System* → *Settings* → *Dashboard* → *Themes*

Global controls are available offline while the Suite background task is
running. The **Optional theme for this model** controls are enabled only when
a flight controller is connected and its MCU ID is known. Theme choices that
need a larger screen are hidden; Cinder require at least 784 × 294.

## Settings

| Setting | What it does |
| --- | --- |
| Default theme for all models — Use same theme | When enabled, copies the preflight choice to inflight and postflight and disables those two fields. Enabled by default. |
| Default theme for all models — Preflight Theme | The global theme before flight; also supplies all phases when Use same theme is enabled. Default: Default. |
| Default theme for all models — Inflight Theme | The global theme during flight. Editable when Use same theme is disabled. |
| Default theme for all models — Postflight Theme | The global theme for recorded flight results. Editable when Use same theme is disabled. |
| Optional theme for this model — Use same theme | Copies this model's preflight choice to its other phases. Requires a connected controller with a known MCU ID. |
| Optional theme for this model — Preflight Theme | Overrides the global preflight theme for this controller. Disabled uses the global choice. |
| Optional theme for this model — Inflight Theme | Overrides the global inflight theme when the model's Use same theme is disabled. Disabled uses the global choice. |
| Optional theme for this model — Postflight Theme | Overrides the global postflight theme when the model's Use same theme is disabled. Disabled uses the global choice. |

## Notes

- Save confirms and stores global choices in `SCRIPTS:/rfsuite.user/settings.ini`
  and model overrides in `SCRIPTS:/rfsuite.user/models/<MCU ID>.ini` on the radio.
  It does not write flight-controller EEPROM.
- Cinder are registered in the current Cinder branch source changes.
  The theme provides all three phases and show live numeric headspeed without an RPM
  limit, redline, comparison scale, or RPM threshold setting.
- Use [Dashboard Settings](settings.md) to change a theme's instrument warnings.
  Selecting a per-model theme does not create separate per-model thresholds.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)
- [Cinder](../../../dashboard/cinder.md)

*Documented against RFSuite Ethos 2.3.1, Cinder branch source, 2026-09-30.*
