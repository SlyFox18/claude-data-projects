# Data Platform Workspace Reference

Created 2026-09-04 as part of the JD Bronze migration / data platform redesign
(see `docs/superpowers/specs/2026-09-04-jd-bronze-data-platform-redesign-design.md`).

| Workspace | Workspace ID | Purpose | Git branch | Git folder | Capacity |
|---|---|---|---|---|---|
| DP - Staging - Dev | `ab15d64d-c7ba-415d-9bcf-7feb1ef9b201` | Bronze shortcuts + silver (dev) | dev | `workspaces/DP - Staging - Dev` | fabric1cap1 (F8) |
| DP - Staging - Prod | `189e5c0a-548a-4feb-93d6-dda9ebbe96c1` | Bronze shortcuts + silver (prod) | main | `workspaces/DP - Staging - Prod` | fabric1cap1 (F8) |
| DP - Presentation - Dev | `73fd5443-240e-410a-990a-98827f32c087` | Gold + semantic models (dev) | dev | `workspaces/DP - Presentation - Dev` | fabric1cap1 (F8) |
| DP - Presentation - Prod | `7836042d-adb1-4846-b70d-bd42980054c5` | Gold + semantic models (prod) | main | `workspaces/DP - Presentation - Prod` | fabric1cap1 (F8) |

All 4 verified `gitConnectionState: ConnectedAndInitialized` with 0 pending changes as of 2026-09-04.
`fabric1cap1` capacity ID: `c703247c-8451-4349-b95d-93e4eac756e8` (F8, North Central US).

## Folder organization (Dev tier)

2026-09-09: Brian reorganized both Dev-tier workspaces into folders so items stay easy
to find as this grows. Current convention — new items should follow it:
- **`DP - Staging - Dev`**: `Data Notebooks/` (Spark notebooks), `Raw Data - Dataflows/`
  (Dataflow Gen2 items for sources that can't be a JD Bronze shortcut, e.g.
  `df_BranchOperational_Raw`), `Variable - Environment Config/` (the Variable Library).
- **`DP - Presentation - Dev`**: `Dimensions/` (shared dimension notebooks — flat, not
  split by report, since dimensions cross report boundaries) and `Fact Tables/<Report>/`
  (fact table notebooks, grouped by the report/subject that owns them).

Git paths below reflect the folder each item is actually in as of this move — items
created before 2026-09-09 were moved into these folders, not recreated, so their git
history still shows the old flat paths for older commits.

## Lakehouses

| Lakehouse | Workspace | Lakehouse ID | Contents |
|---|---|---|---|
| DP_Staging | DP - Staging - Dev | `876255e0-d462-4697-adc1-4a655f5bb101` | `Tables/InTrans` — OneLake shortcut (passthrough identity) into `JD_EquipRDB_Production_Bronze.InTrans` (`JD_FabricOneLake` workspace `4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9`, lakehouse `7348c3a6-8694-4d11-bc70-1bd55be84ea2`). Verified 2026-09-04: row count, min/max timestamp, and the RO 1985073 spot check (9 rows) all match the source exactly — see `.claude/queries/adhoc/dp-bronze-verify/verify_shortcut.py`. Also holds `Tables/Silver_InTrans`, `Tables/GlTrans` (OneLake shortcut into JD's Bronze mirror), `Tables/BranchOperational` (Dataflow Gen2 ingestion, not a shortcut — see `dim_BranchLocation` below), `Tables/PartInformation_Active`, `Tables/PartInformation_Dead`, and `Tables/Silver_PartInformation` — see below for each. Also holds 9 more OneLake shortcuts into `JD_EquipRDB_Production_Bronze` (`ArMaster`, `ArMaster_Customer`, `contact`, `GLMASTER`, `InSalOrd`, `InSalPar`, `VhStockAccess`, `WarSubCl_Labour`, `Branch_Name`) plus their corresponding `Silver_*` tables — see "Raw sources batch 1" below. Also holds 10 more OneLake shortcuts (`TechnicianInvoiceDetail`, `TechnicianPunchedDetail`, `VhStock`, `VhTrans`, `WkInvReg`, `WKMECHWK`, `WKOTHSUB`, `WkRoFile`, `WkVehFl`, `WarClaim`) plus their corresponding `Silver_*` tables — see "Raw sources batch 2" below. Also holds `Tables/Invoice` (OneLake shortcut, 6,505,866 rows — the largest table this backend has touched) and `Tables/Silver_Invoice` — see "Invoice" below for the real grain bug found in this table. Also holds `Tables/InHist_PmManage` and `Tables/WKRODESC` (OneLake shortcuts) plus `Tables/Silver_InHist_PmManage` and `Tables/Silver_WkRoDesc` — see "InHist_PmManage and WKRODESC" below for the real business-rule-filter findings on both. Also holds `Tables/WKMECHADJ` and `Tables/WKMECHFL` (OneLake shortcuts) plus `Tables/Silver_WkMechAdj` and `Tables/Silver_WkMechFl` — see "WKMECHADJ and WKMECHFL" below for the Technician-family investigation these unblock. Also holds `Tables/InMaster` (OneLake shortcut) plus `Tables/Silver_InMaster` — see "InMaster" below for the plain-table scope clarification and the `Parts_InterbranchTransfers` dependency this unblocks. Also holds `Tables/InSalPar_Audit` and `Tables/RepairOrderDetail` — landed via direct ODBC pull (Dataflow Gen2, `df_InSalPar_Audit_Raw`/`df_RepairOrderDetail_Raw` in `Raw Data - Dataflows/`), no shortcut possible for either — see "InSalPar_Audit and RepairOrderDetail" below, the last 2 Category C tables, closing out the entire raw-sources catalog. |
| DP_Presentation | DP - Presentation - Dev | `966efc8a-16f9-423b-aa43-e368fcd8fb91` | `Tables/dim_RepairOrder`, `Tables/Fact_PartsPromo`, `Tables/Fact_InTrans_AllPromo`, `Tables/Fact_PartsAdjustments`, `Tables/dim_DateTable`, `Tables/dim_BranchLocation` — see below for each. |

### `Silver_InTrans`

Built by `Build_Silver_InTrans.Notebook` (in `DP - Staging - Dev`, git-tracked at
`workspaces/DP - Staging - Dev/Build_Silver_InTrans.Notebook`). PySpark, PK-merge on
`(TransId, TransDatetime)` — not `TransId` alone, which the source system reuses for
unrelated transactions (see the notebook's header comment and project memory
`project_intrans_incremental_dedup_2026-08-11` for the full story). `ModifiedDate DESC
NULLS LAST` breaks rare genuine same-key conflicts. Written via path-based
`.save("Tables/Silver_InTrans")`, not `saveAsTable()`, to preserve exact PascalCase
(a third confirmed instance of `saveAsTable()` lowercasing physical table names in
this environment — see `feedback_fabric_saveastable_casing.md`).

Full column parity with `InTrans_Incremental` (all 66 raw `InTrans` columns, using the
same rename mapping already in production use in `df_InTrans_Incremental.Dataflow`'s
`mashup.pq`), not just the 11 columns Parts Promo needs — done deliberately once, so
the other 8+ fact tables that currently depend on `InTrans_Incremental`
(`Fact_WorkOrderParts`, `Fact_Transfers`, Parts Adjustments, Parts Not Re-Ordered,
Unique Parts Customers, etc.) can point at this table with zero column-name surprises
when they eventually migrate.

Verified 2026-09-08 via `.claude/queries/adhoc/dp-bronze-verify/verify_silver_intrans.py`
(independent DuckDB check, separate from the notebook's own verification cell):
20,462,845 rows (0.73% fewer than bronze's 20,612,638 — expected, true exact
duplicates + genuine same-key corrections collapsed), 0 duplicate
`(TransId, TransDatetime)` groups, 0 orphaned rows (nothing stale survived two earlier
flawed builds — first used `TransId` alone as the key, second used `saveAsTable()`
with the wrong case), and the RO 1985073 spot check still shows exactly 9 rows.

### `dim_RepairOrder` / `Fact_PartsPromo`

Built by `Build_Gold_PartsPromo.Notebook` (in `DP - Presentation - Dev`, git-tracked at
`workspaces/DP - Presentation - Dev/Build_Gold_PartsPromo.Notebook`). PySpark, reads
`Silver_InTrans` cross-workspace via its full OneLake path (no shortcut — a direct
same-tenant Spark read), reproduces the existing production business logic exactly
(`dim_RepairOrder.pq` / `Fact_PartsPromo_v2.pq`: promo = `PartNumber` starts with `*`;
non-promo aggregates exclude `Franchise = 'ZP'`; promo aggregates do not). Full
overwrite each run — both tables are small (promo-active orders since 2022-01-01
only). Written via path-based `.save()` from the start (no casing mistake to make
here, unlike `Silver_InTrans`'s first attempt).

As of 2026-09-08: 16,251 `dim_RepairOrder` rows, 16,918 `Fact_PartsPromo` rows.

**This is the actual bug-fix proof.** Verified via
`.claude/queries/adhoc/dp-bronze-verify/verify_gold_parts_promo.py` — compared
`dim_RepairOrder` directly against `EquipRDB` (the real source system, not another
copy of our own data) for all 11 repair orders confirmed wrong in the original
investigation. **All 11 now match to the penny** (differences shown are
floating-point noise on the order of `1e-13`, not real discrepancies). The original
Parts Promo bug — RO 1985073 showing $229.18 instead of $627.64, and 10 other
orders similarly understated — is fixed at the gold layer.

**`dim_RepairOrder` trimmed 2026-09-11:** the LH_Master_Data dimensions catalog's
column-usage-depth audit (`docs/architecture/lh-master-data-dimensions-catalog.md`) found
only 2 of the original 15 columns (`REF_NO` as the relationship key, `CustomerNo` in a
visual) are genuinely used by the live Parts Promo report. Dropped the 13 unused
pre-aggregated order-level metrics (`TotalPartsSales`, `TotalPartsCost`, `PartsCount`,
`TotalPromoDiscount`, `PromoCount`, `NetOrderValue`, `OriginalMargin`, `NetMargin`,
`DiscountAmount`, `DiscountPercent`, `BranchKey`, `OrderDate`, `LastActivityDate`) — all
genuinely well-designed (they replaced a runtime self-join in the original Power Query),
just never surfaced in the report; full derivation preserved in the catalog doc and git
history if a future report enhancement needs them back. Verified 2026-09-11: 16,269 rows
(unchanged), 2-column contract exact, all 11 known-important orders (including RO
1985073) still present.

**Variable Library:** `DP - Environment Config`, lives in `DP - Staging - Dev`, git-synced under
`workspaces/DP - Staging - Dev/DP - Environment Config.VariableLibrary`. Value sets: `Default`
(built-in), `Dev`, `Prod`.

Variables defined so far:

| Variable | Type | Default | Dev | Prod |
|---|---|---|---|---|
| `staging_lakehouse_id` | String | `876255e0-d462-4697-adc1-4a655f5bb101` | `876255e0-d462-4697-adc1-4a655f5bb101` | `6713bd45-a4ad-47e6-8bff-1bb0415e9784` |
| `presentation_lakehouse_id` | String | `966efc8a-16f9-423b-aa43-e368fcd8fb91` | `966efc8a-16f9-423b-aa43-e368fcd8fb91` | `29d9df80-a383-4d40-9807-1e2e6cbff88f` |

**Gotcha (confirmed 2026-09-04):** Variable Library value sets require non-blank values to save —
leaving a value empty blocks both saving and adding further value sets. Also, the Git integration
connect dialog's "Git folder" field defaults to the repo **root** if left blank, which pulls in
every other workspace's items as pending updates — always fill it in explicitly (no leading slash),
and check the Updates count immediately after connecting before touching anything else.

## Foundational dimensions (2026-09-09)

First shared dimensions built in the new backend, per Brian's direction to pause report
migration and build shared foundation first — see
`docs/superpowers/plans/2026-09-09-dp-foundational-dims.md`. Dev tier only; no report is
repointed at either of these yet.

### `dim_DateTable` — deliberately slimmer than production, not an incomplete port

Built by `Build_Gold_DateTable.Notebook` (`Dimensions/Build_Gold_DateTable.Notebook` in
`DP - Presentation - Dev`). Pure calendar generation, no source dependency at all — same
as production.

Production's `dim_DateTable` (`LH_Master_Data`) has 76 columns. This one has 28. The
missing ~48 are every "today"-relative column (`IsCurrentYear`, `IsCurrentMonth`,
`IsPrevious*`, `IsYearToDate`/`IsQuarterToDate`/`IsMonthToDate`, every `IsRolling*`,
`IsLast*Days`, `IsNext30Days`, `IsSameMonthLastYear`/`IsSameQuarterLastYear`,
`RollingPeriodCategory`, `DaysFromToday`, `YearOffset`) — all of which were computed off
`DateTime.LocalNow()` baked into static refresh-time columns in production, the same
UTC-not-actual-local-time bug class already found and fixed twice this session
(`Fact_PartsAdjustments.LoadedDatetime`, and the documented 2026-02-27 Data Refresh Table
fix). Confirmed live and silently wrong for hours around midnight in every one of those
flags in production, the whole time.

**This was a deliberate redesign, agreed with Brian 2026-09-09, not a mistake or an
unfinished port:** that class of logic belongs in report-layer DAX measures (or a
calculation group) evaluated dynamically against `TODAY()` at query time, not frozen at
whatever moment the backend last refreshed. It will come back as report-layer work when
each report actually migrates onto this backend — deliberately not part of this table.

Verified 2026-09-09 via `verify_gold_datetable.py`: 4,018 rows (2020-01-01 to
2030-12-31, matching production's range), 28 columns, hand-computed spot checks correct
for three known dates, zero dropped columns leaked back in.

**Further trimmed 2026-09-11:** the LH_Master_Data dimensions catalog's column-usage-depth
audit (`docs/architecture/lh-master-data-dimensions-catalog.md`) cross-checked this table's
28 columns against real usage across all 24 of `dim_DateTable`'s production consumers and
found only 13 are genuinely referenced by any of them. The other 15 (`DayOfWeekName`,
`DayOfWeekNameShort`, `SortableMonthYear`, `DateDisplayName`, `Season`, `IsPeakSeason`,
`FiscalYear`, `FiscalQuarter`, `MonthSort`, `QuarterSort`, `IsWeekday`, `IsBusinessDay`,
`WorkingDaysInMonth`, `WorkingDaysInQuarter`, `WorkingDaysInYear`) are all genuine,
non-buggy calendar attributes — nothing wrong with any of them, just never proven needed —
dropped per the same "build what's proven needed" discipline used throughout this backend.
Verified 2026-09-11 (`verify_dim_trims_datetable_branchlocation_repairorder.py`): 4,018
rows (unchanged), 13-column contract exact.

### `dim_BranchLocation` — no bug found, rebuilt off Silver_BranchName, trimmed (2026-09-11)

Built by `Build_Gold_BranchLocation.Notebook` (`Dimensions/Build_Gold_BranchLocation.Notebook`
in `DP - Presentation - Dev`). No correctness issue was ever found in this table's
enrichment logic (`BranchType` classification, branch-number fixes, `DataQualityScore`) —
unlike `dim_DateTable`, this was never a bug fix, just first a faithful port (2026-09-09)
and now a source-swap + column trim (2026-09-11), both driven by real findings.

**Original source (2026-09-09), now retired:** `BranchOperational`, an EquipRDB **view**
confirmed not in JD's Bronze mirror, landed via its own small direct-ODBC Dataflow Gen2
(`df_BranchOperational_Raw`, `Raw Data - Dataflows/` in `DP - Staging - Dev`).

**Current source (2026-09-11):** during the Category B Technician-family investigation,
Brian pulled `BranchOperational`'s real SQL Anywhere view definition and found it's a
trivial rename over `Branch_Name` — already migrated as `Silver_BranchName` (raw sources
batch 1, a zero-cost OneLake shortcut). This notebook now reads `Silver_BranchName`
directly (via a new cross-workspace shortcut added to `DP_Presentation`, same
"shortcuts, not copies" pattern as `Silver_InTrans`/`GlTrans`) and reproduces
`BranchOperational`'s own 7-column projection inline before the same downstream logic
runs unchanged. `df_BranchOperational_Raw` itself has been **deleted** (both from the live
`DP - Staging - Dev` workspace and this repo) — confirmed nothing read it anymore.

**Column trim (2026-09-11):** the LH_Master_Data dimensions catalog's column-usage-depth
audit (`docs/architecture/lh-master-data-dimensions-catalog.md`) found only 9 of the
original 16 columns are genuinely used by any of `dim_BranchLocation`'s 22+ real
consumers. Dropped the 7 heuristic columns pattern-matched on `BranchID`/`BranchName`/
`State`/`City` (`ServiceCapacity`, `MarketPresence`, `TerritoryCoverage`,
`OperationalPriority`, `RegionalClassification`, `ServiceHours`, `DistanceFromHub`) —
`DataQualityScore` survived, confirmed genuinely used.

Verified 2026-09-11 (independent DuckDB check,
`verify_dim_trims_datetable_branchlocation_repairorder.py`): 69 rows (exact match to the
original 2026-09-09 build — confirms the source swap changed nothing about which branches
qualify). Seminole (`BranchID '1'` — the specific branch a much older production bug, an
arbitrary `Table.Skip(30)`, used to drop) is present and correctly classified as
`Main Branch`, `DataQualityScore = 100`. 9-column contract confirmed exact.

## jdis_Part_Information tiered refresh (2026-09-09) — first step of a larger design

`jdis_Part_Information` has no `ModifiedDate`/change-tracking field at all, so full
refresh is structurally required regardless of tooling. Its current production refresh
(3x/day, full ~1.1M-row pull, ~8 min each) is already documented as the Fabric
capacity's **#3 CU consumer** (`projects/shannon-report/CLAUDE.md`'s "Refresh" section).
It's also not in JD's Bronze mirror — almost certainly the same volatility reason it has
no change-tracking field to begin with.

**The idea, validated with real numbers before building anything** (queried directly
against `EquipRDB` 2026-09-09): of 1,111,728 total rows, **73.2% (813,379) are
genuinely dormant** by a reasonable 24-month definition (zero on-hand quantity, zero
sales in the trailing 24 months) — only **26.8% (298,349) is "active."** That active
slice is close in scale to Shannon's own "Aftermarket - Parts Orders" report (a
completely separate, non-shared-pipeline tool), which proved a 202,262-row filtered
query against this same source refreshes in **33 seconds** — strong evidence the active
tier here could refresh far more often than the dormant majority, once refresh
scheduling exists for this backend.

**Built:** two Dataflow Gen2 bronze ingestions (`df_JDIS_PartInformation_Active_Raw` /
`df_JDIS_PartInformation_Dead_Raw`, `Raw Data - Dataflows/` in `DP - Staging - Dev`,
WHERE-split by the 24-month definition, landing `PartInformation_Active`/
`PartInformation_Dead`) recombined by `Build_Silver_PartInformation.Notebook`
(`Data Notebooks/`) into one logical `Silver_PartInformation` table.

**First-run results, far better than expected:** Active tier (298,384 rows) refreshed in
**1:17**, Dead tier (813,390 rows) in **1:39** — both dramatically faster than the
original ~8-minute full pull, and far from proportional to row count (813k rows took
barely longer than 298k). Likely explanation: both new queries use an explicit
30-column `SELECT` instead of production's `pi.*`-style full-column pull — that alone
probably accounts for most of the win, independent of the row filtering itself.

**Two real findings from execution, worth remembering for future work on this table:**
1. **The true row-level grain of `jdis_Part_Information` is `(Branch, PartNumber,
   Franchise)`, not `(Branch, PartNumber)` alone.** The same part number can be carried
   under multiple franchise codes at the same branch, each an independent inventory/
   cost/sales record — confirmed by pulling every column for a real example (Franchise
   `'D'` vs `'UD'`, fully independent data otherwise). A verification script that
   assumed `(Branch, PartNumber)` was unique found 2,215 false-positive "overlaps";
   correcting the key dropped that to 5 (0.00045%), fully explained by the two
   dataflows being non-atomic point-in-time pulls against a live source run ~2 minutes
   apart — not a bug.
2. **`jdis_Part_Information` has genuine sentinel "never happened" dates** (e.g.
   `DateLastRequested = 1900-01-01`) that trigger `SparkUpgradeException:
   [INCONSISTENT_BEHAVIOR_CROSS_VERSION.READ_ANCIENT_DATETIME]` when Spark writes a
   table containing them — a known Spark/Parquet cross-engine calendar ambiguity
   (SPARK-31404) for timestamps before 1900-01-01T00:00:00Z, since Dataflow Gen2's
   Parquet writer uses a different calendar convention than native Spark expects. Fix:
   `spark.conf.set("spark.sql.parquet.datetimeRebaseModeInRead", "CORRECTED")` and the
   same for `...InWrite`, set once at the top of any notebook reading/writing tables
   built from this source. **Any future notebook touching `jdis_Part_Information` (or
   its derivatives) should expect this and set both configs up front.**

Verified 2026-09-09: `verify_shortcut_partinformation_tiers.py` confirms the bronze
split is correct on the true grain (0 duplicate `(Branch, PartNumber, Franchise)`
groups within either tier) and its combined total matches a fresh live `EquipRDB` count
almost exactly. `verify_silver_partinformation.py` confirms the recombined silver total
matches the bronze sum exactly (1,111,774) and `ActivityTier` classification is 100%
internally consistent with the underlying on-hand/sales data.

**Explicitly deferred, not part of this step** (this plan proves the tier-and-recombine
pattern only — see `docs/superpowers/plans/2026-09-09-dp-parts-information-tiered-refresh.md`):
- The actual `dim_Parts` gold business-logic enrichment (promo/margin/supersession
  classification) — a separate, substantial future project, same category as
  `dim_CustomerList` (already has its own open, deferred Spark-redesign ticket in
  project memory).
- Any refresh schedule/cadence for either bronze dataflow — both are manually triggered
  for now, same as every other piece of this backend before scheduling exists (still the
  platform's biggest open gap).
- Periodic reclassification of which tier a part belongs to — not needed yet, since
  there's no schedule driving repeated runs at different cadences; each manual run
  re-evaluates activity status fresh against live source data. This becomes a real
  design question once an asymmetric schedule (Active hourly, Dead daily/weekly) exists.

## Raw sources batch 1 (2026-09-10) — simple shortcuts

First batch of a broader effort to migrate `LH_Master_Data`'s ODBC-based raw-source
dataflows onto this backend — catalogued in full in
`docs/architecture/jd-bronze-raw-sources-catalog.md` (45 dataflows sorted into 4
categories by how they map onto `JD_EquipRDB_Production_Bronze`). This batch covers
exactly the 9 tables in that catalog's Category A with **zero filtering logic** in
their old dataflow (no date-range bound, no business-rule `WHERE`, no join/group/
dedup) — confirmed by reading every candidate dataflow's `mashup.pq` directly, not
assumed.

**Why:** these 9 tables already exist, live, in JD's own Fabric mirror — the old
`LH_Master_Data` dataflows were running a redundant ODBC query against `EquipRDB64`
for data JD already replicates continuously. `ArMaster_Customer` specifically had a
long-standing, never-diagnosed "300-400% refresh performance degradation" investigation
open in the old pipeline (refresh time grew from 1-2 minutes to 6-8 minutes, root cause
never found) — resolved as a side effect of this migration, since there's no ODBC query
against `EquipRDB64` running for it anymore at all.

**What was built:** a plain OneLake shortcut per table (zero CU cost, always current,
no refresh action needed — a shortcut points at the same underlying Delta files as its
JD Bronze source) plus a Spark notebook per table (`Build_Silver_<Name>.Notebook`, all
in `DP - Staging - Dev/Data Notebooks/`) replicating the exact column rename contract
the old dataflow used, so nothing downstream needs to change shape. Column mappings
were verified against the *live* JD Bronze schema (not the old dataflow's SQL text) —
several columns' real casing differs from what the old ODBC-layer SQL assumed (e.g.
`VhStockAccess`'s real columns are `Stock_No`/`Sale_Value`/`Qty`, not the old query's
all-caps `STOCK_NO`/`SALE_VALUE`/`QTY` — SQL Anywhere resolves column names
case-insensitively so the old query worked regardless, but Delta/Parquet does not).

| Bronze shortcut | Old dataflow | Silver table | Row count (2026-09-10) |
|---|---|---|---|
| `ArMaster` | `df_ARMASTER_Raw` | `Silver_ArMaster` | 54,127 |
| `ArMaster_Customer` | `df_ArMaster_Customer_Raw` | `Silver_ArMasterCustomer` | 54,129 |
| `contact` | `df_CONTACT_Raw` | `Silver_Contact` | 82,756 |
| `GLMASTER` | `df_GlMaster_Raw` | `Silver_GlMaster` | 25,924 |
| `InSalOrd` | `df_INSALORD_Raw` | `Silver_InSalOrd` | 10,134 |
| `InSalPar` | `df_INSALPAR_Raw` | `Silver_InSalPar` | 20,302 |
| `VhStockAccess` | `df_VhStockAccess_Raw` | `Silver_VhStockAccess` | 695,965 |
| `WarSubCl_Labour` | `df_WARSUBCI_LABOUR_Raw` | `Silver_WarSubClLabour` | 68,311 |
| `Branch_Name` | `df_Branch_Name_Raw` | `Silver_BranchName` | 99 |

One real finding during execution, not a design decision: Brian's first shortcut
attempt for `VhStockAccess` selected the wrong JD Bronze table (`VhStock` — a
separate, similarly-named table) by accident. Caught immediately by the bronze
verification script (`verify_shortcuts_rawsources_batch1.py`), which threw a real
DuckDB Delta-kernel error ("No files in log segment") rather than a silent mismatch —
root-caused by listing `DP_Staging`'s actual table contents via `fab ls` rather than
guessing, which showed `VhStock.Shortcut` where `VhStockAccess.Shortcut` was expected.
Fixed by deleting the wrong shortcut and creating the correct one; re-verification
passed cleanly.

**Verification:** both independent DuckDB scripts pass on all 9 tables —
`.claude/queries/adhoc/dp-bronze-verify/verify_shortcuts_rawsources_batch1.py` (bronze
shortcut row count == JD Bronze direct, for every table) and
`verify_silver_rawsources_batch1.py` (Silver row count == bronze shortcut row count,
for every table, confirming the rename/select step never adds or drops rows).

**Explicitly deferred, not part of this batch:**
- The 4 dataflows that all pull `InMaster` (`df_InMaster_Raw`,
  `df_InMaster_PartsLookup_Raw`, `df_InMaster_PartsLookup_Incremental`,
  `df_InMaster_Parts_Ordering_Raw`) — a real consolidation opportunity (one shortcut +
  one silver notebook could replace all 4), needs its own design pass.
- Tables whose old dataflow has a date-range `WHERE` (`TechnicianInvoiceDetail`,
  `TechnicianPunchedDetail`, `VHSTOCK`, `VhTrans`, `WKINVREG`, `WKMECHWK`, `WKOTHSUB`,
  `WKROFILE`, `WKVEHFL`, `Invoice`, `WarClaim`) — structurally simple too, but dropping
  or preserving that windowing is a real scope decision not yet made.
- `InHist_PmManage` (`Franchise = 'D'` business-rule filter) and `WKRODESC`
  (`WHERE LINE_NO = 1` grain-narrowing rule) — real business logic embedded in the old
  SQL, not just a performance bound, needs more thought before treating as "just bring
  it in."
- The Technician-family views (Category B in the catalog) and the tables genuinely
  excluded from JD's mirror (Category C) — each needs its own design work, not a
  shortcut.
- Any report repointing, gold-layer business logic, or refresh schedule — this batch is
  Dev-tier, Silver-layer, manually-triggered only, matching every prior piece of this
  backend.

## Raw sources batch 2 (2026-09-10) — date-windowed tables, brought in unfiltered

Second batch of the `LH_Master_Data` raw-sources migration — the 10 Category A tables
whose old dataflow had a date-range `WHERE` clause (`TechnicianInvoiceDetail`,
`TechnicianPunchedDetail`, `VhStock`, `VhTrans`, `WkInvReg`, `WKMECHWK`, `WKOTHSUB`,
`WkRoFile`, `WkVehFl`, `WarClaim`).

**Why the old date windows were dropped, not replicated:** investigated directly with
Brian this session, three findings together:
1. The `RangeStart`/`RangeEnd` parameter pattern was Brian's own unfinished attempt at
   incremental refresh — never completed or validated, not a deliberate "we only need
   N years" scope decision.
2. On six of these tables, the filter column (`ModifiedDate`) turned out to be
   40–91% NULL — a `>=` comparison against NULL is neither true nor false, so the old
   dataflows were silently dropping most of the table regardless of age, not
   "excluding old data." Worst case: `WkInvReg` at 90.8% NULL.
3. Now that a shortcut is free (no ODBC/CU cost), there's no cost reason to filter at
   this layer — date-scoping is a business decision that belongs at Gold, where a
   specific consumer's real need is known, matching how Parts Adjustments and Parts
   Promo were already built (Silver stays complete, filtering happens at Gold).

So every notebook in this batch brings in full table history. The one exception:
`WarClaim` keeps its two `IS NOT NULL` filters (`INVOICE_NO`, `CLAIM_NO`) — confirmed
via real data to be legitimate data-quality guards (10.75% of the table excluded, all
missing `CLAIM_NO`, sample excluded rows all `STATUS='U'` — warranty-eligible records
that never became a filed claim), unrelated to the date-windowing question.

**`WkVehFl` special case:** unlike the other nine tables, no reliably-populated date
column exists on this table at all — five candidates checked (`CreationDate` 62.0%
NULL, `DELIVERY_DATE` 20.9% NULL, `LAST_SERV_DATE` 75.1% NULL, `BUILD_DATE` 76.1%
NULL, plus the old `ModifiedDate` at 43.3% NULL). Brought in fully unfiltered on the
data, not as a default.

**New standing practice, starting with this batch:** every notebook in this backend
now proactively sets
```python
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInRead", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInWrite", "CORRECTED")
```
at the top, regardless of whether a sentinel date has already been confirmed on that
specific table — this source system has shown the pre-1900 sentinel-date pattern often
enough (`jdis_Part_Information`, `VhStock`, `VhTrans`, and `WKMECHWK.DATE_CLOCKED_IN`
which has a confirmed **year-0013** minimum) that it's cheaper to always include this
than wait to hit the write failure again.

**Real casing corrections found and fixed** (live bronze schema vs. the old ODBC-layer
SQL — SQL Anywhere resolves column names case-insensitively, Delta/Parquet does not):
`VhStock` had 7 (`OWNER`→`Owner`, `OPTION_COST`→`Option_Cost`, `PAINT_COST`→
`Paint_Cost`, `TRIM_COST`→`Trim_Cost`, `CHARGE_COST`→`Charge_Cost`,
`AFTER_MARKET_COST`→`After_Market_Cost`, `PRE_TRADE_OVRALLOW`→`Pre_Trade_Ovrallow`),
`WkRoFile` had 1 (`RO_PROGRESS_STATUS`→`ro_progress_status`), `WkVehFl` had 1
(`COMPLIANCE_DATE`→`Compliance_Date`).

**Verification:** both independent DuckDB scripts pass on all 10 tables —
`verify_shortcuts_rawsources_batch2.py` (bronze shortcut vs. JD Bronze direct) and
`verify_silver_rawsources_batch2.py` (Silver vs. bronze shortcut, with `WarClaim`
special-cased for its expected reduction — confirmed exactly -5,042 rows, matching
the number found during investigation almost to the digit).

**`Invoice` deliberately excluded from this batch** — at 6.5M rows, the largest table
found in this whole catalog effort and one of the most heavily-relied-upon tables in
the platform, it gets its own dedicated look next, the same treatment
`jdis_Part_Information` got, not lumped into a batch with nine other tables.

**Explicitly deferred, not part of this batch:**
- `InHist_PmManage` (`Franchise = 'D'` business-rule filter) and `WKRODESC`
  (`WHERE LINE_NO = 1` grain-narrowing rule) — real business logic, not just a
  performance bound.
- The InMaster group — investigated in depth this session, filed separately (see
  `project_nonjd_parts_order_tool_paused.md` in project memory): one table is
  mission-critical/do-not-touch, one has a real report consumer, one belongs to a
  real-but-paused project, one is confirmed dead code.
- Category B (Technician-family views) and Category C (tables excluded from JD's
  mirror) from the catalog doc.
- Any report repointing, gold-layer business logic, or refresh schedule.

## Invoice (2026-09-10) — the grain bug and why Silver stays unpartitioned

`Invoice` was deliberately excluded from raw sources batch 2 and given its own
dedicated migration — at 6,505,866 rows it's the largest table this backend has
touched (4.3x the next-largest, `WKMECHWK` at 1.5M), and one of the most
foundational tables in the whole source system.

**The real finding this table's migration exists to carry forward.** The old
`df_Invoice_Raw` dataflow's own header comment claims:
```
Grain: One row per invoice (unique by InvoiceNumber)
```
This is false. Confirmed via direct query against live data: 6,505,866 total rows,
but only 3,806,166 distinct `document_no` (`InvoiceNumber`) values. Two real examples
pulled directly:
- `document_no = '900022'` — 4 completely unrelated records spanning **2012, 2020,
  2021, and 2023**, different customers (`JOHNDEERV2`, `22253`, a null,
  `HERITAGE-CRYS26`), different branches, different module/invoice types.
- `document_no = '2331659999'` — 3 unrelated records across **2014, 2015, 2016**.

This is the same reused-reference-number bug class already confirmed 3 times this
session in this exact source system (`TransId`, `GlTrans.DocRef`, `RONumber`) — the
source system recycles document numbers over the years. `InvoiceNumber` alone is
never a safe join or dedup key.

**The real, confirmed-unique grain is `(InvoiceNumber, Branch, ModuleType,
InvoiceType)`.** Tested directly this session and re-confirmed independently against
the written Silver data: `SELECT COUNT(*) FROM (SELECT DISTINCT InvoiceNumber,
Branch, ModuleType, InvoiceType FROM Silver_Invoice)` returns exactly 6,505,866,
matching the row count exactly.

**Not fixed here** — `Silver_Invoice` stays a faithful passthrough of the source, no
deduplication or grain-correction (that's Gold's job if/when it's ever needed, same
pattern as how the `InTrans`/`GlTrans` reused-key bugs were ultimately handled: a
closest-date-match join at the point of actual use, not a magic key baked into
Silver). **Any future Fact table built on `Silver_Invoice` must account for this** —
joining or grouping on `InvoiceNumber` alone will silently produce wrong results, the
same class of bug that caused Parts Adjustments' PA Type misclassification earlier
this session.

**Why `Silver_Invoice` is deliberately unpartitioned**, despite being by far the
largest table here: partitioning (e.g. by year) would bet on a specific future
Gold-layer consumer's query pattern before any such consumer exists — the same
category of premature decision as date-filtering at Silver, which this whole backend
has consistently rejected. Every real optimization built here so far
(`jdis_Part_Information`'s tiering, the ancient-date config, the various grain fixes)
came from a measured, already-documented problem, not speculation — `Invoice` isn't
feeding anything yet. If a real Fact table is later built on top of it and shows an
actual, measured need, partitioning (or Delta `OPTIMIZE`/`ZORDER`, a lighter-weight
alternative) is the fix to reach for then, informed by that consumer's real query
pattern — not decided now.

**What was built:** a plain OneLake shortcut (`Invoice`) plus `Build_Silver_Invoice`
in `DP - Staging - Dev/Data Notebooks/` — full history, no date filter, keeps the old
dataflow's two data-quality filters (`document_no IS NOT NULL AND document_no <>
''`), confirmed to have zero current impact (0 of 6,505,866 rows excluded).

**Verification:** both independent DuckDB scripts pass —
`verify_shortcut_invoice.py` (bronze shortcut exactly matches JD Bronze direct,
6,505,866 = 6,505,866) and `verify_silver_invoice.py` (Silver matches bronze exactly,
0 rows excluded, and independently re-confirms the grain finding directly against the
written Silver data).

**Explicitly not part of this work:** deduplication, gold-layer business logic,
partitioning, any report repointing, any refresh schedule.

## InHist_PmManage and WKRODESC (2026-09-10) — real business-rule filters, brought in unfiltered anyway

The last two Category A tables from the original raw-sources catalog that needed more
thought before migrating — both old dataflows filtered on something more meaningful
than a date window, unlike every other table migrated so far.

**`InHist_PmManage`'s `Franchise = 'D'` filter** is genuinely tied to the real "First
Pass Fill" report's purpose (John Deere equipment specifically), and Franchise D really
is the dominant scope: 1,105,419 of 1,328,067 rows (83.2%). But a lowercase `'d'`
variant (212 rows) sits right next to uppercase `'D'` in the live data — almost
certainly the same franchise with a data-entry casing inconsistency, which the old
exact-match `= 'D'` filter would have silently excluded. The remaining 16.8% spans 43
other franchise codes, some down to single-digit row counts.

**`WKRODESC`'s `WHERE LINE_NO = 1` filter** is a grain-narrowing rule ("primary job per
work order"), not a date bound, and it has two real, confirmed costs:
- **10 work orders have no `LINE_NO = 1` row at all** (716,698 distinct
  `(Branch, WorkOrder)` combos, only 716,688 have a line-1 row) — a report trusting
  "every RO has a primary job" would silently get zero rows for those 10.
- **`LINE_NO` values of `1000001` and `1000002` account for 426,921 rows** — 26% of the
  whole 1,623,053-row table. Not organic sequential numbers — an unexplained offset
  pattern the old filter silently drops entirely, and nobody has yet investigated what
  it represents.

**Neither filter is replicated.** Both encode a real business-scoping decision, not a
data-quality guard (unlike `WarClaim`'s or `Invoice`'s `IS NOT NULL` filters, which
were kept) — and both have a confirmed real cost on top of that. Consistent with every
other business-shaping call already deferred this session (date windows, no
partitioning on `Invoice`): bring in everything at Silver, let Gold decide. The
eventual First Pass Fill Gold/Fact table can still scope to Franchise D there. A future
`WKRODESC` Fact table consumer can decide whether it wants "primary job only" or
something else, once the `1000001`/`1000002` pattern is actually understood.

**One real casing correction found:** `InHist_PmManage`'s `PART_NO` → `Part_No` (the
old dataflow's all-caps SQL text worked under SQL Anywhere's case-insensitive
resolution, but the live bronze schema stores it mixed-case). `WKRODESC` needed no
casing corrections.

**What was built:** plain OneLake shortcuts (`InHist_PmManage`, `WKRODESC`) plus
`Build_Silver_InHist_PmManage` and `Build_Silver_WkRoDesc`, both in
`DP - Staging - Dev/Data Notebooks/` — full unfiltered data, no WHERE clause on
either.

**Verification:** both independent DuckDB scripts pass exactly —
`verify_shortcuts_inhist_wkrodesc.py` (both bronze shortcuts match JD Bronze direct:
`InHist_PmManage` 1,328,067 = 1,328,067, `WKRODESC` 1,623,053 = 1,623,053) and
`verify_silver_inhist_wkrodesc.py` (both Silver tables match their bronze shortcut
exactly).

**This closes out every Category A table in the original raw-sources catalog except
the InMaster group** (filed separately — see `project_nonjd_parts_order_tool_paused.md`
in project memory). Remaining, each needing its own future design work: Category B
(the Technician-family views — `Technician`, `TechnicianAttendance`,
`TechnicianEfficiency`, `TechnicianInvoice`, `TechnicianPunchedTime` — source-side
views JD's mirror doesn't replicate) and Category C (tables genuinely excluded from
JD's mirror — `ArMaster_Contact`, `InSalPar_Audit`, `Parts_InterbranchTransfers`,
`RepairOrderDetail`).

**Explicitly not part of this work:** no Franchise D or `LINE_NO = 1` scoping applied,
no gold-layer business logic, no report repointing, no refresh schedule.

## WKMECHADJ and WKMECHFL (2026-09-10) — the two missing pieces for the Technician-family rebuild

Brian pulled the real `CREATE/ALTER VIEW` SQL for all 5 Technician-family source-side
views directly from SQL Central this session (`Technician`, `TechnicianAttendance`,
`TechnicianEfficiency`, `TechnicianInvoice`, `TechnicianPunchedTime`) — fully decoding
Category B of the raw-sources catalog, previously the most opaque, undecided piece of
the whole migration effort. Full writeup — the actual Efficiency formula, complete
lineage for all 5 views, a real `BranchOperational` simplification opportunity found
along the way, and Brian's own stated intent to revisit the whole Labor Performance
report design once this reaches Gold — lives in project memory:
`project_labor_performance_technician_views_resolved.md`.

**The short version:** every input the eventual Gold rebuild needs traces back to a
table already in this backend — `Contact` (batch 1), `WkMechWk` and `WkOthSub` (batch
2) — except two new ones, both confirmed present in JD Bronze this session (no
direct-ODBC pull needed anywhere in this category, unlike Category C):
- **`WKMECHADJ`** — the real source behind `TechnicianAttendance`, and part of
  `TechnicianPunchedTime`'s join-gate logic (only counts labor on days a technician
  has a valid same-day attendance record).
- **`WKMECHFL`** — the real source behind `TechnicianInformation`, which `Technician`
  routes through.

Neither table ever had its own `LH_Master_Data` dataflow — both were only ever
consumed indirectly through the views — so there was no old dataflow column contract
to replicate here, unlike every other table migrated this session.

**What was built:** `WKMECHADJ` (1,583,585 rows) brought in whole — narrow enough (12
columns total) that there was no real curation decision to make. `WKMECHFL` (1,454
rows — matches the existing live `Technician` table's own row count exactly,
confirming it's the true one-row-per-technician master) curated to the 5 columns the
real `TechnicianInformation` view proved necessary, out of 38 total — the shortcut
itself stays full-fidelity regardless, so nothing is permanently lost by curating
Silver narrowly; the other 33 columns are one query away whenever the Gold-layer
rework wants them.

**One real casing correction:** the view's own SQL text references `Team_Code`, the
live bronze schema stores it as `TEAM_CODE`.

**One real, deliberate omission:** `TechnicianInformation`'s view applies
`CASE WHEN Is_Terminated = 'N' THEN 0 ELSE 1 END` to derive a boolean `IsTerminated`
flag — a real business interpretation (any non-`'N'` value, including nulls, means
"terminated"), not a faithful passthrough. `Silver_WkMechFl` carries the raw
`is_terminated` value through unconverted — same principle already applied to every
other business-rule filter deferred this session (`InHist_PmManage`'s `Franchise='D'`,
`WKRODESC`'s `LINE_NO=1`).

**Verification:** both independent DuckDB scripts pass exactly —
`verify_shortcuts_wkmechadj_wkmechfl.py` (`WKMECHADJ` 1,583,585 = 1,583,585,
`WKMECHFL` 1,454 = 1,454) and `verify_silver_wkmechadj_wkmechfl.py` (both Silver
tables match their bronze shortcut exactly).

**This is raw + Silver only.** The actual Gold-layer Technician-family Fact rebuild —
the real joins (`WkMechWk` ⋈ `WkOthSub`, gated by `WkMechAdj`), the invoiced-only and
2-year-window decisions, the Efficiency formula, the grouping logic — and any Labor
Performance report rework are deliberately separate, future pieces of work, not
started here. So is the `BranchOperational` simplification opportunity found in the
same investigation (see the project memory file for detail).

## InMaster (2026-09-10) — the plain base table, separate from PartsLookup/Parts-Ordering

`InMaster` is a completely separate Fabric object from two other things with confusingly
similar names, neither touched by this work: **`InMaster_PartsLookup_Raw`** (mission-critical,
live, feeds the production Parts Availability tool) and **`InMaster_Parts_Ordering_Raw`**
(which, confusingly, writes to a table literally named `InMaster_Raw`, belonging to the
Non-JD Parts Order Tool — a real project deliberately paused since 2026-08-04, see
`project_nonjd_parts_order_tool_paused.md`). This is the plain `InMaster` table — what the
old `df_InMaster_Raw` dataflow pulls today, feeding the live "Part Sales with Low Margin"
report.

**Why now:** two real reasons. First, it matches the exact same raw+Silver pattern as every
other table this session — no new complexity. Second, it's a proven dependency for
`Parts_InterbranchTransfers` — one of the Category C raw-sources catalog tables, confirmed
this session (via its actual SQL Anywhere view definition, pulled directly via SQL Central)
to be a VIEW joining `InSalPar` + `InMaster` + `InSalOrd`, not a table genuinely excluded
from JD's mirror after all. `InSalPar` and `InSalOrd` were already migrated in batch 1; this
brings in the third input. Full detail on this and the other Category C findings
(`ArMaster_Contact` also turned out to be a view) is in project memory
`project_category_c_views_resolved.md`. Brian's own reasoning, endorsed: "whatever we do
with the InMaster it will happen downstream from the raw silver layer anyway so we might as
well scope this in as well."

**Column contract:** replicates the old dataflow's exact 19-column contract — it already had
NO WHERE clause (full master pull already) and every selected source column matched the live
bronze schema's real casing exactly, no corrections needed. One deliberate addition beyond
the old 19 columns: `IN_TRANSIT_QTY` — not in the old dataflow's SELECT list, but proven
necessary by `Parts_InterbranchTransfers`'s real view SQL (`inm.in_transit_qty`), a specific
already-identified need, not speculative scope creep.

**Business context:** `LowMarginFlag` (`user_field_3`) is a manually-maintained flag parts
managers set to "Low" to mark margin-problem parts — the key field for the live "Part Sales
with Low Margin" report, which already reads `dbo.InMaster` directly via the SQL Analytics
Endpoint. This migration doesn't change that report's behavior, just gives it — and any
future consumer — a non-ODBC path to the same data.

**Verification:** both independent DuckDB scripts pass exactly —
`verify_shortcut_inmaster.py` (JD Bronze 1,111,807 rows / 73 columns = DP_Staging shortcut
1,111,807 rows / 73 columns) and `verify_silver_inmaster.py` (Silver_InMaster 1,111,807 rows,
20-column contract confirmed including `IN_TRANSIT_QTY`). `LowMarginFlag` breakdown: 1,065,514
null, 45,014 empty string, 1,279 `LOW` — confirms the field is real and sparsely populated, as
expected for a manually-maintained flag.

**This is raw + Silver only.** No Gold-layer logic, no `Parts_InterbranchTransfers` rebuild
(deliberately deferred — a separate future piece of work), no report work.

## InSalPar_Audit and RepairOrderDetail (2026-09-10) — the last 2 genuinely-excluded Category C tables

Neither of these tables has a JD Bronze mirror (confirmed via direct SQL Anywhere
system-catalog query — both `table_type = 'BASE'`, genuine base tables, not views). Unlike
every other table this session, there's no OneLake shortcut path, so both go through a
direct ODBC pull via Dataflow Gen2 — the same mechanism already proven in this backend by
`df_BranchOperational_Raw` and `df_JDIS_PartInformation_*_Raw`. Because every refresh is a
live ODBC query against the production SQL Anywhere box (not a zero-cost shortcut read),
this pair made different filtering/column-scope calls than the "bring in everything,
unfiltered" default used everywhere else this session.

**`InSalPar_Audit`** — real numbers from SQL Central (2026-09-10): 2,150,130 total rows,
only 299,145 (13.9%) match `PURORDER_TYPE = 'E'` (Emergency/Machine-Down orders); 76 total
real columns, the old dataflow only used 8. **Kept the `PURORDER_TYPE = 'E'` filter** — a
real 7.2x reduction in recurring ODBC load on the live production database, not a free
Spark-compute difference like every prior filter-drop decision this session. The table's
only known consumer (`Fact_MDInvoices_Closed`, matching Machine-Down order `FILE_NO`s) only
ever needed the `'E'` rows — revisit if a real second consumer shows up. **Stayed curated
to 9 columns** (the old 8 + one new addition, `Audit_TS`) rather than bringing in all 76 —
most of the other columns are internal/technical (`GUID_SO`, `Connection_ID`,
`Windows_User`, `SourceProgram`, `EPC_DocID`, a 4000-char `COMMENTS` field) with no
identified consumer, same discipline as `WKMECHFL`. `Audit_TS` was a real completeness gap
— the old dataflow never selected it despite this being literally an audit table.

**`RepairOrderDetail`** — only 2,875 total rows, much smaller than every other
repair-order-related table this session (`WKRODESC` 1.6M, `InHist_PmManage` 1.3M). The
column list (`CurrentDate`, `DaysSinceCreationDate`, `DaysSinceROFinishDate`,
`DaysSinceLastLabor`) strongly suggests this is a **live open-work-orders/WIP snapshot**,
not a historical archive — closed ROs most likely age out, the same pattern
`InSalPar_Audit`'s own old-dataflow documentation describes for `InSalPar` itself. Brought
in **all 31 real columns, unfiltered** — the old dataflow's 17-column "performance
optimization" (targeting a 1-minute refresh) was solving a problem that doesn't exist at
this table's real size. Worth knowing for whenever a Gold-layer fact table reads this:
`DaysSinceLastLabor`, `DaysSinceROFinishDate`, `DaysSinceCreationDate`, and `CurrentDate`
(landed as `SourceCurrentDate`) are computed by the source system at some point in time, not
recomputed live by this pull — same caution as `Parts_InterbranchTransfers`'s `OrderAge`.

**No Silver notebook for either** — the Dataflow Gen2's own SQL does the column
selection/renaming, matching `BranchOperational`'s precedent.

**Verification** (2026-09-10, via `verify_insalpar_audit_repairorderdetail.py`):
`RepairOrderDetail` matches exactly (2,875 = 2,875, 31-column contract confirmed).
`InSalPar_Audit` landed 291,124 rows against the raw 299,145 `PURORDER_TYPE='E'` count — the
gap is expected and not a bug: the query applies `SELECT DISTINCT` across only the 9
selected columns (same as the old dataflow), so audit events differing only in one of the
68 excluded technical columns collapse together. Every landed row confirmed
`PurOrderType = 'E'`, 9-column contract confirmed.

This closes out every table in `docs/architecture/jd-bronze-raw-sources-catalog.md`'s
Category A, B, and C. **Raw only** — no Gold-layer logic (including no
`Parts_InterbranchTransfers`/`ArMaster_Contact` rebuilds, no fact tables reading either of
these two), no report work.

## Prod tier

Stood up 2026-09-08 (`docs/superpowers/plans/2026-09-08-dp-prod-tier.md`). Same content as the Dev
tier above, built and verified **independently** — not copied or assumed identical.

| Lakehouse | Workspace | Lakehouse ID | Contents |
|---|---|---|---|
| DP_Staging | DP - Staging - Prod | `6713bd45-a4ad-47e6-8bff-1bb0415e9784` | `Tables/InTrans` — OneLake shortcut into `JD_EquipRDB_Production_Bronze.InTrans`, same source as Dev. `Tables/Silver_InTrans` — built by the Prod-tier `Build_Silver_InTrans.Notebook` (`workspaces/DP - Staging - Prod/Build_Silver_InTrans.Notebook`), cell code byte-identical to Dev's — only the notebook's own `default_lakehouse` METADATA binding differs. |
| DP_Presentation | DP - Presentation - Prod | `29d9df80-a383-4d40-9807-1e2e6cbff88f` | `Tables/Silver_InTrans` — OneLake shortcut into `DP_Staging (Prod).Silver_InTrans`. `Tables/dim_RepairOrder`, `Tables/Fact_PartsPromo`, `Tables/Fact_InTrans_AllPromo` — built by the Prod-tier `Build_Gold_PartsPromo.Notebook` (`workspaces/DP - Presentation - Prod/Build_Gold_PartsPromo.Notebook`). |

**First-run output (2026-09-08):** `Silver_InTrans` 20,462,845 rows (0.73% below bronze's
20,612,638 — expected, same as Dev); `Silver_InTrans` filtered ≥2022-01-01: 6,352,677 rows;
`dim_RepairOrder` 16,251 rows; `Fact_PartsPromo` 16,918 rows; `Fact_InTrans_AllPromo` (≥2023-01-01)
5,008,913 rows — all match Dev's counts exactly, as expected since both tiers read the same JD
Bronze source.

Verified independently via `verify_shortcut_prod.py`, `verify_silver_intrans_prod.py`,
`verify_gold_parts_promo_prod.py` (`.claude/queries/adhoc/dp-bronze-verify/`) — not cross-checked
against Dev's own result. Bronze shortcut matches JD source exactly (20,612,638 rows, same max
timestamp, RO 1985073's 9 rows match). Silver has 0 duplicate `(TransId, TransDatetime)` groups and
0 orphaned rows. **Gold matches `EquipRDB` (the real source system) exactly for all 11 known-bad
repair orders** — differences shown are floating-point noise (1e-12 to 1e-14), not real
discrepancies. RO 1985073: $627.64 sales / $414.73 cost / 8 lines, matching the live-fixed figure
already confirmed in the Dev tier and in the actual report UI.

**Variable Library `Prod` value set populated 2026-09-08** with the real GUIDs above, replacing the
`not-yet-created` placeholders (see table above).

**Corrected during planning, not left as a later fix:** notebooks do NOT call
`notebookutils.variableLibrary` at runtime — confirmed via current Fabric docs that this API only
supports access to variable libraries within the same workspace, which every consumer here
(`Build_Gold_PartsPromo` living in a different workspace than the Variable Library) would have
needed to violate. Both notebooks resolve their own lakehouse via `default_lakehouse` METADATA
binding (an environment-specific difference in the same category as a `.tmdl` connection string
differing per report tier) and reach the one genuinely cross-workspace dependency (Gold's need for
Silver_InTrans) via a OneLake shortcut instead — the same "shortcuts, not copies" principle already
used for bronze. Zero hardcoded GUIDs in either notebook's actual code; cell code is byte-identical
between the Dev and Prod tiers. The Variable Library remains the authoritative record of the 4
lakehouse GUIDs for humans and any future consumer that *does* support cross-workspace resolution
(a Fabric pipeline, or an item-reference shortcut variable — both Fabric-documented, neither used by
this build).

**Gotcha (confirmed 2026-09-08):** `fabric-workspace-docs` has a local git hook enforcing the
repo's own stated convention (root `CLAUDE.md`: "Direct pushes to `main` should be avoided even on
`fabric-workspace-docs`") — a direct `git push origin main` is rejected outright, even though GitHub
itself can't technically enforce branch protection on this repo (Free plan limitation). New
Prod-tier files with no `dev` counterpart to promote via merge (different git folder paths per
workspace) still need a real branch + PR + `gh pr merge` into `main`, not a direct push.
