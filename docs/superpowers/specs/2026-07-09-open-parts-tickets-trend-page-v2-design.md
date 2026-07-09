# Open Parts Tickets — Trend Page v2 (Controls & Visual Rework) — Design Spec

**Date:** 2026-07-09
**Report:** Open Parts Tickets
**Requested by:** Brian, after reviewing the v1 build live in Desktop
**Status:** Approved — ready for implementation
**Supersedes:** Visual/chart sections of `docs/superpowers/specs/2026-07-08-open-parts-tickets-trend-page-design.md` and Tasks 5–12 of `docs/superpowers/plans/2026-07-08-open-parts-tickets-trend-page.md`. The v1 measures already built (Tasks 1–4 of that plan, commits `08896852`, `3aaafb7f`, `e6f89fcd`) are the foundation this spec builds on — most are kept, one is modified, two new ones are added.
**Reference mockup:** interactive HTML mockup built during design discussion (not committed to the repo — a throwaway visual aid), screenshots of both iterations are in this conversation's history.

---

## Why v2

The v1 build (line charts for Order Count + Backorder Count, and Order Total $ + Backorder $) shipped and was reviewed live in Desktop. Two problems surfaced:

1. **Order Count and Backorder Count are different grains** — Order Count is a count of order tickets (~1,700–2,000/month), Backorder Count is `SUM(#_On_Back_Order)`, a sum of individual backordered *part quantities* (~3,700–6,900/month). Plotting them on one shared axis (line or clustered column) always produces a scale mismatch no amount of dual-axis or indexing cleanly fixes — it's a units problem, not a chart-type problem.
2. **No visible way to control the time window or Aging bucket without opening the hidden slicer panel**, and the trend visuals were expected to become unreadable as more snapshot months accumulate over the coming months.

## What changes

- Both "line chart of two mismatched metrics" visuals are replaced with **proportion-bar timelines** — a small-multiples repetition of the same "Not Backordered vs. Backordered" bar component already used on the report's Overview page (Page 1), one bar per snapshot month. This works because both new pairings are same-grain, part-to-whole splits:
  - **Dollars Trend**: Available $ vs. Backordered $ (already same unit/grain — Backorder $ is a subset of Order Total $)
  - **Orders Trend**: Orders with no backorder vs. orders with ≥1 backordered part (both order-grain — replaces the mismatched raw Backorder Count with a new same-grain measure)
- **Aging Mix Over Time** (the 100%-... actually the absolute stacked column chart) is unchanged.
- **KPI Row** gets one coloring fix: Invoices and Order Total $ deltas move from neutral to the same conditional red(increase)/green(decrease) coloring already used for Backorder $ and Backorder Count. Rationale confirmed with Brian: this table is *open* (unfulfilled) orders, so a growing Order Count or Order Total $ is backlog growing — same "bad direction" as backorders, not a neutral fact. All 4 KPI cards now use one consistent rule.
- **New always-visible controls**: an Aging bucket chip-row and a time-window control, replacing reliance on the hidden slicer panel for this page. A header context line reflects whatever's currently selected.

---

## Aging control

**Mechanism**: a real native Slicer visual on `fact_parts_open_orders_snapshot[Aging]` (single-select, Tile style, horizontal), styled with per-value background colors matching the report's real aging palette (`#27ae60` → `#cf1322`, same 6 hexes already used elsewhere in this report — not the stale `REPORT-PAGES-GUIDE.md` gradient). This is simpler than the click-to-filter trick built for Page 1: Page 1 needed an *invisible* slicer layered over styled HTML cards because HTML Content visuals have zero native interactivity. Here there's no HTML card layer to preserve underneath — the slicer tiles themselves are styled directly and are the visible UI, no overlay needed.

**The "All" tile**: a slicer can't show a synthetic "All" option (it only lists real column values). "All" is a separate `actionButton` visual styled identically to the slicer tiles, positioned first in the row, wired via **Edit Interactions → Bookmark** to a saved bookmark that clears the Aging slicer's selection. This is a standard, well-understood PBI pattern.

**Interaction scoping**: the Aging slicer filters the KPI Row, the Dollars Trend timeline, and the Orders Trend timeline. It does **not** filter the Aging Mix Over Time chart — that chart's entire purpose is showing the full 6-bucket breakdown, so it stays immune to the Aging control the same way Page 1's per-bucket aging cards stay immune to their own click (Edit Interactions → **None** for that pairing).

## Time control

**Mechanism**: a native **Relative Date** slicer on `fact_parts_open_orders_snapshot[SnapshotDate]`, default set to "in the last 6 months." This was chosen over the two alternatives considered during design:
- *A disconnected preset-button table* (reusing this model's existing `Ratio_Period_Selector` pattern) plus a separate individual-month tile slicer — rejected as unnecessary complexity: two controls that could conflict with each other for one concept (which months are in view).
- *A bookmark-based default selection on a multi-select month slicer* — rejected because the "default" would need manual re-saving every time a new snapshot month lands, unlike a Relative Date filter which shifts forward automatically with zero maintenance.

Relative Date slicers don't support picking arbitrary individual non-contiguous months — if that's ever needed, it's a fast follow-up, not part of this build (YAGNI for v1; the hidden panel remains available as a fallback for ad-hoc filtering in the meantime, see "Hidden panel" below).

**Interaction scoping**: filters the KPI Row, Dollars Trend timeline, Orders Trend timeline, **and** Aging Mix Over Time (unlike the Aging control, restricting the time window should shrink all 4 visuals together — there's no "stays immune" case here).

## Header context line

`Page 6 - Trends - Header` (already built, currently static) gets a new line appended below the title: `Viewing {relative date label} · Aging {selected bucket or "All"}`, built via `SELECTEDVALUE` against the Aging slicer (fallback `"All"`) and the Relative Date slicer's own filter state (Power BI relative-date slicers expose their selection through the filter, not a clean `SELECTEDVALUE`-able column — the exact DAX pattern for reading it back needs a quick Desktop spike, flagged in the plan rather than guessed here).

## Hidden panel

**The entire hidden panel is off-limits for this work — do not add, remove, or modify anything in it.** Per Brian's explicit instruction, this includes the page's `HiddenInViewMode` visibility, its leftover `Order_No` drillthrough filter binding, the Branch slicer, and the old Aging/Invoice_Type/Customer/Contact Code slicers (even though the new Aging chip control makes the panel's Aging slicer redundant, and Invoice_Type/Customer/Contact Code are already known to be inert). The panel also handles page-to-page navigation, so it carries more risk to touch than a simple slicer cleanup — Brian will handle any changes to it himself, on his own schedule. The new Aging chip control and the old panel's Aging slicer will coexist as two independent, unconnected controls for now; that's accepted as a known, temporary redundancy rather than something this build should resolve.

---

## New/Modified Measures

| Measure | Status | Change |
|---|---|---|
| `Snapshot Order Count`, `Snapshot Order Total $`, `Snapshot Backorder $`, `Snapshot Backorder Count` | **Kept as-is** | Still feed the KPI Row (all 4) and the Dollars Trend timeline (Order Total $ / Backorder $ only) |
| `HTML - Trend KPI Row` | **Modified** | `Clr1` (Invoices) and `Clr2` (Order Total $) change from the hardcoded `NeutralClr` to the same conditional `IF(Change > 0, BadClr, IF(Change < 0, GoodClr, NeutralClr))` pattern already used for `Clr3`/`Clr4` |
| `Snapshot Orders with Backorder` | **New** | `CALCULATE(DISTINCTCOUNT(fact_parts_open_orders_snapshot[Order_No]), fact_parts_open_orders_snapshot[#_On_Back_Order] > 0)` — same pattern as the live report's existing `Orders with Backordered Parts` measure, applied at the snapshot table's grain (valid since the snapshot is already one row per order per month) |
| `HTML - Dollars Trend Timeline` | **New** | Renders N proportion-bar rows (one per month in the current Relative-Date + Aging filter context), Available $ vs. Backordered $ per row. Must be built with `CONCATENATEX` over the distinct qualifying `SnapshotDate` values (respecting ambient filters), **not** a fixed set of hardcoded per-month `VAR`s like the ~~original~~ replaced line-chart approach — row count now varies with the Relative Date selection |
| `HTML - Orders Trend Timeline` | **New** | Same `CONCATENATEX` pattern, Orders without backorder vs. `Snapshot Orders with Backorder` per row |

## Visual-layer changes

| Item | Action |
|---|---|
| Order Count Trend chart (line) | Remove |
| Dollars Trend chart (dual line) | Remove |
| Backorder Count Trend chart (line) | Remove |
| Aging Mix Over Time chart | Keep, unchanged, but rescope Edit Interactions (immune to Aging slicer, responsive to Time slicer) |
| New htmlContent visual, bound to `HTML - Dollars Trend Timeline` | Add |
| New htmlContent visual, bound to `HTML - Orders Trend Timeline` | Add |
| New Slicer visual on `fact_parts_open_orders_snapshot[Aging]` | Add — Tile style, horizontal, single-select, per-value colors from the real aging palette |
| New `actionButton` styled as an "All" tile + bookmark clearing the Aging slicer | Add |
| New **Relative Date** Slicer visual on `fact_parts_open_orders_snapshot[SnapshotDate]` | Add — default "in the last 6 months" |
| `Page 6 - Trends - Header` measure | Modify — append the dynamic context line |
| Hidden panel: Aging/Invoice_Type/Customer/Contact Code slicers | Remove (Branch slicer stays) |

---

## Known Constraints & Gotchas

- **Relative Date filter state isn't a plain column value** — reading it back for the header context line needs a Desktop spike to confirm the right DAX pattern (likely via the slicer's own filter context rather than `SELECTEDVALUE` on a real column). Flag this early in the plan rather than assuming a specific approach works.
- **`CONCATENATEX` row count now varies** — the two new timeline measures must handle 1 month (edge case: a Relative Date selection narrower than the data, or very early in the table's life) through however many months "All" resolves to, without breaking the bar layout at either extreme.
- **Aging Mix Over Time must stay immune to the Aging slicer** — this is intentional (mirrors Page 1's per-bucket cards staying immune to their own click), not an oversight to "fix" later.
- Same repo-wide rules apply as v1: no `//` TMDL comments, unique lineage tags, `fact_parts_open_orders_snapshot` stays lowercase, DAX bracket measure refs never take inner quotes.

---

## Files to Edit

| File | Change |
|---|---|
| `_Measures.tmdl` | Modify `HTML - Trend KPI Row` (coloring fix); add `Snapshot Orders with Backorder`, `HTML - Dollars Trend Timeline`, `HTML - Orders Trend Timeline`; modify `Page 6 - Trends - Header` (context line) |
| Trends page (`ac8bedf2271b0d172508`) | Remove the 3 line-chart visuals; add 2 new htmlContent timeline visuals, 1 Aging Slicer, 1 "All" action button, 1 Relative Date Slicer; set Edit Interactions per the scoping table above; add 1 new bookmark (clear-Aging). New controls go in the page's main canvas area, not the hidden panel. |
| Hidden panel (any file under `bookmarks/`, or the panel's visual containers) | **Do not touch** — off-limits per Brian, see "Hidden panel" above |

---

## Validation Checklist (manual, in Desktop)

- [ ] All 4 KPI cards use consistent red/green coloring (no more neutral dark-blue delta text anywhere)
- [ ] Dollars Trend and Orders Trend timelines render the correct number of rows for "Last 6 months" (or fewer, once the table has less than 6 months — not applicable now, but don't hardcode an assumption of exactly 6)
- [ ] Selecting an Aging bucket filters KPI Row + both timelines, but Aging Mix Over Time stays unchanged
- [ ] Clicking "All" clears the Aging selection via the bookmark
- [ ] Adjusting the Relative Date slicer filters all 4 visuals including Aging Mix Over Time
- [ ] Header context line updates correctly for both controls, including the "All" / default states
- [ ] Hidden panel is completely untouched — same 5 slicers, same bookmarks, same nav behavior as before this build started
- [ ] Other pages unaffected
