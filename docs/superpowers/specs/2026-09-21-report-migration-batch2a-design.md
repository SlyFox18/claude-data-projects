# Report Migration Batch 2a — Design Spec

## 1. Problem Statement

`docs/architecture/report-migration-catalog.md` lists 6 remaining Tier 2 reports
(small, well-understood gaps). Brian split this into two rounds: the 3 reports
needing zero-to-minimal new backend work first (this spec), then the 3 needing
real new Gold-layer builds (Inventory Analysis's `dim_Date`, Parts on Open
Orders' snapshot table, Transfers' `Fact_OutstandingTransfers`) as a later,
separate round.

This spec covers: **Open Work Orders** (`RP - Service Reports`), **Pin Capture**
(`RP - Parts Reports`), **Part Sales with Low Margin** (`RP - Parts Reports`).

The catalog's own per-report claims for these 3 were re-verified directly this
session (not trusted blindly — the same discipline that already caught 2 real,
business-critical gaps in this project, in `dim_RepairOrder` and
`Fact_Part_Transactions`). All 3 held up on the "what already exists" question, but
real, non-obvious nuances were found on exactly *how* to repoint 2 of them.

## 2. Scope

**In scope — 3 reports, all pure repoint work (no new Gold-layer builds):**

1. **Open Work Orders** — `Fact_OpenWorkOrders.tmdl` reads 3 raw source tables via
   local M parameters (`SqlEndpoint`/`DatabaseName`, not the usual inline literal):
   `RepairOrderDetail` (its `DP_Presentation` shortcut kept the same name — no
   `Item=` rename needed), `TechnicianPunchedDetail` (rename `Item=` to
   `Silver_TechnicianPunchedDetail`), `WKROFILE` (rename `Item=` to
   `Silver_WkRoFile`). Plus `dim_BranchLocation`, `dim_CustomerList`,
   `dim_DateTable` (standard repoints). `dim_AgingBucket` is a pure DAX
   `DATATABLE` literal — no SQL source, not part of this migration at all.
2. **Pin Capture** — `Fact_PinTransactions.tmdl` reads raw `InTrans_Incremental`
   (rename `Item=` to `Silver_InTrans`) and `wkothsub` (rename `Item=` to
   `Silver_WkOthSub`). Plus `dim_BranchLocation`, `dim_CustomerList`,
   `dim_DateTable`, `dim_Parts` (standard repoints).
3. **Part Sales with Low Margin** — `Fact_InTrans.tmdl` reads raw
   `InTrans_Incremental` (rename to `Silver_InTrans`). `dim_Parts_LowMargin.tmdl`
   merges two raw sources: `InMaster` (rename to `Silver_InMaster` — see the real
   finding below) and `jdis_Part_Information` (rename to `Silver_PartInformation`,
   same rename already used for Parts Adjustments in Batch 1). Plus
   `dim_BranchLocation`, `dim_CustomerList`, `dim_DateTable`, `dim_Parts`
   (standard repoints).

**Real finding that changes the catalog's own framing:** the catalog said
`InMaster` "has no shortcut into `DP_Presentation` yet... needs a new shortcut."
Confirmed directly: `DP_Staging` already has a fully-built `Silver_InMaster` table
(not just a raw passthrough shortcut) with all 5 columns
`dim_Parts_LowMargin.tmdl` needs (`PartNumber`, `Franchise`, `Branch`,
`LowMarginFlag`, `StockOrderPrice`) — zero column gap. The only missing piece is a
`DP_Presentation`-side OneLake shortcut into that already-built table, the same
"shortcuts, not copies" mechanical step already used repeatedly in this project
(a portal action, not new backend build work). `Silver_PartInformation` was
similarly confirmed to have all 9 columns `dim_Parts_LowMargin.tmdl` needs from
`jdis_Part_Information` (`ListPrice`, `SellPrice1`, `Cost`, `QuantityOnHand`,
`BulkBinQty`, `InventoryCost`, plus the 3 shared join keys) — zero gap there
either.

**Explicitly out of scope:**
- Inventory Analysis, Parts on Open Orders, Transfers — the 3 reports needing
  real new Gold-layer work, deliberately deferred to a later round.
- Customer Anatomy, Inspections — deliberately held back by Brian, unrelated to
  this round.

## 3. Architecture

Same proven workflow as every prior batch this project: Brian publishes each
report as-is to `RP - Dev` first (clean baseline, production stays untouched as
fallback) — **already done for all 3** as of this spec. Confirmed not open in
Desktop. Claude now does, per report:

1. **New shortcut** (Part Sales with Low Margin only): Brian adds a
   `Silver_InMaster` OneLake shortcut in `DP_Presentation`, pointing at
   `DP_Staging`'s already-built `Silver_InMaster` table — same mechanism as every
   other Silver shortcut already in `DP_Presentation`.
2. **Exhaustive real-usage audit**: `pbir fields list` (visual-level) AND a full
   DAX-text grep across every measure table plus `relationships.tmdl`, per
   report — the same two-tool combination that already caught 2 real gaps this
   session. Confirms which dimension columns are genuinely used (candidates for
   the same kind of trim already done in Batch 1) and surfaces anything the
   quick investigation above might have missed.
3. **Repoint + rename**: swap the `Sql.Database(...)` connection on every table,
   renaming `Item=` values from raw table names to their real Silver shortcut
   names where applicable (per the table above — most tables are a simple 1:1
   name match, a few need the rename).
4. **Known bug-class checks** on each report: `DateTime.LocalNow()` (fix per
   `.claude/queries/DATA-REFRESH-TEMPLATE.pq`, watching for the query-folding
   pitfall found on Price Matrix if it's used inside a `Table.SelectRows` filter
   against a live SQL table), raw `PartNumber`-text joins (vs `PartNumberKey`
   surrogate — `dim_Parts` control-character exposure risk), and any `sortByColumn`
   that a column trim might dangle.
5. **Trim** genuinely-unused dimension columns per the audit, with matching
   `Table.SelectColumns` M-query pins (the Batch 0 lesson).

## 4. Verification Plan

Post-publish DuckDB row-count/spot-check against the real `DP_Presentation`
tables for each report, same pattern as every prior batch. Since none of these 3
reports need new Gold-layer logic (unlike `dim_RepairOrder`/`Fact_Part_Transactions`),
no new ground-truth-against-`EquipRDB` verification script is needed here — the
underlying Gold tables (`Silver_InTrans`, `Silver_WkOthSub`,
`Silver_TechnicianPunchedDetail`, `Silver_WkRoFile`, `RepairOrderDetail`,
`Silver_InMaster`, `Silver_PartInformation`) are all already-proven, already-live
tables reused as-is.

Plus Brian's own visual confirmation of each refreshed report in Desktop against
its real, currently-live production output, matching the established three-way
check used throughout this project.

## 5. What This Spec Deliberately Does Not Cover

- Any new Gold-layer table build (deferred to the next round: `dim_Date`,
  `fact_parts_open_orders_snapshot`, `Fact_OutstandingTransfers`).
- Any change to `Silver_InMaster`'s or `Silver_PartInformation`'s own build
  logic — both already correct and complete for this report's needs.
- Customer Anatomy, Inspections — unrelated, deliberately deferred by Brian.
