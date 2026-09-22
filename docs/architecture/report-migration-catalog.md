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
| `Inventory Analysis` | Parts | **COMPLETE (2026-09-22).** Original plan below (new `dim_Date` Gold build) was superseded — see the completion note after this table. |
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
readiness, not by workspace or alphabetically. **Confirmed with Brian (2026-09-15)**:
sequence by real business impact too, not just migration readiness — start with the
*lowest*-impact reports (cross-referenced against `CLAUDE.md`'s real refresh-priority
tiers, a different classification than this doc's readiness tiers), prove the manual
repoint process and `fabric-cicd`/Variable Library deployment both work on low-stakes
reports, *then* move to the higher-impact ones.

### Batch 0 — 3 low-impact reports, manual repoint first, deployment tooling proven second — **COMPLETE (2026-09-16)**

| Report | Readiness tier | Refresh-priority tier (`CLAUDE.md`) | Why this one |
|---|---|---|---|
| `Bin Location Report` | Tier 2 (1 small gap) | 3 (weekly, lowest impact) | Simplest report in the whole catalog — 4 dims + 1 raw repoint with an existing shortcut |
| `Physical Inventory` | Tier 2 (1 small gap) | 2 (low impact) | Same shape, same 1 gap |
| `60+ Days Past Due` | Tier 2 (1 small gap) | 1 (daily, but only report in `RP - Financial Reports` — swapped in for `Unique Parts Customers` per Brian's own suggestion, 2026-09-15, since it proves the pattern across a 3rd workspace/data domain (AR, not parts) for near-zero extra risk) | Only report in `RP - Financial Reports` |

All 3 repointed, validated, published to `RP - Dev`, and confirmed live pointed at
`DP_Presentation`. Real bugs found and fixed along the way (see
`project_report_migration_batch0.md` in memory for full detail):
- `dim_Parts` had 3 rows (of 316,365) with a stray control character in `PartNumber`
  that survived normalization and created an invisible duplicate — root-caused to
  `F.trim()` only stripping literal spaces, not `\r`/`\t`; fixed in
  `Build_Gold_Parts.Notebook` with an explicit control-character strip, plus a new
  guard assertion.
- `Physical Inventory`'s M query used `DateTime.LocalNow()` for year-boundary counting
  logic — the same UTC-not-local bug class fixed 8+ times elsewhere in this project.
- A **new bug class** found on `60+ Days Past Due`: trimming a shared dimension's
  column list in the TMDL model *without* also restricting the M query itself
  (`Table.SelectColumns`) does not survive a Desktop refresh — Power Query
  auto-detects and silently re-adds any column the query can still return. Caught on
  `dim_CustomerList` (46→3 trim reverted to 43 on refresh, plus spawned an unwanted
  auto-detected relationship); fixed there and retroactively pinned on
  `dim_BranchLocation`/`dim_Franchise` across all 3 reports.
- `dim_DateTable` was completely unused (zero fields, zero relationships) in both
  `Physical Inventory` and `60+ Days Past Due` — removed entirely rather than migrated,
  in both cases confirmed with Brian first.

**New workflow established this batch**, now the standard going forward for any report
touched by this migration: the report's real working copy moves to
`fabric-workspace-docs/workspaces/RP - Dev/<Report>.pbip` (a `.pbip` Fabric's own Git
integration never creates, added manually — same pattern already used for Parts Promo/
Parts Adjustments) once first published there; the `data-projects` copy is archived
under `report(s)/archive/`, not edited again.

**Real, pre-existing infrastructure gap found and partially fixed while validating
this batch's promotion path**: `RP - Service Reports` and `RP - Financial Reports`
were both actually git-connected to the `dev` branch, not `main` as `CLAUDE.md`
documents — confirmed via the Fabric REST API, not assumed. Brian corrected both to
`main` directly in the portal (2026-09-16). `RP - Financial Reports` was low-risk —
`main`/`dev` content was identical there. `RP - Service Reports` surfaced a deeper,
separate, pre-existing problem: its live production content doesn't match *either*
git branch (old, unversioned report names live; `main` has newer "V2" versions;
`dev` additionally has `Customer Anatomy V2`/`Job Code Parts Advisor`/`Stock Check`
that never reached `main`) — production and git have been drifting independently
there, unrelated to today's fix, not yet resolved. Brian's own words: "the RP -
Service workspace needs to be cleaned up any way" — flagged as a real follow-up
before any deployment automation targets that workspace specifically.

Next: Variable Library + `fabric-cicd` deployment tooling, proven on these same 3
reports (and the DP backend's own Dev→Prod tier promotion, the other open gap
surfaced during Batch 0 — see `docs/architecture/data-platform-workspaces.md`'s
"Prod tier" section) before touching anything business-critical.

### Batch 1 — remaining Tier 1 reports (Customer Anatomy, Inspections, Price Matrix,
Negative On Hand, Parts Not Re-Ordered, Parts Adjustments, Planter Inspection Part
Sales, Stock Check)

The real pilot this project's original design spec called for, now de-risked by Batch
0. Repoint, validate column-by-column against each report's real measures/
relationships, fix whatever a real per-report audit turns up (same "verify, don't
assume" discipline as every prior batch). `Price Matrix` needs extra scrutiny given the
`Fact_Part_Transactions` redesign; `Inspections` needs the `IsPending` business-rule
flag carried forward clearly into the report layer, not just the backend notebook
comment.

**6 of 8 — COMPLETE (2026-09-21):** Negative On Hand, Parts Not Re-Ordered, Parts
Adjustments, Planter Inspection Part Sales, Stock Check, and Unique Parts Customers
(swapped in for this batch per Brian's own call) all repointed, validated, and live in
`RP - Dev` — see `docs/superpowers/plans/2026-09-21-report-migration-batch1.md`.
`Customer Anatomy` and `Inspections` deliberately deferred, held back for "special
care" per Brian's explicit instruction.

**`Price Matrix` — COMPLETE (2026-09-21), done separately from the rest of Batch 1**
per Brian's own choice (`docs/superpowers/plans/2026-09-21-price-matrix-migration.md`).
The "real report-level risk" flagged above was worse than this catalog's own audit
found: the `Fact_Part_Transactions` redesign's real-usage audit was itself wrong for
this report — it only checked visual-level field references, not DAX measure bodies,
and missed that 4 "matrix-pricing" columns (`EffectiveListSalVal`,
`EffectiveListMargin`, `MatrixSaleGained`, `MatrixMarginGained`) are genuinely used by
this report's own namesake measures. Fixed by restoring those 4 columns to the Gold
table (verified against real `EquipRDB` ground truth), then repointing + exhaustively
re-auditing + trimming the report itself. See
`docs/architecture/lh-master-data-facts-catalog.md`'s own corrected `Fact_Part_Transactions`
section for the full finding.

### Batch 2 — remaining Tier 2 reports (small gaps + raw-table repoints)

`dim_Date`, the `InMaster` shortcut, the snapshot table, then the raw-table repoints
(Open Work Orders, 60+ Days Past Due, Pin Capture, Transfers, Part Sales with Low
Margin). Each gap is small enough to fold into the same pass as its report.

**Batch 2a — 3 of 6, COMPLETE (2026-09-22):** Open Work Orders, Pin Capture, Part
Sales with Low Margin — the reports needing zero-to-minimal new backend work,
repointed and refreshed clean. See `docs/superpowers/plans/2026-09-22-report-migration-batch2a.md`
for the full real-finding trail. `InMaster`'s real gap was smaller than this
catalog's own original claim: `DP_Staging` already had a fully-built `Silver_InMaster`
(not just a raw shortcut) — only a `DP_Presentation`-side shortcut was needed, not
new backend work. 3 real refresh-blocking bugs found and fixed, none caught by the
standard audit alone:
- `dim_DateTable.IsPreviousMonth`/`IsRolling12Months` (Pin Capture) — deliberately
  dropped from the Gold table for baking in `DateTime.LocalNow()` at refresh time;
  restored as report-layer DAX calculated columns sourced from the report's own
  `Data Refresh` table instead.
- `RepairOrderDetail.WorkOrder`→`RONumber` and the `*Sale`→`*Revenue` column
  renames (Open Work Orders) — a real, silent schema drift from that table's own
  earlier Category C migration, unrelated to this batch, invisible to both
  existence and usage checks.
- `RepairOrderDetail.DaysSinceLastLabor` (Open Work Orders) — a real source column
  colliding with a calculated column of the same name.

A genuinely new audit blind spot was also found and fixed going forward: bookmark
filters can reference a column with zero visual or DAX-formula usage (caught on
Pin Capture's `IsRolling12Months`) — see `feedback_report_audit_bookmark_blindspot`
in memory. Part Sales with Low Margin refreshed clean but the data looked stale —
flagged for a full validation pass (including confirming the daily pipeline refresh
covers it) before production promotion, not blocking further report migrations.

**Inventory Analysis — COMPLETE (2026-09-22).** Real investigation superseded the
originally-planned new `dim_Date` Gold build: `dim_DateTable` (already live,
already used by every other migrated report) turned out to already have every
column this report needs under identical names, so the report's `dim_Date` table
was repointed to `dim_DateTable` instead — model table name kept as `dim_Date` so
none of the ~35 existing DAX measures or 2 relationships needed to change, only
the M query's source and column selection. See
`docs/superpowers/specs/2026-09-22-inventory-analysis-datetable-consolidation-design.md`
and `docs/superpowers/plans/2026-09-22-inventory-analysis-migration.md` for the
full design and exhaustive per-table audit trail. All 13 real data tables
repointed to `DP_Presentation`; 9 of them trimmed to confirmed-used columns
(Fact_Inventory, Fact_Invoice_InventoryAnalysis, dim_BranchLocation,
dim_CommodityCode, dim_Franchise, dim_ModuleType, dim_Parts, dim_PaymentMethod,
plus dim_Date itself), 4 left untrimmed (dim_DealerGroupCode, dim_SLC, dim_Source,
dim_VendorCode — every column genuinely used). Two `sortByColumn` dependencies
found and preserved (`dim_BranchLocation.LocationID`, `dim_ModuleType.SortOrder`),
matching the same discipline already applied to `dim_Date`'s own `Month` column.
Also found and fixed a real, previously-unflagged `DateTime.LocalNow()` bug live
in `Fact_Part_Transactions.tmdl`'s own rolling-7-year cutoff filter — same bug
class fixed repeatedly elsewhere in this project, replaced with the DST-aware
pattern from `.claude/queries/DATA-REFRESH-TEMPLATE.pq`. Refreshed clean in
Desktop and republished to `RP - Dev` by Brian; post-publish DuckDB row-count
check confirmed all 14 backend tables resolve with sensible counts. A pre-existing,
unrelated stale filter referencing a nonexistent `dim_Branch` entity (should be
`dim_BranchLocation`) was found in one visual and ~26 bookmarks — flagged for
Brian's awareness, not acted on since it predates this migration and isn't caused
by it. Full validation pass (beyond the spot-checks done here) still recommended
before production promotion, same standing caveat as the rest of Batch 2a/2.

Remaining for Batch 2: 60+ Days Past Due (already done in Batch 0, listed here in
error — confirm and remove), Transfers (needs `Fact_OutstandingTransfers`),
Parts on Open Orders / Open Parts Tickets (needs the snapshot table) — the 2
remaining reports genuinely needing new Gold-layer work, sequenced next per
Brian's own "one at a time, easiest first" call.

### Batch 3 — Tier 3 (4 reports needing real new Gold-layer work first)

`Fact_FirstPassFill` needs its own full audit-and-build; `dim_WkcdPart`/`dim_JobCodes`
needs investigation; Combine Vault Sales and Labor Performance both need their
already-known blockers resolved — same rigor as Batches A–D, not a shortcut.
