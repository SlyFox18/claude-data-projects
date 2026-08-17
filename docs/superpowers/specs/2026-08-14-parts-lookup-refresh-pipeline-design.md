# Parts Lookup — Automated Refresh Pipeline — Design Spec

**Date:** 2026-08-14
**Author:** Brian Fox
**Status:** Approved for implementation planning

---

## 1. Problem Statement

The static-file backend prototype (`2026-08-14-parts-lookup-static-file-prototype-design.md`) validated GO: pre-partitioned JSON files in SharePoint can serve `parts-lookup-app`'s exact-match part-number search fast enough to replace its Fabric SQL Database backend. That prototype's data pipeline was entirely manual — Brian ran `extract.py`/`partition.py` by hand using his own interactive `az`/`fab` CLI login, and dragged the resulting files into SharePoint himself.

For real pilot testing (a small trusted group, ahead of the eventual move to a dedicated IT-provided gateway machine), this needs to run **unattended, on a schedule, from Brian's computer** — without depending on him being logged in or manually uploading anything. This spec covers only that automation. The frontend rebuild (auth + data-fetching swap) is a separate spec/plan in the `parts-lookup-app` repo.

Also folded in: a real, confirmed schema gap found during the prototype (see Section 4) needs a real fix here, not another workaround.

---

## 2. Scope

### In scope
- Fixing the `InMaster_PartsLookup_Raw` dataflow so `OnOrder` is actually live on the Fabric table (currently only in the local `.pq` file, not deployed)
- A dedicated Entra ID service principal for unattended authentication, replacing Brian's personal CLI login
- Extending `extract.py`/`partition.py` to use the service principal and include `OnOrder`
- A new `upload.py` that pushes partition files to SharePoint via Microsoft Graph API, replacing manual drag-and-drop
- Basic per-run logging
- Windows Task Scheduler setup on Brian's computer, running the full pipeline every 15 minutes

### Out of scope
- The frontend rebuild (separate spec, `parts-lookup-app` repo)
- Moving the scheduled job to the eventual gateway machine (same script/task, different host — a config change when the time comes, not new design work)
- Alerting/notifications beyond a local log file (pilot-phase scope; revisit if this becomes the permanent production path)
- Decommissioning the existing Fabric App or its sync dataflows (unrelated, separate decision)

---

## 3. Service Principal Setup

A new Entra ID app registration (single-tenant, no interactive sign-in needed — this is app-only/client-credentials auth), scoped narrowly:

- **Read access to `LH_Master_Data`** (Fabric workspace) — sufficient to run the same `delta_scan` queries `extract.py` already does, via a client-secret-based Azure credential instead of `az`/`fab`'s cached CLI token
- **Write access to the test SharePoint library** — via Microsoft Graph API permissions (`Sites.Selected` scoped to just this one site, preferred over tenant-wide `Sites.ReadWrite.All`, to keep the credential's blast radius small)

Brian registers this himself (Application Administrator role covers it) and stores its client ID/secret/tenant ID somewhere the scheduled script can read them without them living in plaintext in the repo (e.g., Windows Credential Manager, or an environment-variable-backed local config file excluded from git — exact mechanism decided during implementation, not prescribed here).

---

## 4. Fix: `OnOrder` Not Live on `InMaster_PartsLookup_Raw`

**Root cause (confirmed during the prototype, not guessed):** `.claude/queries/raw-tables/InMaster_PartsLookup_Raw.pq` already defines `OnOrder` (sourced from `OS_ORDER_QTY`), added 2026-08-04. The live Fabric dataflow (`df_InMaster_PartsLookup_Raw` in `LH_Master_Data`) was never redeployed to match — confirmed via `DESCRIBE` against the live table during the prototype's Task 1, which showed no `OnOrder` column.

**Fix:** Brian opens `df_InMaster_PartsLookup_Raw` in the Fabric portal's Power Query editor, updates its M code to match the current `.pq` file content, publishes, and triggers a refresh. Verification: re-run `DESCRIBE` (or the extraction script itself) against the live table and confirm `OnOrder` is present. Manual step — not something to automate, given it's a one-time dataflow correction, not a recurring task.

---

## 5. Pipeline Scripts

Extends the prototype's scripts (`.claude/queries/adhoc/parts-lookup-static-prototype/`) rather than replacing them — same location, since this is still fundamentally the same pipeline, now made unattended:

- **`extract.py`** — same `delta_scan` logic, with two changes: (1) DuckDB's Azure secret configured via the service principal's client credentials instead of `CHAIN 'cli'`, (2) `OnOrder` added back into the `SELECT` list (contingent on Section 4's fix being deployed first).
- **`partition.py`** — unchanged logic (already handles the NaN→`null` fix from the prototype); one more column now flows through automatically since it's schema-agnostic.
- **`upload.py`** (new) — reads the generated `output/2char/` files and pushes each to the SharePoint library via Graph API (`PUT` to the drive item's content endpoint, using the file name as the path — this naturally overwrites existing files with the same name, no separate delete/cleanup step needed since partition filenames are stable across runs).

A simple orchestrator (`run_refresh.py` or equivalent) runs all three in sequence and writes one log line per run: timestamp, row count, per-step timing, success/failure. This is what Task Scheduler actually invokes.

---

## 6. Scheduling

**Revised during implementation (originally planned as every 15 minutes):** Windows Task Scheduler on Brian's computer, running the orchestrator **every hour**. The original 15-minute target assumed the scripted upload would be considerably faster than the prototype's ~6 min manual drag-and-drop; real end-to-end testing (Task 5) instead measured ~20 minutes for a full 1,248-file sequential upload (the simple `requests` implementation makes one HTTP round-trip per file with no connection reuse or concurrency — a real, separately-tracked performance follow-up, not fixed as part of this plan). An hourly cadence gives real margin (20 min inside a 60 min window, not razor-thin) and matches the actual freshness ceiling anyway — the underlying `InMaster_PartsLookup_Raw` Lakehouse dataflow this pipeline reads from only refreshes roughly every 2.5 hours, so refreshing more often than that wouldn't produce fresher data regardless of how fast the upload step is. Still easy to adjust later — this is a Task Scheduler trigger setting, not a code change, including when the job moves to the eventual gateway machine or if the upload performance follow-up lands and a faster cadence becomes worthwhile.

---

## 7. Testing / Validation Plan

- Confirm `OnOrder` is live on `InMaster_PartsLookup_Raw` (Section 4) before extending `extract.py` to select it
- Verify the service principal can authenticate and read the Lakehouse table with zero interactive login involved (test by temporarily signing out of `az`/`fab` CLI locally and confirming the script still runs)
- Verify `upload.py` correctly overwrites existing SharePoint files (not creating duplicates) by running it twice in a row and confirming file count stays constant
- Let the Task Scheduler job run unattended for a period and confirm the log shows successful cycles without Brian's active involvement
- Cross-check a few real partition files' contents in SharePoint against a fresh manual extract, to confirm the automated pipeline produces the same data shape the prototype validated

---

## 8. Related Work

- **`2026-08-14-parts-lookup-static-file-prototype-design.md`** — the validated prototype this pipeline automates. Read latency/concurrency findings from that spec still apply; this spec only concerns the write/refresh side.
- **`project_parts_lookup_tool` memory** — full incident history and the four-option architecture evaluation that led here.
- **Frontend rebuild spec** (separate, `parts-lookup-app` repo, not yet written) — the other half of making this pilot-testable; independently buildable against the files this pipeline (or the prototype's already-uploaded files) produces.
