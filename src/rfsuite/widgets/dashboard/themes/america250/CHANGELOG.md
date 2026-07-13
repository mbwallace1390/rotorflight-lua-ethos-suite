# America 250 changelog

## v1.0

- Initial radio-test build for the FrSky X20 Pro.
- Added Liberty Readiness, Freedom Flight, and Mission Debrief screens.
- Added a 13-star original-colonies ring, shield geometry, patriotic segmented fuel meters, and 1776–2026 anniversary details.
- Added MWRC author watermark to the shared header.
- Added configurable headspeed, BEC, ESC, fuel, and radio-link thresholds.

## v1.2 - Liberty Readiness gradient pass
- Rebuilt the preflight screen with cached red-to-white-to-blue rails.
- Added gradient instrument-card accents, patriotic title treatment, and a tri-color readiness seal.
- Preserved status colors and telemetry warning logic.
- Inflight and postflight remain unchanged for one-screen-at-a-time radio testing.

## v1.3 - Readability and watermark gradient
- Removed the patriotic stripe that crossed the lower portion of the main status text.
- Changed the header MWRC watermark from solid red to a red-to-white-to-blue per-letter gradient.

## v1.4 - Solid MWRC watermark
- Restored the shared-header MWRC watermark to its original solid red treatment.
- Kept the center status stripe removed for improved CHECK/READY readability.

## v1.5 - Thin tricolor title rails
- Replaced the two heavy title gradients with crisp one-pixel red, parchment-white, and blue pinstripes.
- Preserved the existing gradients on cards and gauges.

## v1.6 - Medium gradient title rails
- Replaced the one-pixel tricolor pinstripes with four-pixel smooth red-to-white-to-blue rails.
- Keeps the sharper title framing while making the gradient clearly visible on the radio.

## v1.7 - Freedom Flight inflight redesign
- Added cached red-to-white-to-blue rails throughout the inflight screen.
- Added a patriotic headspeed gauge with 13 tricolor stars and gradient active ticks.
- Refined cards, state badge, meters, timer framing, and footer while preserving warning colors.
- Preflight v1.6 remains unchanged; postflight remains original for the next pass.

## v1.8 - Inflight cleanup
- Rotated the 13-star ring to remove the star touching the top title rail.
- Improved the 1776 / 2026 shield caption size and placement.
- Slimmed the lower gauge gradient accent.
- Raised the consumed-capacity labels for better spacing.
- Lowered the power-load subtitle and separated BEC and link values.

## v1.9 - Preflight cleanup
- Opened the central readiness hierarchy so the main state, anniversary caption, and diagnostic text no longer crowd each other.
- Removed the redundant `+N MORE` warning suffix; the concise status line now carries the total item count.
- Retained all 13 original-colony stars while reducing the two lowest stars to protect the lower status labels.
- Standardized BEC, radio-link, and ESC progress-bar thickness and insets.
- Added a fixed right-aligned value column and more even row spacing in Liberty Profile.
- Raised the footer signature two pixels for cleaner bottom-edge clearance.
- Inflight v1.8 remains unchanged; postflight remains original.

## v2.0 - Mission Debrief postflight redesign
- Rebuilt postflight to match the polished Liberty Readiness and Freedom Flight screens.
- Added four-pixel patriotic title rails, a mission-result summary panel, anniversary shield, and all 13 original-colony stars.
- Reworked the nine flight-stat cards with double borders, cached gradient accents, threshold-aware colors, and compact progress indicators.
- Preserved preflight v1.9 and inflight v1.8 without further changes.

## v2.1 - Preflight signature placement
- Removed MWRC from the preflight commemorative signature.
- Moved the signature into the center Smart Fuel panel below the state bar.

## v2.2 - Font-safe separators
- Replaced unsupported UTF-8 bullet glyphs with small drawn gold separator dots.
- Applied the fix to both the Smart Fuel commemorative line and the 1776 / 2026 shield date.

## v2.3 - Inflight gauge cleanup
- Removed the horizontal patriotic gradient bar from the central headspeed/RPM gauge.
- Preserved all other inflight, preflight, and postflight styling.

## v2.4 - Final radio cleanup
- Replaced the duplicated postflight title status with a static `FLIGHT SUMMARY` label while retaining the live mission grade in the report panel.
- Raised the Mission Debrief footer and reserved additional clearance so the full signature remains visible on the X20 Pro.
- Replaced the remaining inflight and postflight UTF-8 bullet separators with small drawn gold dots for consistent ETHOS font support.
- Added the optimized 70×70 MWRC theme-selector icon to the complete package.

## v2.5 - Postflight telemetry completion
- Preserved the maximum headspeed observed by the inflight screen and used it when RPM is absent from ETHOS sensor statistics.
- Added the standard Rotorflight peak-power fallback using maximum recorded pack voltage multiplied by peak current when a dedicated watts statistic is unavailable.
- Retained the approved v2.4 screen layout, footer placement, and font-safe separators unchanged.

## v2.6 - Reliable postflight headspeed handoff
- Fixed ETHOS RPM statistics that report a numeric `0`, which previously prevented the inflight peak fallback from being used.
- Added a dashboard-level peak-RPM cache that survives the inflight-to-postflight module transition.
- Postflight now selects the greatest valid RPM value from ETHOS statistics, the session cache, and the persistent dashboard cache.


## v2.7 - Aegis telemetry baseline
- Restored the proven Aegis inflight peak-RPM behavior and removed the timer-based reset that could clear MAX RPM during a flight.
- Kept the live inflight peak in a dashboard-level cache for Mission Debrief.
- Changed postflight to resolve that cache during wakeup, preventing an early-preload nil reference.
- Retained all approved America 250 visuals and the peak-power fallback unchanged.
