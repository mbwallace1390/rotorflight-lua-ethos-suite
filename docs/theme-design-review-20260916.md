⚠️ DEGRADED: single-context (team concurrency ceiling; bundled Impeccable engine unavailable; review adapted to native Ethos LCD images and Lua source).

# Theme design review — 16 September 2026

## Scope and method

Reviewed Aegis, America 250, Liberty Ops 250, MWRC, Singularity, Zafira, and Vantage across preflight, inflight, and postflight, plus Theme Bridge. The product mode is **Operate**: telemetry recognition, honest state, and readable numbers take priority over decorative expression. Each theme's existing identity is a constraint, not a defect.

The baseline is commit `2bb13409` and its current-header preview set in `build/header-review/`. All 21 compact screens in `build/polish-before/` were inspected at 784×294. All seven full-size inflight screens were compared in Ethos 26 light appearance; selected full-size dark previews provided comparison. These are desktop renders of the actual Lua engine using substituted fonts, not physical-radio screenshots or an outdoor visibility test.

The installed **UXCritique** and **UIAudit** entry skills and their bundled Impeccable references were read and applied. The UIAudit `context` command and UXCritique `critique-storage slug` / `detect --json` commands were attempted. All failed because engine 0.1.5 was unavailable and its cache directory could not be created. Consequently there is no automated Impeccable detector result, browser overlay, stored critique trend, or claimed detector pass. Existing project instructions, source, and current preview evidence were used through the skills' documented fallback. No PRODUCT.md or DESIGN.md existed when this review began; DesignSystem documentation is a separate workstream.

The critique was conducted in one assessment context, with independent visual corroboration from `theme_refresh` and runtime corroboration from `suite_contract`. This is not the plugin's prescribed isolated dual-agent assessment. Browser/DOM, CSS, ARIA, iOS, and Android criteria were not imposed on Ethos. Native fonts, LCD geometry, cached paint paths, native forms, and the suite's telemetry contract replace those platform-specific checks.

## Prioritized baseline findings

### P1 — Singularity loses header readability under a light native theme

**Evidence:** `build/header-review/singularity-inflight-light26.png` shows the model name, RSSI text/bars, and transmitter-battery indicator as near-black on the theme's dark header. The dark-appearance preview remains readable. All three phase files clone the native palette, while `header_boxes()` replaces the boxes' backgrounds with `C.space` without replacing the corresponding native text/fill colors.

The fixture's foreground `(32,40,52)` on `(3,5,12)` has approximately **1.37:1** luminance contrast. This is a recognition problem for aircraft identity and radio status, not a request to change Singularity's space aesthetic.

**Correction:** give the theme-owned dark header explicit readable text, active-fill, and inactive-fill colors, leaving the suite palette untouched. Verify all three phases in light and dark native appearance. Owner: Polish.

### P2 — MWRC and Liberty Ops gauge layouts exceed their allocated space

**Evidence:** full-size previews show the headspeed MAX footer extending past its gauge panel; compact previews in `build/polish-before/` show the fuel cap/right edge reaching the screen edge and the consumption caption crowded against the lower boundary. Both themes share this layout family. Independent visual review confirmed the same geometry issues.

**Correction:** fit footer text within each gauge, reserve width for the fuel cap, and keep the consumed-capacity caption inside its box. Preserve the three-dial layout, accent palette, and measured values. Owner: Polish.

### P2 — MWRC and Liberty Ops governor captions inherit unreadable light-theme ink

**Evidence:** `build/header-review/mwrc-inflight-light26.png` and `libertyops250-inflight-light26.png` show a nearly invisible GOV caption beneath a readable governor state. The native governor boxes supply state colors but omit an explicit title color over the dark theme surface. Approximate fixture contrast is **1.26:1** for MWRC and **1.28:1** for Liberty Ops.

**Correction:** assign theme-owned title colors to these native objects and check similar native titles. Owner: Polish.

### P2 — America 250's crimson status text has insufficient contrast

**Evidence:** `drawStateBadge()` uses the state color for its small text. The theme's `C.red=(184,48,49)` on `C.panel2=(12,34,61)` gives **2.67:1**, visible in the ARMED / ACTIVE badge in both full and compact inflight previews. Small status text needs stronger separation than a decorative flag stripe.

**Correction:** retain crimson in flags, borders, and decoration while using a brighter semantic red or light text for the status label. The measured 4.5:1 small-text benchmark is a design check here, not a claim of comprehensive WCAG certification for the radio. Owner: Polish.

### P2 — Singularity's “SYSTEM INTEGRITY” percentage implies an unmeasured health quantity

**Evidence:** `postflight.lua` computes an integrity value from formulas such as `100 - cautions * 10` and `55 - faults * 20 - cautions * 8`, with a 100% result when recorded data exists and no checked limit is exceeded. The compact baseline displays **70% SYSTEM INTEGRITY**. It is not a recorded telemetry percentage and does not express how much of the aircraft was actually observed.

**Correction:** retain the orbital composition but display the actual flagged-item count and a recorded-data review state. Missing history must remain distinct from zero flagged items. Do not imply flightworthiness or invent a replacement quality score. The parent accepted this correction. Owner: Polish/HardenUI.

## Coverage by theme

| Theme | Preflight | Inflight | Postflight |
|---|---|---|---|
| Aegis | Clear status and instrument groups | Headspeed is dominant; no standard-fixture compact collision found | Clear min/peak labels; compact cards fit |
| America 250 | Patriotic identity retained; compact columns fit | Status contrast finding above | Dense but fitting summary; decorative 250 remains brand content |
| Liberty Ops 250 | Compact instrument grid fits | Gauge/fuel geometry and GOV-title findings above | Recorded-stat grid fits standard fixture |
| MWRC | Dials fit; absent model bitmap leaves a large empty area | Gauge/fuel geometry and GOV-title findings above | Recorded-stat grid fits standard fixture |
| Singularity | Space composition readable; light-native header finding | Clear headspeed priority; light-native header finding | Synthetic integrity finding; light-native header finding |
| Zafira | Jewel identity and values remain readable | Distinct decoration does not collide with standard readings | Compact report grid fits |
| Vantage | Required telemetry count and partial-state language are clear | Primary RPM and secondary power/thermal values are separated | Actual duration, peaks, averages, and minima have clear labels |

The empty model area in MWRC preflight is a lower-priority observation when no bitmap is available. It is not treated as a required new feature. Likewise, the decorative stars, jewels, patriotic borders, and space terminology are intentional identities rather than generic defects to remove.

## Theme Bridge and technical findings

Bridge painting consumes prepared palette/geometry data; metadata/settings work belongs to throttled wakeup. Close paths unsubscribe retained-bus listeners and clear owned caches. Native input controls remain native. These are good patterns to preserve. Static inspection is not a measured radio CPU or memory benchmark.

Vantage's installed files can be rendered directly, but the current standard dashboard/settings registration lists do not include it. Bridge mirrors that availability and falls back to Default. This is an existing integration limitation from the earlier new-folder-only scope, not permission to add suite-core registrations during this review.

**P2 — malformed optional colors can reach drawing and invalidate the palette cache.** HardenUI reproduced two baseline failures: non-finite custom RGB/native-color values could survive palette construction, and non-finite native colors could poison the appearance signature (`table index is NaN`). A validated finite-channel boundary now falls back for invalid colors and clamps valid RGB channels to 0–255 during palette compilation. This preserves cached painting and avoids adding validation work to every draw call. The two regression tests failed before the correction; all ten Bridge tests pass afterward. Evidence: `tests/theme_bridge/test_theme_bridge.py`, particularly `test_invalid_metadata_colors_fall_back_before_drawing` and `test_invalid_native_colors_do_not_poison_signature_or_palette`.

**P2 — Liberty Ops' Bridge accent is too dark for small titles.** Its baseline metadata accent `(42,111,214)` measures 4.22:1 against the background and 3.94:1 against the alternate surface. Bridge uses the accent as title ink, making this an actual use of the low-contrast pair. The accent now uses `(64,145,255)`, the phase palette's existing brighter blue, with a regression for its small-title contrast. HardenUI also identified below-benchmark error/muted metadata pairs in America 250, MWRC, and Zafira. They remain unchanged because no actual Bridge paint use was found for these roles; an unused metadata role is not itself evidence of a visible rendering defect. Owners: HardenUI/Polish.

**P2 — long model names escape the header.** A baseline probe with a 32-character `W` name overflowed in all seven themes: the measured title width was 1,920 px at a 64 px font, with its top at −10 px. This is a theme-owned header sizing problem. The correction fits and, when necessary, truncates whole UTF-8 characters within the existing aircraft-name slot, while caching the result until the name or width changes. A narrow-width probe validates the header only; it does not claim the entire theme supports a radio below its declared minimum resolution.

**P2 — unrepresentable numeric values can break rendering.** A deliberately corrupt `1e100` timer crashed ten custom phase views and MWRC/Liberty's native postflight summaries. A huge MWRC preflight reading also generated text wider than the screen. These are resilience defects under corrupted input, not normal-flight data failures. Corrections reject unrepresentable values and display unavailable markers, while preserving valid zero values and the established recorded-stat fallback. HardenUI owns the final regressions.

## Baseline assessment

These scores are an explicit prioritization rubric for the reviewed surfaces, not radio certification. They describe the before-images; corrections are tracked separately.

| UX heuristic | Score / 4 | Evidence |
|---|---:|---|
| Visibility of system status | 3 | Phase, timer, state, and unavailable readings are visible; radio indicators fail in one appearance |
| Match with the real world | 2 | Units/min/max labels are useful; integrity percentage overstates the measured data |
| User control and freedom | n/a | Read-only phase screens; configurator interaction is outside this visual sample |
| Consistency and standards | 2 | Native palette inheritance conflicts with some forced dark surfaces |
| Error prevention | 3 | Missing-data states exist; derived health language needs correction |
| Recognition rather than recall | 3 | Stable instrument placement and labeled values; small status contrast needs work |
| Flexibility and efficiency | 3 | Theme-specific thresholds and full/compact layouts support different use |
| Aesthetic and minimalist design | 3 | Seven intentional identities; primary numbers generally dominate |
| Error recognition and recovery | 3 | Connection/partial-data language exists; flagged findings need honest summaries |
| Help and documentation | 2 | Labels provide context; accepted shared conventions were not yet documented |
| **Total** | **24 / 36** | **Acceptable baseline; address the listed issues** |

| Technical dimension | Score / 4 | Basis and limit |
|---|---:|---|
| Readability/accessibility | 2 | Measured contrast failures; no physical-radio outdoor test |
| Runtime/performance discipline | 3 | Cached values/geometry and separated I/O; no measured hardware budget |
| Appearance/theming | 2 | Shared native palette remains isolated, but some foregrounds mismatch dark surfaces |
| Ethos platform conformity | 3 | Native drawing/fonts/forms and suite facade respected |
| Resolution adaptation | 2 | Both sizes covered; confirmed narrow-card and edge crowding |
| **Total** | **12 / 20** | **Acceptable baseline; focused corrections required** |

Persona checks focused on the expert reading telemetry quickly, a pilot reading under reduced visual contrast, and a methodical user encountering missing or extreme values. Their concrete risks are obscured model/radio indicators, small low-contrast state text, clipped gauges, and an apparently measured health score. No claim was made about screen-reader support, touch-target dimensions, or browser keyboard behavior on this LCD-only evidence.

## Correction verification

One focused confirmation pass rendered and visually inspected six corrected views. `build/polish-audit-after/results.json` records six successful renders with no text-boundary overflow:

| Corrected view | Confirmed result |
|---|---|
| Singularity inflight, 800×480, native light | Model name and radio indicators remain readable on the dark header |
| Singularity postflight, 784×294 light and 800×480 dark | The fixture displays **3 FLAGS RECORDED**, with **9/10 SIGNALS RECORDED** in the full layout, replacing the synthetic integrity percentage |
| MWRC inflight, 784×294, native light | MAX footer, fuel cap, and mAh caption fit; GOV caption is visible |
| Liberty Ops inflight, 784×294, native light | The same geometry/caption corrections retain the navy/blue/gold identity |
| America 250 inflight, 784×294, native light | State badge uses brighter readable red while flag crimson remains decorative |

Source review confirms the explicit Singularity header palette is applied in all three phases. Its missing-history branch leaves the flagged count unavailable; partial history is distinguished from a complete debrief, and zero flagged items is not presented as flightworthiness certification.

HardenUI completed **19 theme test methods**: the combined 18-method run (12 existing contract methods and six hardening methods) passed, followed by a new focused missing-history regression. Coverage includes 42 long-name/UTF-8 header cases plus rename refresh, 21 live extreme-value views, seven corrupt-history views, 14 stale-source/valid-zero views, 14 connection-loss/reconnect views, and MWRC/Liberty summary formatting/cache/history behavior. A final focused summary rerun passed for both themes after preserving retained last-flight duration ahead of older persisted history. All **ten Bridge tests** also pass, including the two failing-before malformed-color cases and Liberty title contrast.

The final independent review caught and corrected a MWRC preflight regression: offline absence of flight history was displayed as `0` flights. It now displays `--`, preserving the distinction between unavailable history and a valid connected zero count. `test_preflight_flight_count_distinguishes_missing_history_from_zero` failed with the guard removed and passes with the correction; summary-retention behavior was also rechecked. This correction preserves preflight availability rules while keeping postflight history readable.

The stale-source checks specifically show 47°C becoming unavailable when stale and returning as a valid 0°C; the connection checks hide the previous 62°C reading and refresh to 63°C after reconnect. Postflight regressions preserve recorded summaries during disconnection, cold-start history, valid zero, and reconnect. These are actual desktop Lua-engine regressions, not only source-pattern checks.

Polish regenerated the complete final matrix in `build/theme-design-20260916/validation/`: **84/84** connected cases passed across seven themes, three phases, two sizes, and two native appearances. Its intact `results.json` has 84 entries, with 84 PNGs alongside it and no text-boundary overflow. Following the final MWRC preflight correction, its four affected size/appearance entries and images were refreshed in that intact matrix. An additional **8/8** connected/offline cases passed in `build/theme-design-20260916/mwrc-refresh/validation/results.json`. This is the authoritative final preview evidence; it supersedes the earlier `build/polish-after/` report overwritten by a focused rerun. The separate six-case audit JSON above also remains complete. Packaging/deployment are outside this design audit.

DesignSystem has since created root `DESIGN.md` from the incumbent design and user constraints. The parent also connected Penpot and verified editable text/vector output from the actual renderer; its full design-file handoff is documented separately in `docs/theme-penpot-review.md`. Those coordinated deliverables are separate from the unavailable Impeccable detector; the report does not equate an exported design board with hardware acceptance.

No confirmed finding from this review remains awaiting a correction. Physical-radio font metrics, outdoor visibility, and sustained hardware performance remain untested in this desktop design pass. Vantage's standard-picker availability remains intentionally unchanged.

## Workflow provenance

Installed skill sources (version 2.0.0):

- `C:/Users/mmlwa/.codex/plugins/cache/openai-curated-remote/engineering-suite-ux-critique/2.0.0/skills/entry-ux-critique/SKILL.md`
- `C:/Users/mmlwa/.codex/plugins/cache/openai-curated-remote/engineering-suite-ux-critique/2.0.0/skills/impeccable/reference/critique.md`
- `C:/Users/mmlwa/.codex/plugins/cache/openai-curated-remote/engineering-suite-ui-audit/2.0.0/skills/entry-ui-audit/SKILL.md`
- `C:/Users/mmlwa/.codex/plugins/cache/openai-curated-remote/engineering-suite-ui-audit/2.0.0/skills/impeccable/SKILL.md`
- `C:/Users/mmlwa/.codex/plugins/cache/openai-curated-remote/engineering-suite-ui-audit/2.0.0/skills/impeccable/reference/audit.md`
- `C:/Users/mmlwa/.codex/plugins/cache/openai-curated-remote/engineering-suite-ui-audit/2.0.0/skills/impeccable/reference/audit.native.md`

Recommended action order: HardenUI for truthful/error states, Polish for the scoped contrast/geometry corrections, then one confirmation audit. Penpot and DesignSystem are separate coordinated workstreams. No theme source, suite core, radio files, or deployment was changed by this review.

Questions skipped: the user already authorized these workflows and the parent assigned the correction scope; there is no remaining design decision requiring a pause.
