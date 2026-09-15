# Report Migration Catalog — LH_Master_Data → DP Backend

**Status:** Scoping pass complete (2026-09-15). Not yet started — no report has been
repointed to the DP backend yet, including the original design spec's own pilot
candidate (Parts Promo, still sitting in `RP - Dev`/`RP - Sandbox`, never promoted to
production).

## Why this phase, and what "migration" means here

The original design spec (`docs/superpowers/specs/2026-09-04-jd-bronze-data-platform-redesign-design.md`)
called for repointing each report's semantic model from `LH_Master_Data` to the new
`DP_Presentation` gold layer, one report at a time, after a pilot validation. The dims,
facts, and Customer Anatomy backend work (Batches A–D, all complete and verified) is
that gold layer. This catalog is the ground-truth scoping pass for the phase the design
spec called "6. Once proven, pick the next report to migrate."

**Real, non-obvious finding that changes the shape of this work**: throughout the whole
backend build, every dimension/fact table was deliberately built under its *exact* real
LH_Master_Data table name (not a new naming scheme) — a consistent choice made without
this phase specifically in mind, but it means most reports' Power Query M source
references (`Item="TableName"`) already match a real table that exists in
`DP_Presentation` today. For most reports, migration is closer to "repoint the SQL
connection + verify column-level parity" than "rebuild the report" — **except** where a
Batch A–D audit deliberately changed a table's shape (documented per-report below).

## Method

For each of the 23 real production semantic models (`RP - Parts Reports` 15,
`RP - Service Reports` 7, `RP - Financial Reports` 1 — one of the 15,
`Table-Column-Names-Search`, is an internal dev utility, not a real report, excluded
below), extracted every real M-query source table reference
(`Source{[Schema="dbo",Item="X"]}` pattern) from its `.tmdl` table files and
cross-checked each against the authoritative live `DP_Presentation` table list (`fab ls`,
2026-09-15 — not assumed from memory).

## Readiness tiers

### Tier 1 — fully ready (every real dependency already exists in DP_Presentation)

| Report | Workspace | Real dependencies (all present) |
|---|---|---|
| `Unique Parts Customers` | Parts | `Fact_InTrans_UniqueCustomers`, `Fact_Invoice_UniqueCustomers`, `dim_BranchLocation`, `dim_CustomerList`, `dim_DateTable`, `dim_UniqueCustomers` |
| `Customer Anatomy V2` | Service | All 9 Batch D tables + `dim_BranchLocation`, `dim_CustomerList`, `dim_DateTable`, `dim_Parts`, `lookup_UniqueCustomers_Invoice` |
| `Planter Inspection Part Sales - V2` | Service | `Fact_PlanterInspectionParts`, `Fact_PlanterInspections`, `Fact_PlanterInvoiceAllParts`, `Fact_PlanterPartSales`, `dim_BranchLocation`, `dim_CustomerList`, `dim_DateTable`, `dim_Parts` |
| `Stock Check` | Service | `Fact_InternalWorkOrders`, `dim_BranchLocation`, `dim_DateTable`, `dim_Salesperson` |
| `Price Matrix` | Parts | `Fact_Inventory`, `Fact_Part_Transactions`, `dim_BranchLocation`, `dim_DateTable`, `dim_DealerGroupCode`, `dim_Franchise`, `dim_Parts`, `dim_SLC`, `dim_Source`, `dim_VendorCode` — **real report-level risk**: `Fact_Part_Transactions` was redesigned (13 columns, down from 40+) based on this report's own real usage during Batch C — needs its own real validation, not just a connection swap |
| `Negative On Hand-On Hand No Bin` | Parts | `Fact_NegativeOnHand_OnHandNoBin`, `dim_BranchLocation`, `dim_DateTable` |
| `Parts Not Re-Ordered 24 Hours` | Parts | `Fact_PartsNotReordered`, `dim_BranchLocation`, `dim_DateTable` |
| `Parts Adjustments` | Parts | `Fact_AdjPairs_Summary`, `Fact_AdjustmentPairs`, `Fact_PartsAdjustments`, `dim_AdjustmentType`, `dim_BranchLocation`, `dim_DateTable`, `dim_Parts` (+ `jdis_Part_Information` raw ref — `Silver_PartInformation` shortcut already exists) |
| `Inspections - V2` | Service | `Fact_LaborJobSummary`, `Fact_PendingInspections`, `Fact_ServiceRecommendations`, `Fact_WorkOrderParts`, `dim_BranchLocation`, `dim_CustomerList`, `dim_DateTable`, `dim_Parts` — **flagged**: `Fact_LaborJobSummary.IsPending` is confirmed permanently `False` in production itself (ported faithfully per Brian's own call in Batch B); a real business-rule fix still needed before this report's pending-count visuals are trustworthy, independent of the migration itself. `Table3` reference (`Inspection Goals.tmdl`) needs a quick look — likely a disconnected manual-entry table, not a real Gold dependency |

**9 reports, the most-used ones in the whole portfolio** (Customer Anatomy, Inspections,
Unique Parts Customers, Price Matrix) are in this tier.

### Tier 2 — small, well-understood gaps (raw-table repoints with an existing Silver
shortcut, or one small missing piece)

| Report | Workspace | Gap |
|---|---|---|
| `Bin Location Report` | Parts | Only gap is `jdis_Part_Information` (raw) → `Silver_PartInformation` (shortcut exists) |
| `Physical Inventory` | Parts | Same — only real dependency is the `jdis_Part_Information` raw repoint |
| `Inventory Analysis` | Parts | **Real gap found this pass**: references `dim_Date`, a genuinely different (simpler) table than `dim_DateTable` — both are built by the *same* production dataflow (`df_Dim_Date.Dataflow`), but only `dim_DateTable` was carried into the DP backend during the dims catalog work. `dim_Date` itself is small (basic year/month/day/quarter columns, no rolling-period logic) — a quick Gold build, not a redesign. Every other dependency (`Fact_Inventory`, `Fact_Invoice_InventoryAnalysis`, `Fact_Part_Transactions`, 7 dims) already exists. |
| `Parts on Open Orders` | Parts | `Fact_Parts_Open_Tickets`/`_Details` are ready; missing `fact_parts_open_orders_snapshot` (the separate monthly-snapshot notebook table, `nb_Snapshot_Parts_Open_Orders` — a different, smaller piece of work than the main facts) |
| `Transfers` | Parts | `Fact_Transfers` is ready; missing `Fact_OutstandingTransfers` — already deliberately deferred in Batch B (real path known: `Silver_InSalPar`+`Silver_InSalOrd`+`Silver_InMaster`, needs a new `Silver_InSalOrd.trf_to_branch` column and an `OrderAge`-as-DAX-measure design decision) |
| `Open Work Orders` | Service | All raw refs (`RepairOrderDetail`, `TechnicianPunchedDetail`, `WKROFILE`) already have real Silver shortcuts (`RepairOrderDetail.Shortcut`, `Silver_TechnicianPunchedDetail.Shortcut`, `Silver_WkRoFile.Shortcut`) — needs column-rename repoints, not new Gold builds |
| `60+ Days Past Due` | Financial | Same pattern — `ArMaster_Customer`/`armaster` raw refs already have Silver shortcuts (`Silver_ArMasterCustomer.Shortcut`, `Silver_ArMaster.Shortcut`); `Fact_InSalOrd_InSalPar` already ready |
| `Pin Capture` | Parts | Raw refs (`InTrans_Incremental`, `wkothsub`) have real Silver shortcuts (`Silver_InTrans`, `Silver_WkOthSub`) already in `DP_Presentation` |
| `Part Sales with Low Margin` | Parts | Reads `InMaster` + `InTrans_Incremental` directly (matches the real `LowMarginFlag` business context found during the raw-sources catalog work) — `InTrans_Incremental`'s Silver equivalent exists; `InMaster` has **no shortcut into `DP_Presentation` yet** even though the raw table itself was migrated to `DP_Staging` back in the raw-sources catalog phase — needs a new shortcut, not new Gold-layer work |

### Tier 3 — real gaps, needs new Gold-layer work before migration is possible

| Report | Workspace | What's missing |
|---|---|---|
| `First Pass Fill` | Parts | `Fact_FirstPassFill` was never built — **a real miss from the original facts catalog audit**, not caught until this report-level cross-check. Needs its own audit-and-build pass like every other fact table got. |
| `Job Code Parts Advisor` | Service | References `dim_JobCodes` (plural — confirmed via direct check this is NOT what `df_Dim_JobCode.Dataflow` produces, which writes `dim_JobCode` singular, already built) and `dim_WkcdPart` (a real, separate dataflow, `df_Dim_WKCDPART.Dataflow`, never audited or built). Needs investigation: is `dim_JobCodes` a stale/legacy reference this report should just repoint to `dim_JobCode`, or a genuinely different table? |
| `Combine Vault Sales` | Parts | `Fact_Branch12_Transactions` + `dim_Branch12_Parts` — already known, deliberately deferred in both the dims and facts catalog work (circular dependency between the two, needs a real build-order decision) |
| `Labor Performance V2` | Service | `TechnicianAttendance`/`TechnicianEfficiency`/`TechnicianPunchedTime` — Category B (Technician-family) raw sources were decoded early in this project but their Gold-layer facts were deliberately deferred; this is that deferred work coming due |

## Proposed approach

Mirrors the dims/facts precedent that's worked well throughout this project: batch by
readiness tier, not by workspace or alphabetically, so the earliest work is also the
lowest-risk and highest-value (Customer Anatomy and Inspections are both in Tier 1).

1. **Batch 1 — Tier 1 (9 reports)**: the real pilot this project never got to. Repoint,
   validate column-by-column against each report's real measures/relationships, fix
   whatever a real per-report audit turns up (same "verify, don't assume" discipline as
   every prior batch). `Price Matrix` needs extra scrutiny given the `Fact_Part_Transactions`
   redesign; `Inspections` needs the `IsPending` business-rule flag carried forward
   clearly into the report layer, not just the backend notebook comment.
2. **Batch 2 — Tier 2 (9 reports)**: small, well-understood gaps first (`dim_Date`,
   the `InMaster` shortcut, the snapshot table), then the raw-table repoints. Each is
   small enough to fold into the same batch as its report.
3. **Batch 3 — Tier 3 (4 reports)**: real new Gold-layer work first (`Fact_FirstPassFill`
   needs its own full audit-and-build; `dim_WkcdPart`/`dim_JobCodes` needs investigation;
   Combine Vault Sales and Labor Performance both need their already-known blockers
   resolved) — same rigor as Batches A–D, not a shortcut.

**Not addressed by this catalog, real open questions from the design spec itself**:
Variable Library parameterization and `fabric-cicd` deployment adoption (Section 5 of
the design spec) — whether these are needed *before* Batch 1 starts or can be layered in
once a few reports are proven manually repointed is a real decision, not resolved here.
