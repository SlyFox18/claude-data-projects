# MD Invoices With No Freight — Monthly Snapshot

**Date:** 2026-07-08
**Status:** Approved — ready for implementation plan
**Project:** `projects/md invoices with no freight - report/`

## Problem

The Open Orders page (`Fact_MDInvoices_NoFreight`) shows only currently-open MD (Machine Down) parts orders. Once an order closes/invoices, it drops out of this table — there is no way to answer "what did the open MD freight backlog look like on May 1st?" This mirrors a problem already solved for the Open Parts Tickets report via `nb_Snapshot_Parts_Open_Orders` / `Fact_Parts_Open_Orders_Snapshot` / `Pipeline_Monthly_Open_Orders_Snapshot`.

Closed Invoices (`Fact_MDInvoices_Closed`) does **not** need this treatment — it already has permanent history via `Insalpar_Audit`, which records every insalpar change including deletes.

## Goal

Stand up the same monthly-snapshot infrastructure for MD Invoices' open-order backlog: a Delta table that accumulates one full copy of the open-order detail on the 1st of every month, so trend analysis becomes possible once enough history exists. No trend page/visuals in this pass — infrastructure only, matching how Open Parts Tickets deferred its trend page until data existed.

## Non-Goals

- No trend page or new report visuals (deferred until 3+ months of snapshot history exist)
- No changes to the live Open Orders page, its measures, or its performance-tuning (`MissedFreightAmount`/`PctFreightDifference`/`FreightBucket` caching pattern)
- No backfill of historical months — snapshot history begins the first time the notebook runs (same limitation as Open Parts Tickets; the source table only reflects current state)
- No Fabric automation via `fab` CLI — the notebook and pipeline are created manually in the Fabric portal, following the established Open Parts Tickets precedent

## Design

### 1. Lakehouse table

New Delta table: **`Fact_MDInvoices_NoFreight_Snapshot`** in `LH_Master_Data`, append-only, one row per open order line per `SnapshotDate`.

### 2. Notebook

New notebook: **`nb_Snapshot_MDInvoices_NoFreight`**, following the same 4-cell structure as `nb_Snapshot_Parts_Open_Orders`:

1. **Setup** — `snapshot_date = date.today().replace(day=1)`, target table name.
2. **Duplicate guard** — checks whether a snapshot for this month's `SnapshotDate` already exists; skips if so (safe to rerun), handles "table doesn't exist yet" on first run.
3. **Read and write** — reads the live `Fact_MDInvoices_NoFreight` Lakehouse table via Spark SQL, selecting its 23 base (non-calculated) columns:

   `FileNumber, LineNumber, Branch, Franchise, CustomerNumber, OrderDate, CustomerOrderNumber, RONumber, PartNumber, OrderQty, UnitPrice, UnitCost, LineTotal, Weight, TotalLineWeight, TotalFreightCharged, FreightLineCount, FreightStatus, Salesperson, JobCode, SuppliedQty, BackorderQty, OrderType`

   None of these need backtick-quoting (unlike the Open Parts Tickets source, which had `#`/`$$` in column names). Adds `SnapshotDate` as a literal column, appends with `mergeSchema=true` via `saveAsTable`.
4. **Verification (optional/commented)** — a summary query grouping by `SnapshotDate` to spot-check row counts and totals across snapshot history.

**Explicitly excluded from the read:** `MissedFreightAmount`, `PctFreightDifference`, `FreightBucket` — these are DAX calculated columns that exist only in the semantic model, not in the Lakehouse Delta table, so the notebook has no access to them. They're recreated in the semantic model instead (see below).

### 3. Pipeline

New pipeline: **`Pipeline_Monthly_MDInvoices_Snapshot`** — runs the notebook on the 1st of each month at 5:30 AM CST, same slot as `Pipeline_Monthly_Open_Orders_Snapshot`. This is comfortably after the 4:15 AM master orchestrator finishes refreshing `Fact_MDInvoices_NoFreight` (Phase 4).

### 4. Semantic model

New table `Fact_MDInvoices_NoFreight_Snapshot` in the MD Invoices semantic model:

- **Partition:** `import` mode via the SQL Analytics Endpoint, same pattern as the other two fact tables in this model (`Sql.Database(...)` → `Source{[Schema="dbo",Item="Fact_MDInvoices_NoFreight_Snapshot"]}[Data]`).
- **Columns:** the 23 base columns plus `SnapshotDate`, typed to match the source table (`Fact_MDInvoices_NoFreight.tmdl` as the reference for dataType/formatString/summarizeBy per column).
- **Calculated columns:** `MissedFreightAmount`, `PctFreightDifference`, `FreightBucket` — recreated with identical formulas to `Fact_MDInvoices_NoFreight`'s versions. This is a third copy of the same logic; `Fact_MDInvoices_Closed` already duplicates these from `Fact_MDInvoices_NoFreight` rather than sharing them, so this follows the model's existing convention rather than introducing a new one. Document the three-way sync obligation clearly — if the freight-bracket formula changes again, all three tables need the update.
- **Relationships:**
  - `Fact_MDInvoices_NoFreight_Snapshot.Branch` → `dim_BranchLocation.BranchID`
  - `Fact_MDInvoices_NoFreight_Snapshot.SnapshotDate` → `dim_DateTable.Date` (active)
  - `OrderDate` stays present as a plain column but **not** related to `dim_DateTable` — avoids a second active relationship to the same date dimension from one table, matching how the Open Parts Tickets snapshot table only relates `SnapshotDate`, not `Order_Date`.
- **Desktop gotcha:** adding a brand-new TMDL table requires a Desktop close/reopen — hot-reload only picks up edits to existing tables, not new table files.

No new measures in this pass (deferred with the trend page).

### 5. Documentation

Update this project's `CLAUDE.md` and `PROJECT-SUMMARY.md` with a "Monthly Snapshot" section mirroring Open Parts Tickets' write-up: notebook name, target table, pipeline schedule, first-snapshot date, no-backfill caveat, and the three-way calculated-column sync note.

## Naming Summary

| Item | Name |
|---|---|
| Lakehouse table | `Fact_MDInvoices_NoFreight_Snapshot` |
| Notebook | `nb_Snapshot_MDInvoices_NoFreight` |
| Pipeline | `Pipeline_Monthly_MDInvoices_Snapshot` |
| Semantic model table | `Fact_MDInvoices_NoFreight_Snapshot` |

## Open Questions

None — all scoping questions resolved during brainstorming (snapshot grain = full detail, schedule = 1st @ 5:30 AM, trend page deferred, Fabric infra built manually via portal using prepared notebook code).
