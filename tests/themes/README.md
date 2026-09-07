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
python tests/themes/build_review_bundle.py
python tests/themes/build_vantage_preview.py
```

The default renderer covers six themes × three phases × two sizes × four data
scenarios × three appearance modes (432 cases). The separate Vantage matrix adds
72 cases. Behavioral tests cover settings, temperature units, invalid/missing
telemetry, historical cell voltage, consistent link sources, model-name changes,
small MWRC signatures, and cache reuse. Bridge tests exercise shared snapshot
ownership, flight-phase continuity, resize behavior, and cleanup.

The six-theme bundle includes only those six theme directories and Theme Bridge.
Vantage remains a separate source folder; no suite-core registration changes are
included. Preview galleries and ZIPs are generated deliverables under `artifacts`.
