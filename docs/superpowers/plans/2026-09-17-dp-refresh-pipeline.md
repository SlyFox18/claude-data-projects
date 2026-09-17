# DP Backend Recurring Refresh Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build three config-driven Fabric Data Pipelines (`Pipeline_DP_Daily_Refresh`, `Pipeline_DP_Monthly_Refresh`, `Pipeline_DP_SemanticModel_Refresh`) that keep the DP backend's Silver/Gold tables and the 3 Batch 0 reports' semantic models current on a real schedule, reading their scope from one shared config file instead of hardcoded pipeline activities — so future report migrations mean editing a config array, not rebuilding a pipeline.

**Architecture:** A single JSON config (`dp_backend_scope.json`) is the source of truth for both `deploy_backend.py` (code deployment) and all three pipelines (what to run/refresh and how often). `deploy_backend.py` writes an environment-resolved copy of it into each tier's Lakehouse Files on every deploy. Each pipeline reads that file via a `Lookup` activity, filters it with a `Filter` activity, and iterates the result with a `ForEach` (`batchCount: 3`) whose per-iteration activity (`TridentNotebook` or `PBISemanticModelRefresh`) is parameterized dynamically from the current item — the exact pattern already proven live in `Pipeline_SemanticModels_V2`.

**Tech Stack:** Python 3.12, `fabric-cicd` (pip), `azure-identity` (`ClientSecretCredential`), `azure-storage-file-datalake` (writing to OneLake), `fab` CLI (ID lookups), Fabric Data Factory pipelines (portal-built).

**Reference:** `docs/superpowers/specs/2026-09-17-dp-refresh-pipeline-design.md` — the approved design this plan implements. Read it first if anything below seems underspecified; this plan follows it section-by-section. Also supersedes Task 12 of `docs/superpowers/plans/2026-09-17-fabric-cicd-deployment.md` (Task 19 below updates that plan to point here).

---

## Real API facts this plan relies on (verified 2026-09-17, not assumed)

- **Fabric pipeline activity type names** (from the real `DataPipeline` item definition schema, `learn.microsoft.com/rest/api/fabric/articles/item-management/definitions/datapipeline-definition`):
  - A Notebook activity's real `type` is **`TridentNotebook`**, with `typeProperties`: `notebookId` (String, required), `workspaceId` (String, required), `parameters` (Object, optional), **`sessionTag`** (String, optional — this is the real property name for High Concurrency session tagging).
  - `PBISemanticModelRefresh` `typeProperties`: `groupId`, `workspaceId`, `datasetId`, `waitOnCompletion`, `commitMode`, `operationType`, etc.
  - `ForEach` `typeProperties`: `items` (Expression, required array), `activities` (required), `isSequential` (default `false`), `batchCount`.
  - `Filter` `typeProperties`: `condition` (Expression), `items` (Expression, input array).
  - The REST API doc's "Type" column (e.g. `String`) does **not** reliably indicate whether a field accepts a dynamic `{"value": "@...", "type": "Expression"}` object instead of a literal — `PBISemanticModelRefresh`'s `groupId`/`datasetId` are documented as plain `String` but are proven live in `Pipeline_SemanticModels_V2.DataPipeline`'s real committed JSON to accept `{"value": "@item().workspaceId", "type": "Expression"}`. `TridentNotebook`'s `notebookId`/`workspaceId` are the same structural type of field, so the same dynamic form is expected to work — **confirmed for real in Task 4 below before the full pipelines are built around it.**
- **Lookup activity** supports **Lakehouse Files** as a source with **JSON format** (confirmed via `learn.microsoft.com/fabric/data-factory/format-json` — JSON format is explicitly supported for Lookup activity + Lakehouse Files connector).
- **OneLake is ADLS Gen2 API-compatible** — a plain Python script (not a Fabric notebook) can write a file into a Lakehouse's `Files/` section using the `azure-storage-file-datalake` SDK's `DataLakeServiceClient`, pointed at `https://onelake.dfs.fabric.microsoft.com`, authenticated with the same `ClientSecretCredential` `lib.py` already uses. This project's own DuckDB verification scripts already read from this same endpoint (`abfss://...@onelake.dfs.fabric.microsoft.com/...`) via a different client, confirming the endpoint and workspace/lakehouse-ID-as-path-segment structure are real and correct.
- **`Pipeline_DP_Master_Orchestrator` has no `.schedules` file** — it has never actually been on a recurring schedule (only run manually so far). There is no existing schedule to preserve; this plan sets real schedule times fresh, matching the old `LH_Master_Data` pipeline's proven cadence for consistency (Task 15).
- Real workspace/lakehouse IDs already confirmed this project (reused from the CI/CD plan):

| Name | ID |
|---|---|
| `DP - Staging - Dev` | `ab15d64d-c7ba-415d-9bcf-7feb1ef9b201` |
| `DP - Presentation - Dev` | `73fd5443-240e-410a-990a-98827f32c087` |
| `DP_Staging` Dev-tier lakehouse | `876255e0-d462-4697-adc1-4a655f5bb101` |
| `DP_Presentation` Dev-tier lakehouse | `966efc8a-16f9-423b-aa43-e368fcd8fb91` |
| `RP - Sandbox` | `ba9d8de4-ef13-44e6-9156-e23a2511f3ad` |

---

### Task 1: Set up the worktree

**Files:** none — environment setup only.

- [ ] **Step 1: Create a fresh worktree and branch**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git fetch origin dev
git worktree add .worktrees/dp-refresh-pipeline -b dp-refresh-pipeline origin/dev
```

Expected: worktree created, branch `dp-refresh-pipeline` checked out inside it, based on the current tip of `dev` (which already has the corrected `deploy_backend.py`/`lib.py` from the CI/CD plan's scope-fix work).

---

### Task 2: Look up the real notebook item IDs

**Files:** none — this is a lookup, not a code change.

Each `TridentNotebook` pipeline activity needs a real `notebookId` + `workspaceId`, not a repo path. Look these up now so Task 6 can write them straight into the config file.

- [ ] **Step 1: Get each Silver notebook's item ID (in `DP - Staging - Dev`)**

```bash
export PATH="$HOME/.local/bin:$PATH"
for nb in Build_Silver_PartInformation Build_Silver_ArMaster Build_Silver_ArMasterCustomer \
          Build_Silver_Contact Build_Silver_InSalOrd Build_Silver_InSalPar Build_Silver_BranchName; do
  echo "=== $nb ==="
  fab get "DP - Staging - Dev.Workspace/${nb}.Notebook" -q "id"
done
```

Expected: a GUID printed for each of the 7 names.

- [ ] **Step 2: Get each Gold notebook's item ID (in `DP - Presentation - Dev`)**

```bash
for nb in Build_Gold_Parts Build_Gold_DealerGroupCode Build_Gold_Franchise Build_Gold_BranchLocation; do
  echo "=== $nb ==="
  fab get "DP - Presentation - Dev.Workspace/${nb}.Notebook" -q "id"
done
fab get "DP - Presentation - Dev.Workspace/Dimensions/Build_Gold_CustomerList.Notebook" -q "id"
fab get "DP - Presentation - Dev.Workspace/Fact Tables/60 Days Past Due/Build_Gold_InSalOrdInSalPar.Notebook" -q "id"
```

Expected: a GUID printed for each of the 6 names.

- [ ] **Step 3: Record all 13 IDs**

Write them down (workspace ID is already known: `ab15d64d-c7ba-415d-9bcf-7feb1ef9b201` for Silver, `73fd5443-240e-410a-990a-98827f32c087` for Gold) — Task 6 needs the exact values.

---

### Task 3: Look up the real Sandbox semantic model dataset IDs

**Files:** none — lookup only.

- [ ] **Step 1: Get each report's Dev-tier (`RP - Sandbox`) SemanticModel item ID**

```bash
for report in "Bin Location Report" "Physical Inventory" "60+ Days Past Due"; do
  echo "=== $report ==="
  fab get "RP - Sandbox.Workspace/${report}.SemanticModel" -q "id"
done
```

Expected: a GUID printed for each of the 3 reports. Workspace ID is already known:
`ba9d8de4-ef13-44e6-9156-e23a2511f3ad`.

- [ ] **Step 2: Record all 3 IDs**

Task 6's config file uses these as `reports[].semantic_model.dev.datasetId` — do not leave these as the spec's `null` placeholders.

---

### Task 4: Verify `TridentNotebook` accepts a dynamic `notebookId`/`workspaceId`

**Files:** none — this is a throwaway portal test, deleted afterward. Confirms the
core mechanism (Task 6's "Real API facts" note) before three real pipelines get built
around it.

- [ ] **Step 1: Build a 2-item test pipeline**

In `DP - Presentation - Dev`, create a new Data Pipeline named `zz_test_dynamic_notebook`
(the `zz_` prefix marks it as throwaway). Add a `ForEach` activity:
- **Items**: switch to dynamic content, enter:
  ```
  @json('[{"name":"Build_Gold_Franchise","notebookId":"<Build_Gold_Franchise's real ID from Task 2>","workspaceId":"73fd5443-240e-410a-990a-98827f32c087"},{"name":"Build_Gold_DealerGroupCode","notebookId":"<Build_Gold_DealerGroupCode's real ID from Task 2>","workspaceId":"73fd5443-240e-410a-990a-98827f32c087"}]')
  ```
- **Batch count**: 2 (not sequential).

Inside the ForEach, add a `Notebook` activity. In its Settings, switch **both** the
Workspace and Notebook pickers to dynamic content (look for a "pencil"/expression
icon next to each dropdown — if the UI doesn't offer this directly on the picker,
switch to the pipeline's **Code** view (`</>` icon, top right) and edit the activity's
JSON directly to set:
```json
"typeProperties": {
  "notebookId": {"value": "@item().notebookId", "type": "Expression"},
  "workspaceId": {"value": "@item().workspaceId", "type": "Expression"}
}
```

- [ ] **Step 2: Run it and check the real result**

Run the pipeline. Go to **Monitor** → the run → check the Notebook activity's 2
iterations under **All Runs**. Expected: two separate notebook executions, one for
`Build_Gold_Franchise` and one for `Build_Gold_DealerGroupCode` (confirm via each
run's own Snapshot/monitoring detail, not just "succeeded" — the whole point is
confirming they ran *different* notebooks, not the same one twice).

- [ ] **Step 3: Record the result and clean up**

If both notebooks really ran: the mechanism is confirmed, proceed to Task 10+ as
written. If it silently ran the same notebook both times, or failed to accept the
dynamic value: **stop and reconsider** — the code-view JSON edit (Step 1) is the
fallback path (build every ForEach's Notebook activity via Code view rather than the
property picker), which still works structurally, just isn't driven by the
dropdown UI. Either way, delete `zz_test_dynamic_notebook` once confirmed — it's not
part of the real architecture.

---

### Task 5: Write the shared config file

**Files:**
- Create: `fabric-workspace-docs/deploy/dp_backend_scope.json`

Uses the real notebook IDs (Task 2), dataset IDs (Task 3), and the exact
`silver_notebooks`/`gold_notebooks` per report already verified against each
report's real `.tmdl` references (spec Section 4). Do not re-derive these — they're
already correct.

- [ ] **Step 1: Write the file**

```json
{
  "notebooks": [
    {"name": "Build_Silver_PartInformation", "tier": "silver", "cadence": "daily",
     "notebookId": "<from Task 2>", "workspaceId": "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201",
     "path": "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_PartInformation.Notebook"},
    {"name": "Build_Silver_ArMaster", "tier": "silver", "cadence": "daily",
     "notebookId": "<from Task 2>", "workspaceId": "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201",
     "path": "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_ArMaster.Notebook"},
    {"name": "Build_Silver_ArMasterCustomer", "tier": "silver", "cadence": "daily",
     "notebookId": "<from Task 2>", "workspaceId": "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201",
     "path": "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_ArMasterCustomer.Notebook"},
    {"name": "Build_Silver_Contact", "tier": "silver", "cadence": "daily",
     "notebookId": "<from Task 2>", "workspaceId": "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201",
     "path": "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_Contact.Notebook"},
    {"name": "Build_Silver_InSalOrd", "tier": "silver", "cadence": "daily",
     "notebookId": "<from Task 2>", "workspaceId": "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201",
     "path": "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_InSalOrd.Notebook"},
    {"name": "Build_Silver_InSalPar", "tier": "silver", "cadence": "daily",
     "notebookId": "<from Task 2>", "workspaceId": "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201",
     "path": "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_InSalPar.Notebook"},
    {"name": "Build_Silver_BranchName", "tier": "silver", "cadence": "monthly",
     "notebookId": "<from Task 2>", "workspaceId": "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201",
     "path": "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_BranchName.Notebook"},

    {"name": "Build_Gold_Parts", "tier": "gold", "cadence": "daily",
     "notebookId": "<from Task 2>", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
     "path": "workspaces/DP - Presentation - Dev/Build_Gold_Parts.Notebook"},
    {"name": "Build_Gold_CustomerList", "tier": "gold", "cadence": "daily",
     "notebookId": "<from Task 2>", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
     "path": "workspaces/DP - Presentation - Dev/Dimensions/Build_Gold_CustomerList.Notebook"},
    {"name": "Build_Gold_InSalOrdInSalPar", "tier": "gold", "cadence": "daily",
     "notebookId": "<from Task 2>", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
     "path": "workspaces/DP - Presentation - Dev/Fact Tables/60 Days Past Due/Build_Gold_InSalOrdInSalPar.Notebook"},
    {"name": "Build_Gold_BranchLocation", "tier": "gold", "cadence": "monthly",
     "notebookId": "<from Task 2>", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
     "path": "workspaces/DP - Presentation - Dev/Build_Gold_BranchLocation.Notebook"},
    {"name": "Build_Gold_DealerGroupCode", "tier": "gold", "cadence": "monthly",
     "notebookId": "<from Task 2>", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
     "path": "workspaces/DP - Presentation - Dev/Build_Gold_DealerGroupCode.Notebook"},
    {"name": "Build_Gold_Franchise", "tier": "gold", "cadence": "monthly",
     "notebookId": "<from Task 2>", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
     "path": "workspaces/DP - Presentation - Dev/Build_Gold_Franchise.Notebook"}
  ],
  "reports": [
    {
      "name": "Bin Location Report",
      "silver_notebooks": ["Build_Silver_PartInformation", "Build_Silver_BranchName"],
      "gold_notebooks": ["Build_Gold_Parts", "Build_Gold_BranchLocation", "Build_Gold_DealerGroupCode", "Build_Gold_Franchise"],
      "semantic_model": {
        "dev": {"workspaceId": "ba9d8de4-ef13-44e6-9156-e23a2511f3ad", "datasetId": "<from Task 3>"},
        "prod": {"workspaceId": null, "datasetId": null}
      }
    },
    {
      "name": "Physical Inventory",
      "silver_notebooks": ["Build_Silver_PartInformation", "Build_Silver_BranchName"],
      "gold_notebooks": ["Build_Gold_BranchLocation"],
      "semantic_model": {
        "dev": {"workspaceId": "ba9d8de4-ef13-44e6-9156-e23a2511f3ad", "datasetId": "<from Task 3>"},
        "prod": {"workspaceId": "4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7", "datasetId": "80c1dc15-60b3-4c6a-9398-3c79b77a4667"}
      }
    },
    {
      "name": "60+ Days Past Due",
      "silver_notebooks": ["Build_Silver_ArMaster", "Build_Silver_ArMasterCustomer", "Build_Silver_InSalOrd", "Build_Silver_InSalPar", "Build_Silver_BranchName"],
      "gold_notebooks": ["Build_Gold_CustomerList", "Build_Gold_InSalOrdInSalPar", "Build_Gold_BranchLocation"],
      "semantic_model": {
        "dev": {"workspaceId": "ba9d8de4-ef13-44e6-9156-e23a2511f3ad", "datasetId": "<from Task 3>"},
        "prod": {"workspaceId": "67fefa98-9e80-4a79-afdd-c8988b6e64fc", "datasetId": "2516982b-f52f-4676-b879-525e089e9b9e"}
      }
    }
  ]
}
```

Fill in the `<from Task 2>`/`<from Task 3>` placeholders with the real values looked
up earlier — every other value above is already real and verified, do not change
them. `prod` semantic model values for Physical Inventory / 60+ Days Past Due are
pre-filled from the live `Pipeline_SemanticModels_V2` JSON (traceability only — not
live in this config until actual Prod promotion, per Task 6 of the CI/CD plan's
promotion checklist). Bin Location Report's `prod` stays `null` — it has no
production semantic model yet.

- [ ] **Step 2: Validate it's well-formed JSON**

```bash
python -c "import json; json.load(open('fabric-workspace-docs/deploy/dp_backend_scope.json'))" && echo VALID
```

Expected: `VALID`, no exception.

- [ ] **Step 3: Commit**

```bash
cd "fabric-workspace-docs/.worktrees/dp-refresh-pipeline"
git add deploy/dp_backend_scope.json
git commit -m "Add shared DP backend scope config

Single source of truth for deploy_backend.py's deploy scope and all
three refresh pipelines' notebook/report arrays, closing the drift
bug that caused the earlier missing-9-notebooks scoping bug.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 6: Add `write_lakehouse_file()` and `load_backend_scope()` to `lib.py`

**Files:**
- Modify: `fabric-workspace-docs/deploy/lib.py`
- Modify: `fabric-workspace-docs/deploy/requirements.txt`

- [ ] **Step 1: Add the new dependency**

Add one line to `deploy/requirements.txt`:

```
azure-storage-file-datalake
```

Full expected file content:
```
fabric-cicd
azure-identity
requests
duckdb
azure-storage-file-datalake
```

- [ ] **Step 2: Add the two new functions to `lib.py`**

Insert after the existing `get_credential()` function (keep `stage_items()` and
`deploy()` unchanged):

```python
import json


def load_backend_scope(repo_root: Path) -> dict:
    """Load the shared DP backend scope config (notebooks + reports in scope).

    Single source of truth for both deploy_backend.py's deploy scope and all
    three refresh pipelines - see dp_backend_scope.json's own structure.
    """
    config_path = repo_root / "deploy" / "dp_backend_scope.json"
    with open(config_path, encoding="utf-8") as f:
        return json.load(f)


def notebooks_by_tier(scope: dict, tier: str) -> list[dict]:
    """Return the notebook entries for one tier ('silver' or 'gold'), regardless
    of cadence - deploy_backend.py pushes all notebook code on every deploy,
    independent of how often each notebook actually runs."""
    return [nb for nb in scope["notebooks"] if nb["tier"] == tier]


def resolve_scope_for_environment(scope: dict, environment: str) -> dict:
    """Build the environment-resolved copy of the scope config that gets written
    to each tier's Lakehouse Files - each report's semantic_model collapses from
    {dev: {...}, prod: {...}} down to just this environment's {workspaceId,
    datasetId}, and reports with no real id yet for this environment (not
    promoted here yet) are dropped entirely, so the refresh pipeline's array
    never contains a null id."""
    resolved_reports = []
    for report in scope["reports"]:
        ids = report["semantic_model"][environment]
        if ids["workspaceId"] is None or ids["datasetId"] is None:
            continue
        resolved_reports.append({
            "name": report["name"],
            "workspaceId": ids["workspaceId"],
            "datasetId": ids["datasetId"],
        })
    return {"notebooks": scope["notebooks"], "reports": resolved_reports}


def write_lakehouse_file(
    workspace_id: str, lakehouse_id: str, file_path: str, content: dict
) -> None:
    """Write a JSON file into a Lakehouse's Files section via OneLake's ADLS
    Gen2-compatible endpoint - lets a plain Python script (not a Fabric notebook)
    publish config a pipeline's Lookup activity can read at runtime, with no
    separate sync job."""
    from azure.storage.filedatalake import DataLakeServiceClient

    service_client = DataLakeServiceClient(
        account_url="https://onelake.dfs.fabric.microsoft.com",
        credential=get_credential(),
    )
    file_system_client = service_client.get_file_system_client(file_system=workspace_id)
    file_client = file_system_client.get_file_client(f"{lakehouse_id}/Files/{file_path}")
    file_client.upload_data(json.dumps(content, indent=2).encode("utf-8"), overwrite=True)
```

- [ ] **Step 3: Compile-check**

```bash
cd "fabric-workspace-docs/.worktrees/dp-refresh-pipeline"
python -m py_compile deploy/lib.py
```

Expected: no output, exit code 0.

- [ ] **Step 4: Commit**

```bash
git add deploy/lib.py deploy/requirements.txt
git commit -m "Add config-loading and Lakehouse Files write helpers to lib.py

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 7: Rewrite `deploy_backend.py` to use the shared config

**Files:**
- Modify: `fabric-workspace-docs/deploy/deploy_backend.py`

Replaces the hardcoded `STAGING_NOTEBOOKS`/`PRESENTATION_NOTEBOOKS` lists with
config-driven ones, and writes the environment-resolved config to each tier's
Lakehouse Files after each deploy.

- [ ] **Step 1: Rewrite the file**

```python
"""Deploy the DP backend notebooks in scope to a target tier (dev or prod)."""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from lib import (
    deploy,
    load_backend_scope,
    notebooks_by_tier,
    resolve_scope_for_environment,
    stage_items,
    write_lakehouse_file,
)

REPO_ROOT = Path(__file__).parent.parent

WORKSPACE_IDS = {
    "dev": {
        "staging": "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201",
        "presentation": "73fd5443-240e-410a-990a-98827f32c087",
    },
    "prod": {
        "staging": "189e5c0a-548a-4feb-93d6-dda9ebbe96c1",
        "presentation": "7836042d-adb1-4846-b70d-bd42980054c5",
    },
}

LAKEHOUSE_IDS = {
    "dev": {
        "staging": "876255e0-d462-4697-adc1-4a655f5bb101",
        "presentation": "966efc8a-16f9-423b-aa43-e368fcd8fb91",
    },
    "prod": {
        "staging": "6713bd45-a4ad-47e6-8bff-1bb0415e9784",
        "presentation": "29d9df80-a383-4d40-9807-1e2e6cbff88f",
    },
}


def main(environment: str) -> None:
    scope = load_backend_scope(REPO_ROOT)
    ids = WORKSPACE_IDS[environment]
    lh_ids = LAKEHOUSE_IDS[environment]

    staging_notebooks = [REPO_ROOT / nb["path"] for nb in notebooks_by_tier(scope, "silver")]
    staging_stage = stage_items(REPO_ROOT, staging_notebooks)
    deploy(
        workspace_id=ids["staging"],
        repository_directory=staging_stage,
        item_type_in_scope=["Notebook"],
        environment=environment,
    )
    print(f"Deployed {len(staging_notebooks)} Silver notebooks to "
          f"{environment} staging workspace.")

    presentation_notebooks = [REPO_ROOT / nb["path"] for nb in notebooks_by_tier(scope, "gold")]
    presentation_stage = stage_items(REPO_ROOT, presentation_notebooks)
    deploy(
        workspace_id=ids["presentation"],
        repository_directory=presentation_stage,
        item_type_in_scope=["Notebook"],
        environment=environment,
    )
    print(f"Deployed {len(presentation_notebooks)} Gold notebooks to "
          f"{environment} presentation workspace.")

    resolved = resolve_scope_for_environment(scope, environment)
    write_lakehouse_file(
        workspace_id=ids["staging"],
        lakehouse_id=lh_ids["staging"],
        file_path="config/dp_backend_scope.json",
        content=resolved,
    )
    write_lakehouse_file(
        workspace_id=ids["presentation"],
        lakehouse_id=lh_ids["presentation"],
        file_path="config/dp_backend_scope.json",
        content=resolved,
    )
    print(f"Wrote resolved config to both {environment} tier lakehouses' "
          f"Files/config/dp_backend_scope.json.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--environment", choices=["dev", "prod"], required=True)
    args = parser.parse_args()
    main(args.environment)
```

- [ ] **Step 2: Compile-check**

```bash
python -m py_compile deploy/deploy_backend.py
```

Expected: no output, exit code 0.

- [ ] **Step 3: Commit**

```bash
git add deploy/deploy_backend.py
git commit -m "Rewrite deploy_backend.py to read scope from dp_backend_scope.json

Replaces hardcoded STAGING_NOTEBOOKS/PRESENTATION_NOTEBOOKS lists with
config-driven ones, and writes an environment-resolved copy of the
config into each tier's Lakehouse Files on every deploy, so the three
refresh pipelines always see what was actually last deployed.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 8: Real dry run — confirm the config lands in Lakehouse Files

**Files:** none — verification only, matching this project's own "verify against
real APIs, don't assume" discipline used for every prior deploy script change.

- [ ] **Step 1: Run the updated script against Dev tier**

```bash
export FABRIC_CICD_TENANT_ID="<tenant id>"
export FABRIC_CICD_CLIENT_ID="<client id>"
export FABRIC_CICD_CLIENT_SECRET="<client secret>"
cd "fabric-workspace-docs/.worktrees/dp-refresh-pipeline"
pip install -r deploy/requirements.txt
python deploy/deploy_backend.py --environment dev
```

Expected: the same "Deployed N Silver/Gold notebooks" messages as before, plus the
new "Wrote resolved config to both dev tier lakehouses'..." line, no exceptions.

- [ ] **Step 2: Independently verify the file actually landed, with real content**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
for ws, lh, label in [
    ("ab15d64d-c7ba-415d-9bcf-7feb1ef9b201", "876255e0-d462-4697-adc1-4a655f5bb101", "staging"),
    ("73fd5443-240e-410a-990a-98827f32c087", "966efc8a-16f9-423b-aa43-e368fcd8fb91", "presentation"),
]:
    path = f"abfss://{ws}@onelake.dfs.fabric.microsoft.com/{lh}/Files/config/dp_backend_scope.json"
    content = con.execute(f"SELECT content FROM read_text('{path}')").fetchone()[0]
    print(f"=== {label} ===")
    print(content[:300])
```

Expected: real JSON printed for both, starting with `{"notebooks": [...`, matching
what `dp_backend_scope.json` actually contains (confirms the write worked and the
read path is correct — not just "no exception was thrown").

---

### Task 9: Enable High Concurrency mode (Brian, Fabric portal)

**Files:** none — workspace settings, not git-tracked.

- [ ] **Step 1: Enable it in `DP - Staging - Dev`**

Workspace → Workspace settings → Data Engineering/Science → Spark settings → High
concurrency → enable **"For pipeline running multiple notebooks."** Save.

- [ ] **Step 2: Enable it in `DP - Presentation - Dev`**

Same steps, same workspace setting, different workspace.

---

### Task 10: Create the Fabric Environment items (Brian, Fabric portal)

**Files:** none initially — the Environment items become git-tracked automatically
via Fabric's Git integration once created and committed, same as every other item in
this project. (fabric-cicd's own support for redeploying Environment items on future
CI/CD runs is a real unknown per the spec — not a blocker, since Fabric's own Git
integration tracks the item regardless of whether fabric-cicd can also publish it.)

- [ ] **Step 1: Create an Environment in `DP - Staging - Dev`**

Workspace → New item → Environment → name it `DP_Silver_HighConcurrency`. Open it →
**Spark properties** tab → Add:
```
spark.highConcurrency.max = 20
```
Save → **Publish** (Environment changes need an explicit publish before notebooks
can use them).

- [ ] **Step 2: Attach it to all 7 Silver notebooks**

For each of `Build_Silver_PartInformation`, `Build_Silver_BranchName`,
`Build_Silver_ArMaster`, `Build_Silver_ArMasterCustomer`, `Build_Silver_Contact`,
`Build_Silver_InSalOrd`, `Build_Silver_InSalPar`: open the notebook → Home tab →
**Environment** dropdown → select `DP_Silver_HighConcurrency`.

- [ ] **Step 3: Create an Environment in `DP - Presentation - Dev`**

Same steps, name it `DP_Gold_HighConcurrency`, same `spark.highConcurrency.max = 20`
Spark property, publish.

- [ ] **Step 4: Attach it to all 6 Gold notebooks**

`Build_Gold_Parts`, `Build_Gold_DealerGroupCode`, `Build_Gold_Franchise`,
`Build_Gold_BranchLocation`, `Build_Gold_CustomerList`, `Build_Gold_InSalOrdInSalPar`
— same Environment dropdown, select `DP_Gold_HighConcurrency`.

- [ ] **Step 5: Commit via Fabric Git integration**

Both workspaces → Source control → Commit. Confirm (`git pull origin dev` in the
main `fabric-workspace-docs` checkout, not this plan's worktree) that
`DP_Silver_HighConcurrency.Environment` and `DP_Gold_HighConcurrency.Environment`
folders appear, and that the 13 notebook `.platform`/definition files show the new
environment binding.

---

### Task 11: Build `Pipeline_DP_Daily_Refresh` (Brian, Fabric portal)

**Files:** none in `data-projects` — becomes git-tracked via Fabric's own Git
integration once created and committed, same as every pipeline in this project.

- [ ] **Step 1: Create the pipeline**

`DP - Presentation - Dev` → New → Data pipeline → name it `Pipeline_DP_Daily_Refresh`.

- [ ] **Step 2: Add the config Lookup**

Add a **Lookup** activity, name it `Lookup_Config`. Settings → source: a Lakehouse
Files connection to `DP_Presentation`'s lakehouse → file path
`config/dp_backend_scope.json` → format: JSON → check **First row only** (the file
is one JSON object, not a list of records). Run it once standalone (Debug) and check
the **Output** tab to confirm the exact shape of `output.firstRow` before wiring the
next steps — adjust the `.firstRow`/`.value` expressions below if the real Output
pane shows a different shape than expected.

- [ ] **Step 3: Filter to daily-cadence Silver notebooks**

Add a **Filter** activity, name it `Filter_SilverDaily`, `dependsOn` `Lookup_Config`
(Succeeded). Settings:
- **Items**: `@activity('Lookup_Config').output.firstRow.notebooks`
- **Condition**: `@and(equals(item().tier, 'silver'), equals(item().cadence, 'daily'))`

- [ ] **Step 4: ForEach over the filtered Silver notebooks**

Add a **ForEach** activity, name it `ForEach_SilverDaily`, `dependsOn`
`Filter_SilverDaily` (Succeeded). Settings: **Sequential** unchecked, **Batch count**
`3`, **Items**: `@activity('Filter_SilverDaily').output.value`.

Inside it, add a **Notebook** activity, name it `Notebook_SilverDaily`. Switch to
**Code view** (`</>`) for this activity and set:
```json
"typeProperties": {
  "notebookId": {"value": "@item().notebookId", "type": "Expression"},
  "workspaceId": {"value": "@item().workspaceId", "type": "Expression"},
  "sessionTag": "dp-silver-daily"
}
```
(Confirmed dynamic per Task 4 — if Task 4 found the dropdown pickers themselves
support dynamic content, use those instead of Code view; the JSON shape is the
same either way.)

Add a second activity inside the ForEach, an **AppendVariable**, name it
`Append_FailedSilverDaily`, `dependsOn` `Notebook_SilverDaily` (**Failed**).
`typeProperties`: `variableName: "FailedItems"`, `value: {"value": "@item().name", "type": "Expression"}`.
(Create the `FailedItems` array-type pipeline variable first, via the canvas
background → Variables tab → `+ New`.)

- [ ] **Step 5: Gate, then repeat for Gold**

Add a **Wait** activity, name it `Wait_SilverDaily_Gate`, `waitTimeInSeconds: 1`,
`dependsOn` `ForEach_SilverDaily` with **both** `Succeeded` and `Failed` conditions
(so one failed notebook doesn't block the Gold tier).

Repeat Steps 3-4 for Gold: `Filter_GoldDaily` (condition:
`@and(equals(item().tier, 'gold'), equals(item().cadence, 'daily'))`, items:
`@activity('Lookup_Config').output.firstRow.notebooks`, `dependsOn`
`Wait_SilverDaily_Gate` Succeeded), `ForEach_GoldDaily` (batch count 3, session tag
`dp-gold-daily`), `Append_FailedGoldDaily`.

- [ ] **Step 6: Success/failure summary email**

Add a **Wait** activity `Wait_GoldDaily_Gate` (1s, `dependsOn` `ForEach_GoldDaily`
Succeeded+Failed). After it, add an **IfCondition** activity checking
`@equals(length(variables('FailedItems')), 0)` — `ifTrueActivities`: an
**Office365Email** (or Outlook) activity to `bfox@spitractor.com`, subject
`Pipeline_DP_Daily_Refresh - Success`; `ifFalseActivities`: same activity type,
subject `Pipeline_DP_Daily_Refresh - Some Items Failed`, body including
`@{join(variables('FailedItems'), ', ')}` — matching `Pipeline_SemanticModels_V2`'s
exact real pattern.

- [ ] **Step 7: Add the daily schedule**

Pipeline → Add trigger → New → Schedule → Daily → **4:15 AM CST** (matching the old
`LH_Master_Data` pipeline's proven timing for consistency — there is no existing
schedule on the current `Pipeline_DP_Master_Orchestrator` to preserve, this is a
fresh choice).

- [ ] **Step 8: Save and commit via Fabric Git integration**

`DP - Presentation - Dev` → Source control → Commit. Confirm
`Pipeline_DP_Daily_Refresh.DataPipeline` appears after `git pull origin dev`.

---

### Task 12: Build `Pipeline_DP_Monthly_Refresh` (Brian, Fabric portal)

**Files:** none — same git-tracking as Task 11.

- [ ] **Step 1: Build the same shape as `Pipeline_DP_Daily_Refresh`**

Create `Pipeline_DP_Monthly_Refresh`. Repeat Task 11's Steps 2-6 exactly, with two
changes: every `Filter` condition checks `cadence == 'monthly'` instead of `'daily'`
(e.g. `@and(equals(item().tier, 'silver'), equals(item().cadence, 'monthly'))`), and
session tags are `dp-silver-monthly`/`dp-gold-monthly` instead of the daily ones.
Email subjects: `Pipeline_DP_Monthly_Refresh - Success` /
`- Some Items Failed`.

- [ ] **Step 2: Add the monthly schedule**

Pipeline → Add trigger → New → Schedule → Monthly → **1st of month, 7:30 AM CST**
(matching `Pipeline_Dimensions_Monthly`'s own real, live, proven timing exactly).

- [ ] **Step 3: Save and commit via Fabric Git integration**

Same as Task 11 Step 8.

---

### Task 13: Build `Pipeline_DP_SemanticModel_Refresh` (Brian, Fabric portal)

**Files:** none — same git-tracking pattern.

- [ ] **Step 1: Create the pipeline and read the config**

Create `Pipeline_DP_SemanticModel_Refresh` in `DP - Presentation - Dev`. Add a
**Lookup** activity `Lookup_Config` — same Lakehouse Files JSON source as Task 11
Step 2 (`config/dp_backend_scope.json`, First row only checked).

- [ ] **Step 2: ForEach over the reports array**

Add a **ForEach** activity `ForEach_SMRefresh`, `dependsOn` `Lookup_Config`
(Succeeded). Batch count `3`, not sequential. Items:
`@activity('Lookup_Config').output.firstRow.reports` (this array is already
environment-resolved and pre-filtered to reports with a real dataset ID for this
tier — `deploy_backend.py`'s `resolve_scope_for_environment()` drops any report
without one, so no separate Filter activity is needed here, unlike the notebook
tiers).

Inside it, add a **PBISemanticModelRefresh** activity, name it
`Refresh_SemanticModel`. `typeProperties`:
```json
{
  "method": "POST",
  "operationType": "SemanticModelRefresh",
  "groupId": {"value": "@item().workspaceId", "type": "Expression"},
  "datasetId": {"value": "@item().datasetId", "type": "Expression"},
  "waitOnCompletion": true,
  "commitMode": "Transactional"
}
```
(Matches `Pipeline_SemanticModels_V2`'s real, live, proven shape exactly.) You'll
need a Power BI connection the first time you add this activity type — reuse the
existing one if the picker offers it (same connection `Pipeline_SemanticModels_V2`
already uses), or create a new one scoped to this SPN/account.

Add `Append_FailedSMRefresh` (AppendVariable, `dependsOn` `Refresh_SemanticModel`
Failed, appends `@item().name` to `FailedItems`).

- [ ] **Step 3: Success/failure summary email**

Add `Wait_SMRefresh_Gate` (1s, `dependsOn` `ForEach_SMRefresh` Succeeded+Failed),
then the same IfCondition + email pattern as Task 11 Step 6, subjects
`Pipeline_DP_SemanticModel_Refresh - Success` / `- Some Reports Failed`.

- [ ] **Step 4: Add the daily schedule, offset after the data pipeline**

Pipeline → Add trigger → New → Schedule → Daily → **6:30 AM CST** — a fixed offset
after `Pipeline_DP_Daily_Refresh`'s 4:15 AM run (matching the old
`LH_Master_Data`/`Pipeline_SemanticModels` pipelines' exact proven 4:15→6:30 gap,
not a cross-pipeline "Invoke Pipeline" dependency — simpler and already proven at
this project's real scale).

- [ ] **Step 5: Save and commit via Fabric Git integration**

Same as Task 11 Step 8.

---

### Task 14: Trigger all three pipelines manually and verify with real data

**Files:** none — verification only, matching this project's "don't just trust a
green checkmark" discipline used throughout (e.g. the CI/CD plan's Task 11).

- [ ] **Step 1: Run `Pipeline_DP_Daily_Refresh` manually**

Fabric portal → open the pipeline → **Run**. Watch it complete in **Monitor**.
Expected: `ForEach_SilverDaily` and `ForEach_GoldDaily` both show all iterations
Succeeded, `FailedItems` empty, success email received.

- [ ] **Step 2: Independently verify real table freshness**

```python
import duckdb
from datetime import datetime, timezone
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91"
for table in ["dim_Parts", "dim_CustomerList", "Fact_InSalOrd_InSalPar"]:
    n = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/Tables/{table}')").fetchone()[0]
    print(f"{table}: {n:,} rows")
```

Expected: real, sensible row counts for all 3 daily-tier Gold tables — not just "the
pipeline said Succeeded." (This is the same DuckDB pattern used everywhere else in
this project for independent verification.)

- [ ] **Step 3: Run `Pipeline_DP_Monthly_Refresh` manually**

Same as Step 1, for the monthly pipeline (can't wait for the real 1st-of-month
schedule to prove this works). Verify `dim_BranchLocation`, `dim_DealerGroupCode`,
`dim_Franchise` the same way as Step 2.

- [ ] **Step 4: Run `Pipeline_DP_SemanticModel_Refresh` manually**

Same as Step 1. Then open one of the 3 Sandbox reports in the Fabric portal and
check its semantic model's **Refresh history** — confirm a real, recent successful
refresh timestamp, not just the pipeline activity's own "Succeeded" status (the
`PBISemanticModelRefresh` activity waiting on completion doesn't guarantee the
refresh itself did something meaningful — check the actual refresh history).

---

### Task 15: Update the CI/CD plan to point at this one

**Files:**
- Modify: `data-projects/docs/superpowers/plans/2026-09-17-fabric-cicd-deployment.md`

- [ ] **Step 1: Add a superseding note to Task 12**

Find the existing Task 12 section (`### Task 12: Create the recurring refresh Data
Pipeline...`) and add, immediately after its final paragraph (the one ending "...not
yet done as of this note."):

```markdown

**Superseded 2026-09-17** by `docs/superpowers/plans/2026-09-17-dp-refresh-pipeline.md`
— that plan replaces this single pipeline with three config-driven pipelines
(`Pipeline_DP_Daily_Refresh`, `Pipeline_DP_Monthly_Refresh`,
`Pipeline_DP_SemanticModel_Refresh`), scoped from the shared
`dp_backend_scope.json` config instead of hardcoded activities. Do not add the 7
missing notebook activities described above directly to
`Pipeline_DP_Master_Orchestrator` — that work happens in the new plan's pipelines
instead. `Pipeline_DP_Master_Orchestrator` itself can be deleted once the three new
pipelines are proven (Task 14 of the new plan) - Brian's call on timing, not urgent.
```

- [ ] **Step 2: Commit**

```bash
cd "data-projects"
git add docs/superpowers/plans/2026-09-17-fabric-cicd-deployment.md
git commit -m "Point Task 12 at the new dedicated refresh pipeline plan

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## What this plan deliberately does not cover

- The `jdis_Part_Information` rebuild (design spec Section 8) — a separate,
  already-scoped future migration effort, not part of this plan.
- Prod-tier pipelines — these three pipelines are Dev-tier only. Promoting them to
  Prod happens alongside each report's own Prod promotion (CI/CD plan Task 15+),
  per the design spec's Section 6 cutover checklist, not built ahead of time here.
- Deleting `Pipeline_DP_Master_Orchestrator` — noted as an optional cleanup in
  Task 15, left to Brian's own timing rather than a required step of this plan.
