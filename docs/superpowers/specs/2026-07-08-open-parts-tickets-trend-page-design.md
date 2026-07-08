# Open Parts Tickets — Trend Page (Snapshot) — Design Spec

**Date:** 2026-07-08
**Report:** Open Parts Tickets
**Requested by:** Ben (metrics), via Brian
**Status:** Approved — ready for implementation

---

## Problem

`fact_parts_open_orders_snapshot` (Delta table in `LH_Master_Data`, populated monthly by `nb_Snapshot_Parts_Open_Orders` via `Pipeline_Monthly_Open_Orders_Snapshot`, first snapshot March 1, 2026) now has enough monthly history to support a trend view. Ben has asked for three metrics, broken out "by the buckets": Number of Invoices, Dollars, Number of Back Orders.

A "Trends" page already exists in the report (`ac8bedf2271b0d172508`), cloned from the standard page shell (header, logos, page navigator, Show/Hide Panel Group bookmarks, hidden slicer panel) — but it has no trend content yet, and its hidden slicer panel is misconfigured for this use (see below).

---

## Solution

Build the trend content on the existing "Trends" page: 4 KPI cards (latest snapshot month vs. prior month) + 4 trend visuals plotted by `SnapshotDate` month, filterable by a 2-slicer panel (Aging, Branch). No new page or bookmark plumbing needed.

### Terminology note

The snapshot table has no invoice-number column (only `Order_No`). Per stakeholder confirmation, "Number of Invoices" = count of open order/ticket records (`DISTINCTCOUNT(Order_No)`), since there is no separate invoice concept in open-order data.

### Existing slicer panel needs rebinding (found during investigation)

The hidden panel's 5 slicers were cloned from another page's filter panel and are bound as follows:

| Slicer (visual name) | Currently bound to | Would filter the snapshot trend content? |
|---|---|---|
| Aging (`37863f7901b2021370d5`) | `Fact_Parts_Open_Tickets[Aging]` | **No** — no relationship between that table and the snapshot fact |
| Branch (`72470bc2b5e161e9e3b6`) | `dim_BranchLocation[Branch]` | **Yes** — snapshot relates to `dim_BranchLocation` via `Location` |
| Invoice_Type (`1737fbdb29e6eec57b5a`) | `Fact_Parts_Open_Tickets[Invoice_Type]` | No |
| Customer (`a4cdee90e75c2e97582e`) | `Fact_Parts_Open_Tickets[Customer]` | No |
| Contact Code (`d937f1fa957dec51cf6a`) | `Fact_Parts_Open_Tickets[Contact Code]` | No |

**Changes:**
- Rebind the Aging slicer's field from `Fact_Parts_Open_Tickets[Aging]` to `fact_parts_open_orders_snapshot[Aging]`, sorted by `fact_parts_open_orders_snapshot[Aging_Sort_Order]`.
- Leave the Branch slicer as-is (already correctly bound).
- Remove the Invoice_Type, Customer, and Contact Code slicer visuals from the panel — out of scope for this page and currently inert against snapshot data.

### Real aging color palette

Use the palette already established in `_Measures.tmdl` (`_HTML_Bucket1`–`6`), **not** the gradient documented in `REPORT-PAGES-GUIDE.md`, which is stale:

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

None currently exist against `fact_parts_open_orders_snapshot`. Add to `_Measures.tmdl` under a new display folder `Snapshot Trend`:

| Measure | DAX | Notes |
|---|---|---|
| `Snapshot Order Count` | `DISTINCTCOUNT(fact_parts_open_orders_snapshot[Order_No])` | "Number of Invoices" per Ben, per the terminology note above |
| `Snapshot Order Total $` | `SUM(fact_parts_open_orders_snapshot[Order_Total_$$])` | |
| `Snapshot Backorder $` | `SUM(fact_parts_open_orders_snapshot[$$_BackOrdered])` | |
| `Snapshot Backorder Count` | `SUM(fact_parts_open_orders_snapshot[#_On_Back_Order])` | |
| `Snapshot Order Count - Prior Month` | Latest-vs-prior pattern below | For KPI delta card |
| `Snapshot Order Total $ - Prior Month` | Same pattern | |
| `Snapshot Backorder $ - Prior Month` | Same pattern | |
| `Snapshot Backorder Count - Prior Month` | Same pattern | |

**Latest/prior snapshot month pattern** (avoids relying on "today," since the snapshot only has ~5 rows of month history and today's date won't line up with `SnapshotDate`):

```dax
VAR LatestSnapshot = CALCULATE(MAX(fact_parts_open_orders_snapshot[SnapshotDate]), ALL(fact_parts_open_orders_snapshot))
VAR PriorSnapshot =
    CALCULATE(
        MAX(fact_parts_open_orders_snapshot[SnapshotDate]),
        ALL(fact_parts_open_orders_snapshot),
        fact_parts_open_orders_snapshot[SnapshotDate] < LatestSnapshot
    )
RETURN CALCULATE([Snapshot Order Count], fact_parts_open_orders_snapshot[SnapshotDate] = PriorSnapshot)
```

`ALL(fact_parts_open_orders_snapshot)` is used (not `ALLSELECTED`) so "latest/prior" always means the two most recent calendar months of snapshot data regardless of what the Aging/Branch slicers have filtered — the KPI cards compare the same two months whether the user is scoped to one bucket or all of them.

### KPI Cards (4)

Each card: metric name, latest-month value, delta vs. prior month as `+X.X%` / `-X.X%` with an up/down arrow, and literal comparison wording (`"vs May 2026"`, using `FORMAT(PriorSnapshot, "MMMM YYYY")`) rather than vague "Prior Period" text — consistent with the wording convention already adopted on the Pin Capture report.

Color convention: for **Backorder $** and **Backorder Count**, an increase is colored red (`#FF6B6B`) and a decrease green (`#5CB85C`), matching the report's existing backorder-is-bad convention. For **Order Count** and **Order Total $**, deltas are neutral (dark blue `#1D3C4E`) since a growing backlog isn't inherently good or bad in isolation — flag if you'd rather these be colored too.

---

## Trend Visuals (4)

All four use `dim_DateTable[MonthYear]` as the axis (sorted by `SortableMonthYear`), implicitly scoped to snapshot months via the `SnapshotDate → dim_DateTable.Date` relationship. No date hierarchy/drill — at ~5 months of data, month-level is the only meaningful grain.

1. **Order Count Trend** — line chart, `[Snapshot Order Count]` by month. Single line (Aging/Branch scoping via slicers, not series-split).
2. **Dollars Trend** — dual-line chart, `[Snapshot Order Total $]` and `[Snapshot Backorder $]` by month, same axis. Colors: Order Total `#3A7CA5` (blue), Backorder `#FF6B6B` (red), matching existing Charts-page conventions.
3. **Backorder Count Trend** — line chart, `[Snapshot Backorder Count]` by month.
4. **Aging Mix Over Time** — 100%-stacked column chart, `[Snapshot Order Count]` by month, legend = `fact_parts_open_orders_snapshot[Aging]` sorted by `Aging_Sort_Order`, colored with the real palette above. This is the one visual that shows bucket composition directly rather than relying on the slicer — addresses "by the buckets" as a trend story even when no bucket filter is applied.

---

## Page Layout

```
┌─────────────────────────────────────────────────────────────────┐
│  (existing) Header / logos / page nav — unchanged                │
├───────────────┬─────────────────────────────────────────────────┤
│ SLICERS       │  KPI CARDS (4, latest month vs prior month)      │
│ • Aging       │  ┌────────┐┌────────┐┌────────┐┌────────┐       │
│   (rebound)   │  │#Invoices││ Order $││ BO $   ││ #BO    │       │
│ • Branch      │  └────────┘└────────┘└────────┘└────────┘       │
│   (unchanged) ├─────────────────────────────────────────────────┤
│ (hidden panel,│  TREND CHARTS                                    │
│  bookmark-    │  • Order Count (line)                            │
│  driven,      │  • Order $ vs Backorder $ (dual line)            │
│  unchanged)   │  • Backorder Count (line)                        │
│               │  • Aging Mix Over Time (100% stacked column)     │
└───────────────┴─────────────────────────────────────────────────┘
```

---

## Known Constraints & Gotchas

- **Only ~5 months of data exist** (first snapshot March 2026). Trend lines will look sparse initially; this is expected, not a bug. No forecasting or trendline extrapolation in v1.
- **Snapshot table has no relationship to `Fact_Parts_Open_Tickets`** — any new visual on this page must pull fields from `fact_parts_open_orders_snapshot`, `dim_BranchLocation`, or `dim_DateTable` only. Dragging a field from the live fact table onto this page will silently fail to filter (same bug as the pre-existing Aging slicer).
- **`Days_Open` on the snapshot table is locked at snapshot time** — it does not recalculate as time passes, unlike the live fact table's aging. This is intentional (that's what makes it a snapshot) but worth remembering if numbers look "stale" compared to the live Overview page.
- **Table name casing**: `fact_parts_open_orders_snapshot` is lowercase in the Lakehouse (Fabric's `saveAsTable()` lowercases Delta table names — see `feedback_fabric_saveastable_casing` in memory). The M-query partition already uses the correct lowercase `Item="fact_parts_open_orders_snapshot"`; don't "fix" the casing.
- **TMDL files don't support `//` comments** at the structural level — fine inside DAX backtick expressions only.
- **Lineage tag uniqueness** — new measures need unique lineage tags not already present in `_Measures.tmdl`.

---

## Files to Edit

| File | Change |
|---|---|
| `reports/current/Open Parts Tickets.SemanticModel/definition/tables/_Measures.tmdl` | Add 8 new measures under a new `Snapshot Trend` display folder (4 base + 4 prior-month) |
| `reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/visuals/37863f7901b2021370d5/visual.json` (Aging slicer) | Rebind field to `fact_parts_open_orders_snapshot[Aging]`, set sort by `Aging_Sort_Order` |
| `reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/visuals/1737fbdb29e6eec57b5a/visual.json` (Invoice_Type slicer) | Remove |
| `reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/visuals/a4cdee90e75c2e97582e/visual.json` (Customer slicer) | Remove |
| `reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/visuals/d937f1fa957dec51cf6a/visual.json` (Contact Code slicer) | Remove |
| `reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/` | Add 4 new KPI card visuals + 4 new chart visuals |

---

## Validation Checklist (manual, in Desktop)

- [ ] All 4 new base measures return correct totals for the latest snapshot month (spot-check against a manual filter on `fact_parts_open_orders_snapshot`)
- [ ] Prior-month measures correctly resolve to the second-most-recent snapshot month, and stay fixed at that comparison even when Aging/Branch slicers are applied
- [ ] KPI card delta wording shows the literal prior month name, not "Prior Period"
- [ ] Rebound Aging slicer actually filters all 4 trend visuals + all 4 KPI cards
- [ ] Branch slicer still filters correctly post-change
- [ ] Invoice_Type/Customer/Contact Code slicers no longer present on the panel; Show/Hide Panel Group bookmarks still work for the remaining 2 slicers
- [ ] Aging Mix Over Time chart uses the real palette (not the stale `REPORT-PAGES-GUIDE.md` gradient)
- [ ] Page performs acceptably with 5 months of data; re-check after 12 months to confirm it doesn't degrade
- [ ] Other pages (Overview, On Order Details, Comparison, Charts, Backordered Parts) unaffected
