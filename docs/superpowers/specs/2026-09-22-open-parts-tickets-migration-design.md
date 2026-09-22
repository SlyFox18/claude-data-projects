# Open Parts Tickets Migration — Design Spec

## 1. Problem Statement

`Open Parts Tickets` (the report's real name — the report-migration catalog
calls it "Parts on Open Orders," a naming drift already confirmed earlier
this project; production still runs under the old name in `RP - Parts
Reports`, while `RP - Dev` already has it under the correct name) is the
next Batch 2 report to migrate from `LH_Master_Data` to `DP_Presentation`,
per Brian's own "one at a time, easiest first" sequencing.

The report-migration catalog described this as a single small gap: a
missing `fact_parts_open_orders_snapshot` table. Real investigation (TMDL
greps, `fab ls` against `DP_Presentation`, reading the real production
notebook and native-query source) found the actual gap is larger and more
nuanced:

- **`fact_parts_open_orders_snapshot`** genuinely doesn't exist in
  `DP_Presentation` — but it's not a blank slate. The real
  `LH_Master_Data` table (actually persisted lowercase,
  `fact_parts_open_orders_snapshot`, due to the known `saveAsTable()`
  lowercases-Delta-names bug — see `feedback_fabric_saveastable_casing`
  in memory) holds **7 months of real, irreplaceable history**
  (March–September 2026, ~1,700–2,200 rows/month, confirmed via direct
  `delta_scan`). The source notebook
  (`LH_Master_Data/Notebooks/nb_Snapshot_Parts_Open_Orders.Notebook`)
  documents in its own header that this history cannot be backfilled —
  it only starts accumulating from whenever the notebook first runs.
- **`Fact_PartsInvoiced_ByBranch`** — not flagged in the catalog at all.
  It isn't backed by any Gold table in either backend; it's a live
  `Value.NativeQuery` straight against the raw `Invoice` table in
  `LH_Master_Data` (`EnableFolding=false`), with a hardcoded ~30-number
  customer-exclusion list and its own distinct business logic (excludes
  those customers entirely — different from `Fact_Invoice_InventoryAnalysis`'s
  Gold-layer approach of bucketing similar customers into "Internal"/
  "Warranty" categories but still including them). Confirmed via direct
  read of both notebooks that no existing Gold table can substitute
  without silently changing the report's real output.

## 2. Scope

**In scope:**
1. Build `Fact_Parts_Open_Orders_Snapshot` in `DP_Presentation` (proper
   PascalCase, fixing the lowercase-name bug via an explicit
   `.save("Tables/...")` write instead of `saveAsTable()`), backfilled
   with the 7 existing months of real history, then kept current going
   forward by a new monthly Gold notebook.
2. Build `Fact_PartsInvoiced_ByBranch` in `DP_Presentation` as a proper
   Gold table, faithfully porting the existing native query's exact
   logic (same ModuleType filter, same customer-exclusion list, same
   15-month rolling window), replacing the `EnableFolding=false`
   raw-SQL-in-TMDL pattern.
3. Repoint all 6 of the report's real data tables
   (`Fact_Parts_Open_Tickets`, `Fact_Parts_Open_Tickets_Details`,
   `dim_BranchLocation`, `dim_DateTable`, `Fact_Parts_Open_Orders_Snapshot`,
   `Fact_PartsInvoiced_ByBranch`) from `LH_Master_Data` to
   `DP_Presentation`, with the same exhaustive usage-audit-before-trim
   discipline used on every other report this project.
4. Register the new snapshot notebook in `deploy/dp_backend_scope.json`
   (`tier: gold, cadence: monthly`) so it runs inside the existing
   `Pipeline_DP_Monthly_Refresh` — no new pipeline.
5. Retire the old `nb_Snapshot_Parts_Open_Orders` from its current
   pipeline (`Pipeline_Monthly_Open_Orders_Snapshot`) once the new
   DP-side notebook is confirmed running, to prevent both writing
   duplicate/diverging future months.

**Explicitly out of scope:**
- Any change to `Fact_Parts_Open_Tickets` / `Fact_Parts_Open_Tickets_Details`
  themselves — both already exist, already correct, already used by
  other reports; this migration only repoints the report's own reference
  to them.
- Renaming the report itself, or reconciling the "Open Parts Tickets" vs
  "Parts on Open Orders" naming drift in production (`RP - Parts
  Reports`) — out of scope for this backend migration; noted in the
  catalog doc, not acted on here.
- Any change to `Fact_Invoice_InventoryAnalysis`'s own Gold-layer
  business logic — its different customer-categorization approach is
  confirmed correct for its own report and is not being changed or
  reused here.
- Transfers — the other remaining Batch 2 report, deliberately
  sequenced after this one.

## 3. Architecture

### 3.1 `Fact_Parts_Open_Orders_Snapshot`

**One-time backfill:** a scratch script/notebook cell reads all 7 months
from `LH_Master_Data`'s `fact_parts_open_orders_snapshot` (16 columns:
`Location`, `Location_Name`, `Order_No`, `Invoice_Type`, `Order_Date`,
`Days_Open`, `Aging`, `Aging_Sort_Order`, `` #_Parts_On_Order``,
`` #_On_Back_Order``, `` Order_Total_$$``, `` $$_Available``,
`` $$_BackOrdered``, `Backorder_Pct`, `Customer`, `Salesman`, plus
`SnapshotDate`) and writes them unchanged into a new
`Fact_Parts_Open_Orders_Snapshot` table in `DP_Presentation`, via
`.save("Tables/Fact_Parts_Open_Orders_Snapshot")` (path-based write,
not `saveAsTable()`, per the established casing-bug fix).

**New monthly notebook** (`Build_Gold_PartsOpenOrdersSnapshot.Notebook`,
under `DP - Presentation - Dev/Fact Tables/Open Parts Tickets/`):
replicates the existing notebook's logic exactly — same duplicate-guard
(skip if `SnapshotDate` for the current month already exists), same
`SnapshotDate = 1st of the current month` rule, same source-column list
— but reads from `DP_Presentation.Fact_Parts_Open_Tickets` instead of
`LH_Master_Data.Fact_Parts_Open_Tickets`, and appends to the new
`DP_Presentation.Fact_Parts_Open_Orders_Snapshot` via the same
path-based write. The original notebook's `date.today()`-based
`SnapshotDate` logic is kept as-is (not a real bug: the pipeline runs at
5:30 AM Central, nowhere near a UTC day-boundary edge case, so this
differs from the `DateTime.LocalNow()` rolling-window bug class already
fixed elsewhere).

**Pipeline registration:** add an entry to `deploy/dp_backend_scope.json`
(`tier: gold, cadence: monthly`, matching the existing
`Build_Gold_BranchLocation`/`Build_Gold_DealerGroupCode`/
`Build_Gold_Franchise` entries' shape) — this alone wires the new
notebook into `Pipeline_DP_Monthly_Refresh`'s existing config-driven
`ForEach`, no pipeline JSON edits needed.

**Cutover:** once the new notebook has run cleanly at least once (or its
logic is confirmed correct via a dry-run check against the guard
condition), remove `nb_Snapshot_Parts_Open_Orders` from
`Pipeline_Monthly_Open_Orders_Snapshot` to prevent duplicate/diverging
writes going forward. The old notebook and its `LH_Master_Data` table
are left in place (not deleted) as a historical record.

### 3.2 `Fact_PartsInvoiced_ByBranch`

New `Build_Gold_PartsInvoicedByBranch.Notebook`, same folder, faithfully
porting the existing `Value.NativeQuery`'s exact logic in PySpark:
`SELECT Branch, CAST(InvoiceDate AS DATE), SUM(PartsSaleValue) ...`
grouped by `Branch`/date, filtered to `ModuleType IN ('I','W')`, excluding
the same ~30 hardcoded customer numbers, over the same 15-month rolling
window — but computed with a fixed/DST-safe date boundary instead of raw
T-SQL `GETDATE()`. Registered as `tier: gold, cadence: daily` (matching
this project's standard cadence for report-facing Gold tables, unlike the
monthly snapshot).

### 3.3 Report-layer repoint

Once both new Gold tables are built and verified, the report itself gets
the same treatment as every prior migration this project: exhaustive
real-usage audit (pbir + DAX-grep + bookmark check + relationships.tmdl
cross-reference) across all 6 real data tables, repoint each connection
string to `DP_Presentation`, trim to confirmed-used columns where
confident, leave ambiguous columns untouched. Brian confirms the report
isn't open in Desktop before Claude edits TMDL directly, matching the
established real-tool boundary.

## 4. Verification Plan

1. **Backfill correctness:** row-count and `SnapshotDate`-grouped count
   comparison between the old `LH_Master_Data.fact_parts_open_orders_snapshot`
   and the new `DP_Presentation.Fact_Parts_Open_Orders_Snapshot` — must
   match exactly for all 7 pre-existing months.
2. **`Fact_PartsInvoiced_ByBranch` correctness:** a DuckDB comparison
   between the new Gold table's output and the original native query's
   output (same `Branch`/`InvoiceDate`/`Invoiced_Parts` grain) over a
   shared date range, confirming the ported filter/exclusion logic
   produces identical results.
3. **Post-migration:** Brian's standard Desktop pull/refresh/publish/
   visually-confirm cycle, then Claude's standard post-publish DuckDB
   row-count check across all 6 backend tables.
4. **Pipeline cutover safety:** confirm the new monthly notebook's first
   real scheduled run (or a manual dry-run against the guard condition)
   before removing the old notebook from its pipeline — never remove the
   old one first.

## 5. What This Spec Deliberately Does Not Cover

- The report's own column-usage audit findings (which columns get
  trimmed per table) — that's real investigation work for the
  implementation plan, not this design.
- Any change to `Pipeline_Monthly_Open_Orders_Snapshot` beyond removing
  the one notebook activity — the pipeline itself isn't being redesigned.
- Reconciling "Open Parts Tickets" vs "Parts on Open Orders" naming
  anywhere outside this spec's own text.
