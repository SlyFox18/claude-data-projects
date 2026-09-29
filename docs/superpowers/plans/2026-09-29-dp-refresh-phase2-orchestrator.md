# DP Refresh Redesign — Phase 2–3 (Orchestrator, Pipeline, Alerts, Drills) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the three old DP pipelines with one `Pipeline_DP_Refresh` that runs every due producer
in dependency order through two identical `Run_DP_Refresh` orchestrator notebooks, logs every item, refreshes
all report models, and alerts by Teams and email, proven by drills and a full manual run in Dev.

**Architecture:** All decision logic (what's due, the DAG, skip propagation, result classification,
Bronze verdict, summary text) lives in one pure-Python module, `deploy/orchestrator_core.py`, unit-tested
locally. A renderer writes both notebook copies from that module plus a Fabric-only "glue" file, so the two
copies can never drift and CI proves they're current. The pipeline stays thin: Silver orchestrator → Gold
orchestrator → emails/Teams, driven by the Gold orchestrator's JSON exit value.

**Tech Stack:** Python 3.12/3.13, pytest, Fabric notebooks (PySpark, `notebookutils.notebook.runMultiple`,
semantic-link `sempy.fabric` for REST and model refresh), Fabric Data Pipeline JSON (TridentNotebook,
Office365Email, IfCondition), GitHub Actions CI, `fab` CLI.

**Inputs:** spec `docs/superpowers/specs/2026-09-28-dp-refresh-pipeline-redesign-design.md`; Phase 0
`docs/architecture/dp-refresh-prototype-results.md`; Phase 1 `docs/architecture/dp-refresh-phase1-results.md`.

---

## Ground rules (read before any task)

- **Two repos, branch `dev` only:**
  - `fabric-workspace-docs` (`C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs`): Fabric Git
    mirror, `deploy/`, CI.
  - `data-projects` (`C:\Users\bfox\Documents\Git-Projects\data-projects`): tools in `tools/dp-migration/`,
    docs.
  - Never commit to `main`. Both repos have unrelated uncommitted files, so **stage only the files a task
    names.** Every commit message ends with a blank line and
    `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Pushing `fabric-workspace-docs` `dev` runs CI.** CI runs `pytest deploy`, `dag_check.py` and
  `hygiene_audit.py`, then deploys the config files to the Dev lakehouses.
  - If a push is rejected: `git pull --rebase --autostash origin dev`, then push.
  - On a rebase conflict, stop and report.
- **Single writer for the Dev workspaces:** push → `python C:/Users/bfox/Documents/Git-Projects/data-projects/tools/dp-migration/wait_ci.py`
  → `python .../git_sync.py <workspaceId>`.
  - Never `fab import`.
  - If `git_sync.py` refuses, stop and report.
  - New `.platform` files have **no trailing newline**.
- **Never delete anything in Fabric or Git without Brian's explicit OK** (Task 11 is controller-only).
- **Timing:** don't run anything 4:15–6:00 AM Central. Don't create any schedule; Dev stays on-demand.
- **After any Gold notebook runs**, refresh the SQL endpoint metadata:
  `fab api -X post "workspaces/73fd5443-240e-410a-990a-98827f32c087/sqlEndpoints/18effb0e-7bc2-47a1-854c-f4f2e8129145/refreshMetadata"`.
  The orchestrator does this itself; this is only for manual runs.
- **Bash hooks sometimes falsely block commands** ("printenv", "az token", "rm -rf"). Put the command in a
  script under `C:/Users/bfox/AppData/Local/Temp/claude/c--Users-bfox-Documents-Git-Projects-data-projects/ed03239b-4817-4e80-8f42-4dd2204a7945/scratchpad`.
  Prefix direct `fab` use with `export PATH="$HOME/.local/bin:$PATH"`. `fab api` output may start with a
  fabric-cicd upgrade notice, so parse from `'{\n  "status_code"'`.

| Thing | Value |
|---|---|
| DP - Staging - Dev | workspace `ab15d64d-c7ba-415d-9bcf-7feb1ef9b201`, lakehouse DP_Staging `876255e0-d462-4697-adc1-4a655f5bb101` |
| DP - Presentation - Dev | workspace `73fd5443-240e-410a-990a-98827f32c087`, lakehouse DP_Presentation `966efc8a-16f9-423b-aa43-e368fcd8fb91`, SQL endpoint `18effb0e-7bc2-47a1-854c-f4f2e8129145` |
| JD_FabricOneLake | workspace `4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9`; Full `e2094bc4-2b08-4510-83db-bd0d19ec754f`; Incremental `c310aa3b-3143-49aa-b77c-a3ae13e5660b` |
| Office 365 email connection (existing, used by the old DP pipelines) | `97d3696e-b886-4770-9fd0-f4aae4c6a7ed`, to `bfox@spitractor.com` |
| Report models | 24, all in workspace `RP - Dev` (names = `reports[].model` in the config) |

**Facts learned in Phases 0–1 that this plan relies on:**
- `runMultiple` blocks a child whose default lakehouse differs from the caller's, so there's one orchestrator
  per lakehouse. Never set `useRootDefaultLakehouse`.
- `from notebookutils.common.exceptions import …` doesn't exist in runtime 1.3. Catch `Exception` and read
  `getattr(ex, "result", None)`. Its per-activity values are dicts with `exception` and `exitVal`.
- A dependent of a failed item comes back with the exception text `Job X failed due to upstream job Y failed`.
- `runMultiple` gives **no per-item timings**. The log records per-tier durations; per-item rows have no
  duration. This replaces the spec's "5 slowest notebooks" line.
- Defaults from tuning: concurrency 8; session settings `spark.sql.shuffle.partitions=16`,
  `spark.sql.autoBroadcastJoinThreshold=52428800`.

## File structure

| File | Repo | Responsibility |
|---|---|---|
| `deploy/dp_refresh_dag.json` (modify) | fabric-workspace-docs | Add the `orchestrator` settings block |
| `deploy/dag_config.py`, `deploy/test_dag_config.py` (modify) | fabric-workspace-docs | Validate the `orchestrator` block |
| `deploy/orchestrator_core.py` (create) | fabric-workspace-docs | Pure logic: due cadences, selection, DAG + skip propagation, result classification, Bronze verdict, affected reports, summary text |
| `deploy/test_orchestrator_core.py` (create) | fabric-workspace-docs | Unit tests for the above |
| `deploy/orchestrator_glue.py` (create) | fabric-workspace-docs | Fabric-only code (notebookutils, sempy, Spark): env resolution, jobs, Bronze fetch, runMultiple, log, metadata + model refresh, exit |
| `deploy/render_orchestrator.py`, `deploy/test_render_orchestrator.py` (create) | fabric-workspace-docs | Build both `Run_DP_Refresh` notebooks from core + glue; test that the committed notebooks are current and that glue parses |
| `workspaces/DP - Staging - Dev/Orchestration/Run_DP_Refresh.Notebook/` (generated) | fabric-workspace-docs | Silver orchestrator |
| `workspaces/DP - Presentation - Dev/Orchestration/Run_DP_Refresh.Notebook/` (generated) | fabric-workspace-docs | Gold orchestrator |
| `deploy/deploy_backend.py` (modify) | fabric-workspace-docs | Also write `dp_refresh_dag.json` to both lakehouses' `Files/config/` |
| `workspaces/DP - Presentation - Dev/Pipelines/Pipeline_DP_Refresh.DataPipeline/` (create) | fabric-workspace-docs | The pipeline |
| `docs/architecture/dp-refresh-pipeline-assessment.md`, `projects/jd-bronze-pipelines/README.md` (modify) | data-projects | Point to the new pipeline |
| `docs/architecture/dp-refresh-phase2-results.md` (create) | data-projects | Drill and full-run results |

---

### Task 1: `orchestrator` settings block in the config

**Files:** Modify `deploy/dp_refresh_dag.json`, `deploy/dag_config.py`, `deploy/test_dag_config.py` (fabric-workspace-docs).

- [ ] **Step 1: Failing tests** (append to `deploy/test_dag_config.py`)

```python
GOOD_SETTINGS = {
    "concurrency": 8,
    "sparkConf": {"spark.sql.shuffle.partitions": "16", "spark.sql.autoBroadcastJoinThreshold": "52428800"},
    "retry": 2,
    "retryIntervalSeconds": 60,
    "timeoutPerCellSeconds": 1800,
    "dagTimeoutSeconds": 10800,
    "reportWorkspace": {"Dev": "RP - Dev"},
    "modelRefreshParallelism": 4,
}


def test_orchestrator_settings_valid():
    config, notebooks, reports = base()
    config["orchestrator"] = dict(GOOD_SETTINGS)
    assert check(config, notebooks, reports) == []


def test_orchestrator_settings_missing_or_bad():
    config, notebooks, reports = base()
    config["orchestrator"] = {k: v for k, v in GOOD_SETTINGS.items() if k != "concurrency"}
    assert any("orchestrator: missing concurrency" in e for e in check(config, notebooks, reports))
    config["orchestrator"] = dict(GOOD_SETTINGS, concurrency=0)
    assert any("orchestrator: concurrency" in e for e in check(config, notebooks, reports))
    config["orchestrator"] = dict(GOOD_SETTINGS, reportWorkspace={})
    assert any("reportWorkspace" in e for e in check(config, notebooks, reports))
```

  Also change the `base()` fixture so its config includes `"orchestrator": dict(GOOD_SETTINGS)`. Define
  `GOOD_SETTINGS` above `base()`, and add the key inside the `config` dict. Otherwise the new "missing block"
  check below would fail every existing test.

- [ ] **Step 2:** `cd deploy && python -m pytest test_dag_config.py -q` → the two new tests fail.
- [ ] **Step 3: Implement.** In `dag_config.py`, add near the constants:

```python
ORCHESTRATOR_INTS = {"concurrency": 1, "retry": 0, "retryIntervalSeconds": 0, "timeoutPerCellSeconds": 60,
                     "dagTimeoutSeconds": 600, "modelRefreshParallelism": 1}  # key -> minimum


def _check_orchestrator(settings) -> list:
    if not isinstance(settings, dict):
        return ["config missing key 'orchestrator'"]
    errors = []
    for key, minimum in ORCHESTRATOR_INTS.items():
        if key not in settings:
            errors.append(f"orchestrator: missing {key}")
        elif not isinstance(settings[key], int) or settings[key] < minimum:
            errors.append(f"orchestrator: {key} must be an integer >= {minimum}")
    if not isinstance(settings.get("sparkConf"), dict):
        errors.append("orchestrator: sparkConf must be an object of Spark setting -> value")
    workspaces = settings.get("reportWorkspace")
    if not isinstance(workspaces, dict) or not workspaces:
        errors.append("orchestrator: reportWorkspace must map environment (e.g. Dev) -> report workspace name")
    return errors
```

  and in `check()` right after the `"items" not in config` check add
  `errors += _check_orchestrator(config.get("orchestrator"))`.
- [ ] **Step 4:** Add to `deploy/dp_refresh_dag.json` (top level, after `"excluded"`; use a Python
  load/dump with `indent=2` and a trailing newline):

```json
"orchestrator": {
  "concurrency": 8,
  "sparkConf": {"spark.sql.shuffle.partitions": "16", "spark.sql.autoBroadcastJoinThreshold": "52428800"},
  "retry": 2,
  "retryIntervalSeconds": 60,
  "timeoutPerCellSeconds": 1800,
  "dagTimeoutSeconds": 10800,
  "reportWorkspace": {"Dev": "RP - Dev"},
  "modelRefreshParallelism": 4
}
```

- [ ] **Step 5:** `python -m pytest -q` in `deploy/` passes, and `python deploy/dag_check.py` prints OK.
  Commit `deploy/dag_config.py deploy/test_dag_config.py deploy/dp_refresh_dag.json` with message
  `DAG config: orchestrator settings (concurrency 8 + session settings)`. Don't push yet.

---

### Task 2: `orchestrator_core.py` — selection and DAG

**Files:** Create `deploy/orchestrator_core.py`, `deploy/test_orchestrator_core.py`.

- [ ] **Step 1: Failing tests**

```python
# deploy/test_orchestrator_core.py
from datetime import datetime
from pathlib import Path
import sys

import pytest

sys.path.insert(0, str(Path(__file__).parent))
from orchestrator_core import build_dag, due_cadences, select_items  # noqa: E402

SETTINGS = {"concurrency": 8, "retry": 2, "retryIntervalSeconds": 60, "timeoutPerCellSeconds": 1800,
            "dagTimeoutSeconds": 10800}


def item(name, tier, cadence="daily", deps=(), type_="notebook"):
    return {"name": name, "type": type_, "tier": tier, "cadence": cadence, "dependsOn": list(deps),
            "produces": [name.split("_", 2)[-1]], "workspace": "staging" if tier != "gold" else "presentation"}


CONFIG = {"items": [
    item("df_Raw", "staging", type_="dataflow"),
    item("Build_Silver_A", "silver"),
    item("Build_Silver_W", "silver", cadence="weekly"),
    item("Build_Gold_Dim", "gold", deps=["Build_Silver_A"]),
    item("Build_Gold_Fact", "gold", deps=["Build_Gold_Dim", "df_Raw"]),
    item("Build_Gold_Month", "gold", cadence="monthly"),
    item("Build_Gold_Cal", "gold", cadence="manual"),
], "reports": []}
TUESDAY = datetime(2026, 9, 29, 4, 15)
MONDAY = datetime(2026, 9, 28, 4, 15)
FIRST = datetime(2026, 10, 1, 4, 15)


def names(items):
    return [i["name"] for i in items]


def test_due_cadences():
    assert due_cadences("scheduled", TUESDAY) == {"daily"}
    assert due_cadences("scheduled", MONDAY) == {"daily", "weekly"}
    assert due_cadences("scheduled", FIRST) == {"daily", "monthly"}
    assert due_cadences("all", TUESDAY) == {"daily", "weekly", "monthly"}
    assert due_cadences("intraday", TUESDAY) == {"intraday"}
    with pytest.raises(ValueError):
        due_cadences("sometimes", TUESDAY)


def test_select_scheduled_by_tier_and_type():
    assert names(select_items(CONFIG, "gold", "scheduled", TUESDAY)) == ["Build_Gold_Dim", "Build_Gold_Fact"]
    assert names(select_items(CONFIG, "silver", "scheduled", MONDAY)) == ["Build_Silver_A", "Build_Silver_W"]
    assert names(select_items(CONFIG, "staging", "scheduled", TUESDAY)) == ["df_Raw"]


def test_manual_items_only_run_when_named():
    assert "Build_Gold_Cal" not in names(select_items(CONFIG, "gold", "all", TUESDAY))
    assert names(select_items(CONFIG, "gold", "items", TUESDAY, requested=["Build_Gold_Cal"])) == ["Build_Gold_Cal"]
    with pytest.raises(ValueError):
        select_items(CONFIG, "gold", "items", TUESDAY, requested=["Nope"])


def test_rerun_uses_the_given_names():
    assert names(select_items(CONFIG, "gold", "rerun_failed", TUESDAY, requested=["Build_Gold_Fact"])) == ["Build_Gold_Fact"]


def test_build_dag_keeps_in_run_edges_and_settings():
    items = select_items(CONFIG, "gold", "scheduled", TUESDAY)
    dag, skipped = build_dag(items, CONFIG, SETTINGS, upstream_failed=set())
    acts = {a["name"]: a for a in dag["activities"]}
    assert skipped == {}
    assert acts["Build_Gold_Dim"]["dependencies"] == []            # Silver edge is cross-tier: dropped
    assert acts["Build_Gold_Fact"]["dependencies"] == ["Build_Gold_Dim"]
    assert acts["Build_Gold_Fact"]["path"] == "Build_Gold_Fact"
    assert acts["Build_Gold_Fact"]["retry"] == 2 and acts["Build_Gold_Fact"]["timeoutPerCellInSeconds"] == 1800
    assert dag["concurrency"] == 8 and dag["timeoutInSeconds"] == 10800


def test_upstream_failure_skips_dependents_transitively():
    items = select_items(CONFIG, "gold", "scheduled", TUESDAY)
    dag, skipped = build_dag(items, CONFIG, SETTINGS, upstream_failed={"Build_Silver_A"})
    assert names(dag["activities"]) == []
    assert skipped == {"Build_Gold_Dim": "Build_Silver_A", "Build_Gold_Fact": "Build_Gold_Dim"}


def test_failed_dataflow_skips_its_dependents_only():
    items = select_items(CONFIG, "gold", "scheduled", TUESDAY)
    dag, skipped = build_dag(items, CONFIG, SETTINGS, upstream_failed={"df_Raw"})
    assert names(dag["activities"]) == ["Build_Gold_Dim"]
    assert skipped == {"Build_Gold_Fact": "df_Raw"}


def test_inject_failure_swaps_the_path():
    items = select_items(CONFIG, "gold", "scheduled", TUESDAY)
    dag, _ = build_dag(items, CONFIG, SETTINGS, upstream_failed=set(), inject_failure="Build_Gold_Dim",
                       failure_probe="Proto_FailProbe")
    acts = {a["name"]: a for a in dag["activities"]}
    assert acts["Build_Gold_Dim"]["path"] == "Proto_FailProbe"
    assert acts["Build_Gold_Dim"]["retry"] == 0
```

- [ ] **Step 2:** Run → FAIL (ModuleNotFoundError).
- [ ] **Step 3: Implement**

```python
# deploy/orchestrator_core.py
"""Pure logic for Run_DP_Refresh (no Spark, no Fabric imports).

Unit-tested locally (deploy/test_orchestrator_core.py) and embedded verbatim into both orchestrator
notebooks by deploy/render_orchestrator.py, so the Silver and Gold copies can't drift.
"""
import html
from datetime import datetime

MODES = {"scheduled", "all", "intraday", "items", "rerun_failed"}
SKIP_MARKER = "failed due to upstream job"


def due_cadences(mode: str, now_local: datetime) -> set:
    """Cadences a run of this mode covers. 'manual' items only run when named (mode 'items')."""
    if mode == "scheduled":
        due = {"daily"}
        if now_local.weekday() == 0:
            due.add("weekly")
        if now_local.day == 1:
            due.add("monthly")
        return due
    if mode == "all":
        return {"daily", "weekly", "monthly"}
    if mode == "intraday":
        return {"intraday"}
    raise ValueError(f"mode {mode!r} has no cadences (use one of {sorted(MODES)})")


def select_items(config: dict, tier: str, mode: str, now_local: datetime, requested=()) -> list:
    """Config items of one tier ('staging' = dataflows, 'silver', 'gold') this run should execute."""
    by_name = {i["name"]: i for i in config["items"]}
    if mode in ("items", "rerun_failed"):
        unknown = sorted(set(requested) - set(by_name))
        if unknown:
            raise ValueError(f"unknown items: {unknown}")
        wanted = set(requested)
    else:
        due = due_cadences(mode, now_local)
        wanted = {n for n, i in by_name.items() if i["cadence"] in due}
    return [by_name[n] for n in sorted(wanted) if by_name[n]["tier"] == tier]


def build_dag(items: list, config: dict, settings: dict, upstream_failed: set,
              inject_failure: str = "", failure_probe: str = "Proto_FailProbe"):
    """runMultiple DAG for `items`, plus {skipped item: the failed/skipped item it depends on}.

    Edges to items outside this run are dropped (they're either another tier, ordered by the pipeline,
    or not due today, so the existing table is used). An item whose dependency failed upstream, or was
    itself skipped, is skipped: running it would only rebuild from stale input.
    """
    selected = {i["name"] for i in items}
    skipped, bad = {}, set(upstream_failed)
    changed = True
    while changed:
        changed = False
        for item in items:
            if item["name"] in skipped:
                continue
            culprit = next((d for d in item["dependsOn"] if d in bad), None)
            if culprit:
                skipped[item["name"]] = culprit
                bad.add(item["name"])
                changed = True
    activities = []
    for item in items:
        if item["name"] in skipped:
            continue
        injected = item["name"] == inject_failure
        activities.append({
            "name": item["name"],
            "path": failure_probe if injected else item["name"],
            "timeoutPerCellInSeconds": int(item.get("timeoutSeconds", settings["timeoutPerCellSeconds"])),
            "retry": 0 if injected else int(settings["retry"]),
            "retryIntervalInSeconds": int(settings["retryIntervalSeconds"]),
            "dependencies": [d for d in item["dependsOn"] if d in selected and d not in skipped],
        })
    return {"activities": activities, "concurrency": int(settings["concurrency"]),
            "timeoutInSeconds": int(settings["dagTimeoutSeconds"])}, skipped
```

  (An item's optional `timeoutSeconds` in the config overrides the default cell timeout.)

- [ ] **Step 4:** Tests pass. Commit `deploy/orchestrator_core.py deploy/test_orchestrator_core.py` with
  message `orchestrator_core: selection + DAG with skip propagation`.

---

### Task 3: `orchestrator_core.py` — results, Bronze verdict, reports, summary

**Files:** Modify `deploy/orchestrator_core.py`, `deploy/test_orchestrator_core.py`.

- [ ] **Step 1: Failing tests** (append; extend the import line with
  `affected_reports, classify_results, compose_summary, evaluate_bronze`)

```python
def test_classify_results():
    results = {
        "A": {"exception": None, "exitVal": ""},
        "B": {"exception": "RuntimeError: boom\nlong traceback", "exitVal": ""},
        "C": {"exception": "Job C failed due to upstream job B failed", "exitVal": ""},
    }
    out = classify_results(results, ["A", "B", "C", "D"])
    assert out["A"] == {"status": "Succeeded", "error": None, "skipped_because": None}
    assert out["B"]["status"] == "Failed" and out["B"]["error"].startswith("RuntimeError: boom")
    assert out["C"] == {"status": "Skipped", "error": None, "skipped_because": "B"}
    assert out["D"]["status"] == "Skipped"          # never reported back


def test_evaluate_bronze():
    now = datetime(2026, 9, 29, 9, 20)               # naive UTC, ~4:20 AM Central
    ok_run = {"id": "r", "status": "Completed", "startTimeUtc": "2026-09-29T05:00:13.3063771Z"}
    good = [{"activityType": "Copy", "status": "Succeeded"}] * 3
    assert evaluate_bronze(ok_run, good, ok_run, good, now) == []
    bad_copy = good + [{"activityType": "Copy", "status": "Failed",
                        "error": {"message": "gateway can access ncu.frontend.clouddatahub.net"}}]
    problems = evaluate_bronze(ok_run, bad_copy, ok_run, good, now)
    assert len(problems) == 1 and "Full" in problems[0] and "clouddatahub" in problems[0]
    old = dict(ok_run, startTimeUtc="2026-09-27T05:00:13Z")
    assert any("Incremental" in p and "not from today" in p for p in evaluate_bronze(ok_run, good, old, good, now))
    assert any("no runs" in p for p in evaluate_bronze(None, [], ok_run, good, now))


REPORT_CONFIG = {"items": [
    {"name": "S", "dependsOn": [], "produces": ["Silver_S"]},
    {"name": "D", "dependsOn": ["S"], "produces": ["dim_D"]},
    {"name": "F", "dependsOn": ["D"], "produces": ["Fact_F"]},
    {"name": "X", "dependsOn": [], "produces": ["Fact_X"]},
], "reports": [{"model": "R1", "tables": ["Fact_F"]}, {"model": "R2", "tables": ["Fact_X", "dim_D"]}]}


def test_affected_reports_follow_downstream():
    assert affected_reports(REPORT_CONFIG, {"S"}) == ["R1", "R2"]
    assert affected_reports(REPORT_CONFIG, {"X"}) == ["R2"]
    assert affected_reports(REPORT_CONFIG, set()) == []


def run(**kw):
    base = {"env": "Dev", "mode": "scheduled", "dry_run": False, "run_id": "abc",
            "started_local": "2026-09-29 04:15", "finished_local": "2026-09-29 05:41",
            "bronze_problems": [], "error": None, "items": {}, "models": {}, "tier_seconds": {},
            "affected_reports": [], "plan": None}
    base.update(kw)
    return base


def test_summary_ok():
    s = compose_summary(run(items={"A": {"status": "Succeeded", "tier": "gold"}}, models={"R": {"status": "Completed"}}))
    assert s["status"] == "ok" and s["subject"].startswith("✅ [Dev] DP Refresh OK")
    assert s["alert_email"] is False and s["teams"] is False


def test_summary_partial():
    items = {"A": {"status": "Failed", "tier": "gold", "error": "boom"},
             "B": {"status": "Skipped", "tier": "gold", "skipped_because": "A"}}
    s = compose_summary(run(items=items, affected_reports=["Customer Anatomy"]))
    assert s["status"] == "partial" and s["subject"].startswith("⚠ [Dev] DP Refresh: 1 failed, 1 skipped")
    assert s["teams"] is True and s["alert_email"] is False
    assert "rerun_failed" in s["teams_text"] and "Customer Anatomy" in s["html"]


def test_summary_bronze_failed_and_error():
    s = compose_summary(run(bronze_problems=["Full: 98 failed activities"]))
    assert s["status"] == "bronze_failed" and s["alert_email"] and s["teams"]
    assert s["subject"].startswith("🔴 [Dev] DP Refresh FAILED") and "jd-bronze-pipelines/README.md" in s["html"]
    e = compose_summary(run(error="KeyError: x"))
    assert e["status"] == "error" and e["alert_email"] and "KeyError" in e["html"]


def test_summary_escapes_html_and_dry_run():
    s = compose_summary(run(items={"A": {"status": "Failed", "tier": "gold", "error": "<script>"}}))
    assert "<script>" not in s["html"] and "&lt;script&gt;" in s["html"]
    d = compose_summary(run(dry_run=True, plan={"gold": ["Build_Gold_X"]}))
    assert d["status"] == "dry_run" and d["alert_email"] is False and "Build_Gold_X" in d["html"]
```

- [ ] **Step 2:** Run → FAIL (ImportError).
- [ ] **Step 3: Implement** (append to `orchestrator_core.py`)

```python
RUNBOOK = "data-projects/projects/jd-bronze-pipelines/README.md"


def classify_results(results: dict, names: list) -> dict:
    """runMultiple results -> {name: {status, error, skipped_because}} for every name in the DAG."""
    out = {}
    for name in names:
        r = results.get(name)
        if r is None:
            out[name] = {"status": "Skipped", "error": None, "skipped_because": "not run"}
            continue
        exc = r.get("exception")
        if exc is None:
            out[name] = {"status": "Succeeded", "error": None, "skipped_because": None}
        elif SKIP_MARKER in str(exc):
            culprit = str(exc).split("upstream job", 1)[1].split("failed", 1)[0].strip()
            out[name] = {"status": "Skipped", "error": None, "skipped_because": culprit}
        else:
            out[name] = {"status": "Failed", "error": str(exc)[:1000], "skipped_because": None}
    return out


MAX_BRONZE_AGE_HOURS = 30


def evaluate_bronze(full_run, full_acts, inc_run, inc_acts, now_utc) -> list:
    """Problems with JD's Bronze load (empty list = healthy). Judged on activity runs, never on the
    pipeline status: JD's Full pipeline reports Completed even when every copy fails. A run counts as
    'today' if it started within MAX_BRONZE_AGE_HOURS of the check (which runs ~4:15 AM Central, after
    JD's midnight Full load). now_utc is a naive UTC datetime."""
    problems = []
    for label, run_, acts in (("Full", full_run, full_acts), ("Incremental", inc_run, inc_acts)):
        if not run_:
            problems.append(f"{label}: no runs found")
            continue
        start = datetime.fromisoformat(run_["startTimeUtc"].rstrip("Z").split("+")[0][:26])
        if (now_utc - start).total_seconds() > MAX_BRONZE_AGE_HOURS * 3600:
            problems.append(f"{label}: latest run {run_['startTimeUtc']} is not from today")
        failed = [a for a in acts if a.get("status") == "Failed"]
        if failed:
            msg = (failed[0].get("error") or {}).get("message", "")[:200]
            problems.append(f"{label}: {len(failed)} failed activities, e.g. {msg}")
    return problems


def affected_reports(config: dict, bad_items: set) -> list:
    """Report models that read a table produced by a bad item or anything downstream of one."""
    downstream, frontier = set(bad_items), set(bad_items)
    while frontier:
        frontier = {i["name"] for i in config["items"]
                    if i["name"] not in downstream and set(i["dependsOn"]) & frontier}
        downstream |= frontier
    tables = {t.lower() for i in config["items"] if i["name"] in downstream for t in i["produces"]}
    return sorted(r["model"] for r in config["reports"] if tables & {t.lower() for t in r["tables"]})


def compose_summary(run: dict) -> dict:
    """Status, email subject/html, Teams text and alert flags for one pipeline run."""
    items, models = run["items"], run["models"]
    failed = sorted(n for n, i in items.items() if i["status"] == "Failed")
    skipped = sorted(n for n, i in items.items() if i["status"] == "Skipped")
    bad_models = sorted(m for m, s in models.items() if s["status"] != "Completed")
    env = f"[{run['env']}]"
    if run.get("dry_run"):
        status, subject = "dry_run", f"🧪 {env} DP Refresh dry run ({run['mode']})"
    elif run.get("error"):
        status, subject = "error", f"🔴 {env} DP Refresh FAILED – orchestrator error"
    elif run["bronze_problems"]:
        status, subject = "bronze_failed", f"🔴 {env} DP Refresh FAILED – JD Bronze problem, nothing refreshed"
    elif failed or skipped or bad_models:
        status = "partial"
        parts = [f"{len(failed)} failed", f"{len(skipped)} skipped"] + ([f"{len(bad_models)} models failed"] if bad_models else [])
        subject = f"⚠ {env} DP Refresh: {', '.join(parts)}"
    else:
        status, subject = "ok", f"✅ {env} DP Refresh OK – {run['finished_local'][-5:]}"

    e = html.escape
    rows = [f"<p><b>{e(subject)}</b><br>Run {e(run['run_id'])} · mode {e(run['mode'])} · "
            f"{e(run['started_local'])} → {e(run['finished_local'])} (Central)</p>"]
    if status == "error":
        rows.append(f"<p><b>Error:</b> <pre>{e(str(run['error'])[:3000])}</pre></p>")
    if status == "bronze_failed":
        rows.append("<p><b>JD Bronze check failed — nothing was rebuilt and no model was refreshed:</b></p><ul>"
                    + "".join(f"<li>{e(p)}</li>" for p in run["bronze_problems"]) + "</ul>"
                    f"<p>Fix: follow the runbook <code>{RUNBOOK}</code>, re-run JD's pipelines, then run "
                    "Pipeline_DP_Refresh again.</p>")
    if status == "dry_run":
        rows.append("<p><b>Plan (nothing ran):</b></p><ul>" + "".join(
            f"<li>{e(t)}: {e(', '.join(n))}</li>" for t, n in (run.get("plan") or {}).items()) + "</ul>")
    if failed:
        rows.append("<p><b>Failed:</b></p><ul>" + "".join(
            f"<li>{e(n)} — {e((items[n].get('error') or '').splitlines()[0][:300])}</li>" for n in failed) + "</ul>")
    if skipped:
        rows.append("<p><b>Skipped (dependency failed):</b></p><ul>" + "".join(
            f"<li>{e(n)} (because {e(items[n].get('skipped_because') or '?')})</li>" for n in skipped) + "</ul>")
    if bad_models:
        rows.append("<p><b>Model refresh failed:</b></p><ul>" + "".join(
            f"<li>{e(m)} — {e(str(models[m].get('error'))[:300])}</li>" for m in bad_models) + "</ul>")
    if run["affected_reports"]:
        rows.append("<p><b>Reports with partly stale data:</b> " + e(", ".join(run["affected_reports"])) + "</p>")
    if status == "partial":
        rows.append("<p>Fix the cause, then run <b>Pipeline_DP_Refresh</b> with <b>mode = rerun_failed</b>.</p>")
    ok_items = sum(1 for i in items.values() if i["status"] == "Succeeded")
    rows.append(f"<p>Items: {ok_items} succeeded · {len(failed)} failed · {len(skipped)} skipped. "
                f"Models: {sum(1 for s in models.values() if s['status'] == 'Completed')} of {len(models)} refreshed. "
                + " · ".join(f"{e(t)} {int(s)} s" for t, s in run["tier_seconds"].items()) + "</p>")

    teams_text = subject
    if failed:
        teams_text += " | Failed: " + ", ".join(failed)
    if run["affected_reports"]:
        teams_text += " | Stale: " + ", ".join(run["affected_reports"])
    if status == "partial":
        teams_text += " | Fix, then run Pipeline_DP_Refresh with mode = rerun_failed"
    if status == "bronze_failed":
        teams_text += f" | Runbook: {RUNBOOK}"
    return {"status": status, "subject": subject, "html": "\n".join(rows), "teams_text": teams_text[:2000],
            "alert_email": status in ("error", "bronze_failed"),
            "teams": status in ("error", "bronze_failed", "partial")}
```

- [ ] **Step 4:** Tests pass. Commit (message `orchestrator_core: results, Bronze verdict, reports, summary`).

---

### Task 4: Fabric glue (`orchestrator_glue.py`)

This code only runs inside a Fabric notebook (it uses `notebookutils`, `spark`, `sempy`). Locally it's
parse-checked, not executed. It uses the functions from `orchestrator_core.py`, which the renderer places
in an earlier cell.

**Files:** Create `deploy/orchestrator_glue.py`.

- [ ] **Step 1: Write it**

```python
# deploy/orchestrator_glue.py
# Fabric-only glue for Run_DP_Refresh. Rendered into both notebooks after orchestrator_core.
# Parameters (from the PARAMETERS cell): mode, dry_run, items, run_id, upstream_json,
# inject_failure, simulate_bronze_failure.
import json
import time
import traceback
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

import sempy.fabric as fabric
from sempy.fabric import FabricRestClient

CENTRAL = ZoneInfo("America/Chicago")
JD_WS = "4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9"
JD_FULL = "e2094bc4-2b08-4510-83db-bd0d19ec754f"
JD_INCR = "c310aa3b-3143-49aa-b77c-a3ae13e5660b"
TERMINAL = {"Completed", "Failed", "Cancelled", "Deduped"}
LOG_SCHEMA = ("run_id string, env string, tier string, mode string, row_type string, name string, "
              "status string, start_utc timestamp, end_utc timestamp, duration_s double, attempts int, "
              "error string, skipped_because string, cu_seconds double")
rest = FabricRestClient()


def now_utc():
    return datetime.now(timezone.utc).replace(tzinfo=None)


def rest_get(path):
    r = rest.get(path)
    if r.status_code >= 300:
        raise RuntimeError(f"GET {path}: {r.status_code} {r.text[:300]}")
    return r.json()


def rest_list(path):
    values, token = [], None
    while True:
        sep = "&" if "?" in path else "?"
        page = rest_get(path + (f"{sep}continuationToken={token}" if token else ""))
        values += page.get("value", [])
        token = page.get("continuationToken")
        if not token:
            return values


def run_job(ws, item, job_type, timeout_s):
    """Start a Fabric job and wait for it (same approach as tools/dp-migration/run_item.py)."""
    before = {i["id"] for i in rest_list(f"v1/workspaces/{ws}/items/{item}/jobs/instances")}
    r = rest.post(f"v1/workspaces/{ws}/items/{item}/jobs/instances?jobType={job_type}")
    if r.status_code not in (200, 201, 202):
        return {"status": "Failed", "error": f"submit {r.status_code} {r.text[:300]}"}
    started = time.time()
    while time.time() - started < timeout_s:
        time.sleep(20)
        new = [i for i in rest_list(f"v1/workspaces/{ws}/items/{item}/jobs/instances") if i["id"] not in before]
        if new and new[0].get("status") in TERMINAL:
            reason = new[0].get("failureReason")
            return {"status": new[0]["status"], "error": json.dumps(reason)[:1000] if reason else None}
    return {"status": "Failed", "error": f"timed out after {timeout_s}s"}


def latest_run_and_activities(item):
    runs = rest_list(f"v1/workspaces/{JD_WS}/items/{item}/jobs/instances")
    if not runs:
        return None, []
    run = max(runs, key=lambda r: r.get("startTimeUtc") or "")
    body = {"filters": [], "orderBy": [{"orderBy": "ActivityRunStart", "order": "ASC"}],
            "lastUpdatedAfter": "2026-01-01T00:00:00Z", "lastUpdatedBefore": "2099-01-01T00:00:00Z"}
    r = rest.post(f"v1/workspaces/{JD_WS}/datapipelines/pipelineruns/{run['id']}/queryactivityruns", json=body)
    if r.status_code >= 300:
        raise RuntimeError(f"queryactivityruns {r.status_code} {r.text[:300]}")
    return run, r.json().get("value", [])


def log_rows(rows):
    df = spark.createDataFrame(rows, LOG_SCHEMA)
    df.write.format("delta").mode("append").save(LOG_PATH)


def row(**kw):
    base = dict(run_id=RUN_ID, env=ENV, tier=TIER, mode=mode, row_type=None, name=None, status=None,
                start_utc=None, end_utc=None, duration_s=None, attempts=None, error=None,
                skipped_because=None, cu_seconds=None)
    base.update(kw)
    return base


def already_running():
    try:
        log = spark.read.format("delta").load(LOG_PATH)
    except Exception:
        return False
    recent = log.filter(f"row_type = 'run' AND tier = 'silver' AND start_utc > current_timestamp() - INTERVAL 4 HOURS")
    started = {r.run_id for r in recent.filter("status = 'InProgress'").select("run_id").collect()}
    finished = {r.run_id for r in recent.filter("status != 'InProgress'").select("run_id").collect()}
    return bool(started - finished - {RUN_ID})


def run_dag(dag):
    for key, value in SETTINGS["sparkConf"].items():
        spark.conf.set(key, str(value))
    try:
        results = notebookutils.notebook.runMultiple(dag)
    except Exception as ex:  # skipped/failed children raise; per-activity results ride on the exception
        results = getattr(ex, "result", None)
        if not isinstance(results, dict):
            raise
    return classify_results(results, [a["name"] for a in dag["activities"]])


def refresh_sql_endpoint():
    ep = next(i for i in rest_list(f"v1/workspaces/{PRES_WS_ID}/items?type=SQLEndpoint")
              if i["displayName"] == "DP_Presentation")
    r = rest.post(f"v1/workspaces/{PRES_WS_ID}/sqlEndpoints/{ep['id']}/refreshMetadata", json={})
    if r.status_code == 202 and r.headers.get("Location"):
        for _ in range(60):
            time.sleep(10)
            s = rest.get(r.headers["Location"])
            if s.status_code == 200 and s.json().get("status") in ("Succeeded", "Failed", None):
                break
    elif r.status_code >= 300:
        raise RuntimeError(f"refreshMetadata {r.status_code} {r.text[:300]}")


def refresh_model(model, workspace):
    last_error = None
    for _attempt in range(2):
        try:
            req = fabric.refresh_dataset(dataset=model, workspace=workspace, refresh_type="full")
            for _ in range(180):
                time.sleep(10)
                st = fabric.get_refresh_execution_details(model, req, workspace=workspace).status
                if st in ("Completed", "Failed", "Cancelled", "Disabled"):
                    break
            if st == "Completed":
                return {"status": "Completed", "error": None}
            last_error = f"status {st}"
        except Exception as ex:
            last_error = f"{type(ex).__name__}: {str(ex)[:300]}"
    return {"status": "Failed", "error": last_error}


# ---------------------------------------------------------------- run --------------------------------
ctx = notebookutils.runtime.context
LAKEHOUSE = ctx.get("defaultLakehouseName")
TIER = {"DP_Staging": "silver", "DP_Presentation": "gold"}[LAKEHOUSE]
ENV = ctx.get("currentWorkspaceName").rsplit(" - ", 1)[1]
PRES_WS_ID = fabric.resolve_workspace_id(f"DP - Presentation - {ENV}")
PRES_LH_ID = fabric.resolve_item_id("DP_Presentation", "Lakehouse", PRES_WS_ID)
LOG_PATH = f"abfss://{PRES_WS_ID}@onelake.dfs.fabric.microsoft.com/{PRES_LH_ID}/Tables/dp_refresh_log"
CONFIG = json.loads(notebookutils.fs.head("Files/config/dp_refresh_dag.json", 20_000_000))
SETTINGS = CONFIG["orchestrator"]
RUN_ID = run_id or str(uuid.uuid4())
DRY = str(dry_run).lower() == "true"
REQUESTED = [n.strip() for n in items.split(",") if n.strip()]
started_utc, started_local = now_utc(), datetime.now(CENTRAL)
summary = {"env": ENV, "mode": mode, "dry_run": DRY, "run_id": RUN_ID, "tier": TIER,
           "started_local": started_local.strftime("%Y-%m-%d %H:%M"), "finished_local": "",
           "bronze_problems": [], "error": None, "items": {}, "models": {}, "tier_seconds": {},
           "affected_reports": [], "plan": None}
upstream = json.loads(upstream_json) if upstream_json else {}
log = []

try:
    if TIER == "silver":
        if already_running():
            raise RuntimeError("another DP refresh started in the last 4 hours is still InProgress")
        if not DRY:
            log_rows([row(row_type="run", name="Pipeline_DP_Refresh", status="InProgress", start_utc=started_utc)])
        if mode == "rerun_failed":
            last = (spark.read.format("delta").load(LOG_PATH)
                    .filter("row_type IN ('item','dataflow') AND status IN ('Failed','Skipped')")
                    .orderBy("end_utc", ascending=False))
            prev = last.select("run_id").limit(1).collect()
            REQUESTED = [r.name for r in last.filter(f"run_id = '{prev[0].run_id}'").select("name").distinct().collect()] if prev else []
        silver = select_items(CONFIG, "silver", mode, started_local, REQUESTED)
        flows = select_items(CONFIG, "staging", mode, started_local, REQUESTED)
        summary["requested"] = REQUESTED
        if DRY:
            summary["plan"] = {"dataflows": [i["name"] for i in flows], "silver": [i["name"] for i in silver]}
        else:
            staging_ws = fabric.resolve_workspace_id(f"DP - Staging - {ENV}")
            jobs = {}
            with ThreadPoolExecutor(max_workers=4) as pool:
                if mode in ("scheduled", "all", "intraday"):
                    jobs["JD_Incremental"] = pool.submit(run_job, JD_WS, JD_INCR, "Pipeline", 3600)
                for f in flows:
                    df_id = fabric.resolve_item_id(f["name"], "Dataflow", staging_ws)
                    jobs[f["name"]] = pool.submit(run_job, staging_ws, df_id, "Refresh", 3600)
            for name, fut in jobs.items():
                res = fut.result()
                if name != "JD_Incremental":
                    summary["items"][name] = {"status": "Succeeded" if res["status"] == "Completed" else "Failed",
                                              "tier": "staging", "error": res["error"]}
            if str(simulate_bronze_failure).lower() == "true":
                summary["bronze_problems"] = ["Simulated Bronze failure (drill)"]
            elif mode in ("scheduled", "all", "intraday"):
                full_run, full_acts = latest_run_and_activities(JD_FULL)
                inc_run, inc_acts = latest_run_and_activities(JD_INCR)
                summary["bronze_problems"] = evaluate_bronze(full_run, full_acts, inc_run, inc_acts, now_utc())
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
    else:  # gold
        summary["items"] = dict(upstream.get("items", {}))
        summary["bronze_problems"] = upstream.get("bronze_problems", [])
        summary["tier_seconds"] = dict(upstream.get("tier_seconds", {}))
        summary["error"] = upstream.get("error")
        REQUESTED = upstream.get("requested", REQUESTED)
        gold = select_items(CONFIG, "gold", mode, started_local, REQUESTED)
        if DRY:
            summary["plan"] = dict(upstream.get("plan") or {}, gold=[i["name"] for i in gold],
                                   models=[r["model"] for r in CONFIG["reports"]])
        elif not summary["bronze_problems"] and not summary["error"]:
            bad_upstream = {n for n, i in summary["items"].items() if i["status"] != "Succeeded"}
            dag, skipped = build_dag(gold, CONFIG, dict(SETTINGS), bad_upstream, inject_failure=inject_failure)
            t0 = time.time()
            results = run_dag(dag) if dag["activities"] else {}
            summary["tier_seconds"]["gold"] = time.time() - t0
            for n, r in results.items():
                summary["items"][n] = dict(r, tier="gold")
            for n, culprit in skipped.items():
                summary["items"][n] = {"status": "Skipped", "tier": "gold", "skipped_because": culprit}
            refresh_sql_endpoint()
            workspace = SETTINGS["reportWorkspace"][ENV]
            t0 = time.time()
            with ThreadPoolExecutor(max_workers=int(SETTINGS["modelRefreshParallelism"])) as pool:
                futures = {r["model"]: pool.submit(refresh_model, r["model"], workspace) for r in CONFIG["reports"]}
            summary["models"] = {m: f.result() for m, f in futures.items()}
            summary["tier_seconds"]["models"] = time.time() - t0
        bad = {n for n, i in summary["items"].items() if i["status"] != "Succeeded"}
        summary["affected_reports"] = affected_reports(CONFIG, bad)
except Exception:
    summary["error"] = traceback.format_exc()[-3000:]

finished_utc = now_utc()
summary["finished_local"] = datetime.now(CENTRAL).strftime("%Y-%m-%d %H:%M")
if TIER == "gold" or summary["error"] or summary["bronze_problems"] or DRY:
    summary.update(compose_summary(summary))
for n, i in summary["items"].items():
    if i.get("tier") == TIER or (TIER == "silver" and i.get("tier") == "staging"):
        log.append(row(row_type="dataflow" if i["tier"] == "staging" else "item", name=n, status=i["status"],
                       error=i.get("error"), skipped_because=i.get("skipped_because"), end_utc=finished_utc))
for m, s in summary["models"].items():
    log.append(row(row_type="model", name=m, status=s["status"], error=s.get("error"), end_utc=finished_utc))
if TIER == "silver" and summary["bronze_problems"]:
    log.append(row(row_type="bronze", name="JD_Bronze", status="Failed", error="; ".join(summary["bronze_problems"])[:1000]))
final = summary.get("status") or ("error" if summary["error"] else "tier_done")
log.append(row(row_type="run", name="Pipeline_DP_Refresh", status=final, start_utc=started_utc, end_utc=finished_utc,
               duration_s=(finished_utc - started_utc).total_seconds(), error=(summary["error"] or "")[:1000] or None))
if not DRY:
    try:
        log_rows(log)
    except Exception:
        summary["log_error"] = traceback.format_exc()[-1000:]
```

- [ ] **Step 2: Parse check:** `python -c "import ast; ast.parse(open('deploy/orchestrator_glue.py', encoding='utf-8').read())"`
  prints nothing. The file isn't importable locally; `pytest` doesn't import it, but Task 5's test parses it.
- [ ] **Step 3:** Commit `deploy/orchestrator_glue.py` with message `orchestrator glue (Fabric-only)`.

---

### Task 5: Render both notebooks from core + glue

**Files:** Create `deploy/render_orchestrator.py`, `deploy/test_render_orchestrator.py`. Generated:
`workspaces/DP - Staging - Dev/Orchestration/Run_DP_Refresh.Notebook/{.platform,notebook-content.py}` and
the same under `DP - Presentation - Dev/Orchestration/`.

- [ ] **Step 1: Failing test**

```python
# deploy/test_render_orchestrator.py
import ast
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).parent))
from render_orchestrator import TARGETS, render  # noqa: E402

REPO = Path(__file__).parent.parent


def test_committed_notebooks_are_current():
    for target in TARGETS:
        path = REPO / target["path"] / "notebook-content.py"
        assert path.read_text(encoding="utf-8") == render(target), \
            f"{path} is stale: run python deploy/render_orchestrator.py"


def test_both_copies_identical_below_metadata():
    a, b = (render(t).split("# MARKDOWN", 1)[1] for t in TARGETS)
    assert a == b


def test_every_code_cell_parses():
    for target in TARGETS:
        for cell in render(target).split("# CELL ********************")[1:]:
            ast.parse(cell.split("# METADATA ********************")[0])
```

- [ ] **Step 2:** Run → FAIL (ModuleNotFoundError).
- [ ] **Step 3: Implement**

```python
# deploy/render_orchestrator.py
"""Render both Run_DP_Refresh notebooks from orchestrator_core.py + orchestrator_glue.py.

Usage: python deploy/render_orchestrator.py   (writes the two notebook-content.py files and, if missing,
their .platform). CI's test_render_orchestrator.py fails when the committed notebooks are stale.
"""
import json
import uuid
from pathlib import Path

DEPLOY = Path(__file__).parent
REPO = DEPLOY.parent
TARGETS = [
    {"path": "workspaces/DP - Staging - Dev/Orchestration/Run_DP_Refresh.Notebook",
     "lakehouse": "876255e0-d462-4697-adc1-4a655f5bb101", "lakehouse_name": "DP_Staging",
     "workspace": "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"},
    {"path": "workspaces/DP - Presentation - Dev/Orchestration/Run_DP_Refresh.Notebook",
     "lakehouse": "966efc8a-16f9-423b-aa43-e368fcd8fb91", "lakehouse_name": "DP_Presentation",
     "workspace": "73fd5443-240e-410a-990a-98827f32c087"},
]
CELL_META = ('# METADATA ********************\n\n# META {\n# META   "language": "python",\n'
             '# META   "language_group": "synapse_pyspark"\n# META }\n')
PARAMETERS = '''mode = "scheduled"
dry_run = "false"
items = ""
run_id = ""
upstream_json = ""
inject_failure = ""
simulate_bronze_failure = "false"
'''
MARKDOWN = '''# # Run_DP_Refresh
# DP refresh orchestrator (one identical copy per lakehouse). GENERATED by
# fabric-workspace-docs/deploy/render_orchestrator.py from orchestrator_core.py + orchestrator_glue.py:
# edit those files and re-render, never this notebook.
# Staging copy: JD Incremental + staging dataflows + Bronze check + Silver. Presentation copy: Gold,
# SQL endpoint metadata refresh, report model refresh, summary. Spec:
# data-projects/docs/superpowers/specs/2026-09-28-dp-refresh-pipeline-redesign-design.md
'''


def _header(t):
    return ("# Fabric notebook source\n\n# METADATA ********************\n\n# META {\n"
            '# META   "kernel_info": {\n# META     "name": "synapse_pyspark"\n# META   },\n'
            '# META   "dependencies": {\n# META     "lakehouse": {\n'
            f'# META       "default_lakehouse": "{t["lakehouse"]}",\n'
            f'# META       "default_lakehouse_name": "{t["lakehouse_name"]}",\n'
            f'# META       "default_lakehouse_workspace_id": "{t["workspace"]}",\n'
            '# META       "known_lakehouses": [\n# META         {\n'
            f'# META           "id": "{t["lakehouse"]}"\n'
            "# META         }\n# META       ]\n# META     }\n# META   }\n# META }\n")


def render(target) -> str:
    core = (DEPLOY / "orchestrator_core.py").read_text(encoding="utf-8")
    glue = (DEPLOY / "orchestrator_glue.py").read_text(encoding="utf-8")
    exit_cell = "notebookutils.notebook.exit(json.dumps(summary, default=str))\n"
    parts = [_header(target), "\n# MARKDOWN ********************\n\n", MARKDOWN,
             "\n# PARAMETERS CELL ********************\n\n", PARAMETERS, "\n", CELL_META]
    for code in (core, glue, exit_cell):
        parts += ["\n# CELL ********************\n\n", code.rstrip("\n") + "\n", "\n", CELL_META]
    return "".join(parts)


def main():
    for t in TARGETS:
        folder = REPO / t["path"]
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "notebook-content.py").write_text(render(t), encoding="utf-8", newline="\n")
        platform = folder / ".platform"
        if not platform.exists():
            platform.write_text(json.dumps({
                "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
                "metadata": {"type": "Notebook", "displayName": "Run_DP_Refresh"},
                "config": {"version": "2.0", "logicalId": str(uuid.uuid4())}}, indent=2), encoding="utf-8", newline="\n")
        print("rendered", folder)


if __name__ == "__main__":
    main()
```

  (`json.dumps(..., indent=2)` output has no trailing newline, as `.platform` requires.)

- [ ] **Step 4:** `python deploy/render_orchestrator.py`, then `cd deploy && python -m pytest -q` → all pass.
  - Add both `Run_DP_Refresh` notebooks to `dp_refresh_dag.json` `excluded` (reason: "orchestrator").
    `dag_check.py` only requires `Build_*` names, so this is documentation. Run `python deploy/dag_check.py` → OK.
  - Also run `python deploy/hygiene_audit.py` → still 0 problems. The orchestrator isn't a config item,
    so it isn't audited.
- [ ] **Step 5:** Commit the renderer, its test, both generated notebook folders and the config (message
  `Render Run_DP_Refresh (Staging + Presentation) from core + glue`). Don't push yet.

---

### Task 6: Deploy the new config file with CI

**Files:** Modify `deploy/deploy_backend.py`.

- [ ] **Step 1:** In `main()`, after the two existing `write_lakehouse_file(...)` calls for
  `dp_backend_scope.json`, add:

```python
    dag = json.loads((REPO_ROOT / "deploy" / "dp_refresh_dag.json").read_text(encoding="utf-8"))
    for tier in ("staging", "presentation"):
        write_lakehouse_file(workspace_id=ids[tier], lakehouse_id=lh_ids[tier],
                             file_path="config/dp_refresh_dag.json", content=dag)
    print(f"Wrote dp_refresh_dag.json to both {environment} tier lakehouses' Files/config/.")
```

  and add `import json` at the top. First read `deploy/lib.py`'s `write_lakehouse_file` to confirm it takes
  a dict `content`. If it expects a string, pass `json.dumps(dag, indent=2)` instead.
- [ ] **Step 2:** `python -m pytest deploy -q` still passes. Commit `deploy/deploy_backend.py` (message
  `CI: deploy dp_refresh_dag.json to the Dev lakehouses`).
- [ ] **Step 3:** Push all commits, then `wait_ci.py` → success. Then run
  `git_sync.py ab15d64d-c7ba-415d-9bcf-7feb1ef9b201` and `git_sync.py 73fd5443-240e-410a-990a-98827f32c087`.
  - Confirm both `Run_DP_Refresh` notebooks exist in each workspace's `Orchestration` folder, and record
    their item IDs from `fab api "workspaces/<ws>/items?type=Notebook"`.
  - Confirm `Files/config/dp_refresh_dag.json` exists in both lakehouses:
    `fab ls "DP - Staging - Dev.Workspace/DP_Staging.Lakehouse/Files/config"` and the Presentation
    equivalent.

---

### Task 7: `Pipeline_DP_Refresh`

**Files:** Create `workspaces/DP - Presentation - Dev/Pipelines/Pipeline_DP_Refresh.DataPipeline/.platform`
(new logicalId, no trailing newline) and `pipeline-content.json`.

- [ ] **Step 1:** Write `pipeline-content.json`. Replace `<SILVER_NB_ID>` and `<GOLD_NB_ID>` with the
  Task 6 item IDs. The activity formats are copied from the working `Pipeline_DP_Daily_Refresh`
  (TridentNotebook, Office365Email).

```json
{
  "properties": {
    "parameters": {
      "mode": {"type": "string", "defaultValue": "scheduled"},
      "dry_run": {"type": "string", "defaultValue": "false"},
      "items": {"type": "string", "defaultValue": ""},
      "inject_failure": {"type": "string", "defaultValue": ""},
      "simulate_bronze_failure": {"type": "string", "defaultValue": "false"}
    },
    "activities": [
      {
        "name": "Run_Silver", "type": "TridentNotebook", "dependsOn": [],
        "policy": {"timeout": "0.06:00:00", "retry": 0, "retryIntervalInSeconds": 30, "secureInput": false, "secureOutput": false},
        "typeProperties": {
          "notebookId": "<SILVER_NB_ID>", "workspaceId": "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201",
          "parameters": {
            "mode": {"value": {"value": "@pipeline().parameters.mode", "type": "Expression"}, "type": "string"},
            "dry_run": {"value": {"value": "@pipeline().parameters.dry_run", "type": "Expression"}, "type": "string"},
            "items": {"value": {"value": "@pipeline().parameters.items", "type": "Expression"}, "type": "string"},
            "simulate_bronze_failure": {"value": {"value": "@pipeline().parameters.simulate_bronze_failure", "type": "Expression"}, "type": "string"},
            "run_id": {"value": {"value": "@pipeline().RunId", "type": "Expression"}, "type": "string"}
          }
        }
      },
      {
        "name": "Run_Gold", "type": "TridentNotebook",
        "dependsOn": [{"activity": "Run_Silver", "dependencyConditions": ["Succeeded"]}],
        "policy": {"timeout": "0.06:00:00", "retry": 0, "retryIntervalInSeconds": 30, "secureInput": false, "secureOutput": false},
        "typeProperties": {
          "notebookId": "<GOLD_NB_ID>", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
          "parameters": {
            "mode": {"value": {"value": "@pipeline().parameters.mode", "type": "Expression"}, "type": "string"},
            "dry_run": {"value": {"value": "@pipeline().parameters.dry_run", "type": "Expression"}, "type": "string"},
            "items": {"value": {"value": "@pipeline().parameters.items", "type": "Expression"}, "type": "string"},
            "inject_failure": {"value": {"value": "@pipeline().parameters.inject_failure", "type": "Expression"}, "type": "string"},
            "run_id": {"value": {"value": "@pipeline().RunId", "type": "Expression"}, "type": "string"},
            "upstream_json": {"value": {"value": "@activity('Run_Silver').output.result.exitValue", "type": "Expression"}, "type": "string"}
          }
        }
      },
      {
        "name": "Email_Summary", "type": "Office365Email",
        "dependsOn": [{"activity": "Run_Gold", "dependencyConditions": ["Succeeded"]}],
        "policy": {"timeout": "0.00:10:00", "retry": 1, "retryIntervalInSeconds": 60, "secureInput": false, "secureOutput": false},
        "externalReferences": {"connection": "97d3696e-b886-4770-9fd0-f4aae4c6a7ed"},
        "typeProperties": {
          "to": "bfox@spitractor.com",
          "subject": "@{json(activity('Run_Gold').output.result.exitValue).subject}",
          "body": "@{json(activity('Run_Gold').output.result.exitValue).html}"
        }
      },
      {
        "name": "If_Alert_Email", "type": "IfCondition",
        "dependsOn": [{"activity": "Run_Gold", "dependencyConditions": ["Succeeded"]}],
        "typeProperties": {
          "expression": {"value": "@bool(json(activity('Run_Gold').output.result.exitValue).alert_email)", "type": "Expression"},
          "ifTrueActivities": [
            {
              "name": "Email_Alert", "type": "Office365Email", "dependsOn": [],
              "policy": {"timeout": "0.00:10:00", "retry": 1, "retryIntervalInSeconds": 60, "secureInput": false, "secureOutput": false},
              "externalReferences": {"connection": "97d3696e-b886-4770-9fd0-f4aae4c6a7ed"},
              "typeProperties": {
                "to": "bfox@spitractor.com", "importance": "High",
                "subject": "@{json(activity('Run_Gold').output.result.exitValue).subject}",
                "body": "@{json(activity('Run_Gold').output.result.exitValue).html}"
              }
            }
          ],
          "ifFalseActivities": []
        }
      },
      {
        "name": "If_Teams", "type": "IfCondition",
        "dependsOn": [{"activity": "Run_Gold", "dependencyConditions": ["Succeeded"]}],
        "typeProperties": {
          "expression": {"value": "@bool(json(activity('Run_Gold').output.result.exitValue).teams)", "type": "Expression"},
          "ifTrueActivities": [],
          "ifFalseActivities": []
        }
      },
      {
        "name": "Email_Silver_Crashed", "type": "Office365Email",
        "dependsOn": [{"activity": "Run_Silver", "dependencyConditions": ["Failed"]}],
        "policy": {"timeout": "0.00:10:00", "retry": 1, "retryIntervalInSeconds": 60, "secureInput": false, "secureOutput": false},
        "externalReferences": {"connection": "97d3696e-b886-4770-9fd0-f4aae4c6a7ed"},
        "typeProperties": {
          "to": "bfox@spitractor.com", "importance": "High",
          "subject": "🔴 [Dev] DP Refresh FAILED – Silver orchestrator crashed",
          "body": "<p>Run_DP_Refresh (DP - Staging) failed before it could report. Error:</p><pre>@{activity('Run_Silver').error.message}</pre><p>Open the pipeline run in the Fabric Monitor for details, fix, then run Pipeline_DP_Refresh again.</p>"
        }
      },
      {
        "name": "Email_Gold_Crashed", "type": "Office365Email",
        "dependsOn": [{"activity": "Run_Gold", "dependencyConditions": ["Failed"]}],
        "policy": {"timeout": "0.00:10:00", "retry": 1, "retryIntervalInSeconds": 60, "secureInput": false, "secureOutput": false},
        "externalReferences": {"connection": "97d3696e-b886-4770-9fd0-f4aae4c6a7ed"},
        "typeProperties": {
          "to": "bfox@spitractor.com", "importance": "High",
          "subject": "🔴 [Dev] DP Refresh FAILED – Gold orchestrator crashed",
          "body": "<p>Run_DP_Refresh (DP - Presentation) failed before it could report. Error:</p><pre>@{activity('Run_Gold').error.message}</pre><p>Silver finished; open the pipeline run in the Fabric Monitor, fix, then run Pipeline_DP_Refresh with mode = rerun_failed.</p>"
        }
      }
    ]
  }
}
```

- [ ] **Step 2:** Validate the JSON (`python -c "import json; json.load(open(...))"`). Commit both files
  (message `Pipeline_DP_Refresh`), push, `wait_ci.py`, `git_sync.py 73fd5443-240e-410a-990a-98827f32c087`.
  Confirm the pipeline appears in the Presentation workspace's `Pipelines` folder. **If Git sync rejects the
  pipeline definition, report the exact error.** Don't guess other formats: the controller will have Brian
  open the pipeline in the UI and save it, which normalises the JSON.

---

### Task 8 (controller + Brian, in the Fabric UI): Teams activities and a visual check

- [ ] **Step 1:** Brian opens `Pipeline_DP_Refresh` in DP - Presentation - Dev and:
  1. **In `If_Teams` → True**, adds a **Teams** activity:
     - Sign in and create the Teams connection.
     - Post to the **Fabric Monitoring** channel.
     - Message: `@{json(activity('Run_Gold').output.result.exitValue).teams_text}`
  2. **Adds a Teams activity after each crash email** (`On completion` of `Email_Silver_Crashed` and of
     `Email_Gold_Crashed`), with messages:
     - `🔴 [Dev] DP Refresh FAILED – Silver orchestrator crashed: @{activity('Run_Silver').error.message}`
     - the same pattern for Gold.
  3. **Checks the two alert emails and the crash emails show Importance = High.** If the `importance`
     field from the JSON didn't survive, sets it in each email activity's settings.
  4. **Saves**, then in **Source control** commits the pipeline.
- [ ] **Step 2 (controller):** `git pull` fabric-workspace-docs and read the committed pipeline JSON, to learn
  the Teams activity format for the record.

---

### Task 9: Dry run, then failure drills

Each run: trigger the pipeline with parameters and wait, using `run_item.py` with jobType `Pipeline`:
`python .../run_item.py 73fd5443-240e-410a-990a-98827f32c087 <PIPELINE_ID> Pipeline 10800 --param mode=… --param …`.
Pipeline parameters go through the same `executionData.parameters` body. After each run, read the log with
a scratchpad DuckDB script over
`abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables/dp_refresh_log`,
and check Brian's inbox/Teams with him (controller).

- [ ] **Step 1: Dry run.** `--param mode=all --param dry_run=true`.
  - **Expected:** the pipeline succeeds, and one summary email arrives: `🧪 [Dev] DP Refresh dry run (all)`,
    listing the dataflows, Silver, Gold (every non-manual item: 2 dataflows / 29 Silver / 59 Gold with
    today's cadences) and 24 models.
  - Compare the counts with `dp_refresh_dag.json`. No `dp_refresh_log` rows, because a dry run doesn't log.
  - **If `activity('Run_Silver').output.result.exitValue` isn't the right expression** (Run_Gold fails on
    `upstream_json`), open the Run_Silver activity output in the Fabric Monitor. Find the exit value's real
    path, fix the 4 expressions in `pipeline-content.json`, and redeploy.
  - **Check the parameters arrived:** the email subject must say `(all)`, and the plan must list Gold items.
    If the pipeline ran with its defaults instead (`scheduled`, not a dry run), then `run_item.py`'s
    notebook-style parameter body (`{"value":…, "type":…}`) doesn't fit pipeline jobs. Re-run from a
    scratchpad script that POSTs `jobs/instances?jobType=Pipeline` with
    `{"executionData": {"parameters": {"mode": "all", "dry_run": "true"}}}` (plain values), and use that
    script for the remaining drills.
- [ ] **Step 2: Gold failure drill.** `--param mode=items --param items=Build_Gold_CustomerList,Build_Gold_CustomerLookup,Build_Gold_EngagedAcres --param inject_failure=Build_Gold_CustomerList`.
  - **Expected:**
    - CustomerList is **Failed** (probe), CustomerLookup is **Skipped** because of CustomerList, and
      EngagedAcres **Succeeded**.
    - 24 models refreshed.
    - Email subject `⚠ [Dev] DP Refresh: 1 failed, 1 skipped` listing the stale reports.
    - A Teams post, and **no** alert email.
    - Log rows: 3 item rows, 24 model rows, and run rows (InProgress plus the final `partial`).
- [ ] **Step 3: rerun_failed.** `--param mode=rerun_failed`.
  - **Expected:** it reruns exactly CustomerList and CustomerLookup (now without injection); both Succeed,
    and the summary is `✅`.
- [ ] **Step 4: Bronze drill.** `--param mode=all --param simulate_bronze_failure=true`.
  - **Expected:** no notebook runs and no model refreshes. The subject is
    `🔴 [Dev] DP Refresh FAILED – JD Bronze problem…` with the runbook line.
  - Both the summary email and the **High-importance alert email** arrive, plus a Teams post.
  - Note that this mode also triggers JD Incremental and the 2 dataflows, which is harmless.
- [ ] **Step 5: Crash path (optional, controller decides).** Temporarily set an invalid `mode` (`--param mode=bogus`).
  - **Expected:** Run_Silver catches the error, so the pipeline still reaches Run_Gold. The error shows as
    status `error`, with an alert email and a Teams post.
  - This proves the error path; the "crashed" emails are only for a notebook that dies outright.

---

### Task 10: Full manual run

- [ ] **Step 1 (controller):** confirm a quiet window with Brian (not 4:15–6:00 AM; about 1–1.5 hours; the
  DP workspaces otherwise idle).
- [ ] **Step 2:** `--param mode=all`.
  - **Expected:** the pipeline succeeds. Every non-manual item is Succeeded, or Failed/Skipped with a real
    reason, and all 24 models are Completed.
  - Record the tier durations from the summary email, and the CU from Capacity Metrics an hour later (the two
    `Run_DP_Refresh` items plus the model refreshes, by hour).
- [ ] **Step 3:** For every Failed item: read its error from the log. **Stop and report** to the controller
  with the error text before changing any notebook. Fixes follow the normal flow and a `rerun_failed` run.
- [ ] **Step 4:** Spot-check 3 reports' row counts against the Phase 1 tuning counts (Customer Anatomy tables):
  same or grown slightly with new data.

---

### Task 11 (controller + Brian): Retire the old DP pipelines and the prototypes

- [ ] **Step 1:** Ask Brian to approve deleting:
  - `Pipeline_DP_Daily_Refresh`, `Pipeline_DP_Monthly_Refresh` and `Pipeline_DP_SemanticModel_Refresh`
    (all paused);
  - `Proto_RunMultiple` in both workspaces, and `Proto_AfterFail`.
  **Keep `Proto_FailProbe`:** drills inject it.
- [ ] **Step 2:** For the approved items: delete their folders in Git, update `excluded` in the config,
  run `dag_check.py` → OK, commit, push, `wait_ci.py`, `git_sync.py` both workspaces.
- [ ] **Step 3:** `dp_backend_scope.json` stays. `deploy_backend.py` (Prod notebook publish) and
  `deploy_reports.py` still read it. Moving those to `dp_refresh_dag.json` belongs to the Prod-promotion
  stage (with fabric-cicd and the Variable Library review). Record that in the results doc.

---

### Task 12 (controller): Docs, then STOP

- [ ] **Step 1:** Write `C:\Users\bfox\Documents\Git-Projects\data-projects\docs\architecture\dp-refresh-phase2-results.md`:
  - what was built;
  - the drill results (each expected-vs-actual);
  - the full run (durations, CU, failures and fixes);
  - how to operate it: parameters, re-run, dry run, reading `dp_refresh_log`, the runbook links;
  - what's left for Prod (fabric-cicd, report workspaces per environment, the 4:15 AM schedule, turning
    off JD Incremental's own schedule).
- [ ] **Step 2:** Update:
  - `docs/architecture/dp-refresh-pipeline-assessment.md`: status header → "Replaced by
    Pipeline_DP_Refresh (Phase 2 results)";
  - `projects/jd-bronze-pipelines/README.md`: note that `Pipeline_DP_Refresh` triggers JD Incremental and
    runs the Bronze check.
  Commit and push.
- [ ] **Step 3: STOP.** Present to Brian. Next is his RP-Dev report validation on fresh data.
