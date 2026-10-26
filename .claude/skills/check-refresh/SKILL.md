---
name: check-refresh
description: Morning check of the DP refresh (Pipeline_DP_Refresh) and diagnosis when it failed or data looks stale. Runs tools/dp-migration/dp_refresh_status.py (the same summary the refresh email is built from), explains any failed items, warnings or JD Bronze problems using TROUBLESHOOTING.md, and gives the exact rerun. Use when Brian asks whether the refresh worked, why data is stale, or runs /check-refresh.
argument-hint: "[prod|dev] [optional problem description]"
allowed-tools: Read, Grep, Glob, Bash
---

Check the DP refresh. Arguments: **$ARGUMENTS** (tier defaults to prod; anything else is Brian's description of a problem).

Repos: data-projects = `C:/Users/bfox/Documents/Git-Projects/data-projects`, fabric-workspace-docs = `C:/Users/bfox/Documents/Git-Projects/fabric-workspace-docs`.

## 1. Status
```bash
python tools/dp-migration/dp_refresh_status.py <prod|dev> --runs 5
```
(run from data-projects). It lists recent pipeline runs, then the latest run's own summary: mode, status, item and model counts, and every failed or skipped item, warning and Bronze problem. Exit 0 = ok, 1 = problems, 2 = in progress / no summary.
- A pipeline run shows **Completed even when items failed**. Trust the summary's status and problem lines, not the pipeline status.
- Prod runs weekdays 06:15 Central (~35–40 min). Dev has no schedule, so stale-data warnings in Dev are usually expected.
- No run today on a weekday after ~07:00 → check the schedule hasn't expired (Fabric schedules end silently on their end date).

If everything is ok, say so in one or two lines (run time, duration, item/model counts) and stop.

## 2. Diagnose each problem
- Look up the error text in `fabric-workspace-docs/docs/TROUBLESHOOTING.md` first. Most failures are already there with the fix.
- What a failed item feeds: `fabric-workspace-docs/docs/TABLE-LINEAGE.md` (or `produces` in `deploy/dp_refresh_dag.json`). Name the reports affected.
- **Bronze problems / stale source:** `python tools/dp-migration/jd_bronze_check.py`. JD's pipelines report Completed even when copies fail. Runbook: `projects/jd-bronze-pipelines/README.md` (fix is on JD's gateway SPI01SR2034W).
- **Every staging dataflow failed with `SPNBasedRefreshNotAllowed`:** the Prod pipeline wasn't re-claimed after a backend deploy. Brian runs `python deploy/claim_prod_pipeline.py` (fabric-workspace-docs).
- **Run crashed before Finish** (no summary; a `Fail_*_Crashed` failure line): the failure message names the step. Read that step's notebook run in the Fabric Monitor.
- Per-item timings or older history are in `dp_refresh_log` (DP_Presentation; `row_type` run / item / dataflow / model). DuckDB reads of it take minutes (many small files), so query it only if the summary isn't enough.

## 3. Recommend the fix and the rerun
Rerunning is Brian's call: say what to run, don't start it. Options, from the pipeline's **Run** dialog:
- `mode=rerun_failed`: retries just what failed in the last run.
- `mode=items`, `items=A,B`: specific items. Skips the Bronze check, so use it when JD had a problem but the Bronze tables DP reads are healthy.
- Wait for the next scheduled run if the cause was transient and nothing urgent depends on it.

## 4. Record anything new
A new error and its fix goes into `fabric-workspace-docs/docs/TROUBLESHOOTING.md` (offer to add it).
