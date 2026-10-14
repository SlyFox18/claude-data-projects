# DP Prod Tier Build-out Implementation Plan

> **Progress 2026-10-07:**
> - **Task 10 done.**
>   - The four-pass first run is complete. Seeding also needed the 6 manual-cadence Gold items and 2 uploaded CSVs, which no deploy copies.
>   - The first runs failed with 403 because the pipeline ran as the CI service principal (the last modifier). Fixed by `deploy/claim_prod_pipeline.py`, which must run after every deploy.
>   - Snapshot appends needed a schema cast (PR #19).
> - **Task 11:**
>   - `compare_tiers.py` was built. It also needed DOUBLE values rounded to 6 decimals.
>   - Back-to-back comparisons found non-deterministic notebooks plus a Silver_InTrans key bug that dropped about 150K rows.
>   - Fixed in PR #20 (Brian's decisions: dim_Parts company-wide; Parts Not Re-Ordered sums quantities) and PR #21 (BranchKey and two row-order dedups).
>   - Rules written up in `docs/architecture/dp-notebook-rules.md`.
>   - The final comparison is running on 2026-10-07.
> - **Task 12 done:** "DP Backend: Dev and Prod" in fabric-workspace-docs `OPERATIONS-GUIDE.md`, plus a README section.
>
> **Progress 2026-10-05:**
> - **Tasks 1–9 done.**
>   - Code: commits 5a7143d3 through 8f32f2e5.
>   - Prod workspaces disconnected from Git.
>   - The CI service principal is a User on the 3 dataflow connections. The Outlook and Teams connections can't be shared, so notifications moved to Graph: plan `2026-10-05-dp-refresh-notifications-graph.md`.
>   - First PR #17 merged after `main` was merged into `dev` (`dev` and `main` had diverged).
>   - Prod deploy run 37337445301: 36 + 72 items; all IDs checked as Prod.
>   - Staging shortcuts are created (33). The 29 Presentation shortcuts to Silver can't be created until their target tables exist.
> - **Task 10 amended. The first Prod run goes in four passes:**
>   1. `mode=items` with every Staging item;
>   2. `deploy/sync_shortcuts.py --apply`;
>   3. the snapshot-history copy;
>   4. `mode=all`.
>
>   Prod `Pipeline_DP_Refresh` is `1fa19eb8-7d5f-465e-b7e7-b31e02e56a2c` in workspace `7836042d-…`.
> - **Production workspaces sync from different branches:**
>   - **`main`:** RP - Parts Reports, RP - Financial Reports and the three LH - *_Data_Prep workspaces.
>   - **`dev`:** RP - Service Reports, LH_Master_Data, RP - Sandbox, RP - Dev, JD_FabricOneLake and Shannon.
>
>   The report-promotion plan has to settle this.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the full DP backend in `DP - Staging - Prod` and `DP - Presentation - Prod`, deployed by CI (fabric-cicd) from `main`. Prove it with a full Prod run whose Gold output matches Dev table for table.

**Architecture:**
- **Code lives once,** in the Dev workspace folders of `fabric-workspace-docs`. The Prod workspaces are disconnected from Git and receive items only from fabric-cicd, run by a manual "Deploy Prod" workflow on `main`.
- **What gets deployed** comes from `deploy/dp_refresh_dag.json` (the same config the refresh orchestrator uses), plus the two orchestrators and `Pipeline_DP_Refresh`.
- **Dev → Prod ID swaps:**
  - `parameter.yml` swaps the Dev workspace and lakehouse IDs to Prod.
  - The one cross-workspace item ID (Presentation's pipeline calling Staging's orchestrator) is resolved at deploy time.
- **Run as Brian:**
  - Lakehouse shortcuts are created by an idempotent script that runs as Brian.
  - One-off data moves, such as the snapshot history copy, run through a git-tracked one-off notebook runner.
  - The Prod pipeline has no schedule in this plan.

**Tech Stack:** Python 3.12, fabric-cicd 1.3.0, the Fabric REST API (through `fab api` for operator scripts; through an SPN token in CI), DuckDB `delta_scan` for verification, pytest, and GitHub Actions.

**Repos:**
- `F` = `C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs`, all code; branch `dev`, PR to `main`.
- `D` = `C:\Users\bfox\Documents\Git-Projects\data-projects`, this plan and docs.

**Decisions (Brian, 2026-10-02):**
1. The Prod workspaces are disconnected from Git; fabric-cicd deploys from `main`.
2. Branch flow: `dev` → PR → `main` → manual "Deploy Prod" workflow.
3. Snapshot history is copied from Dev to Prod once.
4. The Prod refresh runs as Brian at first; moving it to the SPN is a separate, tested step before cutover (see "Next").

**Prod schedule stays OFF.** This plan never creates a schedule, so the old and new pipelines don't use capacity at the same time.

**Known IDs**

| Thing | Dev | Prod |
|---|---|---|
| DP - Staging workspace | `ab15d64d-c7ba-415d-9bcf-7feb1ef9b201` | `189e5c0a-548a-4feb-93d6-dda9ebbe96c1` |
| DP_Staging lakehouse | `876255e0-d462-4697-adc1-4a655f5bb101` | `6713bd45-a4ad-47e6-8bff-1bb0415e9784` |
| DP - Presentation workspace | `73fd5443-240e-410a-990a-98827f32c087` | `7836042d-adb1-4846-b70d-bd42980054c5` |
| DP_Presentation lakehouse | `966efc8a-16f9-423b-aa43-e368fcd8fb91` | `29d9df80-a383-4d40-9807-1e2e6cbff88f` |
| JD Bronze (same in both) | workspace `4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9`, lakehouse `7348c3a6-8694-4d11-bc70-1bd55be84ea2` | same |
| CI service principal | `4d783e19-0965-45c3-9c66-96b664d7cd72` | |

**Connections the deployed items use** (tenant-wide; the same IDs work in Prod):
- Outlook `97d3696e-b886-4770-9fd0-f4aae4c6a7ed` and Teams `4d11db48-257d-4c9d-9773-961f7ad419a4`, used by the pipeline.
- Dataflow connections: Lakehouse `ec4b2ec8-cf80-4ab1-a47d-f018c5be7b6c`, ODBC `70ea8af2-b529-4843-aee6-28297801fe71`, SharePoint `42db34a4-fef6-4221-aac7-18ff87e019ec`.

---

## File Structure (repo F unless noted)

| File | Responsibility |
|---|---|
| `deploy/orchestrator_core.py` (modify) | `report_workspace(settings, env)`: `None` when an environment has no report workspace yet |
| `deploy/orchestrator_glue.py` (modify) | Skip model refresh with a warning when `report_workspace` is `None` |
| `deploy/prod_scope.py` (new) | Which item folders deploy to each Prod workspace, derived from the DAG config |
| `deploy/params.py` (new) | Append deploy-time literal find/replace rules to a staged `parameter.yml` |
| `deploy/fabric_ids.py` (new) | Look up an item ID by name and type in a workspace (SPN token) |
| `deploy/deploy_backend.py` (modify) | Prod path: Staging deploy → resolve IDs → Presentation deploy → write the config |
| `parameter.yml` (modify) | Workspace/lakehouse swap rules also apply to Dataflow and DataPipeline |
| `deploy/sync_shortcuts.py` (new) | Create missing Prod lakehouse shortcuts from the Dev shortcut files (runs as the operator) |
| `deploy/merge_preview.py` (new) | Before a `dev`→`main` PR: what changes under each workspace folder, with production folders flagged |
| `deploy/run_oneoff_notebook.py` (new) | Create or update a notebook in a workspace from a git folder, run it and wait (operator) |
| `deploy/oneoff/Utilities_CopySnapshotHistoryToProd_20261002.Notebook/` (new) | Copies the 2 snapshot tables from Dev Gold to Prod Gold |
| `deploy/compare_tiers.py` (new) | Prod Gold vs Dev Gold: row counts plus a full-row multiset diff for every Gold table |
| `.github/workflows/deploy.yml` (modify) | Prod job: drop the stale `run_and_verify_notebooks.py` step |
| Tests: `deploy/test_*.py` (new/modify) | Unit tests for each pure function above |

---

### Task 1: Orchestrator skips model refresh when an environment has no report workspace

Without this, a Prod run fails at the end with `KeyError: 'Prod'`. `orchestrator.reportWorkspace` only has `{"Dev": "RP - Dev"}`, and no reports read DP Prod until promotion.

**Files:** Modify `deploy/orchestrator_core.py`, `deploy/orchestrator_glue.py:351-356`; Test `deploy/test_orchestrator_core.py`.

- [ ] **Step 1: Write the failing test** (append to `deploy/test_orchestrator_core.py`)

```python
from orchestrator_core import report_workspace


def test_report_workspace_returns_configured_workspace():
    assert report_workspace({"reportWorkspace": {"Dev": "RP - Dev"}}, "Dev") == "RP - Dev"


def test_report_workspace_is_none_when_env_not_configured():
    assert report_workspace({"reportWorkspace": {"Dev": "RP - Dev"}}, "Prod") is None


def test_report_workspace_is_none_when_setting_missing():
    assert report_workspace({}, "Prod") is None
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `cd F && python -m pytest deploy/test_orchestrator_core.py -q -k report_workspace`
Expected: FAIL with `ImportError: cannot import name 'report_workspace'`.

- [ ] **Step 3: Implement** (add to `deploy/orchestrator_core.py`, after `models_for_run`)

```python
def report_workspace(settings: dict, env: str):
    """Report workspace whose models a run in this environment refreshes, or None when the
    environment has none yet (Prod before report promotion): the run then skips model refresh."""
    return (settings.get("reportWorkspace") or {}).get(env)
```

- [ ] **Step 4: Use it in the glue.** In `deploy/orchestrator_glue.py`, replace lines 351-356 (from `workspace = SETTINGS["reportWorkspace"][ENV]` through `summary["tier_seconds"]["models"] = ...`) with:

```python
                workspace = report_workspace(SETTINGS, ENV)
                if workspace is None:
                    summary["warnings"].append(f"no report workspace configured for {ENV}; models not refreshed")
                else:
                    t0 = time.time()
                    with ThreadPoolExecutor(max_workers=int(SETTINGS["modelRefreshParallelism"])) as pool:
                        futures = {m: pool.submit(refresh_model, m, workspace) for m in models_for_run(CONFIG, mode)}
                    summary["models"] = {m: f.result() for m, f in futures.items()}
                    summary["tier_seconds"]["models"] = time.time() - t0
```

No import is needed. `render_orchestrator.py` pastes `orchestrator_core.py` above `orchestrator_glue.py` in the same notebook, so `report_workspace` is already defined where the glue runs.

- [ ] **Step 5: Run the tests, render, and check**

Run: `cd F && python -m pytest deploy -q && python deploy/render_orchestrator.py && python deploy/dag_check.py`
Expected: all tests pass; both `Run_DP_Refresh.Notebook` files are re-rendered; dag_check prints `OK`.

- [ ] **Step 6: Commit and sync Dev** (Dev behavior doesn't change, because Dev has a report workspace)

```bash
git add deploy/orchestrator_core.py deploy/orchestrator_glue.py deploy/test_orchestrator_core.py "workspaces/DP - Staging - Dev/Orchestration/Run_DP_Refresh.Notebook" "workspaces/DP - Presentation - Dev/Orchestration/Run_DP_Refresh.Notebook"
git commit -m "Orchestrator: skip model refresh when the environment has no report workspace (Prod before promotion)"
git push origin dev
```
Then run `python D/tools/dp-migration/wait_ci.py`, followed by `git_sync.py` for both DP Dev workspaces.

---

### Task 2: Prod deploy scope from the DAG config

**Files:** Create `deploy/prod_scope.py`, `deploy/test_prod_scope.py`.

What deploys:
- every DAG `items` entry of type `notebook` or `dataflow`;
- `Run_DP_Refresh` in both workspaces (it's in `excluded`, but as an orchestrator, not a non-producer);
- `Pipeline_DP_Refresh`.

What doesn't:
- lakehouses (they already exist; their shortcuts come from Task 6);
- utilities (`Utilities_*`), `Proto_FailProbe`, and the unused variable library.

- [ ] **Step 1: Write the failing tests** (`deploy/test_prod_scope.py`)

```python
import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent))
from prod_scope import prod_items  # noqa: E402


def _item(root: Path, ws: str, rel: str, item_type: str, name: str) -> Path:
    p = root / "workspaces" / ws / rel
    p.mkdir(parents=True)
    (p / ".platform").write_text(json.dumps({"metadata": {"type": item_type, "displayName": name}}), encoding="utf-8")
    return p


def _config(items, excluded=()):
    return {"items": items, "excluded": list(excluded), "reports": [], "orchestrator": {}}


def test_prod_items_maps_items_to_their_workspace_folders(tmp_path):
    s = _item(tmp_path, "DP - Staging - Dev", "Build_Silver_A.Notebook", "Notebook", "Build_Silver_A")
    d = _item(tmp_path, "DP - Staging - Dev", "Raw/df_X.Dataflow", "Dataflow", "df_X")
    g = _item(tmp_path, "DP - Presentation - Dev", "Fact Tables/Build_Gold_B.Notebook", "Notebook", "Build_Gold_B")
    o1 = _item(tmp_path, "DP - Staging - Dev", "Orchestration/Run_DP_Refresh.Notebook", "Notebook", "Run_DP_Refresh")
    o2 = _item(tmp_path, "DP - Presentation - Dev", "Orchestration/Run_DP_Refresh.Notebook", "Notebook", "Run_DP_Refresh")
    pl = _item(tmp_path, "DP - Presentation - Dev", "Pipelines/Pipeline_DP_Refresh.DataPipeline", "DataPipeline", "Pipeline_DP_Refresh")
    _item(tmp_path, "DP - Presentation - Dev", "Utilities_X.Notebook", "Notebook", "Utilities_X")
    cfg = _config([
        {"name": "Build_Silver_A", "type": "notebook", "workspace": "staging"},
        {"name": "df_X", "type": "dataflow", "workspace": "staging"},
        {"name": "Build_Gold_B", "type": "notebook", "workspace": "presentation"},
    ])

    result = prod_items(tmp_path, cfg)

    assert sorted(result["staging"]) == sorted([s, d, o1])
    assert sorted(result["presentation"]) == sorted([g, o2, pl])


def test_prod_items_raises_when_a_registered_item_has_no_folder(tmp_path):
    _item(tmp_path, "DP - Staging - Dev", "Orchestration/Run_DP_Refresh.Notebook", "Notebook", "Run_DP_Refresh")
    _item(tmp_path, "DP - Presentation - Dev", "Orchestration/Run_DP_Refresh.Notebook", "Notebook", "Run_DP_Refresh")
    _item(tmp_path, "DP - Presentation - Dev", "Pipelines/Pipeline_DP_Refresh.DataPipeline", "DataPipeline", "Pipeline_DP_Refresh")
    cfg = _config([{"name": "Build_Silver_Missing", "type": "notebook", "workspace": "staging"}])

    with pytest.raises(FileNotFoundError, match="Build_Silver_Missing"):
        prod_items(tmp_path, cfg)


def test_prod_items_raises_on_duplicate_display_names(tmp_path):
    _item(tmp_path, "DP - Staging - Dev", "A/Build_Silver_A.Notebook", "Notebook", "Build_Silver_A")
    _item(tmp_path, "DP - Staging - Dev", "B/Build_Silver_A.Notebook", "Notebook", "Build_Silver_A")
    cfg = _config([{"name": "Build_Silver_A", "type": "notebook", "workspace": "staging"}])

    with pytest.raises(ValueError, match="Build_Silver_A"):
        prod_items(tmp_path, cfg)
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `cd F && python -m pytest deploy/test_prod_scope.py -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'prod_scope'`.

- [ ] **Step 3: Implement** (`deploy/prod_scope.py`)

```python
"""Which Dev item folders the Prod deploy publishes to each Prod workspace.

Source of truth is deploy/dp_refresh_dag.json: every notebook/dataflow item, plus the two
Run_DP_Refresh orchestrators and Pipeline_DP_Refresh. Lakehouses are not deployed (they exist;
shortcuts come from sync_shortcuts.py); utilities, prototypes and the unused variable library
are not deployed.
"""
import json
from pathlib import Path

DEV_FOLDERS = {"staging": "DP - Staging - Dev", "presentation": "DP - Presentation - Dev"}
TYPE_SUFFIX = {"notebook": "Notebook", "dataflow": "Dataflow"}
ALWAYS = [("staging", "Notebook", "Run_DP_Refresh"),
          ("presentation", "Notebook", "Run_DP_Refresh"),
          ("presentation", "DataPipeline", "Pipeline_DP_Refresh")]


def _index(workspace_dir: Path) -> dict:
    """{(fabric type, displayName): [folder, ...]} for every item folder in a workspace directory."""
    found = {}
    for platform in workspace_dir.rglob(".platform"):
        meta = json.loads(platform.read_text(encoding="utf-8"))["metadata"]
        found.setdefault((meta["type"], meta["displayName"]), []).append(platform.parent)
    return found


def prod_items(repo_root: Path, config: dict) -> dict:
    """{"staging": [item folder, ...], "presentation": [...]} to publish to the Prod workspaces."""
    indexes = {ws: _index(repo_root / "workspaces" / folder) for ws, folder in DEV_FOLDERS.items()}
    wanted = [(i["workspace"], TYPE_SUFFIX[i["type"]], i["name"]) for i in config["items"]] + ALWAYS
    result = {"staging": [], "presentation": []}
    for ws, fabric_type, name in wanted:
        folders = indexes[ws].get((fabric_type, name), [])
        if not folders:
            raise FileNotFoundError(f"{fabric_type} {name} not found under workspaces/{DEV_FOLDERS[ws]}")
        if len(folders) > 1:
            raise ValueError(f"{fabric_type} {name} has {len(folders)} folders: {[str(f) for f in folders]}")
        result[ws].append(folders[0])
    return result
```

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `cd F && python -m pytest deploy/test_prod_scope.py -q`
Expected: 3 passed.

- [ ] **Step 5: Run it against the real repo**

Run: `cd F && python -c "import json,sys; sys.path.insert(0,'deploy'); from prod_scope import prod_items; from pathlib import Path; r=prod_items(Path('.'), json.load(open('deploy/dp_refresh_dag.json',encoding='utf-8'))); print({k: len(v) for k, v in r.items()})"`
Expected, as of 2026-10-02: `{'staging': 36, 'presentation': 71}`. Staging is 30 Silver notebooks, 5 dataflows and 1 orchestrator; Presentation is 69 Gold notebooks, 1 orchestrator and 1 pipeline. In general, each workspace's DAG notebook and dataflow count plus its orchestrator (and the pipeline for Presentation). Any exception names the item to fix.

- [ ] **Step 6: Commit**

```bash
git add deploy/prod_scope.py deploy/test_prod_scope.py
git commit -m "Deploy: Prod deploy scope derived from dp_refresh_dag.json"
```

---

### Task 3: Deploy-time parameter rules and item-ID lookup

`Pipeline_DP_Refresh` calls the Staging orchestrator by its **Dev item ID**, `f7e553a7-7597-469b-8ba8-5736d0775d8d`, in another workspace. Nobody knows the Prod ID until the Staging deploy creates the item, so the deploy looks up both IDs by name and appends a literal rule to the staged `parameter.yml`.

**Files:** Create `deploy/params.py`, `deploy/fabric_ids.py`, `deploy/test_params.py`.

- [ ] **Step 1: Write the failing tests** (`deploy/test_params.py`)

```python
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from params import append_rules  # noqa: E402

BASE = 'find_replace:\n  - find_value: "aaa"\n    replace_value:\n      dev: "aaa"\n      prod: "bbb"\n    item_type: "Notebook"\n'


def test_append_rules_adds_literal_rule_under_find_replace(tmp_path):
    f = tmp_path / "parameter.yml"
    f.write_text(BASE, encoding="utf-8")

    append_rules(f, [("dev-id-1", "prod-id-1", "DataPipeline")])

    text = f.read_text(encoding="utf-8")
    assert text.startswith(BASE)
    assert ('  - find_value: "dev-id-1"\n    replace_value:\n      dev: "dev-id-1"\n'
            '      prod: "prod-id-1"\n    item_type: "DataPipeline"\n') in text


def test_append_rules_handles_file_without_trailing_newline(tmp_path):
    f = tmp_path / "parameter.yml"
    f.write_text(BASE.rstrip("\n"), encoding="utf-8")

    append_rules(f, [("x", "y", "DataPipeline")])

    assert '\n  - find_value: "x"' in f.read_text(encoding="utf-8")
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `cd F && python -m pytest deploy/test_params.py -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'params'`.

- [ ] **Step 3: Implement** (`deploy/params.py`)

```python
"""Append literal find/replace rules to a staged parameter.yml (rules whose Prod value is only
known at deploy time, e.g. an item ID created by an earlier step of the same deploy)."""
from pathlib import Path


def append_rules(parameter_file: Path, rules: list) -> None:
    """rules: [(dev_value, prod_value, item_type)]. parameter.yml's only top-level key is
    find_replace, so appended list items land under it."""
    text = parameter_file.read_text(encoding="utf-8")
    if not text.endswith("\n"):
        text += "\n"
    for dev_value, prod_value, item_type in rules:
        text += (f'  - find_value: "{dev_value}"\n'
                 f'    replace_value:\n'
                 f'      dev: "{dev_value}"\n'
                 f'      prod: "{prod_value}"\n'
                 f'    item_type: "{item_type}"\n')
    parameter_file.write_text(text, encoding="utf-8")
```

And `deploy/fabric_ids.py`. It's covered by Task 9's real run, not a unit test, because it's a thin HTTP call:

```python
"""Look up a Fabric item's ID by display name and type (SPN token from lib.get_credential)."""
import requests

from lib import get_credential

FABRIC_API = "https://api.fabric.microsoft.com/v1"


def find_item_id(workspace_id: str, display_name: str, item_type: str) -> str:
    token = get_credential().get_token("https://api.fabric.microsoft.com/.default").token
    r = requests.get(f"{FABRIC_API}/workspaces/{workspace_id}/items", params={"type": item_type},
                     headers={"Authorization": f"Bearer {token}"}, timeout=60)
    r.raise_for_status()
    matches = [i["id"] for i in r.json()["value"] if i["displayName"] == display_name]
    if len(matches) != 1:
        raise LookupError(f"{item_type} {display_name!r} in workspace {workspace_id}: {len(matches)} matches")
    return matches[0]
```

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `cd F && python -m pytest deploy/test_params.py -q`
Expected: 2 passed.

- [ ] **Step 5: Commit**

```bash
git add deploy/params.py deploy/fabric_ids.py deploy/test_params.py
git commit -m "Deploy: deploy-time parameter rules + item-id lookup"
```

---

### Task 4: parameter.yml covers dataflows and the pipeline

Today the four workspace and lakehouse swap rules only apply to `item_type: "Notebook"`. Dataflow destinations and the pipeline's Staging `workspaceId` use the same Dev IDs.

**Files:** Modify `parameter.yml` (repo root of F).

- [ ] **Step 1: Edit.** In each of the four rules (find values `876255e0-…`, `ab15d64d-…`, `966efc8a-…`, `73fd5443-…`), change `item_type: "Notebook"` to:

```yaml
    item_type: ["Notebook", "Dataflow", "DataPipeline"]
```

Leave the two report rules as they are.

- [ ] **Step 2: Check that every Dev ID in a deployed item has a rule.** Run this check (Task 2 must already be done):

```bash
cd F && python - <<'EOF'
import json, re, sys
from pathlib import Path
sys.path.insert(0, "deploy")
from prod_scope import prod_items
rules = set(re.findall(r'find_value: "([0-9a-f-]{36})"', Path("parameter.yml").read_text(encoding="utf-8")))
dev = {"ab15d64d-c7ba-415d-9bcf-7feb1ef9b201", "876255e0-d462-4697-adc1-4a655f5bb101",
       "73fd5443-240e-410a-990a-98827f32c087", "966efc8a-16f9-423b-aa43-e368fcd8fb91"}
items = prod_items(Path("."), json.load(open("deploy/dp_refresh_dag.json", encoding="utf-8")))
for folder in items["staging"] + items["presentation"]:
    for f in folder.rglob("*"):
        if f.is_file() and f.name != ".platform":
            for g in dev & set(re.findall(r"[0-9a-f-]{36}", f.read_text(encoding="utf-8", errors="ignore"))):
                assert g in rules, (str(f), g)
print("every Dev workspace/lakehouse ID in deployed items has a parameter rule:", sorted(dev & rules) == sorted(dev))
EOF
```
Expected: prints `... True` and raises no assertion.

- [ ] **Step 3: Commit**

```bash
git add parameter.yml
git commit -m "parameter.yml: Dev->Prod workspace/lakehouse swaps also apply to dataflows and the pipeline"
```

---

### Task 5: deploy_backend.py Prod path

**Files:** Modify `deploy/deploy_backend.py` (the `else:` Prod branch and the config writes); modify `.github/workflows/deploy.yml` (remove the `Run and verify Prod-tier notebooks` step); delete nothing else.

- [ ] **Step 1: Replace the Prod branch.** In `main()`, replace the whole `else:` block (the two Staging and Presentation `deploy(...)` calls) and everything after it with:

```python
    else:
        dag = json.loads((REPO_ROOT / "deploy" / "dp_refresh_dag.json").read_text(encoding="utf-8"))
        items = prod_items(REPO_ROOT, dag)

        staging_stage = stage_items(REPO_ROOT, items["staging"])
        deploy(workspace_id=ids["staging"], repository_directory=staging_stage,
               item_type_in_scope=["Notebook", "Dataflow"], environment=environment)
        print(f"Deployed {len(items['staging'])} items to the {environment} staging workspace.")

        # Pipeline_DP_Refresh calls the Staging orchestrator by item ID in another workspace.
        dev_orch = find_item_id(WORKSPACE_IDS["dev"]["staging"], "Run_DP_Refresh", "Notebook")
        prod_orch = find_item_id(ids["staging"], "Run_DP_Refresh", "Notebook")
        presentation_stage = stage_items(REPO_ROOT, items["presentation"])
        append_rules(presentation_stage / "parameter.yml", [(dev_orch, prod_orch, "DataPipeline")])
        deploy(workspace_id=ids["presentation"], repository_directory=presentation_stage,
               item_type_in_scope=["Notebook", "DataPipeline"], environment=environment)
        print(f"Deployed {len(items['presentation'])} items to the {environment} presentation workspace "
              f"(Staging orchestrator {dev_orch} -> {prod_orch}).")

        for tier in ("staging", "presentation"):
            write_lakehouse_file(workspace_id=ids[tier], lakehouse_id=lh_ids[tier],
                                 file_path="config/dp_refresh_dag.json", content=dag)
        print(f"Wrote dp_refresh_dag.json to both {environment} tier lakehouses' Files/config/.")
        return
```

Then:
- Add `from prod_scope import prod_items`, `from params import append_rules` and `from fabric_ids import find_item_id` to the imports.
- Leave the Dev branch and its config writes exactly as they are; the new Prod branch `return`s before them. The legacy `dp_backend_scope.json` is no longer written for Prod: nothing in Prod reads it, and `resolve_scope_for_environment("prod")` would raise.

- [ ] **Step 2: Remove the stale CI step.** In `.github/workflows/deploy.yml`, under `deploy-prod`, delete the `Run and verify Prod-tier notebooks` step: its `RUN_ORDER` holds placeholder IDs from the 9/17 pilot. Verification is Task 11's comparison instead.

- [ ] **Step 3: Run the tests and DAG check**

Run: `cd F && python -m pytest deploy -q && python deploy/dag_check.py`
Expected: all pass; `OK`.

- [ ] **Step 4: Commit**

```bash
git add deploy/deploy_backend.py .github/workflows/deploy.yml
git commit -m "Deploy Prod: full DAG scope, Staging first, deploy-time orchestrator ID, DAG config only"
git push origin dev
```
Expected: the CI `deploy-dev` job passes. The Dev path is unchanged.

---

### Task 6: Prod lakehouse shortcuts (run as the operator)

Do Steps 1–4 at any time. **Step 5 (applying) runs after Task 7, Step 1**, so the shortcuts land in a workspace that's no longer Git-synced.

**Files:** Create `deploy/sync_shortcuts.py`, `deploy/test_sync_shortcuts.py`.

- [ ] **Step 1: Write the failing tests**

```python
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from sync_shortcuts import missing_shortcuts, retarget  # noqa: E402

DEV_STG_WS, DEV_STG_LH = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201", "876255e0-d462-4697-adc1-4a655f5bb101"
PRD_STG_WS, PRD_STG_LH = "189e5c0a-548a-4feb-93d6-dda9ebbe96c1", "6713bd45-a4ad-47e6-8bff-1bb0415e9784"
JD_WS, JD_LH = "4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9", "7348c3a6-8694-4d11-bc70-1bd55be84ea2"


def _sc(name, ws, lh):
    return {"name": name, "path": "/Tables",
            "target": {"type": "OneLake", "oneLake": {"path": f"Tables/{name}", "itemId": lh, "workspaceId": ws}}}


def test_retarget_swaps_dev_staging_ids_and_keeps_jd():
    out = retarget([_sc("Silver_A", DEV_STG_WS, DEV_STG_LH), _sc("InTrans", JD_WS, JD_LH)],
                   {DEV_STG_WS: PRD_STG_WS, DEV_STG_LH: PRD_STG_LH})
    assert out[0]["target"]["oneLake"] == {"path": "Tables/Silver_A", "itemId": PRD_STG_LH, "workspaceId": PRD_STG_WS}
    assert out[1]["target"]["oneLake"]["workspaceId"] == JD_WS


def test_missing_shortcuts_skips_existing_by_path_and_name():
    wanted = [_sc("A", JD_WS, JD_LH), _sc("B", JD_WS, JD_LH)]
    existing = [{"name": "A", "path": "Tables"}]
    assert [s["name"] for s in missing_shortcuts(wanted, existing)] == ["B"]
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `cd F && python -m pytest deploy/test_sync_shortcuts.py -q`
Expected: FAIL with `ModuleNotFoundError`.

- [ ] **Step 3: Implement** (`deploy/sync_shortcuts.py`)

```python
"""Create the Prod lakehouse shortcuts the Dev lakehouses have (idempotent; runs as the operator via `fab api`).

Usage: python deploy/sync_shortcuts.py [--apply]     (default: dry run - prints what would be created)
"""
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).parent.parent
ID_MAP = {
    "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201": "189e5c0a-548a-4feb-93d6-dda9ebbe96c1",   # Staging workspace
    "876255e0-d462-4697-adc1-4a655f5bb101": "6713bd45-a4ad-47e6-8bff-1bb0415e9784",   # DP_Staging lakehouse
}
TARGETS = [  # (Dev shortcuts file, Prod workspace, Prod lakehouse)
    ("workspaces/DP - Staging - Dev/DP_Staging.Lakehouse/shortcuts.metadata.json",
     "189e5c0a-548a-4feb-93d6-dda9ebbe96c1", "6713bd45-a4ad-47e6-8bff-1bb0415e9784"),
    ("workspaces/DP - Presentation - Dev/DP_Presentation.Lakehouse/shortcuts.metadata.json",
     "7836042d-adb1-4846-b70d-bd42980054c5", "29d9df80-a383-4d40-9807-1e2e6cbff88f"),
]


def retarget(shortcuts: list, id_map: dict) -> list:
    out = []
    for s in shortcuts:
        s = json.loads(json.dumps(s))
        one = s["target"]["oneLake"]
        one["workspaceId"] = id_map.get(one["workspaceId"], one["workspaceId"])
        one["itemId"] = id_map.get(one["itemId"], one["itemId"])
        out.append(s)
    return out


def missing_shortcuts(wanted: list, existing: list) -> list:
    have = {(e["path"].strip("/"), e["name"]) for e in existing}
    return [s for s in wanted if (s["path"].strip("/"), s["name"]) not in have]


def fab_api(path, method=None, body=None):
    env = dict(os.environ, PATH=os.path.expanduser("~/.local/bin") + os.pathsep + os.environ["PATH"], PYTHONIOENCODING="utf-8")
    cmd = ["fab", "api", path] + (["-X", method] if method else [])
    tmp = None
    if body is not None:
        tmp = tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8")
        json.dump(body, tmp)
        tmp.close()
        cmd += ["-i", tmp.name]
    out = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", env=env).stdout
    if tmp:
        os.unlink(tmp.name)
    return json.loads(out[out.find("{"):])


def main(apply: bool) -> None:
    for rel, ws, lh in TARGETS:
        wanted = retarget(json.loads((REPO / rel).read_text(encoding="utf-8")), ID_MAP)
        existing = fab_api(f"workspaces/{ws}/items/{lh}/shortcuts")["text"].get("value", [])
        todo = missing_shortcuts(wanted, existing)
        print(f"{rel}: {len(wanted)} wanted, {len(existing)} exist, {len(todo)} to create")
        for s in todo:
            body = {"path": s["path"].strip("/"), "name": s["name"], "target": {"oneLake": s["target"]["oneLake"]}}
            if apply:
                r = fab_api(f"workspaces/{ws}/items/{lh}/shortcuts", "post", body)
                print(f"   {s['name']}: {r.get('status_code')}")
            else:
                print(f"   would create {s['name']} -> {s['target']['oneLake']}")


if __name__ == "__main__":
    main("--apply" in sys.argv)
```

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `cd F && python -m pytest deploy/test_sync_shortcuts.py -q`
Expected: 2 passed.

- [ ] **Step 5: Dry run, then apply**

Run: `cd F && python deploy/sync_shortcuts.py`
Expected: Staging lists about 34 wanted with 1 existing (InTrans); Presentation lists about 33 wanted with 1 existing (Silver_InTrans). Every Presentation target shows Prod Staging IDs.
Then run: `python deploy/sync_shortcuts.py --apply`. Expected: each line reports `201`. Re-run without `--apply`; expected: `0 to create` for both.

- [ ] **Step 6: Commit**

```bash
git add deploy/sync_shortcuts.py deploy/test_sync_shortcuts.py
git commit -m "Prod lakehouse shortcuts: idempotent sync from the Dev shortcut files"
```

---

### Task 7: Prerequisites in the Fabric UI (Brian)

**Files:** none.

- [ ] **Step 1: Disconnect both Prod workspaces from Git.** For `DP - Staging - Prod` and `DP - Presentation - Prod`: Workspace settings → Git integration → **Disconnect workspace**. The items stay in the workspace; the deploy updates the two pilot notebooks by name.
- [ ] **Step 2: Give the CI service principal access to the connections the deployed items use.** In Settings → Manage connections and gateways, add the SPN (app ID `4d783e19-0965-45c3-9c66-96b664d7cd72`) as **User** on:
  - the Outlook connection (`97d3696e…`) and Teams connection (`4d11db48…`) that the pipeline uses;
  - the Lakehouse (`ec4b2ec8…`), ODBC (`70ea8af2…`) and SharePoint (`42db34a4…`) connections that the dataflows use.
- [ ] **Step 3: Confirm the SPN is Admin or Member on both Prod workspaces** (it deployed the pilot notebooks there on 9/17), under Manage access in each workspace.
- [ ] **Step 4: Agent check.** Run `python D/tools/dp-migration/git_status.py 189e5c0a-548a-4feb-93d6-dda9ebbe96c1 7836042d-adb1-4846-b70d-bd42980054c5`. Expected: both report not connected.

---

### Task 8: First `dev` → `main` PR

`main` is about 440 commits behind `dev`. The three production report workspaces (RP - Parts Reports, RP - Service Reports, RP - Financial Reports) and LH_Master_Data are Git-connected to `main`. A merge doesn't change them until someone clicks **Update** in Fabric, but anything changed under their folders becomes "incoming" there.

**Files:** Create `deploy/merge_preview.py`, `deploy/test_merge_preview.py`. Also delete the stale pilot folders `workspaces/DP - Staging - Prod/` and `workspaces/DP - Presentation - Prod/` on `dev`, but only after Brian approves in Step 4.

- [ ] **Step 1: Write the failing test**

```python
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from merge_preview import group_changes  # noqa: E402


def test_group_changes_by_workspace_and_flags_production():
    lines = ["M\tworkspaces/RP - Parts Reports/X.Report/report.json",
             "A\tworkspaces/RP - Dev/Y.Report/report.json",
             "M\tdeploy/lib.py"]
    g = group_changes(lines, production={"RP - Parts Reports"})
    assert g["RP - Parts Reports"] == {"production": True, "files": ["M workspaces/RP - Parts Reports/X.Report/report.json"]}
    assert g["RP - Dev"]["production"] is False
    assert g["(repo)"]["files"] == ["M deploy/lib.py"]
```

- [ ] **Step 2: Implement** (`deploy/merge_preview.py`)

```python
"""What a dev->main merge changes, grouped by workspace folder; production folders flagged.
Usage: python deploy/merge_preview.py   (compares origin/main..origin/dev after a fetch)"""
import subprocess
import sys

PRODUCTION = {"RP - Parts Reports", "RP - Service Reports", "RP - Financial Reports", "LH_Master_Data"}


def group_changes(name_status_lines: list, production: set) -> dict:
    groups = {}
    for line in name_status_lines:
        status, path = line.split("\t", 1)
        parts = path.split("/")
        key = parts[1] if parts[0] == "workspaces" and len(parts) > 2 else "(repo)"
        g = groups.setdefault(key, {"production": key in production, "files": []})
        g["files"].append(f"{status} {path}")
    return groups


def main() -> None:
    subprocess.run(["git", "fetch", "-q", "origin"], check=True)
    out = subprocess.run(["git", "diff", "--name-status", "origin/main", "origin/dev"],
                         capture_output=True, text=True, encoding="utf-8", check=True).stdout
    groups = group_changes([l for l in out.splitlines() if l.strip()], PRODUCTION)
    for key, g in sorted(groups.items(), key=lambda kv: (not kv[1]["production"], kv[0])):
        print(f"{'PRODUCTION ' if g['production'] else ''}{key}: {len(g['files'])} files")
        if g["production"]:
            for f in g["files"]:
                print("    ", f)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
```

- [ ] **Step 3: Test and run**

Run: `cd F && python -m pytest deploy/test_merge_preview.py -q && python deploy/merge_preview.py`
Expected: the test passes, and the preview prints every production folder's changed files.

- [ ] **Step 4: Review with Brian (STOP).** Show the production-folder list. For each file, Brian confirms it's either already live in that workspace (committed from the workspace) or intended. Ask him to approve deleting the stale `workspaces/DP - Staging - Prod/` and `workspaces/DP - Presentation - Prod/` folders, since those workspaces are no longer Git-connected. **Do not continue without both answers.**
- [ ] **Step 5: Commit (folder deletion only if approved), push, and open the PR**

```bash
git rm -r -q "workspaces/DP - Staging - Prod" "workspaces/DP - Presentation - Prod"
git add deploy/merge_preview.py deploy/test_merge_preview.py
git commit -m "Merge preview tool; remove stale Prod-tier pilot folders (Prod is fabric-cicd-deployed, not Git-synced)"
git push origin dev
gh pr create --base main --head dev --title "DP backend + RP-Dev migration: first dev -> main" --body-file pr_body.md
```
Write `pr_body.md` first, outside the repo or deleted after use. Fill in each section of `.github/PULL_REQUEST_TEMPLATE/dev_to_main.md` using:
- the merge preview output (one line per workspace folder, with production folders listed file by file);
- "Deploys: DP backend to Prod via the manual Deploy DP backend workflow; no report deploys";
- "Production report workspaces: do NOT click Update after merge";
- and end with the attribution line from the session's system reminder.
```bash
```
Brian reviews and merges the PR on GitHub. **Nobody clicks Update in the production report workspaces.**

---

### Task 9: First Deploy Prod run (Brian clicks, agent watches)

**Files:** none.

- [ ] **Step 1: Brian runs the workflow.** GitHub → Actions → "Deploy DP backend" → Run workflow → branch `main`. Approve the `production` environment gate.
- [ ] **Step 2: Watch it.** Run `gh run watch` on that run. Expected:
  - tests, dag_check and hygiene pass;
  - "Deployed 36 items to the prod staging workspace";
  - "Deployed 71 items to the prod presentation workspace (Staging orchestrator f7e553a7-7597-469b-8ba8-5736d0775d8d -> {id})";
  - the config is written.

  Record the Prod orchestrator ID printed there.
- [ ] **Step 3: Check the items.**

```bash
cd F && python - <<'EOF'
import json, os, subprocess
from collections import Counter
env = dict(os.environ, PATH=os.path.expanduser("~/.local/bin") + os.pathsep + os.environ["PATH"], PYTHONIOENCODING="utf-8")
for label, ws in (("staging", "189e5c0a-548a-4feb-93d6-dda9ebbe96c1"), ("presentation", "7836042d-adb1-4846-b70d-bd42980054c5")):
    out = subprocess.run(["fab", "api", f"workspaces/{ws}/items"], capture_output=True, text=True, encoding="utf-8", env=env).stdout
    items = json.loads(out[out.find("{"):])["text"]["value"]
    print(label, dict(Counter(i["type"] for i in items)))
    print("   Prod Pipeline_DP_Refresh id:", [i["id"] for i in items if i["displayName"] == "Pipeline_DP_Refresh"])
EOF
```
Expected:
- staging: `Notebook: 31` (30 Silver plus the orchestrator) and `Dataflow: 5`, plus the lakehouse, its SQL endpoint, and any dataflow staging lakehouse/warehouse Fabric creates automatically.
- presentation: `Notebook: 70` (69 Gold plus the orchestrator) and `DataPipeline: 1`, plus the lakehouse and SQL endpoint. Record the Prod pipeline ID for Task 10.

Also check in the portal that the folders (Dimensions, Fact Tables/…, Orchestration, Pipelines, Raw Data - Dataflows) mirror Dev.

- [ ] **Step 4: Check the ID swaps.** Run `fab export` for the Prod `Pipeline_DP_Refresh`, one Silver notebook, one Gold notebook and `df_RepairOrderDetail_Raw`, then grep the exports.
  - Expected: no Dev workspace or lakehouse ID.
  - Expected: the pipeline's staging `notebookId` equals the Prod `Run_DP_Refresh` ID from Step 2.
- [ ] **Step 5: If the deploy fails on a connection or permission error,** the message names the item. Fix the access (Task 7, Step 2 or 3) and re-run the workflow. Deploys are idempotent and update items by name.

---

### Task 10: Copy snapshot history, then the first full Prod run

**Files:** Create `deploy/run_oneoff_notebook.py`, `deploy/oneoff/Utilities_CopySnapshotHistoryToProd_20261002.Notebook/notebook-content.py` and `.platform`.

The snapshot notebooks append one month per run and skip a month that's already present (`WHERE SnapshotDate = '{snapshot_date}'`). So copying the history first and then running is safe.

- [ ] **Step 1: Write the one-off notebook** (`deploy/oneoff/Utilities_CopySnapshotHistoryToProd_20261002.Notebook/notebook-content.py`)

```python
# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {"name": "synapse_pyspark"},
# META   "dependencies": {"lakehouse": {
# META     "default_lakehouse": "29d9df80-a383-4d40-9807-1e2e6cbff88f",
# META     "default_lakehouse_name": "DP_Presentation",
# META     "default_lakehouse_workspace_id": "7836042d-adb1-4846-b70d-bd42980054c5",
# META     "known_lakehouses": [{"id": "29d9df80-a383-4d40-9807-1e2e6cbff88f"}]}}
# META }

# CELL ********************

# One-off (2026-10-02): copy the two append-only snapshot tables' history from DP_Presentation Dev
# to DP_Presentation Prod, before the first Prod run. Re-running overwrites with Dev's current copy.
DEV = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables"
for table in ("Fact_MDInvoices_NoFreight_Snapshot", "Fact_Parts_Open_Orders_Snapshot"):
    df = spark.read.format("delta").load(f"{DEV}/{table}")
    df.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save(f"Tables/{table}")
    prod = spark.read.format("delta").load(f"Tables/{table}")
    print(table, "dev rows", df.count(), "prod rows", prod.count(),
          "snapshots", sorted(r[0] for r in prod.select("SnapshotDate").distinct().collect()))

# METADATA ********************

# META {"language": "python", "language_group": "synapse_pyspark"}
```

The `.platform` file:
```json
{"$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
 "metadata": {"type": "Notebook", "displayName": "Utilities_CopySnapshotHistoryToProd_20261002"},
 "config": {"version": "2.0", "logicalId": "00000000-0000-0000-0000-000000000000"}}
```

- [ ] **Step 2: Write the runner** (`deploy/run_oneoff_notebook.py`)

```python
"""Create (or update) a notebook in a workspace from a git folder, run it, wait, print the result.
For one-off operator tasks in workspaces that aren't Git-synced. Runs as the operator via `fab api`.
Usage: python deploy/run_oneoff_notebook.py <workspaceId> <path/to/X.Notebook>"""
import base64
import json
import sys
import time
from pathlib import Path

from sync_shortcuts import fab_api


def main(ws: str, folder: Path) -> None:
    name = json.loads((folder / ".platform").read_text(encoding="utf-8"))["metadata"]["displayName"]
    payload = base64.b64encode((folder / "notebook-content.py").read_bytes()).decode()
    definition = {"format": "fabricGitSource", "parts": [
        {"path": "notebook-content.py", "payload": payload, "payloadType": "InlineBase64"}]}
    existing = [i for i in fab_api(f"workspaces/{ws}/items?type=Notebook")["text"]["value"] if i["displayName"] == name]
    if existing:
        nb_id = existing[0]["id"]
        r = fab_api(f"workspaces/{ws}/items/{nb_id}/updateDefinition", "post", {"definition": definition})
    else:
        r = fab_api(f"workspaces/{ws}/items", "post", {"displayName": name, "type": "Notebook", "definition": definition})
    print("definition:", r.get("status_code"))
    for _ in range(30):
        found = [i for i in fab_api(f"workspaces/{ws}/items?type=Notebook")["text"]["value"] if i["displayName"] == name]
        if found:
            nb_id = found[0]["id"]
            break
        time.sleep(5)
    r = fab_api(f"workspaces/{ws}/items/{nb_id}/jobs/instances?jobType=RunNotebook", "post", {})
    print("run submitted:", r.get("status_code"))
    while True:
        time.sleep(20)
        runs = sorted(fab_api(f"workspaces/{ws}/items/{nb_id}/jobs/instances")["text"]["value"],
                      key=lambda x: x.get("startTimeUtc") or "", reverse=True)
        if runs and runs[0]["status"] not in ("NotStarted", "InProgress"):
            print(runs[0]["status"], runs[0].get("failureReason"))
            sys.exit(0 if runs[0]["status"] == "Completed" else 1)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main(sys.argv[1], Path(sys.argv[2]))
```

- [ ] **Step 3: Run it**

Run: `cd F/deploy && python run_oneoff_notebook.py 7836042d-adb1-4846-b70d-bd42980054c5 "oneoff/Utilities_CopySnapshotHistoryToProd_20261002.Notebook"`
Expected: `Completed`. Then check with DuckDB that the Prod and Dev row counts are equal for both tables.

- [ ] **Step 4: Commit**

```bash
git add deploy/run_oneoff_notebook.py deploy/oneoff
git commit -m "One-off runner + snapshot history copy to DP Prod"
```

- [ ] **Step 5: Dry run the Prod pipeline.** Run `Pipeline_DP_Refresh` in **DP - Presentation - Prod** with `mode=all dry_run=true`. `<PROD_PL>` is the Prod pipeline ID recorded in Task 9, Step 3:

```bash
printf '%s' '{"executionData":{"parameters":{"mode":"all","dry_run":"true"}}}' > run_body.json
fab api -X post "workspaces/7836042d-adb1-4846-b70d-bd42980054c5/items/<PROD_PL>/jobs/instances?jobType=Pipeline" -i run_body.json
fab api "workspaces/7836042d-adb1-4846-b70d-bd42980054c5/items/<PROD_PL>/jobs/instances"
```
Repeat the last command until the newest run's `status` is terminal. Step 6 uses the same commands with `"dry_run":"false"`.
  - Expected: Completed.
  - Expected: the summary plan lists every daily/weekly/monthly item and warns "no report workspace configured for Prod".
- [ ] **Step 6: Real run.** Run the same with `mode=all`, **outside 06:00–06:45 CT** (JD Incremental). Expected:
  - the run Completes with all items Succeeded;
  - no models are refreshed, with that warning;
  - a Teams post and email arrive saying `env: Prod`.
- [ ] **Step 7: If an item fails,** read its error in `dp_refresh_log` in DP_Presentation Prod. Typical first-run causes:
  - a missing shortcut: re-run Task 6;
  - dataflow connection access: Task 7, Step 2; then open the dataflow once in the Prod workspace and confirm its connections.

  Then run `mode=rerun_failed`.

---

### Task 11: Prove Prod Gold = Dev Gold

**Files:** Create `deploy/compare_tiers.py`, `deploy/test_compare_tiers.py`.

- [ ] **Step 1: Write the failing test**

```python
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from compare_tiers import comparable_columns  # noqa: E402


def test_comparable_columns_drops_load_timestamps():
    cols = ["Branch", "LoadTimestamp", "LoadedDatetime", "Amount", "_load_ts", "DaysSinceLastRequest"]
    assert comparable_columns(cols) == ["Branch", "Amount", "DaysSinceLastRequest"]
```

- [ ] **Step 2: Implement** (`deploy/compare_tiers.py`)

```python
"""Prod Gold vs Dev Gold for every Gold table in the DAG: row counts + full-row multiset diff.
Run right after back-to-back Dev and Prod runs (same Bronze, no JD run in between).
Usage: python deploy/compare_tiers.py   (DuckDB over OneLake, az cli credential)"""
import json
import re
import sys
from pathlib import Path

DEV = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables/"
PROD = "abfss://7836042d-adb1-4846-b70d-bd42980054c5@onelake.dfs.fabric.microsoft.com/29d9df80-a383-4d40-9807-1e2e6cbff88f/Tables/"
LOAD_COL = re.compile(r"(?i)^_?load(ed)?_?(timestamp|datetime|ts)$")


def comparable_columns(columns: list) -> list:
    return [c for c in columns if not LOAD_COL.match(c)]


def main() -> None:
    import duckdb
    con = duckdb.connect()
    con.sql("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
    dag = json.loads((Path(__file__).parent / "dp_refresh_dag.json").read_text(encoding="utf-8"))
    tables = sorted({t for i in dag["items"] if i["tier"] == "gold" for t in i["produces"]})
    bad = 0
    for t in tables:
        try:
            cols = [r[0] for r in con.cursor().sql(f"DESCRIBE SELECT * FROM delta_scan('{DEV}{t}')").fetchall()]
            sel = ", ".join(f'"{c}"' for c in comparable_columns(cols))
            d, p = f"SELECT {sel} FROM delta_scan('{DEV}{t}')", f"SELECT {sel} FROM delta_scan('{PROD}{t}')"
            nd, np_ = (con.cursor().sql(f"SELECT COUNT(*) FROM ({q})").fetchall()[0][0] for q in (d, p))
            only_d = con.cursor().sql(f"SELECT COUNT(*) FROM ({d} EXCEPT ALL {p})").fetchall()[0][0]
            only_p = con.cursor().sql(f"SELECT COUNT(*) FROM ({p} EXCEPT ALL {d})").fetchall()[0][0]
            ok = nd == np_ and only_d == 0 and only_p == 0
            bad += not ok
            print(f"{'OK  ' if ok else 'DIFF'} {t:45s} dev {nd:>12,} prod {np_:>12,} only-dev {only_d:>8,} only-prod {only_p:>8,}")
        except Exception as e:
            bad += 1
            print(f"ERR  {t:45s} {str(e)[:150]}")
    print(f"\n{len(tables) - bad} of {len(tables)} Gold tables identical")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
```

- [ ] **Step 3: Run the test**

Run: `cd F && python -m pytest deploy/test_compare_tiers.py -q`
Expected: 1 passed.

- [ ] **Step 4: Run Dev and Prod back to back, then compare.**
  1. Run Dev `Pipeline_DP_Refresh` `mode=all` (models refresh in RP-Dev as usual).
  2. Immediately run Prod `mode=all`, with no JD run in between.
  3. Run `python deploy/compare_tiers.py`.

  Expected: every table `OK`, except any that compute "days since today" or a run-time snapshot date. List those, explain each, and get Brian's agreement on each one. Any other `DIFF` is a bug to fix before moving on.
- [ ] **Step 5: Commit**

```bash
git add deploy/compare_tiers.py deploy/test_compare_tiers.py
git commit -m "compare_tiers: Prod vs Dev Gold verification"
git push origin dev
```

---

### Task 12: Document and close

**Files:** Modify `F/OPERATIONS-GUIDE.md` (a "Deploying to Prod" section) and `F/README.md` (architecture: Dev is Git-synced, Prod is fabric-cicd-deployed). In repo D: memory and this plan's checkboxes.

- [ ] **Step 1: Operations guide section**, covering:
  - the release flow: merge preview → PR → "Run workflow" on `main`;
  - when to re-run `sync_shortcuts.py`: after adding a shortcut in Dev;
  - the one-off runner;
  - the rule that nobody clicks Update in the production report workspaces after a merge unless that change is meant to go live.
- [ ] **Step 2: Update the memory notes**: `project_dp_rollout_roadmap` (stage 3 status) and `project_ci_deploy_is_push` (Prod is fabric-cicd).
- [ ] **Step 3: Commit both repos.** In F, push to `dev` and open the next PR when Brian is ready. In D, commit the plan and doc updates to `dev`.

---

## Next (separate plans, not this one)
1. **Prod refresh runs as the SPN**, building on `docs/superpowers/plans/2026-08-04-sm-refresh-spn-migration.md`. It's a tested switch before cutover: the pipeline, notebooks and dataflow ownership, plus SPN access to JD Bronze, SharePoint and Teams/Outlook.
2. **Report promotion workflow:**
   - a promotion map (report → Sandbox → production workspace);
   - an on-demand fabric-cicd workflow that updates items in place, keeping IDs;
   - pointing at DP Prod, using the Prod SQL endpoint host already in `parameter.yml`;
   - a shareable cloud connection for the Prod SQL endpoint;
   - per-environment `reportWorkspace` / per-model workspaces in the orchestrator;
   - piloting with Bin Location.
3. **Parallel run and cutover:** a Prod schedule alongside the old LH_Master_Data orchestrator for about a week, then cutover.
