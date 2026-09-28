# DP Refresh Redesign — Phase 0 Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove (or disprove) the `runMultiple` orchestrator design on the Labor Performance chain and
measure its duration and CU against running the same 9 notebooks one session each, so Brian can
choose Option 2 or Option A before Phases 1–3 are planned.

**Architecture:** One prototype orchestrator notebook per DP workspace (identical code; the tier is
detected from the default lakehouse). Each runs its tier's Labor Performance notebooks through
`notebookutils.notebook.runMultiple` in one shared Spark session. A baseline script runs the same 9
notebooks as separate jobs (3 at a time, like today's pipeline ForEach). A measurement script
collects job times and Spark session durations; CU comes from the Capacity Metrics model. **Stop
at the end for Brian's decision.**

**Tech Stack:** Fabric notebooks (PySpark, `notebookutils`), Fabric REST via `fab api`, Python 3.13
helper scripts in `data-projects/tools/dp-migration/`, pytest, DuckDB (not needed here), Power BI
executeQueries (Capacity Metrics model).

**Spec:** `docs/superpowers/specs/2026-09-28-dp-refresh-pipeline-redesign-design.md` (see the
"Revision … one orchestrator per lakehouse" note and §7 Phase 0).

---

## Ground rules (read before any task)

- **Two repos.** `data-projects` (this repo: tools, docs) and `fabric-workspace-docs` (the Fabric
  Git mirror: notebooks). Both on branch `dev`. Never commit to `main`.
- **Single writer for Dev workspaces.** Notebook code reaches Fabric only by:
  push `fabric-workspace-docs` → `python tools/dp-migration/wait_ci.py` →
  `python tools/dp-migration/git_sync.py <workspaceId>` → run. **Never `fab import`.** If
  `git_sync.py` refuses (item changed on both sides), stop and report.
- **New `.platform` files have no trailing newline.**
- The Bash tool's hooks sometimes block commands falsely ("printenv", "az token" messages). Put the
  command in a `.py`/`.sh` file in the session scratchpad and run that instead.
- **Never set `useRootDefaultLakehouse`.** It would make Silver notebooks write into DP_Presentation.
- After any Gold notebook runs (they VACUUM), refresh the SQL endpoint metadata:
  `fab api -X post "workspaces/73fd5443-240e-410a-990a-98827f32c087/sqlEndpoints/18effb0e-7bc2-47a1-854c-f4f2e8129145/refreshMetadata"`
- These runs rebuild real Dev tables with current data. That's harmless (it's the normal refresh), but
  **don't run anything during 4:15–6:00 AM** and don't run other DP notebooks by hand on the
  measurement day, or the CU numbers get polluted.

| Thing | ID / value |
|---|---|
| DP - Staging - Dev workspace | `ab15d64d-c7ba-415d-9bcf-7feb1ef9b201` (lakehouse DP_Staging `876255e0-d462-4697-adc1-4a655f5bb101`) |
| DP - Presentation - Dev workspace | `73fd5443-240e-410a-990a-98827f32c087` (lakehouse DP_Presentation `966efc8a-16f9-423b-aa43-e368fcd8fb91`) |
| Capacity Metrics model | workspace `412a3d0a-73b6-4314-8134-c65c89209fd6`, dataset `235b264c-203b-4425-9686-94589a67127a` |
| Silver notebooks (Staging) | `Build_Silver_WkMechFl`, `Build_Silver_Contact`, `Build_Silver_WkMechAdj`, `Build_Silver_WkMechWk`, `Build_Silver_WkOthSub` (no dependencies among them) |
| Gold notebooks (Presentation) | `Build_Gold_TechnicianCodeNames` (reads Silver_WkMechFl, Silver_Contact), `Build_Gold_TechnicianAttendance` (Silver_WkMechAdj), `Build_Gold_TechnicianPunchedTime` (Silver_WkMechWk, Silver_WkMechAdj), `Build_Gold_TechnicianEfficiency` (Silver_WkMechWk, Silver_WkOthSub). No Gold→Gold dependencies |

## File structure

| File | Repo | Responsibility |
|---|---|---|
| `tools/dp-migration/run_item.py` (modify) | data-projects | Add `--param name=value` notebook parameters to job submission |
| `tools/dp-migration/test_run_item.py` (create) | data-projects | Unit test for the parameter body builder |
| `tools/dp-migration/proto_baseline.py` (create) | data-projects | Run the 9 notebooks one job each, 3 at a time, Silver before Gold; record times |
| `tools/dp-migration/proto_measure.py` (create) | data-projects | For a UTC window: job instances + Livy (Spark) sessions for the 9 notebooks and 2 orchestrators |
| `tools/dp-migration/proto_counts.py` (create) | data-projects | Row counts of the 9 output tables; fails if a Silver table appears in DP_Presentation |
| `workspaces/DP - Staging - Dev/Orchestration/Proto_RunMultiple.Notebook/` (create) | fabric-workspace-docs | Prototype orchestrator, Staging copy |
| `workspaces/DP - Presentation - Dev/Orchestration/Proto_RunMultiple.Notebook/` (create) | fabric-workspace-docs | Prototype orchestrator, Presentation copy (identical code) |
| `workspaces/DP - Presentation - Dev/Orchestration/Proto_FailProbe.Notebook/` (create) | fabric-workspace-docs | Always fails; used to test retry and skip-dependents |
| `workspaces/DP - Presentation - Dev/Orchestration/Proto_AfterFail.Notebook/` (create) | fabric-workspace-docs | Depends on FailProbe in the failure drill; must never run |
| `docs/architecture/dp-refresh-prototype-results.md` (create) | data-projects | Results + recommendation for Brian |

---

### Task 1: Pre-flight check of the 9 notebooks for shared-session hazards

In `runMultiple`, all children share one Spark session, so a `spark.conf.set` in one child affects the
others, and `%%configure` is not allowed in reference runs.

**Files:** none changed (read-only check).

- [ ] **Step 1: List every `spark.conf.set`, `%%configure` and `useRootDefaultLakehouse` in the 9 notebooks**

Use the Grep tool (not bash grep) on
`C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs\workspaces` with pattern
`spark\.conf\.set|%%configure|useRootDefaultLakehouse` and glob
`**/{Build_Silver_WkMechFl,Build_Silver_Contact,Build_Silver_WkMechAdj,Build_Silver_WkMechWk,Build_Silver_WkOthSub,Build_Gold_TechnicianCodeNames,Build_Gold_TechnicianAttendance,Build_Gold_TechnicianPunchedTime,Build_Gold_TechnicianEfficiency}.Notebook/notebook-content.py`, output mode content.

Expected (checked while planning): only these settings, all compatible when shared:
`spark.sql.parquet.datetimeRebaseModeInRead/InWrite = CORRECTED` (Silver),
`spark.sql.session.timeZone = UTC` and
`spark.databricks.delta.retentionDurationCheck.enabled = false` (Gold). No `%%configure`.

- [ ] **Step 2: Confirm each notebook's default lakehouse matches its workspace**

Grep the same glob for `"default_lakehouse_name"`. Expected: the 5 Silver = `DP_Staging`, the
4 Gold = `DP_Presentation`. **If anything else appears (a conflicting setting, `%%configure`, a
different lakehouse), stop and report to the controller**; the prototype design depends on it.

---

### Task 2: `run_item.py` accepts notebook parameters

The prototype orchestrator is run with parameters (`failure_drill`, `concurrency`), and the Fabric
job API takes them as `executionData.parameters`.

**Files:**
- Modify: `C:\Users\bfox\Documents\Git-Projects\data-projects\tools\dp-migration\run_item.py`
- Create: `C:\Users\bfox\Documents\Git-Projects\data-projects\tools\dp-migration\test_run_item.py`

- [ ] **Step 1: Write the failing test**

```python
# tools/dp-migration/test_run_item.py
import pytest

from run_item import build_body


def test_no_params_gives_no_body():
    assert build_body([]) is None


def test_params_become_execution_data():
    body = build_body(["failure_drill=true", "concurrency=4", "label=proto a"])
    assert body == {"executionData": {"parameters": {
        "failure_drill": {"value": "true", "type": "string"},
        "concurrency": {"value": "4", "type": "string"},
        "label": {"value": "proto a", "type": "string"},
    }}}


def test_value_may_contain_equals():
    body = build_body(["expr=a=b"])
    assert body["executionData"]["parameters"]["expr"]["value"] == "a=b"


def test_missing_equals_is_rejected():
    with pytest.raises(ValueError):
        build_body(["justaname"])
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd C:/Users/bfox/Documents/Git-Projects/data-projects/tools/dp-migration && python -m pytest test_run_item.py -v`
Expected: FAIL with `ImportError: cannot import name 'build_body'`.

- [ ] **Step 3: Implement `build_body` and the `--param` option**

In `run_item.py`, replace the usage docstring, `fab_api`, and the start of `main()` up to and including
the submit call with the following. The polling loop after the submit stays exactly as it is.

```python
"""Run a Fabric item job by ID and wait for it to finish.

Usage: python run_item.py <workspaceId> <itemId> <jobType> [timeoutSeconds] [--param name=value ...]
  jobType: RunNotebook (notebooks) | Refresh (Dataflow Gen2)
  --param: notebook parameter (string), repeatable; overrides the notebook's parameter cell.
Exit codes: 0 completed, 1 failed/submit error, 2 timeout, 3 already running, 4 ambiguous.
"""
import json
import os
import subprocess
import sys
import tempfile
import time

os.environ["PATH"] = os.path.expanduser("~/.local/bin") + os.pathsep + os.environ["PATH"]
os.environ["PYTHONIOENCODING"] = "utf-8"
TERMINAL = {"Completed", "Failed", "Cancelled", "Deduped"}
NON_TERMINAL = {"NotStarted", "InProgress"}


def build_body(params):
    """['a=1', 'b=x'] -> Fabric job executionData body, or None when there are no params."""
    if not params:
        return None
    parsed = {}
    for p in params:
        if "=" not in p:
            raise ValueError(f"--param needs name=value, got {p!r}")
        name, value = p.split("=", 1)
        parsed[name] = {"value": value, "type": "string"}
    return {"executionData": {"parameters": parsed}}


def fab_api(path, method=None, body=None):
    cmd = ["fab", "api", path] + (["-X", method] if method else [])
    tmp = None
    if body is not None:
        tmp = tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8")
        json.dump(body, tmp)
        tmp.close()
        cmd += ["-i", tmp.name]
    out = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8").stdout
    if tmp:
        os.unlink(tmp.name)
    start = out.find("{")
    return json.loads(out[start:]) if start >= 0 else {"raw": out[-800:]}
```

Keep `list_instances` unchanged. Replace the first lines of `main()` (argument parsing through the
submit) with:

```python
def main():
    args = sys.argv[1:]
    params = []
    while "--param" in args:
        i = args.index("--param")
        params.append(args[i + 1])
        del args[i:i + 2]
    ws, item, job_type = args[0:3]
    timeout = int(args[3]) if len(args) > 3 else 1800

    existing = list_instances(ws, item)
    for inst in existing:
        if inst.get("status") in NON_TERMINAL:
            print("already running:", json.dumps(inst, indent=1))
            sys.exit(3)
    existing_ids = {i["id"] for i in existing}

    r = fab_api(f"workspaces/{ws}/items/{item}/jobs/instances?jobType={job_type}", "post", build_body(params))
    print("submit status:", r.get("status_code"))
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd C:/Users/bfox/Documents/Git-Projects/data-projects/tools/dp-migration && python -m pytest test_run_item.py -v`
Expected: 4 passed.

- [ ] **Step 5: Commit (data-projects)**

```bash
cd C:/Users/bfox/Documents/Git-Projects/data-projects
git add tools/dp-migration/run_item.py tools/dp-migration/test_run_item.py
git commit -m "run_item.py: support notebook parameters (--param name=value)"
```
End the message with the Co-Authored-By line from the session's attribution reminder.

---

### Task 3: Create the prototype notebooks (4 folders) in fabric-workspace-docs

**Files (all in `C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs\workspaces\`):**
- Create: `DP - Staging - Dev/Orchestration/Proto_RunMultiple.Notebook/.platform` and `notebook-content.py`
- Create: `DP - Presentation - Dev/Orchestration/Proto_RunMultiple.Notebook/.platform` and `notebook-content.py`
- Create: `DP - Presentation - Dev/Orchestration/Proto_FailProbe.Notebook/.platform` and `notebook-content.py`
- Create: `DP - Presentation - Dev/Orchestration/Proto_AfterFail.Notebook/.platform` and `notebook-content.py`

- [ ] **Step 1: Generate 4 new logicalIds**

Run: `python -c "import uuid; [print(uuid.uuid4()) for _ in range(4)]"`
Use one per `.platform` below.

- [ ] **Step 2: Write the 4 `.platform` files (no trailing newline)**

Template (replace `<NAME>` and `<GUID>`); write with the Write tool and make sure the file ends right
after the final `}` with no newline:

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "<NAME>"
  },
  "config": {
    "version": "2.0",
    "logicalId": "<GUID>"
  }
}
```

Names: `Proto_RunMultiple` (twice, different GUIDs), `Proto_FailProbe`, `Proto_AfterFail`.

- [ ] **Step 3: Write the Staging `Proto_RunMultiple/notebook-content.py`**

```python
# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "876255e0-d462-4697-adc1-4a655f5bb101",
# META       "default_lakehouse_name": "DP_Staging",
# META       "default_lakehouse_workspace_id": "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201",
# META       "known_lakehouses": [
# META         {
# META           "id": "876255e0-d462-4697-adc1-4a655f5bb101"
# META         }
# META       ]
# META     }
# META   }
# META }

# MARKDOWN ********************

# # Proto_RunMultiple
# Phase 0 prototype of the DP refresh orchestrator (spec: data-projects
# docs/superpowers/specs/2026-09-28-dp-refresh-pipeline-redesign-design.md).
# Identical code in DP - Staging and DP - Presentation; the tier comes from the default lakehouse.
# Runs the Labor Performance chain for this tier with notebookutils.notebook.runMultiple.

# PARAMETERS CELL ********************

concurrency = "4"
failure_drill = "false"
run_label = "proto"

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import json
import time
from datetime import datetime, timezone

from notebookutils.common.exceptions import RunMultipleFailedException

ctx = notebookutils.runtime.context
lakehouse = ctx.get("defaultLakehouseName")
print("orchestrator:", ctx.get("currentNotebookName"), "| workspace:", ctx.get("currentWorkspaceName"),
      "| default lakehouse:", lakehouse)

CHAINS = {
    "DP_Staging": [
        {"name": "Build_Silver_WkMechFl"},
        {"name": "Build_Silver_Contact"},
        {"name": "Build_Silver_WkMechAdj"},
        {"name": "Build_Silver_WkMechWk"},
        {"name": "Build_Silver_WkOthSub"},
    ],
    "DP_Presentation": [
        {"name": "Build_Gold_TechnicianCodeNames"},
        {"name": "Build_Gold_TechnicianAttendance"},
        {"name": "Build_Gold_TechnicianPunchedTime"},
        {"name": "Build_Gold_TechnicianEfficiency"},
    ],
}
FAILURE_DRILL = [
    {"name": "Proto_FailProbe", "retry": 1},
    {"name": "Proto_AfterFail", "dependsOn": ["Proto_FailProbe"]},
    {"name": "Build_Gold_TechnicianAttendance"},
]

if lakehouse not in CHAINS:
    raise ValueError(f"Unexpected default lakehouse {lakehouse!r}; refusing to run")
if failure_drill.lower() == "true":
    if lakehouse != "DP_Presentation":
        raise ValueError("failure_drill only runs in the Presentation copy")
    items = FAILURE_DRILL
else:
    items = CHAINS[lakehouse]

dag = {
    "activities": [
        {
            "name": i["name"],
            "path": i["name"],
            "timeoutPerCellInSeconds": 1800,
            "retry": i.get("retry", 2),
            "retryIntervalInSeconds": 30,
            "dependencies": i.get("dependsOn", []),
        }
        for i in items
    ],
    "concurrency": int(concurrency),
    "timeoutInSeconds": 7200,
}
notebookutils.notebook.validateDAG(dag)
print("DAG:", json.dumps(dag, indent=1))

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

started = datetime.now(timezone.utc)
t0 = time.time()
try:
    results = notebookutils.notebook.runMultiple(dag)
    raised = False
except RunMultipleFailedException as ex:
    results = ex.result
    raised = True
wall = round(time.time() - t0, 1)

summary = {
    "label": run_label,
    "lakehouse": lakehouse,
    "failure_drill": failure_drill,
    "concurrency": int(concurrency),
    "started_utc": started.isoformat(),
    "wall_seconds": wall,
    "raised": raised,
    "activities_in_dag": [i["name"] for i in items],
    "results": {
        name: {
            "ok": r.get("exception") is None,
            "error": str(r.get("exception"))[:500] if r.get("exception") is not None else None,
            "exitVal": r.get("exitVal"),
            "raw_keys": sorted(r.keys()),
        }
        for name, r in results.items()
    },
}
print(json.dumps(summary, indent=1))
notebookutils.fs.put(f"Files/orchestration_proto/{run_label}.json", json.dumps(summary, indent=1), True)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

notebookutils.notebook.exit(json.dumps({"wall_seconds": wall, "raised": raised}))

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

The exit call is in its own cell, outside any `try`, because Microsoft's docs say `exit()` inside
`try/except` doesn't take effect.

- [ ] **Step 4: Write the Presentation `Proto_RunMultiple/notebook-content.py`**

Identical to Step 3 except the first `# META` block uses the Presentation lakehouse:

```
# META       "default_lakehouse": "966efc8a-16f9-423b-aa43-e368fcd8fb91",
# META       "default_lakehouse_name": "DP_Presentation",
# META       "default_lakehouse_workspace_id": "73fd5443-240e-410a-990a-98827f32c087",
# META       "known_lakehouses": [
# META         {
# META           "id": "966efc8a-16f9-423b-aa43-e368fcd8fb91"
# META         }
# META       ]
```

Check they're identical below the first META block:
`python -c "a=open(r'<staging path>',encoding='utf-8').read().split('# MARKDOWN',1)[1]; b=open(r'<presentation path>',encoding='utf-8').read().split('# MARKDOWN',1)[1]; print(a==b)"`
Expected: `True`.

- [ ] **Step 5: Write `Proto_FailProbe/notebook-content.py`**

```python
# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "966efc8a-16f9-423b-aa43-e368fcd8fb91",
# META       "default_lakehouse_name": "DP_Presentation",
# META       "default_lakehouse_workspace_id": "73fd5443-240e-410a-990a-98827f32c087",
# META       "known_lakehouses": [
# META         {
# META           "id": "966efc8a-16f9-423b-aa43-e368fcd8fb91"
# META         }
# META       ]
# META     }
# META   }
# META }

# CELL ********************

# Proto_FailProbe: always fails. Used only by Proto_RunMultiple's failure drill to prove that
# retries happen and that dependents are skipped.
raise RuntimeError("Proto_FailProbe: deliberate failure for the orchestrator failure drill")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 6: Write `Proto_AfterFail/notebook-content.py`**

```python
# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "966efc8a-16f9-423b-aa43-e368fcd8fb91",
# META       "default_lakehouse_name": "DP_Presentation",
# META       "default_lakehouse_workspace_id": "73fd5443-240e-410a-990a-98827f32c087",
# META       "known_lakehouses": [
# META         {
# META           "id": "966efc8a-16f9-423b-aa43-e368fcd8fb91"
# META         }
# META       ]
# META     }
# META   }
# META }

# CELL ********************

# Proto_AfterFail: depends on Proto_FailProbe in the failure drill, so it must never run.
# If it runs, the file below appears and the drill fails.
notebookutils.fs.put("Files/orchestration_proto/AFTERFAIL_RAN.txt", "Proto_AfterFail ran - dependency skip did NOT work", True)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 7: Commit and push (fabric-workspace-docs)**

```bash
cd C:/Users/bfox/Documents/Git-Projects/fabric-workspace-docs
git add "workspaces/DP - Staging - Dev/Orchestration" "workspaces/DP - Presentation - Dev/Orchestration"
git commit -m "Phase 0: prototype runMultiple orchestrator + failure-drill probes"
git push origin dev
```
End the message with the Co-Authored-By line.

- [ ] **Step 8: Wait for CI, then Git-sync both workspaces**

```bash
T=C:/Users/bfox/Documents/Git-Projects/data-projects/tools/dp-migration
python "$T/wait_ci.py" && python "$T/git_sync.py" ab15d64d-c7ba-415d-9bcf-7feb1ef9b201 && python "$T/git_sync.py" 73fd5443-240e-410a-990a-98827f32c087
```
Expected: CI succeeds; both syncs exit 0. Then confirm the items exist and are in the `Orchestration`
folder:
`fab ls "DP - Staging - Dev.Workspace/Orchestration.Folder"` and
`fab ls "DP - Presentation - Dev.Workspace/Orchestration.Folder"` (expected: `Proto_RunMultiple.Notebook`;
plus the two probes in Presentation). If `fab ls` doesn't accept folder paths, use
`python tools/dp-migration/folder_check.py` or list `workspaces/{id}/items?type=Notebook` and check `folderId`.

---

### Task 4: `proto_measure.py` — job times and Spark sessions for a window

**Files:**
- Create: `C:\Users\bfox\Documents\Git-Projects\data-projects\tools\dp-migration\proto_measure.py`

- [ ] **Step 1: Write the script**

```python
"""Phase 0 measurement: jobs and Spark (Livy) sessions for the prototype notebooks in a UTC window.

Usage: python proto_measure.py <startUtcISO> <endUtcISO>
Prints, per notebook: job instances started in the window (status, start, end, seconds) and its Livy
sessions in the window (state, running seconds). Then totals: session count, summed session running
seconds, and wall clock (first start -> last end).
"""
import json
import os
import subprocess
import sys
from datetime import datetime

sys.stdout.reconfigure(encoding="utf-8")
os.environ["PATH"] = os.path.expanduser("~/.local/bin") + os.pathsep + os.environ["PATH"]
os.environ["PYTHONIOENCODING"] = "utf-8"

STAGING = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
PRESENTATION = "73fd5443-240e-410a-990a-98827f32c087"
NOTEBOOKS = {
    STAGING: ["Build_Silver_WkMechFl", "Build_Silver_Contact", "Build_Silver_WkMechAdj",
              "Build_Silver_WkMechWk", "Build_Silver_WkOthSub", "Proto_RunMultiple"],
    PRESENTATION: ["Build_Gold_TechnicianCodeNames", "Build_Gold_TechnicianAttendance",
                   "Build_Gold_TechnicianPunchedTime", "Build_Gold_TechnicianEfficiency",
                   "Proto_RunMultiple", "Proto_FailProbe", "Proto_AfterFail"],
}


def api(path):
    out = subprocess.run(["fab", "api", path], capture_output=True, text=True, encoding="utf-8").stdout
    i = out.find("{")
    return json.loads(out[i:]).get("text", {}) if i >= 0 else {}


def ts(s):
    """Naive UTC datetime from Fabric's timestamps ('...Z', '+00:00', or 7 fractional digits)."""
    if not s:
        return None
    return datetime.fromisoformat(s.rstrip("Z").split("+")[0][:26])


def seconds(a, b):
    return round((ts(b) - ts(a)).total_seconds(), 1) if a and b else None


def duration_seconds(d):
    """Livy durations come as {'value': n, 'timeUnit': 'Seconds'|'Minutes'|...}."""
    if not isinstance(d, dict):
        return None
    mult = {"Seconds": 1, "Minutes": 60, "Hours": 3600, "Milliseconds": 0.001}.get(d.get("timeUnit"), None)
    return round(d["value"] * mult, 1) if mult is not None and d.get("value") is not None else None


def main():
    start, end = sys.argv[1], sys.argv[2]
    total_sessions, total_running, starts, ends = 0, 0.0, [], []
    for ws, names in NOTEBOOKS.items():
        items = {i["displayName"]: i["id"] for i in api(f"workspaces/{ws}/items?type=Notebook").get("value", [])}
        for name in names:
            nid = items.get(name)
            if not nid:
                print(f"{name}: NOT FOUND in workspace {ws}")
                continue
            jobs = [j for j in api(f"workspaces/{ws}/items/{nid}/jobs/instances").get("value", [])
                    if start <= (j.get("startTimeUtc") or "") <= end]
            sessions = [s for s in api(f"workspaces/{ws}/notebooks/{nid}/livySessions").get("value", [])
                        if start <= (s.get("submittedDateTime") or "") <= end]
            print(f"\n{name} ({'staging' if ws == STAGING else 'presentation'})")
            for j in jobs:
                print(f"  job {j['status']:10s} {j.get('startTimeUtc')} -> {j.get('endTimeUtc')}"
                      f"  {seconds(j.get('startTimeUtc'), j.get('endTimeUtc'))}s")
                starts.append(j.get("startTimeUtc"))
                if j.get("endTimeUtc"):
                    ends.append(j["endTimeUtc"])
            for s in sessions:
                run = duration_seconds(s.get("runningDuration"))
                print(f"  spark session {s.get('state')}  running {run}s  queued "
                      f"{duration_seconds(s.get('queuedDuration'))}s  keys={sorted(s.keys())}")
                total_sessions += 1
                total_running += run or 0
    print("\nTOTALS")
    print(f"  spark sessions: {total_sessions}")
    print(f"  summed session running seconds: {round(total_running, 1)}")
    if starts and ends:
        print(f"  wall clock: {min(starts)} -> {max(ends)} = {seconds(min(starts), max(ends))}s")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Smoke-test it against a window with known past runs**

Run: `python C:/Users/bfox/Documents/Git-Projects/data-projects/tools/dp-migration/proto_measure.py 2026-09-24T00:00:00 2026-09-25T00:00:00`
(Labor Performance notebooks were run by hand on 09-24.)
Expected: each of the 9 Build_* notebooks prints (jobs may be listed), and Livy session lines print
their `keys=` list. **If the `livySessions` call returns nothing for notebooks that did run, report the
raw response** (the endpoint path may differ); fix the path from the response or the Fabric REST docs
("Notebook - List Livy Sessions") before continuing.

- [ ] **Step 3: Write `tools/dp-migration/proto_counts.py`** (row counts + stray-table check)

```python
"""Phase 0 correctness check: row counts of the 9 output tables, and no Silver table in DP_Presentation.

Usage: python proto_counts.py
"""
import sys

import duckdb

sys.stdout.reconfigure(encoding="utf-8")
STAGING = "abfss://ab15d64d-c7ba-415d-9bcf-7feb1ef9b201@onelake.dfs.fabric.microsoft.com/876255e0-d462-4697-adc1-4a655f5bb101/Tables/"
PRESENTATION = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables/"
SILVER = ["Silver_WkMechFl", "Silver_Contact", "Silver_WkMechAdj", "Silver_WkMechWk", "Silver_WkOthSub"]
GOLD = ["dim_Technician_Code_Names", "TechnicianAttendance", "TechnicianPunchedTime", "TechnicianEfficiency"]

con = duckdb.connect()
con.sql("SET TimeZone='UTC'; INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.sql("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
for root, tables in ((STAGING, SILVER), (PRESENTATION, GOLD)):
    for t in tables:
        n = con.sql(f"SELECT count(*) FROM delta_scan('{root}{t}')").fetchone()[0]
        print(f"{t:28s} {n:>12,}")
stray = []
for t in SILVER:
    try:
        con.sql(f"SELECT 1 FROM delta_scan('{PRESENTATION}{t}') LIMIT 1").fetchall()
        stray.append(t)
    except duckdb.Error:
        pass
print("stray Silver tables in DP_Presentation:", stray or "none")
sys.exit(1 if stray else 0)
```

Run it once now: `python C:/Users/bfox/Documents/Git-Projects/data-projects/tools/dp-migration/proto_counts.py`
Expected: 9 counts > 0 and `stray ... none` (exit 0).

- [ ] **Step 4: Commit (data-projects)**

```bash
cd C:/Users/bfox/Documents/Git-Projects/data-projects
git add tools/dp-migration/proto_measure.py tools/dp-migration/proto_counts.py
git commit -m "Phase 0: add proto_measure.py and proto_counts.py"
```

---

### Task 5: `proto_baseline.py` — the 9 notebooks the current way

Today's pipeline runs each notebook as its own job, 3 at a time, Silver before Gold.

**Files:**
- Create: `C:\Users\bfox\Documents\Git-Projects\data-projects\tools\dp-migration\proto_baseline.py`

- [ ] **Step 1: Write the script**

```python
"""Phase 0 baseline: run the Labor Performance chain one job per notebook, 3 at a time
(like today's pipeline ForEach batchCount 3), all Silver before any Gold.

Usage: python proto_baseline.py
Prints the UTC window to pass to proto_measure.py. Exits 1 if any notebook failed.
"""
import json
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone

sys.stdout.reconfigure(encoding="utf-8")
os.environ["PATH"] = os.path.expanduser("~/.local/bin") + os.pathsep + os.environ["PATH"]
os.environ["PYTHONIOENCODING"] = "utf-8"
HERE = os.path.dirname(os.path.abspath(__file__))
STAGING = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
PRESENTATION = "73fd5443-240e-410a-990a-98827f32c087"
SILVER = ["Build_Silver_WkMechFl", "Build_Silver_Contact", "Build_Silver_WkMechAdj",
          "Build_Silver_WkMechWk", "Build_Silver_WkOthSub"]
GOLD = ["Build_Gold_TechnicianCodeNames", "Build_Gold_TechnicianAttendance",
        "Build_Gold_TechnicianPunchedTime", "Build_Gold_TechnicianEfficiency"]


def ids(ws):
    out = subprocess.run(["fab", "api", f"workspaces/{ws}/items?type=Notebook"],
                         capture_output=True, text=True, encoding="utf-8").stdout
    return {i["displayName"]: i["id"] for i in json.loads(out[out.find("{"):])["text"]["value"]}


def run(ws, nid, name):
    r = subprocess.run([sys.executable, os.path.join(HERE, "run_item.py"), ws, nid, "RunNotebook", "3600"],
                       capture_output=True, text=True, encoding="utf-8")
    print(f"{name}: exit {r.returncode}")
    return r.returncode


def main():
    start = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")
    codes = []
    for ws, names in ((STAGING, SILVER), (PRESENTATION, GOLD)):
        lookup = ids(ws)
        missing = [n for n in names if n not in lookup]
        if missing:
            sys.exit(f"not found: {missing}")
        with ThreadPoolExecutor(max_workers=3) as pool:
            codes += list(pool.map(lambda n: run(ws, lookup[n], n), names))
    end = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")
    print(f"\nWINDOW {start} {end}")
    sys.exit(0 if all(c == 0 for c in codes) else 1)


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Commit (data-projects)**

```bash
cd C:/Users/bfox/Documents/Git-Projects/data-projects
git add tools/dp-migration/proto_baseline.py
git commit -m "Phase 0: add proto_baseline.py (one job per notebook, 3 at a time)"
```

---

### Task 6: Run the baseline

- [ ] **Step 1: Confirm nothing else is running** in either DP workspace (no manual runs by Brian,
  not 4:15–6:00 AM). Ask the controller to confirm with Brian if unsure.

- [ ] **Step 2: Run it**

Run: `python C:/Users/bfox/Documents/Git-Projects/data-projects/tools/dp-migration/proto_baseline.py`
(long-running: use `run_in_background` and wait for the notification.)
Expected: 9 lines `exit 0` and a `WINDOW <start> <end>` line. Record the window.
If any notebook fails, stop and report the failing notebook and its `failureReason`; don't continue
with a broken baseline.

- [ ] **Step 3: Refresh the SQL endpoint metadata** (the Gold notebooks VACUUMed):

`fab api -X post "workspaces/73fd5443-240e-410a-990a-98827f32c087/sqlEndpoints/18effb0e-7bc2-47a1-854c-f4f2e8129145/refreshMetadata"`

- [ ] **Step 4: Measure**

Run: `python C:/Users/bfox/Documents/Git-Projects/data-projects/tools/dp-migration/proto_measure.py <start> <end>`
Record: per-notebook job seconds, spark session count (expected 9), summed session running
seconds, wall clock.

- [ ] **Step 5: Record the baseline row counts**

Run: `python C:/Users/bfox/Documents/Git-Projects/data-projects/tools/dp-migration/proto_counts.py`
Record the 9 counts (the prototype's are compared against these).

---

### Task 7: Run the prototype (happy path)

Wait at least 15 minutes after the baseline ends so the two runs are separable in Capacity Metrics.

- [ ] **Step 1: Run the Staging copy (Silver)**

Get the IDs: `fab api "workspaces/ab15d64d-c7ba-415d-9bcf-7feb1ef9b201/items?type=Notebook"` and
`fab api "workspaces/73fd5443-240e-410a-990a-98827f32c087/items?type=Notebook"` → note each
workspace's `Proto_RunMultiple` id (and `Proto_FailProbe`/`Proto_AfterFail` in Presentation).

Record the UTC start time, then:
`python C:/Users/bfox/Documents/Git-Projects/data-projects/tools/dp-migration/run_item.py ab15d64d-c7ba-415d-9bcf-7feb1ef9b201 <stagingProtoId> RunNotebook 3600 --param run_label=happy_silver --param concurrency=4`
Expected: exit 0.

- [ ] **Step 2: Run the Presentation copy (Gold)**

`python C:/Users/bfox/Documents/Git-Projects/data-projects/tools/dp-migration/run_item.py 73fd5443-240e-410a-990a-98827f32c087 <presentationProtoId> RunNotebook 3600 --param run_label=happy_gold --param concurrency=4`
Expected: exit 0. Record the UTC end time. Refresh the SQL endpoint metadata (command in Task 6
Step 3).

- [ ] **Step 3: Read the two summaries**

`fab cat "DP - Staging - Dev.Workspace/DP_Staging.Lakehouse/Files/orchestration_proto/happy_silver.json"`
`fab cat "DP - Presentation - Dev.Workspace/DP_Presentation.Lakehouse/Files/orchestration_proto/happy_gold.json"`
Expected: `raised: false`; every activity `ok: true`; `wall_seconds` recorded. If `fab cat` isn't
available, read the file through OneLake with DuckDB `read_json` using the same abfss root as
`tools/dp-migration/jd_bronze_check.py` (workspace/lakehouse IDs from the ground-rules table) and
path `Files/orchestration_proto/<label>.json`.

- [ ] **Step 4: Measure**

`python .../proto_measure.py <start> <end>` for the prototype window. Expected: **2** Spark sessions
(one per orchestrator), no separate sessions for the 9 children. Record the summed session running
seconds and the wall clock.

- [ ] **Step 5: Confirm the data landed in the right lakehouses**

Run: `python C:/Users/bfox/Documents/Git-Projects/data-projects/tools/dp-migration/proto_counts.py`
Expected: exit 0 (no stray Silver tables in DP_Presentation), and each of the 9 counts within ±1% of
the baseline counts from Task 6 Step 5 (Bronze may have moved slightly between runs). A larger
difference: stop and report.

---

### Task 8: Failure drill

- [ ] **Step 1: Run the Presentation copy with the drill**

`python .../run_item.py 73fd5443-240e-410a-990a-98827f32c087 <presentationProtoId> RunNotebook 3600 --param run_label=failure_drill --param failure_drill=true --param concurrency=4`
Expected: **exit 0**. The orchestrator catches `RunMultipleFailedException`, so the orchestrator
notebook itself succeeds.

- [ ] **Step 2: Read the summary**

`fab cat "DP - Presentation - Dev.Workspace/DP_Presentation.Lakehouse/Files/orchestration_proto/failure_drill.json"`
Expected:
- `raised: true`
- `Proto_FailProbe`: `ok: false`, error contains `deliberate failure`
- `Build_Gold_TechnicianAttendance`: `ok: true` (an unrelated item finished despite the failure)
- `Proto_AfterFail`: either absent from `results` or `ok: false` with an error mentioning the
  dependency. **Record exactly which**; Phase 2's run log depends on how skipped items are reported.

- [ ] **Step 3: Prove the dependent never ran, and the retry happened**

`fab ls "DP - Presentation - Dev.Workspace/DP_Presentation.Lakehouse/Files/orchestration_proto"`
Expected: **no** `AFTERFAIL_RAN.txt`.
For the retry: open the orchestrator's run snapshot in the Fabric Monitor (or the notebook's
`runMultiple` output in the run's snapshot), or check whether `proto_measure.py` for the drill window
shows `Proto_FailProbe` attempts. Record whether 2 attempts are visible; if the retry count can't be
observed, say so in the results.

- [ ] **Step 4: Refresh the SQL endpoint metadata** (Attendance VACUUMed).

---

### Task 9: CU numbers from Capacity Metrics

Capacity Metrics data lags (often 15–60 minutes). Do this at least an hour after Task 8, or the next
morning.

- [ ] **Step 1: Find a per-item, per-day (or per-operation) table**

Write `EVALUATE INFO.VIEW.TABLES()` to a scratchpad `.dax` file and run:
`python C:/Users/bfox/Documents/Git-Projects/data-projects/tools/dp-migration/dax_query.py 412a3d0a-73b6-4314-8134-c65c89209fd6 235b264c-203b-4425-9686-94589a67127a <file.dax>`
Look for a table with item + date (or timepoint/operation) grain, for example "MetricsByItemandDay"
or "TimePoint Background Detail". List its columns with `EVALUATE INFO.VIEW.COLUMNS()` filtered to
that table.

- [ ] **Step 2: Query CU for the 11 items on the run date**

Get the item IDs (the 9 Build_* notebooks + both `Proto_RunMultiple`) and query that table for them on
the run date, returning item name, CU (s), and duration (s). Record the result table.
**If no suitable table exists** (or INFO functions are rejected), give the controller this exact
request for Brian: "In the Capacity Metrics app, Compute page, set the date to <run date>, filter the
Items matrix to these 11 items, and send a screenshot of the CU (s) and Duration (s) columns:
<list>."

- [ ] **Step 3: Compute the comparison**

Baseline CU = sum of the 9 Build_* items (they only ran in the baseline that day; the prototype's
children bill to the orchestrator session). Prototype CU = the two `Proto_RunMultiple` items minus
the failure drill if it's inseparable. Note any contamination if the drill shares the day with the happy
path (the drill's cost is small: 1 Attendance run + 2 tiny probes).

---

### Task 10: Results write-up and decision gate (controller)

**Files:**
- Create: `C:\Users\bfox\Documents\Git-Projects\data-projects\docs\architecture\dp-refresh-prototype-results.md`

- [ ] **Step 1: Write the results doc** with these sections, filled from Tasks 1 and 6–9:
  1. What was tested (the 9 notebooks, two orchestrators, the concurrency used).
  2. Results table:

     | | Baseline (1 job per notebook, 3 at a time) | Prototype (runMultiple) |
     |---|---|---|
     | Spark sessions | | |
     | Wall clock | | |
     | Summed session running time | | |
     | CU (s) | | |

  3. Correctness: row counts vs baseline; no stray tables; shared-session settings.
  4. Failure drill: retry observed?, dependent skipped?, how skipped items appear in results.
  5. Surprises and limits found.
  6. Recommendation: Option 2 (proceed to the Phase 1–3 plan) or Option A, with the reason.

- [ ] **Step 2: Commit (data-projects)**

```bash
cd C:/Users/bfox/Documents/Git-Projects/data-projects
git add docs/architecture/dp-refresh-prototype-results.md
git commit -m "Phase 0 prototype results: runMultiple vs per-notebook sessions"
git push origin dev
```

- [ ] **Step 3: STOP.** Present the results table and recommendation to Brian and wait for his decision.
Phases 1–3 get their own plan (writing-plans) once he decides. Leave the prototype notebooks in
place; Phase 2 replaces `Proto_RunMultiple` with `Run_DP_Refresh` and deletes the probes.
