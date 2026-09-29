# DP Refresh Redesign — Phase 1 Results

**Date:** 2026-09-29
**Plan:** `docs/superpowers/plans/2026-09-29-dp-refresh-phase1-config-and-tuning.md`
**Spec:** `docs/superpowers/specs/2026-09-28-dp-refresh-pipeline-redesign-design.md`
**Next:** Phase 2–3 plan (orchestrator `Run_DP_Refresh`, `dp_refresh_log`, `Pipeline_DP_Refresh`, alerts, drills)

---

## 1. The config: `fabric-workspace-docs/deploy/dp_refresh_dag.json`

| | Count |
|---|---|
| Items | **100**: 98 notebooks (30 Silver, 68 Gold) + 2 staging dataflows |
| Report models mapped to their DP tables | **24** (every RP - Dev model that reads DP_Presentation) |
| Excluded (not scheduled producers) | 4: `Proto_RunMultiple`, `Proto_FailProbe`, `Proto_AfterFail`, `Utilities_BackfillMDInvoicesNoFreightSnapshot_20260923` (the Utilities one has since been deleted in Fabric; its local untracked copy is still excluded) |
| Cadence (Brian's review, `dp-refresh-cadence-review.md`) | **73 daily · 13 weekly · 12 manual · 2 monthly** |

- The config was bootstrapped from a static scan, then reviewed. Spot-checks of 5 complex notebooks
  matched their code exactly.
- **45 producers had never been scheduled** (not in the old `dp_backend_scope.json`), including Silver
  Invoice, WkOthSub, WkRoFile and WkInvReg, which Customer Anatomy needs. That was the "Silver scheduling
  gap", now closed.
- **A real missing dependency surfaced:** 17 Gold notebooks read `Silver_InTrans`, and the old pipeline
  never ordered them after it (it's a dynamic notebook the old config didn't model). They now depend on it.
- **4 dynamic notebooks** (table names built at run time) were reviewed by hand and marked
  `dynamicReviewed`: MDInvoicesNoFreightSnapshot, PartsOpenOrdersSnapshot, PlanterInspectionPartSales,
  Silver_InTrans.

## 2. CI gates (every push to `dev`, before deploying)

1. `pytest deploy` (35 tests: scanner, checker, hygiene).
2. `deploy/dag_check.py` fails the push on:
   - a notebook reading a table produced by another item it doesn't (transitively) depend on — **the
     race-condition guard**;
   - an unregistered `Build_*` notebook;
   - a registered notebook missing from the repo;
   - an unknown or excluded dependency, or a cycle;
   - a Silver→Gold (wrong-tier) dependency;
   - a wrong default lakehouse or workspace;
   - declared outputs that differ from the code;
   - dynamic notebooks not reviewed;
   - report tables that don't match the model, or have no producer; stale report entries;
   - bad config values.
   Proven: removing one dependency makes it fail with the exact reason.
3. `deploy/hygiene_audit.py`: every Gold notebook pins UTC, VACUUMs each table it writes, and avoids
   `saveAsTable`.

## 3. Hygiene fixes

48 Gold notebooks got whatever they were missing: the UTC pin (51 insertions in total, including 3 that
needed only UTC) and 55 VACUUM statements. The changes are additions only (+267/−0). All 201 code cells
parse; 5 edited notebooks and the full Customer Anatomy chain (4 times) ran clean afterwards.

## 4. Orphans (Brian approved 2026-09-29)

- **Deleted:** Environments `DP_Silver_HighConcurrency` and `DP_Gold_HighConcurrency` (neither is a
  workspace default); `Pipeline_DP_Master_Orchestrator`; 3 workspace-only Utilities notebooks; table
  `dim_JobCodes_v2`; table `BranchOperational` (Staging) and its shortcut (Presentation); shortcut
  `Silver_ArMasterCustomer_1`.
- **Kept, cadence manual:** `Build_Gold_OpenOrders` / `Build_Gold_OpenOrderParts` (no report reads them).
- The old DP pipelines (Daily/Monthly/SemanticModel) stay until Phase 2 replaces them.

## 5. Measurement calibration (`tools/dp-migration/spark_usage.py`)

Allocated executor core-seconds (Spark resource-usage API) vs. Capacity Metrics CU for the Phase 0 runs:

| Run kind | CU ÷ core-seconds |
|---|---|
| One notebook alone (3 samples) | 0.465 – 0.480 |
| Shared `runMultiple` session (2 samples) | 0.823 – 0.952 |

The ratio is **stable within a run kind but not across kinds**, so core-seconds are used here only to
compare runs of the same kind (all tuning runs below are shared sessions).

## 6. Tuning: Customer Anatomy chain (11 Silver + 14 Gold notebooks), 2026-09-29

Workspace Spark pool: Starter Pool, max 6 nodes / 5 executors, runtime 1.3 (both DP workspaces).

| Run | Concurrency | Session settings | Silver s | Gold s | **Total s** | Silver core-s | Gold core-s | **Total core-s** | Efficiency S / G |
|---|---|---|---|---|---|---|---|---|---|
| ca_c2 | 2 | default | 396 | 451 | 847 | 3,639 | 6,829 | 10,468 | 0.51 / 0.52 |
| ca_c4 | 4 | default | 372 | 414 | 785 | 5,447 | 6,071 | 11,518 | 0.47 / 0.62 |
| ca_c8 | 8 | default | 290 | 439 | 728 | 4,197 | 6,405 | 10,603 | 0.62 / 0.69 |
| **ca_conf** | **8** | shuffle partitions 16, broadcast 50 MB | **282** | **369** | **651** | 4,114 | **5,333** | **9,447** | 0.61 / 0.55 |

- **Row counts were identical across all 4 runs** for all 13 Customer Anatomy tables.
- **Concurrency changes speed much more than capacity.** Core-seconds stay within ±5% across 2/4/8
  (single runs vary about 10% from noise), while wall time drops 14% from c2 to c8, and core efficiency
  is best at 8.
- **The session settings helped Gold:** −17% core-seconds and −16% time versus the same concurrency with
  defaults. That's beyond run-to-run noise, most likely from the higher broadcast threshold letting small
  dims join without a shuffle. The Silver difference is within noise.

**Capacity Metrics cross-check** ('Metrics By Item And Hour', hours are local CDT and group each
operation by its start hour, so runs pair up):

| Hour (CDT) | Orchestrator | Runs in that hour | CU (s) |
|---|---|---|---|
| 09:00 | Staging | c2 Silver | 4,375.9 |
| 10:00 | Staging | c4 Silver | 4,076.7 |
| 10:00 | Presentation | c2 Gold + c4 Gold | 9,496.9 |
| 11:00 | Staging | c8 Silver + conf Silver | 6,710.6 |
| 11:00 | Presentation | c8 Gold + conf Gold | 8,901.4 |

- c2 + c4 = 17,949.5 CU(s), about **8,975 per run**. c8 + conf = 15,612.0 CU(s), about **7,806 per run**
  (**13% less**). That agrees with the core-seconds ranking.
- Splitting each pair by its core-seconds share gives roughly c2 9,400 · c4 8,550 · c8 8,250 ·
  **conf 7,360** CU(s). That's CU ÷ core-seconds ≈ 0.78–0.90, consistent with the §5 shared-session
  calibration.
- **Budget:** the best configuration runs the whole 25-notebook Customer Anatomy chain for about
  **1.1% of F8's daily capacity** (691,200 CU s).

## 7. Recommendations for Phase 2

1. **Default `concurrency = 8`** (half of F8's 16 vCores, the same rule JD's notebook uses).
2. **Apply the session settings in the orchestrator** (`spark.sql.shuffle.partitions = 16`,
   `spark.sql.autoBroadcastJoinThreshold = 52428800`), kept in the config so they can be changed without
   code edits. Keep measuring on the first full runs.
3. **Leave the workspace Spark pool as is** (Starter Pool, 6 nodes / 5 executors). Nothing in these runs
   points to the pool as the limit. Core efficiency of 0.55–0.69 means allocated cores are mostly busy
   with little queueing. Revisit if the full ~90-item DAG shows long queued times.

## 8. What Phase 2 needs to know

- **Cadences:** `weekly` = Mondays, `monthly` = the 1st, `manual` = never scheduled (run on code
  change); `intraday` isn't used yet.
- **Skipped dependents** come back from `runMultiple` as exceptions reading "Job X failed due to upstream
  job Y failed". Classify these as Skipped.
- Catch `Exception` around `runMultiple`. The documented `notebookutils.common.exceptions` import doesn't
  exist in runtime 1.3; the real class is
  `notebookutils.mssparkutils.handlers.notebookHandler.RunMultipleFailedException`.
- **Cross-tier edges** (Gold depending on Silver) are in the config. The pipeline orders the tiers, and the
  Presentation orchestrator uses `upstream_failed` to skip dependents of failed Silver items.
  `tier_dag()` in `deploy/dag_config.py` already builds a tier's sub-DAG.
- After Gold runs, refresh the SQL endpoint metadata before any model refresh (VACUUM).
- `dp_backend_scope.json` and the 3 old DP pipelines are still live and untouched. Phase 2 retires them.

## 9. Follow-up found along the way: JD's Full load is the capacity's biggest consumer

Capacity Metrics (14 days to 2026-09-29, Brian's screenshot): `PL_EquipRDB_To_Fabric_Full` used
**1,159,187 CU(s), 38% of all capacity** (3,008,769 in total). That's about 83,000 CU(s) a day, roughly
**12% of F8's daily budget**, spent reloading 98 tables in full every night. The DP Customer Anatomy chain
by comparison costs about 7,400 CU(s) per run.

Suggested separate project after the DP redesign: rank the 98 Full-load tables by size and copy time,
move the large ones that have a reliable "modified" column onto the watermark-based Incremental list
(the same mechanism JD already uses for 17 tables), and measure the saving. SPI now controls both JD
pipelines (see `projects/jd-bronze-pipelines/README.md`).
