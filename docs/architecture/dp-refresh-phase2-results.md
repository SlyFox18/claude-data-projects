# DP Refresh Redesign — Phase 2–3 Results & Operating Guide

**Date:** 2026-09-29
**Plan:** `docs/superpowers/plans/2026-09-29-dp-refresh-phase2-orchestrator.md`
**Earlier phases:** `dp-refresh-prototype-results.md` (Phase 0), `dp-refresh-phase1-results.md` (Phase 1)
**Status:** built and proven in Dev. Dev stays **on-demand** (no schedule) until the Prod stage.

---

## 1. What was built (fabric-workspace-docs)

| Piece | Where | Job |
|---|---|---|
| `Pipeline_DP_Refresh` | DP - Presentation - Dev / Pipelines | Run_Silver → Run_Gold → summary email; alert email (High) on complete failure; Teams post on any failure; crash emails + Teams if a notebook dies |
| `Run_DP_Refresh` ×2 | DP - Staging - Dev / Orchestration, DP - Presentation - Dev / Orchestration | Staging copy: JD Incremental + 2 staging dataflows + Bronze check + Silver DAG. Presentation copy: Gold DAG + SQL endpoint metadata refresh + all report models + summary. **Generated** from the two files below; never edit the notebooks |
| `deploy/orchestrator_core.py` | repo | All decisions: due cadences, selection, DAG + skip propagation, result classification, Bronze verdict, affected reports, summary text. 69 unit tests in `deploy/` |
| `deploy/orchestrator_glue.py` | repo | Fabric-only code: jobs API, Bronze fetch, runMultiple, log, metadata + model refresh, exit |
| `deploy/render_orchestrator.py` | repo | Writes both notebooks; CI fails if they're stale |
| `deploy/dp_refresh_dag.json` | repo → both lakehouses `Files/config/` (by CI) | Items, dependencies, cadences, reports, and `orchestrator` settings (concurrency 8, session settings, retries, report workspace) |
| `dp_refresh_log` | DP_Presentation Delta table | One row per run (InProgress + final), item, dataflow, model, Bronze check |

Retired (Brian approved 2026-09-29): `Pipeline_DP_Daily_Refresh`, `Pipeline_DP_Monthly_Refresh`,
`Pipeline_DP_SemanticModel_Refresh`, `Proto_RunMultiple` ×2, `Proto_AfterFail`. `Proto_FailProbe` stays for drills.

## 2. Drills (all 2026-09-29, Dev)

| Drill | Parameters | Expected | Actual |
|---|---|---|---|
| Dry run | `mode=all dry_run=true` | Plan only; 🧪 email | ✅ 2 dataflows / 24 Silver / 62 Gold / 24 models (all non-manual items); nothing ran, no log rows |
| Gold failure | `mode=items items=Build_Gold_CustomerList,Build_Gold_CustomerLookup,Build_Gold_EngagedAcres inject_failure=Build_Gold_CustomerList` | CustomerList Failed, CustomerLookup Skipped, EngagedAcres Succeeded; ⚠ email + Teams, no alert | ✅ exactly that; stale-report list correct |
| rerun_failed | `mode=rerun_failed` | Re-runs only CustomerList + CustomerLookup | ✅ both Succeeded |
| Bronze failure | `mode=all simulate_bronze_failure=true` | Nothing rebuilt, no model refresh; 🔴 summary + High alert email + Teams | ✅ exactly that (JD Incremental + both dataflows still ran first) |
| Crash path | (happened for real, see §3) | 🔴 "Silver orchestrator crashed" email (High) + Teams | ✅ |

## 3. Problems the drills found and fixed

1. **Pipeline parameters arrive as None, not "".** Unset pipeline parameters reach the notebook as
   `None`, which crashed `items.split` before error handling. Fixed by normalising every parameter.
   This also proved the crash email and Teams path for real.
2. **12 of 24 report models couldn't refresh unattended:** "semantic model uses a default data
   connection without explicit connection credentials". Brian mapped each one's SQL source to the
   shareable cloud connection **`SQL_DP_Presentation_v2`** (OAuth2) in the model's
   Settings → Gateway and cloud connections. The other 12 had been fixed during their migrations.
   **Any new or republished DP report model needs this mapping, or the pipeline's model refresh fails.**
3. **Teams posts give no notification.** They're posted as Brian (his connection), and Teams never
   notifies you about your own messages. Complete failures still send the High-importance email. The
   option, if wanted: a Teams Workflows webhook so posts come from a bot.

## 4. Full run (2026-09-29 17:01–17:39 CDT, `mode=all`)

**✅ OK:** 88 of 88 items succeeded (2 dataflows, 24 Silver, 62 Gold) and 24 of 24 models refreshed.

| Step | Time |
|---|---|
| JD Incremental + 2 dataflows + Bronze check | ~10 min |
| Silver (24 notebooks, one session) | 7.1 min |
| Gold (62 notebooks, one session) | 12.3 min |
| 24 model refreshes (4 at a time) | 8.1 min |
| **Total** | **38 min** (a 4:15 AM start finishes ≈ 4:55 AM) |

## 5. Operating guide

**Run it:** DP - Presentation - Dev → `Pipeline_DP_Refresh` → Run. The parameters (all strings) are:

| Parameter | Values | Use |
|---|---|---|
| `mode` | `scheduled` (default: daily, + weekly on Mondays, + monthly on the 1st or the first weekday after), `all` (everything except manual), `items`, `rerun_failed`, `intraday` (no items yet) | |
| `items` | comma-separated item names | with `mode=items`, e.g. to run a manual item like `Build_Gold_DateTable` |
| `dry_run` | `true` | show the plan without running anything |
| `inject_failure` | a Gold item name | drills only: runs `Proto_FailProbe` in its place |
| `simulate_bronze_failure` | `true` | drills only |

**When an email says:**
- **✅ OK:** nothing to do.
- **⚠ N failed / skipped / models failed:** fix the cause (the email names the item and its first error
  line), then run with `mode=rerun_failed`. Reports listed as "partly stale" still refreshed, on
  yesterday's data for the failed parts.
- **🔴 JD Bronze problem:** nothing was rebuilt. Follow the runbook
  `data-projects/projects/jd-bronze-pipelines/README.md` (gateway on SPI01SR2034W), re-run JD's
  pipelines, then run `Pipeline_DP_Refresh` (`mode=all` or `scheduled`).
- **🔴 orchestrator error / crashed:** open the pipeline run in the Fabric Monitor, fix, and run again.

**Read the log** (DuckDB, as in `tools/dp-migration/proto_counts.py`):
`delta_scan('abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables/dp_refresh_log')`.
Columns: `run_id` (pipeline RunId), `tier`, `mode`, `row_type` (run / item / dataflow / model / bronze),
`name`, `status`, `error`, `skipped_because`, times.

**Change something:**
- **A notebook's logic:** edit it, push → CI → Git sync as usual. The orchestrator picks it up automatically.
- **Add a producer:** add its notebook, then add it to `deploy/dp_refresh_dag.json` with `dependsOn` /
  `produces` / cadence. CI's `dag_check.py` tells you what's missing.
- **Orchestrator logic:** edit `deploy/orchestrator_core.py` (with tests) or `orchestrator_glue.py`, run
  `python deploy/render_orchestrator.py`, push, then Git sync both workspaces.
- **Concurrency, session settings, retries:** `orchestrator` block in the config (no code change).

## 6. Left for the Prod stage

- fabric-cicd promotion of the notebooks, config and pipeline to the DP Prod workspaces. The notebooks
  resolve their workspaces by name (`- Dev` / `- Prod`), so only the pipeline's notebook and workspace IDs
  need `parameter.yml` (or the Variable Library review).
- `orchestrator.reportWorkspace` for Prod. The Prod reports live in 3 workspaces
  (Parts/Service/Financial), so this becomes a per-report mapping.
- Explicit connection mapping for each Prod model (see §3.2).
- The **4:15 AM Mon–Fri schedule** on the Prod pipeline. Then **turn off JD Incremental's own schedule**,
  because the pipeline triggers it.
- `deploy_backend.py` / `deploy_reports.py` still read the old `dp_backend_scope.json` (Prod notebook
  publish and Sandbox reports). Move them to `dp_refresh_dag.json` at that stage.
- Optional: a Teams Workflows webhook for notifying alerts (§3.3); capacity (CU) per run from Capacity
  Metrics into the summary (spec §6); cheaper intraday runs.
