# Inventory Analysis — dim_DateTable Consolidation Design Spec

## 1. Problem Statement

`Inventory Analysis` is the only remaining report in this project still using its own
standalone `dim_Date` table instead of the shared `dim_DateTable` every other
report has already consolidated onto. Per Brian: "this was one of the first
reports that I built and used the dim_Date table before I created the
dim_DateTable... I always meant to change this so that all the reports used the
same date table."

The report-migration catalog originally scoped this as "build a new `dim_Date`
Gold table" (matching the report's current model shape). Real investigation
found a better option: `dim_DateTable` — already live in `DP_Presentation`,
already used by every other migrated report — already has every column
Inventory Analysis actually needs.

## 2. Scope

**In scope:** repoint Inventory Analysis's `dim_Date` table to source from
`DP_Presentation`'s `dim_DateTable`, and trim to the 3 real columns confirmed
used (`Date`, `Year`, `MonthName` — all present in `dim_DateTable` under
identical names, no renaming needed).

**Real confirmed usage** (via `pbir` + full DAX-text grep across every measure
table + `relationships.tmdl` + both bookmarks touching this table): of
`dim_Date`'s 12 real columns, only `Date` (2 relationships:
`Fact_Part_Transactions.TransactionDate`, `Fact_Invoice_InventoryAnalysis.InvoiceDate`
bothDirections), `Year` (~35 DAX references — YoY comparisons, `USERELATIONSHIP`
filters, a 5-year trend measure), and `MonthName` (an area-chart category axis
+ a bookmark filter) are genuinely used anywhere. `Month`, `Day`, `Weekday`,
`WeekdayName`, `WeekOfYear`, `Quarter`, `YearMonth`, `MonthShort`, `IsWeekend`
have zero usage found anywhere.

**Explicitly out of scope:**
- No new Gold-layer notebook or table — `dim_DateTable` already exists,
  already correct, already used elsewhere. This is pure report-layer work.
- No change to `dim_DateTable`'s own Gold-layer build or schema.
- Parts on Open Orders and Transfers — the other 2 remaining Batch 2 gaps,
  deliberately sequenced after this one, unrelated to this spec.

## 3. Architecture

A TMDL table's *name* in the model doesn't have to match its M-query source
table name. The report's model table stays named `dim_Date` (so the ~35
existing DAX measures and 2 relationships that reference `dim_Date[Date]` /
`dim_Date[Year]` / `dim_Date[MonthName]` need zero changes) — only the M
query itself changes:

- Connection swapped from `LH_Master_Data` to `DP_Presentation` (the
  standard connection-string swap used throughout this project).
- `Item="dim_Date"` changed to `Item="dim_DateTable"`.
- The M query's column selection trimmed to `{"Date", "Year", "MonthName"}`
  via `Table.SelectColumns`, matching the Batch 0 lesson (a TMDL-only trim
  doesn't survive a Desktop refresh — the M query itself must be pinned too).

Same real-tool boundary as every prior report migration this session: Brian
confirms the report isn't open in Desktop (it currently isn't tracked in
`fabric-workspace-docs/workspaces/RP - Dev` at all yet — this report hasn't
been touched by this migration project before, so it needs its first publish
to `RP - Dev` as-is before Claude can safely edit the TMDL directly, matching
the exact same first-time workflow already proven on every other report this
session).

## 4. Verification Plan

No new Gold-layer logic is being computed — `dim_DateTable` is already
proven correct and already in production use by other reports — so no new
DuckDB ground-truth script is needed. Verification is:
1. A DuckDB row-count/spot-check confirming `dim_DateTable` returns real,
   sensible `Date`/`Year`/`MonthName` values (a trivial sanity check, not a
   new correctness proof).
2. Brian's own post-publish Desktop refresh + visual confirmation that
   Inventory Analysis's date-based visuals (YoY comparisons, the 5-year trend
   measure, the area-chart category axis) still render correctly — the same
   three-way check used throughout this project.

## 5. What This Spec Deliberately Does Not Cover

- Building the previously-planned standalone `dim_Date` Gold table — superseded
  entirely by this consolidation approach.
- Parts on Open Orders and Transfers — separate, later work.
- Any structural change to `dim_DateTable` itself.
