# Parts Lookup Automated Refresh Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the validated static-file prototype's manual extract/partition/upload steps into an unattended pipeline, scheduled hourly (revised from an original 15-minute target once real upload timing was measured — see design spec Section 6), using a dedicated service principal instead of Brian's personal login.

**Architecture:** Extend `extract.py`/`partition.py` (from the prototype) to authenticate via an Entra ID service principal instead of interactive CLI login; add a new `upload.py` that pushes files to SharePoint via Microsoft Graph API; chain all three behind a logging orchestrator; run it from Windows Task Scheduler.

**Tech Stack:** Python (duckdb, pandas, msal, requests, python-dotenv), Entra ID app registration, Microsoft Graph API, Windows Task Scheduler.

Full context: `docs/superpowers/specs/2026-08-14-parts-lookup-refresh-pipeline-design.md`

---

### Task 1: Fix the `OnOrder` dataflow gap

This task is manual (Fabric portal), not code.

- [ ] **Step 1: Update the dataflow's Power Query to match the local `.pq` file**

Open `df_InMaster_PartsLookup_Raw` in the Fabric portal (workspace `LH_Master_Data`) in the Power Query editor. Compare its current M code against `.claude/queries/raw-tables/InMaster_PartsLookup_Raw.pq` in this repo — update the dataflow's query to add the `OnOrder` column (sourced from `OS_ORDER_QTY`) exactly as the local file already defines it.

- [ ] **Step 2: Publish and refresh**

Publish the dataflow, then trigger a manual refresh so the live Lakehouse table picks up the schema change.

- [ ] **Step 3: Verify**

Run this once from a terminal with `fab auth login`/`az login` active (reuses the prototype's proven connection pattern, one-time manual check, not part of the automated pipeline):

```python
import duckdb

WS_ID = "b48cdb35-7ce3-46de-96df-d70db77649cb"
LH_ID = "3e74497b-8c51-4a1a-91a1-888c59118f48"
BASE = f"abfss://{WS_ID}@onelake.dfs.fabric.microsoft.com/{LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
print(con.execute(f"DESCRIBE SELECT * FROM delta_scan('{BASE}/InMaster_PartsLookup_Raw')").df())
```

Expected: `OnOrder` now appears in the printed column list. If it doesn't, the dataflow refresh may still be in progress — wait and re-check before proceeding to later tasks, since Task 4 depends on this column actually being live.

---

### Task 2: Register the service principal and resolve SharePoint IDs

This task is manual (Entra admin center / Fabric portal / Graph Explorer), not code.

- [ ] **Step 1: Register a new Entra ID app**

Entra admin center → App registrations → New registration. Single-tenant, no redirect URI needed (this will use client-credentials/app-only auth, not interactive sign-in). Note the **Application (client) ID** and **Directory (tenant) ID** from the app's Overview page.

- [ ] **Step 2: Create a client secret**

App registration → Certificates & secrets → New client secret. Note the **secret value** immediately (only shown once).

- [ ] **Step 3: Grant Fabric workspace read access**

In the Fabric portal, `LH_Master_Data` workspace → Manage access → add the new app registration (search by its name/client ID) with **Viewer** role — sufficient for the `delta_scan` reads `extract.py` already does.

- [ ] **Step 4: Grant scoped SharePoint write access**

App registration → API permissions → Add a permission → Microsoft Graph → Application permissions → `Sites.Selected`. Grant admin consent. `Sites.Selected` alone doesn't grant access to any specific site yet — it needs to be explicitly permitted on the test library's site via a Graph API call (this can be done via Graph Explorer, signed in as an admin):

```
POST https://graph.microsoft.com/v1.0/sites/{site-id}/permissions
{
  "roles": ["write"],
  "grantedToIdentities": [{
    "application": {
      "id": "<the app registration's client ID>",
      "displayName": "<app registration's name>"
    }
  }]
}
```

(`{site-id}` is resolved in Step 5 below — do Step 5 first if you need the site ID for this call.)

- [ ] **Step 5: Resolve the SharePoint site ID and drive ID**

Via Graph Explorer (or a quick authenticated `requests` call), resolve:

```
GET https://graph.microsoft.com/v1.0/sites/spitractor.sharepoint.com:/sites/SouthPlainsImplement-ReportSite:/sites/Test%20%20Part%20Availability
```

(Adjust the path if the site/library structure differs from what's in the design spec — the goal is the `id` field in the response, formatted like `spitractor.sharepoint.com,<guid>,<guid>`.) Then:

```
GET https://graph.microsoft.com/v1.0/sites/{site-id}/drives
```

Note the `id` of the drive corresponding to the "Test - Part Availability" library — this is the drive ID.

- [ ] **Step 6: Record all five values for Task 3**

`TENANT_ID`, `CLIENT_ID`, `CLIENT_SECRET`, `SITE_ID`, `DRIVE_ID` — needed by the config file in Task 3. Do not commit these anywhere yet.

---

### Task 3: Local credential config

**Files:**
- Create: `.claude/queries/adhoc/parts-lookup-static-prototype/.env.example`
- Create: `.claude/queries/adhoc/parts-lookup-static-prototype/config.py`
- Modify: `.claude/queries/adhoc/parts-lookup-static-prototype/.gitignore`

- [ ] **Step 1: Write the example env file (committed, no real values)**

```
TENANT_ID=
CLIENT_ID=
CLIENT_SECRET=
SITE_ID=
DRIVE_ID=
LIBRARY_BASE=https://spitractor.sharepoint.com/sites/SouthPlainsImplement-ReportSite/Test%20%20Part%20Availability
```

- [ ] **Step 2: Write the config loader**

```python
"""
Loads the service principal credentials and SharePoint identifiers needed
by the unattended refresh pipeline (extract.py, upload.py, run_refresh.py).

Values come from a local .env file (gitignored, never committed) - copy
.env.example to .env and fill in the real values from Task 2 before running
anything in this pipeline unattended.
"""

import os

from dotenv import load_dotenv

load_dotenv()

TENANT_ID = os.environ["TENANT_ID"]
CLIENT_ID = os.environ["CLIENT_ID"]
CLIENT_SECRET = os.environ["CLIENT_SECRET"]
SITE_ID = os.environ["SITE_ID"]
DRIVE_ID = os.environ["DRIVE_ID"]
LIBRARY_BASE = os.environ["LIBRARY_BASE"]
```

- [ ] **Step 3: Add `.env` to `.gitignore`**

Add this line to the existing `.gitignore` (which already has `*.parquet` and `output/` from the prototype):

```
.env
```

- [ ] **Step 4: Create the real `.env` from Task 2's values**

`cp .env.example .env`, then fill in the five real values recorded in Task 2, Step 6.

- [ ] **Step 5: Verify it loads**

Run: `pip install python-dotenv && python -c "import config; print(config.CLIENT_ID)"`
Expected: prints the real client ID (confirms `.env` is being read correctly), not an empty string or a `KeyError`.

- [ ] **Step 6: Commit**

```bash
git add .claude/queries/adhoc/parts-lookup-static-prototype/.env.example .claude/queries/adhoc/parts-lookup-static-prototype/config.py .claude/queries/adhoc/parts-lookup-static-prototype/.gitignore
git commit -m "Add service principal config loader for unattended refresh pipeline"
```

(`.env` itself is never committed — confirm `git status` shows it untracked before committing.)

---

### Task 4: Update `extract.py` for service-principal auth and `OnOrder`

**Files:**
- Modify: `.claude/queries/adhoc/parts-lookup-static-prototype/extract.py`

- [ ] **Step 1: Replace the CLI credential chain with the service principal**

Change the secret creation and add `OnOrder` to the column list:

```python
"""
PARTS LOOKUP STATIC-FILE PROTOTYPE - EXTRACT
============================================================================
Pulls InMaster_PartsLookup_Raw from the LH_Master_Data lakehouse via DuckDB
over OneLake (delta_scan). Authenticates via a dedicated service principal
(see config.py / .env) rather than an interactive az/fab CLI login, so this
can run unattended on a schedule.

Requires .env to be populated (see .env.example and Task 3 of
docs/superpowers/plans/2026-08-14-parts-lookup-refresh-pipeline.md).
============================================================================
"""

import time

import duckdb

import config

WS_ID = "b48cdb35-7ce3-46de-96df-d70db77649cb"  # LH_Master_Data workspace
LH_ID = "3e74497b-8c51-4a1a-91a1-888c59118f48"  # LH_Master_Data lakehouse
BASE = f"abfss://{WS_ID}@onelake.dfs.fabric.microsoft.com/{LH_ID}/Tables"
OUT_PATH = "partslookup_extract.parquet"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute(
    f"""
    CREATE SECRET (
        TYPE azure,
        PROVIDER service_principal,
        TENANT_ID '{config.TENANT_ID}',
        CLIENT_ID '{config.CLIENT_ID}',
        CLIENT_SECRET '{config.CLIENT_SECRET}'
    );
    """
)

start = time.time()
df = con.execute(
    f"""
    SELECT
        PartNumber, Branch, Franchise, Description, VendorCode,
        Bin, BinQty, OnOrder, SellPrice1, SuperTo, SuperFrom, Comments
    FROM delta_scan('{BASE}/InMaster_PartsLookup_Raw')
    """
).df()
elapsed = time.time() - start

df.to_parquet(OUT_PATH, index=False)

print(f"Extracted {len(df):,} rows in {elapsed:.1f} sec")
print(f"Saved to {OUT_PATH}")
```

Note: if DuckDB's azure extension reports the `service_principal` provider needs different/additional fields than shown here (extension APIs occasionally add required parameters between versions), check the error message and the installed extension's own documentation (`duckdb -c "SELECT extension_name, extension_version FROM duckdb_extensions() WHERE extension_name='azure';"`) rather than guessing — this exact secret syntax hasn't been run against this specific DuckDB version yet as of writing this plan.

- [ ] **Step 2: Run it (requires Task 1 and Task 2/3 complete)**

Run: `python extract.py`
Expected: prints `Extracted N,NNN,NNN rows in X.X sec` and `Saved to partslookup_extract.parquet`. Row count should be close to the prototype's 1,060,738 (some drift expected — real data changes over time). Open the parquet with pandas and confirm `OnOrder` is now a real column (not missing, and not all-null unless that's genuinely correct for current data).

- [ ] **Step 3: Commit**

```bash
git add .claude/queries/adhoc/parts-lookup-static-prototype/extract.py
git commit -m "Switch extract.py to service-principal auth, add OnOrder column"
```

---

### Task 5: Write `upload.py`

**Files:**
- Create: `.claude/queries/adhoc/parts-lookup-static-prototype/upload.py`

- [ ] **Step 1: Write the upload script**

Handles both small files (single PUT) and large files (chunked upload session) — several of the prototype's partition files (e.g. `RE.json` at ~18.2 MB) exceed Microsoft Graph's 4 MB simple-upload limit.

```python
"""
PARTS LOOKUP REFRESH PIPELINE - UPLOAD
============================================================================
Pushes the partitioned JSON files (from partition.py's output/2char/) to
the SharePoint test library via Microsoft Graph API, using the service
principal's client-credentials token. Overwrites existing files by name -
no separate delete/cleanup step needed since partition filenames are
stable across runs.

Handles files over Graph's 4 MB simple-upload limit via a chunked upload
session (some partition files, e.g. the RE prefix, are ~18 MB).
============================================================================
"""

import glob
import os
import time

import msal
import requests

import config

GRAPH_BASE = "https://graph.microsoft.com/v1.0"
SIMPLE_UPLOAD_LIMIT = 4 * 1024 * 1024  # Graph API's simple-upload ceiling
CHUNK_SIZE = 4 * 1024 * 1024  # must be a multiple of 320 KiB per Graph docs
SOURCE_DIR = "output/2char"


def get_access_token() -> str:
    app = msal.ConfidentialClientApplication(
        client_id=config.CLIENT_ID,
        client_credential=config.CLIENT_SECRET,
        authority=f"https://login.microsoftonline.com/{config.TENANT_ID}",
    )
    result = app.acquire_token_for_client(scopes=["https://graph.microsoft.com/.default"])
    if "access_token" not in result:
        raise RuntimeError(f"Failed to acquire Graph token: {result.get('error_description')}")
    return result["access_token"]


def upload_file(local_path: str, file_name: str, access_token: str) -> None:
    file_size = os.path.getsize(local_path)
    headers = {"Authorization": f"Bearer {access_token}"}

    if file_size <= SIMPLE_UPLOAD_LIMIT:
        url = f"{GRAPH_BASE}/sites/{config.SITE_ID}/drives/{config.DRIVE_ID}/root:/{file_name}:/content"
        with open(local_path, "rb") as f:
            resp = requests.put(url, headers=headers, data=f.read())
        resp.raise_for_status()
        return

    session_url = (
        f"{GRAPH_BASE}/sites/{config.SITE_ID}/drives/{config.DRIVE_ID}"
        f"/root:/{file_name}:/createUploadSession"
    )
    session_resp = requests.post(
        session_url,
        headers=headers,
        json={"item": {"@microsoft.graph.conflictBehavior": "replace"}},
    )
    session_resp.raise_for_status()
    upload_url = session_resp.json()["uploadUrl"]

    with open(local_path, "rb") as f:
        offset = 0
        while offset < file_size:
            chunk = f.read(CHUNK_SIZE)
            chunk_len = len(chunk)
            chunk_headers = {
                "Content-Length": str(chunk_len),
                "Content-Range": f"bytes {offset}-{offset + chunk_len - 1}/{file_size}",
            }
            # No Authorization header here - upload session URLs are pre-authenticated.
            chunk_resp = requests.put(upload_url, headers=chunk_headers, data=chunk)
            chunk_resp.raise_for_status()
            offset += chunk_len


def main() -> None:
    access_token = get_access_token()
    files = sorted(glob.glob(os.path.join(SOURCE_DIR, "*.json")))
    if not files:
        raise RuntimeError(f"No files found in {SOURCE_DIR} - run partition.py first")

    start = time.time()
    for i, path in enumerate(files, 1):
        file_name = os.path.basename(path)
        upload_file(path, file_name, access_token)
        if i % 100 == 0:
            print(f"  uploaded {i}/{len(files)}")
    elapsed = time.time() - start

    print(f"Uploaded {len(files)} files in {elapsed:.1f} sec")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run it (requires Task 2's `Sites.Selected` grant and Task 4's extract/partition already run)**

Run: `pip install msal requests && python upload.py`
Expected: prints periodic progress (`uploaded 100/1248`, etc.) and a final `Uploaded 1248 files in X.X sec`. Spot-check in the SharePoint library that a few files' "Modified" timestamps updated to just now.

- [ ] **Step 3: Verify idempotency (overwrite behavior)**

Run: `python upload.py` again immediately.
Expected: succeeds again with the same file count, and the library's file count stays at 1,248 afterward (not 2,496) — confirms files are being overwritten by name, not duplicated.

- [ ] **Step 4: Commit**

```bash
git add .claude/queries/adhoc/parts-lookup-static-prototype/upload.py
git commit -m "Add upload.py: automated Graph API upload replacing manual drag-and-drop"
```

---

### Task 6: Orchestrator with logging

**Files:**
- Create: `.claude/queries/adhoc/parts-lookup-static-prototype/run_refresh.py`

- [x] **Step 1: Write the orchestrator**

> Implemented with more robustness than shown below, added through two code-quality review cycles: `(connect, read)` timeouts on both Graph calls and MSAL token acquisition, a 60-min per-step `subprocess.run` timeout, top-level exception handling so every failure path logs, truncated per-step log capture (final summary line only, not full progress output), and a `refresh.lock` file with staleness detection (185 min threshold) to prevent overlapping runs while self-healing after a hard kill. See `run_refresh.py` as committed (`a0af0861`, `b4b17ee0`, `739cc81f`) for the real implementation; the code block below is the original starting point from planning.

```python
"""
PARTS LOOKUP REFRESH PIPELINE - ORCHESTRATOR
============================================================================
Runs extract.py -> partition.py -> upload.py in sequence and logs one line
per run (timestamp, success/failure, timing, row count) to refresh.log in
this folder. This is the script Windows Task Scheduler invokes directly.
============================================================================
"""

import datetime
import subprocess
import sys

LOG_PATH = "refresh.log"
STEPS = ["extract.py", "partition.py", "upload.py"]


def log(message: str) -> None:
    line = f"{datetime.datetime.now().isoformat()} {message}"
    print(line)
    with open(LOG_PATH, "a", encoding="utf-8") as f:
        f.write(line + "\n")


def main() -> int:
    log("=== refresh run starting ===")
    for step in STEPS:
        result = subprocess.run(
            [sys.executable, step], capture_output=True, text=True
        )
        if result.returncode != 0:
            log(f"FAILED at {step}: {result.stderr.strip()[-500:]}")
            log("=== refresh run FAILED ===")
            return 1
        # Capture the step's own summary line(s) - already informative
        # (e.g. "Extracted N rows in X sec") without re-deriving them here.
        for line in result.stdout.strip().splitlines():
            log(f"  [{step}] {line}")
    log("=== refresh run completed successfully ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [x] **Step 2: Run it end-to-end**

Run: `python run_refresh.py`
Expected: exit code 0, `refresh.log` created/appended with a full run's worth of lines from all three steps ending in `=== refresh run completed successfully ===`.

Verified live: full run completed 1248/1248 files uploaded in ~21 min, `refresh.log` showed a clean successful cycle end to end.

- [x] **Step 3: Add the log file to `.gitignore`**

```
refresh.log
```

(Append to the existing `.gitignore` alongside `*.parquet`, `output/`, `.env`.) Also added `refresh.lock`.

- [x] **Step 4: Commit**

```bash
git add .claude/queries/adhoc/parts-lookup-static-prototype/run_refresh.py .claude/queries/adhoc/parts-lookup-static-prototype/.gitignore
git commit -m "Add run_refresh.py orchestrator with per-run logging"
```

---

### Task 7: Verify it works with zero interactive session

This task is manual verification, not code.

- [ ] **Step 1: Sign out of interactive sessions**

Run `az logout` and close/sign out of any `fab` CLI session. This simulates the scheduled-task context, where nobody is logged in.

- [ ] **Step 2: Run the orchestrator**

Run: `python run_refresh.py`
Expected: still succeeds — confirms the service-principal auth in `extract.py` (Task 4) and `upload.py` (Task 5) is genuinely not depending on your personal CLI login anymore. If it fails here but worked in Tasks 4-6, the credential chain is still falling back to something interactive somewhere — don't proceed to Task 8 until this passes cleanly.

- [ ] **Step 3: Sign back in for your own normal work**

Run `az login` / `fab auth login` again for your own subsequent use of these CLIs outside this pipeline.

---

### Task 8: Windows Task Scheduler setup

This task is manual (Windows UI), not code.

- [ ] **Step 1: Create the scheduled task**

Task Scheduler → Create Task. Trigger: repeat every hour, indefinitely (revised from the original 15-minute target — the real ~20 min upload time measured in Task 5 doesn't fit a 15-minute window with reasonable margin; hourly gives real headroom). Action: start a program — point it at your Python executable, with the argument set to the full path of `run_refresh.py`, and "Start in" set to the `.claude/queries/adhoc/parts-lookup-static-prototype/` folder (so relative paths in the scripts resolve correctly).

- [ ] **Step 2: Run it once manually from Task Scheduler**

Right-click the task → Run. Confirm `refresh.log` gets a new entry and the SharePoint library's file timestamps update.

- [ ] **Step 3: Let it run unattended and check back**

Come back after a few cycles (an hour or so) and confirm `refresh.log` shows multiple successful runs with no manual intervention.

---

## Self-Review

**Spec coverage:** Section 3 (service principal) → Task 2. Section 4 (`OnOrder` fix) → Task 1. Section 5 (pipeline scripts) → Tasks 3-6. Section 6 (scheduling) → Task 8. Section 7 (validation plan) → covered across Tasks 4 Step 2 (data shape), 5 Step 3 (idempotency), 7 (unattended auth), 8 Step 3 (sustained unattended operation). All spec sections covered.

**Placeholder scan:** No TBD/TODO. `.env.example` intentionally ships with empty values (that's its purpose — a template, filled with real secrets in Task 3 Step 4, never committed with real values).

**Type/naming consistency:** `config.py`'s five exported names (`TENANT_ID`, `CLIENT_ID`, `CLIENT_SECRET`, `SITE_ID`, `DRIVE_ID`, `LIBRARY_BASE`) are used identically by name in both `extract.py` (Task 4) and `upload.py` (Task 5) — no renaming drift. `extract.py`'s column list from the prototype is preserved with only `OnOrder` added, matching the design spec's Section 5 description exactly. `upload.py`'s `SOURCE_DIR = "output/2char"` matches `partition.py`'s existing output path from the prototype (unchanged in this plan).
