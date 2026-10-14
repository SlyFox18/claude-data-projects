# DP Refresh as a Service Principal: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pipeline_DP_Refresh runs every notebook as SPN-Fabric-Refresh-Automation and refreshes report models with pipeline activities, so deploys no longer change the run identity and `claim_prod_pipeline.py` can be retired.

**Architecture:**
- **Run_DP_Refresh** gets a `phase` parameter: Silver copy `plan` / `run`, Gold copy `run` / `finish`.
- **The pipeline** becomes Plan_Silver → ForEach dataflows (Dataflow activities, run as the invoker) → Run_Silver → Run_Gold → ForEach models (Semantic model refresh activities, run as the service principal) → Finish, which writes the log and sends the email.
- **Rendering:** the pipeline JSON is rendered from Python (`deploy/pipeline_render.py`) like the notebooks already are.
- **Lookups:** Power BI lookups via sempy, which the service principal can't use from a notebook, are replaced with Fabric REST.

**Tech stack:** Python 3 + pytest (local), Fabric notebooks (PySpark, `notebookutils`, `sempy.fabric.FabricRestClient`), Fabric Data Factory pipeline JSON, fabric-cicd (Prod deploy).

**Spec:** `docs/superpowers/specs/2026-10-12-dp-refresh-service-principal-design.md` (data-projects).
**Code repo:** `C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs`, branch `dev`. All paths below are relative to that repo unless they say data-projects.

**Ground rules for every task:**
- Stage only the files the task names; the repo has unrelated uncommitted files.
- Never hand-edit the generated notebooks (`workspaces/*/Orchestration/*.Notebook/notebook-content.py`) or the generated pipeline. Edit the sources in `deploy/`, then run `python deploy/render_orchestrator.py`.
- Run the full suite before each commit: `python -m pytest deploy -q`, `python deploy/dag_check.py`, `python deploy/hygiene_audit.py`.

**Known IDs (Dev):**

| What | ID |
|---|---|
| DP - Staging - Dev workspace | `ab15d64d-c7ba-415d-9bcf-7feb1ef9b201` |
| DP - Presentation - Dev workspace | `73fd5443-240e-410a-990a-98827f32c087` |
| Staging `Run_DP_Refresh` (item) | `f7e553a7-7597-469b-8ba8-5736d0775d8d` |
| Presentation `Run_DP_Refresh` (item) | `5cc39c32-7f3c-49e8-9ca1-04afaea79f73` |
| Presentation `Notify_DP_Refresh` (item) | `8fc246c2-ad2c-4d3b-bab7-6e111c5635ad` |
| Notebook connection (service principal) | `e2b15d1e-677d-4ec4-89b6-8712a319e8eb` |
| Semantic model refresh connection (service principal) | `f647686a-acc4-40ea-a49f-d4da1bffc476` |

---

## File structure

| File | Change | Responsibility |
|---|---|---|
| `deploy/orchestrator_core.py` | modify | + `PHASES`, `latest_since`, `dataflow_result`, `merge_model_results`, `resolve_model_ids` (pure, tested) |
| `deploy/test_orchestrator_core.py` | modify | tests for the new functions |
| `deploy/orchestrator_glue.py` | modify | phases, Fabric REST lookups, JD start in plan + wait in run, model list out of Gold, Finish phase |
| `deploy/render_orchestrator.py` | modify | new parameters, markdown, and render the pipeline JSON |
| `deploy/pipeline_render.py` | create | Pipeline_DP_Refresh definition (activities, connections, ForEach wiring) |
| `deploy/test_pipeline_render.py` | create | connections on every activity, wiring, committed file current |
| `deploy/deploy_backend.py` | modify | Dev→Prod item-ID swaps for all three notebooks the pipeline calls |
| `deploy/test_deploy_backend.py` | modify | the three swaps |
| generated | re-render | both `Run_DP_Refresh` notebooks, `Notify_DP_Refresh`, `Pipeline_DP_Refresh/pipeline-content.json` |
| `OPERATIONS-GUIDE.md`, `CLAUDE.md` (both repos), `deploy/claim_prod_pipeline.py` | modify/delete | Task 10 only, after Prod is proven |

---

### Task 1: Pure functions in orchestrator_core

**Files:**
- Modify: `deploy/orchestrator_core.py` (add `import json` at the top; add the new code after `model_targets`, around line 76)
- Test: `deploy/test_orchestrator_core.py`

- [ ] **Step 1: Write the failing tests.** Append to `deploy/test_orchestrator_core.py`, and extend the import at line 9 with `PHASES, dataflow_result, latest_since, merge_model_results, resolve_model_ids`:

```python
def test_phases_per_tier():
    assert PHASES == {"silver": ("plan", "run"), "gold": ("run", "finish")}


def _inst(start, status="Completed", reason=None):
    return {"startTimeUtc": start, "status": status, "failureReason": reason}


def test_latest_since_picks_newest_at_or_after_cutoff():
    runs = [_inst("2026-10-12T11:00:00.1234567"), _inst("2026-10-12T11:20:05.0000001"),
            _inst("2026-10-12T11:10:00.0000000")]
    assert latest_since(runs, "2026-10-12T11:05:00")["startTimeUtc"].startswith("2026-10-12T11:20:05")
    assert latest_since(runs, "2026-10-12T11:30:00") is None
    assert latest_since([], "2026-10-12T11:00:00") is None


def test_latest_since_counts_same_second_as_after():
    assert latest_since([_inst("2026-10-12T11:05:00.9999999")], "2026-10-12T11:05:00") is not None


def test_dataflow_result_outcomes():
    since = "2026-10-12T11:00:00"
    assert dataflow_result([_inst("2026-10-12T11:01:00")], since) == {"status": "Succeeded", "error": None}
    failed = dataflow_result([_inst("2026-10-12T11:01:00", "Failed", {"errorCode": "X", "message": "boom"})], since)
    assert failed["status"] == "Failed" and "boom" in failed["error"] and failed["error"].startswith("Failed: ")
    missing = dataflow_result([_inst("2026-10-12T10:00:00")], since)
    assert missing["status"] == "Failed" and "no refresh of this dataflow started after" in missing["error"]
    running = dataflow_result([_inst("2026-10-12T11:01:00", "InProgress")], since)
    assert running == {"status": "Failed", "error": "refresh still InProgress when Silver started"}


def test_merge_model_results_parses_and_fills_missing():
    raw = '["Inspections|Completed|", "Stock Check|Failed|Timeout | gateway offline", "Odd|Weird|"]'
    out = merge_model_results(["Inspections", "Stock Check", "Odd", "Missing"], raw)
    assert out["Inspections"] == {"status": "Completed", "error": None}
    assert out["Stock Check"] == {"status": "Failed", "error": "Timeout | gateway offline"}
    assert out["Odd"] == {"status": "Failed", "error": "status Weird"}
    assert out["Missing"] == {"status": "Failed", "error": "no refresh result recorded by the pipeline"}


def test_merge_model_results_empty_and_bad_input():
    assert merge_model_results([], "") == {}
    assert merge_model_results([], "[]") == {}
    with pytest.raises(ValueError, match="not a JSON array"):
        merge_model_results(["A"], "{oops")
    with pytest.raises(ValueError, match="not a JSON array"):
        merge_model_results(["A"], '{"a": 1}')


def test_resolve_model_ids():
    targets = [("Inspections", "RP - Service Reports"), ("Gone", "RP - Service Reports"), ("X", "RP - Nowhere")]
    ws = {"RP - Service Reports": "ws-1"}
    models = {"ws-1": {"Inspections": "ds-1"}}
    resolved, failed = resolve_model_ids(targets, ws, models)
    assert resolved == [{"name": "Inspections", "groupId": "ws-1", "datasetId": "ds-1"}]
    assert failed["Gone"] == {"status": "Failed", "error": "semantic model not found in RP - Service Reports"}
    assert failed["X"]["error"] == "report workspace 'RP - Nowhere' not found (or no access)"
```

- [ ] **Step 2: Run them to confirm they fail.**
Run: `python -m pytest deploy/test_orchestrator_core.py -q`
Expected: ImportError (`cannot import name 'PHASES'`).

- [ ] **Step 3: Implement.** In `deploy/orchestrator_core.py`, add `import json` next to `import html`, then add after `model_targets`:

```python
PHASES = {"silver": ("plan", "run"), "gold": ("run", "finish")}
TERMINAL_JOB = {"Completed", "Failed", "Cancelled", "Deduped"}


def latest_since(instances: list, since_utc: str):
    """Newest Fabric job instance that started at or after since_utc ('YYYY-MM-DDTHH:MM:SS', UTC), else None.
    Fabric's startTimeUtc has 7 fractional digits and no zone, so compare on the first 19 characters."""
    cutoff = (since_utc or "")[:19]
    hits = [i for i in instances if (i.get("startTimeUtc") or "")[:19] >= cutoff]
    return max(hits, key=lambda i: i.get("startTimeUtc") or "", default=None)


def dataflow_result(instances: list, since_utc: str) -> dict:
    """Item result {status, error} for a dataflow the pipeline's ForEach_Dataflows ran in this run."""
    inst = latest_since(instances, since_utc)
    if inst is None:
        return {"status": "Failed", "error": f"no refresh of this dataflow started after {since_utc} UTC "
                                             "(did the pipeline's ForEach_Dataflows run it?)"}
    status = inst.get("status")
    if status == "Completed":
        return {"status": "Succeeded", "error": None}
    if status not in TERMINAL_JOB:
        return {"status": "Failed", "error": f"refresh still {status} when Silver started"}
    reason = inst.get("failureReason")
    return {"status": "Failed",
            "error": (f"{status}: " + (json.dumps(reason) if reason else "no failure reason"))[:1000]}


def merge_model_results(planned: list, raw: str) -> dict:
    """{model: {status, error}} from the pipeline variable model_results: a JSON array of
    'name|status|error' strings (the error itself may contain '|'). A planned model with no entry is Failed."""
    try:
        entries = json.loads(raw) if raw else []
    except ValueError:
        entries = None
    if not isinstance(entries, list):
        raise ValueError(f"model_results is not a JSON array: {str(raw)[:200]!r}")
    out = {}
    for entry in entries:
        name, _, rest = str(entry).partition("|")
        status, _, error = rest.partition("|")
        if status == "Completed":
            out[name] = {"status": "Completed", "error": None}
        else:
            out[name] = {"status": "Failed", "error": error or f"status {status or '?'}"}
    for name in planned:
        out.setdefault(name, {"status": "Failed", "error": "no refresh result recorded by the pipeline"})
    return out


def resolve_model_ids(targets: list, workspace_ids: dict, models_by_workspace: dict):
    """[(model, workspace name)] -> ([{name, groupId, datasetId}], {model: Failed result} for unresolvable ones)."""
    resolved, failed = [], {}
    for model, ws in targets:
        wid = workspace_ids.get(ws)
        if wid is None:
            failed[model] = {"status": "Failed", "error": f"report workspace {ws!r} not found (or no access)"}
            continue
        did = (models_by_workspace.get(wid) or {}).get(model)
        if did is None:
            failed[model] = {"status": "Failed", "error": f"semantic model not found in {ws}"}
        else:
            resolved.append({"name": model, "groupId": wid, "datasetId": did})
    return resolved, failed
```

- [ ] **Step 4: Run the tests.** `python -m pytest deploy/test_orchestrator_core.py -q`. Expected: all pass.

- [ ] **Step 5: Re-render and run the full suite.** The core is embedded in the notebooks, so `test_render_orchestrator` fails until you re-render.
Run: `python deploy/render_orchestrator.py && python -m pytest deploy -q`. Expected: all pass.

- [ ] **Step 6: Commit.**
```bash
git add deploy/orchestrator_core.py deploy/test_orchestrator_core.py "workspaces/DP - Staging - Dev/Orchestration/Run_DP_Refresh.Notebook/notebook-content.py" "workspaces/DP - Presentation - Dev/Orchestration/Run_DP_Refresh.Notebook/notebook-content.py"
git commit -m "orchestrator_core: phases, job-instance and model-result helpers for the SPN refresh"
```

---

### Task 2: Glue: Fabric REST lookups, JD start/wait (no behavior change yet)

**Files:**
- Modify: `deploy/orchestrator_glue.py`

**Why:** `sempy.fabric.resolve_*` call the Power BI groups API, which returns 403 under the service principal. Dataflows will be run by the pipeline, so `run_job` is replaced by `start_job` (Plan) plus `wait_for_instance` (Run_Silver).

- [ ] **Step 1: Imports.** Delete `import sempy.fabric as fabric` (line 14) and `from concurrent.futures import ThreadPoolExecutor` (line 10). Keep `from sempy.fabric import FabricRestClient`.

- [ ] **Step 2: Lookup helpers.** Add after `rest_list` (after line 59):

```python
def workspace_id(name):
    """Workspace ID by display name via Fabric REST (sempy's resolver uses the Power BI API: 403 as a service principal)."""
    hits = [w["id"] for w in rest_list("v1/workspaces") if w["displayName"] == name]
    if len(hits) != 1:
        raise RuntimeError(f"workspace {name!r}: expected 1 match, found {len(hits)}")
    return hits[0]


def item_id(name, item_type, ws):
    """Item ID by display name and type in a workspace, via Fabric REST."""
    hits = [i["id"] for i in rest_list(f"v1/workspaces/{ws}/items?type={item_type}") if i["displayName"] == name]
    if len(hits) != 1:
        raise RuntimeError(f"{item_type} {name!r} in workspace {ws}: expected 1 match, found {len(hits)}")
    return hits[0]
```

- [ ] **Step 3: Replace `run_job`** (the whole function, lines 62–93) with:

```python
def start_job(ws, item, job_type):
    """Submit a Fabric job. Returns None, or an error string when the submit is refused."""
    r = rest.post(f"v1/workspaces/{ws}/items/{item}/jobs/instances?jobType={job_type}")
    if r.status_code not in (200, 201, 202):
        return f"submit {r.status_code} {r.text[:300]}"
    return None


def wait_for_instance(ws, item, since_utc, timeout_s, max_poll_errors=5):
    """Wait for the newest job instance started at/after since_utc to finish. Returns {status, error}."""
    started, poll_errors = time.time(), 0
    while time.time() - started < timeout_s:
        try:
            inst = latest_since(rest_list(f"v1/workspaces/{ws}/items/{item}/jobs/instances"), since_utc)
            poll_errors = 0
        except Exception as ex:
            poll_errors += 1
            if poll_errors > max_poll_errors:
                return {"status": "Failed", "error": f"polling failed {poll_errors} times in a row: "
                                                     f"{type(ex).__name__}: {str(ex)[:300]}"}
            time.sleep(20)
            continue
        if inst is None:
            return {"status": "Failed", "error": f"no run started after {since_utc} UTC"}
        if inst.get("status") in TERMINAL:
            reason = inst.get("failureReason")
            return {"status": inst["status"], "error": json.dumps(reason)[:1000] if reason else None}
        time.sleep(20)
    return {"status": "Failed", "error": f"timed out after {timeout_s}s"}
```

- [ ] **Step 4: Replace `refresh_model`** (the whole function, `def refresh_model` through its final `return`) with:

```python
def resolve_model_targets(targets):
    """[(model, workspace name)] -> ([{name, groupId, datasetId}], {model: Failed result}) via Fabric REST."""
    ws_ids = {w["displayName"]: w["id"] for w in rest_list("v1/workspaces")}
    models = {}
    for ws_name in sorted({ws for _, ws in targets}):
        wid = ws_ids.get(ws_name)
        if wid:
            models[wid] = {m["displayName"]: m["id"] for m in rest_list(f"v1/workspaces/{wid}/semanticModels")}
    return resolve_model_ids(targets, ws_ids, models)
```

- [ ] **Step 5: Setup lookups.** In the run section's setup (currently lines 250–251), replace
`PRES_WS_ID = fabric.resolve_workspace_id(...)` / `PRES_LH_ID = fabric.resolve_item_id(...)` with:

```python
    PRES_WS_ID = workspace_id(f"DP - Presentation - {ENV}")
    PRES_LH_ID = item_id("DP_Presentation", "Lakehouse", PRES_WS_ID)
```

Leave the Silver and Gold bodies for Task 3. They still reference `fabric.` / `run_job` / `ThreadPoolExecutor` / `refresh_model`; Task 3 replaces those blocks, so don't run the notebook between Tasks 2 and 3.

- [ ] **Step 6: Commit with Task 3.** There is no separate commit: Task 3 finishes the edit and the tests run there.

---

### Task 3: Glue: phases (Plan / Silver run / Gold run / Finish)

**Files:**
- Modify: `deploy/orchestrator_glue.py` (header comment lines 1–4; the whole run section from `# --- run ---` to the end of the file)
- Modify: `deploy/render_orchestrator.py` (`PARAMETERS`, `MARKDOWN`)

- [ ] **Step 1: Header comment** (lines 1–4) becomes:

```python
# deploy/orchestrator_glue.py
# Fabric-only glue for Run_DP_Refresh. Rendered into both notebooks after orchestrator_core.
# Parameters (from the PARAMETERS cell): mode, dry_run, items, run_id, upstream_json, phase, model_results,
# inject_failure, simulate_bronze_failure, simulate_crash. Phases: Silver copy plan|run, Gold copy run|finish
# (spec: data-projects/docs/superpowers/specs/2026-10-12-dp-refresh-service-principal-design.md).
```

- [ ] **Step 2: Replace everything from the line `# ---------------------------------------------------------------- run` to the end of the file** with:

```python
# ---------------------------------------------------------------- run --------------------------------
# Safe defaults first: row(), the log and the exit value must work even if setup fails.
# A pipeline passes an empty/unset parameter to the notebook as None, not "": normalise every one.
mode = mode or "scheduled"
dry_run = dry_run or "false"
items = items or ""
run_id = run_id or ""
upstream_json = upstream_json or ""
phase = phase or "run"
model_results = model_results or ""
inject_failure = inject_failure or ""
simulate_bronze_failure = simulate_bronze_failure or "false"
simulate_crash = simulate_crash or "false"
if str(simulate_crash).lower() == "true":
    raise RuntimeError("simulate_crash drill: Run_DP_Refresh failed on purpose before reporting")
DRY = str(dry_run).lower() == "true"
PHASE = str(phase).lower()
REQUESTED = [n.strip() for n in items.split(",") if n.strip()]
started_utc, started_local = now_utc(), datetime.now(CENTRAL)
ENV, TIER, RUN_ID = "unknown", "unknown", run_id or ""
PRES_WS_ID = PRES_LH_ID = LOG_PATH = CONFIG = SETTINGS = None
upstream = {}
summary = {"env": ENV, "mode": mode, "dry_run": DRY, "run_id": RUN_ID, "tier": TIER, "phase": PHASE,
           "started_local": started_local.strftime("%Y-%m-%d %H:%M"), "finished_local": "",
           "bronze_problems": [], "error": None, "items": {}, "models": {}, "tier_seconds": {},
           "affected_reports": [], "plan": None, "warnings": [], "dataflows": [], "models_to_refresh": []}
log = []

try:
    ctx = notebookutils.runtime.context
    TIER = {"DP_Staging": "silver", "DP_Presentation": "gold"}[ctx.get("defaultLakehouseName")]
    ENV = ctx.get("currentWorkspaceName").rsplit(" - ", 1)[1]
    summary.update(env=ENV, tier=TIER)
    if PHASE not in PHASES[TIER]:
        raise OrchestratorAbort(f"phase {PHASE!r} is not valid for the {TIER} orchestrator (use {PHASES[TIER]})")
    if upstream_json:
        try:
            upstream = json.loads(upstream_json)
            if not isinstance(upstream, dict):
                raise ValueError(f"expected a JSON object, got {type(upstream).__name__}")
        except Exception as ex:
            raise OrchestratorAbort(f"could not parse the upstream exit value: {type(ex).__name__}: "
                                    f"{str(ex)[:300]} (value starts {str(upstream_json)[:200]!r})")
    RUN_ID = RUN_ID or upstream.get("run_id") or str(uuid.uuid4())
    summary["run_id"] = RUN_ID
    PRES_WS_ID = workspace_id(f"DP - Presentation - {ENV}")
    PRES_LH_ID = item_id("DP_Presentation", "Lakehouse", PRES_WS_ID)
    LOG_PATH = f"abfss://{PRES_WS_ID}@onelake.dfs.fabric.microsoft.com/{PRES_LH_ID}/Tables/dp_refresh_log"
    CONFIG = json.loads(notebookutils.fs.head("Files/config/dp_refresh_dag.json", 20_000_000))
    SETTINGS = CONFIG["orchestrator"]
    if upstream.get("error") and PHASE != "finish":
        raise OrchestratorAbort(str(upstream["error"]))   # an earlier phase failed: carry it to the email

    if TIER == "silver" and PHASE == "plan":
        # Plan: guard, InProgress row, item selection, start JD Incremental (Run_Silver waits for it),
        # and the dataflow list the pipeline's ForEach_Dataflows runs (as the pipeline's invoker).
        if already_running():
            raise RuntimeError("another DP refresh started in the last 4 hours is still InProgress")
        if not DRY:
            log_rows([row(row_type="run", name="Pipeline_DP_Refresh", status="InProgress", start_utc=started_utc)])
        if mode == "rerun_failed":
            log_df = spark.read.format("delta").load(LOG_PATH)
            prev = (log_df.filter("row_type = 'run' AND tier = 'gold'").orderBy("end_utc", ascending=False)
                    .select("run_id").limit(1).collect())
            REQUESTED = sorted({r.name for r in log_df.filter(
                f"run_id = '{prev[0].run_id}' AND row_type IN ('item','dataflow') AND status IN ('Failed','Skipped')"
            ).select("name").distinct().collect()}) if prev else []
            known = {i["name"] for i in CONFIG["items"]}
            summary["rerun_dropped"] = sorted(set(REQUESTED) - known)
            REQUESTED = sorted(set(REQUESTED) & known)
            if summary["rerun_dropped"]:
                summary["warnings"].append(
                    "rerun skipped items no longer in the config: " + ", ".join(summary["rerun_dropped"]))
        flows = select_items(CONFIG, "staging", mode, started_local, REQUESTED)
        summary["requested"] = REQUESTED
        # 2 min of slack for clock skew between this Spark node and the Fabric job service.
        summary["planned_utc"] = (started_utc - timedelta(minutes=2)).strftime("%Y-%m-%dT%H:%M:%S")
        summary["run_jd"] = (mode in ("scheduled", "all", "intraday")) and not DRY
        if not DRY:
            staging_ws = workspace_id(f"DP - Staging - {ENV}")
            summary["dataflows"] = [{"name": f["name"], "id": item_id(f["name"], "Dataflow", staging_ws)}
                                    for f in flows]
            if summary["run_jd"]:
                err = start_job(JD_WS, JD_INCR, "Pipeline")
                if err:
                    summary["jd_submit_error"] = err

    elif TIER == "silver":  # run
        REQUESTED = upstream.get("requested", REQUESTED)
        summary["requested"] = REQUESTED
        summary["warnings"] = list(upstream.get("warnings") or [])
        if upstream.get("rerun_dropped"):
            summary["rerun_dropped"] = upstream["rerun_dropped"]
        silver = select_items(CONFIG, "silver", mode, started_local, REQUESTED)
        if DRY:
            summary["plan"] = {"dataflows": [i["name"] for i in select_items(CONFIG, "staging", mode,
                                                                               started_local, REQUESTED)],
                               "silver": [i["name"] for i in silver]}
        else:
            since = upstream.get("planned_utc") or ""
            staging_ws = workspace_id(f"DP - Staging - {ENV}")
            for f in upstream.get("dataflows") or []:
                res = dataflow_result(rest_list(f"v1/workspaces/{staging_ws}/items/{f['id']}/jobs/instances"), since)
                summary["items"][f["name"]] = dict(res, tier="staging")
            if str(simulate_bronze_failure).lower() == "true":
                summary["bronze_problems"] = ["Simulated Bronze failure (drill)"]
            elif upstream.get("run_jd"):
                jd_result = ({"status": "Failed", "error": upstream["jd_submit_error"]}
                             if upstream.get("jd_submit_error") else wait_for_instance(JD_WS, JD_INCR, since, 3600))
                full_run, full_acts = latest_run_and_activities(JD_FULL)
                inc_run, inc_acts = latest_run_and_activities(JD_INCR)
                summary["bronze_problems"] = evaluate_bronze(full_run, full_acts, inc_run, inc_acts,
                                                             bronze_since_utc())
                if jd_result["status"] != "Completed":
                    summary["bronze_problems"].append(
                        f"JD Incremental pipeline run ended {jd_result['status']}: {jd_result['error']}")
            if not summary["bronze_problems"]:
                failed_flows = {n for n, i in summary["items"].items() if i["status"] != "Succeeded"}
                dag, skipped = build_dag(silver, CONFIG, dict(SETTINGS), failed_flows)
                t0 = time.time()
                results = run_dag(dag) if dag["activities"] else {}
                summary["tier_seconds"]["silver"] = time.time() - t0
                for n, r in results.items():
                    summary["items"][n] = dict(r, tier="silver")
                for n, culprit in skipped.items():
                    summary["items"][n] = {"status": "Skipped", "tier": "silver", "skipped_because": culprit}
                checks, newest = [], {}
                for c in SETTINGS.get("freshnessChecks") or []:  # file-fed sources: warn when the files stop
                    try:
                        newest[c["table"]] = spark.sql(
                            f"SELECT max(`{c['column']}`) FROM delta.`Tables/{c['table']}`").first()[0]
                        checks.append(c)
                    except Exception as ex:
                        summary["warnings"].append(f"freshness check on {c['table']} could not run "
                                                   f"({type(ex).__name__}: {str(ex)[:200]})")
                summary["warnings"] += freshness_warnings(checks, newest, datetime.now(CENTRAL).date())

    elif PHASE == "run":  # gold run: Gold DAG, SQL endpoint, then the model list for ForEach_Models
        summary["items"] = dict(upstream.get("items", {}))
        summary["bronze_problems"] = upstream.get("bronze_problems", [])
        summary["tier_seconds"] = dict(upstream.get("tier_seconds", {}))
        summary["warnings"] = list(upstream.get("warnings") or [])
        if upstream.get("rerun_dropped"):
            summary["rerun_dropped"] = upstream["rerun_dropped"]
        REQUESTED = upstream.get("requested", REQUESTED)
        summary["requested"] = REQUESTED
        gold = select_items(CONFIG, "gold", mode, started_local, REQUESTED)
        if inject_failure and inject_failure not in {i["name"] for i in gold}:
            summary["warnings"].append(f"inject_failure {inject_failure!r} is not in this run's Gold selection, "
                                       "so no failure was injected")
        if DRY:
            summary["plan"] = dict(upstream.get("plan") or {}, gold=[i["name"] for i in gold],
                                   models=models_for_run(CONFIG, mode))
        elif not summary["bronze_problems"]:
            bad_upstream = {n for n, i in summary["items"].items() if i["status"] != "Succeeded"}
            dag, skipped = build_dag(gold, CONFIG, dict(SETTINGS), bad_upstream, inject_failure=inject_failure)
            t0 = time.time()
            results = run_dag(dag) if dag["activities"] else {}
            summary["tier_seconds"]["gold"] = time.time() - t0
            for n, r in results.items():
                summary["items"][n] = dict(r, tier="gold")
            for n, culprit in skipped.items():
                summary["items"][n] = {"status": "Skipped", "tier": "gold", "skipped_because": culprit}
            if not gold and not summary["items"]:
                summary["warnings"].append("nothing ran, so no models were refreshed")
            else:
                try:
                    refresh_sql_endpoint()
                except Exception as ex:
                    summary["warnings"].append(f"SQL endpoint metadata refresh failed ({type(ex).__name__}: "
                                               f"{str(ex)[:300]}); report models were refreshed anyway")
                targets = model_targets(CONFIG, SETTINGS, ENV, mode)
                if not targets:
                    summary["warnings"].append(f"no report workspace configured for {ENV}; models not refreshed")
                else:
                    resolved, unresolved = resolve_model_targets(targets)
                    summary["models_to_refresh"] = resolved
                    summary["models"].update(unresolved)
        bad = {n for n, i in summary["items"].items() if i["status"] != "Succeeded"}
        summary["affected_reports"] = affected_reports(CONFIG, bad)

    else:  # gold finish: model results from the pipeline, then the log's final rows and the notifications
        for key in ("items", "bronze_problems", "tier_seconds", "error", "warnings", "plan", "affected_reports",
                    "requested", "rerun_dropped", "started_local"):
            if key in upstream:
                summary[key] = upstream[key]
        planned = [m["name"] for m in upstream.get("models_to_refresh") or []]
        summary["models"] = dict(upstream.get("models") or {})
        summary["models"].update(merge_model_results(planned, model_results))
except OrchestratorAbort as ex:
    summary["error"] = str(ex)
except Exception:
    summary["error"] = traceback.format_exc()[-3000:]

# ---------------------------------------------------------------- finish -----------------------------
RUN_ID = RUN_ID or str(uuid.uuid4())
summary["run_id"] = RUN_ID
finished_utc = now_utc()
summary["finished_local"] = datetime.now(CENTRAL).strftime("%Y-%m-%d %H:%M")
FINAL = TIER == "gold" and PHASE == "finish"
if FINAL or (TIER == "silver" and (summary["error"] or summary["bronze_problems"] or DRY)):
    try:
        summary.update(compose_summary(summary))
    except Exception:
        summary["compose_error"] = traceback.format_exc()[-1000:]
        subject = f"🔴 [{ENV}] DP Refresh FAILED – could not build the summary"
        summary.update(status="error", subject=subject, teams_text=subject, alert_email=True, teams=True,
                       html=f"<p><b>{html.escape(subject)}</b><br>Run {html.escape(str(RUN_ID))}</p><pre>"
                            f"{html.escape(str(summary.get('error') or summary['compose_error'])[:3000])}</pre>")
for key, default in (("subject", ""), ("html", ""), ("teams_text", ""), ("alert_email", False), ("teams", False)):
    summary.setdefault(key, default)
# Who writes what: Plan only the InProgress row (above); Silver run its dataflow/item/bronze rows and a
# tier_done run row; Gold run its item rows; Finish the model rows and the final run row.
if LOG_PATH and not DRY and not (TIER == "silver" and PHASE == "plan"):
    try:
        for n, i in summary["items"].items():
            if (TIER == "silver" and i.get("tier") in ("silver", "staging")) or \
                    (TIER == "gold" and PHASE == "run" and i.get("tier") == "gold"):
                log.append(row(row_type="dataflow" if i["tier"] == "staging" else "item", name=n, status=i["status"],
                               error=i.get("error"), skipped_because=i.get("skipped_because"), end_utc=finished_utc))
        if FINAL:
            for m, s in summary["models"].items():
                log.append(row(row_type="model", name=m, status=s["status"], error=s.get("error"), end_utc=finished_utc))
        if TIER == "silver" and summary["bronze_problems"]:
            log.append(row(row_type="bronze", name="JD_Bronze", status="Failed",
                           error="; ".join(summary["bronze_problems"])[:1000]))
        if TIER == "silver" or FINAL:
            final = summary.get("status") or ("error" if summary["error"] else "tier_done")
            log.append(row(row_type="run", name="Pipeline_DP_Refresh", status=final, start_utc=started_utc,
                           end_utc=finished_utc, duration_s=(finished_utc - started_utc).total_seconds(),
                           error=(summary["error"] or "")[:1000] or None))
        if log:
            log_rows(log)
    except Exception:
        summary["log_error"] = traceback.format_exc()[-1000:]

# ---------------------------------------------------------------- notify -----------------------------
# Finish sends the run's notifications (summary always; alert + Teams per compose_summary's flags).
# A failed send fails this notebook on purpose (exit cell), so the pipeline's crash path still tells someone.
summary["notify_errors"] = []
if TIER not in ("silver", "gold"):
    summary["notify_errors"] = [f"orchestrator could not tell its tier ({TIER}); nobody was notified"]
elif FINAL:
    try:
        if SETTINGS is None:
            raise RuntimeError("config not loaded: " + (summary.get("error") or "")[:500])
        notify = SETTINGS.get("notify")
        if not notify:
            raise RuntimeError("orchestrator.notify missing from Files/config/dp_refresh_dag.json")
        summary["notify_errors"] = send_notifications(notify_messages(summary, notify, ENV), notify)
    except Exception as ex:
        summary["notify_errors"] = [f"{type(ex).__name__}: {str(ex)[:500]}"]
```

Before replacing, **diff the old tail against this text.** Any line in the current file that this block doesn't account for, other than the deliberate changes (phase split, `fabric.` lookups, `run_job` / `ThreadPoolExecutor` / `refresh_model`, notify only in Finish), must be kept. Report it in the task summary.

- [ ] **Step 3: Remove unused constants.** If `MODEL_TERMINAL` (line 25) is no longer referenced anywhere, delete it. Check with `grep -n MODEL_TERMINAL deploy/orchestrator_glue.py`.

- [ ] **Step 4: Parameters and markdown** in `deploy/render_orchestrator.py`:

```python
PARAMETERS = '''mode = "scheduled"
dry_run = "false"
items = ""
run_id = ""
upstream_json = ""
phase = "run"
model_results = ""
inject_failure = ""
simulate_bronze_failure = "false"
simulate_crash = "false"
'''
MARKDOWN = '''# # Run_DP_Refresh
# DP refresh orchestrator (one identical copy per lakehouse). GENERATED by
# fabric-workspace-docs/deploy/render_orchestrator.py from orchestrator_core.py + orchestrator_glue.py:
# edit those files and re-render, never this notebook.
# Staging copy: phase=plan (selection, JD Incremental start, dataflow list for the pipeline) and phase=run
# (dataflow results, Bronze check, Silver). Presentation copy: phase=run (Gold, SQL endpoint, model list for
# the pipeline's model-refresh activities) and phase=finish (log, summary email). Runs as
# SPN-Fabric-Refresh-Automation via the pipeline's notebook connection. Specs:
# data-projects/docs/superpowers/specs/2026-09-28-dp-refresh-pipeline-redesign-design.md and
# data-projects/docs/superpowers/specs/2026-10-12-dp-refresh-service-principal-design.md
'''
```

Also change `EXIT_CELL`'s comment line to say "(the pipeline's Notify_*_Crashed)" instead of "(Notify_DP_Refresh)". The code is unchanged.

- [ ] **Step 5: Re-render and test.**
Run: `python deploy/render_orchestrator.py && python -m pytest deploy -q && python deploy/dag_check.py && python deploy/hygiene_audit.py`
Expected: all pass. `test_every_code_cell_parses` confirms the glue is valid Python.

- [ ] **Step 6: Static check for leftovers.**
Run: `grep -n "fabric\.\|run_job\|ThreadPoolExecutor\|refresh_model(" deploy/orchestrator_glue.py`
Expected: no matches. `FabricRestClient` on the import line is fine.

- [ ] **Step 7: Commit Tasks 2 and 3.**
```bash
git add deploy/orchestrator_glue.py deploy/render_orchestrator.py "workspaces/DP - Staging - Dev/Orchestration/Run_DP_Refresh.Notebook/notebook-content.py" "workspaces/DP - Presentation - Dev/Orchestration/Run_DP_Refresh.Notebook/notebook-content.py"
git commit -m "Run_DP_Refresh: plan/run/finish phases, Fabric REST lookups, models refreshed by the pipeline"
```

---

### Task 4: Render Pipeline_DP_Refresh from code

**Files:**
- Create: `deploy/pipeline_render.py`
- Create: `deploy/test_pipeline_render.py`
- Modify: `deploy/render_orchestrator.py` (`main()`)
- Generated: `workspaces/DP - Presentation - Dev/Pipelines/Pipeline_DP_Refresh.DataPipeline/pipeline-content.json`

- [ ] **Step 1: Write the failing tests** in `deploy/test_pipeline_render.py`:

```python
# deploy/test_pipeline_render.py
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from pipeline_render import (GOLD_ORCHESTRATOR, MODEL_CONNECTION, NOTEBOOK_CONNECTION, NOTIFIER,  # noqa: E402
                             PIPELINE_PATH, SILVER_ORCHESTRATOR, pipeline)

REPO = Path(__file__).parent.parent


def _all(acts):
    for a in acts:
        yield a
        yield from _all(a.get("typeProperties", {}).get("activities", []))


def _by_name(p):
    return {a["name"]: a for a in _all(p["properties"]["activities"])}


def test_every_notebook_and_model_activity_has_its_connection():
    acts = list(_all(pipeline(4)["properties"]["activities"]))
    notebooks = [a for a in acts if a["type"] == "TridentNotebook"]
    models = [a for a in acts if a["type"] == "PBISemanticModelRefresh"]
    assert len(notebooks) == 8 and len(models) == 1
    assert all(a["externalReferences"] == {"connection": NOTEBOOK_CONNECTION} for a in notebooks)
    assert all(a["externalReferences"] == {"connection": MODEL_CONNECTION} for a in models)
    assert all("externalReferences" not in a for a in acts if a["type"] == "RefreshDataflow")


def test_main_chain_and_phases():
    a = _by_name(pipeline(4))
    phase = lambda n: a[n]["typeProperties"]["parameters"]["phase"]["value"]
    assert (phase("Plan_Silver"), phase("Run_Silver"), phase("Run_Gold"), phase("Finish")) == \
        ("plan", "run", "run", "finish")
    assert a["Plan_Silver"]["typeProperties"]["notebookId"] == SILVER_ORCHESTRATOR
    assert a["Run_Gold"]["typeProperties"]["notebookId"] == GOLD_ORCHESTRATOR
    assert a["Finish"]["typeProperties"]["notebookId"] == GOLD_ORCHESTRATOR
    assert a["ForEach_Dataflows"]["dependsOn"] == [{"activity": "Plan_Silver", "dependencyConditions": ["Succeeded"]}]
    assert a["Run_Silver"]["dependsOn"] == [{"activity": "ForEach_Dataflows", "dependencyConditions": ["Completed"]}]
    assert a["Run_Gold"]["dependsOn"] == [{"activity": "Run_Silver", "dependencyConditions": ["Succeeded"]}]
    assert a["ForEach_Models"]["dependsOn"] == [{"activity": "Run_Gold", "dependencyConditions": ["Succeeded"]}]
    assert a["Finish"]["dependsOn"] == [{"activity": "ForEach_Models", "dependencyConditions": ["Completed"]}]


def test_foreach_wiring():
    a = _by_name(pipeline(4))
    assert a["ForEach_Dataflows"]["typeProperties"]["items"]["value"] == \
        "@json(activity('Plan_Silver').output.result.exitValue).dataflows"
    assert a["Run_Dataflow"]["typeProperties"]["dataflowId"] == {"value": "@item().id", "type": "Expression"}
    assert a["ForEach_Models"]["typeProperties"]["batchCount"] == 4
    assert a["Refresh_Model"]["typeProperties"]["datasetId"] == {"value": "@item().datasetId", "type": "Expression"}
    assert a["Record_Model_OK"]["dependsOn"][0]["dependencyConditions"] == ["Succeeded"]
    assert a["Record_Model_Failed"]["dependsOn"][0]["dependencyConditions"] == ["Failed"]
    assert a["Finish"]["typeProperties"]["parameters"]["model_results"]["value"]["value"] == \
        "@string(variables('model_results'))"


def test_crash_paths():
    a = _by_name(pipeline(4))
    for act, tier in (("Plan_Silver", "Plan"), ("Run_Silver", "Silver"), ("Run_Gold", "Gold"), ("Finish", "Finish")):
        n = a[f"Notify_{tier}_Crashed"]
        assert n["typeProperties"]["notebookId"] == NOTIFIER
        assert n["dependsOn"] == [{"activity": act, "dependencyConditions": ["Failed"]}]
        assert a[f"Fail_{tier}_Crashed"]["dependsOn"][0]["activity"] == f"Notify_{tier}_Crashed"


def test_committed_pipeline_is_current():
    committed = json.loads((REPO / PIPELINE_PATH).read_text(encoding="utf-8"))
    cfg = json.loads((REPO / "deploy" / "dp_refresh_dag.json").read_text(encoding="utf-8"))
    assert committed == pipeline(cfg["orchestrator"]["modelRefreshParallelism"]), \
        "Pipeline_DP_Refresh is stale: run python deploy/render_orchestrator.py"
```

- [ ] **Step 2: Run them to confirm they fail.** `python -m pytest deploy/test_pipeline_render.py -q`. Expected: `ModuleNotFoundError: pipeline_render`.

- [ ] **Step 3: Create `deploy/pipeline_render.py`:**

```python
# deploy/pipeline_render.py
"""Pipeline_DP_Refresh definition (Dev IDs). render_orchestrator.py writes it to PIPELINE_PATH.

Every Notebook activity runs as SPN-Fabric-Refresh-Automation through NOTEBOOK_CONNECTION and every model
refresh through MODEL_CONNECTION, so the run identity no longer depends on who last saved the pipeline.
Dataflow activities can't take a connection (and Dataflow Gen2 refuses service principals): they run as the
pipeline's invoker - the schedule owner. Prod: deploy_backend.py swaps the three notebook item IDs, and
parameter.yml the workspace IDs; the connections are tenant-level and the same in both tiers.
Spec: data-projects/docs/superpowers/specs/2026-10-12-dp-refresh-service-principal-design.md
"""
PIPELINE_PATH = "workspaces/DP - Presentation - Dev/Pipelines/Pipeline_DP_Refresh.DataPipeline/pipeline-content.json"
NOTEBOOK_CONNECTION = "e2b15d1e-677d-4ec4-89b6-8712a319e8eb"
MODEL_CONNECTION = "f647686a-acc4-40ea-a49f-d4da1bffc476"
STAGING_WS = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
PRESENTATION_WS = "73fd5443-240e-410a-990a-98827f32c087"
SILVER_ORCHESTRATOR = "f7e553a7-7597-469b-8ba8-5736d0775d8d"  # Staging Run_DP_Refresh (Dev item ID)
GOLD_ORCHESTRATOR = "5cc39c32-7f3c-49e8-9ca1-04afaea79f73"    # Presentation Run_DP_Refresh (Dev item ID)
NOTIFIER = "8fc246c2-ad2c-4d3b-bab7-6e111c5635ad"             # Notify_DP_Refresh (Dev item ID)


def _expr(value):
    return {"value": value, "type": "Expression"}


def _param(expression):
    return {"value": _expr(expression), "type": "string"}


def _lit(value):
    return {"value": value, "type": "string"}


def _pp(name):
    return _param(f"@pipeline().parameters.{name}")


def _exit(activity):
    return f"@activity('{activity}').output.result.exitValue"


def _dep(activity, condition):
    return {"activity": activity, "dependencyConditions": [condition]}


def _policy(timeout, retry=0, interval=30):
    return {"timeout": timeout, "retry": retry, "retryIntervalInSeconds": interval,
            "secureInput": False, "secureOutput": False}


def _notebook(name, notebook_id, workspace_id, params, depends, timeout="0.06:00:00", retry=0, interval=30):
    return {"name": name, "type": "TridentNotebook", "dependsOn": depends, "policy": _policy(timeout, retry, interval),
            "typeProperties": {"notebookId": notebook_id, "workspaceId": workspace_id, "parameters": params},
            "externalReferences": {"connection": NOTEBOOK_CONNECTION}}


def _crash_path(activity, tier):
    return [
        _notebook(f"Notify_{tier}_Crashed", NOTIFIER, PRESENTATION_WS,
                  {"tier": _lit(tier), "error_message": _param(f"@activity('{activity}').error.message"),
                   "run_id": _param("@pipeline().RunId")},
                  [_dep(activity, "Failed")], timeout="0.00:15:00", retry=1, interval=60),
        {"name": f"Fail_{tier}_Crashed", "type": "Fail", "dependsOn": [_dep(f"Notify_{tier}_Crashed", "Completed")],
         "typeProperties": {"message": _expr(f"@activity('{activity}').error.message"), "errorCode": f"{tier}Crashed"}},
    ]


def pipeline(model_parallelism: int) -> dict:
    common = {"mode": _pp("mode"), "dry_run": _pp("dry_run"), "items": _pp("items"),
              "run_id": _param("@pipeline().RunId")}
    plan = _notebook("Plan_Silver", SILVER_ORCHESTRATOR, STAGING_WS,
                     dict(common, phase=_lit("plan"), simulate_crash=_pp("simulate_crash")), [])
    dataflows = {
        "name": "ForEach_Dataflows", "type": "ForEach", "dependsOn": [_dep("Plan_Silver", "Succeeded")],
        "typeProperties": {
            "items": _expr(f"@json({_exit('Plan_Silver')[1:]}).dataflows"), "isSequential": False, "batchCount": 6,
            "activities": [{
                "name": "Run_Dataflow", "type": "RefreshDataflow", "dependsOn": [], "policy": _policy("0.01:00:00"),
                "typeProperties": {"dataflowId": _expr("@item().id"), "workspaceId": STAGING_WS,
                                   "notifyOption": "NoNotification", "dataflowType": "DataflowFabric"}}]}}
    silver = _notebook("Run_Silver", SILVER_ORCHESTRATOR, STAGING_WS,
                       dict(common, phase=_lit("run"), simulate_bronze_failure=_pp("simulate_bronze_failure"),
                            upstream_json=_param(_exit("Plan_Silver"))),
                       [_dep("ForEach_Dataflows", "Completed")])
    gold = _notebook("Run_Gold", GOLD_ORCHESTRATOR, PRESENTATION_WS,
                     dict(common, phase=_lit("run"), inject_failure=_pp("inject_failure"),
                          upstream_json=_param(_exit("Run_Silver"))),
                     [_dep("Run_Silver", "Succeeded")])
    models = {
        "name": "ForEach_Models", "type": "ForEach", "dependsOn": [_dep("Run_Gold", "Succeeded")],
        "typeProperties": {
            "items": _expr(f"@json({_exit('Run_Gold')[1:]}).models_to_refresh"), "isSequential": False,
            "batchCount": model_parallelism,
            "activities": [
                {"name": "Refresh_Model", "type": "PBISemanticModelRefresh", "dependsOn": [],
                 "policy": _policy("0.01:00:00", retry=1, interval=60),
                 "typeProperties": {"method": "POST", "operationType": "SemanticModelRefresh",
                                    "groupId": _expr("@item().groupId"), "datasetId": _expr("@item().datasetId"),
                                    "waitOnCompletion": True, "commitMode": "Transactional"},
                 "externalReferences": {"connection": MODEL_CONNECTION}},
                {"name": "Record_Model_OK", "type": "AppendVariable", "dependsOn": [_dep("Refresh_Model", "Succeeded")],
                 "typeProperties": {"variableName": "model_results",
                                    "value": _expr("@concat(item().name, '|Completed|')")}},
                {"name": "Record_Model_Failed", "type": "AppendVariable",
                 "dependsOn": [_dep("Refresh_Model", "Failed")],
                 "typeProperties": {"variableName": "model_results",
                                    "value": _expr("@concat(item().name, '|Failed|', "
                                                   "activity('Refresh_Model').error.message)")}},
            ]}}
    finish = _notebook("Finish", GOLD_ORCHESTRATOR, PRESENTATION_WS,
                       dict(common, phase=_lit("finish"), upstream_json=_param(_exit("Run_Gold")),
                            model_results=_param("@string(variables('model_results'))")),
                       [_dep("ForEach_Models", "Completed")], timeout="0.01:00:00")
    activities = [plan, dataflows, silver, gold, models, finish]
    for act, tier in (("Plan_Silver", "Plan"), ("Run_Silver", "Silver"), ("Run_Gold", "Gold"), ("Finish", "Finish")):
        activities += _crash_path(act, tier)
    return {"properties": {
        "activities": activities,
        "parameters": {"mode": {"type": "string", "defaultValue": "scheduled"},
                       "dry_run": {"type": "string", "defaultValue": "false"},
                       "items": {"type": "string"}, "inject_failure": {"type": "string"},
                       "simulate_bronze_failure": {"type": "string", "defaultValue": "false"},
                       "simulate_crash": {"type": "string", "defaultValue": "false"}},
        "variables": {"model_results": {"type": "Array", "defaultValue": []}}}}
```

`_exit(...)[1:]` drops the leading `@`, because the expression is embedded inside `@json(...)`.

- [ ] **Step 4: Write the pipeline in `render_orchestrator.main()`.** Add after the notebook loop:

```python
    cfg = json.loads((DEPLOY / "dp_refresh_dag.json").read_text(encoding="utf-8"))
    wanted = pipeline(cfg["orchestrator"]["modelRefreshParallelism"])
    path = REPO / PIPELINE_PATH
    # Compare parsed JSON: after a workspace commit Fabric may re-serialise the file (key order, spacing);
    # only rewrite when the definition really changed, so a Fabric round-trip doesn't churn the file.
    if not path.exists() or json.loads(path.read_text(encoding="utf-8")) != wanted:
        path.write_text(json.dumps(wanted, indent=2), encoding="utf-8", newline="\n")
        print("rendered", path)
```

Then add `from pipeline_render import PIPELINE_PATH, pipeline` after the other imports. The deploy folder is the script's own folder, so the import resolves.

- [ ] **Step 5: Render and test.**
Run: `python deploy/render_orchestrator.py && python -m pytest deploy -q`. Expected: all pass, including `test_committed_pipeline_is_current`.

- [ ] **Step 6: Commit.**
```bash
git add deploy/pipeline_render.py deploy/test_pipeline_render.py deploy/render_orchestrator.py "workspaces/DP - Presentation - Dev/Pipelines/Pipeline_DP_Refresh.DataPipeline/pipeline-content.json"
git commit -m "Pipeline_DP_Refresh rendered from code: SPN connections, dataflow and model-refresh ForEach, Finish"
```

---

### Task 5: Prod deploy swaps all three notebook IDs

**Files:**
- Modify: `deploy/deploy_backend.py:110-118`
- Modify: `deploy/test_deploy_backend.py:47-90`

- [ ] **Step 1: Update the test.** In `test_main_prod_deploys_staging_then_presentation_and_writes_dag_only`, replace `fake_find_item_id` and the assertions from `# orchestrator IDs looked up …` through the staging-stage check with:

```python
    def fake_find_item_id(workspace_id, display_name, item_type):
        find_item_id_calls.append({"workspace_id": workspace_id, "display_name": display_name, "item_type": item_type})
        env = "dev" if workspace_id in deploy_backend.WORKSPACE_IDS["dev"].values() else "prod"
        tier = next(t for t, w in deploy_backend.WORKSPACE_IDS[env].items() if w == workspace_id)
        return f"{env}-{tier}-{display_name}"
```

```python
    # every notebook the pipeline calls is looked up in Dev and Prod
    ws = deploy_backend.WORKSPACE_IDS
    assert find_item_id_calls == [
        {"workspace_id": ws[env][tier], "display_name": name, "item_type": "Notebook"}
        for tier, name in (("staging", "Run_DP_Refresh"), ("presentation", "Run_DP_Refresh"),
                           ("presentation", "Notify_DP_Refresh"))
        for env in ("dev", "prod")]

    # the presentation stage's parameter.yml got one DataPipeline swap per notebook
    presentation_stage = deploy_calls[1]["repository_directory"]
    parameter_text = (presentation_stage / "parameter.yml").read_text(encoding="utf-8")
    for tier, name in (("staging", "Run_DP_Refresh"), ("presentation", "Run_DP_Refresh"),
                       ("presentation", "Notify_DP_Refresh")):
        assert f'  - find_value: "dev-{tier}-{name}"' in parameter_text
        assert f'      prod: "prod-{tier}-{name}"' in parameter_text
    assert '    item_type: "DataPipeline"' in parameter_text

    # the staging stage's parameter.yml must NOT have gotten those rules
    staging_stage = deploy_calls[0]["repository_directory"]
    assert "dev-staging-Run_DP_Refresh" not in (staging_stage / "parameter.yml").read_text(encoding="utf-8")
```

- [ ] **Step 2: Run it to confirm it fails.** `python -m pytest deploy/test_deploy_backend.py -q`. Expected: FAIL; only the Staging orchestrator is looked up today.

- [ ] **Step 3: Implement.** Replace `deploy/deploy_backend.py` lines 110–118 (from the comment `# Pipeline_DP_Refresh calls the Staging orchestrator…` through the `print(...)`) with:

```python
        # Pipeline_DP_Refresh's notebook activities carry a connection, and with one Fabric stores the real
        # item ID (not the logicalId), so every notebook it calls needs a Dev -> Prod ID swap.
        swaps = (("staging", "Run_DP_Refresh"), ("presentation", "Run_DP_Refresh"),
                 ("presentation", "Notify_DP_Refresh"))
        rules = []
        for tier, name in swaps:
            dev_id = find_item_id(WORKSPACE_IDS["dev"][tier], name, "Notebook")
            prod_id = find_item_id(ids[tier], name, "Notebook")
            rules.append((dev_id, prod_id, "DataPipeline"))
        presentation_stage = stage_items(REPO_ROOT, items["presentation"])
        append_rules(presentation_stage / "parameter.yml", rules)
        deploy(workspace_id=ids["presentation"], repository_directory=presentation_stage,
               item_type_in_scope=["Notebook", "DataPipeline"], environment=environment)
        print(f"Deployed {len(items['presentation'])} items to the {environment} presentation workspace "
              f"({len(rules)} notebook ID swaps for Pipeline_DP_Refresh).")
```

The lookup loop order (dev then prod, per notebook) matches the test's expected call list.

- [ ] **Step 4: Run all tests.** `python -m pytest deploy -q`. Expected: all pass.

- [ ] **Step 5: Commit.**
```bash
git add deploy/deploy_backend.py deploy/test_deploy_backend.py
git commit -m "deploy_backend: swap all three notebook IDs Pipeline_DP_Refresh calls"
```

---

### Task 6: Push, sync Dev, first Dev runs (controller + Brian)

These steps need Fabric. The controller runs the git commands; Brian runs the pipeline in the UI unless the controller starts it via `fab api`.

- [ ] **Step 1: Push and sync.**
```bash
git push origin dev
python ../data-projects/tools/dp-migration/wait_ci.py
python ../data-projects/tools/dp-migration/git_sync.py ab15d64d-c7ba-415d-9bcf-7feb1ef9b201
python ../data-projects/tools/dp-migration/git_sync.py 73fd5443-240e-410a-990a-98827f32c087
```
Expected: CI success; both syncs report incoming Modified items: Run_DP_Refresh in each workspace, and Pipeline_DP_Refresh in Presentation.

- [ ] **Step 2: Brian checks the pipeline in the UI.**
  - Open Pipeline_DP_Refresh (DP - Presentation - Dev). Every Notebook activity's **Connection** shows the service-principal notebook connection, and Refresh_Model shows the model connection.
  - **If the Dataflow activity's dataflow box rejects the `@item().id` expression** (red outline or validation error), stop: the expression form isn't supported. The fallback, a plan amendment, is a **Switch** activity inside the ForEach on `@item().name`, with one static Dataflow activity per dataflow (6 cases plus a default case that fails). A notebook can't do this instead, because dataflows refuse the service principal. Amend `pipeline_render.py` and the tests, then re-render.
  - Click **Validate**. Expected: no errors.
  - If Fabric shows the pipeline as changed after opening, have Brian commit it, then pull and run `python deploy/render_orchestrator.py`. Its parsed-JSON comparison means it only rewrites the file when the definition really differs; `git diff` should show nothing.

- [ ] **Step 3: Dry run.** Run Pipeline_DP_Refresh with `dry_run = true`. Expected:
  - Plan_Silver, Run_Silver, Run_Gold and Finish succeed; both ForEach loops run 0 iterations;
  - a "🧪 [Dev] DP Refresh dry run" email arrives;
  - `dp_refresh_log` gets no rows.

- [ ] **Step 4: Small items run.** `mode = items`, `items = df_Dim_BranchUserAccess,Build_Silver_BranchName,Build_Gold_BranchLocation`. Expected:
  - the ForEach runs 1 dataflow;
  - Run_Silver records it as Succeeded;
  - Gold builds dim_BranchLocation;
  - ForEach_Models refreshes every model that reads it;
  - the email lists items and models as OK.

  Then check the log with a DuckDB read: one `run` row InProgress (tier silver), one silver `tier_done` run row, dataflow + item rows, model rows, and a final gold `run` row with status `ok`.

- [ ] **Step 5: Full run.** `mode = all`, in a quiet window (before 07:00 or after 17:00). This answers the spec's open question, whether the service principal can start JD Incremental:
  - **Run_Silver shows no "JD Incremental pipeline run ended Failed: submit 403…" Bronze problem:** answered yes.
  - **The submit was refused:** the email shows a Bronze problem with the submit error. Go to Task 7.

  Compare the item and model outcomes with the last pre-change Dev run in `dp_refresh_log`.

- [ ] **Step 6: Failure drills.** Run each, one at a time:
  - `simulate_crash = true` → the Plan crash email, and the pipeline fails at `Fail_Plan_Crashed`;
  - `simulate_bronze_failure = true` with `mode = items` and a small item list → "JD Bronze problem" email, and no model refresh;
  - `inject_failure = Build_Gold_BranchLocation` with `mode = items` → that item failed, dependents skipped, models still refresh;
  - a model failure: temporarily remove the service principal's role on RP - Dev (Brian), run `mode = items` with one Gold item → that model shows Failed with the Power BI error in the email. Restore the role afterwards.

- [ ] **Step 7: Record the results** in this plan's progress note (top of file) and commit to data-projects.

---

### Task 7 (only if Task 6 Step 5 showed the service principal can't start JD Incremental)

- [ ] **Step 1: Decision with Brian.** Either run JD Incremental as the schedule owner via an **Invoke Pipeline** activity (connection: organizational account, Brian; it sits before Run_Silver), or ask JD/Brian to grant the service principal use of JD's gateway connections. **Don't build without his choice.**
- [ ] **Step 2, if Invoke Pipeline:** have Brian add the activity in the Dev UI (`Run_JD_Incremental` → JD_FabricOneLake → `PL_EquipRDB_To_Fabric_Incremental`, wait on completion), dependent on Plan_Silver Succeeded, with Run_Silver depending on it (Completed) as well as on ForEach_Dataflows. Commit from the workspace, then copy the committed activity JSON into `pipeline_render.py` and extend the tests.
- [ ] **Step 3: Change Plan** so it no longer submits JD: set `summary["run_jd"]` as now, but skip `start_job`. Run_Silver's `wait_for_instance(JD_WS, JD_INCR, since, 3600)` already reads the run the activity started, so no change there.
- [ ] **Step 4: Re-render, test, commit, sync, and repeat Task 6 Step 5.**

---

### Task 8: Pipeline-failure alert (Brian, UI)

The crash notifier runs as the service principal, so it can't email if that principal's secret expires or it loses access. This alert is the backstop.

- [ ] **Step 1: Set the alert.** Fabric → Monitor → find Pipeline_DP_Refresh (start with Dev) → **…** → **Set alert** (Activator). Condition: the job status is **Failed**. Action: **email bfox@spitractor.com**. Save it into a new Activator item, `Alert_DP_Refresh_Failed`, in DP - Presentation - Dev.
- [ ] **Step 2: Test.** Run with `simulate_crash = true` and confirm both emails arrive: the crash email and the Activator alert.
- [ ] **Step 3: Note** the alert in OPERATIONS-GUIDE (Task 10). Repeat for Prod after Task 9.

---

### Task 9: Prod release (Brian + controller)

- [ ] **Step 1: Brian grants access.**
  - Add SPN-Fabric-Refresh-Automation as **Contributor** on DP - Staging - Prod, DP - Presentation - Prod, RP - Parts Reports, RP - Service Reports and RP - Financial Reports.
  - Add **SPN-Fabric-CICD-Deploy** as a **user** on both connections (Manage connections and gateways → each connection → Manage users).
- [ ] **Step 2: Release.**
  - `python deploy/merge_preview.py`;
  - PR `dev → main`; Brian merges with "Create a merge commit" and runs **Deploy DP backend**;
  - **don't run `claim_prod_pipeline.py`**;
  - fast-forward `dev`: `git fetch origin && git merge --ff-only origin/main && git push origin dev`.
- [ ] **Step 3: If the deploy fails** on the pipeline with a connection or permission error, the deploy service principal still lacks access to a connection. Brian fixes it in Manage users, then re-runs the workflow.
- [ ] **Step 4: Check the Prod pipeline in the UI.** The notebook activities show the service-principal connection, and the notebook IDs are the Prod ones (open Run_Gold → its notebook is the Prod Run_DP_Refresh).
- [ ] **Step 5: First Prod run, manually:** `mode = items`, `items = Build_Silver_BranchName,Build_Gold_BranchLocation`. Confirm the models refresh in the three production report workspaces and the email arrives.
- [ ] **Step 6: Watch three scheduled mornings** (06:15). Compare durations and outcomes with the previous week in `dp_refresh_log`, and record them in the progress note.
- [ ] **Step 7: Brian sets the Prod failure alert** (Task 8 Step 1, for Prod).

---

### Task 10: Retire the re-claim step, update docs, clean up

- [ ] **Step 1: Delete `deploy/claim_prod_pipeline.py`** (`git rm`). **Brian approves this delete** first. Grep for references: `grep -rn claim_prod_pipeline --include=*.md --include=*.py .` in both repos, and update each one.
- [ ] **Step 2: `OPERATIONS-GUIDE.md`.**
  - Replace "Why the pipeline has to be re-claimed" with an **"Identity"** section: notebooks and models run as SPN-Fabric-Refresh-Automation via the two connections; dataflows run as the schedule owner; the secret table and its rotation steps; the failure alert.
  - Remove step 5 ("Re-claim the Prod pipeline") from "Releasing a change to Prod".
  - In "Daily check (DP)", add: a pipeline-failure Activator alert means the service principal or connection is broken. Check the secret expiry and workspace roles.
- [ ] **Step 3: Update both CLAUDE.md files and the troubleshooting doc.**
  - Remove the "After every Prod deploy, run claim_prod_pipeline.py" lines.
  - Add: "Pipeline_DP_Refresh is generated (`deploy/pipeline_render.py`); notebooks run as SPN-Fabric-Refresh-Automation".
  - In `docs/TROUBLESHOOTING.md`, replace the 403 "re-claim" row with: "notebook activities fail to start → the connection's secret expired or the service principal lost a workspace role".
- [ ] **Step 4: Update memory.** `project_sm_refresh_spn_migration.md` becomes "done", with the design summary; update the MEMORY.md line.
- [ ] **Step 5: Probe cleanup, with Brian's OK.** Delete `Utilities_SPN_Probe`, `Pipeline_SPN_Probe` and the tables `SPN_Probe_Results` and `SPN_Probe_Write` in DP - Presentation - Dev. Remove the folders from Git, then sync.
- [ ] **Step 6: Commit and push both repos.**

---

## Progress

**2026-10-12: Tasks 1–5 done** (subagent-driven; each task passed spec + quality review, with fixes). fabric-workspace-docs `dev`, not pushed yet:

| Commit | What |
|---|---|
| `911977bd`, `6debb0b0` | core helpers + review fixes |
| `178a8d9b`, `2c2c2079`, `fc050ae7` | glue phases + review fixes |
| `f6faf010`, `2e550337`, `754a1041` | pipeline render + review fixes |
| `1ad7e7cd` | deploy swaps |
| `9482a7b1` | final-review fix: crashed row sets start_utc |

The suite is at 230 tests.

**Changes beyond the plan text, all reviewed:**
- `latest_since` rejects an empty or malformed cutoff.
- `run_still_open` and `pipeline_start` are pure core functions; the pipeline start time is carried through every phase.
- JD wait has a 600 s grace period.
- `crash_drill_target`: `simulate_crash` takes `plan` / `silver` / `gold` / `finish`, and `true` means plan.
- Notify writes a "crashed" closing run row.
- Per-tier crash advice.
- Model refresh `retry=0` with a 2 h timeout (not 1 retry).
- `executeMashupQueriesOnly: true` on the Dataflow activity.
- Reference-integrity tests on the pipeline.

**2026-10-12/13: Task 6 (Dev) done; Task 7 not needed.**
- **Sync:** pushed and synced (`9482a7b1`, then `43d216bb`).
  - The first Presentation sync conflicted only on Fabric's own reformat of the old pipeline (notebook references stored as real IDs, content otherwise identical). Brian chose Accept incoming.
  - After the sync, Fabric re-serialised the rendered pipeline (same content); Brian committed that once (`c402babc`).
- **Dev runs:**

  | Run | Result |
  |---|---|
  | dry run | ✅ |
  | `items` run (1 dataflow, 1 Silver, 1 Gold, 28 models) | ✅ |
  | Silver crash, then immediate rerun not refused (the crashed row closes the run) | ✅ |
  | Bronze failure | ✅ |
  | Gold `inject_failure` (models still refresh) | ✅ |
  | `rerun_failed` (picked exactly the failed item) | ✅ |
  | full `mode=all` (96 items, 28/28 models, ~42 min) | ✅ |

- **JD question answered:** the full run's Plan started JD Incremental as the service principal (run 13:56Z, Completed in 4.5 min).
- **Real findings, fixed in `2f671d59`:**
  - Pin Capture's model refresh failed once from capacity memory governance (9.2 GB consumed vs a 2.9 GB limit, during parallel refreshes), so Refresh_Model is back to **retry 1, after 120 s**.
  - A mistyped `mode` ("item") produced tracebacks in every phase, so Plan now checks `mode` up front with a plain message, and Gold skips selection after an upstream error.
- **Follow-up, not urgent:** Pin Capture used about 9 GB to refresh a 138 MB model. Its Power Query is worth a look.
- **Task 8 changed (2026-10-13):** the Monitor-hub "Set alert" is Activator-based (paid, needs workspace monitoring), so it isn't worth it here. Use the pipeline schedule's built-in, free **Failure notifications** instead (pipeline → Home → Schedule → Failure notifications → add Brian). Fabric sends it, independent of the service principal. It only covers scheduled runs, so it is set on the **Prod** 06:15 schedule during Task 9; Dev has no schedule.
- **2026-10-13, Task 9 in progress (Prod live):**
  - **Access:** the refresh service principal is Contributor on DP Prod ×2 and the 3 report workspaces (Brian also asked to add RP - Sandbox, for models in validation). The deploy SPN is a user on both connections.
  - **Release:** PR #32 merged; Deploy DP backend succeeded (run 38419778309). `claim_prod_pipeline.py` was run as a safety net, and dev was fast-forwarded (`0cd25e53`).
  - **Prod pipeline verified:** all 8 notebook activities point at the Prod notebooks with the notebook connection, Refresh_Model has the model connection, Run_Dataflow points at Prod staging, and the schedule is kept.
  - **First manual Prod run** (`items` = Build_Silver_BranchName,Build_Gold_BranchLocation): OK, 2 items, 27/27 models.
  - **Why 27, not 28:** the 28th promoted report, Table-Column-Names-Search, is ODBC-only. It isn't in the DAG `reports`, so the DP run never refreshed it, before or after.
  - **Next:**
    - Brian adds Failure notifications on the Prod schedule.
    - **The 2026-10-14 06:15 scheduled run (5 dataflows) is the proof** that the Dataflow activities run as the schedule owner after a CI deploy. If it's clean, do Task 10 (retire the re-claim step).

**2026-10-14: Task 9 proven, Task 10 done.**
- **The proof:** the 06:15 scheduled run ran all 5 staging dataflows OK after the CI deploy, so the Dataflow activities run as the schedule owner.
- **Re-claim retired:** `claim_prod_pipeline.py` deleted (`347d3d44`, Brian's OK). OPERATIONS-GUIDE has a new "Identity" section; TROUBLESHOOTING, both CLAUDE.md files, NEW-DATA-SOURCE and git-integration-guide are updated.
- **Probe cleanup:**
  - `Utilities_SPN_Probe` and `Pipeline_SPN_Probe` removed from Git. The Dev sync needs Brian's Accept incoming, because the workspace re-saved the probe notebook.
  - `SPN_Probe_Results` and `SPN_Probe_Write` deleted from the Dev lakehouse.
- **The same morning's Bronze check blocked the refresh** over 2 unused rental tables. Fixed in PR #34: only failures on tables DP reads block now.
- **JD gateway error:** a one-off (1 of 15 Full runs, 0 of 24 Incremental since 9/30). Look at SPI01SR2034W only if it repeats.

**Amendments from the final review (apply in Tasks 6 and 9):**
- **Task 6 Step 6, model-failure drill:** removing the service principal's RP - Dev role makes the model *lookup* fail, so it never exercises Refresh_Model's Failed branch. Instead, make one Dev model's refresh itself fail (temporarily break its data-source credential), run, then restore it.
- **Task 6:** also run a Silver crash drill (`simulate_crash = silver`). Check that Notify writes the `crashed` row and that an immediate rerun isn't refused by the already-running guard.
- **Task 9:** the Dataflow activity has no connection. In a **scheduled** Prod run after a CI deploy, it might run as SPN-Fabric-CICD-Deploy (refused with `SPNBasedRefreshNotAllowed`) rather than the schedule owner.
  - **Keep running `claim_prod_pipeline.py` after Prod deploys** until a scheduled Prod run with dataflows in its selection has succeeded without a re-claim. The next normal 06:15 run proves it. Only then do Task 10 Step 1.
  - **If it fails:** dataflows need the re-claim, or their own schedule. Decide with Brian.
