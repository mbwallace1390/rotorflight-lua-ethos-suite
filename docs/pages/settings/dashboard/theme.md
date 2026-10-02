---
title: Themes
sidebar_label: Themes
sidebar_position: 10
---

# Themes

Choose the dashboard appearance for all models or override it for the connected
flight controller. A separate choice can be saved for each flight phase. In
the All Themes build, compatible installed folders appear automatically.

## Where to find it

*System* → *Settings* → *Dashboard* → *Themes*

Global controls are available offline while the Suite background task is
running. The **Optional theme for this model** controls are enabled only when
a flight controller is connected and its MCU ID is known. Theme choices that
need a larger screen are hidden. All ten MWRC themes require at least 784 × 294;
480 × 320 and 472 × 191 windows hide them.
System and user folders are separate choices. User themes are marked **(User)**
and do not replace same-name system themes automatically.

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

- Packaged custom theme names use the Suite's locale catalog, including proper
  names that stay unchanged across languages. Existing selections and warning
  sections are preserved.

- Install the complete All Themes package with folder discovery once. Then copy
  each complete theme folder into its supported location:
  `SCRIPTS:/rfsuite/widgets/dashboard/themes/<folder>/` for system themes, or
  `SCRIPTS:/rfsuite.user/dashboard/<folder>/` for location-compatible user themes.
  Fully restart the radio or Suite Lua session after adding, updating or removing
  a folder, then choose the theme and Save. Reopening this page alone does not
  refresh the catalog. See the [theme installation guide](../../../dashboard-themes.md).
- A folder needs valid metadata and the phase modules it references. Invalid
  entries are omitted. Discovery does not prove that a theme's rendering code
  works on the radio; use themes compatible with this Suite version and screen.
- If a selected theme is missing, the dashboard renders Default. The stored
  selection is retained until changed, so restoring the folder and restarting
  can restore the theme.
- Save confirms and stores global choices in `SCRIPTS:/rfsuite.user/settings.ini`
  and model overrides in `SCRIPTS:/rfsuite.user/models/<MCU ID>.ini` on the radio.
  It does not write flight-controller EEPROM.
- Meridian and Cinder are included in the All Themes package.
  Both provide all three phases and show live numeric headspeed without an RPM
  limit, redline, comparison scale, or RPM threshold setting.
- Use [Dashboard Settings](settings.md) to change a theme's instrument warnings.
  Selecting a per-model theme does not create separate per-model thresholds.

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)
- [Meridian](../../../dashboard/meridian.md)
- [Cinder](../../../dashboard/cinder.md)

- [Bastion](../../../dashboard/bastion.md)

- [America 250](../../../dashboard/america250.md)

- [Liberty Ops 250](../../../dashboard/libertyops250.md)

- [MWRC](../../../dashboard/mwrc.md)

- [Singularity](../../../dashboard/singularity.md)

- [Zafira](../../../dashboard/zafira.md)

- [Vantage](../../../dashboard/vantage.md)

- [Ink & Halo](../../../dashboard/inkhalo.md)

*Documented against RFSuite Ethos 2.3.1, All Themes source, 2026-10-02.*
