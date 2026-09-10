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
| DP_Staging | DP - Staging - Dev | `876255e0-d462-4697-adc1-4a655f5bb101` | `Tables/InTrans` — OneLake shortcut (passthrough identity) into `JD_EquipRDB_Production_Bronze.InTrans` (`JD_FabricOneLake` workspace `4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9`, lakehouse `7348c3a6-8694-4d11-bc70-1bd55be84ea2`). Verified 2026-09-04: row count, min/max timestamp, and the RO 1985073 spot check (9 rows) all match the source exactly — see `.claude/queries/adhoc/dp-bronze-verify/verify_shortcut.py`. Also holds `Tables/Silver_InTrans`, `Tables/GlTrans` (OneLake shortcut into JD's Bronze mirror), `Tables/BranchOperational` (Dataflow Gen2 ingestion, not a shortcut — see `dim_BranchLocation` below), `Tables/PartInformation_Active`, `Tables/PartInformation_Dead`, and `Tables/Silver_PartInformation` — see below for each. Also holds 9 more OneLake shortcuts into `JD_EquipRDB_Production_Bronze` (`ArMaster`, `ArMaster_Customer`, `contact`, `GLMASTER`, `InSalOrd`, `InSalPar`, `VhStockAccess`, `WarSubCl_Labour`, `Branch_Name`) plus their corresponding `Silver_*` tables — see "Raw sources batch 1" below. |
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

### `dim_BranchLocation` — faithful port, no bug found

Built by `Build_Gold_BranchLocation.Notebook` (`Dimensions/Build_Gold_BranchLocation.Notebook`
in `DP - Presentation - Dev`). Unlike `dim_DateTable`, no correctness issue was found in
this table's enrichment logic during review — the `MarketPresence`/`TerritoryCoverage`/
`OperationalPriority`/`RegionalClassification`/`ServiceHours`/`DistanceFromHub`/
`DataQualityScore` heuristics are all pattern-matched on `BranchID`/`BranchName`/`State`/
`City`, none date-dependent. Ported faithfully to PySpark from production's
`dim_BranchLocation.pq`.

Its source, `BranchOperational`, is an EquipRDB **view**, not a base table — confirmed
this session it isn't in JD's Bronze mirror (JD's replication apparently only covers
base tables). Gets its own small Dataflow Gen2 ingestion instead
(`df_BranchOperational_Raw`, `Raw Data - Dataflows/` in `DP - Staging - Dev` — same
mechanism production already uses), landing into `DP_Staging`, then reaches the gold
notebook via a cross-workspace shortcut — same "shortcuts, not copies" pattern as
`Silver_InTrans`/`GlTrans`.

Verified 2026-09-09 via `verify_gold_branchlocation.py`: 69 rows (matches production
exactly). Seminole (`BranchID '1'` — the specific branch a prior production bug, an
arbitrary `Table.Skip(30)`, used to drop) is present and correctly classified as
`Main Branch` / `West Texas`, zero Hourly/Salary branches leaked through the filter,
`BranchType` distribution shows a healthy mix (23 Main Branch, 22 IS Shop, 15 Set-Up
Shop, 9 CP Shop).

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
