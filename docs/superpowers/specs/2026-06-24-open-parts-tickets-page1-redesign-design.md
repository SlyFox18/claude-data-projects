# Open Parts Tickets — Page 1 (Overview) Redesign — Design Spec

**Date:** 2026-06-24
**Report:** Open Parts Tickets
**Requested by:** Stakeholder (via Brian), modeled after the Open Work Orders - WIP Report layout
**Status:** Approved — ready for implementation

---

## Problem

Page 1 ("Overview") currently renders as **one large HTML measure** (`HTML - Parts Overview Dashboard`) stacking 4 full-width aging sections vertically (90+, 61-90, 31-60, 15-30, with 8-14 and 0-7 below the fold). Each section repeats the same 4-metric grid (Order Total, # Parts On Order, Parts Line Count, Total # of Orders), each with its own Not-Backordered-vs-Backordered bar. This means:

- No top-line/rolled-up summary — you have to scan all 6 sections to get the big picture
- Heavy vertical scrolling, ~24 metric tiles total across 6 sections
- No way to focus on a single aging tier without scrolling to find it

The stakeholder saw the Open Work Orders - WIP Report (hero totals row + compact horizontal aging-bucket cards + a chart below) and wants Page 1 redesigned in that spirit — but **not a literal copy**: the WIP report's bottom chart is a branch breakdown, which would be redundant here since Page 3 ("Comparison") already covers branch-level comparison for this report.

---

## Solution

Three stacked sections replacing today's single HTML dashboard, plus a click-to-filter interaction tying the bottom two sections to the aging row:

1. **Hero row** — 3 rolled-up totals (Order Total, # Parts On Order, Parts Line Count), responsive to aging-tier selection
2. **Aging card row** — 6 compact cards (0-7, 8-14, 15-30, 31-60, 61-90, 90+ days), each showing its own tier's Total # of Orders. Clickable.
3. **Backorder Pulse** — 4 wide Not-Backordered-vs-Backordered bars (Order Total, # Parts On Order, Parts Line Count, Total # of Orders), also responsive to aging-tier selection

Default state (nothing selected): Hero and Pulse show **all-tiers rolled up** totals. Clicking an aging card filters Hero and Pulse to that tier; clicking the same card again (or anywhere else that clears the slicer) returns to the rolled-up view. The aging cards themselves never visually change — each is hardcoded to its own bucket, same pattern as `_HTML_Bucket1`–`_HTML_Bucket6` today and as used in the Open Work Orders report's per-bucket measures.

**Why Total # of Orders moves off the hero:** it's already shown per-tier on the aging card the user just clicked, so repeating it on the hero would be redundant. Hero carries the 3 metrics that aren't already visible elsewhere when a tier is selected.

**Why no branch chart in the bottom slot:** branch comparison already exists on Page 3; repeating it here adds no value. The "what's working well today" element — the Not-BO-vs-BO split — is what fills that visual space instead.

---

## Why the click-to-filter needs a workaround

Page 1's cards are rendered by the **"HTML Content" custom visual** (`htmlContent443BE3AD55E043BF878BED274D3A6855`, registered in `report.json` → `publicCustomVisuals`). This visual is render-only — it has no native click/selection support, so an HTML card can never directly drive a filter.

**Approach: invisible slicer overlay.** Add a native `Slicer` visual on `Fact_Parts_Open_Tickets[Aging]`:
- Layout: List/Tile, horizontal, exactly 6 columns (so each tile spans the same width as one HTML card)
- Selection: single-select (gives free toggle-off — click a selected tile again to clear and return to rolled-up totals)
- Formatting: background, border, header, and font all set to fully transparent/off — visually invisible
- Position: identical `x`/`y`/`width`/`height` to the Aging Card Row visual, z-order **above** it so it intercepts the click; the styled HTML card underneath shows through since the slicer has no visible chrome

This was chosen over styling a *visible* native slicer to look like the cards, because a native slicer's per-tile formatting can't reproduce the existing card design (colored accent, label, count badge) — only a flat value can be shown per tile.

**Edit Interactions scoping** (Format → Edit Interactions, applied to the new slicer):
- → Hero Card visual: **Filter**
- → Backorder Pulse visual: **Filter**
- → Aging Card Row visual: **None** (cosmetic only — its measures are hardcoded per bucket via `CALCULATE(..., Aging = "90+ Days")`, so they're immune to the ambient filter regardless, but explicitly setting None avoids Power BI attempting any visual highlight pass on it)
- → all other Page 1 visuals (filter panel slicers, etc.): leave default/unaffected

**Implementation risk to flag:** pixel-exact alignment between the slicer's 6 auto-distributed tiles and the HTML card row's 6 flex columns. The page uses a fixed canvas (`FitToPage`, 1664×936, not responsive), so this is achievable, but should be validated as a quick spike in Desktop before the rest of the layout is finalized around it.

---

## Existing measures this reuses (found during investigation — don't rebuild)

| Measure | Location | Reuse plan |
|---|---|---|
| `Hero Card - Parts Open Tickets` | `_Measures.tmdl` | Currently shows 4 metrics (Order Total, Parts on Order, Line Count, Total Orders) on 2 hidden pages (`On Order Details`, `Backordered Parts` drillthrough). Already filter-context-aware (no hardcoded `CALCULATE` override) — will respond to the new slicer automatically. **Do not modify this shared measure** — see Decision below. |
| `KPI SVG - Order Total vs Backordered (Modern)` | `_Measures.tmdl:640` | Filter-context-aware SVG bar (Order Total split). Reuse as-is inside the new Pulse measure. |
| `KPI SVG - Parts On Order vs Back Order (Modern)` | `_Measures.tmdl:489` | Same pattern, reuse as-is. |
| `KPI SVG - Line Count vs Backordered Line (Modern)` | `_Measures.tmdl:783` | Same pattern, reuse as-is. |
| `KPI SVG - Orders vs Orders with BO Parts (Modern)` | `_Measures.tmdl:929` | Same pattern, reuse as-is. |
| `_HTML_Bucket1`–`_HTML_Bucket6` | `_Measures.tmdl:1147-1325` | Source of truth for per-bucket hardcoded `VAR Lbl = "90+ days" ... CALCULATE(..., Aging = Lbl)` pattern and the real color palette (see below). New aging card measure reuses this pattern, trimmed to just the order count. These 6 measures + the wrapper `HTML - Parts Overview Dashboard` are retired once the new measures are validated. |
| `HTML_Parts_Overview` (calculated table) | `HTML_Parts_Overview.tmdl` | Pre-summarized per-bucket table (Avg_Days_Open, Order/Parts/Lines/Orders × Total/Available/BackOrdered). Not required for the new measures (which call existing measures directly via `CALCULATE`), but available if a table-driven rewrite is preferred during implementation. |

**Decision — don't edit `Hero Card - Parts Open Tickets` directly:** that measure is already placed on 2 other pages (hidden `On Order Details`, drillthrough `Backordered Parts`). Trimming it to 3 metrics and adding the dynamic tier label would silently change those pages too. Build a **new** measure for Page 1 instead (see below), leaving the original untouched.

**Real aging color palette** (from `_HTML_Bucket1`–`6` — use these, not the gradient in `REPORT-PAGES-GUIDE.md`, which is stale):

| Tier | Color | Light variant |
|---|---|---|
| 90+ days | `#cf1322` | `#ffe0e0` |
| 61-90 days | `#f5222d` | `#ffe6e6` |
| 31-60 days | `#fa8c16` | `#fff1e6` |
| 15-30 days | `#faad14` | `#fff7e6` |
| 8-14 days | `#52c41a` | `#e6f7d9` |
| 0-7 days | `#27ae60` | `#d5f4e6` |

---

## New Measures Required

### 1. `HTML - Parts Overview Hero` (new)

3-metric hero card, adapted from `Hero Card - Parts Open Tickets` but:
- Drops the "Total Orders" section (3 metrics, not 4)
- Adds a label: `"TOTALS — " & SELECTEDVALUE(Fact_Parts_Open_Tickets[Aging], "All Tiers")`
- Uses `[Order Total]`, `[# Parts On Order]`, `[Line Count]` directly (no `CALCULATE` override) so it responds to ambient filter context from the slicer
- Same gradient/styling as the existing Hero Card measure (`#1D3C4E` → `#3A7CA5`)

### 2. `HTML - Aging Card Row` (new)

Replaces `_HTML_Bucket1`–`6` + `HTML - Parts Overview Dashboard`. One measure, 6 `VAR` blocks (same `Lbl`/`Clr`/`ClrLt` pattern as today), each rendering a compact card:
- Tier label (top, colored per the palette above)
- `Total # of Orders` count for that tier via `CALCULATE([Total # of Orders], Fact_Parts_Open_Tickets[Aging] = Lbl)` — hardcoded, intentionally immune to the slicer
- No avg-days badge in v1 (dropped for compactness — easy to add later as a tooltip if wanted)
- 6 cards laid out as equal-width flex columns spanning the visual's full width (needed for slicer-tile alignment)

### 3. `HTML - Backorder Pulse` (new)

Wraps the 4 existing `KPI SVG - ... (Modern)` measures with a dynamic label, e.g.:

```
"BACKORDER PULSE — " & SELECTEDVALUE(Fact_Parts_Open_Tickets[Aging], "All Tiers")
& [KPI SVG - Order Total vs Backordered (Modern)]
& [KPI SVG - Parts On Order vs Back Order (Modern)]
& [KPI SVG - Line Count vs Backordered Line (Modern)]
& [KPI SVG - Orders vs Orders with BO Parts (Modern)]
```

Each SVG measure already returns valid inline `<svg>...</svg>` markup, so concatenation inside one HTML wrapper is valid. No changes needed to the 4 SVG measures themselves — they're already filter-context-aware.

---

## Page 1 Layout Changes (Desktop / PBIR)

| Visual | Action |
|---|---|
| `d702c61039d5365b597d` (htmlContent, `HTML - Parts Overview Dashboard`) | Remove |
| New htmlContent visual | Add, bound to `HTML - Parts Overview Hero`, positioned at top |
| New htmlContent visual | Add, bound to `HTML - Aging Card Row`, positioned below hero |
| New Slicer visual on `Fact_Parts_Open_Tickets[Aging]` | Add, transparent/Tile/horizontal/6-column/single-select, positioned identically to and z-ordered above the Aging Card Row visual |
| New htmlContent visual | Add, bound to `HTML - Backorder Pulse`, positioned below the aging cards |
| `b33423b49e53c9cb6022` (hidden `cardVisual` scaffold) | Remove — unused leftover sitting under the old HTML visual |
| `03dc303b2bf81fc5e96e` (hidden `tableEx` scaffold) | Remove — unused leftover |
| Existing filter panel (Branch/Aging/Invoice Type/Order Date/Customer/Contact Code slicers, Show/Hide Panel buttons) | No change |
| `Home - Header` HTML visual, logo/nav images | No change |

---

## Known Constraints & Gotchas

- **Don't touch `Hero Card - Parts Open Tickets`** — it's shared with 2 other pages (see Decision above). Build the new 3-metric hero as a separate measure.
- **TMDL files don't support `//` comments** at the structural level — fine inside DAX backtick expressions, not as bare TMDL lines.
- **Slicer/HTML alignment is the main build risk** — validate with a quick spike before finalizing positions; both visuals need identical `x`/`y`/`width`/`height` in the visual.json, and the slicer needs exactly 6 evenly-distributed tiles.
- **Aging Card Row measures stay hardcoded per bucket** — this is intentional (mirrors the existing `_HTML_Bucket1`–`6` and the Open Work Orders report's per-bucket measure convention), not an oversight. Don't "fix" it to be filter-context-aware or the cards will all collapse to the same selected tier instead of always showing all 6.
- **Lineage tag uniqueness** — new measures need unique lineage tags not already in `_Measures.tmdl`.
- **Retire cleanly** — once the new measures are validated in Desktop, delete `_HTML_Bucket1`–`6`, `HTML - Parts Overview Dashboard`, and the 2 hidden scaffold visuals rather than leaving them as dead weight.

---

## Files to Edit

| File | Change |
|---|---|
| `reports/current/Open Parts Tickets.SemanticModel/definition/tables/_Measures.tmdl` | Add `HTML - Parts Overview Hero`, `HTML - Aging Card Row`, `HTML - Backorder Pulse`. Remove `_HTML_Bucket1`–`6`, `HTML - Parts Overview Dashboard` (after validation). |
| `reports/current/Open Parts Tickets.Report/definition/pages/e384167396533ecc066e/` (Overview page) | Remove old HTML visual + 2 hidden scaffold visuals; add 3 new htmlContent visuals + 1 new Slicer visual; set Edit Interactions scoping |
| `reports/current/Open Parts Tickets.Report/definition/report.json` | No change expected (custom visual already registered) |

---

## Validation Checklist (manual, in Desktop)

- [ ] Default state: Hero shows all-tiers totals, Pulse shows "All Tiers" label and all-tiers split
- [ ] Click each of the 6 cards individually: Hero and Pulse both update to that tier; aging cards stay visually unchanged
- [ ] Click a selected card again: returns to all-tiers rolled-up state on Hero and Pulse
- [ ] Confirm filter panel slicers (Branch, Invoice Type, etc.) still work normally and don't interact unexpectedly with the new invisible slicer
- [ ] Confirm Page 3 (Comparison) and other pages are unaffected
- [ ] Confirm `Hero Card - Parts Open Tickets` still renders unchanged on `On Order Details` and `Backordered Parts` drillthrough pages
- [ ] Visual QA: invisible slicer truly invisible (no border/background/header bleed-through) at actual report zoom level
- [ ] Performance: page load time comparable to or better than today (fewer, simpler HTML measures vs. one large 6-section measure)
