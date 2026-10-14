# Shannon — Parts Ordering Filter Tool — Project Summary

## Overview
A simple Power BI report — "After Market - Parts Orders" — built for Shannon to use when ordering parts. It's not an analytics report with charts; it's a filterable list: Shannon sets filters, reviews sales-trend and order-planning columns, and exports the results to work from.

**Status (2026-09-03):** Built and sent to Shannon for review — awaiting her feedback before finalizing layout.
**Built for:** Shannon (Parts)
**Source:** Direct database connection (ODBC) to the parts master data — not the shared Lakehouse used by most other reports in this repo
**Refresh:** Its own independent schedule, planned for hourly during business hours (8 AM–5 PM), separate from every other report

## Scope
Covers ~202,000 parts — the subset relevant to Shannon's ordering work, filtered down from the full ~1.1 million-row parts table by excluding a set of franchises and branches outside her scope. A live test of this exact scope refreshed in 33 seconds.

## What It Shows
One row per part per branch. Each row includes:
- Part identification: branch, franchise, part number, description, vendor code, dealer group code (DGC), user field 2, bin
- Inventory: on-hand quantity (labeled "O/H" in the report), on-order, in-transit, pending, cost, inventory value ("Inv Total")
- Sales trend columns (added 2026-09-02/03):
  - **R6mS / R12S / R24S / R36S** — units sold in the trailing 6 months, trailing 12 months, the 12 months before that ("last year"), and the 12 months before *that* ("two years ago"), calculated from the part's monthly sales history
  - **R6m $ / R12 $ / R24 $ / R36 $** — the dollar value of each of those (units × current cost)
- Three intentionally blank columns — **To Order, To Do, Order $** — for Shannon to fill in manually after exporting to Excel. These aren't calculated by the report; they just hold the column position.

## How Shannon Uses It
She filters by branch, franchise, vendor code, DGC, user field 2, and/or part number, reviews the sales-trend columns to judge what's moving, exports the filtered list, then fills in the three blank order-planning columns herself in Excel. Long term, this replaces the 6-8 manual queries she currently runs directly against the ERP system each day.

## Where This Is Headed: Faster Refresh
Shannon asked for hourly updates during business hours so the data stays current while she's ordering. Initial concern was that this table is large and expensive to refresh, but a real test came back at 33 seconds for the scoped ~200k-row population — small enough that a direct hourly refresh looks like the right call, without needing extra complexity to split the report into pieces. Still to be confirmed once it's actually running on a schedule: the real compute cost over time, and that hitting the source system hourly during business hours doesn't cause any slowdowns for Shannon or other staff using the ERP directly.

## Open Items
- Awaiting Shannon's feedback on the report as sent.
- A few usability tweaks suggested (default sort order, cleaning up a misleading total, a note near the blank columns, on-hand-zero highlighting) — holding until she's weighed in.
- Decide how the report gets refreshed/published on its hourly schedule and get it actually set up.

## Query
`queries/UserField2_ByPart.pq` — the data-pull layer. Full technical detail, including the exact formulas for the sales-trend columns, is in this project's `CLAUDE.md`.
