# Inspections Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repoint the Inspections Power BI report from LH_Master_Data to DP_Presentation with verified production parity, plus the approved fixes (spec: `docs/superpowers/specs/2026-09-25-inspections-migration-design.md`).

**Architecture:** Five Gold notebooks in `DP - Presentation - Dev/Fact Tables/Inspections/`, run in waves:
1. A new `Build_Gold_InspectionJobCodes` writes `lookup_InspectionJobCodes`.
2. LaborJobSummary, WorkOrderParts and PendingInspections read that lookup.
3. ServiceRecommendations reads LaborJobSummary and PendingInspections.

Before any of that, a CI fix makes the fabric-cicd deploy preserve workspace folders. Then the chain is run manually (schedules are paused), parity is checked against production month by month, and Claude edits the report TMDL while Desktop is closed. Brian validates and publishes.

**Tech Stack:** PySpark notebooks (Fabric), fabric-cicd 1.3.0 via GitHub Actions, `fab` CLI and Fabric REST (`fab api`), DuckDB `delta_scan` over OneLake, TMDL/PBIP.

---

## Context every task needs

**Repos:**
- `C:/Users/bfox/Documents/Git-Projects/fabric-workspace-docs` (branch `dev`). This is the Fabric Git mirror, and it holds the notebooks, the report and `deploy/`.
- `C:/Users/bfox/Documents/Git-Projects/data-projects` (branch `dev`). Docs, plus the helper scripts in `.claude/queries/adhoc/dp-migration-tools/`.

**Every push to `dev` in fabric-workspace-docs triggers GitHub Actions** (`.github/workflows/deploy.yml`). The workflow runs two scripts:
- `deploy/deploy_backend.py --environment dev` publishes every notebook registered in `deploy/dp_backend_scope.json` from the repo to the Dev workspaces, and rewrites `Files/config/dp_backend_scope.json` in both lakehouses.
- `deploy_reports.py` deploys only the three Batch 0 reports to RP - Sandbox. Inspections is not among them.

> **REVISED 2026-09-25, after Task 3 (single-writer fix).** The Dev workspaces are Fabric-Git-connected, and CI publishing notebooks into them, along with `fab import` creates, produced 16 "split identity" notebooks. Those were repaired in commits `3a4ba3ec` and `3cb6b1c2`. **CI now writes only the config for Dev (`deploy_backend.py` skips notebook publish when `environment == "dev"`) and fails if a registered folder is missing.** Notebook code reaches Dev only through Fabric Git sync:
>
> push to `dev` → `wait_ci.py` → `git_sync.py <workspaceId>` (Fabric updateFromGit; it refuses if an item changed on both sides) → run the notebook.
>
> **Never use `fab import` to create or update DP notebooks**, and never let anything other than Git sync write notebook content into a Dev workspace. A brand-new notebook is created by pushing its folder (with a `.platform` carrying a new logicalId) and syncing; Fabric then creates it already linked. The Task 4–8 steps below were rewritten to this flow.

**Never stage unrelated files.** Both repos have many dirty or untracked files left by Brian's Desktop sessions. `git add` only the exact paths each task names. If a push is rejected as non-fast-forward, run `git fetch origin && git merge origin/dev` (no rebase, no force), then push again.

**Shell gotchas:**
- Every `fab` call needs `export PATH="$HOME/.local/bin:$PATH"; export PYTHONIOENCODING=utf-8`.
- `fab` prints a long notice about a new fabric-cicd release; JSON output starts at the first `{`.
- Bash hooks sometimes falsely block commands that contain `VAR=$(...)` or `sleep`. Use the Python helpers from Task 1 instead of inline bash loops.

**IDs:**

| Item | ID |
|---|---|
| DP - Presentation - Dev workspace | `73fd5443-240e-410a-990a-98827f32c087` |
| DP_Presentation lakehouse | `966efc8a-16f9-423b-aa43-e368fcd8fb91` |
| SQL endpoint | `18effb0e-7bc2-47a1-854c-f4f2e8129145` |
| DP - Staging - Dev workspace | `ab15d64d-c7ba-415d-9bcf-7feb1ef9b201` |
| DP_Staging lakehouse | `876255e0-d462-4697-adc1-4a655f5bb101` |
| LH_Master_Data workspace (production) | `b48cdb35-7ce3-46de-96df-d70db77649cb` |
| LH_Master_Data lakehouse (production) | `3e74497b-8c51-4a1a-91a1-888c59118f48` |
| Build_Gold_LaborJobSummary | `acee9f09-8ccc-46aa-a553-ae9cb11077ed` |
| Build_Gold_WorkOrderParts | `8328ba15-55d8-4f73-abb3-19ea2e5cb2fa` |
| Build_Gold_PendingInspections | `645d32c8-bff7-4462-b341-525e16b819f3` |
| Build_Gold_ServiceRecommendations | `fc54d368-ff80-4a81-8770-fb3a67f08db1` |
| Build_Silver_WkOthSub | `1de7a0c6-f05e-4cd7-b7cd-6b76e719637d` |
| Build_Silver_WkRoFile | `af3d4019-6d41-4629-8c38-376e40d422e3` |
| Build_Silver_WkMechWk | `8ccd63c9-ece5-4a89-bf38-df3062fd59ab` |
| Build_Silver_TechnicianPunchedDetail | `92d8cd2e-a9f0-4286-8045-7449d03b6f2e` |
| Build_Silver_InTrans | `8bfdff09-5033-4c06-b9ad-1dfae9659c85` |
| df_RepairOrderDetail_Raw (Dataflow Gen2, in DP - Staging - Dev) | `77de2d0e-334d-478b-8e43-697e604203bb` |

**Notebook hygiene (every Gold notebook in this plan):**
- `spark.conf.set("spark.sql.session.timeZone", "UTC")` right after imports.
- After every `mode("overwrite")` write:
  ```python
  spark.conf.set("spark.databricks.delta.retentionDurationCheck.enabled", "false")
  spark.sql("VACUUM delta.`Tables/<name>` RETAIN 0 HOURS")
  ```
  Overwrite leaves orphaned Parquet files. The SQL endpoint scans them, which causes false "duplicate value" relationship errors in Desktop. This is a real bug that has been hit before, not optional boilerplate.

**Line numbers in the edit steps refer to the file as it was before the task began.** Earlier steps in the same task shift them. Always locate an edit by its quoted anchor text (the "from `X` through `Y`" lines); the line numbers are only hints.

**Decisions already made (don't revisit):**
- Include NULL-ModifiedDate punches.
- 2023+ scope on `Silver_WkOthSub.ModifiedDate`; headers and punches are scoped through the jobs, not filtered themselves.
- The 113 codes stay exactly as they are, matched on `TRIM(JobCode)`.
- One git-tracked lookup notebook.
- Gold facts are trimmed to the columns in use.

---

### Task 1: Shared helper scripts

**Files:**
- Create: `data-projects/.claude/queries/adhoc/dp-migration-tools/run_item.py`
- Create: `data-projects/.claude/queries/adhoc/dp-migration-tools/wait_ci.py`
- Create: `data-projects/.claude/queries/adhoc/dp-migration-tools/folder_check.py`
- Create: `data-projects/.claude/queries/adhoc/dp-migration-tools/README.md`

These helpers run an item and wait for it to finish, wait for the CI run of the current commit, and compare Fabric folders against repo paths. Customer Anatomy will reuse them.

- [ ] **Step 1: Write `run_item.py`**

```python
"""Run a Fabric item job by ID and wait for it to finish.

Usage: python run_item.py <workspaceId> <itemId> <jobType> [timeoutSeconds]
  jobType: RunNotebook (notebooks) | Refresh (Dataflow Gen2)
Exit code 0 only when the job's status is Completed.
"""
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timedelta, timezone

os.environ["PATH"] = os.path.expanduser("~/.local/bin") + os.pathsep + os.environ["PATH"]
os.environ["PYTHONIOENCODING"] = "utf-8"
TERMINAL = {"Completed", "Failed", "Cancelled", "Deduped"}


def fab_api(path, method=None):
    cmd = ["fab", "api", path] + (["-X", method] if method else [])
    out = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8").stdout
    start = out.find("{")
    return json.loads(out[start:]) if start >= 0 else {"raw": out[-800:]}


def main():
    ws, item, job_type = sys.argv[1:4]
    timeout = int(sys.argv[4]) if len(sys.argv) > 4 else 1800
    submitted = (datetime.now(timezone.utc) - timedelta(seconds=60)).strftime("%Y-%m-%dT%H:%M:%S")
    r = fab_api(f"workspaces/{ws}/items/{item}/jobs/instances?jobType={job_type}", "post")
    print("submit status:", r.get("status_code"))
    if r.get("status_code") not in (200, 201, 202):
        print(json.dumps(r, indent=1)[:2000])
        sys.exit(1)
    started = time.time()
    while True:
        time.sleep(20)
        body = fab_api(f"workspaces/{ws}/items/{item}/jobs/instances")
        runs = [i for i in body.get("text", {}).get("value", []) if (i.get("startTimeUtc") or "") >= submitted]
        if runs:
            latest = max(runs, key=lambda i: i.get("startTimeUtc") or "")
            status = latest.get("status")
            print(f"  {int(time.time() - started)}s: {status}")
            if status in TERMINAL:
                keys = ("status", "startTimeUtc", "endTimeUtc", "failureReason")
                print(json.dumps({k: latest.get(k) for k in keys}, indent=1))
                sys.exit(0 if status == "Completed" else 1)
        if time.time() - started > timeout:
            print("TIMEOUT waiting for job")
            sys.exit(2)


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Write `wait_ci.py`**

```python
"""Wait for the GitHub Actions run of fabric-workspace-docs' current HEAD commit.

Usage: python wait_ci.py [repoPath]   (default: fabric-workspace-docs)
Exit code 0 only when the run concluded 'success'.
"""
import json
import subprocess
import sys
import time

repo = sys.argv[1] if len(sys.argv) > 1 else r"C:/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
sha = subprocess.run(["git", "-C", repo, "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
print("waiting for CI run of", sha[:8])
deadline = time.time() + 900
while time.time() < deadline:
    out = subprocess.run(
        ["gh", "run", "list", "--commit", sha, "--json", "databaseId,status,conclusion"],
        capture_output=True, text=True, cwd=repo,
    ).stdout
    runs = json.loads(out or "[]")
    if runs:
        run = runs[0]
        print(f"  run {run['databaseId']}: {run['status']} {run.get('conclusion') or ''}")
        if run["status"] == "completed":
            sys.exit(0 if run.get("conclusion") == "success" else 1)
    time.sleep(15)
print("TIMEOUT waiting for CI")
sys.exit(2)
```

- [ ] **Step 3: Write `folder_check.py`**

```python
"""Compare each registered notebook's Fabric folder against its repo path.

Usage: python folder_check.py
Prints every registered notebook whose Fabric folder != its repo folder
(relative to workspaces/<workspace>/). Exit 1 if any mismatch.
"""
import json
import os
import subprocess
import sys

os.environ["PATH"] = os.path.expanduser("~/.local/bin") + os.pathsep + os.environ["PATH"]
os.environ["PYTHONIOENCODING"] = "utf-8"
SCOPE = r"C:/Users/bfox/Documents/Git-Projects/fabric-workspace-docs/deploy/dp_backend_scope.json"


def api(path):
    out = subprocess.run(["fab", "api", path], capture_output=True, text=True, encoding="utf-8").stdout
    return json.loads(out[out.find("{"):])["text"]


def folder_paths(ws):
    folders = {f["id"]: f for f in api(f"workspaces/{ws}/folders").get("value", [])}

    def full(fid):
        f = folders[fid]
        parent = f.get("parentFolderId")
        return (full(parent) + "/" if parent in folders else "") + f["displayName"]

    return {fid: full(fid) for fid in folders}


scope = json.load(open(SCOPE, encoding="utf-8"))
by_ws = {}
for nb in scope["notebooks"]:
    by_ws.setdefault(nb["workspaceId"], []).append(nb)

mismatches = 0
for ws, nbs in by_ws.items():
    paths = folder_paths(ws)
    items = {i["displayName"]: i for i in api(f"workspaces/{ws}/items?type=Notebook")["value"]}
    for nb in nbs:
        rel = nb["path"].split("/", 2)[2]          # drop "workspaces/<ws>/"
        repo_dir = rel.rsplit("/", 1)[0] if "/" in rel else ""
        it = items.get(nb["name"])
        fabric_dir = paths.get(it.get("folderId"), "") if it else "<MISSING>"
        ok = fabric_dir == repo_dir
        mismatches += not ok
        print(f"{'OK  ' if ok else 'DIFF'} {nb['name']:45s} fabric='{fabric_dir}' repo='{repo_dir}'")
print(f"\n{mismatches} mismatch(es) across {sum(len(v) for v in by_ws.values())} registered notebooks")
sys.exit(1 if mismatches else 0)
```

- [ ] **Step 4: Write `README.md`**

```markdown
# DP migration tools

Helpers for DP-backend report migrations (Inspections, Customer Anatomy, ...).

- `run_item.py <wsId> <itemId> <RunNotebook|Refresh> [timeout]`: run a notebook or Dataflow Gen2 and wait; exit 0 only on Completed.
- `wait_ci.py [repoPath]`: wait for the GitHub Actions run of fabric-workspace-docs HEAD; exit 0 only on success.
- `folder_check.py`: registered notebooks' Fabric folder vs repo path; exit 1 on any mismatch.
- `inspections_parity.py`: Inspections DP-vs-production parity (added in the Inspections plan, Task 9).

All need `fab` (authenticated) and, for DuckDB scripts, `az login`.
```

- [ ] **Step 5: Smoke-test `folder_check.py` (read-only)**

Run: `python "C:/Users/bfox/Documents/Git-Projects/data-projects/.claude/queries/adhoc/dp-migration-tools/folder_check.py"`
Expected (the bug that Task 2 fixes): nearly every registered notebook with a non-empty repo folder shows `DIFF ... fabric=''`. The summary shows a non-zero mismatch count, and the exit code is 1.

- [ ] **Step 6: Commit (data-projects)**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/data-projects"
git add .claude/queries/adhoc/dp-migration-tools/
git commit -m "Add DP migration helper scripts (run item, wait CI, folder check)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 2: Make the CI deploy preserve workspace folders

**Files:**
- Modify: `fabric-workspace-docs/deploy/lib.py` (`stage_items`, currently lines 117–151)
- Create: `fabric-workspace-docs/deploy/test_lib.py`
- Modify: `fabric-workspace-docs/deploy/requirements.txt`
- Modify: `data-projects/docs/architecture/dp-refresh-pipeline-assessment.md`

**The bug:** `stage_items` copies every item into one flat temp directory. fabric-cicd 1.3.0 mirrors the repository directory's folder structure into the workspace (it creates folders and calls `items/{id}/move`). As a result, all 38 registered notebooks were moved to the workspace root, while the repo expects them in folders. The fix keeps each item's path relative to `workspaces/<Workspace>/` in the staging copy. `deploy_reports.py` is unaffected, because its items live at the root of `workspaces/RP - Dev/`.

- [ ] **Step 1: Write the failing test**

Create `deploy/test_lib.py`:

```python
from pathlib import Path
import sys

import pytest

sys.path.insert(0, str(Path(__file__).parent))
from lib import stage_items  # noqa: E402


def _make_item(root: Path, rel: str) -> Path:
    p = root / rel
    p.mkdir(parents=True)
    (p / ".platform").write_text("{}", encoding="utf-8")
    return p


def test_stage_items_preserves_workspace_relative_folders(tmp_path):
    (tmp_path / "parameter.yml").write_text("", encoding="utf-8")
    nested = _make_item(tmp_path, "workspaces/WS/Fact Tables/Inspections/A.Notebook")
    top = _make_item(tmp_path, "workspaces/WS/B.Notebook")

    stage = stage_items(tmp_path, [nested, top])

    assert (stage / "Fact Tables" / "Inspections" / "A.Notebook" / ".platform").is_file()
    assert (stage / "B.Notebook" / ".platform").is_file()
    assert not (stage / "A.Notebook").exists()
    assert (stage / "parameter.yml").is_file()


def test_stage_items_rejects_items_from_two_workspaces(tmp_path):
    (tmp_path / "parameter.yml").write_text("", encoding="utf-8")
    a = _make_item(tmp_path, "workspaces/WS1/A.Notebook")
    b = _make_item(tmp_path, "workspaces/WS2/B.Notebook")

    with pytest.raises(ValueError):
        stage_items(tmp_path, [a, b])
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs" && python -m pytest deploy/test_lib.py -v`
Expected: both tests FAIL. The first fails its `Fact Tables/Inspections/A.Notebook` assertion; the second fails with `DID NOT RAISE`. If `pytest` isn't installed, run `python -m pip install pytest` first.

- [ ] **Step 3: Implement**

Replace the whole `stage_items` function in `deploy/lib.py` with:

```python
def stage_items(repo_root: Path, item_paths: list[Path]) -> Path:
    """Copy the given Fabric item folders into a fresh temp directory, keeping
    each item's folder path relative to its workspace directory, and return
    that temp directory's path.

    fabric-cicd deploys everything under repository_directory AND mirrors that
    directory's folder structure into the workspace (creating folders and
    moving existing items into them). Items must therefore be staged at their
    workspace-relative path, e.g. 'workspaces/DP - Presentation - Dev/Fact
    Tables/Inspections/X.Notebook' -> '<stage>/Fact Tables/Inspections/X.Notebook'.
    Staging them flat (the previous behavior, until 2026-09-25) made every
    deploy move every registered notebook to the workspace root - that, not
    the Fabric portal, is what emptied the Dimensions/ and Fact Tables/
    subfolders.

    All items in one call must come from the same workspace directory (one
    fabric-cicd deploy targets one workspace); mixing workspaces raises.

    Also copies parameter.yml from the repo root into the stage directory -
    fabric-cicd looks for parameter.yml directly inside repository_directory,
    not the original repo root, so without this copy every find_replace rule
    (the default_lakehouse rebinding, the report connection-string swap)
    silently never applies. Confirmed via a real dry run (2026-09-17):
    fabric-cicd logs "Parameter file not found" and continues anyway rather
    than failing loudly.
    """
    stage_dir = Path(tempfile.mkdtemp(prefix="fabric_cicd_stage_"))
    workspaces_root = (repo_root / "workspaces").resolve()
    workspace_dirs = set()
    for item_path in item_paths:
        if not item_path.is_dir():
            raise FileNotFoundError(f"Expected item folder not found: {item_path}")
        rel = item_path.resolve().relative_to(workspaces_root)
        workspace_dirs.add(rel.parts[0])
        target = stage_dir.joinpath(*rel.parts[1:])
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(item_path, target)

    if len(workspace_dirs) > 1:
        raise ValueError(f"stage_items got items from more than one workspace: {sorted(workspace_dirs)}")

    parameter_file = repo_root / "parameter.yml"
    if not parameter_file.is_file():
        raise FileNotFoundError(f"parameter.yml not found at repo root: {parameter_file}")
    shutil.copy2(parameter_file, stage_dir / "parameter.yml")

    return stage_dir
```

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `python -m pytest deploy/test_lib.py -v`
Expected: 2 passed.

- [ ] **Step 5: Stage the real scope as a dry run (no deploy)**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
python -c "
import sys; sys.path.insert(0, 'deploy')
from pathlib import Path
from lib import load_backend_scope, notebooks_by_tier, stage_items
root = Path('.')
scope = load_backend_scope(root)
for tier in ('silver', 'gold'):
    stage = stage_items(root, [root / nb['path'] for nb in notebooks_by_tier(scope, tier)])
    staged = sorted(str(p.relative_to(stage)).replace(chr(92), '/') for p in stage.rglob('*.Notebook'))
    print(tier, len(staged)); print('\n'.join('  ' + s for s in staged))
"
```
Expected: silver 9, gold 29. Items such as `Dimensions/Build_Gold_DateTable.Notebook` and `Fact Tables/Labor Performance/Build_Gold_TechnicianAttendance.Notebook` appear with their folders, and there are no errors.

- [ ] **Step 6: Pin fabric-cicd**

Change the `fabric-cicd` line in `deploy/requirements.txt` to `fabric-cicd==1.3.0`. That's the version CI has actually been installing (confirmed in run 36058128250's log). An unpinned deploy tool is a silent-change risk for a promotion pipeline.

- [ ] **Step 7: Commit, push and wait for CI**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add deploy/lib.py deploy/test_lib.py deploy/requirements.txt
git commit -m "Fix CI deploy flattening registered notebooks into workspace root

stage_items copied every item into one flat directory; fabric-cicd mirrors
the staged folder structure into the workspace, so every deploy moved all
38 registered notebooks out of their folders. Stage items at their
workspace-relative path instead. Also pin fabric-cicd to 1.3.0 (the version
CI has been running) and add tests.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin dev
python "/c/Users/bfox/Documents/Git-Projects/data-projects/.claude/queries/adhoc/dp-migration-tools/wait_ci.py"
```
Expected: `completed success`. If CI fails, open `gh run view <id> --log-failed`, report it, and stop.

- [ ] **Step 8: Verify the folders are restored**

Run: `python "/c/Users/bfox/Documents/Git-Projects/data-projects/.claude/queries/adhoc/dp-migration-tools/folder_check.py"`
Expected: `0 mismatch(es) across 38 registered notebooks`, exit 0.

- [ ] **Step 9: Correct the assessment doc (data-projects)**

In `docs/architecture/dp-refresh-pipeline-assessment.md`:

(a) In §2, replace the bullet that begins `- **The pipeline reads a deployed copy of the config**` with:
```markdown
- **The pipeline reads a deployed copy of the config**, which sits in the Lakehouse *Files* area. It does not read the repo file (`fabric-workspace-docs/deploy/dp_backend_scope.json`). The copy is refreshed automatically: every push to `dev` runs GitHub Actions (`deploy.yml` → `deploy_backend.py`). That run publishes every registered notebook from the repo through fabric-cicd, then rewrites the config in both Dev lakehouses. **Pushing to `dev` is therefore a deployment.** (Corrected 2026-09-25; this doc originally said the copy needed a manual re-upload.)
```

(b) At the end of §3e, add:
```markdown
- **Fixed 2026-09-25: CI deploy flattened folders.** `deploy/lib.py` `stage_items` staged every notebook flat, and fabric-cicd mirrors the staged structure, so every deploy moved all registered notebooks to the workspace root. Items are now staged at their workspace-relative path, and `fabric-cicd` is pinned to 1.3.0.
```

```bash
cd "/c/Users/bfox/Documents/Git-Projects/data-projects"
git add docs/architecture/dp-refresh-pipeline-assessment.md
git commit -m "Correct pipeline assessment: config sync is CI-driven; record folder fix

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin dev
```

- [ ] **Step 10: Ask Brian to check the DP workspaces' Git panels**

Controller task (don't dispatch it): ask Brian to open **Source control** in `DP - Presentation - Dev` and `DP - Staging - Dev`. The notebook moves that were showing as pending changes should now be gone. Record what he sees.

---

### Task 3: Refresh the Inspections input chain (manual; schedules are paused)

**Files:** none. This task only runs items.

The Silver inputs have been frozen since 09-09/09-10. Refresh the Staging dataflow and all 5 Silver inputs so Gold builds on current data. All 5 Silver notebooks read Bronze directly and don't depend on each other. `df_RepairOrderDetail_Raw` is an ODBC pull of about 2.9K rows, which is small enough to run during business hours.

- [ ] **Step 1: Refresh the RepairOrderDetail dataflow**

```bash
T="/c/Users/bfox/Documents/Git-Projects/data-projects/.claude/queries/adhoc/dp-migration-tools"
python "$T/run_item.py" ab15d64d-c7ba-415d-9bcf-7feb1ef9b201 77de2d0e-334d-478b-8e43-697e604203bb Refresh 1800
```
Expected: `"status": "Completed"`. If submission fails with a job-type error, report the exact output and stop; don't try other job types.

- [ ] **Step 2: Run the 5 Silver notebooks one at a time**

```bash
python "$T/run_item.py" ab15d64d-c7ba-415d-9bcf-7feb1ef9b201 1de7a0c6-f05e-4cd7-b7cd-6b76e719637d RunNotebook
python "$T/run_item.py" ab15d64d-c7ba-415d-9bcf-7feb1ef9b201 af3d4019-6d41-4629-8c38-376e40d422e3 RunNotebook
python "$T/run_item.py" ab15d64d-c7ba-415d-9bcf-7feb1ef9b201 8ccd63c9-ece5-4a89-bf38-df3062fd59ab RunNotebook
python "$T/run_item.py" ab15d64d-c7ba-415d-9bcf-7feb1ef9b201 92d8cd2e-a9f0-4286-8045-7449d03b6f2e RunNotebook
python "$T/run_item.py" ab15d64d-c7ba-415d-9bcf-7feb1ef9b201 8bfdff09-5033-4c06-b9ad-1dfae9659c85 RunNotebook
```
(In order: WkOthSub, WkRoFile, WkMechWk, TechnicianPunchedDetail, InTrans.) Expected: each shows `Completed`. Stop on the first failure and report it.

- [ ] **Step 3: Verify freshness**

```python
import duckdb
con = duckdb.connect()
con.sql("SET TimeZone='UTC'; INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.sql("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
S = "abfss://ab15d64d-c7ba-415d-9bcf-7feb1ef9b201@onelake.dfs.fabric.microsoft.com/876255e0-d462-4697-adc1-4a655f5bb101/Tables/"
for t, col in [("Silver_WkOthSub", "ModifiedDate"), ("Silver_WkRoFile", "CreatedOn"),
               ("Silver_WkMechWk", "ClockInDate"), ("Silver_TechnicianPunchedDetail", None),
               ("Silver_InTrans", "TransDatetime"), ("RepairOrderDetail", None)]:
    agg = f", MAX({col})" if col else ""
    print(t, con.sql(f"SELECT COUNT(*){agg} FROM delta_scan('{S}{t}')").fetchone())
```
Expected: every MAX date falls within the last 1–2 days, and `RepairOrderDetail` has about 2.9K rows. Save the output; the Task 9 report quotes it.

---

### Task 4: Build `Build_Gold_InspectionJobCodes` (wave 1)

**Files:**
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/Inspections/Build_Gold_InspectionJobCodes.Notebook/notebook-content.py`
- Create: `.../Build_Gold_InspectionJobCodes.Notebook/.platform`
- Modify: `fabric-workspace-docs/deploy/dp_backend_scope.json`

- [ ] **Step 1: Write `notebook-content.py`**

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

# Build_Gold_InspectionJobCodes
# Purpose: single source of truth for the inspection job codes the service
# team tracks. Writes lookup_InspectionJobCodes (one column, JobCode), read by
# Build_Gold_LaborJobSummary, Build_Gold_WorkOrderParts and
# Build_Gold_PendingInspections. Replaces the three hard-coded copies those
# notebooks (and production's dataflows) each carried.
#
# WAVE 1 of the Inspections chain - must run before the wave-2 notebooks,
# which fail loudly if this table is missing or doesn't hold 113 codes.
#
# THE LIST IS OWNED BY SERVICE (confirmed with Brian 2026-09-25): exactly the
# 113 codes service defined. Unlisted look-alikes seen in the data
# ('IS INSPECTION', '/BASKET VIP INSPECT', 'VEHICLE INSPECT' - 25 in-scope
# rows total) are deliberately NOT included. To change the list: edit
# INSPECTION_CODES below, update the expected count, commit, push, run.
# Consumers match on TRIM(JobCode), so codes here must not carry
# leading/trailing spaces (asserted below).
#
# Spec: data-projects docs/superpowers/specs/2026-09-25-inspections-migration-design.md

print("=" * 80)
print("BUILD_GOLD_INSPECTIONJOBCODES")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql.types import StructField, StructType, StringType

spark.conf.set("spark.sql.session.timeZone", "UTC")

EXPECTED_CODE_COUNT = 113

INSPECTION_CODES = [
    "/COMBINE VIP INSPECT", "/CS690 INSPECTION", "/CS690 VIP INSPECTIO", "/INSPECTION",
    "/PLANTER INSPECTION", "/Rental Inspection", "/SPRAYER INSPECTION", "/TRACTOR INSPECTION",
    "/WINTER INSPECTION", "ALL/9001/LEG/590", "COMBINE INSPECTION", "IS-125", "IS-145",
    "IS-3E ANNUAL SERVICE", "IS-4X2", "IS-5E INSPECT", "IS-AMS DATA", "IS-AMS DATA SETUP",
    "IS-AMS OPTIMIZE", "IS-AMS SOFTWARE", "IS-COMBINE INSPECT", "IS-COMPACT INSPECT",
    "IS-CORN/DRAPER", "IS-CP690 INSPECT", "IS-CP770 INSPECT", "IS-CS690 INSPECT",
    "IS-CS770 INSPECT", "IS-D100", "IS-D105(-200000)", "IS-D105(200001-)",
    "IS-D110(-500000)", "IS-D110(500001-)", "IS-D120", "IS-D125", "IS-D130(-400000)",
    "IS-D130(400001-)", "IS-D140(-400000)", "IS-D140(400001-)", "IS-D155(700001-)",
    "IS-D160", "IS-D170", "IS-E100", "IS-E120", "IS-E120-QCD", "IS-E130-QCD",
    "IS-E170-QCD", "IS-E180-QCD", "IS-GATOR INSPECTION", "IS-HPX(-040000)",
    "IS-HPX(040001-)", "IS-L110", "IS-L130", "IS-LA115", "IS-LA125", "IS-LA135",
    "IS-LT150(039001-)", "IS-LT160", "IS-LT166", "IS-LT180", "IS-MOWER INSPECTION",
    "IS-PICKER INSPECT", "IS-PLANTER INSPECT", "IS-PLATFORM INSP", "IS-PRE R INSPECTION",
    "IS-R INSPECTION", "IS-S240", "IS-SKID STEER INSPEC", "IS-SPRAYER INSPECT",
    "IS-STRIPPER INSPECT", "IS-SWATHER INSPECT", "IS-TRACTOR INSPECT", "IS-TS4X2",
    "IS-X300(-180000)", "IS-X300(180001-)", "IS-X300R(120001-)", "IS-X304(180001-)",
    "IS-X310", "IS-X320(-180000)", "IS-X324(-180000)", "IS-X350", "IS-X354",
    "IS-X360(-180000)", "IS-X380", "IS-X500", "IS-X570", "IS-XUV550", "IS-XUV560",
    "IS-XUV590I", "IS-XUV590M", "IS-XUV835R", "IS-XUV855D", "IS-Z225(-060000)",
    "IS-Z225(100001-12000", "IS-Z255", "IS-Z335E", "IS-Z345M", "IS-Z345R", "IS-Z355E",
    "IS-Z355R", "IS-Z375R", "IS-Z425(-040000)", "IS-Z425(100001-)",
    "IS-Z425(40001-100000", "IS-Z435", "IS-Z445(-100000)", "IS-Z445(100000-14000",
    "IS-Z445(140001-)", "IS-Z515E", "IS-Z525E", "IS-Z535M", "IS-Z540M",
    "IS-HARVESTREADY", "IS-Z540R",
]

assert len(INSPECTION_CODES) == EXPECTED_CODE_COUNT, (
    f"Expected {EXPECTED_CODE_COUNT} codes, found {len(INSPECTION_CODES)}")
assert len(set(INSPECTION_CODES)) == len(INSPECTION_CODES), "Duplicate code in INSPECTION_CODES"
assert all(c == c.strip() for c in INSPECTION_CODES), (
    "Codes must not carry leading/trailing spaces - consumers match on TRIM(JobCode)")

schema = StructType([StructField("JobCode", StringType(), False)])
lookup = spark.createDataFrame([(c,) for c in INSPECTION_CODES], schema)

lookup.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/lookup_InspectionJobCodes")
spark.conf.set("spark.databricks.delta.retentionDurationCheck.enabled", "false")
spark.sql("VACUUM delta.`Tables/lookup_InspectionJobCodes` RETAIN 0 HOURS")

written = spark.read.format("delta").load("Tables/lookup_InspectionJobCodes").count()
assert written == EXPECTED_CODE_COUNT, f"lookup_InspectionJobCodes has {written} rows after write"
print(f"lookup_InspectionJobCodes written and vacuumed: {written} codes")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

The 113-code list is copied verbatim from the current `Build_Gold_LaborJobSummary` notebook (lines 86–112). Before saving, diff your list against that source and confirm it is identical, character for character.

- [ ] **Step 2: Write `.platform`**

Generate a GUID with `python -c "import uuid; print(uuid.uuid4())"`, then:
```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Gold_InspectionJobCodes"
  },
  "config": {
    "version": "2.0",
    "logicalId": "<the generated guid>"
  }
}
```

- [ ] **Step 3: Create it in Fabric through Git sync (never `fab import`)**

Push the new folder, which is not registered yet, then sync the workspace so Fabric creates the notebook already linked to Git:
```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/DP - Presentation - Dev/Fact Tables/Inspections/Build_Gold_InspectionJobCodes.Notebook"
git commit -m "Add Build_Gold_InspectionJobCodes: single source for the 113 inspection codes

Wave 1 of the Inspections chain; replaces three hard-coded copies.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin dev
T="/c/Users/bfox/Documents/Git-Projects/data-projects/.claude/queries/adhoc/dp-migration-tools"
python "$T/wait_ci.py" && python "$T/git_sync.py" 73fd5443-240e-410a-990a-98827f32c087
export PATH="$HOME/.local/bin:$PATH"; export PYTHONIOENCODING=utf-8
fab get "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Inspections.Folder/Build_Gold_InspectionJobCodes.Notebook" -q "id"
```
Expected:
- `git_sync.py` prints `incoming Added Build_Gold_InspectionJobCodes (Notebook)` and then `Synced to <sha>`.
- `fab get` returns the new item ID. Record it; the steps below call it `<LOOKUP_ID>`.

If `git_sync.py` refuses because of changes on both sides, stop and report; don't resolve anything in the workspace.

- [ ] **Step 4: Run it**

```bash
python "/c/Users/bfox/Documents/Git-Projects/data-projects/.claude/queries/adhoc/dp-migration-tools/run_item.py" 73fd5443-240e-410a-990a-98827f32c087 <LOOKUP_ID> RunNotebook
```
Expected: `Completed`. Then run a DuckDB check that `SELECT COUNT(*), COUNT(DISTINCT JobCode) FROM delta_scan('abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables/lookup_InspectionJobCodes')` returns `(113, 113)`.

- [ ] **Step 5: Register it (wave 1)**

Insert the entry with the Edit tool, matching the existing compact style. **Never rewrite the file with `json.dump`**, which reformats the whole file. The current last entry is `Build_Gold_TechnicianEfficiency`; add a comma after its closing `}` and append:
```json
    {"name": "Build_Gold_InspectionJobCodes", "tier": "gold", "cadence": "daily", "wave": 1,
     "notebookId": "<LOOKUP_ID>", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
     "path": "workspaces/DP - Presentation - Dev/Fact Tables/Inspections/Build_Gold_InspectionJobCodes.Notebook"}
```
Validate: `python -c "import json; json.load(open('deploy/dp_backend_scope.json', encoding='utf-8'))"`.

- [ ] **Step 6: Commit the registration, push, wait for CI, check folders and Git status**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add deploy/dp_backend_scope.json
git commit -m "Register Build_Gold_InspectionJobCodes (Inspections wave 1)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin dev
T="/c/Users/bfox/Documents/Git-Projects/data-projects/.claude/queries/adhoc/dp-migration-tools"
python "$T/wait_ci.py" && python "$T/git_sync.py" 73fd5443-240e-410a-990a-98827f32c087
python "$T/folder_check.py"
```
Expected:
- CI succeeds (it now only writes the config for Dev).
- `git_sync.py` reports `Already up to date` or syncs with no incoming notebook changes.
- `folder_check` shows `OK  Build_Gold_InspectionJobCodes fabric='Fact Tables/Inspections'` with 0 mismatches.

---

### Task 5: Update `Build_Gold_LaborJobSummary` (wave 2)

**Files:**
- Modify: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/Inspections/Build_Gold_LaborJobSummary.Notebook/notebook-content.py`
- Modify: `fabric-workspace-docs/deploy/dp_backend_scope.json`

**Changes:**
- 2023+ scope on WkOthSub.
- Punches unfiltered, so they are scoped through the jobs; this includes the NULL-ModifiedDate hours.
- Use the lookup table with `TRIM`.
- Trim the output to 9 columns.
- Add a row-count gate.
- UTC pin and VACUUM.

- [ ] **Step 1: Replace the header's KNOWN ISSUE block**

Replace everything from the first `# ============================================================================` line (line 38) through `# unaffected and safe to use.` (line 66) with:
```python
# ============================================================================
# 2026-09-25 MIGRATION UPDATE (Inspections -> DP_Presentation)
# Spec: data-projects docs/superpowers/specs/2026-09-25-inspections-migration-design.md
# ============================================================================
# - SCOPE: Silver_WkOthSub.ModifiedDate >= 2023-01-01, reproducing
#   production's own WKOTHSUB filter. Headers (WkRoFile) and punches
#   (WkMechWk) are scoped THROUGH those jobs by the LEFT joins below;
#   Silver_WkMechWk is deliberately NOT filtered on its own ModifiedDate.
#   Production filtered punches on ModifiedDate >= 2023, which silently
#   dropped NULL-ModifiedDate punches (~15.5K hrs 2023, ~15.9K 2024,
#   ~4.2K 2025) - a production under-count fixed here (Brian, 2026-09-24).
#   It also admits 11 punches (17.1 hrs, clocked 2022) modified before
#   2023 on jobs modified 2023+.
# - Inspection codes come from lookup_InspectionJobCodes
#   (Build_Gold_InspectionJobCodes, wave 1), matched on TRIM(JobCode).
# - Output trimmed to the 9 columns the report and
#   Build_Gold_ServiceRecommendations use. Production's IsPending flag
#   (always False - case-sensitive match against codes that never occur)
#   is dropped; the report uses its own IsPendingInspection column.
```

- [ ] **Step 2: Replace the setup cell body**

Replace everything from `from pyspark.sql import functions as F` (line 81) through `print(f"Base wkothsub rows: {source.count():,}")` (line 150) with:
```python
from pyspark.sql import functions as F

spark.conf.set("spark.sql.session.timeZone", "UTC")

# Inspection codes: single source of truth is lookup_InspectionJobCodes
# (Build_Gold_InspectionJobCodes, wave 1). Fail loudly if it's missing or
# incomplete rather than silently flagging zero inspections.
INSPECTION_CODES = [r["JobCode"] for r in spark.read.table("lookup_InspectionJobCodes").select("JobCode").collect()]
assert len(INSPECTION_CODES) == 113 and len(set(INSPECTION_CODES)) == 113, (
    f"lookup_InspectionJobCodes must hold 113 distinct codes - found {len(INSPECTION_CODES)} "
    f"({len(set(INSPECTION_CODES))} distinct). Run Build_Gold_InspectionJobCodes first."
)
print(f"Inspection codes from lookup_InspectionJobCodes: {len(INSPECTION_CODES)}")

SCOPE_START = "2023-01-01"

# STEP 2: aggregate labor hours to job grain. Deliberately NOT filtered on
# Silver_WkMechWk.ModifiedDate - scoped through the in-scope jobs by the
# LEFT join in STEP 6 (see header).
aggregated_hours = (
    spark.read.table("Silver_WkMechWk")
    .select("Branch", F.col("WorkOrder").cast("string").alias("WorkOrder"), "JobCode", "JobType", "HoursWorked")
    .groupBy("Branch", "WorkOrder", "JobCode", "JobType")
    .agg(F.sum(F.coalesce(F.col("HoursWorked"), F.lit(0))).alias("ActualHoursWorked"))
)

# STEP 3: work order context from WKROFILE - creation date is the only
# header field the trimmed output keeps.
work_order_context = (
    spark.read.table("Silver_WkRoFile")
    .select(
        "Branch", F.col("WorkOrder").cast("string").alias("WorkOrder"),
        F.col("CreatedOn").alias("WorkOrderCreationDate"),
    )
)

# STEP 4: core job data from wkothsub (base grain), 2023+ scope.
source = (
    spark.read.table("Silver_WkOthSub")
    .filter(F.col("ModifiedDate") >= F.to_timestamp(F.lit(SCOPE_START)))
    .select(
        "Branch", F.col("WorkOrder").cast("string").alias("WorkOrder"), "JobCode", "JobType",
        "InvLabor", "InvoiceNumber",
    )
)
source_count = source.count()
print(f"Base wkothsub rows (ModifiedDate >= {SCOPE_START}): {source_count:,}")
```

- [ ] **Step 3: Replace the build cell body**

Replace everything from `# STEP 5: IsInspection flag.` (line 161) through `print("Gold build complete: Fact_LaborJobSummary written.")` (line 232) with:
```python
# STEP 5: IsInspection flag (TRIM guards against space-padded source codes).
with_inspection_flag = source.withColumn("IsInspection", F.trim(F.col("JobCode")).isin(INSPECTION_CODES))

# STEP 6: join aggregated labor hours (left) - this is what scopes punches
# through the in-scope jobs.
with_hours = with_inspection_flag.join(aggregated_hours, ["Branch", "WorkOrder", "JobCode", "JobType"], "left")

# STEP 7: join work order context (left).
with_wo_context = with_hours.join(work_order_context, ["Branch", "WorkOrder"], "left")

fact_labor_job_summary = with_wo_context.select(
    F.col("Branch").alias("BranchCode"),
    F.col("WorkOrder").alias("WorkOrderNumber"),
    "JobCode", "JobType", "InvoiceNumber",
    F.col("InvLabor").alias("InvoicedLaborAmount"),
    "IsInspection", "ActualHoursWorked",
    F.to_date(F.col("WorkOrderCreationDate")).alias("WorkOrderCreationDate"),
)

fact_count = fact_labor_job_summary.count()
print(f"Fact_LaborJobSummary rows: {fact_count:,}")
assert fact_count == source_count, (
    f"Row count changed across LEFT joins ({source_count:,} -> {fact_count:,}): a join key is "
    "duplicated in the Silver_WkMechWk aggregation or Silver_WkRoFile. Investigate before writing."
)

fact_labor_job_summary.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Fact_LaborJobSummary")
spark.conf.set("spark.databricks.delta.retentionDurationCheck.enabled", "false")
spark.sql("VACUUM delta.`Tables/Fact_LaborJobSummary` RETAIN 0 HOURS")
print("Gold build complete: Fact_LaborJobSummary written and vacuumed.")
```

- [ ] **Step 4: Replace the verification cell body**

Replace everything from `sample = spark.sql(` (line 243) through `print(status_check.to_string())` (line 270) with:
```python
sample = spark.sql("SELECT * FROM delta.`Tables/Fact_LaborJobSummary` LIMIT 10").toPandas()
print("Sample rows:")
print(sample.to_string())

inspection_rate = spark.sql("""
    SELECT IsInspection, COUNT(*) AS RowCount
    FROM delta.`Tables/Fact_LaborJobSummary`
    GROUP BY IsInspection
""").toPandas()
print("\nIsInspection breakdown:")
print(inspection_rate.to_string())

by_year = spark.sql("""
    SELECT YEAR(WorkOrderCreationDate) AS CreatedYear, COUNT(*) AS RowCount,
           ROUND(SUM(ActualHoursWorked), 1) AS Hours
    FROM delta.`Tables/Fact_LaborJobSummary`
    GROUP BY 1 ORDER BY 1
""").toPandas()
print("\nRows/hours by work order creation year:")
print(by_year.to_string())
```

Then confirm the file no longer contains `IsPending`, `INSPECTION_CODES = [`, `TotalInvoicedAmount` or `WorkOrderStatus`.

- [ ] **Step 5: Register it (wave 2)**

Append after the `Build_Gold_InspectionJobCodes` entry (add a comma to that entry first):
```json
    {"name": "Build_Gold_LaborJobSummary", "tier": "gold", "cadence": "daily", "wave": 2,
     "notebookId": "acee9f09-8ccc-46aa-a553-ae9cb11077ed", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
     "path": "workspaces/DP - Presentation - Dev/Fact Tables/Inspections/Build_Gold_LaborJobSummary.Notebook"}
```
Validate with the `json.load` one-liner.

- [ ] **Step 6: Commit, push, wait for CI, Git-sync the workspace (this is what delivers the edited code), then run**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/DP - Presentation - Dev/Fact Tables/Inspections/Build_Gold_LaborJobSummary.Notebook/notebook-content.py" deploy/dp_backend_scope.json
git commit -m "LaborJobSummary: 2023+ scope via jobs, include NULL-ModifiedDate hours, lookup codes, trim, VACUUM

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin dev
T="/c/Users/bfox/Documents/Git-Projects/data-projects/.claude/queries/adhoc/dp-migration-tools"
python "$T/wait_ci.py" && python "$T/git_sync.py" 73fd5443-240e-410a-990a-98827f32c087 && python "$T/run_item.py" 73fd5443-240e-410a-990a-98827f32c087 acee9f09-8ccc-46aa-a553-ae9cb11077ed RunNotebook
```
Expected: CI succeeds and the run shows `Completed`. If the row-count assert fires, stop and report the two counts; don't remove the assert.

- [ ] **Step 7: Schema and sanity check (DuckDB)**

```python
import duckdb
con = duckdb.connect()
con.sql("SET TimeZone='UTC'; INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.sql("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
P = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables/Fact_LaborJobSummary"
print(con.sql(f"DESCRIBE SELECT * FROM delta_scan('{P}')").fetchall())
print(con.sql(f"SELECT COUNT(*), COUNT(*) FILTER (WHERE IsInspection), ROUND(SUM(ActualHoursWorked),1) FROM delta_scan('{P}')").fetchall())
```
Expected: exactly 9 columns (BranchCode, WorkOrderNumber, JobCode, JobType, InvoiceNumber, InvoicedLaborAmount, IsInspection, ActualHoursWorked, WorkOrderCreationDate), with `WorkOrderCreationDate` of type DATE. The row count should be a little above production's 387,174 (the base grew after 09-24), and the inspection count should be about 4.9K.

---

### Task 6: Update `Build_Gold_WorkOrderParts` (wave 2)

**Files:**
- Modify: `.../Fact Tables/Inspections/Build_Gold_WorkOrderParts.Notebook/notebook-content.py`
- Modify: `fabric-workspace-docs/deploy/dp_backend_scope.json`

**Changes:**
- 2023+ scope on the inspection jobs.
- Lookup codes with `TRIM`.
- Replace the Feb-29 crash-prone cutoff with `add_months(-36)`.
- Trim the output to 9 columns.
- UTC pin and VACUUM.

- [ ] **Step 1: Add to the header's REAL BUG FOUND note**

After the line `# UTC-to-Central conversion, computed once for this run.` (line 96), insert:
```python
#
# 2026-09-25 (Inspections migration): the 3-year cutoff used
# datetime.replace(year=year-3), which raises ValueError when run on
# Feb 29. Replaced with Spark add_months(..., -36). Inspection jobs are now
# scoped to Silver_WkOthSub.ModifiedDate >= 2023-01-01 (production's own
# WKOTHSUB scope), codes come from lookup_InspectionJobCodes matched on
# TRIM(JobCode), and the output is trimmed to the 9 columns the report uses.
```

- [ ] **Step 2: Replace the code-list block**

Replace everything from `from pyspark.sql import functions as F` (line 125) through `print(f"Inspection code list: {len(INSPECTION_CODES)} codes (expect 113)")` (line 163) with:
```python
from pyspark.sql import functions as F

spark.conf.set("spark.sql.session.timeZone", "UTC")

# Inspection codes: single source of truth is lookup_InspectionJobCodes
# (Build_Gold_InspectionJobCodes, wave 1).
INSPECTION_CODES = [r["JobCode"] for r in spark.read.table("lookup_InspectionJobCodes").select("JobCode").collect()]
assert len(INSPECTION_CODES) == 113 and len(set(INSPECTION_CODES)) == 113, (
    f"lookup_InspectionJobCodes must hold 113 distinct codes - found {len(INSPECTION_CODES)} "
    f"({len(set(INSPECTION_CODES))} distinct). Run Build_Gold_InspectionJobCodes first."
)
print(f"Inspection codes from lookup_InspectionJobCodes: {len(INSPECTION_CODES)}")

SCOPE_START = "2023-01-01"
```

- [ ] **Step 3: Scope the inspection jobs**

Replace:
```python
wkothsub = spark.read.table("Silver_WkOthSub")
inspection_jobs = wkothsub.filter(F.col("JobCode").isin(INSPECTION_CODES))
```
with:
```python
wkothsub = spark.read.table("Silver_WkOthSub").filter(F.col("ModifiedDate") >= F.to_timestamp(F.lit(SCOPE_START)))
inspection_jobs = wkothsub.filter(F.trim(F.col("JobCode")).isin(INSPECTION_CODES))
```

- [ ] **Step 4: Replace the cutoff and InTrans load**

Replace everything from `# STEP 3: load parts transactions, rolling 3-year cutoff.` (line 206) through `print(f"InTrans rows after 3-year cutoff: {parts_filtered.count():,}")` (line 231) with:
```python
# STEP 3: load parts transactions, rolling 3-year cutoff: Central-time
# "today" minus 36 months. add_months replaces datetime.replace(year=year-3),
# which raised ValueError on Feb 29 (see header).
cutoff_date = spark.sql(
    "SELECT add_months(to_date(from_utc_timestamp(current_timestamp(), 'America/Chicago')), -36) AS cutoff"
).collect()[0]["cutoff"]
print(f"3-year rolling cutoff (Central time): {cutoff_date}")

intrans = spark.read.table("Silver_InTrans").select(
    "Branch", "RONumber", "TransDatetime", "PartNumber", "Description",
    "Franchise", "Qty", "SaleValue", "CustomerNo",
)

parts_filtered = (
    intrans
    .filter(F.to_date(F.col("TransDatetime")) >= F.lit(cutoff_date))
    .select(
        F.col("Branch").cast("string").alias("Branch"),
        F.col("RONumber").cast("string").alias("RONumber"),  # RONumber in InTrans = Invoice Number
        "TransDatetime", "PartNumber", "Description", "Franchise", "Qty",
        "SaleValue", "CustomerNo",
    )
)
print(f"InTrans rows after 3-year cutoff: {parts_filtered.count():,}")
```

- [ ] **Step 5: Trim the renamed select**

Replace the `renamed = parts_on_inspection_invoices.select(...)` statement (lines 246–257) with:
```python
renamed = parts_on_inspection_invoices.select(
    F.col("Branch").alias("BranchCode"),
    F.col("RONumber").alias("InvoiceNumber"),
    F.to_date(F.col("TransDatetime")).alias("TransactionDate"),
    "PartNumber", "Description", "Franchise",
    F.col("Qty").alias("Quantity"),
    "SaleValue",
    F.col("CustomerNo").alias("CustomerNumber"),
)
```

- [ ] **Step 6: Add VACUUM after the write**

Replace:
```python
fact_work_order_parts.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Fact_WorkOrderParts")
print("Gold build complete: Fact_WorkOrderParts written.")
```
with:
```python
fact_work_order_parts.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Fact_WorkOrderParts")
spark.conf.set("spark.databricks.delta.retentionDurationCheck.enabled", "false")
spark.sql("VACUUM delta.`Tables/Fact_WorkOrderParts` RETAIN 0 HOURS")
print("Gold build complete: Fact_WorkOrderParts written and vacuumed.")
```
Confirm the file no longer contains `.replace(year=`, `CostValue`, `SellPrice`, `ListPrice`, `TradeType` or `INSPECTION_CODES = [`.

- [ ] **Step 7: Register, commit, push, wait for CI, run**

Append after the LaborJobSummary entry (add a comma first):
```json
    {"name": "Build_Gold_WorkOrderParts", "tier": "gold", "cadence": "daily", "wave": 2,
     "notebookId": "8328ba15-55d8-4f73-abb3-19ea2e5cb2fa", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
     "path": "workspaces/DP - Presentation - Dev/Fact Tables/Inspections/Build_Gold_WorkOrderParts.Notebook"}
```
```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
python -c "import json; json.load(open('deploy/dp_backend_scope.json', encoding='utf-8'))"
git add "workspaces/DP - Presentation - Dev/Fact Tables/Inspections/Build_Gold_WorkOrderParts.Notebook/notebook-content.py" deploy/dp_backend_scope.json
git commit -m "WorkOrderParts: 2023+ scope, lookup codes, Feb-29-safe cutoff, trim, VACUUM

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin dev
T="/c/Users/bfox/Documents/Git-Projects/data-projects/.claude/queries/adhoc/dp-migration-tools"
python "$T/wait_ci.py" && python "$T/git_sync.py" 73fd5443-240e-410a-990a-98827f32c087 && python "$T/run_item.py" 73fd5443-240e-410a-990a-98827f32c087 8328ba15-55d8-4f73-abb3-19ea2e5cb2fa RunNotebook
```
Expected: `Completed`. A DuckDB `DESCRIBE` of `Fact_WorkOrderParts` shows exactly 9 columns: TransactionDate (DATE), PartNumber, Quantity, SaleValue, Franchise, BranchCode, Description, CustomerNumber, InvoiceNumber.

---

### Task 7: Update `Build_Gold_PendingInspections` (wave 2)

**Files:**
- Modify: `.../Fact Tables/Inspections/Build_Gold_PendingInspections.Notebook/notebook-content.py`
- Modify: `fabric-workspace-docs/deploy/dp_backend_scope.json`

- [ ] **Step 1: Replace the code-list block**

Replace everything from `from pyspark.sql import functions as F` (line 68) through `print(f"Inspection code list: {len(INSPECTION_CODES)} codes (expect 113)")` (line 106) with:
```python
from pyspark.sql import functions as F

spark.conf.set("spark.sql.session.timeZone", "UTC")

# 2026-09-25 (Inspections migration): codes come from lookup_InspectionJobCodes
# (Build_Gold_InspectionJobCodes, wave 1), matched on TRIM(JobCode); output
# trimmed to the 8 columns the report and Build_Gold_ServiceRecommendations use.
INSPECTION_CODES = [r["JobCode"] for r in spark.read.table("lookup_InspectionJobCodes").select("JobCode").collect()]
assert len(INSPECTION_CODES) == 113 and len(set(INSPECTION_CODES)) == 113, (
    f"lookup_InspectionJobCodes must hold 113 distinct codes - found {len(INSPECTION_CODES)} "
    f"({len(set(INSPECTION_CODES))} distinct). Run Build_Gold_InspectionJobCodes first."
)
print(f"Inspection codes from lookup_InspectionJobCodes: {len(INSPECTION_CODES)}")
```

- [ ] **Step 2: Use TRIM and print the status breakdown before trimming**

Replace `    .filter(F.col("JobCode").isin(INSPECTION_CODES))` with `    .filter(F.trim(F.col("JobCode")).isin(INSPECTION_CODES))`.

Then, directly after `print(f"Pending inspection rows (non-Invoiced, inspection codes only): {pending.count():,}")`, add:
```python
print("StatusDisplay breakdown (expect only 'In Process' and 'WIP Finished Not Invoiced'):")
pending.groupBy("StatusDisplay").count().show(truncate=False)
```

- [ ] **Step 3: Trim the output and add VACUUM**

Replace everything from `fact_pending_inspections = (` (line 142) through `print("Gold build complete: Fact_PendingInspections written.")` (line 159) with:
```python
fact_pending_inspections = (
    joined
    .withColumnRenamed("Branch", "BranchCode")
    .withColumnRenamed("WorkOrder", "WorkOrderNumber")
    .withColumnRenamed("DaysSinceCreationDate", "DaysSinceCreation")
    .withColumn("IsInspection", F.lit(True))
    .select(
        "BranchCode", "WorkOrderNumber", "JobCode", "CreationDate", "LastLaborPunch",
        "DaysSinceCreation", "HoursWorked", "IsInspection",
    )
)

fact_count = fact_pending_inspections.count()
print(f"Fact_PendingInspections rows (one per pending inspection work order): {fact_count:,}")

fact_pending_inspections.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Fact_PendingInspections")
spark.conf.set("spark.databricks.delta.retentionDurationCheck.enabled", "false")
spark.sql("VACUUM delta.`Tables/Fact_PendingInspections` RETAIN 0 HOURS")
print("Gold build complete: Fact_PendingInspections written and vacuumed.")
```

- [ ] **Step 4: Replace the verification query that used the dropped `StatusDisplay`**

Replace everything from `status_breakdown = spark.sql("""` through `print(status_breakdown.to_string())` with:
```python
by_code = spark.sql("""
    SELECT JobCode, COUNT(*) AS RowCount
    FROM delta.`Tables/Fact_PendingInspections`
    GROUP BY JobCode ORDER BY RowCount DESC
""").toPandas()
print("\nPending rows by inspection code:")
print(by_code.to_string())
```

- [ ] **Step 5: Register, commit, push, wait for CI, run**

Append (with a comma first):
```json
    {"name": "Build_Gold_PendingInspections", "tier": "gold", "cadence": "daily", "wave": 2,
     "notebookId": "645d32c8-bff7-4462-b341-525e16b819f3", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
     "path": "workspaces/DP - Presentation - Dev/Fact Tables/Inspections/Build_Gold_PendingInspections.Notebook"}
```
```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
python -c "import json; json.load(open('deploy/dp_backend_scope.json', encoding='utf-8'))"
git add "workspaces/DP - Presentation - Dev/Fact Tables/Inspections/Build_Gold_PendingInspections.Notebook/notebook-content.py" deploy/dp_backend_scope.json
git commit -m "PendingInspections: lookup codes, trim, VACUUM

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin dev
T="/c/Users/bfox/Documents/Git-Projects/data-projects/.claude/queries/adhoc/dp-migration-tools"
python "$T/wait_ci.py" && python "$T/git_sync.py" 73fd5443-240e-410a-990a-98827f32c087 && python "$T/run_item.py" 73fd5443-240e-410a-990a-98827f32c087 645d32c8-bff7-4462-b341-525e16b819f3 RunNotebook
```
Expected: `Completed`. A DuckDB check shows 8 columns, and the row count is close to production's current `Fact_PendingInspections` count (135 on 09-23).

---

### Task 8: Update `Build_Gold_ServiceRecommendations` (wave 3)

**Files:**
- Modify: `.../Fact Tables/Inspections/Build_Gold_ServiceRecommendations.Notebook/notebook-content.py`
- Modify: `fabric-workspace-docs/deploy/dp_backend_scope.json`

The logic stays the same; only hygiene changes. It reads `Fact_LaborJobSummary` columns `IsInspection, InvoiceNumber, JobCode, WorkOrderNumber, JobType, InvoicedLaborAmount`, all of which were kept in Task 5, and `Fact_PendingInspections.JobCode`, kept in Task 7.

- [ ] **Step 1: Add the UTC pin**

Directly after `from pyspark.sql import functions as F` (line 63), insert a blank line and then `spark.conf.set("spark.sql.session.timeZone", "UTC")`.

- [ ] **Step 2: Add VACUUM**

Replace:
```python
fact_service_recommendations.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Fact_ServiceRecommendations")
print("Gold build complete: Fact_ServiceRecommendations written.")
```
with:
```python
fact_service_recommendations.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Fact_ServiceRecommendations")
spark.conf.set("spark.databricks.delta.retentionDurationCheck.enabled", "false")
spark.sql("VACUUM delta.`Tables/Fact_ServiceRecommendations` RETAIN 0 HOURS")
print("Gold build complete: Fact_ServiceRecommendations written and vacuumed.")
```

- [ ] **Step 3: Register (wave 3), commit, push, wait for CI, run, refresh endpoint metadata**

Append (with a comma first):
```json
    {"name": "Build_Gold_ServiceRecommendations", "tier": "gold", "cadence": "daily", "wave": 3,
     "notebookId": "fc54d368-ff80-4a81-8770-fb3a67f08db1", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
     "path": "workspaces/DP - Presentation - Dev/Fact Tables/Inspections/Build_Gold_ServiceRecommendations.Notebook"}
```
```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
python -c "import json; json.load(open('deploy/dp_backend_scope.json', encoding='utf-8'))"
git add "workspaces/DP - Presentation - Dev/Fact Tables/Inspections/Build_Gold_ServiceRecommendations.Notebook/notebook-content.py" deploy/dp_backend_scope.json
git commit -m "ServiceRecommendations: UTC pin, VACUUM; register as Inspections wave 3

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin dev
T="/c/Users/bfox/Documents/Git-Projects/data-projects/.claude/queries/adhoc/dp-migration-tools"
python "$T/wait_ci.py" && python "$T/git_sync.py" 73fd5443-240e-410a-990a-98827f32c087 && python "$T/run_item.py" 73fd5443-240e-410a-990a-98827f32c087 fc54d368-ff80-4a81-8770-fb3a67f08db1 RunNotebook
export PATH="$HOME/.local/bin:$PATH"; export PYTHONIOENCODING=utf-8
fab api -X post "workspaces/73fd5443-240e-410a-990a-98827f32c087/sqlEndpoints/18effb0e-7bc2-47a1-854c-f4f2e8129145/refreshMetadata"
python "$T/folder_check.py"
```
Expected: `Completed`, the metadata refresh is accepted, and `folder_check` reports 0 mismatches across 43 registered notebooks. All 5 Inspections notebooks should show `fabric='Fact Tables/Inspections'`.

---

### Task 9: Parity validation against production (stop gate)

**Files:**
- Create: `data-projects/.claude/queries/adhoc/dp-migration-tools/inspections_parity.py`

- [ ] **Step 1: Write the parity script**

```python
"""Inspections parity: DP_Presentation vs production LH_Master_Data.

Complete months only (through the last day of the previous month). Prints
differences with the ones the spec expects already accounted for:
  - LJS hours: NULL-ModifiedDate punches + 11 pre-2023-modified punches on
    2023+ jobs (Decision 1/2) -> 'expected_extra_hrs'
  - WOP: ~14 invoices production lost to its InTrans watermark gap (DP-only)
  - Pending / ServiceRecommendations: snapshot timing
Anything left in 'unexplained' goes to Brian before any change is made.
"""
from datetime import date, timedelta

import duckdb

con = duckdb.connect()
con.sql("SET TimeZone='UTC'; INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.sql("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
DP = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables/"
LH = "abfss://b48cdb35-7ce3-46de-96df-d70db77649cb@onelake.dfs.fabric.microsoft.com/3e74497b-8c51-4a1a-91a1-888c59118f48/Tables/"
ST = "abfss://ab15d64d-c7ba-415d-9bcf-7feb1ef9b201@onelake.dfs.fabric.microsoft.com/876255e0-d462-4697-adc1-4a655f5bb101/Tables/"
LAST = date.today().replace(day=1) - timedelta(days=1)
WOP_START = "2023-10-01"   # first full month after both sides' 3-year cutoffs
print(f"Comparing complete months through {LAST}\n")


def show(title, sql, limit=60):
    rows = con.sql(sql).fetchall()
    cols = [d[0] for d in con.sql(sql).description]
    print(f"=== {title} ({len(rows)} rows)")
    print("  " + " | ".join(cols))
    for r in rows[:limit]:
        print("  " + " | ".join(str(v) for v in r))
    if len(rows) > limit:
        print(f"  ... {len(rows) - limit} more")
    print()


# ---------- Fact_LaborJobSummary ----------
for tag, base in (("dp", DP), ("prod", LH)):
    con.sql(f"""CREATE TABLE ljs_{tag} AS
      SELECT BranchCode, strftime(CAST(WorkOrderCreationDate AS DATE), '%Y-%m') AS ym,
             COUNT(*) AS n, COUNT(*) FILTER (WHERE IsInspection) AS insp,
             COALESCE(SUM(CAST(ActualHoursWorked AS DOUBLE)), 0) AS hrs,
             COALESCE(SUM(CAST(InvoicedLaborAmount AS DOUBLE)), 0) AS labor
      FROM delta_scan('{base}Fact_LaborJobSummary')
      WHERE WorkOrderCreationDate IS NULL OR CAST(WorkOrderCreationDate AS DATE) <= DATE '{LAST}'
      GROUP BY ALL""")
    con.sql(f"""CREATE TABLE ljs_keys_{tag} AS
      SELECT DISTINCT BranchCode, CAST(WorkOrderNumber AS VARCHAR) AS wo, JobCode, JobType,
             strftime(CAST(WorkOrderCreationDate AS DATE), '%Y-%m') AS ym
      FROM delta_scan('{base}Fact_LaborJobSummary')
      WHERE WorkOrderCreationDate IS NULL OR CAST(WorkOrderCreationDate AS DATE) <= DATE '{LAST}'""")

con.sql(f"""CREATE TABLE extra AS
  WITH jobs AS (SELECT DISTINCT Branch, CAST(WorkOrder AS VARCHAR) AS wo, JobCode, JobType
                FROM delta_scan('{ST}Silver_WkOthSub') WHERE ModifiedDate >= TIMESTAMP '2023-01-01'),
       hdr AS (SELECT Branch, CAST(WorkOrder AS VARCHAR) AS wo, CAST(CreatedOn AS DATE) AS created
               FROM delta_scan('{ST}Silver_WkRoFile'))
  SELECT w.Branch AS BranchCode, strftime(h.created, '%Y-%m') AS ym,
         SUM(CAST(w.HoursWorked AS DOUBLE)) AS extra_hrs
  FROM delta_scan('{ST}Silver_WkMechWk') w
  JOIN jobs j ON j.Branch = w.Branch AND j.wo = CAST(w.WorkOrder AS VARCHAR)
             AND j.JobCode = w.JobCode AND j.JobType = w.JobType
  LEFT JOIN hdr h ON h.Branch = w.Branch AND h.wo = CAST(w.WorkOrder AS VARCHAR)
  WHERE w.ModifiedDate IS NULL OR w.ModifiedDate < TIMESTAMP '2023-01-01'
  GROUP BY ALL""")

con.sql("""CREATE TABLE ljs_diff AS
  SELECT COALESCE(d.BranchCode, p.BranchCode) AS br, COALESCE(d.ym, p.ym) AS ym,
         COALESCE(d.n, 0) - COALESCE(p.n, 0) AS d_rows,
         COALESCE(d.insp, 0) - COALESCE(p.insp, 0) AS d_insp,
         ROUND(COALESCE(d.labor, 0) - COALESCE(p.labor, 0), 2) AS d_labor,
         ROUND(COALESCE(d.hrs, 0) - COALESCE(p.hrs, 0), 2) AS d_hrs,
         ROUND(COALESCE(e.extra_hrs, 0), 2) AS expected_extra_hrs,
         ROUND(COALESCE(d.hrs, 0) - COALESCE(p.hrs, 0) - COALESCE(e.extra_hrs, 0), 2) AS unexplained_hrs
  FROM ljs_dp d
  FULL OUTER JOIN ljs_prod p ON d.BranchCode = p.BranchCode AND d.ym IS NOT DISTINCT FROM p.ym
  LEFT JOIN extra e ON e.BranchCode = COALESCE(d.BranchCode, p.BranchCode)
                   AND e.ym IS NOT DISTINCT FROM COALESCE(d.ym, p.ym)""")

show("LJS totals (dp vs prod)", """
  SELECT 'dp' side, SUM(n), SUM(insp), ROUND(SUM(hrs),1), ROUND(SUM(labor),2) FROM ljs_dp
  UNION ALL SELECT 'prod', SUM(n), SUM(insp), ROUND(SUM(hrs),1), ROUND(SUM(labor),2) FROM ljs_prod""")
show("LJS hours delta vs expected (all months)", """
  SELECT ROUND(SUM(d_hrs),1) d_hrs, ROUND(SUM(expected_extra_hrs),1) expected, ROUND(SUM(unexplained_hrs),1) unexplained
  FROM ljs_diff""")
show("LJS by month (all branches)", """
  SELECT ym, SUM(d_rows) d_rows, SUM(d_insp) d_insp, ROUND(SUM(d_labor),2) d_labor,
         ROUND(SUM(d_hrs),1) d_hrs, ROUND(SUM(expected_extra_hrs),1) exp_hrs, ROUND(SUM(unexplained_hrs),1) unexpl_hrs
  FROM ljs_diff GROUP BY ym ORDER BY ym""", limit=200)
show("LJS branch-months with UNEXPLAINED differences", """
  SELECT * FROM ljs_diff
  WHERE d_rows <> 0 OR d_insp <> 0 OR ABS(d_labor) > 0.01 OR ABS(unexplained_hrs) > 0.5
  ORDER BY ym, br""")
show("LJS job keys only in one side, by month", """
  SELECT COALESCE(a.ym, b.ym) ym,
         COUNT(*) FILTER (WHERE b.wo IS NULL) AS dp_only, COUNT(*) FILTER (WHERE a.wo IS NULL) AS prod_only
  FROM ljs_keys_dp a FULL OUTER JOIN ljs_keys_prod b
    ON a.BranchCode = b.BranchCode AND a.wo = b.wo AND a.JobCode = b.JobCode AND a.JobType = b.JobType
  WHERE a.wo IS NULL OR b.wo IS NULL GROUP BY 1 ORDER BY 1""", limit=200)

# ---------- Fact_WorkOrderParts ----------
for tag, base in (("dp", DP), ("prod", LH)):
    con.sql(f"""CREATE TABLE wop_{tag} AS
      SELECT BranchCode, CAST(InvoiceNumber AS VARCHAR) AS inv,
             strftime(CAST(TransactionDate AS DATE), '%Y-%m') AS ym,
             COUNT(*) AS n, SUM(CAST(SaleValue AS DOUBLE)) AS sale, SUM(CAST(Quantity AS DOUBLE)) AS qty
      FROM delta_scan('{base}Fact_WorkOrderParts')
      WHERE CAST(TransactionDate AS DATE) BETWEEN DATE '{WOP_START}' AND DATE '{LAST}'
      GROUP BY ALL""")
show("WOP by month", """
  SELECT COALESCE(d.ym, p.ym) ym, SUM(COALESCE(d.n,0)) - SUM(COALESCE(p.n,0)) d_rows,
         ROUND(SUM(COALESCE(d.sale,0)) - SUM(COALESCE(p.sale,0)), 2) d_sale,
         ROUND(SUM(COALESCE(d.qty,0)) - SUM(COALESCE(p.qty,0)), 2) d_qty
  FROM wop_dp d FULL OUTER JOIN wop_prod p ON d.BranchCode = p.BranchCode AND d.inv = p.inv AND d.ym = p.ym
  GROUP BY 1 ORDER BY 1""", limit=200)
show("WOP invoices only in DP (expect ~14 recovered from prod's watermark gap)", """
  SELECT d.BranchCode, d.inv, d.ym, d.n, ROUND(d.sale,2) FROM wop_dp d
  LEFT JOIN wop_prod p ON d.BranchCode = p.BranchCode AND d.inv = p.inv AND d.ym = p.ym
  WHERE p.inv IS NULL ORDER BY d.ym""")
show("WOP invoices only in PROD (expect none)", """
  SELECT p.BranchCode, p.inv, p.ym, p.n, ROUND(p.sale,2) FROM wop_prod p
  LEFT JOIN wop_dp d ON d.BranchCode = p.BranchCode AND d.inv = p.inv AND d.ym = p.ym
  WHERE d.inv IS NULL ORDER BY p.ym""")
show("WOP invoices in both with different lines/amounts", """
  SELECT d.BranchCode, d.inv, d.ym, d.n - p.n d_rows, ROUND(d.sale - p.sale, 2) d_sale
  FROM wop_dp d JOIN wop_prod p ON d.BranchCode = p.BranchCode AND d.inv = p.inv AND d.ym = p.ym
  WHERE d.n <> p.n OR ABS(d.sale - p.sale) > 0.01 ORDER BY d.ym""")

# ---------- Pending + ServiceRecommendations (snapshot tables) ----------
show("Pending counts", f"""
  SELECT 'dp', COUNT(*) FROM delta_scan('{DP}Fact_PendingInspections')
  UNION ALL SELECT 'prod', COUNT(*) FROM delta_scan('{LH}Fact_PendingInspections')""")
show("Pending keys only in one side", f"""
  WITH d AS (SELECT BranchCode, CAST(WorkOrderNumber AS VARCHAR) wo, JobCode FROM delta_scan('{DP}Fact_PendingInspections')),
       p AS (SELECT BranchCode, CAST(WorkOrderNumber AS VARCHAR) wo, JobCode FROM delta_scan('{LH}Fact_PendingInspections'))
  SELECT 'dp_only' side, * FROM (SELECT * FROM d EXCEPT SELECT * FROM p)
  UNION ALL SELECT 'prod_only', * FROM (SELECT * FROM p EXCEPT SELECT * FROM d)""")
show("ServiceRecommendations", f"""
  SELECT 'dp', COUNT(*), SUM(TimesAdded), COUNT(DISTINCT InspectionJobCode) FROM delta_scan('{DP}Fact_ServiceRecommendations')
  UNION ALL SELECT 'prod', COUNT(*), SUM(TimesAdded), COUNT(DISTINCT InspectionJobCode) FROM delta_scan('{LH}Fact_ServiceRecommendations')""")
```

- [ ] **Step 2: Run it and save the output**

Run: `python "/c/Users/bfox/Documents/Git-Projects/data-projects/.claude/queries/adhoc/dp-migration-tools/inspections_parity.py" > "<scratchpad>/inspections_parity_output.txt" 2>&1`, then read the whole file.

- [ ] **Step 3: Classify every difference**

- **LJS hours:** `unexplained` should be close to 0 overall, and roughly 0 for each complete month. `expected` should be about 36K hours in total (the NULL-ModifiedDate hours plus 17.1).
- **LJS rows, inspections, labor:** differences are allowed only where prod and DP read the source at different times. That shows up as small counts of keys present on only one side, concentrated in recent months. For any branch-month with an unexplained difference, pull 5 example keys from each side, check `Silver_WkOthSub.ModifiedDate` for them, and record the explanation.
- **WOP:** the DP-only invoices should be about 14 (production's watermark gap). There should be no prod-only invoices. Any "in both, different" row needs an explanation.
- **Pending and SR:** the differences should match the snapshot timing (production refreshed this morning; RepairOrderDetail was refreshed in Task 3).

- [ ] **Step 4: Stop gate (controller; don't dispatch)**

Commit the script:
```bash
cd "/c/Users/bfox/Documents/Git-Projects/data-projects"
git add .claude/queries/adhoc/dp-migration-tools/inspections_parity.py
git commit -m "Add Inspections DP-vs-production parity script

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin dev
```
Present Brian with the totals table, the month table, and each classified difference. **If anything is unexplained, stop and discuss it with Brian; don't change code to make the numbers match.** Continue to Task 10 only after Brian accepts the parity results.

---

### Task 10: Create the `.pbip` and edit the report TMDL (Desktop must be closed)

**Files:**
- Create: `fabric-workspace-docs/workspaces/RP - Dev/Inspections.pbip`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Inspections.SemanticModel/definition/tables/{Fact_LaborJobSummary,Fact_PendingInspections,Fact_WorkOrderParts,ServiceRecommendations,dim_BranchLocation,dim_CustomerList,dim_DateTable,dim_Parts}.tmdl`
- Create: `data-projects/.claude/queries/adhoc/dp-migration-tools/edit_inspections_tmdl.py`

- [ ] **Step 1: Confirm Desktop is closed (controller asks Brian)**

Ask Brian directly: "Is Inspections closed in Power BI Desktop?" Don't edit anything until he confirms. If Desktop has the report open, its in-memory model silently overwrites file edits.

- [ ] **Step 2: Create `Inspections.pbip`**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/pbip/pbipProperties/1.0.0/schema.json",
  "version": "1.0",
  "artifacts": [
    {
      "report": {
        "path": "Inspections.Report"
      }
    }
  ],
  "settings": {
    "enableAutoRecovery": true
  }
}
```

- [ ] **Step 3: Write the TMDL edit script**

```python
"""Repoint Inspections to DP_Presentation, trim columns, restore IsRolling12Months.

Run only while the report is CLOSED in Power BI Desktop.
"""
import re
import sys
from pathlib import Path

SM = Path(r"C:/Users/bfox/Documents/Git-Projects/fabric-workspace-docs/workspaces/RP - Dev/Inspections.SemanticModel/definition")
OLD_SRC = 'Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data")'
NEW_SRC = 'Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation")'

KEEP = {
    "Fact_LaborJobSummary": ["JobCode", "JobType", "InvoiceNumber", "BranchCode", "WorkOrderNumber",
                             "InvoicedLaborAmount", "IsInspection", "ActualHoursWorked", "WorkOrderCreationDate"],
    "Fact_PendingInspections": ["BranchCode", "WorkOrderNumber", "JobCode", "CreationDate", "LastLaborPunch",
                                "DaysSinceCreation", "HoursWorked", "IsInspection"],
    "Fact_WorkOrderParts": ["TransactionDate", "PartNumber", "Quantity", "SaleValue", "Franchise", "BranchCode",
                            "Description", "CustomerNumber", "InvoiceNumber"],
    "ServiceRecommendations": ["InspectionJobCode", "JobCode", "JobType", "CompletedInspections", "TimesAdded", "TotalLabor"],
    "dim_BranchLocation": ["Branch", "BranchID", "BranchName", "LocationID"],
    "dim_CustomerList": ["CustomerNumber", "PrimaryName"],
    "dim_DateTable": ["DateKey", "Date", "MonthYear", "SortableMonthYear"],
    "dim_Parts": ["PartNumber", "Description", "Franchise", "SellPrice1"],
}
EXPECTED_REMOVED = {
    "Fact_LaborJobSummary": 22, "Fact_PendingInspections": 4, "Fact_WorkOrderParts": 5,
    "ServiceRecommendations": 0, "dim_BranchLocation": 12, "dim_CustomerList": 53,
    "dim_DateTable": 62, "dim_Parts": 18,
}
DIMS = {"dim_BranchLocation", "dim_CustomerList", "dim_DateTable", "dim_Parts"}

ROLLING = [
    "\tcolumn IsRolling12Months = ```",
    "",
    "\t\t\tVAR RefDate = MAX('Data Refresh'[Date])",
    "\t\t\tVAR StartOfRollingPeriod = EOMONTH(RefDate, -12) + 1",
    "\t\t\tVAR EndOfRollingPeriod = EOMONTH(RefDate, 0)",
    "\t\t\tRETURN",
    "\t\t\tdim_DateTable[Date] >= StartOfRollingPeriod && dim_DateTable[Date] <= EndOfRollingPeriod",
    "\t\t\t```",
    "\t\tdataType: boolean",
    '\t\tformatString: """TRUE"";""TRUE"";""FALSE"""',
    "\t\tlineageTag: a89fe68a-1123-4db4-bf32-6b8cb601951d",
    "\t\tsummarizeBy: none",
    "\t\tisDataTypeInferred",
    "",
    "\t\tannotation SummarizationSetBy = Automatic",
    "",
]

COL_RE = re.compile(r"^\tcolumn ('([^']+)'|(\S+))(\s*=.*)?$")
TOP_RE = re.compile(r"^\t[^\t]")


def rewrite_columns(lines, table):
    out, kept, removed = [], [], []
    i = 0
    while i < len(lines):
        m = COL_RE.match(lines[i])
        if not m:
            out.append(lines[i])
            i += 1
            continue
        name, is_calc = m.group(2) or m.group(3), bool(m.group(4))
        j = i + 1
        while j < len(lines) and not TOP_RE.match(lines[j]):
            j += 1
        if table == "dim_DateTable" and name == "IsRolling12Months":
            out.extend(ROLLING)
            kept.append(name)
        elif is_calc or name in KEEP[table]:
            out.extend(lines[i:j])
            kept.append(name)
        else:
            while out and out[-1].startswith("\t///"):
                out.pop()
            removed.append(name)
        i = j
    return out, kept, removed


def main():
    ok = True
    for table, keep in KEEP.items():
        path = SM / "tables" / f"{table}.tmdl"
        raw = path.read_bytes().decode("utf-8")
        eol = "\r\n" if "\r\n" in raw else "\n"
        text = raw.replace("\r\n", "\n")

        n_src = text.count(OLD_SRC)
        assert n_src == (2 if table == "Fact_WorkOrderParts" else 1), f"{table}: {n_src} source strings"
        text = text.replace(OLD_SRC, NEW_SRC)

        if table in DIMS:
            old = (f'\t\t\t\t    dbo_{table} = Source{{[Schema="dbo",Item="{table}"]}}[Data]\n'
                   f'\t\t\t\tin\n\t\t\t\t    dbo_{table}')
            cols = ", ".join(f'"{c}"' for c in keep)
            new = (f'\t\t\t\t    dbo_{table} = Source{{[Schema="dbo",Item="{table}"]}}[Data],\n'
                   f'\t\t\t\t    #"Selected Columns" = Table.SelectColumns(dbo_{table}, {{{cols}}})\n'
                   f'\t\t\t\tin\n\t\t\t\t    #"Selected Columns"')
            assert text.count(old) == 1, f"{table}: partition tail not found exactly once"
            text = text.replace(old, new)

        lines, kept, removed = rewrite_columns(text.split("\n"), table)
        missing = [c for c in keep if c not in kept]
        print(f"{table}: removed {len(removed)} (expected {EXPECTED_REMOVED[table]}), missing keeps {missing}")
        if missing or len(removed) != EXPECTED_REMOVED[table]:
            ok = False
            print("   removed:", removed)
            continue
        path.write_bytes(eol.join(lines).encode("utf-8"))   # UTF-8, no BOM

    leftovers = [p.name for p in SM.rglob("*.tmdl") if "LH_Master_Data" in p.read_text(encoding="utf-8")]
    print("files still referencing LH_Master_Data:", leftovers)
    sys.exit(0 if ok and not leftovers else 1)


if __name__ == "__main__":
    main()
```

Note that a table which fails its checks is **not written**, while the others are. If the script exits 1, run `git checkout -- "workspaces/RP - Dev/Inspections.SemanticModel"`, fix the cause, and re-run, so no half-edited state survives.

- [ ] **Step 4: Run it**

Run: `python "/c/Users/bfox/Documents/Git-Projects/data-projects/.claude/queries/adhoc/dp-migration-tools/edit_inspections_tmdl.py"`
Expected: every table prints `removed N (expected N), missing keeps []`, followed by `files still referencing LH_Master_Data: []` and exit 0.

- [ ] **Step 5: Review the diff**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git diff --stat -- "workspaces/RP - Dev/Inspections.SemanticModel"
git diff -- "workspaces/RP - Dev/Inspections.SemanticModel/definition/tables/dim_DateTable.tmdl" | head -80
grep -n "IsRolling12Months\|a89fe68a" "workspaces/RP - Dev/Inspections.SemanticModel/definition/tables/dim_DateTable.tmdl"
grep -rn "Table.SelectColumns\|DP_Presentation" "workspaces/RP - Dev/Inspections.SemanticModel/definition/tables/" | wc -l
```
Expected:
- Only the 8 table files have changed.
- The `IsRolling12Months` DAX block is present with lineageTag `a89fe68a-…`.
- The last command prints `13`: 9 DP_Presentation source lines (8 partitions plus the WorkOrderParts refresh policy) and 4 SelectColumns lines.
- There are no `//` comment lines; TMDL doesn't allow them.

- [ ] **Step 6: Confirm Desktop is still closed, then commit and push**

Controller confirms with Brian again, then:
```bash
git add "workspaces/RP - Dev/Inspections.pbip" \
  "workspaces/RP - Dev/Inspections.SemanticModel/definition/tables/Fact_LaborJobSummary.tmdl" \
  "workspaces/RP - Dev/Inspections.SemanticModel/definition/tables/Fact_PendingInspections.tmdl" \
  "workspaces/RP - Dev/Inspections.SemanticModel/definition/tables/Fact_WorkOrderParts.tmdl" \
  "workspaces/RP - Dev/Inspections.SemanticModel/definition/tables/ServiceRecommendations.tmdl" \
  "workspaces/RP - Dev/Inspections.SemanticModel/definition/tables/dim_BranchLocation.tmdl" \
  "workspaces/RP - Dev/Inspections.SemanticModel/definition/tables/dim_CustomerList.tmdl" \
  "workspaces/RP - Dev/Inspections.SemanticModel/definition/tables/dim_DateTable.tmdl" \
  "workspaces/RP - Dev/Inspections.SemanticModel/definition/tables/dim_Parts.tmdl"
git commit -m "Inspections: add .pbip, repoint to DP_Presentation, trim columns, restore IsRolling12Months

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin dev
python "/c/Users/bfox/Documents/Git-Projects/data-projects/.claude/queries/adhoc/dp-migration-tools/wait_ci.py"
cd "/c/Users/bfox/Documents/Git-Projects/data-projects"
git add .claude/queries/adhoc/dp-migration-tools/edit_inspections_tmdl.py
git commit -m "Add Inspections TMDL repoint/trim script

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin dev
```
Inspections isn't in `deploy_reports.py`, so CI doesn't deploy the report; it only redeploys the backend notebooks, which is harmless.

---

### Task 11: Brian validates and publishes in Desktop (Brian's step; don't dispatch)

- [ ] **Step 1: Give Brian these steps**

1. In `fabric-workspace-docs`, `git pull` on `dev`, then open `workspaces/RP - Dev/Inspections.pbip` in Desktop.
2. Refresh all. If Desktop asks for credentials to the DP_Presentation SQL endpoint, sign in with organizational credentials.
3. Check each page against production's Inspections report:
   - Home/hero totals
   - the Rolling 12 bookmark or visual (IsRolling12Months)
   - Pending
   - Recommendations
   - work order drill-through

   Expected differences are more labor hours in 2023–24 (the NULL-ModifiedDate fix) and small recent-month and snapshot differences.
4. Publish to **RP - Dev**, replacing the existing report.
5. In the RP - Dev workspace, **Source control → Commit**.

- [ ] **Step 2: Wait for Brian's confirmation**

Don't start Task 12 until Brian confirms the report is published and committed.

---

### Task 12: Post-publish verification and docs

**Files:**
- Modify: `data-projects/docs/architecture/report-migration-catalog.md`
- Modify: memory `project_inspections_migration.md`, `project_report_migration_catalog.md`, `MEMORY.md`

- [ ] **Step 1: Pull Brian's commit and check the model**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git fetch origin && git merge origin/dev
grep -rln "LH_Master_Data" "workspaces/RP - Dev/Inspections.SemanticModel/" || echo "no LH_Master_Data references"
grep -n "a89fe68a-1123-4db4-bf32-6b8cb601951d" "workspaces/RP - Dev/Inspections.SemanticModel/definition/tables/dim_DateTable.tmdl"
git status --short -- "workspaces/RP - Dev/"
```
Expected:
- `no LH_Master_Data references`.
- The lineageTag is still present.
- `git status` shows nothing unexpected under RP - Dev. If any file outside Inspections changed, especially bookmarks or filters on another report, stop and tell Brian; that's the known pbir side-effect pattern.

- [ ] **Step 2: Bookmark integrity**

```bash
git diff HEAD~1 --stat -- "workspaces/RP - Dev/Inspections.Report/definition/bookmarks/"
grep -l "IsRolling12Months" "workspaces/RP - Dev/Inspections.Report/definition/bookmarks/"*.json | wc -l
```
Expected: 6 bookmark files still reference `IsRolling12Months`.

- [ ] **Step 3: Update the migration catalog**

In `docs/architecture/report-migration-catalog.md`, set the Inspections row to **COMPLETE (2026-09-25)** and add a completion narrative that covers:
- the 5-notebook chain and its waves
- the lookup table
- the 2023+ scope
- the NULL-ModifiedDate production under-count fixed (with the hours delta figures from Task 9)
- the Feb-29 fix
- the trims
- IsRolling12Months restored
- the CI folder-flattening fix
- the parity results summary

Update the status header so Customer Anatomy is the only report remaining.

- [ ] **Step 4: Update memory**

- `project_inspections_migration.md`: mark it COMPLETE and add the parity numbers and anything Brian flagged in Task 11.
- `project_report_migration_catalog.md`: add a short Inspections section.
- `MEMORY.md`: change the Inspections line to COMPLETE.

- [ ] **Step 5: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/data-projects"
git add docs/architecture/report-migration-catalog.md
git commit -m "Document Inspections migration completion

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin dev
```
Remind Brian that Sandbox validation comes later, per the roadmap.
