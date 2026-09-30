# Editable theme review in Penpot

The radio theme formerly named Aegis is now Bastion; its legacy source folder is
still `aegis`. On 2026-09-30 the saved Penpot page, all six screens, palette-role
labels, and six shared color assets were renamed to Bastion in place. Reload
verification confirmed the eight native heading/footer text changes. Both
inflight footers moved 16 pixels left to preserve their right alignment; the
remaining screen geometry was preserved.

The boards' `source_sha256` plugin metadata still contains the pre-rename
fingerprints: the configured local Penpot MCP helper was unavailable. Current
Bastion text records and source fingerprints are exported selectively to
`build/bastion-rename/penpot`. Live-edit verification and a screenshot are in
`build/upstream-sync-20260930/penpot-bastion-verification.json` and
`build/upstream-sync-20260930/penpot-bastion-saved.jpg`.

[Open MWRC — Rotorflight Ethos Themes](https://design.penpot.app/#/workspace?team-id=c514c1fb-1cda-8125-8008-a4c2900578e2&file-id=d8ac01df-6646-81d2-8008-a58c5471ce84&page-id=d8ac01df-6646-81d2-8008-a58c5471ce85).

The design file contains a Design System page and individual pages for Bastion, America 250, Liberty Ops 250, MWRC, Singularity, Zafira, and Vantage. Each theme has preflight, inflight, and postflight boards at 800 × 480 and 784 × 294: 42 screen boards in total. Geometry and text are editable, with a shared library of 42 theme colors.

At the original 2026-09-16 review, after reloading the saved file, all 42 boards were checked against their then-current Lua source fingerprints. All 1,066 native text layers were present and none extended beyond its screen board. That historical verification record is `build/theme-design-20260916/penpot-verification.json`; the metadata limitation above applies to the later Bastion rename.

Screens come from the actual Lua dashboard paint callbacks through the desktop LCD fixture. Penpot uses Arimo as an approximation of the fixture's Arial metrics. Values, selected model, connection state, and telemetry are simulated examples. A `Rotorflight 700` label in a board is fixture data; the radio uses its selected model or live craft name.

Board titles and editor page names are not radio content. Full screens begin with the 44px native header, including the centered `Rotorflight // Ethos | MWRC` signature. Compact widgets preserve the suite's header suppression. No additional title strip is included above the header.

## Recreate the design payloads

Using the same Python dependencies as `tests/themes/render_themes.py`:

```text
python tests/themes/export_penpot_review.py --output build/theme-design-20260916
```

The exporter writes PNG previews, vector SVGs, per-theme JSON containing geometry and native-text records, and `index.json` with source SHA-256 fingerprints. SVG geometry can be imported as editable shapes; the text records become native Penpot text so labels remain directly editable. The SHA-256 fingerprint is also saved on each screen board as `source_sha256` plugin data.

Align the imported SVG's `base-background` rectangle to the screen origin, then clip the parent board. Do not align the whole geometry group's bounding box: Zafira deliberately draws diagonal lines outside the viewport. Native text uses screen-relative coordinates independently of those decorative bounds. Use a nonempty layer name for separator-only text, since Penpot normalizes slashes in layer names.

`DESIGN.md` describes the runtime conventions and theme palette roles. `.impeccable/design.json` provides the DesignSystem sidecar. The separate [design audit](theme-design-review-20260916.md) records visual corrections and test evidence.

Desktop verification covers the full/compact layouts and both native appearances. This pass does not establish physical-radio font metrics, outdoor readability, or sustained device performance. Vantage remains a standalone theme folder; no upstream picker or suite core was changed.
