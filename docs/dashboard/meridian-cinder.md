# Meridian and Cinder

Two dashboard themes developed from the selected MWRC concept previews.
Each provides preflight, inflight, and postflight layouts for an 800 × 480
full screen and a 784 × 294 compact widget.

Meridian uses an open headspeed field between vertical fuel and ESC-temperature
instruments, with ice-cyan outlines and mint fuel. Cinder uses warm copper
outlines, a large headspeed/timer panel, and stacked fuel, ESC temperature,
current, and pack-voltage instruments.

The full-screen header begins at the top edge. The complete
`Rotorflight // Ethos | MWRC` group is centered, with a smaller MWRC signature.
The model name comes from the active Suite/radio context. Compact widgets omit
the native header. Inflight RPM is a live number with no fixed maximum, redline,
limit label, or RPM-limit setting.

## Availability

Source folders:

- `src/rfsuite/widgets/dashboard/themes/meridian/`
- `src/rfsuite/widgets/dashboard/themes/cinder/`

The current `radio-all-themes` source changes include both registrations.
Choose a theme under **System → Settings → Dashboard → Themes**, then adjust
its warnings under **System → Settings → Dashboard → Settings**. Both themes
are hidden from these choices when the available window is below 784 × 294.

The loader, accepted settings IDs, selection list, and configuration grid each
receive one registration entry per theme. The All Themes build also includes
the corresponding Theme Bridge metadata entries, allowing an enabled Bridge
to follow the chosen theme. Each separate theme branch needs only its own
folder and those four standard registrations. Its `appTheme` palette metadata
is available to a compatible optional Bridge; Bridge is not a theme dependency.

This work targets `radio-all-themes` and the two separate theme branches;
`main` and `master` are unchanged. Registration is included in the source
changes; publication and radio installation are separate steps.

Global theme choices are available offline while the Suite background task is
running. The optional model override requires a connected flight controller
with a known MCU ID. **Use same theme** applies the preflight choice to all
three phases; otherwise each phase can use its own choice. A disabled model
override uses the global choice.

Save stores global selections and theme thresholds in
`SCRIPTS:/rfsuite.user/settings.ini`; model selections go into the radio's
per-controller model preference file. These changes do not write FC EEPROM.
Thresholds belong to the selected theme, not to the per-model theme override.

See [Meridian](meridian.md), [Cinder](cinder.md),
[theme selection](../pages/settings/dashboard/theme.md), and
[theme settings](../pages/settings/dashboard/settings.md) for individual controls.

## Screens

Preflight distinguishes missing readings, connection state, and configured
telemetry warnings. A ready indication describes the displayed telemetry checks;
it is not a general aircraft safety assessment. Missing or stale live readings
use placeholders, and valid zero readings remain valid.

Inflight prioritizes headspeed and operating measurements. Fuel, BEC, ESC
temperature, and link warnings use each theme's own saved settings. Temperature
display respects Celsius/Fahrenheit while stored thresholds remain Celsius.

Postflight explicitly shows recorded results and retained flight duration.
Current model data must not substitute for missing historical samples. Changing
models clears retained results from the previous aircraft.

## Desktop verification and preview

Use Python with Pillow and Lupa:

```text
python -m unittest discover -s tests/themes -p test_meridian.py
python -m unittest discover -s tests/themes -p test_cinder.py
python tests/themes/build_meridian_cinder_preview.py --render
```

The preview gallery is `artifacts/meridian-cinder/preview-gallery.html`.
The renderer checks both sizes, all phases, dark/light appearance, and connected,
offline, missing-data, and warning cases. Preview fonts are desktop approximations.
Actual-radio font fitting, sensor transitions, instruction budget, and repeated
theme/phase changes still require device acceptance.

After the latest upstream merge and registration, all 90 theme tests and all
144 render cases passed. See `artifacts/meridian-cinder/validation.md` for the
evidence scope and remaining physical-radio checks.

Documented against the current `radio-all-themes` source of RFSuite Ethos 2.3.1
on 2026-09-30. Related flight-controller documentation:
[Rotorflight](https://www.rotorflight.org/docs/).
