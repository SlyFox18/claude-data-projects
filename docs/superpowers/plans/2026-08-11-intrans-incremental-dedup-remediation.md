# InTrans_Incremental Full Dedup — Remediation Plan

**Status:** ✅ COMPLETE (2026-08-11), downstream validation also now COMPLETE (confirmed
2026-09-03). `InTrans_Incremental` deduped 105,106,772 → 12,125,730 rows, zero data loss,
verified independently via Spark and DuckDB at every step. `df_Fact_Transfers` re-run
confirmed fixed: 4,507,042 rows / 5:20 duration, matching the 8/4 pre-incident baseline
(4,515,597 rows / 5:11) almost exactly. Every downstream fact table listed below has since
been individually confirmed with no damage. Backup table
`InTrans_Incremental_BACKUP_20260811_173538` can now be dropped (see Remaining Work below —
that step itself is not yet done).
**Owner:** Brian Fox, with Claude walking through step-by-step and verifying independently via DuckDB after each checkpoint.

## Post-mortem: the plan changed mid-execution

The dedup key originally planned here (`PARTITION BY TransId ORDER BY TransDatetime`,
treating `TransId` as a safe standalone primary key) turned out to be **wrong** and was
caught by the notebook's own Step 2 integrity check before any destructive action ran.
Two real findings, both confirmed independently before trusting either:

1. **`TransId` is not a safe standalone key across this table's full history.**
   299,971 `TransId` values are legitimately reused by the source system for different
   real transactions at different points in time (confirmed via Spark-native queries —
   e.g. TransId 3223768 = a real 2018 transaction and an unrelated real 2021 transaction
   sharing the same ID). A naive `TransId`-only dedup would have silently deleted one of
   every pair. Fix: partition by `(TransId, TransDatetime)` instead.
2. **49,245 groups still conflicted even at `(TransId, TransDatetime)` grain** — same
   transaction, same timestamp, genuinely different other-column values (real corrections
   applied years later, e.g. `Franchise` 'M'→'BS', `CustomerNo`/`BillToAcc` reassignments,
   `PartLineStatus` transitions). `ModifiedDate` (nulls treated as earliest) resolved all
   49,245 unambiguously — validated with zero remaining ties before use.

A third finding was a **false alarm**, worth recording since it nearly derailed the
investigation: an independent DuckDB cross-check appeared to show 10M+ TransIds with
inconsistent `TransDatetime`, wildly disagreeing with Spark's 299,971. Root cause: this
table has been rewritten by several different engines across its multi-year history
(the various rebuild/fix notebooks plus the original ODBC-loading dataflow), and DuckDB's
delta-kernel was applying a UTC-adjustment inconsistently across files with different
`isAdjustedToUTC` Parquet metadata, manufacturing a phantom second value shifted by
exactly 5-6 hours (the CDT/CST offset) for a large subset of rows. Spark's own reads were
self-consistent throughout and are what the final fix is based on. **Takeaway for future
sessions: don't trust DuckDB reads of this table's `TransDatetime` column for anything
that groups or compares values — plain row counts and `TransId`-only checks are fine.**

## Trigger

`Fact_Transfers` dataflow regressed from ~5 min / 4.5M rows (last good run 8/4) to
30+ min / 40M+ rows starting 8/6-8/7, plus a `MashupException.Error ... conflicting
protocol upgrade` (Lakehouse036/026) error on its destination table write.

## Root cause (confirmed)

`InTrans_Incremental` — the shared raw table 9+ fact tables read from, including
[Fact_Transfers.pq](../../../projects/transfers%20-%20report/queries/fact-tables/Fact_Transfers.pq)
— got duplicated ~9x on **8/5/2026**:

| | Value |
|---|---|
| Total rows | 105,106,772 |
| Distinct TransId | 11,825,759 |
| Duplicate rows | 93,281,013 |
| Ratio | 8.9x |

Duplication factor peaks sharply at 8 and 9 copies per `TransId` (10.5M TransIds at
exactly 9 copies, 1.2M at exactly 8) across the table's ENTIRE history
(2018-01-01 through 2026-08-05 12:48 PM) — everything from 8/6 forward is clean,
single-copy. `Fact_Transfers`'s 4.5M→40M inflation (8.96x) matches this ratio almost
exactly; it does a straight filter/select over `InTrans_Incremental` with no
aggregation, so it inherited the duplication 1:1.

**Mechanism:** [df_InTrans_Incremental](../../../.claude/queries/raw-tables/Raw_InTrans_Incremental.pq)
job history (via `fab api .../jobs/instances`) shows a cluster of ~10 abnormal
refresh invocations on 8/5 between 09:43 and 17:02 UTC (several Cancelled, a couple
Deduped, one that ran 51 minutes vs. the normal 2-3) — versus the routine twice-daily
cadence every other day. `InTrans_Incremental` is Append-only with no destination-side
dedup (`Key Columns: None` per pipeline docs); the within-batch
`Table.Distinct(Source, {"TransId"})` safeguard added after the Dec2025-Feb2026
incident only dedupes a single pull, not against rows already committed from a prior
run. The full-history span of the duplication (not just a recent window) points to
the watermark being reset to something very old — `2019-01-01` matches the literal
hardcoded value in
[Utilities_InTrans_Rebuild_Process.Notebook](https://app.fabric.microsoft.com)
(`LH_Master_Data/Utilities_InTrans_Rebuild_Process.Notebook`), whose documented
procedure is: drop the table, reset watermark to 2019-01-01, then manually refresh.
No backup table from 8/5 exists (only Dec 2025 and Jan 2026 ones), consistent with:
watermark reset took effect, but the table was **not** actually dropped, so every
retriggered refresh that day re-appended near-full history onto the still-populated
table.

Current `watermark_control` state confirms the incremental process self-corrected —
`LastLoadedDatetime` for `InTrans` is advancing normally today (2026-08-11).

## Scope

Any fact table sourced from `InTrans_Incremental` via pass-through/filter logic (not
`GROUP BY`) is currently reading ~9x inflated data:
- `Fact_Transfers` (Transfers report) — confirmed
- `Fact_InTrans_UniqueCustomers` (Unique Parts Customers)
- `Fact_LaborJobSummary` / `Fact_WorkOrderParts` (Inspections)
- `Fact_PartsAdjustment` (Parts Adjustments)
- `Fact_PartsNotReOrdered` (Parts Not Re-Ordered)
- `Fact_InTrans_AllPromo` (Parts Promo)

`Fact_Part_Transactions` (Inventory Analysis) has its own independent watermark
pipeline, not sourced from `InTrans_Incremental` — likely unaffected, worth a spot
check anyway.

The `conflicting protocol upgrade` error on `Fact_Transfers`'s own destination table
is treated as a secondary/plausible symptom of the same overloaded day (heavy Delta
log churn from repeated large appends/cancellations) — not independently confirmed,
lower priority, monitor after the dedup rather than actively chase.

## Remediation approach

Full-table dedup by `TransId` (the confirmed natural key), reusing the proven
staging-table + DELETE + INSERT pattern from `InTrans_Fix.Notebook`'s Dec2025-Feb2026
cleanup (its earlier `df.write.saveAsTable()`/`insertInto()` attempts hit catalog
issues on this specific table and were abandoned in favor of `spark.sql()`
CTAS/DELETE/INSERT). Unlike that prior incident, this one spans the table's entire
history, not one contaminated date range, so the fix is table-wide rather than
date-scoped.

Two safety checks added beyond the prior pattern:
1. **Byte-identical check** — confirm every duplicated `TransId`'s copies agree on
   every column (via a `sha2` hash) before collapsing to one row. Duplicates here are
   simple repeat-appends of the same source row, not conflicting updates, but this is
   verified rather than assumed.
2. **Freshness recheck** — `InTrans_Incremental` gets a scheduled append ~09:4x and
   ~16:0x UTC daily; re-check the live row count immediately before the destructive
   swap to make sure a scheduled refresh hasn't landed mid-procedure (which would
   silently drop those newly-appended real rows if the stale staging snapshot were
   swapped in as-is).

Notebook: `Utilities_InTrans_FullDedup_20260811.Notebook` (staged locally, deployed to
`LH_Master_Data` via `fab import` — kept out of `fabric-workspace-docs` until it's
been run and verified, since that repo syncs directly to production Fabric).

### Steps (run one cell at a time in Fabric, verify before continuing)

0. Record baseline: total rows, distinct TransId, min/max TransDatetime, current
   Delta version (for instant `RESTORE TABLE ... TO VERSION AS OF <N>` rollback).
1. Full backup: `CREATE TABLE InTrans_Incremental_BACKUP_<timestamp> AS SELECT * FROM InTrans_Incremental`.
   Verify row count matches baseline exactly.
2. Integrity check: confirm 0 `TransId` groups have conflicting (non-identical)
   column values across their duplicate copies.
3. Build staging table: one row per `TransId` via `ROW_NUMBER() OVER (PARTITION BY
   TransId ORDER BY TransDatetime)`. Verify staging count == distinct TransId count.
4. Freshness recheck: live table count must still equal the Step 0 baseline. If not,
   rebuild Steps 0/3/4 fresh before proceeding (Steps 1-2 don't need repeating).
5. **Checkpoint** — human confirms all of 1-4 passed before continuing.
6. `DELETE FROM InTrans_Incremental` (full). Verify 0 rows remain.
7. `INSERT INTO InTrans_Incremental SELECT ... FROM InTrans_Incremental_Staging`.
   Verify count matches staging.
8. Final verification: total==distinct TransId, min/max TransDatetime unchanged,
   spot-check sample TransId `5847975` (used throughout this investigation) now has
   exactly 1 copy.
9. Drop staging table. Keep the backup table until downstream validation is done.
10. Downstream refresh checklist (see Scope above) — re-run each dependent dataflow
    and confirm row counts/durations return to normal.

## Timing

Chosen deliberately after the 16:0x UTC scheduled refresh (confirmed via job
history) and well before the next 09:4x UTC one, to minimize collision risk with the
live incremental pipeline.

## Remaining work (downstream validation)

`InTrans_Incremental` itself is fixed and `Fact_Transfers` is confirmed back to
baseline. Still to check — any dataflow that already refreshed against the bloated
table needs a fresh re-run to pick up the corrected source:

- [x] `df_Fact_Transfers` (Transfers report) — confirmed 2026-08-11, 4,507,042 rows / 5:20
- [x] `df_Fact_InTrans_UniqueCustomers` (Unique Parts Customers) — confirmed by Brian, no damage
- [x] `Fact_LaborJobSummary` / `Fact_WorkOrderParts` (Inspections) — confirmed by Brian, no damage
- [x] `Fact_PartsAdjustment` (Parts Adjustments) — confirmed by Brian, no damage
- [x] `Fact_PartsNotReOrdered` (Parts Not Re-Ordered) — confirmed by Brian, no damage
- [x] `Fact_InTrans_AllPromo` (Parts Promo) — confirmed 2026-08-11, semantic model
      refresh back to 4:47 (was 20-22 min during the incident window, matching
      the pattern where the model's Fact_InTrans_AllPromo partition reads
      InTrans_Incremental directly and does a local Table.Distinct dedup — no
      dataflow buffer, so it was fully exposed to the 9x-inflated source).
      Bonus finding: this also cleared up an unrelated red herring — a Data
      Factory pipeline migration for this report went live the same day (8/5)
      the duplication started, which initially looked like the cause but
      wasn't (first new-pipeline run was already slow due to the bad data).
- [x] Spot check `Fact_Part_Transactions` (Inventory Analysis) even though it has its
      own independent watermark pipeline — confirmed by Brian, no damage (2026-09-03)
- [ ] Once all of the above are validated: drop `InTrans_Incremental_BACKUP_20260811_173538`
- [ ] Separately, consider whether the `Utilities_InTrans_FullDedup_20260811.Notebook`
      deployed to `LH_Master_Data` for this remediation should be committed into
      `fabric-workspace-docs` for a permanent record, or deleted from the workspace now
      that it's served its purpose (it was deliberately kept out of git during execution
      since that repo syncs straight to production Fabric)
