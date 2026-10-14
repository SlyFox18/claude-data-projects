# Associated Parts Export Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a weekly export that collapses `Fact_PartAssociation` down to a single small JSON file (part-to-part recommendations, franchise-agnostic, with pre-computed Confidence/Lift) and uploads it to the same SharePoint site the Parts Availability app already reads from.

**Architecture:** A new Python script, living alongside the existing parts-lookup refresh pipeline (same folder, same SharePoint credentials, same upload mechanism reused via import), reads `Fact_PartAssociation` via DuckDB/OneLake, collapses the franchise dimension, computes `ConfidencePercent`/`Lift` as plain numbers (no live DAX engine on the client), writes one gzip JSON file plus a small freshness-metadata file, and uploads both via Microsoft Graph. Scheduled weekly on the Gateway PC, independent of the existing hourly `PartLocations` refresh.

**Tech Stack:** Python (duckdb, pandas, msal, requests — same stack as the existing `parts-lookup-static-prototype` pipeline), DuckDB against OneLake (`delta_scan`), Microsoft Graph API.

**Spec:** `docs/superpowers/specs/2026-08-31-associated-parts-counter-lookup-design.md`

---

## Before You Start

- `az login` must be authenticated (confirmed working earlier this session as `bfox@spitractor.com`) for the local validation steps in this plan — production runs on the Gateway PC use the service principal in `config.py`/`.env` instead, not `az login`.
- The collapse query below was already run once, live, during planning: **44,258 rows, 5,635 distinct `PartA` values, 5.6 MB uncompressed, 718 KB gzipped.** This confirms a single file (no partitioning) is sufficient — don't second-guess this with speculative partitioning logic.
- This plan adds files to `.claude/queries/adhoc/parts-lookup-static-prototype/` — despite the folder name, this is the **real, live production** refresh pipeline for the Parts Availability app (confirmed: `WINDOWS-SERVER-2016-DEPLOYMENT.md` and `GATEWAY-PC-PIPELINE-DEPLOYMENT.md` both describe it as such). Do not treat it as a throwaway prototype.
- `config.py` in that folder loads `TENANT_ID`/`CLIENT_ID`/`CLIENT_SECRET`/`SITE_ID`/`DRIVE_ID`/`LIBRARY_BASE`/`TEAMS_WEBHOOK_URL` from a local `.env` (gitignored). If running any step that needs real upload credentials and `.env` isn't present in your environment, that step needs to run on a machine that has it (the Gateway PC, or wherever Brian has previously set it up) — don't fabricate credentials.

---

### Task 1: Write and validate the collapse/export script

**Files:**
- Create: `.claude/queries/adhoc/parts-lookup-static-prototype/associated_parts_export.py`

- [ ] **Step 1: Write the script**

```python
"""
ASSOCIATED PARTS COUNTER EXPORT
============================================================================
Collapses Fact_PartAssociation (Franchise x PartA x PartB grain, built
weekly by projects/associated parts - report/notebooks/Fact_PartAssociation_Build.ipynb)
down to a single (PartA, PartB) grain, computes ConfidencePercent/Lift as
plain numbers (there is no live DAX engine on the client), joins in
PartB's Description from dim_Parts, and writes a single gzip-compressed
JSON file plus a small freshness-metadata file.

Unlike partition.py (which splits PartLocations across 300+ prefix-bucket
files because that dataset is 1M+ rows), this export is small enough for
one file: confirmed via a real run during planning at 44,258 rows / 718 KB
gzipped for the entire dataset. No partitioning.

The franchise dimension is deliberately collapsed away here -- the counter
app has no use for a franchise breakdown (that's an internal Power BI
modeling detail), so counts are summed across franchise before computing
ratios. AnchorInvoiceCount/AssociatedInvoiceCount/TotalInvoiceCount are
repeated values across multiple rows in the source table (same trap as the
Power BI measures) -- de-duplicated via DISTINCT before summing, exactly
matching the SUMX(SUMMARIZE(...)) pattern already proven correct in the
semantic model's own measures.

See docs/superpowers/specs/2026-08-27-associated-parts-design.md and
docs/superpowers/specs/2026-08-31-associated-parts-counter-lookup-design.md
for full design rationale.

Run standalone: python associated_parts_export.py
============================================================================
"""
import gzip
import json
import os
import time

import duckdb

WS_ID = "b48cdb35-7ce3-46de-96df-d70db77649cb"
LH_ID = "3e74497b-8c51-4a1a-91a1-888c59118f48"
OUT_DIR = "output_associated_parts"
DATA_FILE = "associated_parts.json.gz"
META_FILE = "_meta_associated_parts.json"


def build_export() -> "list[dict]":
    """Runs the collapse query against live Fact_PartAssociation/dim_Parts
    and returns the result as a list of row dicts, ready for JSON export."""
    base = f"abfss://{WS_ID}@onelake.dfs.fabric.microsoft.com/{LH_ID}/Tables"
    con = duckdb.connect()
    con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
    con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

    result = con.execute(f"""
        WITH per_franchise AS (
            SELECT Franchise, PartA, PartB, CoOccurrenceCount, AnchorInvoiceCount,
                   AssociatedInvoiceCount, TotalInvoiceCount
            FROM delta_scan('{base}/Fact_PartAssociation')
        ),
        coocc_summed AS (
            SELECT PartA, PartB, SUM(CoOccurrenceCount) AS CoOccurrenceCount
            FROM per_franchise GROUP BY PartA, PartB
        ),
        anchor_totals AS (
            SELECT PartA, SUM(AnchorInvoiceCount) AS AnchorInvoiceCount
            FROM (SELECT DISTINCT Franchise, PartA, AnchorInvoiceCount FROM per_franchise)
            GROUP BY PartA
        ),
        associated_totals AS (
            SELECT PartB, SUM(AssociatedInvoiceCount) AS AssociatedInvoiceCount
            FROM (SELECT DISTINCT Franchise, PartB, AssociatedInvoiceCount FROM per_franchise)
            GROUP BY PartB
        ),
        total_invoices AS (
            SELECT SUM(TotalInvoiceCount) AS TotalInvoiceCount
            FROM (SELECT DISTINCT Franchise, TotalInvoiceCount FROM per_franchise)
        )
        SELECT
            c.PartA, c.PartB, p.Description,
            CAST(c.CoOccurrenceCount AS BIGINT) AS CoOccurrenceCount,
            ROUND(CAST(c.CoOccurrenceCount AS DOUBLE) / a.AnchorInvoiceCount * 100, 2) AS ConfidencePercent,
            ROUND((CAST(c.CoOccurrenceCount AS DOUBLE) / a.AnchorInvoiceCount)
                  / (CAST(b.AssociatedInvoiceCount AS DOUBLE) / t.TotalInvoiceCount), 2) AS Lift
        FROM coocc_summed c
        INNER JOIN anchor_totals a ON a.PartA = c.PartA
        INNER JOIN associated_totals b ON b.PartB = c.PartB
        CROSS JOIN total_invoices t
        LEFT JOIN delta_scan('{base}/dim_Parts') p ON p.PartNumber = c.PartB
        ORDER BY c.PartA, c.CoOccurrenceCount DESC
    """).df()

    result = result.astype(object).where(result.notna(), None)
    return result.to_dict(orient="records")


def write_gzip_json(rows: list, out_dir: str = OUT_DIR) -> int:
    """Writes rows as gzip-compressed JSON, matching partition.py's
    write_gzip_json() convention (compact separators, no ensure_ascii).
    Returns the resulting file size in bytes."""
    os.makedirs(out_dir, exist_ok=True)
    file_path = os.path.join(out_dir, DATA_FILE)
    with gzip.open(file_path, "wt", encoding="utf-8") as f:
        json.dump(rows, f, ensure_ascii=False, separators=(",", ":"))
    return os.path.getsize(file_path)


def write_meta_file(out_dir: str = OUT_DIR) -> None:
    """Writes _meta_associated_parts.json with the current UTC generation
    timestamp -- a separate file from the existing pipeline's _meta.json,
    since this export runs on its own weekly schedule, independent of the
    hourly PartLocations refresh that owns that file."""
    import datetime

    meta_path = os.path.join(out_dir, META_FILE)
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(
            {"generatedAt": datetime.datetime.now(datetime.timezone.utc).isoformat()},
            f,
        )


def main() -> None:
    start = time.time()
    rows = build_export()
    print(f"Query returned {len(rows):,} rows in {time.time() - start:.1f}s")

    size_bytes = write_gzip_json(rows)
    print(f"Wrote {DATA_FILE}: {size_bytes / 1024:.1f} KB")

    write_meta_file()
    print(f"Wrote {META_FILE}")


if __name__ == "__main__":
    # Guarded the same way as partition.py -- importing this module (e.g.
    # from a test) must never have the side effect of running the real
    # export against real output paths.
    main()
```

- [ ] **Step 2: Run it and verify real output**

Run: `cd ".claude/queries/adhoc/parts-lookup-static-prototype" && python3 associated_parts_export.py`

Expected: prints a row count close to 44,258 (small drift from new data landing since planning is normal — if it's wildly different, e.g. off by more than ~5%, stop and investigate before continuing), a file size close to 718 KB, and both files land in `output_associated_parts/`.

- [ ] **Step 3: Spot-check the output file directly**

Run:
```bash
python3 -c "
import gzip, json
with gzip.open('.claude/queries/adhoc/parts-lookup-static-prototype/output_associated_parts/associated_parts.json.gz', 'rt', encoding='utf-8') as f:
    rows = json.load(f)
print(f'Total rows: {len(rows):,}')
sample = [r for r in rows if r['PartA'] == 'TY22062'][:5]
for r in sample:
    print(r)
"
```
Expected: 5 rows for `TY22062` (the HY-GARD hydraulic fluid part validated earlier in the Power BI report), each with a real `PartB`, non-null `Description`, and `Lift` values in a similar range to what was already validated there (roughly 1.5x-13x, not wildly different — small drift from new data is fine).

- [ ] **Step 4: Commit**

```bash
git add ".claude/queries/adhoc/parts-lookup-static-prototype/associated_parts_export.py"
git commit -m "Add Associated Parts counter export script

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

Note: `output_associated_parts/` itself should NOT be committed (it's generated output) — check `.claude/queries/adhoc/parts-lookup-static-prototype/.gitignore` already excludes `output*/` before committing; if it doesn't, add that pattern to the existing `.gitignore` in that folder as part of this commit.

---

### Task 2: Add the upload step

**Files:**
- Modify: `.claude/queries/adhoc/parts-lookup-static-prototype/associated_parts_export.py`

This reuses `upload.py`'s existing `get_access_token()`/`upload_file()` functions rather than duplicating the retry/chunking logic — both files already live in the same folder, so a plain import works.

- [ ] **Step 1: Add the upload call to `main()`**

```python
import upload  # same folder -- reuses get_access_token()/upload_file(), no duplicated retry/chunking logic


def upload_export(out_dir: str = OUT_DIR) -> None:
    access_token = upload.get_access_token()
    for file_name in (DATA_FILE, META_FILE):
        local_path = os.path.join(out_dir, file_name)
        print(f"  uploading {file_name}...")
        upload.upload_file(local_path, file_name, access_token)
    print(f"Uploaded {DATA_FILE} and {META_FILE}")
```

Update `main()` to call it after `write_meta_file()`:

```python
def main() -> None:
    start = time.time()
    rows = build_export()
    print(f"Query returned {len(rows):,} rows in {time.time() - start:.1f}s")

    size_bytes = write_gzip_json(rows)
    print(f"Wrote {DATA_FILE}: {size_bytes / 1024:.1f} KB")

    write_meta_file()
    print(f"Wrote {META_FILE}")

    upload_export()
```

- [ ] **Step 2: Run it end-to-end for real**

This uploads two new files (`associated_parts.json.gz`, `_meta_associated_parts.json`) to the same production SharePoint site/drive the live Parts Availability app already reads from. This is genuinely a production upload, though a low-risk one — both are brand-new file names, so nothing existing gets overwritten, and the live app doesn't read them yet (that's Plan 2, a separate repo, not yet built). Confirm you're comfortable running this before proceeding; it needs `.env` populated with the real service principal credentials (see "Before You Start").

Run: `cd ".claude/queries/adhoc/parts-lookup-static-prototype" && python3 associated_parts_export.py`

Expected: same output as Task 1's Step 2, plus `Uploaded associated_parts.json.gz and _meta_associated_parts.json` at the end, no exceptions.

- [ ] **Step 3: Verify the files actually landed in SharePoint**

Run:
```bash
python3 -c "
import upload
token = upload.get_access_token()
import requests
url = f'{upload.GRAPH_BASE}/sites/{upload.config.SITE_ID}/drives/{upload.config.DRIVE_ID}/root:/associated_parts.json.gz'
resp = requests.get(url, headers={'Authorization': f'Bearer {token}'})
resp.raise_for_status()
info = resp.json()
print(f\"associated_parts.json.gz: {info['size']:,} bytes, modified {info['lastModifiedDateTime']}\")
"
```
Run from `.claude/queries/adhoc/parts-lookup-static-prototype`. Expected: prints a real size (close to 718 KB) and a recent `lastModifiedDateTime`.

- [ ] **Step 4: Commit**

```bash
git add ".claude/queries/adhoc/parts-lookup-static-prototype/associated_parts_export.py"
git commit -m "Add SharePoint upload step to Associated Parts export

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: Add failure alerting, matching the existing pipeline's convention

**Files:**
- Modify: `.claude/queries/adhoc/parts-lookup-static-prototype/associated_parts_export.py`

`check_app_uptime.py` already reuses `run_refresh.py`'s `log_failure()` (which logs to the shared `refresh.log` AND posts to the "Parts Availability App Alerts" Teams channel) via a plain import, with a custom `title` so the alert doesn't misleadingly say "Parts Lookup Refresh" for a different kind of failure. Do the same here.

- [ ] **Step 1: Wrap `main()` in a try/except that alerts on failure**

```python
import run_refresh  # same folder -- reuses log_failure()'s shared log + Teams alert, with a custom title

ALERT_TITLE = "Associated Parts Export"


def main() -> None:
    try:
        start = time.time()
        rows = build_export()
        run_refresh.log(f"Associated Parts export: query returned {len(rows):,} rows in {time.time() - start:.1f}s")

        size_bytes = write_gzip_json(rows)
        run_refresh.log(f"Associated Parts export: wrote {DATA_FILE} ({size_bytes / 1024:.1f} KB)")

        write_meta_file()
        upload_export()
        run_refresh.log("Associated Parts export: completed successfully")
    except Exception as exc:
        run_refresh.log_failure(f"Associated Parts export FAILED: {exc}", title=ALERT_TITLE)
        raise
```

- [ ] **Step 2: Verify it still runs cleanly**

Run: `cd ".claude/queries/adhoc/parts-lookup-static-prototype" && python3 associated_parts_export.py`
Expected: same successful output as before, now also appearing in `refresh.log` (the same shared log file `run_refresh.py`/`check_app_uptime.py` already write to) prefixed with `Associated Parts export:` lines — confirm by checking the log:

```bash
tail -5 ".claude/queries/adhoc/parts-lookup-static-prototype/refresh.log"
```
Expected: the three `Associated Parts export: ...` lines just logged, each timestamped.

- [ ] **Step 3: Commit**

```bash
git add ".claude/queries/adhoc/parts-lookup-static-prototype/associated_parts_export.py"
git commit -m "Add failure alerting to Associated Parts export, matching existing pipeline convention

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 4: Document the new export in the pipeline's own README

**Files:**
- Modify: `.claude/queries/adhoc/parts-lookup-static-prototype/README.md`

- [ ] **Step 1: Read the existing README to match its structure**

Read `.claude/queries/adhoc/parts-lookup-static-prototype/README.md` in full before editing — match whatever section headers/style it already uses rather than inventing a new format.

- [ ] **Step 2: Add a section documenting `associated_parts_export.py`**

Add a new section (using the same heading level/style as the existing file's other script sections) covering:
- What it does: collapses `Fact_PartAssociation` to `(PartA, PartB)`, computes `ConfidencePercent`/`Lift`, uploads `associated_parts.json.gz` + `_meta_associated_parts.json` to the same SharePoint site.
- Real numbers from this implementation: 44,258 rows / 5,635 distinct PartA / 718 KB gzipped.
- Schedule: weekly (not hourly like the rest of this pipeline) — see Task 5 for the actual Task Scheduler registration.
- Cross-reference: `docs/superpowers/specs/2026-08-31-associated-parts-counter-lookup-design.md` for full design rationale, and the `parts-lookup-app` repo for the consuming feature.

- [ ] **Step 3: Commit**

```bash
git add ".claude/queries/adhoc/parts-lookup-static-prototype/README.md"
git commit -m "Document associated_parts_export.py in the pipeline README

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 5 (manual — Brian): Schedule the weekly export on the Gateway PC

This is not automatable from this session — it requires access to the Gateway PC (`GATEWAY-PC-PIPELINE-DEPLOYMENT.md` describes exactly this machine) and a domain credential prompt (`Get-Credential`) that can't be scripted non-interactively.

- [ ] **Step 1:** Pull the latest `dev` branch on the Gateway PC's clone (`C:\data-projects`, per `GATEWAY-PC-PIPELINE-DEPLOYMENT.md`) so `associated_parts_export.py` is present there:
  ```powershell
  cd C:\data-projects
  git pull origin dev
  ```
- [ ] **Step 2:** Confirm the same `.env` already present in `.claude\queries\adhoc\parts-lookup-static-prototype\` on that machine has everything `config.py` needs (it should — this script reuses the exact same `config.py`/credentials as the existing hourly pipeline, nothing new to add).
- [ ] **Step 3:** Register a new weekly scheduled task, following the exact same pattern already used for "Parts Lookup Refresh" on this machine:
  ```powershell
  $action = New-ScheduledTaskAction -Execute "C:\Users\bfox\AppData\Local\Programs\Python\Python313\python.exe" -Argument "associated_parts_export.py" -WorkingDirectory "C:\data-projects\.claude\queries\adhoc\parts-lookup-static-prototype"

  $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 6:00AM

  $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable

  $cred = Get-Credential -UserName "SPI\bfox" -Message "Enter your domain password - this lets the task run even when nobody's logged in"

  Register-ScheduledTask -TaskName "Associated Parts Export" -Action $action -Trigger $trigger -Settings $settings -User $cred.UserName -Password $cred.GetNetworkCredential().Password -RunLevel Limited
  ```
  Monday 6 AM matches the same "weekly, off any daily critical path" cadence already established for `Fact_PartAssociation_Build.ipynb` itself (the Fabric-side notebook this export depends on) — this export should run comfortably after that notebook's own weekly run has completed. Adjust the day/time if the notebook's actual schedule differs from Monday once Task 9 of the Fabric-side plan (`docs/superpowers/plans/2026-08-27-associated-parts-recommended-parts.md`) sets it up.
- [ ] **Step 4:** Trigger it once manually to confirm it actually works under the scheduled task's own credentials (not just interactively as you): `Start-ScheduledTask -TaskName "Associated Parts Export"`, then check `refresh.log` for a fresh `Associated Parts export: completed successfully` line and re-run Task 2 Step 3's verification script to confirm the SharePoint files updated.
