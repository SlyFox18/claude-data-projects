# First Pass Fill Migration — Design Spec

## 1. Problem Statement

`First Pass Fill` is the first of 3 remaining Parts reports Brian wants to
migrate next (First Pass Fill, then MD Invoices With No Freight, then
Combine Vault Sales), per his own "easiest first" sequencing.

The report-migration catalog flagged this as needing real new Gold-layer
work: `Fact_FirstPassFill` was never built in `DP_Presentation` — "a real
miss from the original facts catalog audit."

Real investigation (full read of the production
`LH_Master_Data/Dataflows/04 - Facts/First Pass Fill/df_Fact_First_Pass_Fill.Dataflow/mashup.pq`,
cross-referenced against `Silver_InHist_PmManage`'s real schema via direct
DuckDB `DESCRIBE`) found this is a clean, low-risk gap:

- **`dim_BranchLocation`, `dim_DateTable`, `dim_JobCode`, `dim_Parts`**
  already exist in `DP_Presentation`, confirmed via `fab ls` — standard
  repoint-and-audit only.
- **`Fact_FirstPassFill`'s one real dependency, `Silver_InHist_PmManage`,
  is already fully migrated** (both Bronze `InHist_PmManage.Shortcut` and
  Silver exist in `DP_Staging`) — confirmed via direct schema check that
  every single column the real transform references (`PeriodDate`,
  `Branch`, `PartNumber`, `JobCode`, `JobType`, `Franchise`,
  `StockedIndicator`, and all 15 `Internal*`/`Parts*`/`Workshop*`
  attempt/success metric columns) already exists under identical names.
  This is pure Gold-layer work — no Silver-layer additions needed at all
  (unlike Transfers, which needed 3).
- **No refresh-time-relative computation** anywhere in the real
  transform — unlike Transfers' `OrderAge`, there's no
  `DateTime.LocalNow()`/`GETDATE()`-style bug class risk here to guard
  against.
- The report's other 8 table files (`Data Refresh`, `Date_Supplemental`,
  `MeasuresTable`, `Metric Names`, `Performance Metrics`,
  `TBL Time Period`, `Time Granularity Table`, `Time Period Table`) are
  all confirmed calculated/parameter tables with zero `Sql.Database`
  calls — not part of this migration.

## 2. Scope

**In scope:**
1. Build `Build_Gold_FirstPassFill.Notebook` in `DP_Presentation`,
   faithfully replicating the real production dataflow's logic — sourced
   from `Silver_InHist_PmManage` instead of the raw lakehouse table.
2. Register it in `deploy/dp_backend_scope.json` (`tier: gold,
   cadence: daily`) from the start — registered at build time, not
   discovered missing later (this project has now hit the
   never-registered-notebook gap 4 times this session; this design
   closes it out proactively for this one).
3. Repoint the report's 5 real data tables (`Fact_FirstPassFill`,
   `dim_BranchLocation`, `dim_DateTable`, `dim_JobCode`, `dim_Parts`) to
   `DP_Presentation`, with the same exhaustive usage-audit-before-trim
   discipline used on every other report this project.

**Explicitly out of scope:**
- Any change to `Silver_InHist_PmManage` itself — already correct,
  already complete, no additions needed (confirmed via direct schema
  check, not assumed).
- Any change to the real production `df_Fact_First_Pass_Fill.Dataflow`
  or the old `LH_Master_Data.Fact_FirstPassFill` — left running as-is.
- MD Invoices With No Freight and Combine Vault Sales — the other 2
  reports in this batch, deliberately sequenced after this one.

## 3. Architecture

`Build_Gold_FirstPassFill.Notebook` (new, under
`DP - Presentation - Dev/Fact Tables/First Pass Fill/`), in PySpark,
ports the real production M-query's 8 steps directly:

1. **Dimensional key lookups**: left-join `Silver_InHist_PmManage` to
   `dim_DateTable` (on `PeriodDate` = `Date`, pulling `DateKey` as
   `PeriodDateKey`), `dim_BranchLocation` (on `Branch` = `BranchID`,
   pulling `BranchKey`), `dim_Parts` (on `PartNumber`, pulling
   `PartNumberKey`), `dim_JobCode` (on `JobCode`, pulling `JobCodeKey`).
2. **Missing-key handling**: any unmatched join defaults its key to
   `-1`, matching the real source's own "maintain grain, flag data
   quality" convention (same pattern already used elsewhere in this
   project).
3. **Null-safe rates**: `InternalFirstPassRate`, `Internal24HourRate`,
   `PartsFirstPassRate`, `Parts24HourRate`, `WorkshopFirstPassRate`,
   `Workshop24HourRate` — each `successes / attempts` if `attempts > 0`,
   else `null`.
4. **Composite metrics**: `Counter*` (Internal + Parts) and `Total*`
   (Internal + Parts + Workshop) attempts/successes/rates, plus
   `CounterServiceRate`/`TotalServiceRate` (first-pass + transfer
   successes over attempts) — same null-safe pattern.
5. **Business flags**: `MeetsCounterTarget` (`CounterFirstPassRate >=
   0.80`), `MeetsTotalTarget` (`TotalFirstPassRate >= 0.85`),
   `HasAnyActivity` (`TotalFirstPassAttempts > 0`), `StockImpactFlag`
   (`"Stocked Part"` / `"Non-Stocked Part"` from `StockedIndicator`).
6. Write via a path-based `.save("Tables/Fact_FirstPassFill")` (matching
   this project's established `saveAsTable()`-casing-bug avoidance).

Report-layer repoint follows the same proven pattern as every prior
report this project: exhaustive real-usage audit (`pbir` + DAX-grep +
bookmark check + `relationships.tmdl` cross-reference), repoint each
connection string, trim to confirmed-used columns where confident, leave
ambiguous columns untouched. Brian has already confirmed the report is
published to `RP - Dev`, committed, and not open in Desktop.

## 4. Verification Plan

1. **Gold table correctness**: row-count and aggregate comparison (sum
   of each attempt/success metric, sample rate values) between the new
   `DP_Presentation.Fact_FirstPassFill` and the real
   `LH_Master_Data.Fact_FirstPassFill`.
2. **Post-migration**: Brian's standard Desktop pull/refresh/publish/
   visually-confirm cycle, then the standard post-publish DuckDB
   row-count check across all 5 backend tables.

## 5. What This Spec Deliberately Does Not Cover

- MD Invoices With No Freight and Combine Vault Sales — separate,
  later work in this same batch.
- Any change to `Silver_InHist_PmManage`'s own build or schema.
- Any redesign of the report's own DAX/measures layer — the Gold
  table's pre-calculated rates and flags are ported as-is, matching the
  real production design's own stated intent ("eliminates complex DAX").
