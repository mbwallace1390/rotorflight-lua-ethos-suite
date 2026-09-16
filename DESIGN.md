---
name: MWRC Rotorflight Ethos themes
description: Distinct flight instruments with shared readable radio conventions.
colors:
  aegis-background: "#070B10"
  aegis-surface: "#0E151D"
  aegis-text: "#E6EFF7"
  aegis-muted: "#8497A8"
  aegis-accent: "#30DAEE"
  aegis-warning: "#FFB748"
  aegis-error: "#FF5667"
  america250-background: "#040E1F"
  america250-surface: "#08182F"
  america250-text: "#F0E7CF"
  america250-muted: "#A0AEBB"
  america250-accent: "#F0E7CF"
  america250-warning: "#D8AA4E"
  america250-error: "#B83031"
  libertyops250-background: "#02050A"
  libertyops250-surface: "#050A12"
  libertyops250-text: "#EEF3FC"
  libertyops250-muted: "#8A99AF"
  libertyops250-accent: "#4091FF"
  libertyops250-warning: "#FFA72D"
  libertyops250-error: "#E33A42"
  mwrc-background: "#05080E"
  mwrc-surface: "#0C121C"
  mwrc-text: "#E6F0FF"
  mwrc-muted: "#788EA4"
  mwrc-accent: "#00F0FF"
  mwrc-warning: "#FFAA00"
  mwrc-error: "#FF003C"
  singularity-background: "#03050C"
  singularity-surface: "#0D1122"
  singularity-text: "#E4F0FF"
  singularity-muted: "#9DB2D0"
  singularity-accent: "#AA61FF"
  singularity-warning: "#FFBE46"
  singularity-error: "#FF486E"
  zafira-background: "#140F1E"
  zafira-surface: "#251B33"
  zafira-text: "#F6EFFF"
  zafira-muted: "#BEA6C7"
  zafira-accent: "#FFC75B"
  zafira-warning: "#FFA63E"
  zafira-error: "#FF4A60"
  vantage-background: "#080E14"
  vantage-surface: "#111B24"
  vantage-text: "#E7F2F6"
  vantage-muted: "#829CAA"
  vantage-accent: "#89DCF1"
  vantage-warning: "#F5B95E"
  vantage-error: "#FF6970"
spacing:
  header-signature-gap: "8px"
  panel-inset: "12px"
components:
  native-header:
    height: "44px"
---
# Design System: MWRC Rotorflight Ethos Themes

## Overview

These are operational flight dashboards for an Ethos transmitter. Preserve the seven existing identities while making model, flight state, power, link, temperature, and recorded results easy to distinguish at a glance. The visual reference is the implemented Lua and its rendered screens; design boards are editable desktop approximations, not photographs of a radio.

The user's constraints govern the shared design: the whole `Rotorflight // Ethos | MWRC` group is centered, the title is readable, and the MWRC signature stays smaller and subdued. No theme title or artwork belongs above the native battery/signal row. The selected model remains live data. This document applies to custom themes and Theme Bridge only; it does not redefine the upstream suite.

## Colors

The frontmatter extracts the persisted `appTheme` roles from each theme's `init.lua`, which Theme Bridge consumes. Phase files may add specialized gauge and status ink. Preserve those explicit phase roles instead of assuming every decorative accent is legible as small text.

| Theme | Existing visual character | Dominant forms |
|---|---|---|
| Aegis | Graphite, cyan, green, restrained violet | Shield, clean rectangular instruments |
| America 250 | Navy, parchment, commemorative red and blue | Instrument panels and patriotic detail |
| Liberty Ops 250 | Dark cockpit, blue, flag red, green | Arc gauges and flag detail |
| MWRC | Near-black, electric cyan, lime, violet | Arc gauges and segmented fuel |
| Singularity | Deep space, violet, ice cyan | Orbital instruments and radial detail |
| Zafira | Aubergine, gold, turquoise | Faceted and gem-like instruments |
| Vantage | Blue-black, ice blue, mint, warm amber | Flight-deck dial and structured report rows |

Keep small status text readable against its actual fill in legacy dark, native dark, and native light modes. A 4.5:1 text contrast check is a useful desktop review floor; large text may use 3:1. Decorative outlines do not need text contrast. Do not use color as the only indication of warning or missing data. Prefer a separate readable status ink over changing an entire theme palette.

## Typography

Runtime typography uses Ethos `FONT_*` constants and `lcd.getTextSize()`. There is no downloadable font dependency. Fit the measured glyphs in the available geometry; do not treat the desktop font sizes as firmware guarantees.

| Role | Runtime convention |
|---|---|
| Main header | Prefer `FONT_L`, then fit down as width requires |
| MWRC signature | `FONT_XS`, subordinate to the title; `FONT_XXS` only on a smaller fitted header |
| Primary measurement | The largest native font that fits value and unit |
| Instrument label | `FONT_XS` or `FONT_S` where room permits |
| Secondary annotation | `FONT_XXS`; never use this as a substitute for a readable primary reading |
| Model name | Dynamic, measured within its own slot; shorten the displayed label only when necessary |

Penpot uses Arimo, a desktop approximation of the Arial-based LCD test fixture. Text remains editable. Firmware glyph metrics and radio legibility still require device acceptance.

## Layout

The full-screen target is 800 × 480. The compact widget target is 784 × 294; the suite's compact view intentionally suppresses the native header. Keep those layouts structurally distinct.

On full screen, the theme-owned native header is 44px high and starts at y=0. The seven-column header keeps the model in columns 1–2, the combined title/signature in 3–5, battery in 6, and signal in 7. Center the combined measured title and signature against the actual viewport midpoint, not the rounded grid-slot midpoint. Keep an 8px gap before the smaller signature. Body geometry begins below that row.

Use the existing per-theme instrument layouts. Measured values and units must fit their own panel and leave room for labels and extrema. Where an unused column causes a crowded neighboring readout, reclaim that existing space rather than shrink all typography. Group related readings with consistent insets; 12px is a recurring panel inset in the custom themes.

Penpot has a page per theme with full-screen and compact boards for all three phases. Board names are editor metadata. They are not part of the radio display.

## Elevation & Depth

The radio themes use flat surfaces, tonal separation, fine rules, and their existing ornamental gauge geometry. Depth comes from contrast and placement. Avoid adding browser-style blur, animated shadows, or expensive effects to paint callbacks.

## Shapes

Preserve each theme's silhouette: Aegis shields, MWRC/Liberty arcs, Singularity orbits, Zafira facets, and Vantage's large dial. Rectangular information regions provide stable reading anchors. Decoration must stay behind clear numeric values and status labels.

## Components

### Native header

Model, centered branding, battery, and signal share the top row. They remain readable independently of the transmitter's system palette. Truncation affects only displayed model text, not telemetry or model identity. Reuse fitted text measurements until geometry or displayed data changes.

### Live instruments

Show a value with its actual unit and label. Keep minimum/maximum annotations in their instrument region. Missing or unusable readings use an explicit placeholder. Zero is valid data where the sensor contract permits it. Unrepresentable values must not be formatted as plausible zero readings.

### Preflight summary

Status depends on required readings and configured thresholds. Missing readings remain visibly incomplete. A readiness label represents telemetry checks, not a general guarantee that an aircraft is safe to fly.

### Postflight report

Use recorded measurements, units, and extrema. Label derived summaries honestly. Do not present an arbitrary penalty score as measured aircraft integrity. Missing history is distinct from a flight with no flagged readings.

### Theme Bridge

Apply the selected theme's metadata to suite app surfaces without changing upstream UI behavior. Invalid or unavailable color metadata falls back to valid native values. Resolve palette and geometry outside hot paint paths. Vantage remains a folder-only theme under the existing user decision; this visual pass does not change the suite's theme picker registration.

## Do's and Don'ts

- Do preserve each theme's color and instrument identity.
- Do keep every radio drawing at or below its native header origin.
- Do distinguish live readings, recorded history, missing values, and derived status.
- Do verify 800 × 480 and 784 × 294 with legacy dark, native dark, and native light fixtures.
- Do cache text, geometry, images, and palette choices when their inputs are unchanged.
- Don't add a second title row above the battery/signal header.
- Don't replace the selected model with a hardcoded demonstration name.
- Don't translate CSS or web effects into heavyweight Lua paint work.
- Don't interpret Penpot or desktop rendering as physical-radio acceptance.
