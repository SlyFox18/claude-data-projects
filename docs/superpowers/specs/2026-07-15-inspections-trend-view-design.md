# Inspections Report — Trend View (Details Page) — Design Spec

**Date:** 2026-07-15
**Report:** Inspections
**Requested by:** Casey, via Brian
**Status:** Approved — ready for implementation

---

## Problem

Casey wants a rolling 24-month trend of average Parts sales and average Service (Labor) sales, filterable by Job Code and Branch, to answer "is our per-job revenue growing or shrinking over time?" — a question the report currently can't answer since every existing view (Home, Details, Goals) is point-in-time or job-code/branch breakdown only, with no time series.

Casey left the placement open ("a page or maybe just add it to the details page and control it by bookmarks"). The Details page already has a two-way bookmark toggle for this exact kind of thing (`Matrix - Jobcode` / `Matrix - Branch`, driven by `Button - Jobcode` / `Button - Branch` action buttons) — extending that pattern with a third `Trend` state is the natural fit and avoids new page navigation plumbing.

---

## Solution

Add a third bookmark/button state (`Matrix - Trend` / `Button - Trend`) to the Details page's existing toggle group. Selecting it hides the two pivot tables (`1401aa2e094056908a34`, `bd2912d19640de5c6eca`) and the other two buttons, and shows new trend visuals in that same canvas area — same mechanism already used for the Jobcode/Branch toggle, just a third state.

### Filters

- **Branch:** reuse the existing Branch slicer already on the Details page (`dim_BranchLocation[Branch]`) — no change needed.
- **Job Code:** switch from the raw `Fact_LaborJobSummary[JobCode]` slicer (100+ distinct values, too noisy for a line chart) to the existing `InspectionCategory` calculated column, which already groups mower/gator variants into fewer, more meaningful buckets. This is a new slicer for the Trend state only — the existing raw JobCode slicer stays as-is for the Jobcode/Branch matrix views.

### Time axis

Uses `dim_DateTable[IsRolling24Months]` (already exists — no new date logic needed) as the window filter, grouped by `dim_DateTable[MonthYear]`, sorted by `dim_DateTable[SortableMonthYear]`. `Fact_LaborJobSummary` relates to `dim_DateTable` via `WorkOrderCreationDateKey`; `Fact_WorkOrderParts` relates via `TransactionDateKey` — both are active many-to-one relationships to the same conformed date dimension, so both fact tables trend against the same calendar without extra DAX date math.

---

## New Measures Required

The one real architectural gap this surfaces: every existing "$ by Job Code" parts measure (`Parts $ Total`, the CS690/770 variants) is built on a **hardcoded job-code list** bridged through invoice numbers, because `Fact_WorkOrderParts` has no `JobCode` column of its own — parts are only linked to a job code indirectly, via the invoice number shared with `Fact_LaborJobSummary`. A trend driven by a live Inspection Category slicer needs a **generalized version of that bridge** that inherits whatever filter is active instead of a fixed list.

Add to `_Measures.tmdl` (this table has no display folders in use anywhere today — new measures are appended flat, consistent with the rest of the file):

| Measure | DAX approach | Notes |
|---|---|---|
| `Parts $ Total (Filtered)` | `VAR ValidInv = CALCULATETABLE(VALUES(Fact_LaborJobSummary[InvoiceNumber]), Fact_LaborJobSummary[IsInspection] = TRUE, NOT(ISBLANK(Fact_LaborJobSummary[InvoiceNumber]))) RETURN CALCULATE(SUM(Fact_WorkOrderParts[SaleValue]), Fact_WorkOrderParts[InvoiceNumber] IN ValidInv, Fact_WorkOrderParts[Franchise] <> "ZP", NOT(Fact_WorkOrderParts[PartNumber] IN {"ADV","LEGACY","4900","*10PROMO"}))` | Same exclusions as today's `Parts $ Total`; the `CALCULATETABLE` inherits whatever `InspectionCategory`/`BranchName` filter is active from the slicers, generalizing the CS690/770 pattern instead of hardcoding job codes |
| _(reuse, no new measure)_ | `[Labor $$]` | No new bridge needed and no new measure created — it already filters `Fact_LaborJobSummary` directly, so it inherits `InspectionCategory`/Branch filter context automatically. Use the existing measure as-is in the Trend chart and in the avg-ticket DIVIDE below |
| _(reuse, no new measure)_ | `[Total Inspections]` | Denominator for the avg-ticket measures below. Already `CALCULATE(COUNTROWS(Fact_LaborJobSummary), IsInspection = TRUE)` with no hardcoded job codes — identical to what a new "Inspection Count (Filtered)" measure would be, so reuse it directly rather than duplicate it |
| `Avg Parts $ / Inspection (Rolling 24)` | `DIVIDE([Parts $ Total (Filtered)], [Total Inspections], 0)` | For KPI card callout |
| `Avg Labor $ / Inspection (Rolling 24)` | `DIVIDE([Labor $$], [Total Inspections], 0)` | For KPI card callout |

**Caveat to flag for Casey:** parts are attributed to an Inspection Category via invoice number, not a direct part-to-job link. If a single invoice mixes job codes from more than one category, its parts $ counts toward all of them. This is the same limitation the existing CS690/770 Parts measure already carries — not a new problem introduced by this feature, just worth knowing before trusting the parts trend at a granular category level.

---

## Trend Visuals — build first, compare, then finalize

Four chart-layout options were sketched (single combined dual-axis chart; 4-series single-axis; two stacked dual-line charts; combined chart + KPI cards). Text/mockup review wasn't conclusive — legibility with 100+ categories' worth of real numbers can't be fully judged from a wireframe. Decision: **build Option D first, compare against Option C with real data in Desktop, then lock in.**

- **Option D (build first):** One combined dual-axis line chart — `Parts $ Total (Filtered)` on the left axis, `Labor $$ (Filtered)` on the right axis, both as monthly total lines over the rolling 24 months. Below the chart, two small KPI cards: `Avg Parts $ / Inspection (Rolling 24)` and `Avg Labor $ / Inspection (Rolling 24)`. Directly answers Casey's "same chart" request; fastest to stand up.
- **Option C (compare against):** Two stacked charts — Parts on top, Labor below — each with its own total line + average-ticket line (dual axis within each chart). Keeps Parts/Labor visually separated if the combined dual-axis chart in D turns out hard to read once populated.
- Both options use the exact same five measures above — nothing built for D is wasted if C is chosen instead. The only difference is visual arrangement, decided in Desktop against live data, not in this spec.

---

## Bookmark Mechanics

Follow the existing `Matrix - Jobcode` / `Matrix - Branch` bookmark pattern exactly:

1. Add new visual(s) for the Trend chart(s) + KPI cards + the `InspectionCategory` slicer, placed in/around the same canvas area as the two pivot tables.
2. Add a third action button, `Button - Trend`, alongside `Button - Jobcode` (`229ae583b0d3c00de190`) and `Button - Branch` (`86c962ed5b7147d37b57`).
3. Create a new bookmark `Matrix - Trend`:
   - `display.mode: hidden` on both pivot table visuals (`1401aa2e094056908a34`, `bd2912d19640de5c6eca`)
   - `display.mode: hidden` on `Button - Jobcode` and `Button - Branch`
   - Trend chart(s), KPI cards, and `InspectionCategory` slicer visible
   - `Button - Trend` visible (hidden in the other two bookmarks)
4. Update the existing `Matrix - Jobcode` and `Matrix - Branch` bookmarks to also hide the new Trend visuals and `Button - Trend` (currently they only reference each other's visuals — all three bookmarks need to account for all three states).
5. Add the new bookmark's name entry to `bookmarks.json`.

---

## Files to Edit

| File | Change |
|---|---|
| `reports/current/Inspections.SemanticModel/definition/tables/_Measures.tmdl` | Add the 3 new measures, appended flat (table above) |
| `reports/current/Inspections.Report/definition/pages/30a66c2b13c2a8e9f495/visuals/` (Details page) | Add: Trend chart visual(s) (Option D first), 2 KPI cards, `InspectionCategory` slicer, `Button - Trend` action button |
| `reports/current/Inspections.Report/definition/bookmarks/bookmarks.json` | Add new bookmark entry |
| `reports/current/Inspections.Report/definition/bookmarks/<new>.bookmark.json` | New `Matrix - Trend` bookmark |
| `reports/current/Inspections.Report/definition/bookmarks/7be3855dee35a77b98c8.bookmark.json` (`Matrix - Jobcode`) | Extend to hide new Trend visuals/button |
| `reports/current/Inspections.Report/definition/bookmarks/9dba35dba10d0450704e.bookmark.json` (`Matrix - Branch`) | Extend to hide new Trend visuals/button |
| `documentation/dax/dax-measures-library.md` | Document new measures (per repo convention) |
| `documentation/report-pages.md` | Update Details page section with the third toggle state |

---

## Known Constraints & Gotchas

- **Parts has no direct JobCode column** — see the invoice-number bridge caveat above. Any future "parts by X" filter follows this same pattern.
- **`InspectionCategory` is a calculated column on `Fact_LaborJobSummary` only** — it doesn't exist on `Fact_WorkOrderParts`; the parts measure filters through the invoice bridge, not a direct column filter, so double-check the new measure's `CALCULATETABLE` correctly inherits the slicer's filter on `Fact_LaborJobSummary[InspectionCategory]` before it builds `ValidInv`.
- **TMDL files don't support `//` comments** at the structural level — fine inside DAX backtick expressions only.
- **Lineage tag uniqueness** — new measures need unique lineage tags not already present in `_Measures.tmdl`.
- **All three bookmarks must be updated together** — since Jobcode/Branch bookmarks currently only know about each other's visuals, forgetting to add the new Trend visuals/button to their hide-lists means switching back from Trend to Jobcode/Branch will leave the Trend visuals stuck on screen. Per `feedback_pbir_cli_filter_side_effects` in memory, `git status` the whole project after any bookmark edit to confirm no unrelated visuals were touched.
- **Chart layout is not finalized** — build Option D, validate readability against live 24 months of data in Desktop, compare with Option C, and confirm with Brian/Casey before considering this done.

---

## Validation Checklist (manual, in Desktop)

- [ ] `Parts $ Total (Filtered)` matches `Parts $ Total` when no Category filter is applied (sanity check against the existing unfiltered measure)
- [ ] `Parts $ Total (Filtered)` correctly changes when the `InspectionCategory` slicer is used, and matches a manual spot-check for at least one category (e.g. filter to CS690/CS770-equivalent category, compare against existing `CS690-CS770 Parts Total`)
- [ ] `Labor $$ (Filtered)` / `Labor With Inspection` respects the same Category/Branch filters
- [ ] Avg $/Inspection KPI cards compute sensible values (spot check against manual total ÷ count)
- [ ] Trend chart(s) show all 24 rolling months, sorted correctly (no alphabetical month-name sorting bug)
- [ ] `Button - Trend` / `Matrix - Trend` bookmark correctly hides both pivot tables and the other two buttons
- [ ] Switching from Trend back to Jobcode or Branch correctly hides the Trend visuals and `Button - Trend` (bookmark round-trip, not just one direction)
- [ ] Branch slicer filters the Trend visuals the same way it filters the existing pivot tables
- [ ] Other Details page elements (header, discount panel, drill-through buttons) unaffected
- [ ] Compare Option D vs Option C readability with live data before finalizing chart layout
