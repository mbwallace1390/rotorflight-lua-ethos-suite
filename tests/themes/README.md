# Desktop theme checks

These fixtures run the actual suite engine/context and Lua theme modules with
simulated radio sources. They check behavior and render deterministic previews;
they do not replace real-radio testing.

Requirements: Python, Pillow, and Lupa (`python -m pip install Pillow lupa`). The
optional `build/test-deps` directory can hold isolated local dependencies. The
preview renderer currently uses Windows Arial at `C:/Windows/Fonts/arial.ttf`;
its font metrics approximate the radio's native fonts.

Run from the repository root:

```powershell
python -m unittest discover -s tests/themes -p "test_*.py" -v
python -m unittest discover -s tests/theme_bridge -v
python tests/themes/render_themes.py --modes dark16 dark26 light26
python tests/themes/render_themes.py --themes vantage --modes dark16 dark26 light26 --output artifacts/vantage/renders
python tests/themes/render_themes.py --themes inkhalo --modes dark16 dark26 light26 --output artifacts/inkhalo/renders
python tests/themes/build_vantage_preview.py
python tests/themes/build_meridian_cinder_preview.py
```

The default renderer covers eight themes × three phases × two sizes × four data
scenarios × three appearance modes (576 cases), including Vantage and Ink & Halo.
Behavioral tests cover settings, temperature units, invalid/missing
telemetry, historical cell voltage, consistent link sources, model-name changes,
small MWRC signatures, and cache reuse. Bridge tests exercise shared snapshot
ownership, flight-phase continuity, resize behavior, and cleanup.

Meridian and Cinder have dedicated behavior/registration checks and a separate
144-case render matrix, bringing the ten-theme matrix to 720 cases. Discovery
checks cover all ten personal themes and system/user folder separation. The
localization fixtures use the actual package resolver and locale files, including
Lua string escaping. Missing labels cannot be hidden by fixture-only replacement.

The normal Suite package builder includes the installed themes and resolves their
locale tags. For individual upstream submissions, follow
[the theme submission standard](../../docs/theme-submissions.md), include only
the theme being submitted, and run its own registration tests and three phase
previews. The private Theme Studio repository enforces the future authoring
checklist and keeps portable ten-theme behavior/render tools. Main/master and
Bridge implementation are outside theme submission work.
