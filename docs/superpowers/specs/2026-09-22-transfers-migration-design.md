# Transfers Migration — Design Spec

## 1. Problem Statement

`Transfers` is the last remaining Batch 2 report — the most involved of the
three, per Brian's own "one at a time, easiest first" sequencing (Inventory
Analysis and Open Parts Tickets are both already complete).

The report-migration catalog described this as needing a new
`Fact_OutstandingTransfers` table built via a `Silver_InSalPar` +
`Silver_InSalOrd` + `Silver_InMaster` join, with a new
`Silver_InSalOrd.trf_to_branch` column and an "`OrderAge`-as-DAX-measure"
design decision cascading into a redesign of the dependent `'Aging Bucket'`
calculated column.

Real investigation (TMDL greps, `fab ls` against `DP_Presentation`, reading
the real production `df_Fact_Transfers.Dataflow`, and Brian pulling the real
`Parts_InterbranchTransfers` view SQL directly from SQL Central) found a
smaller, better-understood gap than the catalog described:

- **`Fact_Transfers`, `dim_BranchLocation`, `dim_DateTable`, `dim_Parts`**
  already exist in `DP_Presentation`, confirmed via `fab ls` — standard
  repoint-and-audit only, no new backend work.
- **`OrderAge` is already a real stored column** on the existing
  `LH_Master_Data.Fact_OutstandingTransfers` table and the report's own
  `'Aging Bucket'` calculated column already just buckets it with a plain
  `SWITCH(TRUE(), ...)` — the catalog's "OrderAge-as-DAX-measure" concern
  was a stale assumption made before anyone had found the real,
  already-built, already-documented `df_Fact_Transfers.Dataflow`. Nothing
  here needs redesigning.
- **The real `Parts_InterbranchTransfers` view SQL** (provided directly by
  Brian via SQL Central):
  ```sql
  ALTER VIEW "Administrator"."Parts_InterbranchTransfers"
        (SupplyingBranch,RequestingBranch,PartTicket,OrderQuantity,ShippedQuantity,InTransitQuantity,OrderAge) AS
   select distinct Isnull(par.branch,'') as SupplyingBranch,
          Isnull(ord.trf_to_branch,'') as RequestingBranch,
          Isnull(par.file_no,0) as PartTicket,
          Isnull(par.order_qty,0) as OrderQuantity,
          Isnull(par.shipped_qty,0) as ShippedQuantity,
          Isnull(inm.in_transit_qty,0) as InTransitQuantity,
          Datediff(dd,Isnull(ord.ord_date,'1900-01-01'),Getdate()) as OrderAge
     from Administrator.insalpar as par
     left outer join Administrator.inmaster as inm on inm.branch = par.branch and inm.franchise = par.franchise and inm.part_no = par.part_no
     left outer join Administrator.insalord as ord on ord.file_no = par.file_no
    where ord.type = 'T'
  ```
  Cross-referencing this against the real, already-migrated
  `Silver_InSalPar`/`Silver_InSalOrd`/`Silver_InMaster` schemas found the
  gap is genuinely small: every join key and most output columns already
  exist under matching names. Only 3 columns are missing from Silver —
  and all 3 already exist in the corresponding Bronze tables, just weren't
  selected into Silver yet:
  - `Silver_InSalPar.ShippedQty` ← Bronze `InSalPar.SHIPPED_QTY`
  - `Silver_InSalPar.SoRoRef` ← Bronze `InSalPar.SO_RO_Ref` (not in the
    view itself, but needed for the report's `TransferSubType`
    classification, confirmed via the production dataflow's own
    documented logic)
  - `Silver_InSalOrd.TrfToBranch` ← Bronze `InSalOrd.TRF_TO_BRANCH`
- **`OrderAge` is refresh-time-relative**, not a static stored value — the
  view computes `DATEDIFF(dd, ord_date, GETDATE())` live on every query.
  The source system's `GETDATE()` is a true on-prem SQL Anywhere server
  call (genuine US/Central local time, not UTC), so the ported Gold-layer
  computation needs to replicate true local "now," not a naive
  `datetime.now()` (same DST-aware fix pattern already used repeatedly
  elsewhere this project, e.g. Open Parts Tickets'
  `Build_Gold_PartsInvoicedByBranch.Notebook`).
- **`Inv_Snapshot`** (a 4th real data table in the report, not previously
  flagged) references the old `jdis_Part_Information` directly — needs a
  simple repoint to `Silver_PartInformation.Shortcut`, 4 matching columns,
  same rename pattern already used elsewhere this project.

Given the real gap is 3 additive, well-understood Silver-layer column
additions rather than a from-scratch reconstruction, Brian chose the
Silver-layer rebuild over a raw-ODBC Dataflow Gen2 port — keeping this
table consistent with the rest of the DP backend's layering rather than
introducing another direct-ODBC dependency.

## 2. Scope

**In scope:**
1. Add 3 columns to 2 existing Silver notebooks (`Build_Silver_InSalPar.Notebook`,
   `Build_Silver_InSalOrd.Notebook`) — pure additive `select()` changes,
   no transform logic, no change to existing columns or row counts.
2. Build `Build_Gold_OutstandingTransfers.Notebook` in `DP_Presentation`,
   faithfully replicating the real production `df_Fact_Transfers.Dataflow`'s
   `Fact_OutstandingTransfers` logic (both its two-step structure and every
   business rule: Branch-12 exclusion, `OpenQty`, `FulfillmentStatus`,
   `TransferSubType`), sourced entirely from Silver tables instead of raw
   ODBC.
3. Repoint the report's other 5 real data tables (`Fact_Transfers`,
   `dim_BranchLocation`, `dim_DateTable`, `dim_Parts`, `Inv_Snapshot`) to
   `DP_Presentation`, with the same exhaustive usage-audit-before-trim
   discipline used on every other report this project.
4. Register the new notebook in `deploy/dp_backend_scope.json` (daily
   cadence, matching `Fact_Transfers`' own real-time nature) so it runs
   inside the existing `Pipeline_DP_Daily_Refresh` — no new pipeline.

**Explicitly out of scope:**
- Any change to `Fact_Transfers` itself — already exists, already correct,
  already used; this migration only repoints the report's own reference.
- Any change to the real production `Parts_InterbranchTransfers` view or
  the old `LH_Master_Data.Fact_OutstandingTransfers`/`df_Fact_Transfers.Dataflow`
  — left running as-is, not touched, same "don't break what's still
  serving production" discipline as every prior migration.
- Reconstructing `'Aging Bucket'` or any other DAX in the report —
  confirmed unnecessary; `OrderAge` stays a plain stored column feeding
  the same existing calculated column, unchanged.
- A raw-ODBC Dataflow Gen2 alternative — considered and rejected once the
  real Silver gap turned out to be 3 trivial additions rather than a
  from-scratch rebuild.

## 3. Architecture

### 3.1 Silver-layer additions

Both notebooks (`DP - Staging - Dev/Build_Silver_InSalPar.Notebook`,
`Build_Silver_InSalOrd.Notebook`) already follow an identical, proven
pattern: `bronze = spark.read.table(...)`, a `.select()` of renamed
columns, a `silver_count == bronze_count` assertion, then a path-based
Delta write. Each gets exactly one more `.alias(...)` line added to its
existing `select()` call:
- `Build_Silver_InSalPar.Notebook`: add `F.col("SHIPPED_QTY").alias("ShippedQty")`
  and `F.col("SO_RO_Ref").alias("SoRoRef")`.
- `Build_Silver_InSalOrd.Notebook`: add `F.col("TRF_TO_BRANCH").alias("TrfToBranch")`.

No other line changes — the existing row-count assertion continues to
guarantee these are pure additive column selections, not row-affecting
transforms.

### 3.2 `Build_Gold_OutstandingTransfers.Notebook`

Mirrors the real production dataflow's own two-step design, translated to
PySpark against Silver tables instead of two raw ODBC queries:

**Step 1 — outstanding-ticket determination** (replicates the view + its
own grouping query): join `Silver_InSalPar` → `Silver_InMaster` (on
`Branch`+`Franchise`+`PartNumber`) → `Silver_InSalOrd` (on `FileNumber`,
filtered `OrderType = 'T'`), computing `SupplyingBranch` (= `Branch`),
`RequestingBranch` (= `TrfToBranch`), `PartTicket` (= `FileNumber`),
`InTransitQuantity` (= `InTransitQty`), and `OrderAge` (=
`DATEDIFF(dd, OrderDate, <DST-safe US/Central now>)`) — exactly matching
the view's own column list and null-handling. Filter to
`InTransitQuantity > 0`, then group by `PartTicket`/`RequestingBranch`/
`SupplyingBranch` with `MAX(OrderAge)`, matching the production
dataflow's own Step 1 SQL exactly.

**Step 2 — line-level detail** (replicates the production dataflow's own
Step 2 exactly): `Silver_InSalPar` directly, filtered
`ShippedQty > SuppliedQty`, carrying `LineNumber`, `PartNumber`,
`OrderQty`, `ShippedQty`, `SuppliedQty`, `SoRoRef`, `CreationDate`.

**Steps 3–11** — Branch-12 exclusion (`RequestingBranch`/`SupplyingBranch`
starting with `"12"`), the left join of Step 1 to Step 2 on `PartTicket`,
`OpenQty = ShippedQty - SuppliedQty`, `FulfillmentStatus`
(Pending/Partial/Shipped from `OrderQty` vs `ShippedQty`), text cleanup,
`TransferSubType` classification from `SoRoRef` (Stock/Work
Order/Counter/Unknown, identical numeric-range logic to `Fact_Transfers`),
`DateKey`/`Date` from `TransDatetime` — all ported verbatim from the real
production dataflow's own documented logic, just in PySpark instead of M.

Written via a path-based `.save("Tables/Fact_OutstandingTransfers")`
(matching this project's established `saveAsTable()`-casing-bug
avoidance), registered in `deploy/dp_backend_scope.json` as
`tier: gold, cadence: daily`.

### 3.3 Report-layer repoint

Once the Gold table is built and verified, the report itself gets the
same treatment as every prior migration this project: exhaustive
real-usage audit (`pbir` + DAX-grep + bookmark check +
`relationships.tmdl` cross-reference for hidden relationship-key usage)
across all 5 remaining real data tables (`Fact_Transfers`,
`dim_BranchLocation`, `dim_DateTable`, `dim_Parts`, `Inv_Snapshot`),
repoint each connection string to `DP_Presentation`, trim to
confirmed-used columns where confident, leave ambiguous columns
untouched. `Inv_Snapshot` additionally needs its `Item=` changed from
`jdis_Part_Information` to `Silver_PartInformation`. Brian confirms the
report isn't open in Desktop before Claude edits TMDL directly, matching
the established real-tool boundary.

## 4. Verification Plan

1. **Silver additions:** confirm `silver_count == bronze_count` still
   holds (the existing assertion) and spot-check the 3 new columns'
   values against a handful of known rows.
2. **`Fact_OutstandingTransfers` correctness:** compare the new Gold
   table's real output (row count, `MAX(OrderAge)`, per-ticket
   `OpenQty`/`FulfillmentStatus`) against a fresh pull of the real
   `Parts_InterbranchTransfers` view SQL + `InSalPar` against
   `LH_Master_Data` (or, if the view's still queryable directly, against
   the source system itself) — expect a close but not necessarily
   exact-to-the-row match, since `OrderAge`/outstanding-status are
   computed live and the two pulls won't run at the exact same instant.
3. **Post-migration:** Brian's standard Desktop pull/refresh/publish/
   visually-confirm cycle, then Claude's standard post-publish DuckDB
   row-count check across all 6 backend tables (`Fact_Transfers`,
   `Fact_OutstandingTransfers`, `dim_BranchLocation`, `dim_DateTable`,
   `dim_Parts`, `Silver_PartInformation`).

## 5. What This Spec Deliberately Does Not Cover

- The report's own column-usage audit findings (which columns get
  trimmed per table) — real investigation work for the implementation
  plan, not this design.
- Any change to the real production `Parts_InterbranchTransfers` view,
  `df_Fact_Transfers.Dataflow`, or the old `Fact_OutstandingTransfers`
  table in `LH_Master_Data` — all left running as-is.
- A cutover/retirement step for the old dataflow — unlike Open Parts
  Tickets' monthly snapshot notebook, `df_Fact_Transfers.Dataflow` also
  builds `Fact_Transfers` (already migrated separately) and may still
  serve other consumers; retiring it is out of scope for this report
  migration and would need its own separate investigation.
