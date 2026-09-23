# MD Invoices With No Freight Migration — Design Spec

## 1. Problem Statement

`MD Invoices With No Freight` is the second of 3 remaining Parts reports
Brian is working through (First Pass Fill complete, this one next, then
Combine Vault Sales), per his own "easiest first" sequencing.

Real investigation (TMDL greps, `fab ls` against `DP_Presentation`,
direct DuckDB row-count/date-range checks, full reads of the real
production notebooks) found 5 real backend gaps — more than the
catalog's original "2 small pieces missing" framing:

- **`Fact_MDInvoices_Closed` and `Fact_MDInvoices_NoFreight`** already
  exist in `DP_Presentation` with real build notebooks
  (`Build_Gold_MDInvoicesClosed.Notebook`, `Build_Gold_MDInvoicesNoFreight
  .Notebook`), but neither is registered in `deploy/dp_backend_scope.json`
  — the same never-registered-notebook bug class found 4+ times already
  this session. Confirmed via direct DuckDB comparison: both are stuck at
  `2026-09-09` (13 days stale vs. real production's `2026-09-22`).
- **`dim_DateTable`'s and `dim_Salesperson`'s own build notebooks**
  (`Build_Gold_DateTable.Notebook`, `Build_Gold_Salesperson.Notebook`)
  are *also* unregistered. Lower real risk — `dim_DateTable` is a fixed
  `2020-01-01`–`2030-12-31` evergreen calendar (staleness is moot),
  `dim_Salesperson` is 645 rows vs. production's 646 (negligible) — but
  the same fix is cheap and closes out the pattern.
- **`FreightCalculator` is genuinely missing** from `DP_Presentation`.
  Its real source, `LH_Master_Data/Notebooks/Freight Calculator Update
  .Notebook`, isn't database-derived at all — it loads a small,
  manually-maintained CSV (`FREIGHT CALCULATOR 2026 - UPDATED.csv`)
  uploaded to the Lakehouse's Files section, casts 4 rate-bracket
  columns, and writes it (with its own manual `saveAsTable()`-casing-bug
  workaround already baked in — a DROP TABLE + RENAME TABLE dance).
- **`Fact_MDInvoices_NoFreight_Snapshot` is genuinely missing.** Its
  real source, `LH_Master_Data/Notebooks/nb_Snapshot_MDInvoices_NoFreight
  .Notebook`, is the same monthly append-only snapshot pattern already
  built once this session for Open Parts Tickets — confirmed via direct
  DuckDB query: 3 real months of history exist in the old table
  (lowercase `fact_mdinvoices_nofreight_snapshot`, same
  `saveAsTable()`-casing-bug pattern), 5,492 rows total (July 1,636 /
  August 2,041 / September 1,815). The notebook's own header confirms 3
  DAX-calculated columns (`MissedFreightAmount`, `PctFreightDifference`,
  `FreightBucket`) live only in the semantic model, already present in
  the report's own `Fact_MDInvoices_NoFreight_Snapshot.tmdl` — no backend
  work needed for those 3.
- **`dim_DateTable`'s real column risk, confirmed directly this time**:
  this report's own `dim_DateTable.tmdl` currently carries the full
  62-column set, including ~48 "today-relative" columns
  (`IsCurrentMonth`, `IsRolling12Months`, `IsYearToDate`, etc.) — the
  real `DP_Presentation.dim_DateTable` only has 14 columns. Same
  confirmed risk class hit twice already this session (Pin Capture,
  First Pass Fill) — this spec builds in the cross-check from the start
  instead of discovering it via a failed Desktop refresh.
- **`dim_FreightPerformanceGroup`** and **`% Freight Difference
  Threshold`** both confirmed to have zero `Sql.Database` calls —
  calculated/parameter tables, not part of this migration.

## 2. Scope

**In scope:**
1. Register `Build_Gold_MDInvoicesClosed`, `Build_Gold_MDInvoicesNoFreight`
   (daily), `Build_Gold_DateTable`, `Build_Gold_Salesperson` (monthly) in
   `deploy/dp_backend_scope.json`; run each once to catch up.
2. Build `Build_Gold_FreightCalculator.Notebook` in `DP_Presentation`,
   uploading the same real CSV and faithfully porting the load/cast
   logic, via a path-based write.
3. Build `Build_Gold_MDInvoicesNoFreightSnapshot.Notebook`, faithfully
   porting the real monthly snapshot logic; one-time backfill of the 3
   real existing months; register monthly; disable the old
   `Pipeline_Monthly_MDInvoices_Snapshot` once the new notebook's guard
   logic is confirmed working (never disable the old one first).
4. Repoint the report's 8 real data tables (`Fact_MDInvoices_Closed`,
   `Fact_MDInvoices_NoFreight`, `Fact_MDInvoices_NoFreight_Snapshot`,
   `FreightCalculator`, `dim_BranchLocation`, `dim_CustomerList`,
   `dim_DateTable`, `dim_Franchise`, `dim_Parts`, `dim_Salesperson` — 10
   tables total), with the same exhaustive usage-audit-before-trim
   discipline used on every other report this project, and the
   `dim_DateTable` real-schema cross-check built in from the start.

**Explicitly out of scope:**
- Any change to the real production `Freight Calculator Update.Notebook`,
  `nb_Snapshot_MDInvoices_NoFreight.Notebook`, `Build_Gold_MDInvoicesClosed
  .Notebook`, or `Build_Gold_MDInvoicesNoFreight.Notebook` — all left
  running/as-is.
- `dim_FreightPerformanceGroup` and `% Freight Difference Threshold` —
  confirmed calculated-only, nothing to migrate.
- Combine Vault Sales — the last report in this batch, deliberately
  sequenced after this one.

## 3. Architecture

### 3.1 Registration fixes

Straightforward `deploy/dp_backend_scope.json` entries for all 4
already-built, already-correct notebooks — no code changes, just
wiring into the existing `Pipeline_DP_Daily_Refresh`/`Pipeline_DP_Monthly_Refresh`.
Each gets run once manually after registering to catch up to current
data immediately, rather than waiting for the next scheduled cycle.

### 3.2 `Build_Gold_FreightCalculator.Notebook`

Uploads `FREIGHT CALCULATOR 2026 - UPDATED.csv` to `DP_Presentation`'s
Files section (same file, re-uploaded — small, static, rarely changes),
reads it with the same schema inference + explicit casts
(`PartWeightFrom`/`PartWeightTo` as integer, `BaseRate`/
`AdditiveRatePerPound` as double), writes via
`.save("Tables/FreightCalculator")` (path-based, avoiding the casing bug
the original notebook works around manually).

### 3.3 `Build_Gold_MDInvoicesNoFreightSnapshot.Notebook`

One-time backfill script copies the 3 existing months (5,492 rows) from
`LH_Master_Data`'s lowercase `fact_mdinvoices_nofreight_snapshot` into a
new, proper-PascalCase `Fact_MDInvoices_NoFreight_Snapshot` in
`DP_Presentation`. The new monthly notebook then replicates the real
production logic exactly (same 22-column selection from
`Fact_MDInvoices_NoFreight`, same `SnapshotDate = 1st of current month`
rule, same duplicate-guard) but reads from the newly-registered
`DP_Presentation.Fact_MDInvoices_NoFreight` and appends to the new
snapshot table via the same path-based write pattern.

### 3.4 Report-layer repoint

Standard exhaustive real-usage audit (`pbir` + DAX-grep + bookmark check
+ `relationships.tmdl` cross-reference) across all 10 real data tables.
`dim_DateTable` gets an explicit extra step: cross-check every
DAX-confirmed-used column against the real 14-column
`DP_Presentation.dim_DateTable` schema before trimming — any genuinely
used "today-relative" column gets restored as a DAX calculated column
sourced from `'Data Refresh'[Date]`, replicating the exact original
logic from `LH_Master_Data/Dataflows/03 - Dimensions/df_Dim_Date
.Dataflow` (same pattern already proven twice this session).

## 4. Verification Plan

1. **Registration fixes**: row-count/max-date comparison for
   `Fact_MDInvoices_Closed`/`Fact_MDInvoices_NoFreight` against real
   production, confirming the 13-day gap is closed.
2. **`FreightCalculator`**: row-count and spot-check a few rate-bracket
   rows against the real production table.
3. **`Fact_MDInvoices_NoFreight_Snapshot`**: per-`SnapshotDate` row-count
   comparison between the old and new tables for the 3 backfilled
   months, exact match required (matching the same discipline already
   used on Open Parts Tickets' equivalent backfill).
4. **Post-migration**: Brian's standard Desktop pull/refresh/publish/
   visually-confirm cycle, then the standard post-publish DuckDB
   row-count check across all 10 backend tables.

## 5. What This Spec Deliberately Does Not Cover

- Combine Vault Sales — separate, later work in this same batch.
- Any change to `dim_FreightPerformanceGroup` or `% Freight Difference
  Threshold` — confirmed out of scope, calculated-only.
- A broader audit of every other already-migrated report's notebooks for
  the same registration gap — flagged as a real candidate follow-up
  project in the catalog doc, not undertaken here.
