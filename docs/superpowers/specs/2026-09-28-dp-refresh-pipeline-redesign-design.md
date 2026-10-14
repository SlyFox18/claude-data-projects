# DP Refresh Pipeline Redesign — Design

**Date:** 2026-09-28
**Status:** Approved in brainstorming (Brian, 2026-09-28)
**Supersedes the options section of:** `docs/architecture/dp-refresh-pipeline-assessment.md` (§4)
**Related:** `projects/jd-bronze-pipelines/README.md` (Bronze runbook), `fabric-workspace-docs/deploy/dp_backend_scope.json`

---

## 1. Goal

One reliable, efficient refresh for the DP backend (DP_Staging Silver → DP_Presentation Gold →
report semantic models) that:

- runs every producer in the correct dependency order, with no race conditions;
- keeps going when individual items fail, and retries transient errors;
- fails loudly and does nothing downstream when JD's Bronze data is bad;
- alerts clearly (Teams, alert email, summary email) with the fix in the message;
- records duration and CU so capacity can be watched and more frequent refreshes decided with data;
- deploys unchanged from Dev to Prod through fabric-cicd.

**Out of scope:** converting notebooks to incremental (MERGE) processing, Materialized Lake Views,
the Prod deployment itself, and the report validation that follows this work.

## 2. Decisions

| Topic | Decision |
|---|---|
| Orchestration | Option 2: a thin pipeline plus orchestrator notebooks using `notebookutils.notebook.runMultiple` with a dependency DAG in a shared Spark session. **Two identical orchestrators, one per lakehouse** (see revision note below). **Fallback** if the prototype fails: today's per-notebook pipeline ForEach with explicit waves (Option A) |
| Start time | **4:15 AM CST, Mon–Fri.** It's proven outside the Equip blackout; target: reports fresh by 8:00 AM |
| JD Incremental | Invoked **by our pipeline** at the start of each run, not on its own schedule (once this pipeline is scheduled) |
| Bronze failure | **Stop everything.** No notebooks and no model refresh; loud alert |
| Silver/Gold/dataflow failure | Retry, then skip only the failed item's dependents; everything else runs; **all models still refresh** |
| Model refresh | Always refresh every report model, unless Bronze failed |
| Alerts | Teams on any failure; separate High-importance alert email on complete failure; summary email every run |
| Environments | **No custom Spark environment.** Delete `DP_Silver_HighConcurrency` and `DP_Gold_HighConcurrency` (Git-sync binding bug, 2026-09-18) |
| Cadences | `daily`, `weekly` (Mondays), `monthly` (the 1st), `manual` (never scheduled; e.g. the fixed 2020–2030 `dim_DateTable`), `intraday` (built, off until measured). Every producer's cadence was reviewed with Brian in Phase 1 (added 2026-09-29) |
| Session Spark settings | The orchestrator applies session-level settings once (e.g. shuffle partitions / broadcast threshold, adapted from JD's IncrementalCopyData_NB); all children inherit them. Adopted only if Phase 1 tuning shows a gain |
| Dev scheduling | On demand until cutover. JD Incremental keeps its own daily schedule until then |

### Revision (2026-09-28, while planning): one orchestrator per lakehouse

Microsoft's `runMultiple` documentation: a child notebook is **blocked if its default lakehouse differs
from the orchestrator's**. The only bypass (`useRootDefaultLakehouse: True`) makes the child use the
*orchestrator's* lakehouse, which would send Silver writes into DP_Presentation. So one orchestrator
can't run both tiers. Every DP notebook is consistent (all 30 Staging notebooks default to DP_Staging,
all 69 Presentation notebooks to DP_Presentation), so:

- `Run_DP_Refresh` exists **twice with identical code**: in DP - Staging (default lakehouse
  DP_Staging; runs Silver) and in DP - Presentation (default lakehouse DP_Presentation; runs Gold,
  then the metadata and model refresh). A CI test asserts the two code bodies are identical.
- No cross-workspace notebook calls are needed at all, which removes the biggest prototype risk.
- The pipeline runs Silver's orchestrator, then Gold's, passing the Silver failures forward so Gold
  skips their dependents. Cross-tier order comes from the pipeline; within-tier order from the DAG.
- CI gains one check: every registered item's default lakehouse matches its tier.

## 3. Timeline

```
12:00 AM  JD PL_EquipRDB_To_Fabric_Full (JD schedule, runs as SPN) — unchanged
          ~ Equip database blackout ~
 4:15 AM  Pipeline_DP_Refresh
            1. Invoke JD PL_EquipRDB_To_Fabric_Incremental (wait; 1 retry) ─┐ parallel
            2. df_RepairOrderDetail_Raw, df_InSalPar_Audit_Raw ─────────────┘
            3. Run_DP_Refresh [Staging](mode): Bronze check → Silver DAG
            4. Run_DP_Refresh [Presentation](mode, silver_failed): Gold DAG
               → SQL endpoint metadata refresh → model refresh → run log
            5. Alerts
~5:30–6:00 done; ~2 hours of slack before 8:00 for a rerun
```

## 4. Components

### 4.1 Config — `fabric-workspace-docs/deploy/dp_backend_scope.json`

The single source of truth, deployed by CI to `Files/config/` in both Dev lakehouses (existing mechanism).

```json
{
  "items": [
    { "name": "Build_Gold_ServiceDetail", "type": "notebook", "workspace": "presentation",
      "tier": "gold", "cadence": "daily",
      "dependsOn": ["Build_Gold_ServiceInvoices", "Build_Silver_WkRoFile"],
      "produces": ["Fact_Service_Detail"] },
    { "name": "df_RepairOrderDetail_Raw", "type": "dataflow", "workspace": "staging",
      "tier": "staging", "cadence": "daily", "dependsOn": [], "produces": ["RepairOrderDetail"] }
  ],
  "reports": [
    { "model": "Customer Anatomy", "workspace": "RP - Dev", "tables": ["Fact_Service_Detail", "..."] }
  ],
  "excluded": [ { "name": "Utilities_...", "reason": "one-off backfill" } ]
}
```

- **No GUIDs.** `workspace` is logical (`staging` / `presentation`), resolved at run time to
  `DP - Staging - <Env>` / `DP - Presentation - <Env>`, where `<Env>` comes from the orchestrator's
  own workspace name.
- `produces` lists the tables each item writes. `dependsOn` lists items (not tables).
- A dataflow's status comes from the pipeline. Its dependents skip if it failed.
- `reports[].workspace` for Prod is resolved at promotion time (`parameter.yml` / Variable Library review).

### 4.2 CI checks (`fabric-workspace-docs/deploy/`, run on every push to `dev`)

1. **Missing dependency:** scan each notebook's source for tables it reads (Delta paths
   `Tables/<name>`, `spark.table`, `spark.read...load`, shortcut names). If a table read is
   produced by another registered item that isn't in `dependsOn` (directly or transitively), fail.
2. **Unregistered notebook:** every `Build_*` notebook folder in the DP workspaces must be in
   `items` or `excluded`.
3. **Graph integrity:** no cycles; every `dependsOn` name exists; names are unique.

These run with the existing unit tests (`deploy/test_lib.py`).

### 4.3 Orchestrator notebook — `Run_DP_Refresh` (one copy per workspace, `Orchestration` folder)

Parameters: `mode` = `daily` | `monthly` | `intraday` | `rerun_failed`; `dry_run` (bool);
`dataflow_status` (JSON from the pipeline); `upstream_failed` (JSON list; the Staging copy's failed
and skipped items, passed to the Presentation copy); `run_id`.

The copy detects its tier from its own default lakehouse (`DP_Staging` → silver,
`DP_Presentation` → gold). Step 2 (Bronze check) runs in the Staging copy only; steps 5–6 run in the
Presentation copy only. Both write to `dp_refresh_log` in DP_Presentation (the Staging copy writes by
absolute OneLake path).

1. **Concurrency guard:** if the run log shows a run `InProgress` started less than 4 hours ago, exit `already_running`.
2. **Bronze check:** the logic of `tools/dp-migration/jd_bronze_check.py`, using the Fabric REST
   API with the notebook's token:
   - JD Full's latest run: every Copy activity Succeeded, started today (CST);
   - JD Incremental's latest run: started today (CST) and has no failed activities (every
     `LookupNewWatermarkValue` succeeded);
   - incremental watermarks are reported in the log for information only. A table with no source
     changes keeps an old `LastSyncToLakeHouse` (e.g. Parts_Pricing_Admin), so the date alone is
     not a failure signal.
   On failure: write the log and exit `bronze_failed` with details.
3. **Build the DAG** from the items matching the mode:
   - `daily`: `cadence = daily`; `monthly`: `daily` + `monthly`; `intraday`: the items whose Bronze
     inputs are incremental tables, plus their dependents;
   - `rerun_failed`: the failed and skipped items of the latest run, plus their dependents.
   Dataflow items are resolved from `dataflow_status` (not executed). Items depending on a failed
   dataflow are marked skipped.
4. **Execute** `runMultiple(dag)`, with per activity `retry = 2`, `retryIntervalInSeconds = 60`,
   `timeoutPerCellInSeconds` from config (default 1800), and a DAG-level `concurrency` set from the
   prototype. Only items of this copy's tier are in its DAG. Items whose dependencies appear in
   `upstream_failed` are marked skipped. A failed item's dependents don't run.
   With `dry_run`, print the ordered plan and the models, then exit.
5. **Refresh the SQL analytics endpoint metadata** for DP_Presentation (and DP_Staging), so
   VACUUMed Gold tables resolve.
6. **Refresh every report model** in `reports` by name (semantic-link `fabric.refresh_dataset`),
   poll until done, with 1 retry per model.
7. **Write the run log** and return a summary via `notebookutils.notebook.exit(json)`:
   `status` (`ok` | `partial` | `bronze_failed` | `error`), counts, the failed/skipped items,
   affected reports, and the slowest 5 items.

### 4.4 Run log — `dp_refresh_log` (DP_Presentation Delta table)

| Column | Notes |
|---|---|
| `run_id`, `mode`, `row_type` | `row_type` = `run` \| `item` \| `model` \| `bronze` |
| `name` | item / model / check name |
| `status` | `Succeeded` \| `Failed` \| `Skipped` \| `InProgress` |
| `start_utc`, `end_utc`, `duration_s`, `attempts` | |
| `error` | first 1,000 characters |
| `skipped_because` | the upstream item that failed |
| `cu_seconds` | `run` rows only; backfilled by the monitoring script |

### 4.5 Pipeline — `Pipeline_DP_Refresh` (DP - Presentation)

```
Invoke JD Incremental (wait, retry 1) ─┐
Dataflow: df_RepairOrderDetail_Raw ────┼→ Run_DP_Refresh [Staging](mode, dataflow_status)
Dataflow: df_InSalPar_Audit_Raw ───────┘        │ (stop here if bronze_failed)
                                                ▼
                                         Run_DP_Refresh [Presentation](mode, upstream_failed)
                                                │
                                                ├→ If status ≠ ok → Teams post
                                                ├→ If status ∈ {bronze_failed, error} or the notebook
                                                │   activity failed → alert email (High importance)
                                                └→ Always → summary email
```

- The dataflow activities continue on failure, and their outcomes feed `dataflow_status`.
- The Incremental invoke failing means the Bronze check fails (the orchestrator sees the failed
  run).
- Pipeline parameter: `mode` (default `daily`; an expression picks `monthly` on the 1st).
- **Replaces** `Pipeline_DP_Daily_Refresh`, `Pipeline_DP_Monthly_Refresh`,
  `Pipeline_DP_SemanticModel_Refresh`; deletes the orphan `Pipeline_DP_Master_Orchestrator`.

## 5. Alerts

| Situation | Teams (Fabric Monitoring channel) | Alert email (High) | Summary email |
|---|---|---|---|
| Complete failure: `bronze_failed`, orchestrator `error`, or pipeline error | ✅ | ✅ `🔴 DP Refresh FAILED – <reason>` | ✅ |
| Partial: some items/models failed | ✅ | — | ✅ `⚠ DP Refresh: N failures` |
| All succeeded | — | — | ✅ `✅ DP Refresh OK – <finish time>` |

Failure messages include: what failed and the first line of the error, what was skipped, which
**reports carry partly stale data**, and the fix. For item failures the fix is "fix the cause,
run `Pipeline_DP_Refresh` with mode = `rerun_failed`". For Bronze failures it's the runbook link.

The summary email includes: start/finish, succeeded/failed/skipped counts, models refreshed, total
duration, the slowest 5 items, and CU vs. budget (when available, §6).

## 6. Capacity monitoring

- `projects/fabric-monitoring` (6 AM scheduled task) is extended to look up the DP run's CU
  (pipeline, orchestrator session, dataflows, model refreshes) in Capacity Metrics and write
  `cu_seconds` onto the `run` row. **CU is per run, not per notebook**, because of the shared session;
  per-item duration is the proxy for cost.
- The summary email shows run CU as % of F8's daily budget (8 CU × 86,400 s) and a 7-day trend.
  Warning threshold: **25%** to start, tuned after the baseline.
- A weekly slowest-items list identifies incremental-processing candidates.
- **More frequent refresh:** after a 2-week baseline, estimate intraday cost from the log. Enable
  `intraday` (for example noon and 3 PM) only if it fits. Only JD's 17 incremental tables change
  intraday (JD Full runs once nightly).

## 7. Rollout

**Phase 0: Prototype (decision gate).** A minimal orchestrator in each workspace runs the Labor
Performance chain (5 Silver in Staging; 1 dim + 3 facts in Presentation). Prove `runMultiple` within
each lakehouse, the shared session, retry and skip-dependents behaviour, and a concurrency level for
F8. Compare duration and CU against the same 9 notebooks run one session each. Brian reviews the
numbers → Option 2 or Option A.

**Phase 1: Config + CI.** Map all producers (~91) with `dependsOn`/`produces`/cadence; the monthly
dims that feed daily facts (`dim_Technician_Code_Names`, `dim_Salesperson`) → daily; the CI checks;
a hygiene audit of all Gold notebooks (UTC pin, VACUUM after overwrite, path-based writes);
orphan cleanup **after Brian confirms the list** (both Environment items,
`Pipeline_DP_Master_Orchestrator`, `dim_JobCodes_v2`, `BranchOperational`,
`Silver_ArMasterCustomer_1`, Utilities notebooks, `OpenOrders`/`OpenOrderParts` if unused).

**Phase 2: Build.** The orchestrator (all modes), run log, Bronze check, metadata refresh, model
refresh; `Pipeline_DP_Refresh` with alerts; retire the old DP pipelines. All notebook code reaches
Fabric by push → CI → Git sync (`tools/dp-migration/git_sync.py`); never `fab import`.

**Phase 3: Test.**
- `dry_run`: the plan order is checked against the dependency map.
- Failure drills: a test notebook that always fails (dependents skip, the rest completes, Teams +
  summary fire, `rerun_failed` fixes only that branch); a simulated Bronze failure (full stop,
  Teams + alert email).
- One full manual run, then the RP-Dev report validation (a separate, already-planned step).

**Scheduling:** Dev stays on demand. JD Incremental keeps its own daily schedule until
`Pipeline_DP_Refresh` is scheduled; then its schedule is switched off.

**Production (later stage):** fabric-cicd deploys notebooks, orchestrator, config and pipeline to
the Prod workspaces. Notebooks resolve by name + workspace-name suffix. Pipeline item references
(orchestrator, dataflows, JD pipeline) go through `parameter.yml` or the Variable Library. Only Prod
gets the 4:15 schedule.

## 8. Risks

| Risk | Mitigation |
|---|---|
| A child with a different default lakehouse is blocked (or redirected with `useRootDefaultLakehouse`) | One orchestrator per lakehouse; never set `useRootDefaultLakehouse`; CI checks each item's default lakehouse |
| One shared session is too small for the whole DAG on F8 | Tune `concurrency`; long items get their own timeout; the prototype measures |
| The dependency scanner misses a read pattern | Start with the patterns used in the repo; any read it can't classify fails CI until handled |
| The model refresh uses Brian's identity; credentials expire | The failure alert names the model; the SPN migration plan (`2026-08-04-sm-refresh-spn-migration.md`) can later move this to the SPN |
| JD's Full pipeline hides copy failures | The Bronze check reads activity runs, never the pipeline status |
