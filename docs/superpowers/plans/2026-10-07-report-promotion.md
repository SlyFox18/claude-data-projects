# Report Promotion (RP-Dev → Sandbox on DP Prod → Production) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the DP-migrated reports from RP-Dev into RP-Sandbox, reading DP Prod data, for Brian to validate. Then cut over the three production report workspaces one at a time, updating each report in place.

**Architecture:**
- **Deployment:** reports are deployed by fabric-cicd from `main`, via a new on-demand GitHub workflow, "Deploy reports". It is driven by one promotion map, `deploy/report_promotion.json`, which lists each report's production home and whether it is live yet.
- **Data:** `parameter.yml` already swaps the SQL endpoint host to DP Prod for `environment=prod`. A new `semantic_model_binding` block binds every model to the DP Prod cloud connection.
- **Refresh:** the Prod refresh pipeline refreshes each model where it currently lives: RP - Sandbox until cut over, then its production workspace.
- **Git:** RP - Sandbox and the three production report workspaces are disconnected from Git. CI is their only writer.

**Tech Stack:**
- fabric-cicd 1.3.0 (`semantic_model_binding` takes `default.connection_id` plus per-model `models` entries, values per environment; see `fabric_cicd/_items/_semanticmodel.py:build_binding_mapping`);
- Python 3.12 + pytest;
- GitHub Actions;
- the Fabric/Power BI REST APIs via `fab api`;
- the DP orchestrator (`deploy/orchestrator_core.py` + `orchestrator_glue.py`, rendered by `render_orchestrator.py`).

**Repos:** **F** = `C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs`, branch `dev` (work here; release to `main` by PR). **D** = `C:\Users\bfox\Documents\Git-Projects\data-projects`.

---

## Decisions (Brian, 2026-10-07)

1. **Sandbox reads DP Prod.** Every report validated in RP-Dev on Dev data is checked once more in Sandbox on Prod data before going live. This applies to new reports too: if a report needs a Gold change, that change is released to Prod before the report goes to Sandbox.
2. **Deployment method:** fabric-cicd from Git, using the same PR → Run workflow flow as the backend.
3. **Git connections:** RP - Sandbox, RP - Parts Reports, RP - Service Reports and RP - Financial Reports are all disconnected from Git and deployed only by CI. This ends the dev/main branch split. RP - Dev stays Git-synced from `dev`.
4. **Updates are in place.** fabric-cicd matches by name and type, so each report keeps the same item ID, URL, app entry, subscriptions and the dataset IDs the Power Automate flows use.
   - **Customer Anatomy:** the production item "Customer Anatomy V2" is renamed once to "Customer Anatomy" (the ID is kept), then updated in place.
5. **Scope:**
   - Every RP-Dev report that already exists in production is in scope.
   - Two new reports go live: **Parts Action Dashboard** → RP - Parts Reports and **Service Time Sheets** → RP - Service Reports.
   - **Top 50 - Job Codes** and **Transfer App** stay in RP-Dev for now.
6. **Validation:** Brian validates alone in Sandbox, with the checklist in Task 9.
7. **Rollout:** every report goes to Sandbox at once. Production then cuts over one workspace at a time: **Financial** (1 report, the pilot), then **Service**, then **Parts**.
8. **Schedule:** while the old LH_Master_Data pipeline still runs, DP Prod runs Mon–Fri at **6:15 AM** CT, after the old 4:15 pipeline finishes around 6:00. Once the old pipeline retires, DP Prod moves to 4:15 AM.

## Report map

| Report (RP-Dev name) | Production home | Notes |
|---|---|---|
| 60+ Days Past Due | financial | pilot |
| Customer Anatomy | service | production item renamed from "Customer Anatomy V2" (Task 11) |
| Inspections | service | 2nd source: OneDrive Excel (Inspection Goals); incremental refresh on Fact_WorkOrderParts |
| Job Code Parts Advisor | service | |
| Labor Performance | service | |
| Open Work Orders | service | |
| Planter Inspection Part Sales | service | |
| Stock Check | service | |
| Service Time Sheets | service | **new** in production |
| Bin Location Report | parts | |
| Combine Vault Sales | parts | |
| First Pass Fill | parts | |
| Inventory Analysis | parts | |
| MD Invoices With No Freight | parts | |
| Negative On Hand-On Hand No Bin | parts | |
| Open Parts Tickets | parts | |
| Part Sales with Low Margin | parts | |
| Parts Adjustments | parts | |
| Parts Not Re-Ordered 24 Hours | parts | |
| Parts Promo | parts | |
| Physical Inventory | parts | |
| Pin Capture | parts | |
| Price Matrix | parts | 2nd source: OneDrive CSV |
| Table-Column-Names-Search | parts | 2nd source: ODBC `dsn=EquipRDB64` via gateway; its SQL tables still point to DP |
| Transfers | parts | |
| Unique Parts Customers | parts | |
| Parts Action Dashboard | parts | **new** in production |

Not promoted: Top 50 - Job Codes, Transfer App.

## File structure (repo F)

| File | Responsibility |
|---|---|
| Create `deploy/report_promotion.json` | Promotion map: workspace names and IDs, and each report's home and `live` flag. |
| Create `deploy/promotion.py` | Load and validate the map. `reports_for(target, workspace)` picks what a deploy covers; `refresh_targets(map)` returns model → workspace for the Prod refresh. Pure functions, no I/O beyond reading the JSON. |
| Create `deploy/test_promotion.py` | Unit tests for `promotion.py`. |
| Rewrite `deploy/deploy_reports.py` | CLI: `--target sandbox` (every report in the map) or `--target production --workspace <key>` (only that workspace's `live` reports). Stages each report's model and report, deploys with `environment="prod"`, then writes the refresh targets into the Prod config (`deploy_backend.write_prod_report_targets`). |
| Modify `parameter.yml` | Add `semantic_model_binding` for `prod`. |
| Modify `deploy/orchestrator_core.py` | `report_workspace` returns either one workspace name (Dev) or a {model: workspace} map (Prod). New `model_targets(config, settings, env, mode)`. |
| Modify `deploy/orchestrator_glue.py` | The model refresh loop uses `model_targets`. |
| Modify `deploy/deploy_backend.py` | Prod: write `orchestrator.reportWorkspace.Prod` = `refresh_targets(...)` into the deployed `dp_refresh_dag.json`. |
| Create `.github/workflows/deploy-reports.yml` | On-demand workflow: inputs `target` and `workspace`; runs from `main` only; uses the `production` environment. |
| Create `deploy/refresh_reports.py` | Operator script: full refresh of the promoted models in one workspace (as the operator via `fab api`), waits, prints per-model results. Needed right after a deploy, because a deployed model starts empty. |
| Create `deploy/test_deploy_reports.py`, `deploy/test_refresh_reports.py` | Tests for the CLI selection and request building. |

---

### Task 0: Gate — Prod Gold equals Dev Gold

- [ ] **Step 1:** Run `python deploy/compare_tiers.py` (F) after the back-to-back runs of 2026-10-07.
  - Expected: every table `OK`, except Fact_OpenOrders and Fact_OpenOrderParts (manual cadence, built at different times) and anything relative to "now".
  - Any other `DIFF` must be fixed (rules: D `docs/architecture/dp-notebook-rules.md`) before Task 7.

### Task 1: DP Prod cloud connection and the other connections (Brian, in the UI; Claude records IDs)

> **DONE 2026-10-07.**
> - PROD_SQL = `83966514-b190-4e72-af5f-1cd40cbc7eac`. Inspections' file = `360bb47c-4a03-44d9-9ac1-b676ab0181e0` (SharePoint_Inspections). Price Matrix's file = `ddd23423-cdfa-4fc8-9916-37f40dc42bd4` ("SharePoint"). GATEWAY_ODBC = `70ea8af2-b529-4843-aee6-28297801fe71`. The CI service principal is User on all four.
> - Gotcha: personal cloud connections with the same file URLs also exist and can't be shared. The live models use the gateway ones.
>
> **Task 0 DONE 2026-10-07:** 75/77 Gold tables are identical. The 2 that differ (Fact_OpenOrders, Fact_OpenOrderParts) are manual cadence and expected to.

**Why:** a deployed model must be bound to a cloud connection, or refresh fails (Premium_ASWL_Error; see memory `feedback_model_explicit_connection_for_api_refresh`). The CI service principal must also be allowed to use each connection, or fabric-cicd fails to bind it.

- [ ] **Step 1 (Brian):** In Fabric, go to **Settings → Manage connections and gateways → New → Cloud**.
  - Connection type: **SQL Server**.
  - Server: `xcrafcusadsu3d3wi4anbgp6we-fucdm6frvvdernynxvbjqacuyu.datawarehouse.fabric.microsoft.com`.
  - Database: `DP_Presentation`.
  - Authentication: **OAuth 2.0**, signed in as bfox@spitractor.com.
  - Name: `SQL_DP_Presentation_Prod`.
  - Mark it **shareable**.
- [ ] **Step 2 (Brian):** On that connection, open **Manage users** and add **SPN-Fabric-CICD-Deploy** (search by name or app ID `ff61d54f-7421-474e-b671-745993805eed`) as **User**.
- [ ] **Step 3 (Claude):** Record the connection IDs. This scratch script lists `id`, `displayName` and `connectionDetails.path` for every connection:
  ```python
  import json, subprocess
  out = subprocess.run(["fab", "api", "connections"], capture_output=True, text=True, encoding="utf-8").stdout
  for c in json.loads(out[out.find("{"):])["text"]["value"]:
      print(c["id"], "|", c["displayName"], "|", c.get("connectionDetails", {}).get("path"))
  ```
  Write down:
  - **PROD_SQL**: the `SQL_DP_Presentation_Prod` ID;
  - **ONEDRIVE**: the connection whose path is the `spitractor-my.sharepoint.com/personal/bfox_spitractor_com` OneDrive (used by Inspections and Price Matrix in production today);
  - **GATEWAY_ODBC**: the gateway connection for `dsn=EquipRDB64`.
  
  If ONEDRIVE or GATEWAY_ODBC can't be identified from the list, read the live production model's data sources:
  `fab api -A powerbi "groups/4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7/datasets/<datasetId>/datasources"`.
- [ ] **Step 4 (Brian):** Add SPN-Fabric-CICD-Deploy as **User** on ONEDRIVE and GATEWAY_ODBC too. If a connection type can't be shared ("prohibited for security reasons"), stop. That model then keeps its current binding, and we drop it from `semantic_model_binding` (fabric-cicd leaves unbound sources alone).

### Task 2: The promotion map

**Files:** create `deploy/report_promotion.json`, `deploy/promotion.py`, `deploy/test_promotion.py`.

- [ ] **Step 1: Write the map** (`deploy/report_promotion.json`):

```json
{
  "workspaces": {
    "sandbox":   {"name": "RP - Sandbox",           "id": "ba9d8de4-ef13-44e6-9156-e23a2511f3ad"},
    "parts":     {"name": "RP - Parts Reports",     "id": "4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7"},
    "service":   {"name": "RP - Service Reports",   "id": "fa9b2eef-d507-48ad-bbeb-242037941987"},
    "financial": {"name": "RP - Financial Reports", "id": "67fefa98-9e80-4a79-afdd-c8988b6e64fc"}
  },
  "reports": [
    {"name": "60+ Days Past Due", "home": "financial", "live": false},
    {"name": "Customer Anatomy", "home": "service", "live": false},
    {"name": "Inspections", "home": "service", "live": false},
    {"name": "Job Code Parts Advisor", "home": "service", "live": false},
    {"name": "Labor Performance", "home": "service", "live": false},
    {"name": "Open Work Orders", "home": "service", "live": false},
    {"name": "Planter Inspection Part Sales", "home": "service", "live": false},
    {"name": "Stock Check", "home": "service", "live": false},
    {"name": "Service Time Sheets", "home": "service", "live": false},
    {"name": "Bin Location Report", "home": "parts", "live": false},
    {"name": "Combine Vault Sales", "home": "parts", "live": false},
    {"name": "First Pass Fill", "home": "parts", "live": false},
    {"name": "Inventory Analysis", "home": "parts", "live": false},
    {"name": "MD Invoices With No Freight", "home": "parts", "live": false},
    {"name": "Negative On Hand-On Hand No Bin", "home": "parts", "live": false},
    {"name": "Open Parts Tickets", "home": "parts", "live": false},
    {"name": "Part Sales with Low Margin", "home": "parts", "live": false},
    {"name": "Parts Adjustments", "home": "parts", "live": false},
    {"name": "Parts Not Re-Ordered 24 Hours", "home": "parts", "live": false},
    {"name": "Parts Promo", "home": "parts", "live": false},
    {"name": "Physical Inventory", "home": "parts", "live": false},
    {"name": "Pin Capture", "home": "parts", "live": false},
    {"name": "Price Matrix", "home": "parts", "live": false},
    {"name": "Table-Column-Names-Search", "home": "parts", "live": false},
    {"name": "Transfers", "home": "parts", "live": false},
    {"name": "Unique Parts Customers", "home": "parts", "live": false},
    {"name": "Parts Action Dashboard", "home": "parts", "live": false}
  ]
}
```

- [ ] **Step 2: Write the failing tests** (`deploy/test_promotion.py`):

```python
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent))
from promotion import check_map, load_map, refresh_targets, reports_for  # noqa: E402

WS = {"sandbox": {"name": "RP - Sandbox", "id": "s"}, "parts": {"name": "RP - Parts Reports", "id": "p"},
      "service": {"name": "RP - Service Reports", "id": "v"}, "financial": {"name": "RP - Financial Reports", "id": "f"}}


def _map(*reports):
    return {"workspaces": WS, "reports": list(reports)}


def test_sandbox_target_takes_every_report():
    m = _map({"name": "A", "home": "parts", "live": False}, {"name": "B", "home": "financial", "live": True})
    assert reports_for(m, "sandbox") == ["A", "B"]


def test_production_target_takes_only_live_reports_of_that_workspace():
    m = _map({"name": "A", "home": "parts", "live": True}, {"name": "B", "home": "parts", "live": False},
             {"name": "C", "home": "financial", "live": True})
    assert reports_for(m, "production", "parts") == ["A"]


def test_production_target_needs_a_workspace():
    with pytest.raises(ValueError, match="workspace"):
        reports_for(_map(), "production")


def test_refresh_targets_live_reports_in_their_home_others_in_sandbox():
    m = _map({"name": "A", "home": "parts", "live": True}, {"name": "B", "home": "service", "live": False})
    assert refresh_targets(m) == {"A": "RP - Parts Reports", "B": "RP - Sandbox"}


def test_check_map_flags_unknown_home_duplicates_and_missing_folders(tmp_path):
    (tmp_path / "A.Report").mkdir()
    (tmp_path / "A.SemanticModel").mkdir()
    m = _map({"name": "A", "home": "parts", "live": False}, {"name": "A", "home": "nowhere", "live": False},
             {"name": "Z", "home": "parts", "live": "yes"})
    errors = check_map(m, tmp_path)
    assert any("duplicate" in e and "A" in e for e in errors)
    assert any("nowhere" in e for e in errors)
    assert any("Z" in e and "folder" in e for e in errors)
    assert any("Z" in e and "live" in e for e in errors)


def test_the_real_map_is_valid():
    repo = Path(__file__).parent.parent
    assert check_map(load_map(repo), repo / "workspaces" / "RP - Dev") == []
```

- [ ] **Step 3: Run them.** `python -m pytest deploy/test_promotion.py -q`. Expected: FAIL, `ModuleNotFoundError: No module named 'promotion'`.

- [ ] **Step 4: Implement** (`deploy/promotion.py`):

```python
"""The report promotion map (deploy/report_promotion.json): which RP-Dev reports are promoted,
their production home, and whether they are live there yet."""
import json
from pathlib import Path

HOMES = ("parts", "service", "financial")


def load_map(repo_root: Path) -> dict:
    return json.loads((repo_root / "deploy" / "report_promotion.json").read_text(encoding="utf-8"))


def check_map(m: dict, rp_dev_dir: Path) -> list:
    """Problems with the map, as messages; [] when it is usable."""
    errors, seen = [], set()
    for key in ("sandbox", *HOMES):
        if key not in m.get("workspaces", {}):
            errors.append(f"workspaces.{key} missing")
    for r in m.get("reports", []):
        name = r.get("name", "<unnamed>")
        if name in seen:
            errors.append(f"duplicate report {name}")
        seen.add(name)
        if r.get("home") not in HOMES:
            errors.append(f"{name}: home {r.get('home')!r} is not one of {HOMES}")
        if not isinstance(r.get("live"), bool):
            errors.append(f"{name}: live must be true or false")
        for kind in ("Report", "SemanticModel"):
            if not (rp_dev_dir / f"{name}.{kind}").is_dir():
                errors.append(f"{name}: no {name}.{kind} folder in {rp_dev_dir.name}")
    return errors


def reports_for(m: dict, target: str, workspace: str = None) -> list:
    """Report names a deploy covers: every report for 'sandbox'; the live reports of one home for 'production'."""
    if target == "sandbox":
        return [r["name"] for r in m["reports"]]
    if target == "production":
        if workspace not in HOMES:
            raise ValueError(f"production deploys need a workspace: one of {HOMES}")
        return [r["name"] for r in m["reports"] if r["home"] == workspace and r["live"]]
    raise ValueError(f"unknown target {target!r}")


def refresh_targets(m: dict) -> dict:
    """{model name: workspace name} the Prod refresh uses: production home once live, else Sandbox."""
    ws = m["workspaces"]
    return {r["name"]: ws[r["home"]]["name"] if r["live"] else ws["sandbox"]["name"] for r in m["reports"]}
```

- [ ] **Step 5: Run.** `python -m pytest deploy/test_promotion.py -q`. Expected: 6 passed. If `test_the_real_map_is_valid` fails, a name in the map doesn't match an RP-Dev folder; fix the map, not the test.
- [ ] **Step 6: Commit.**
  ```bash
  git add deploy/report_promotion.json deploy/promotion.py deploy/test_promotion.py
  git commit -m "Report promotion map + loader/validator"
  ```

### Task 3: Prod refresh targets per model (orchestrator)

**Files:** modify `deploy/orchestrator_core.py`, `deploy/orchestrator_glue.py`, `deploy/test_orchestrator_core.py`, `deploy/deploy_backend.py`, `deploy/test_deploy_backend.py`. Re-render with `deploy/render_orchestrator.py`.

- [ ] **Step 1: Write the failing tests** (append to `deploy/test_orchestrator_core.py`):

```python
from orchestrator_core import model_targets  # noqa: E402


def test_model_targets_single_workspace_refreshes_every_report_there():
    config = {"reports": [{"model": "A", "tables": []}, {"model": "B", "tables": []}]}
    settings = {"reportWorkspace": {"Dev": "RP - Dev"}}
    assert model_targets(config, settings, "Dev", "all") == [("A", "RP - Dev"), ("B", "RP - Dev")]


def test_model_targets_map_refreshes_only_mapped_reports_in_their_workspace():
    config = {"reports": [{"model": "A", "tables": []}, {"model": "B", "tables": []}, {"model": "C", "tables": []}]}
    settings = {"reportWorkspace": {"Prod": {"A": "RP - Sandbox", "C": "RP - Parts Reports"}}}
    assert model_targets(config, settings, "Prod", "all") == [("A", "RP - Sandbox"), ("C", "RP - Parts Reports")]


def test_model_targets_none_when_environment_has_no_workspace():
    assert model_targets({"reports": [{"model": "A", "tables": []}]}, {"reportWorkspace": {}}, "Prod", "all") == []
```

- [ ] **Step 2: Run.** `python -m pytest deploy/test_orchestrator_core.py -q -k model_targets`. Expected: FAIL (ImportError).

- [ ] **Step 3: Implement.** Add to `deploy/orchestrator_core.py`, just below `report_workspace`:

```python
def model_targets(config: dict, settings: dict, env: str, mode: str) -> list:
    """[(model, workspace)] this run refreshes. reportWorkspace[env] is either one workspace name
    (every report model is refreshed there) or a {model: workspace} map (Prod: each promoted model
    where it currently lives - see deploy/report_promotion.json); unmapped models are skipped."""
    target = report_workspace(settings, env)
    if target is None:
        return []
    models = models_for_run(config, mode)
    if isinstance(target, dict):
        return [(m, target[m]) for m in models if m in target]
    return [(m, target) for m in models]
```

  Then in `deploy/orchestrator_glue.py`, replace the block that starts at `workspace = report_workspace(SETTINGS, ENV)` (around line 354) with:

```python
                targets = model_targets(CONFIG, SETTINGS, ENV, mode)
                if not targets:
                    summary["warnings"].append(f"no report workspace configured for {ENV}; models not refreshed")
                else:
                    t0 = time.time()
                    with ThreadPoolExecutor(max_workers=int(SETTINGS["modelRefreshParallelism"])) as pool:
                        futures = {m: pool.submit(refresh_model, m, ws) for m, ws in targets}
                    summary["models"] = {m: f.result() for m, f in futures.items()}
                    summary["tier_seconds"]["models"] = time.time() - t0
```

  Remove `report_workspace` from the glue's imports only if nothing else in the glue uses it (`grep -n report_workspace deploy/orchestrator_glue.py`).

- [ ] **Step 4: Prod writes the map into its config.** In `deploy/deploy_backend.py`, add the function below. In the Prod branch of `main`, call it on the `dag` dict just before the `write_lakehouse_file` loop that writes `config/dp_refresh_dag.json` (around line 117):

```python
def with_prod_report_targets(dag: dict, repo_root: Path) -> dict:
    """Copy of the DAG config whose orchestrator.reportWorkspace.Prod is the per-model map from the
    promotion map (live reports in their production workspace, the rest in RP - Sandbox)."""
    from promotion import load_map, refresh_targets
    out = json.loads(json.dumps(dag))
    out["orchestrator"].setdefault("reportWorkspace", {})["Prod"] = refresh_targets(load_map(repo_root))
    return out
```

  Use it as `dag = with_prod_report_targets(dag, REPO_ROOT)`, Prod path only. Then add the test to `deploy/test_deploy_backend.py`:

```python
def test_prod_config_gets_per_model_report_targets(tmp_path):
    from deploy_backend import with_prod_report_targets
    (tmp_path / "deploy").mkdir()
    (tmp_path / "deploy" / "report_promotion.json").write_text(json.dumps({
        "workspaces": {"sandbox": {"name": "RP - Sandbox", "id": "s"}, "parts": {"name": "RP - Parts Reports", "id": "p"},
                       "service": {"name": "S", "id": "v"}, "financial": {"name": "F", "id": "f"}},
        "reports": [{"name": "A", "home": "parts", "live": True}, {"name": "B", "home": "parts", "live": False}]}))
    dag = {"orchestrator": {"reportWorkspace": {"Dev": "RP - Dev"}}}
    out = with_prod_report_targets(dag, tmp_path)
    assert out["orchestrator"]["reportWorkspace"] == {"Dev": "RP - Dev", "Prod": {"A": "RP - Parts Reports", "B": "RP - Sandbox"}}
    assert dag["orchestrator"]["reportWorkspace"] == {"Dev": "RP - Dev"}
```
  (Add `import json` at the top of the test file if it isn't there already.)

- [ ] **Step 5: `dag_config` must accept the map form.** In `deploy/dag_config.py` (`_check_orchestrator`, lines 32–34), replace the `reportWorkspace` check with:

```python
    workspaces = settings.get("reportWorkspace")
    if not isinstance(workspaces, dict) or not workspaces:
        errors.append("orchestrator: reportWorkspace must map environment (e.g. Dev) -> report workspace name")
    else:
        for env, target in workspaces.items():
            ok = (isinstance(target, str) and target) or (
                isinstance(target, dict) and target
                and all(isinstance(k, str) and k and isinstance(v, str) and v for k, v in target.items()))
            if not ok:
                errors.append(f"orchestrator: reportWorkspace.{env} must be a workspace name or a "
                              f"non-empty {{model: workspace name}} map")
```
  Add to `deploy/test_dag_config.py`, following the file's existing pattern for building a valid settings dict (copy the helper the other orchestrator tests use):

```python
def test_report_workspace_accepts_per_model_map_and_rejects_empty_values():
    from dag_config import _check_orchestrator
    base = _valid_settings()  # the helper the other orchestrator tests in this file use
    assert _check_orchestrator({**base, "reportWorkspace": {"Prod": {"A": "RP - Sandbox"}}}) == []
    errs = _check_orchestrator({**base, "reportWorkspace": {"Prod": {"A": ""}}})
    assert any("reportWorkspace.Prod" in e for e in errs)
```
  If the test file has no `_valid_settings` helper, build the dict inline from `deploy/dp_refresh_dag.json`'s `orchestrator` section: `json.loads(...)["orchestrator"]`.
- [ ] **Step 6: Re-render and run every test.**
  ```
  python deploy/render_orchestrator.py && python -m pytest deploy -q
  ```
  Expected: all pass, and the three rendered notebooks under `workspaces/DP - * - Dev/Orchestration/` change.
- [ ] **Step 7: Commit** the source files, tests and the 3 rendered notebooks. Push to `dev`, run `tools/dp-migration/git_sync.py` (D) for both Dev workspaces, then run Dev once in `mode=items` with a single Gold item. Expected: the models still refresh in RP - Dev, since Dev uses the single-workspace form.

### Task 4: Connection binding (`parameter.yml`)

- [ ] **Step 1:** Append to `parameter.yml` (F), using the IDs from Task 1, Step 3:

```yaml
semantic_model_binding:
  # Prod only: every promoted model reads DP Prod through the shareable SQL_DP_Presentation_Prod
  # cloud connection. Models with a second source list every connection they need.
  default:
    connection_id:
      prod: "83966514-b190-4e72-af5f-1cd40cbc7eac"          # SQL_DP_Presentation_Prod
  models:
    - semantic_model_name: "Inspections"
      connection_id:
        prod: ["83966514-b190-4e72-af5f-1cd40cbc7eac", "360bb47c-4a03-44d9-9ac1-b676ab0181e0"]  # + SharePoint_Inspections (gateway Web)
    - semantic_model_name: "Price Matrix"
      connection_id:
        prod: ["83966514-b190-4e72-af5f-1cd40cbc7eac", "ddd23423-cdfa-4fc8-9916-37f40dc42bd4"]  # + "SharePoint" (gateway Web, PRICE MATRIX csv)
    - semantic_model_name: "Table-Column-Names-Search"
      connection_id:
        prod: ["83966514-b190-4e72-af5f-1cd40cbc7eac", "70ea8af2-b529-4843-aee6-28297801fe71"]  # + dsn=EquipRDB64 (gateway ODBC)
```
  These IDs were verified on 2026-10-07: they're the connections the live production models use (from `datasets/<id>/datasources`), and SPN-Fabric-CICD-Deploy is User on all four. There is no `dev:` key on purpose: Dev deploys don't deploy reports.

- [ ] **Step 2:** Run `python -m pytest deploy -q` (parameter.yml is read by tests only through `stage_items`, so this is a smoke check). Then commit: `git add parameter.yml && git commit -m "parameter.yml: bind promoted models to the DP Prod connection"`.

### Task 5: Deploy and refresh scripts

**Files:** rewrite `deploy/deploy_reports.py`; create `deploy/test_deploy_reports.py`, `deploy/refresh_reports.py`, `deploy/test_refresh_reports.py`.

- [ ] **Step 1: Write the failing tests** (`deploy/test_deploy_reports.py`):

```python
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import deploy_reports  # noqa: E402

M = {"workspaces": {"sandbox": {"name": "RP - Sandbox", "id": "S"}, "parts": {"name": "P", "id": "PID"},
                    "service": {"name": "V", "id": "VID"}, "financial": {"name": "F", "id": "FID"}},
     "reports": [{"name": "A", "home": "parts", "live": True}, {"name": "B", "home": "parts", "live": False}]}


def test_plan_sandbox_deploys_everything_to_sandbox():
    assert deploy_reports.plan(M, "sandbox", None) == ("S", ["A", "B"])


def test_plan_production_deploys_live_reports_to_their_home():
    assert deploy_reports.plan(M, "production", "parts") == ("PID", ["A"])


def test_plan_production_with_nothing_live_is_an_error():
    import pytest
    with pytest.raises(SystemExit):
        deploy_reports.plan(M, "production", "financial")
```

- [ ] **Step 2: Run.** `python -m pytest deploy/test_deploy_reports.py -q`. Expected: FAIL (`plan` not defined).

- [ ] **Step 3: Rewrite `deploy/deploy_reports.py`:**

```python
"""Deploy promoted reports from RP - Dev (repo folder) to RP - Sandbox or a production report workspace.

  python deploy/deploy_reports.py --target sandbox
  python deploy/deploy_reports.py --target production --workspace financial|service|parts

Always deploys with environment="prod": parameter.yml swaps the SQL endpoint host to DP Prod and binds each
model to the DP Prod connection. Production deploys take only the reports marked "live" for that workspace
in deploy/report_promotion.json. Afterwards the Prod refresh pipeline's config is rewritten so it refreshes
each model where it now lives.
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from lib import deploy, stage_items  # noqa: E402
from promotion import check_map, load_map, reports_for  # noqa: E402

REPO_ROOT = Path(__file__).parent.parent
RP_DEV_DIR = REPO_ROOT / "workspaces" / "RP - Dev"


def plan(m: dict, target: str, workspace):
    """(workspace id, report names) for this deploy."""
    names = reports_for(m, target, workspace)
    if not names:
        sys.exit(f"nothing to deploy: no report is marked live for '{workspace}' in report_promotion.json")
    key = "sandbox" if target == "sandbox" else workspace
    return m["workspaces"][key]["id"], names


def main(target: str, workspace) -> None:
    m = load_map(REPO_ROOT)
    errors = check_map(m, RP_DEV_DIR)
    if errors:
        sys.exit("report_promotion.json problems:\n  " + "\n  ".join(errors))
    workspace_id, names = plan(m, target, workspace)
    items = [RP_DEV_DIR / f"{n}.{kind}" for n in names for kind in ("SemanticModel", "Report")]
    stage_dir = stage_items(REPO_ROOT, items)
    deploy(workspace_id=workspace_id, repository_directory=stage_dir,
           item_type_in_scope=["SemanticModel", "Report"], environment="prod")
    print(f"Deployed {len(names)} report(s) to {workspace_id}: {', '.join(names)}")
    from deploy_backend import write_prod_report_targets
    write_prod_report_targets()


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--target", choices=["sandbox", "production"], required=True)
    p.add_argument("--workspace", choices=["parts", "service", "financial"])
    a = p.parse_args()
    main(a.target, a.workspace)
```

  Add `write_prod_report_targets()` to `deploy/deploy_backend.py`. It reads `deploy/dp_refresh_dag.json`, applies `with_prod_report_targets`, and writes the result to both Prod tier lakehouses' `Files/config/dp_refresh_dag.json`, reusing the existing Prod IDs and the `write_lakehouse_file` calls of the Prod branch. Extract that write loop into a helper so `main` and `write_prod_report_targets` share it.

- [ ] **Step 4: Run.** `python -m pytest deploy -q`. Expected: all pass.

- [ ] **Step 5: `deploy/refresh_reports.py`** (operator script: full refresh after a deploy):

```python
"""Full refresh of promoted models in one workspace, as the operator (fab api). Waits and prints each result.

  python deploy/refresh_reports.py sandbox            # every promoted model, in RP - Sandbox
  python deploy/refresh_reports.py financial           # live models of that production workspace
"""
import sys
import time

from promotion import load_map, reports_for
from sync_shortcuts import fab_api
from deploy_reports import REPO_ROOT


def refresh_body() -> dict:
    return {"type": "full", "commitMode": "transactional", "maxParallelism": 4, "retryCount": 1}


def main(key: str) -> int:
    m = load_map(REPO_ROOT)
    names = reports_for(m, "sandbox") if key == "sandbox" else reports_for(m, "production", key)
    ws = m["workspaces"][key]["id"]
    datasets = {d["name"]: d["id"] for d in fab_api(f"groups/{ws}/datasets", audience="powerbi")["text"]["value"]}
    missing = [n for n in names if n not in datasets]
    if missing:
        print("not in the workspace (deploy first):", ", ".join(missing))
        return 1
    for n in names:
        r = fab_api(f"groups/{ws}/datasets/{datasets[n]}/refreshes", "post", refresh_body(), audience="powerbi")
        print(f"{n}: submitted {r.get('status_code')}")
    bad = 0
    for n in names:
        for _ in range(180):
            h = fab_api(f"groups/{ws}/datasets/{datasets[n]}/refreshes?$top=1", audience="powerbi")["text"]["value"][0]
            if h["status"] != "Unknown":
                break
            time.sleep(20)
        ok = h["status"] == "Completed"
        bad += not ok
        print(f"{'OK  ' if ok else 'FAIL'} {n}: {h['status']} {h.get('serviceExceptionJson', '')[:300]}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main(sys.argv[1]))
```

  This needs an `audience` argument on `sync_shortcuts.fab_api`. `fab api` takes `-A powerbi` (confirmed with `fab api --help`: `-A, --audience  Audience for token (fabric, storage, azure, powerbi)`). In `deploy/sync_shortcuts.py`, change the signature and the command line:

```python
def fab_api(path: str, method: str = None, body: dict = None, audience: str = None) -> dict:
    ...
    cmd = ["fab", "api", path] + (["-X", method] if method else []) + (["-A", audience] if audience else [])
```
  Add to `deploy/test_sync_shortcuts.py` (mock `subprocess.run` the same way the existing `fab_api` tests do), asserting that `fab_api("groups", audience="powerbi")` calls `["fab", "api", "groups", "-A", "powerbi"]`.

  Then test `refresh_body()` in `deploy/test_refresh_reports.py`:

```python
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from refresh_reports import refresh_body  # noqa: E402


def test_refresh_is_full_and_transactional():
    assert refresh_body() == {"type": "full", "commitMode": "transactional", "maxParallelism": 4, "retryCount": 1}
```

- [ ] **Step 6: Commit.**
  ```bash
  git add deploy/deploy_reports.py deploy/test_deploy_reports.py deploy/refresh_reports.py deploy/test_refresh_reports.py deploy/deploy_backend.py deploy/test_deploy_backend.py deploy/sync_shortcuts.py deploy/test_sync_shortcuts.py
  git commit -m "deploy_reports: promotion-map driven Sandbox/production deploys; refresh_reports operator script"
  ```

### Task 6: The "Deploy reports" workflow

- [ ] **Step 1:** Create `.github/workflows/deploy-reports.yml`:

```yaml
name: Deploy reports

# Manual only, from main only (the Run workflow click is the approval gate, as for the backend).
on:
  workflow_dispatch:
    inputs:
      target:
        description: "sandbox = every promoted report to RP - Sandbox; production = the live reports of one workspace"
        type: choice
        options: [sandbox, production]
        required: true
      workspace:
        description: "production only"
        type: choice
        options: ["", financial, service, parts]
        required: false

jobs:
  deploy-reports:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - run: pip install -r deploy/requirements.txt pytest
      - name: Unit tests for deploy tooling
        run: python -m pytest deploy -q
      - name: Deploy reports
        env:
          FABRIC_CICD_TENANT_ID: ${{ secrets.FABRIC_CICD_TENANT_ID }}
          FABRIC_CICD_CLIENT_ID: ${{ secrets.FABRIC_CICD_CLIENT_ID }}
          FABRIC_CICD_CLIENT_SECRET: ${{ secrets.FABRIC_CICD_CLIENT_SECRET }}
        run: |
          if [ "${{ inputs.target }}" = "production" ]; then
            python deploy/deploy_reports.py --target production --workspace "${{ inputs.workspace }}"
          else
            python deploy/deploy_reports.py --target sandbox
          fi
```

- [ ] **Step 2:** Commit. Then push `dev`, and open the PR dev → main (run `deploy/merge_preview.py` first) for Tasks 2–6. **STOP for Brian:** he merges with "Create a merge commit" and runs **Deploy DP backend** on `main`, so Prod gets the new orchestrator and the per-model config. Then run `python deploy/claim_prod_pipeline.py` and fast-forward `dev` to `main`.

### Task 7: Sandbox — disconnect, deploy, refresh (Brian + Claude)

- [ ] **Step 1 (Brian):** In **RP - Sandbox**, go to **Workspace settings → Git integration → Disconnect workspace**. Then give SPN-Fabric-CICD-Deploy **Contributor** in **Manage access**, if it isn't already there.
- [ ] **Step 2 (Brian):** On https://github.com/SlyFox18/fabric-workspace-docs/actions/workflows/deploy-reports.yml, click **Run workflow** with **Use workflow from** `main` and target `sandbox`. Expected: success; the log lists all 27 reports.
- [ ] **Step 3 (Claude):** Run `python deploy/refresh_reports.py sandbox`. Expected: 27 `OK`.
  - If a model fails with a credentials or connection error, check its data source binding in **Settings → Semantic model → Gateway and cloud connections**. It should be `SQL_DP_Presentation_Prod`, plus ONEDRIVE or GATEWAY_ODBC where listed. Fix the binding in `parameter.yml` (not by hand) and redeploy.
  - **Inspections** (incremental refresh on Fact_WorkOrderParts) needs this service-side full refresh to build its partitions. A Desktop-side refresh isn't enough.
- [ ] **Step 4 (Claude):** Check every deployed model points at Prod. Read each model's TMDL with `fab api "workspaces/<sandbox>/semanticModels/<id>/getDefinition"`, or check its data sources: no host may contain `inkp24yoeqfedgiktcbh6mwaq4` (the Dev endpoint). Every SQL source must be `...fucdm6frvvdernynxvbjqacuyu...`. Any Dev host is a bug in `parameter.yml`; stop and fix.
- [ ] **Step 5 (Claude):** The 5 reports already in Sandbox from the old auto-deploy (60+ Days Past Due, Bin Location Report, Parts Action Dashboard, Physical Inventory, Service Time Sheets) are overwritten in place by Step 2. Confirm Sandbox now holds exactly the 27 promoted reports and their models, and list anything extra for Brian. Delete nothing without his say-so.

### Task 8: Turn on the DP Prod schedule (Brian)

- [ ] **Step 1 (Brian):** In **DP - Presentation - Prod → Pipeline_DP_Refresh → Schedule**:
  - On; repeat **Weekly**, Mon–Fri, **6:15 AM**, time zone **(UTC-06:00) Central Time**.
  - Leave the parameters at their defaults, so `mode` is `scheduled`.
  - The schedule runs as whoever saves it, so Brian must save it.
- [ ] **Step 2 (Brian):** The DP pipeline now starts JD's Incremental load itself (`mode=scheduled` runs it), so turn **off JD's own 6:30 AM schedule** on `PL_EquipRDB_To_Fabric_Incremental` in JD_FabricOneLake. Otherwise two Incremental loads overlap while Silver is reading. This was decided 2026-09-29 (memory `project_dp_refresh_redesign`). JD's midnight Full load stays as it is.
- [ ] **Step 3 (Claude):** The next weekday morning, check the run: a summary email by about 7:00 AM; every item Succeeded; 27 models refreshed in RP - Sandbox.

### Task 9: Sandbox validation (Brian, with a Claude-prepared checklist)

- [ ] **Step 1 (Claude):** Create `docs/architecture/report-promotion-validation.md` (D). It has one row per report with columns Report | Live report (link) | Sandbox report (link) | Checks | Expected differences | OK?. The checks are:
  - every page opens with no visual errors;
  - for each of 3–5 headline numbers per report, the Sandbox value equals the live value, or differs only by an expected difference;
  - slicers and bookmarks still work;
  - any Power Automate flow on that model still runs (memory `project_flow_dataset_dependencies`).
  
  Pre-fill the expected differences, each sourced from memory:
  - prod InTrans_Incremental missing Aug (7,101) and Sep (~1,419) 2026 transactions, so DP is higher on InTrans-based reports for those months (`project_prod_intrans_aug2026_gap`);
  - the Fact_Service_Invoices InvoiceNumber-merge fix ($19M → $2.13M Unknown);
  - dim_Parts quantities and values are now company-wide;
  - Parts Not Re-Ordered adds quantities;
  - Silver_InTrans gains about 150K rows for 2010–2014;
  - Customer Anatomy: Service_Detail 2x fix, Tornillo fix, branch-if-ambiguous (`project_customer_anatomy_migration`);
  - dim_DateTable today-relative columns rebuilt as report DAX (`feedback_datetable_today_relative_columns_dropped`).
- [ ] **Step 2 (Brian):** Work through the checklist, marking OK or describing the difference. Any unexplained difference is investigated before that workspace's cutover. A fix goes through Dev → Prod (backend) or RP-Dev → Sandbox (report) as usual.

### Task 10: Cut over RP - Financial Reports (pilot: 60+ Days Past Due)

Do this outside business hours: after 5 PM, or before 6 AM, after the DP Prod run has finished.

- [ ] **Step 1 (Brian):** In **RP - Financial Reports**:
  - **Workspace settings → Git integration → Disconnect workspace**.
  - Make sure SPN-Fabric-CICD-Deploy has **Contributor** in **Manage access**.
- [ ] **Step 2 (Claude):** Record the live item IDs, for rollback and to check they don't change:
  `fab api "workspaces/67fefa98-9e80-4a79-afdd-c8988b6e64fc/items"`. Save the report and semantic model IDs to the cutover log in `docs/architecture/report-promotion-validation.md` (D).
- [ ] **Step 3 (Claude):** In `deploy/report_promotion.json`, set `"live": true` for 60+ Days Past Due. Commit, push, PR dev → main. **STOP for Brian:** merge, then run **Deploy reports** with target `production` and workspace `financial`, then **Deploy DP backend**. The backend deploy rewrites the refresh targets in the Prod config; `deploy_reports.py` does this too, so the backend run is a safety net. After it, run `claim_prod_pipeline.py`.
- [ ] **Step 4 (Claude):**
  - Run `python deploy/refresh_reports.py financial`. Expected: `OK`.
  - Confirm the item IDs match Step 2, so the update was in place.
  - Confirm the model's data source is the DP Prod host.
- [ ] **Step 5 (Brian):** If **RP - Financial Reports** has a workspace app, open **Update app** so app users get the new version. Open the report from the app and from its direct link.
- [ ] **Step 6 (Claude):** Stop the old pipeline refreshing this model.
  1. Find its dataset ID (from Step 2) in these files under `workspaces/LH_Master_Data/Pipelines/`:
     - `​Pipeline_SemanticModels_V2.DataPipeline` (note: its folder name starts with a zero-width space; use a glob, not a typed path)
     - `Pipeline_SemanticModels.DataPipeline`
     - `Pipeline_Facts_PartsReports.DataPipeline`
     - `Pipeline_Facts_Inspections.DataPipeline`
     - `Pipeline_PartsNotReordered_QuickRefresh.DataPipeline`
     - `Pipeline_Master_Orchestrator.DataPipeline`
     - `Pipeline_SM_Refresh_TEST.DataPipeline`
  2. Remove that model's refresh activity, or its list entry, together with any `dependsOn` references to it.
  3. Commit to `dev`. LH_Master_Data syncs from `dev`, so Brian clicks **Update all** in LH_Master_Data's source control panel.
  
  If the model is refreshed by a notebook or a config file instead of an activity, remove it there.
- [ ] **Step 7:**
  - The next morning, confirm the 6:15 DP run refreshed the model **in RP - Financial Reports**: the summary lists it, and the model's refresh history shows the run.
  - Confirm the old 4:15 pipeline no longer touches it.
  - Spot-check two numbers with the report's users if Brian wants.
- **Rollback:** set `"live": false`, then redeploy the previous version by running **Deploy reports** from the commit before the cutover. Use the `git revert` of the cutover PR on `main`, then Run workflow.

### Task 11: Cut over RP - Service Reports

Same as Task 10 (financial → service, workspace ID `fa9b2eef-d507-48ad-bbeb-242037941987`), with three additions:

- [ ] **Step 0 (Claude, before the deploy):** Rename the production item **Customer Anatomy V2** to **Customer Anatomy**. Rename both the report and its semantic model, as Brian, via `fab api -X patch "workspaces/fa9b2eef-d507-48ad-bbeb-242037941987/items/<id>"` with `{"displayName": "Customer Anatomy"}`. Confirm the IDs are unchanged.
  - Before renaming, check that no other item in the workspace is already named "Customer Anatomy".
  - "Planter Inspection Part Sales - V1" is an old report and stays untouched.
- [ ] **Service Time Sheets** is new in this workspace, so the deploy creates it. The AuditLog Power App action used from it needs the app link opened and **Allow** clicked once by its users, as was needed in RP-Dev (memory `project_service_time_sheets_migration`).
- [ ] **Inspections:** after `refresh_reports.py service`, confirm Fact_WorkOrderParts has all its partitions (row count matches Sandbox).
- [ ] Mark all 9 service reports `"live": true` in one commit.

> **Lessons from the Financial and Service cutovers (2026-10-07), already built into the code:**
> - **The CI account takes over each existing model before binding** (`pbi_models.take_over`). People own the live models, and only an owner can bind connections.
> - **The bind check waits up to 2 minutes**, because bindings take a few seconds to appear.
> - **Existing models are updated with `allowPurgeData`.** Without it, Inspections failed with RequiredOptionsMissing because of its incremental-refresh partitions.
> - **fabric-cicd publishes all models, then all reports.** If a model fails, no report is published. A failed production run leaves new models under old reports, so **re-run it immediately**.
> - **The old V2 refresh list can hold stale entries** (a dead "Customer Anatomy V2" ID). Search it by workspace ID, not only by the current dataset IDs.

### Task 12: Cut over RP - Parts Reports

Same as Task 10 (parts, workspace ID `4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7`), all 18 reports including the new **Parts Action Dashboard**. Additions:
- [ ] Re-test the **Power Automate flows** that query Parts models: Pin Capture, Low Margin and the Parts Action Summary Orchestrator (memory `project_flow_dataset_dependencies`). Run each once from its run history (resubmit) and confirm it succeeds against the cut-over model.
- [ ] Parts is the largest workspace (18 models). Watch the first 6:15 run's model-refresh time in the summary (`tier_seconds.models`). If the run ends after 7:45, raise `modelRefreshParallelism` in `deploy/dp_refresh_dag.json` (currently 4) only if capacity allows; check the CU numbers in the summary first.

### Task 13: After all three workspaces are live

- [ ] **Step 1 (Brian):** Move the DP Prod schedule to **4:15 AM** Mon–Fri. Do this only after the old LH_Master_Data pipeline schedule is turned off.
- [ ] **Step 2 (Claude):** Write the follow-up plan to retire the old LH_Master_Data pipelines and dataflows (separate plan; nothing is deleted here).
- [ ] **Step 3 (Claude):** Update docs:
  - F `OPERATIONS-GUIDE.md` gets a "Promoting reports" section (the map, the workflow, `refresh_reports.py`, cutover and rollback);
  - F `README.md` (report workspaces are now CI-deployed);
  - D memory `project_report_migration_catalog` and `project_dp_rollout_roadmap`;
  - this plan's checkboxes.
