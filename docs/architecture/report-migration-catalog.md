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
| `Open Parts Tickets` (real name — catalog previously called this "Parts on Open Orders") | Parts | **COMPLETE (2026-09-22).** Original plan below (single missing snapshot table) was superseded — see the completion note after this table. |
| `Transfers` | Parts | **COMPLETE (2026-09-23).** Original plan below (Silver_InSalOrd.trf_to_branch + OrderAge-as-DAX-measure) was overstated — see the completion note after this table. |
| `Open Work Orders` | Service | All raw refs (`RepairOrderDetail`, `TechnicianPunchedDetail`, `WKROFILE`) already have real Silver shortcuts (`RepairOrderDetail.Shortcut`, `Silver_TechnicianPunchedDetail.Shortcut`, `Silver_WkRoFile.Shortcut`) — needs column-rename repoints, not new Gold builds |
| `60+ Days Past Due` | Financial | Same pattern — `ArMaster_Customer`/`armaster` raw refs already have Silver shortcuts (`Silver_ArMasterCustomer.Shortcut`, `Silver_ArMaster.Shortcut`); `Fact_InSalOrd_InSalPar` already ready |
| `Pin Capture` | Parts | Raw refs (`InTrans_Incremental`, `wkothsub`) have real Silver shortcuts (`Silver_InTrans`, `Silver_WkOthSub`) already in `DP_Presentation` |
| `Part Sales with Low Margin` | Parts | Reads `InMaster` + `InTrans_Incremental` directly (matches the real `LowMarginFlag` business context found during the raw-sources catalog work) — `InTrans_Incremental`'s Silver equivalent exists; `InMaster` has **no shortcut into `DP_Presentation` yet** even though the raw table itself was migrated to `DP_Staging` back in the raw-sources catalog phase — needs a new shortcut, not new Gold-layer work |

### Tier 3 — real gaps, needs new Gold-layer work before migration is possible

| Report | Workspace | What's missing |
|---|---|---|
| `First Pass Fill` | Parts | **COMPLETE (2026-09-23).** Original plan below (needs its own audit-and-build pass) was executed — see the completion note after the Batch 3 intro below. |
| `Job Code Parts Advisor` | Service | **COMPLETE (2026-09-24).** Backend built (`dim_JobCodes`, `dim_WkcdPart`, both fact tables), report repointed and published. Hit a real unresolved `dim_JobCodes` refresh bug along the way — see the completion note after the Batch 3 intro below. |
| `Combine Vault Sales` | Parts | **COMPLETE (2026-09-23).** Circular dependency resolved via a hash-based `PartNumberKey` — see the completion note after the Batch 3 intro below. |
| `Labor Performance` | Service | **COMPLETE (2026-09-24).** Backend built (`dim_Technician_Code_Names`, `TechnicianAttendance`, `TechnicianPunchedTime`, `TechnicianEfficiency`), report repointed and published. Renamed from "Labor Performance V2" during evaluation to its permanent name — see the completion note after the Batch 3 intro below for the real bugs found and fixed along the way. |

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

**Open Parts Tickets — COMPLETE (2026-09-22).** Real investigation found the
catalog's original single-gap description ("missing `fact_parts_open_orders_snapshot`")
was incomplete. Two real Gold-layer gaps, both closed:
- `Fact_Parts_Open_Orders_Snapshot` — the old `LH_Master_Data` table
  (`fact_parts_open_orders_snapshot`, lowercase due to the confirmed
  `saveAsTable()`-lowercases-Delta-names bug) held 7 months of real,
  unbackfillable history (13,070 rows, March–September 2026). New
  `Build_Gold_PartsOpenOrdersSnapshot.Notebook` (proper PascalCase, a
  path-based write to avoid the casing bug) replaces it going forward;
  the 7 months were copied forward once via a one-time backfill script,
  verified exact-match per `SnapshotDate`. The old
  `Pipeline_Monthly_Open_Orders_Snapshot` was disabled (not deleted) once
  the new notebook's guard logic was confirmed working against real data.
- `Fact_PartsInvoiced_ByBranch` — not flagged in the original catalog at
  all. Turned out to have no Gold table anywhere; it was a raw
  `Value.NativeQuery` (`EnableFolding=false`) directly against
  `LH_Master_Data.Invoice`, baked into the report's own TMDL, with a
  hardcoded ~30-customer exclusion list. New
  `Build_Gold_PartsInvoicedByBranch.Notebook` faithfully ports the exact
  same logic (verified: exact match to the penny against its real
  source, `Silver_Invoice`, once pipeline-lag was accounted for).

Both new notebooks registered in `deploy/dp_backend_scope.json`
(monthly/daily respectively), running inside the existing
`Pipeline_DP_Monthly_Refresh`/daily pipeline — no new pipelines. See
`docs/superpowers/specs/2026-09-22-open-parts-tickets-migration-design.md`
and `docs/superpowers/plans/2026-09-22-open-parts-tickets-migration.md`
for the full design and 11-task execution trail.

**Real backend-freshness gap also found and fixed during this migration**
(unrelated to the 2 new tables above, but only surfaced because this
migration's own verification caught it): `Build_Gold_PartsOpenTickets.Notebook`
— which builds `Fact_Parts_Open_Tickets`/`Fact_Parts_Open_Tickets_Details`,
both previously believed "already migrated and ready" — existed in
`DP_Presentation` but had never been registered in any automated refresh
pipeline. It had last run manually on 2026-09-14 and was stuck 12+ days
stale, causing the migrated report to initially show ~$5.4M instead of the
real ~$19.3M in Desktop. Registered as `tier: gold, cadence: daily` and run
once to catch up; now exact match to `LH_Master_Data`'s live production
copy. Worth checking whether any other "already migrated" table from
earlier phases of this project has the same never-registered gap.

**Transfers — COMPLETE (2026-09-23). This closes out Batch 2 entirely** (Open
Work Orders, Pin Capture, Part Sales with Low Margin, Inventory Analysis,
Open Parts Tickets, Transfers — all 6 now migrated). Real investigation
(including Brian pulling the actual `Parts_InterbranchTransfers` view SQL
directly from SQL Central) found the original gap was smaller than the
catalog described: `OrderAge` was already a plain stored column with no
DAX redesign needed, and the Silver-layer rebuild only required 3 trivial
additive column selections (`ShippedQty`/`SoRoRef` on `Silver_InSalPar`,
`TrfToBranch` on `Silver_InSalOrd` — all 3 already existed in Bronze, just
weren't selected into Silver yet). New `Build_Gold_OutstandingTransfers.Notebook`
faithfully replicates the real production view + the existing
`df_Fact_Transfers.Dataflow`'s two-step join logic, verified to an
**exact row-level match** against live production (519 rows,
`sum(OrderQty)`, `avg(OrderAge)` all identical) both at initial build and
again the next day. See
`docs/superpowers/specs/2026-09-22-transfers-migration-design.md` and
`docs/superpowers/plans/2026-09-22-transfers-migration.md` for the full
design and 11-task execution trail.

**Real bug found and fixed during the port** (not present in the design,
caught via Task 6's "investigate large discrepancies, don't assume
timing" discipline): the first notebook draft used a `left_outer` join to
`Silver_InSalOrd` even though the query pre-filtered it to `OrderType='T'`
— in SQL, a `WHERE` clause on a left-joined column is an effective inner
join (`NULL = 'T'` is never true), so the real source view behaves as an
inner join despite its own `LEFT OUTER JOIN` syntax. The PySpark port's
initial `left_outer` wrongly preserved unmatched rows, producing 52 rows
(29% of the table) with a null-safe `OrderAge` fallback sentinel
(`46285` days = the day-count to `1900-01-01`). Fixed by changing the
join kind to `inner`.

**Three separate pre-existing "already migrated, should be fresh" backend
gaps found and fixed along the way** (same never-registered-in-the-pipeline
bug class first found on Open Parts Tickets' `Fact_Parts_Open_Tickets`):
`Build_Gold_Transfers` (12 days stale), `Build_Silver_InTrans` (the
shared 10M+-row InTrans backbone many other reports also depend on, 5
days stale), and `Build_Silver_InMaster` (the sole source of
`InTransitQty`, apparently never run on schedule — this alone accounted
for the new Gold table initially showing only 128 of the real 519
outstanding-transfer rows). All 3 registered in
`deploy/dp_backend_scope.json` and confirmed caught up. **Given this is
now the 4th instance of this exact gap class found this project, a
dedicated audit of every notebook referenced by `dp_backend_scope.json`'s
`reports` section against its `notebooks` array (confirming every listed
notebook is actually registered and running) is a real candidate
follow-up, not yet scheduled.**

60+ Days Past Due (already done in Batch 0, listed here in error —
confirm and remove) is the only remaining Batch 2 cleanup item, not new
work.

### Batch 3 — Tier 3 (4 reports needing real new Gold-layer work first)

`Fact_FirstPassFill` needs its own full audit-and-build; `dim_WkcdPart`/`dim_JobCodes`
needs investigation; Combine Vault Sales and Labor Performance both need their
already-known blockers resolved — same rigor as Batches A–D, not a shortcut.

Brian chose to work through 3 real remaining Parts reports next, in his own
"easiest first" order: `First Pass Fill`, `MD Invoices With No Freight`, then
`Combine Vault Sales` (`Job Code Parts Advisor`/`Labor Performance V2` remain
unscheduled). He also published `Table-Column-Names-Search` into `RP - Dev` for
tracking — an informational, rarely-used report that stays on its existing ODBC
connection, deliberately not part of this migration project; noted here only so
it's on record, not forgotten.

**First Pass Fill — COMPLETE (2026-09-23).** Real investigation found the real
gap was smaller than first assumed: `Fact_FirstPassFill`'s one Silver dependency,
`Silver_InHist_PmManage`, was already fully migrated with zero column gaps — pure
Gold-layer work, no Silver-layer additions needed (unlike every other Batch 2
report this project). New `Build_Gold_FirstPassFill.Notebook` faithfully ports
the real production `df_Fact_First_Pass_Fill.Dataflow`'s dimensional-key-lookup/
null-safe-rate/composite-metric/business-flag logic. See
`docs/superpowers/specs/2026-09-23-first-pass-fill-migration-design.md` and
`docs/superpowers/plans/2026-09-23-first-pass-fill-migration.md` for the full
design and 7-task execution trail.

Two real bugs found and fixed during the build, both real "verify, don't assume"
catches:
- **Missing Franchise/date-window filters.** First run produced 1.86x too many
  rows (1,328,067 vs production's 713,482) because `Silver_InHist_PmManage` is
  an unfiltered full mirror of the raw table, while production's own real ETL
  (`LH_Master_Data/Dataflows/01 - Raw Sources/df_InHist_PmManage_Raw.Dataflow`)
  applies `Franchise = 'D'` plus a rolling 2-year/7-day window at the
  raw-extraction stage — filters that never got carried into the Silver mirror.
  Fixed by applying both filters in the Gold notebook itself, using a DST-safe
  US/Central "now" instead of a naive `DateTime.LocalNow()`-style call. Verified:
  all metrics now match production within ~1.8%, fully explained by normal
  refresh-timing boundary shift.
- **`dim_DateTable`'s "today-relative" columns.** The report-layer audit
  correctly found `IsYearToDate`/`IsRolling12Months`/`IsRolling24Months` as
  real DAX-used columns, but the repoint step wrongly treated them as stored
  source columns — they don't exist on `DP_Presentation.dim_DateTable` at all
  (deliberately dropped during the dims-catalog rebuild for baking in
  `DateTime.LocalNow()`, same bug class already fixed once on Pin Capture's
  `dim_DateTable`). Fixed by restoring all 3 as report-layer DAX calculated
  columns sourced from `'Data Refresh'[Date]`, replicating the exact original
  `EOMONTH`/`YEAR`-based logic. Saved as a standing project memory
  (`feedback_datetable_today_relative_columns_dropped`) since this is now a
  confirmed, generalizable pattern for any future report using `dim_DateTable`.

**MD Invoices With No Freight — COMPLETE (2026-09-23).** 2 of 3 reports in this
batch now done. Real gap was 4 notebooks that existed in `DP_Presentation` but
were never registered in `deploy/dp_backend_scope.json` (5th-9th instances of
this recurring bug class this session): `Build_Gold_MDInvoicesClosed`,
`Build_Gold_MDInvoicesNoFreight`, `Build_Gold_DateTable`, `Build_Gold_Salesperson`
— plus 2 genuinely new tables built from scratch, `Build_Gold_FreightCalculator`
(a manually-maintained CSV lookup, no dataflow) and
`Build_Gold_MDInvoicesNoFreightSnapshot` (a monthly append-only snapshot,
backfilled from the old table's real history — same pattern already proven on
Open Parts Tickets). See
`docs/superpowers/specs/2026-09-23-md-invoices-no-freight-migration-design.md`
and `docs/superpowers/plans/2026-09-23-md-invoices-no-freight-migration.md`
for the full design and 10-task execution trail.

One real bug found and fixed post-publish, caught via Brian's own Desktop
refresh (not the report-layer audit):
- **Arbitrary Weight dedup tie-break.** `Build_Gold_MDInvoicesNoFreight` and
  `Build_Gold_MDInvoicesClosed` both deduped `Silver_PartInformation` on
  `(Branch, PartNumber)` with an arbitrary tie-break, matching production's
  equally arbitrary `Table.Distinct`/`ORDER BY (SELECT NULL)`. ~3,300 combos
  have exactly one zero-weight and one real-weight duplicate, so the two
  arbitrary picks landed differently between engines — same bug class as the
  already-fixed `dim_Parts` `Table.Distinct` issue. Fixed to deterministically
  prefer the non-zero weight; row-level Weight now matches production within
  0.025% in aggregate.

A second, larger factor turned out **not** to be a migration bug at all:
production's own materialized `FreightCalculator` table has no bracket
coverage above 249 lbs (silently falls back to a flat $0.15/lb rate), while
the new backend correctly uses the current 36-row rate table covering up to
999,999 lbs. Confirmed via `projects/md invoices with no freight - report/CLAUDE.md`
that this is Brian's own already-completed 2026-05-18 carrier-rate extension —
production's Lakehouse table was simply never refreshed to match. The new
report's higher Opportunity/Missed Freight numbers are the accurate ones. This
also means the live Power Automate "MD Freight" alerts (weekly digest + daily
new-item alert, both driven off the stale production table) have likely been
under-reporting missed freight since May — flagged to Brian as a separate,
out-of-scope follow-up, not touched here.

**Combine Vault Sales — COMPLETE (2026-09-23).** Last of the 3 reports in
this batch. This closes out a real blocker that's been on record since the
original dims and facts catalog audits: `Fact_Branch12_Transactions` and
`dim_Branch12_Parts` each read the other's last-materialized Lakehouse
table (production's own `df_Fact_Branch12_Transactions.Dataflow` joined
`dim_Branch12_Parts` for `PartNumberKey`; `df_Dim_Branch12_Parts.Dataflow`
joined the fact for R12 sales metrics), with no clean build order. Resolved
by switching `dim_Branch12_Parts`'s `PartNumberKey` from a fragile
sequential index (`Table.AddIndexColumn` over alphabetically-sorted parts,
regenerated every refresh — the same shift-risk pattern already fixed once
on `dim_Parts`, the `CustomerKey` incident) to a stable hash of
`PartNumber`. Both `Build_Gold_Branch12Transactions.Notebook` and
`Build_Gold_Branch12Parts.Notebook` compute the same hash independently,
so the fact no longer needs to join the dimension at all — a genuine
one-directional dependency graph (Fact → dim_Branch12_Parts,
dim_BranchPartInventory) where production only ever had an
eventually-consistent cycle. Brian approved this fix explicitly (not a
faithful port on this one point, deliberately) since new key-generation
logic was needed regardless. Verified via 2 independent checks (the
build notebook's own anti-join, and a separate DuckDB anti-join): 0
fact rows with no matching `PartNumberKey` in the dimension.

A 3rd new table, `dim_BranchPartInventory`, was ported faithfully with
zero logic changes — including the deliberate *absence* of an `IsSale`
filter on its compound-key join, which production tried adding twice
(2026-07-07) and reverted both times for corrupting the report's Grand
Total in ways never fully understood. See
`docs/superpowers/specs/2026-09-23-combine-vault-sales-migration-design.md`
and `docs/superpowers/plans/2026-09-23-combine-vault-sales-migration.md`
for the full design and 8-task execution trail.

Two real bugs found and fixed during the build (both caught by an
implementer subagent, not anticipated by the plan):
- **`VendorCode` type mismatch.** `Silver_PartInformation.VendorCode` is
  `INTEGER` in the real schema; the plan's own notebook code called
  `F.upper(F.trim(...))` on it directly. Fixed with an explicit
  `.cast("string")` first.
- **Space-containing Delta column names.** The plan's own code ported
  `"Unit Margin Dollars"`/`"Unit Margin Percent"` literally from the
  original Power Query column names, which violates this project's own
  documented Delta naming rule. Renamed to `UnitMarginDollars`/
  `UnitMarginPercent` in the deployed table — though the report-layer
  audit (below) then found both columns are genuinely unused in the
  report, so Task 5 trimmed them entirely rather than reconciling the
  rename.

The report-layer exhaustive audit (bookmark check + DAX grep + `pbir`
fields + `sortByColumn` inspection, same discipline as every prior report)
found 2 things beyond what the plan anticipated:
- **A second undocumented `dim_DateTable` "today-relative" column in real
  use**: `IsRolling730Days`, alongside the already-known `IsRolling365Days`
  — feeds 3 "previous R12" comparison measures (`Sales Previous R12`,
  `Demands Previous R12`, `Qty Previous R12`). Neither exists on
  `DP_Presentation.dim_DateTable`'s real 14-column schema; both restored
  as report-layer DAX calculated columns off `'Data Refresh'[Date]`.
- **A genuine bookmark-only column usage**: `dim_DateTable[MonthYear]` —
  zero hits in DAX or `pbir fields list`, but referenced in 2 bookmark
  filters. Exactly the blind-spot class this project's bookmark-check step
  exists to catch (same pattern as Pin Capture's `IsRolling12Months`
  earlier this project). Kept, not trimmed.

Post-publish DuckDB verification confirmed all 6 backend tables present
and populated. Brian confirmed the report looks correct on a visual scan
after his own Desktop refresh/publish/commit cycle.

**This completes the 3-report batch** (First Pass Fill → MD Invoices With
No Freight → Combine Vault Sales). `Job Code Parts Advisor` and
`Labor Performance V2` remain separately unscheduled Tier 3 work; Customer
Anatomy/Inspections/Price Matrix remain held back for "special care" per
Brian's earlier instruction; `Table-Column-Names-Search` remains tracked
but deliberately not migrated (informational report, stays on its ODBC
connection).

## Job Code Parts Advisor — COMPLETE (2026-09-24)

Backend built faithfully from the 2 real production dataflows
(`df_Dim_WkCodeFl.Dataflow` → `dim_JobCodes`, `df_Dim_WKCDPART.Dataflow` →
`dim_WkcdPart` — confirmed genuinely different from the already-built
`dim_JobCode` singular table, not a stale reference), plus registering 2
existing-but-unregistered fact notebooks (`Fact_JobCodePartFrequency`,
`Fact_JobCodePartFrequency_Branch`) that were leftover completed work from
the earlier facts-catalog-audit phase. Report-layer audit trimmed the
report to its real 8 backend tables and repointed the connection string.

**Real, unresolved refresh bug found during Brian's own publish/refresh
pass**: `dim_JobCodes` repeatedly failed Desktop refresh with "duplicate
JobCode ... not allowed on the one side of a relationship" — a different
JobCode each time. Exhaustively investigated: `delta_scan` and raw
`read_parquet` (bypassing the Delta log entirely) both agreed the data was
genuinely clean at every layer (Bronze/Silver/Gold, a from-scratch rebuild,
a brand-new never-used table name), a live XMLA trace of the actual TMSL
refresh command showed nothing unusual, and Brian's own tests (new blank
query, cold Desktop restart, cache clear, even a raw OneLake Parquet file
read bypassing the SQL Analytics Endpoint) all consistently reproduced the
exact same 2-row duplicate with `ModifiedDate` values 31 seconds apart.
Root cause never identified — genuinely unresolved, not just unreproduced
on this end. Along the way, found and fixed a real, separate bug affecting
the whole DP_Presentation backend: `mode("overwrite")` doesn't physically
delete a Gold table's previous-run Parquet files, so the SQL endpoint scans
orphaned files from prior runs too — fixed for `dim_JobCodes` (`VACUUM
... RETAIN 0 HOURS` after every write) but confirmed via `fab dir` this
affects other Gold tables too (`dim_Parts`, `dim_BranchLocation`,
`dim_Franchise`); flagged as a real follow-up, not yet fixed project-wide.

**Workaround, per Brian's explicit direction to stop chasing the root
cause**: eliminated `dim_JobCodes` from every model relationship. Its 4
`LOOKUPVALUE` usages in the `Fact_GapAnalysis`/`Fact_BranchAnalysis`
calculated tables never needed a relationship, so the report's filtering
UI ("Select a Job Code" list, "Search Job Code" box, and the Branch
Analysis drillthrough) was repointed to filter those fact tables' own
native `JobCode` columns directly. This broke the drillthrough in 2
distinct ways that both got fixed:
1. The main page's source field (`Fact_GapAnalysis.JobCode`) and the
   drillthrough target field (initially `Fact_BranchAnalysis.JobCode`)
   were different, unrelated tables — drillthrough only auto-passes a
   value when source and target are the exact same field or connected by
   a relationship. Fixed by adding one new relationship,
   `Fact_BranchAnalysis.JobCode` → `Fact_GapAnalysis.JobCode`,
   many-to-many, single direction (never enforces uniqueness on refresh,
   so it can't reintroduce the `dim_JobCodes` bug), and repointing the
   drillthrough target back to `Fact_GapAnalysis.JobCode` to match.
2. The relationship's `fromColumn`/`toColumn` were initially backwards —
   Power BI's default single-direction cross-filtering flows from the
   `toColumn`'s table into the `fromColumn`'s table (confirmed against
   the model's existing `Fact_BranchAnalysis.Branch` →
   `dim_BranchLocation.BranchID` relationship), so the filter was flowing
   the wrong way and `SELECTEDVALUE(Fact_BranchAnalysis[JobCode])` in the
   `Branch Analysis Banner`/`Key Finding` measures came back blank. Fixed
   by swapping which column is `toColumn`.

Brian confirmed the drillthrough works after both fixes, republished, and
committed via Fabric's own Git integration. Post-publish DuckDB
verification: `dim_JobCodes` 575,887 rows, 575,887 distinct JobCode,
**zero duplicate JobCode groups** — final confirmation the underlying
data was always clean, and the relationship-removal was the right call
rather than a data fix. `dim_WkcdPart`/both fact tables present and within
normal day-to-day drift of their build-time baselines. Further validation
still pending on Brian's side per his own note.

## Labor Performance — COMPLETE (2026-09-24)

Was called "Labor Performance V2" during evaluation; the live Fabric item was
already renamed to plain "Labor Performance" before this migration started
(confirmed via `fab ls` — no V2 suffix anywhere live, only a stale git folder
name in `RP - Service Reports` that never got synced back via a Git
Integration commit, part of that workspace's already-known drift cleanup).

Backend built faithfully from the real resolved SQL Anywhere view logic
(`Administrator.TechnicianAttendance`/`TechnicianPunchedTime`/`TechnicianEfficiency`,
resolved from Brian's own direct `CREATE/ALTER VIEW` pulls both earlier in
this project and again live during this migration to settle open questions —
see `project_labor_performance_technician_views_resolved.md`), sourced from
Silver tables that already existed (`Silver_WkMechAdj`, `Silver_WkMechWk`,
`Silver_WkOthSub`). `dim_Technician_Code_Names` was leftover completed work
from the earlier Dimensions catalog audit project — already correct, just
unregistered, the same pattern found repeatedly on other reports.

**Real bugs found and fixed, none of them anticipated by the original plan:**

1. **A duplicate-key bug in `dim_Technician_Code_Names`**: 3 `TechnicianCode`
   values (`T200`/`T1011`/`T229`) each had 2 rows in `Silver_Contact` for 2
   genuinely different real people (the code had been reassigned to a new
   hire after a prior employee left) — an unordered `dropDuplicates` would
   arbitrarily pick either one, a silent wrong-name risk caught by code
   review before it reached the report. Fixed with an explicit
   most-recent-`ModifiedDate` tie-break.
2. **A join-predicate bug in `TechnicianPunchedTime`**: the semi-join gating
   punched time to a same-day attendance record compared full TIMESTAMP
   equality, but `AdjustmentDate` is always midnight while `ClockInDate`
   carries a real time-of-day — they could essentially never match. Fixed by
   comparing calendar dates instead, with the Spark session pinned to UTC for
   deterministic date extraction. (An intermediate fix attempt wrongly
   diagnosed this as a timezone-conversion bug in JD's Bronze mirror — that
   turned out to be a display artifact from un-pinned investigation queries,
   not real data corruption; caught by code review and reverted.) Verified
   against production's real live coverage numbers exactly (116 of 286
   July-2026 technicians matching, both sides).
3. **The big one — `TechnicianEfficiency` grouped by the wrong date
   entirely**: the notebook used `ClockInDate` (when labor was performed) for
   `DateKey`, but the real source view groups by `datepart(yy/mm,
   invoice_date)` — when the invoice was created, which can be a different,
   later month than the work itself. This silently misattributed hours to
   the wrong month whenever invoicing lagged behind the labor date, and got
   worse for more recent months (a technician's real September invoice total
   was capped near 94-158 hours by the work-date grouping vs. production's
   real 284, since work performed in August/July but invoiced in September
   was being counted under the wrong earlier month instead). Found by
   comparing against the literal real view SQL (pulled directly by Brian)
   rather than continuing to trust an earlier session's algebraic
   derivation. Fixed by regrounding `DateKey` on `InvoiceDate`. Confirmed via
   DuckDB across 5 months (March/May/July/August/September 2026) against
   production's real live table: every month now matches exactly, including
   the underlying `ReworkHours`/`EfficiencyRateNumerator`/
   `EfficiencyRateDenominator` components, not just the headline
   `InvoiceHours` total.

Also scoped `TechnicianAttendance`/`TechnicianPunchedTime` to `Year >= 2023`
at Brian's request, matching production's own dataflow-level scope-down (the
Gold notebooks initially carried full history back to 2010 with no filter,
creating an inconsistent history window against `TechnicianEfficiency`'s
permanent ~2-year source-view limit).

Brian confirmed the numbers line up after the `InvoiceDate` fix, republished,
and committed via Fabric's own Git integration. Post-publish DuckDB
verification: all 6 tables present and populated
(`dim_Technician_Code_Names` 1,453 rows/1,453 distinct TechnicianCode — zero
duplicates; `TechnicianAttendance` 13,156; `TechnicianPunchedTime` 5,068;
`TechnicianEfficiency` 2,544; `dim_BranchLocation` 69; `dim_DateTable`
4,018), all 9 relationships intact, no stray `LH_Master_Data` connection
strings remaining.

This closes out both of the previously-unscheduled Tier 3 reports (alongside
`Job Code Parts Advisor` above) — no reports remain in this catalog without
either a completed migration or an explicit, deliberate hold (Customer
Anatomy/Inspections/Price Matrix for "special care" per Brian's instruction;
`Table-Column-Names-Search` staying on its ODBC connection by design).
