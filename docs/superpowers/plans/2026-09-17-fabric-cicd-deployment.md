# fabric-cicd Deployment Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a GitHub Actions + `fabric-cicd` pipeline that promotes the DP backend (Dev tier → Prod tier, notebooks run and independently verified) and the 3 Batch 0 reports (`RP - Dev` → `RP - Sandbox` → real production) through git, with a manual approval gate and a proven recurring refresh schedule required before anything reaches production.

**Architecture:** One GitHub Actions workflow in `fabric-workspace-docs`, triggered on push to `dev` (auto-deploys to Dev-tier backend + `RP - Sandbox`, no gate) and manually via `workflow_dispatch` gated to `main` (deploys to Prod-tier backend + real production report workspaces — a deliberate "Run workflow" click is the approval gate, since GitHub's Required Reviewers protection rule isn't available on this repo's plan for a private repo). A small set of Python scripts do the actual deployment work using `fabric-cicd` as a library; the workflow YAML is orchestration only.

**Tech Stack:** Python 3.12, `fabric-cicd` (pip), `azure-identity` (`ClientSecretCredential`), `requests` (Fabric Jobs REST API), `duckdb` (independent verification), GitHub Actions.

**Reference:** `docs/superpowers/specs/2026-09-16-fabric-cicd-deployment-design.md` — the approved design this plan implements. Read it first if anything below seems underspecified; this plan follows it section-by-section.

---

## Real API facts this plan relies on (verified 2026-09-17, not assumed)

- `fabric-cicd`'s `FabricWorkspace` constructor takes keyword-only args: `workspace_id`, `repository_directory`, `item_type_in_scope`, `environment`, `token_credential`. Deployment is `publish_all_items(target_workspace)` / `unpublish_all_orphan_items(target_workspace)`.
- `item_type_in_scope` order matters for a real, documented bug: `["Report", "SemanticModel"]` fails a preflight check; `["SemanticModel", "Report"]` works (SemanticModel must be deployed before the Report that depends on it).
- `parameter.yml` (repo root) defines `find_replace` rules: `find_value`, `replace_value` (a dict keyed by environment name), optional `is_regex`, `item_type`, `item_name`, `file_path` filters. A regex's first capture group is what gets replaced.
- The Fabric REST API to run a notebook on demand:
  `POST https://api.fabric.microsoft.com/v1/workspaces/{workspaceId}/notebooks/{notebookId}/jobs/execute/instances?beta=false`
  Returns `202` with a `Location` header pointing at `.../items/{itemId}/jobs/instances/{jobInstanceId}` — poll that URL (`GET`, same auth) for a `status` field until it's `Completed`, `Failed`, or `Cancelled`.
- Real workspace/lakehouse IDs (already confirmed live this project, not placeholders):

| Name | ID |
|---|---|
| `DP - Staging - Dev` | `ab15d64d-c7ba-415d-9bcf-7feb1ef9b201` |
| `DP - Staging - Prod` | `189e5c0a-548a-4feb-93d6-dda9ebbe96c1` |
| `DP - Presentation - Dev` | `73fd5443-240e-410a-990a-98827f32c087` |
| `DP - Presentation - Prod` | `7836042d-adb1-4846-b70d-bd42980054c5` |
| `RP - Sandbox` | `ba9d8de4-ef13-44e6-9156-e23a2511f3ad` |
| `RP - Parts Reports` | `4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7` |
| `RP - Financial Reports` | `67fefa98-9e80-4a79-afdd-c8988b6e64fc` |
| `DP_Presentation` Dev-tier lakehouse | `966efc8a-16f9-423b-aa43-e368fcd8fb91` |
| `DP_Presentation` Prod-tier lakehouse | `29d9df80-a383-4d40-9807-1e2e6cbff88f` |
| `DP_Staging` Dev-tier lakehouse | `876255e0-d462-4697-adc1-4a655f5bb101` |
| `DP_Staging` Prod-tier lakehouse | `6713bd45-a4ad-47e6-8bff-1bb0415e9784` |

- Dev-tier and Prod-tier `DP_Presentation` SQL Analytics Endpoints (already confirmed this session, used in every report's `Sql.Database(...)` M query):
  - Dev: `xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com`
  - Prod: `xcrafcusadsu3d3wi4anbgp6we-fucdm6frvvdernynxvbjqacuyu.datawarehouse.fabric.microsoft.com` (looked up 2026-09-17, Task 1)

---

### Task 1: Look up the Prod-tier SQL Analytics Endpoint hostname

**Files:** none — this is a lookup, not a code change.

- [ ] **Step 1: Get the Prod-tier `DP_Presentation` lakehouse's SQL endpoint**

Run (PowerShell or Bash with `fab` on PATH):
```bash
fab get "DP - Presentation - Prod.Workspace/DP_Presentation.Lakehouse" -q "properties.sqlEndpointProperties"
```
Expected: JSON containing a `connectionString` field, e.g.
`"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.datawarehouse.fabric.microsoft.com"`.

- [ ] **Step 2: Record it**

Add a line to the "Real API facts" table at the top of this plan file with the real
value, so Task 6's `parameter.yml` isn't written against a guess.

---

### Task 2: Create the deployment Service Principal (Brian, Fabric/Entra portal)

**Files:** none — this is entirely portal work. Follows the exact recipe already
validated for `SPN-Fabric-Refresh-Automation` (`project_sm_refresh_spn_migration.md`
in memory), reusing the tenant-level groundwork, with a new App Registration scoped
to deployment specifically.

- [ ] **Step 1: Create the App Registration**

Entra ID → App registrations → New registration → name it `SPN-Fabric-CICD-Deploy`.
Needs **Application Administrator** role to create. After creation: Certificates &
secrets → New client secret → copy the **Value** immediately (not the Secret ID —
these look similar; grabbing the wrong one produces a 403 that looks like a
permissions problem later).

- [ ] **Step 2: Add it to the existing security group**

Entra ID → Groups → `SG-Fabric-ServicePrincipals` → add `SPN-Fabric-CICD-Deploy` as a
member. This group is already scoped in Fabric Admin Portal → Tenant settings →
Developer settings → "Service principals can call Fabric public APIs" — no tenant
setting changes needed, this SPN inherits that automatically.

- [ ] **Step 3: Grant API permissions**

Azure Portal → App registrations → `SPN-Fabric-CICD-Deploy` → API permissions → Add a
permission → Power BI Service → Application permissions → `Tenant.ReadWrite.All` →
Grant admin consent. (Same easy-to-miss step documented for the refresh SPN — every
deploy call will 403 without this.)

- [ ] **Step 4: Grant workspace access**

For each of these 7 workspaces, add `SPN-Fabric-CICD-Deploy` as **Contributor**
(Workspace → Manage access → Add people or groups → search the SPN by name):
`DP - Staging - Dev`, `DP - Staging - Prod`, `DP - Presentation - Dev`,
`DP - Presentation - Prod`, `RP - Sandbox`, `RP - Parts Reports`,
`RP - Financial Reports`.

- [ ] **Step 5: Record the 3 credential values**

Note down (don't commit anywhere): Tenant ID, Application (client) ID, and the client
secret **Value** from Step 1. Task 4 needs these as GitHub secrets.

---

### Task 3: Create the GitHub `production` Environment (Brian, GitHub repo settings)

**Files:** none — GitHub repo settings, on `fabric-workspace-docs`.

**Real correction made during execution (2026-09-17):** the original version of this
task called for a Required Reviewers gate. Confirmed live in the GitHub portal:
Required Reviewers is a Team/Enterprise-only protection rule for private
repositories — this repo's `production` environment settings page only shows
"Deployment branches and tags" and secrets/variables, no "Deployment protection
rules" section at all. The steps below reflect what was actually done instead:
`.github/workflows/deploy.yml` (Task 10) uses `workflow_dispatch` as the production
trigger, gated to `refs/heads/main` — a deliberate manual "Run workflow" click is the
approval gate, not an automatic run pausing for review.

- [ ] **Step 1: Create the environment**

`fabric-workspace-docs` repo on GitHub → Settings → Environments → New environment →
name it exactly `production`. (Still worth creating even without Required Reviewers —
it's what scopes the 3 secrets to production-only jobs, via `environment: production`
in the workflow.)

- [ ] **Step 2: Confirm no deployment branch restriction blocks `main`**

Same page → Deployment branches and tags → should default to "No restriction" or
explicitly allow `main`. If it's set to something else, add `main`.

---

### Task 4: Store GitHub Actions secrets

**Files:** none — GitHub repo settings, on `fabric-workspace-docs`.

- [ ] **Step 1: Add repo-level secrets**

Settings → Secrets and variables → Actions → New repository secret. Add three,
using the values recorded in Task 2 Step 5:
- `FABRIC_CICD_TENANT_ID`
- `FABRIC_CICD_CLIENT_ID`
- `FABRIC_CICD_CLIENT_SECRET`

These are read by every deploy script in this plan via environment variables of the
same names — never hardcoded, never logged.

---

### Task 5: Write the shared staging helper

**Files:**
- Create: `fabric-workspace-docs/deploy/lib.py`

`fabric-cicd`'s `FabricWorkspace` deploys everything of the given item type(s) found
under `repository_directory` — there's no "deploy only these named items" parameter.
Both `DP - Presentation - Dev` (many more notebooks than the 4 we want promoted) and
`RP - Dev` (currently only 3 reports, but that won't stay true forever) need an
explicit item allowlist, so every deploy script stages a curated copy into a temp
directory first, then points `fabric-cicd` at that temp directory instead of the real
workspace folder.

- [ ] **Step 1: Write `lib.py`**

```python
"""Shared helpers for the fabric-cicd deployment scripts."""
import os
import shutil
import tempfile
from pathlib import Path

from azure.identity import ClientSecretCredential
from fabric_cicd import FabricWorkspace, publish_all_items


def get_credential() -> ClientSecretCredential:
    """Build the SPN credential from GitHub Actions secrets (env vars)."""
    return ClientSecretCredential(
        tenant_id=os.environ["FABRIC_CICD_TENANT_ID"],
        client_id=os.environ["FABRIC_CICD_CLIENT_ID"],
        client_secret=os.environ["FABRIC_CICD_CLIENT_SECRET"],
    )


def stage_items(source_workspace_dir: Path, item_folder_names: list[str]) -> Path:
    """Copy only the named Fabric item folders (e.g. 'Build_Gold_Parts.Notebook')
    from a real workspace folder into a fresh temp directory, and return that temp
    directory's path. fabric-cicd deploys everything it finds under
    repository_directory, so this is how we scope a deploy to a specific allowlist
    instead of the whole workspace folder.
    """
    stage_dir = Path(tempfile.mkdtemp(prefix="fabric_cicd_stage_"))
    for item_name in item_folder_names:
        source_item_dir = source_workspace_dir / item_name
        if not source_item_dir.is_dir():
            raise FileNotFoundError(
                f"Expected item folder not found: {source_item_dir}"
            )
        shutil.copytree(source_item_dir, stage_dir / item_name)
    return stage_dir


def deploy(
    workspace_id: str,
    repository_directory: Path,
    item_type_in_scope: list[str],
    environment: str,
) -> None:
    """Deploy everything under repository_directory to the given workspace."""
    target_workspace = FabricWorkspace(
        workspace_id=workspace_id,
        repository_directory=str(repository_directory),
        item_type_in_scope=item_type_in_scope,
        environment=environment,
        token_credential=get_credential(),
    )
    publish_all_items(target_workspace)
```

- [ ] **Step 2: Write `requirements.txt`**

```
fabric-cicd
azure-identity
requests
duckdb
```

Create at `fabric-workspace-docs/deploy/requirements.txt`.

- [ ] **Step 3: Verify it imports cleanly**

Run:
```bash
cd "fabric-workspace-docs/deploy"
pip install -r requirements.txt
python -c "import lib; print('lib.py imports OK')"
```
Expected: `lib.py imports OK`, no import errors.

---

### Task 6: Write `parameter.yml`

**Files:**
- Create: `fabric-workspace-docs/parameter.yml` (must be at the repo root —
  `fabric-cicd` looks for it there by convention relative to `repository_directory`'s
  parent, so keep it alongside the `workspaces/` folder)

Two kinds of environment-specific values need swapping at deploy time: each Gold
notebook's `default_lakehouse` METADATA binding (regex, using `fabric-cicd`'s dynamic
`$items.Lakehouse.<Name>.$id` variable so the real ID is resolved per target
workspace rather than hardcoded), and each report's `Sql.Database(...)` connection
string (literal replacement, since a SQL connection string isn't part of Fabric's own
item-reference graph).

- [ ] **Step 1: Write the file**

```yaml
find_replace:
  # Notebook default_lakehouse rebinding - matches the real METADATA block format
  # confirmed in every Build_Gold_*.Notebook / Build_Silver_*.Notebook this session,
  # e.g.:
  #   # META     "default_lakehouse": "966efc8a-16f9-423b-aa43-e368fcd8fb91",
  - find_value: '#\s*META\s+"default_lakehouse":\s*"([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})"'
    replace_value:
      dev: "$items.Lakehouse.DP_Presentation.$id"
      prod: "$items.Lakehouse.DP_Presentation.$id"
    is_regex: "true"
    item_type: "Notebook"

  - find_value: '#\s*META\s+"default_lakehouse_workspace_id":\s*"([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})"'
    replace_value:
      dev: "$workspace.$id"
      prod: "$workspace.$id"
    is_regex: "true"
    item_type: "Notebook"

  # Report connection string - literal host + database swap, not part of Fabric's
  # own item graph so the $items dynamic variable doesn't apply here.
  - find_value: "xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com"
    replace_value:
      dev: "xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com"
      prod: "xcrafcusadsu3d3wi4anbgp6we-fucdm6frvvdernynxvbjqacuyu.datawarehouse.fabric.microsoft.com"
    item_type: ["Report", "SemanticModel"]

  - find_value: '"DP_Presentation"\)'
    replace_value:
      dev: '"DP_Presentation")'
      prod: '"DP_Presentation")'
    item_type: ["Report", "SemanticModel"]
```

The Prod-tier endpoint above (`...fucdm6frvvdernynxvbjqacuyu...`) was looked up as
part of Task 1 (2026-09-17) and is already the real value — nothing left to fill in
here. It's included in this plan as a resolved fact rather than a placeholder, not an
unresolved design question.

(The database name itself, `"DP_Presentation"`, is identical between Dev and Prod
tiers — only the server hostname differs — so that last rule is a same-to-same
mapping included for completeness/documentation, not because it changes anything.)

- [ ] **Step 2: Commit**

```bash
cd "fabric-workspace-docs"
git add parameter.yml
git commit -m "Add fabric-cicd parameter.yml for Dev/Prod tier connection swaps

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 7: Write `deploy_backend.py`

**Files:**
- Create: `fabric-workspace-docs/deploy/deploy_backend.py`

Stages exactly the notebooks in scope (Silver first, then the 4 Gold dims — order
matters because Gold depends on Silver's OneLake shortcut), then deploys them to the
target tier.

- [ ] **Step 1: Write the script**

```python
"""Deploy the DP backend notebooks in scope to a target tier (dev or prod)."""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from lib import deploy, stage_items

REPO_ROOT = Path(__file__).parent.parent

STAGING_NOTEBOOKS = ["Build_Silver_InTrans.Notebook"]
PRESENTATION_NOTEBOOKS = [
    "Build_Gold_Parts.Notebook",
    "Build_Gold_DealerGroupCode.Notebook",
    "Build_Gold_Franchise.Notebook",
    "Build_Gold_BranchLocation.Notebook",
]

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

WORKSPACE_FOLDERS = {
    "staging": REPO_ROOT / "workspaces" / "DP - Staging - Dev" / "Data Notebooks",
    "presentation": REPO_ROOT / "workspaces" / "DP - Presentation - Dev" / "Dimensions",
}


def main(environment: str) -> None:
    ids = WORKSPACE_IDS[environment]

    staging_stage = stage_items(WORKSPACE_FOLDERS["staging"], STAGING_NOTEBOOKS)
    deploy(
        workspace_id=ids["staging"],
        repository_directory=staging_stage,
        item_type_in_scope=["Notebook"],
        environment=environment,
    )
    print(f"Deployed Silver notebook to {environment} staging workspace.")

    presentation_stage = stage_items(
        WORKSPACE_FOLDERS["presentation"], PRESENTATION_NOTEBOOKS
    )
    deploy(
        workspace_id=ids["presentation"],
        repository_directory=presentation_stage,
        item_type_in_scope=["Notebook"],
        environment=environment,
    )
    print(f"Deployed {len(PRESENTATION_NOTEBOOKS)} Gold notebooks to "
          f"{environment} presentation workspace.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--environment", choices=["dev", "prod"], required=True)
    args = parser.parse_args()
    main(args.environment)
```

- [ ] **Step 2: Commit**

```bash
git add deploy/deploy_backend.py
git commit -m "Add deploy_backend.py - stages and deploys DP backend notebooks

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 8: Write `run_and_verify_notebooks.py`

**Files:**
- Create: `fabric-workspace-docs/deploy/run_and_verify_notebooks.py`

Triggers each notebook via the Fabric Jobs API (confirmed endpoint, Task-plan header
above), polls for completion, then runs the same independent DuckDB verification
pattern already established in `.claude/queries/adhoc/dp-bronze-verify/`.

- [ ] **Step 1: Write the script**

```python
"""Run the DP backend notebooks in dependency order via the Fabric Jobs API,
polling each to completion, then independently verify the resulting tables."""
import argparse
import sys
import time
from pathlib import Path

import duckdb
import requests

sys.path.insert(0, str(Path(__file__).parent))
from lib import get_credential

FABRIC_API = "https://api.fabric.microsoft.com/v1"
FABRIC_SCOPE = "https://api.fabric.microsoft.com/.default"

# (workspace_key, notebook_item_id, lakehouse_table_name) - run in this exact order
# because Gold depends on Silver's OneLake shortcut. Notebook item IDs are filled in
# during Task 15 (they don't exist until Task 7's deploy has run once against Prod
# tier and created them there).
RUN_ORDER = [
    ("staging", "<SILVER_INTRANS_NOTEBOOK_ID>", "Silver_InTrans"),
    ("presentation", "<BUILD_GOLD_PARTS_NOTEBOOK_ID>", "dim_Parts"),
    ("presentation", "<BUILD_GOLD_DEALERGROUPCODE_NOTEBOOK_ID>", "dim_DealerGroupCode"),
    ("presentation", "<BUILD_GOLD_FRANCHISE_NOTEBOOK_ID>", "dim_Franchise"),
    ("presentation", "<BUILD_GOLD_BRANCHLOCATION_NOTEBOOK_ID>", "dim_BranchLocation"),
]

WORKSPACE_IDS = {
    "prod": {
        "staging": "189e5c0a-548a-4feb-93d6-dda9ebbe96c1",
        "presentation": "7836042d-adb1-4846-b70d-bd42980054c5",
    },
}

LAKEHOUSE_IDS = {
    "prod": {
        "staging": "6713bd45-a4ad-47e6-8bff-1bb0415e9784",
        "presentation": "29d9df80-a383-4d40-9807-1e2e6cbff88f",
    },
}


def get_token() -> str:
    return get_credential().get_token(FABRIC_SCOPE).token


def run_notebook(workspace_id: str, notebook_id: str, token: str) -> None:
    resp = requests.post(
        f"{FABRIC_API}/workspaces/{workspace_id}/notebooks/{notebook_id}"
        f"/jobs/execute/instances?beta=false",
        headers={"Authorization": f"Bearer {token}"},
        timeout=30,
    )
    if resp.status_code != 202:
        raise RuntimeError(f"Failed to start notebook {notebook_id}: {resp.text}")
    poll_url = resp.headers["Location"]

    while True:
        time.sleep(30)
        poll_resp = requests.get(
            poll_url, headers={"Authorization": f"Bearer {token}"}, timeout=30
        )
        poll_resp.raise_for_status()
        status = poll_resp.json()["status"]
        if status == "Completed":
            return
        if status in ("Failed", "Cancelled"):
            raise RuntimeError(
                f"Notebook {notebook_id} run ended with status {status}: "
                f"{poll_resp.text}"
            )
        # else: NotStarted / InProgress - keep polling


def verify_table(lakehouse_id: str, workspace_id: str, table_name: str) -> None:
    base = (
        f"abfss://{workspace_id}@onelake.dfs.fabric.microsoft.com/{lakehouse_id}"
    )
    con = duckdb.connect()
    con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
    con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
    row_count = con.execute(
        f"SELECT COUNT(*) FROM delta_scan('{base}/Tables/{table_name}')"
    ).fetchone()[0]
    if row_count == 0:
        raise RuntimeError(
            f"Verification failed: {table_name} has 0 rows after refresh."
        )
    print(f"Verified {table_name}: {row_count:,} rows.")


def main(environment: str) -> None:
    token = get_token()
    ws_ids = WORKSPACE_IDS[environment]
    lh_ids = LAKEHOUSE_IDS[environment]

    for workspace_key, notebook_id, table_name in RUN_ORDER:
        workspace_id = ws_ids[workspace_key]
        print(f"Running notebook {notebook_id} in {workspace_key} ({environment})...")
        run_notebook(workspace_id, notebook_id, token)
        print(f"Notebook completed. Verifying {table_name}...")
        verify_table(lh_ids[workspace_key], workspace_id, table_name)

    print("All backend notebooks ran and verified successfully.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--environment", choices=["prod"], required=True)
    args = parser.parse_args()
    main(args.environment)
```

- [ ] **Step 2: Fill in the real notebook item IDs**

The `<..._NOTEBOOK_ID>` placeholders can't be resolved until Task 7's `deploy_backend.py`
has actually run once against Prod tier (Task 15), since that's when those notebook
items are first created there. Come back to this step during Task 15 — get each
item's ID via:
```bash
fab get "DP - Staging - Prod.Workspace/Build_Silver_InTrans.Notebook" -q "id"
fab get "DP - Presentation - Prod.Workspace/Build_Gold_Parts.Notebook" -q "id"
# ... etc for the other 3 Gold notebooks
```
and replace the placeholders in `RUN_ORDER` with the real GUIDs before running this
script for the first time.

- [ ] **Step 3: Commit**

```bash
git add deploy/run_and_verify_notebooks.py
git commit -m "Add run_and_verify_notebooks.py - Fabric Jobs API run + DuckDB verify

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 9: Write `deploy_reports.py`

**Files:**
- Create: `fabric-workspace-docs/deploy/deploy_reports.py`

Stages each report individually (never the whole `RP - Dev` folder as one unit, since
the 2 production targets differ per report) and deploys `SemanticModel` before
`Report` — required order, not a style choice (Section: "Real API facts" above).

- [ ] **Step 1: Write the script**

```python
"""Deploy the 3 Batch 0 reports from RP - Dev to Sandbox or their real
production workspace, per report."""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from lib import deploy, stage_items

REPO_ROOT = Path(__file__).parent.parent
RP_DEV_DIR = REPO_ROOT / "workspaces" / "RP - Dev"

# report base name -> which real production workspace it belongs in
REPORTS = {
    "Bin Location Report": "reports_parts",
    "Physical Inventory": "reports_parts",
    "60+ Days Past Due": "reports_financial",
}

WORKSPACE_IDS = {
    "dev": {"sandbox": "ba9d8de4-ef13-44e6-9156-e23a2511f3ad"},
    "prod": {
        "reports_parts": "4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7",
        "reports_financial": "67fefa98-9e80-4a79-afdd-c8988b6e64fc",
    },
}


def deploy_one_report(report_name: str, workspace_id: str, environment: str) -> None:
    stage_dir = stage_items(
        RP_DEV_DIR,
        [f"{report_name}.SemanticModel", f"{report_name}.Report"],
    )
    deploy(
        workspace_id=workspace_id,
        repository_directory=stage_dir,
        item_type_in_scope=["SemanticModel", "Report"],  # order required
        environment=environment,
    )
    print(f"Deployed '{report_name}' to workspace {workspace_id} ({environment}).")


def main(environment: str) -> None:
    if environment == "dev":
        sandbox_id = WORKSPACE_IDS["dev"]["sandbox"]
        for report_name in REPORTS:
            deploy_one_report(report_name, sandbox_id, "dev")
    else:
        for report_name, target_key in REPORTS.items():
            workspace_id = WORKSPACE_IDS["prod"][target_key]
            deploy_one_report(report_name, workspace_id, "prod")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--environment", choices=["dev", "prod"], required=True)
    args = parser.parse_args()
    main(args.environment)
```

- [ ] **Step 2: Commit**

```bash
git add deploy/deploy_reports.py
git commit -m "Add deploy_reports.py - deploys Batch 0 reports per target workspace

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 10: Write the GitHub Actions workflow

**Files:**
- Create: `fabric-workspace-docs/.github/workflows/deploy.yml`

- [ ] **Step 1: Write the workflow**

**Real correction made during execution (2026-09-17):** the version below uses
`workflow_dispatch` for the production job, not an automatic trigger on push to
`main` as originally planned — see Task 3's note for why (Required Reviewers isn't
available on this repo's GitHub plan). This is the actual, correct version to write.

```yaml
name: Deploy DP backend and Batch 0 reports

on:
  push:
    branches: [dev]
  workflow_dispatch: {}

jobs:
  deploy-dev:
    if: github.event_name == 'push' && github.ref == 'refs/heads/dev'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - run: pip install -r deploy/requirements.txt
      - name: Deploy backend notebooks to Dev tier
        env:
          FABRIC_CICD_TENANT_ID: ${{ secrets.FABRIC_CICD_TENANT_ID }}
          FABRIC_CICD_CLIENT_ID: ${{ secrets.FABRIC_CICD_CLIENT_ID }}
          FABRIC_CICD_CLIENT_SECRET: ${{ secrets.FABRIC_CICD_CLIENT_SECRET }}
        run: python deploy/deploy_backend.py --environment dev
      - name: Deploy reports to RP - Sandbox
        env:
          FABRIC_CICD_TENANT_ID: ${{ secrets.FABRIC_CICD_TENANT_ID }}
          FABRIC_CICD_CLIENT_ID: ${{ secrets.FABRIC_CICD_CLIENT_ID }}
          FABRIC_CICD_CLIENT_SECRET: ${{ secrets.FABRIC_CICD_CLIENT_SECRET }}
        run: python deploy/deploy_reports.py --environment dev

  # Manual trigger only, not auto-deployed on push to main - GitHub's Required
  # Reviewers protection rule isn't available on this repo's plan for a private
  # repo, so a deliberate "Run workflow" click (only possible when main is
  # selected as the branch to run from) is the approval gate instead. The
  # github.ref check guards against an accidental dispatch from any other branch.
  deploy-prod:
    if: github.event_name == 'workflow_dispatch' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - run: pip install -r deploy/requirements.txt
      - name: Deploy backend notebooks to Prod tier
        env:
          FABRIC_CICD_TENANT_ID: ${{ secrets.FABRIC_CICD_TENANT_ID }}
          FABRIC_CICD_CLIENT_ID: ${{ secrets.FABRIC_CICD_CLIENT_ID }}
          FABRIC_CICD_CLIENT_SECRET: ${{ secrets.FABRIC_CICD_CLIENT_SECRET }}
        run: python deploy/deploy_backend.py --environment prod
      - name: Run and verify Prod-tier notebooks
        env:
          FABRIC_CICD_TENANT_ID: ${{ secrets.FABRIC_CICD_TENANT_ID }}
          FABRIC_CICD_CLIENT_ID: ${{ secrets.FABRIC_CICD_CLIENT_ID }}
          FABRIC_CICD_CLIENT_SECRET: ${{ secrets.FABRIC_CICD_CLIENT_SECRET }}
        run: python deploy/run_and_verify_notebooks.py --environment prod
      - name: Deploy reports to production
        env:
          FABRIC_CICD_TENANT_ID: ${{ secrets.FABRIC_CICD_TENANT_ID }}
          FABRIC_CICD_CLIENT_ID: ${{ secrets.FABRIC_CICD_CLIENT_ID }}
          FABRIC_CICD_CLIENT_SECRET: ${{ secrets.FABRIC_CICD_CLIENT_SECRET }}
        run: python deploy/deploy_reports.py --environment prod
```

Note: the recurring refresh Data Pipeline (Task 12) is deliberately **not** wired
into this workflow — it's a separately-scheduled Fabric-native item, promoted through
`fabric-cicd` the same way but triggered by its own schedule, not by a git push. This
workflow only handles one-time code/notebook-run promotion; Task 12 is what keeps the
data fresh afterward.

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/deploy.yml
git commit -m "Add GitHub Actions workflow for dev/prod deployment

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 11: Local dry-run before trusting CI

**Files:** none — this is a manual verification step, run locally by Brian before
the workflow is trusted to run unattended.

- [ ] **Step 1: Set the 3 env vars locally**

```bash
export FABRIC_CICD_TENANT_ID="<tenant id from Task 2>"
export FABRIC_CICD_CLIENT_ID="<client id from Task 2>"
export FABRIC_CICD_CLIENT_SECRET="<client secret from Task 2>"
```

- [ ] **Step 2: Run the Dev-tier deploy scripts by hand**

```bash
cd "fabric-workspace-docs"
pip install -r deploy/requirements.txt
python deploy/deploy_backend.py --environment dev
python deploy/deploy_reports.py --environment dev
```
Expected: both scripts print their "Deployed ... to dev" success messages, no
exceptions. Then open `RP - Sandbox` in the Fabric portal and confirm all 3 reports
are present and openable.

- [ ] **Step 3: Push to `dev` and confirm the workflow does the same thing**

```bash
git push origin dev
```
Watch the Actions tab on GitHub → `deploy-dev` job should run and succeed with the
same result as Step 2. This confirms the CI environment (secrets, permissions) works
identically to the local run before Task 15 touches anything in production.

---

### Task 12: Create the recurring refresh Data Pipeline (Brian, Fabric portal)

**Files:** none in `data-projects` — the pipeline itself becomes a git-tracked item
in `fabric-workspace-docs` automatically once created and committed via Fabric's own
Git integration, same as every notebook/report in this project.

- [ ] **Step 1: Create the pipeline in Dev tier**

`DP - Presentation - Dev` workspace → New → Data pipeline → name it
`Pipeline_DP_Master_Orchestrator`.

- [ ] **Step 2: Add activities in dependency order**

Add a "Notebook" activity for `Build_Silver_InTrans.Notebook` (in
`DP - Staging - Dev`), then 4 more "Notebook" activities for the Gold notebooks
(`Build_Gold_Parts`, `Build_Gold_DealerGroupCode`, `Build_Gold_Franchise`,
`Build_Gold_BranchLocation`), each chained via "On Success" from the Silver
activity (all 4 Gold notebooks can run in parallel — they don't depend on each
other, only on Silver).

- [ ] **Step 3: Add a daily schedule trigger**

Pipeline → Add trigger → New → Schedule → Daily, pick an early-morning time (e.g.
4:00 AM CST, matching the old `LH_Master_Data` pipeline's cadence for consistency).

- [ ] **Step 4: Save and commit via Fabric Git integration**

`DP - Presentation - Dev` workspace → Source control → Commit. Confirm in
`fabric-workspace-docs` (after `git pull origin dev`) that a new
`Pipeline_DP_Master_Orchestrator.DataPipeline` folder appears.

---

### Task 13: Watch the Dev-tier schedule

**Files:** none — this is a real-world observation period, not a code task.

- [ ] **Step 1: Let it run for a handful of days**

No fixed count (per the design doc — Brian's own judgment, not a rigid N). Check the
pipeline's run history in the Fabric portal each morning. A run counts as successful
only if every activity shows Succeeded and the resulting Dev-tier tables have
sensible row counts (spot-check via the same DuckDB pattern used everywhere else in
this project).

- [ ] **Step 2: Confirm you're comfortable trusting it**

This step has no command to run — it's the actual decision gate. Once you judge the
schedule reliable, move to Task 14.

---

### Task 14: Rollback check — confirm a failed notebook run stops the workflow

**Files:**
- Modify (temporarily): `fabric-workspace-docs/deploy/run_and_verify_notebooks.py`

Per the design spec's testing plan, this needs to be confirmed deliberately, not
assumed from "GitHub Actions steps fail sequentially by default" — worth actually
watching happen once before it matters for real.

- [ ] **Step 1: Introduce a deliberate failure**

Create a throwaway branch off `main` (not `main` itself). On it, make two temporary
changes: (a) edit `RUN_ORDER` in `run_and_verify_notebooks.py` to point the first
entry at a notebook ID that doesn't exist (e.g. change the last character of the
Silver notebook's GUID), and (b) since `deploy-prod` is gated to
`github.ref == 'refs/heads/main'` (Task 10), temporarily loosen that check in
`.github/workflows/deploy.yml` to also match this throwaway branch, so a manual
dispatch against it will actually run. Push the branch.

- [ ] **Step 2: Trigger and observe**

GitHub Actions tab → "Deploy DP backend and Batch 0 reports" → **Run workflow** →
select the throwaway branch from the dropdown → **Run workflow**. Confirm:
`deploy_backend.py` succeeds (it doesn't call the broken notebook ID),
`run_and_verify_notebooks.py` fails clearly (the API call 404s or the run fails), and
the `deploy_reports.py` step never runs — GitHub Actions should show it skipped
because an earlier step in the same job failed.

- [ ] **Step 3: Confirm production was untouched**

Check `RP - Parts Reports` / `RP - Financial Reports` in the Fabric portal — nothing
should have changed there, since the report-deploy step never ran.

- [ ] **Step 4: Revert the deliberate breakage**

Discard the throwaway branch — this removes both the deliberate failure and the
temporary ref-check loosening together, so `main` and its real `deploy-prod` gate are
never actually touched. `run_and_verify_notebooks.py` on `main` never had the bad GUID
in the first place (Task 8's placeholders are still unfilled at this point, same as
intended — this task validates failure behavior using a manufactured failure, not the
real not-yet-filled-in placeholder, so it doesn't consume Task 15's actual first
attempt).

---

### Task 15: First real Prod promotion — Bin Location Report

**Files:** none new — this exercises everything built in Tasks 1–14 end-to-end for
the first time against real production.

- [ ] **Step 1: Merge to `main`**

Open a PR from `dev` to `main` in `fabric-workspace-docs`, review the diff, merge it.

- [ ] **Step 2: Manually trigger the production deployment**

GitHub Actions tab → "Deploy DP backend and Batch 0 reports" → **Run workflow** →
select **main** from the branch dropdown → **Run workflow**. This manual dispatch,
gated to `main` (Task 10), is the approval step — there's no separate review/approve
click since Required Reviewers isn't available on this repo's plan (Task 3).

- [ ] **Step 3: Watch it run, get the real notebook IDs, re-run if needed**

The first run will fail at `run_and_verify_notebooks.py` because Task 8 Step 2's
notebook ID placeholders haven't been filled in yet (they can't be, until this
deploy step has created those items in Prod tier for the first time). After
`deploy_backend.py` succeeds:
```bash
fab get "DP - Staging - Prod.Workspace/Build_Silver_InTrans.Notebook" -q "id"
fab get "DP - Presentation - Prod.Workspace/Build_Gold_Parts.Notebook" -q "id"
fab get "DP - Presentation - Prod.Workspace/Build_Gold_DealerGroupCode.Notebook" -q "id"
fab get "DP - Presentation - Prod.Workspace/Build_Gold_Franchise.Notebook" -q "id"
fab get "DP - Presentation - Prod.Workspace/Build_Gold_BranchLocation.Notebook" -q "id"
```
Fill the 5 real GUIDs into `RUN_ORDER` in `deploy/run_and_verify_notebooks.py`, commit
and merge to `main`, then manually trigger the workflow again (Run workflow → `main`).

- [ ] **Step 4: Promote the recurring pipeline to Prod tier**

Repeat Task 12's build, this time in `DP - Presentation - Prod` (or extend
`deploy_backend.py`/the workflow to include the `Pipeline_DP_Master_Orchestrator`
item once Task 13 has proven the Dev-tier copy — whichever is less friction at this
point is fine, this plan doesn't mandate one over the other). Confirm it runs
successfully at least once in Prod tier before Step 5.

- [ ] **Step 5: Confirm the report landed correctly**

Open `Bin Location Report` in `RP - Parts Reports` directly (not via Desktop), refresh
if needed, and spot-check a few real rows against what you'd expect — same discipline
used throughout Batch 0.

---

### Task 16: Extend to Physical Inventory

**Files:** none new.

- [ ] **Step 1: Confirm `Physical Inventory` deployed automatically**

Since `deploy_reports.py`'s `REPORTS` dict already includes it, Task 15's Prod
deploy should have already pushed it to `RP - Parts Reports` too — this task is
verification, not new deployment work. Open it directly in `RP - Parts Reports` and
spot-check.

---

### Task 17: Extend to 60+ Days Past Due

**Files:** none new.

- [ ] **Step 1: Confirm it deployed to the correct (different) workspace**

Same as Task 16 — `deploy_reports.py` should have already routed this one to
`RP - Financial Reports` specifically (not `RP - Parts Reports`), proving the
per-report target-workspace routing works, not just the happy path of "everything
goes to the same place." Open it directly in `RP - Financial Reports` and spot-check.

---

## What this plan deliberately does not cover

Per the design spec's own scope section: `RP - Service Reports` (needs its own
cleanup first), extending this pipeline to any report beyond these 3, per-report
refresh cadence (everything shares one daily schedule for now), and failure alerting
for the recurring schedule (flagged as a real follow-up, not designed here).
