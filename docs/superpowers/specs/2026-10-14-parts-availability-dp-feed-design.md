# Parts Availability: feed the app from DP instead of LH_Master_Data

> **Progress:** design approved by Brian 2026-10-14. Nothing built yet. Next: implementation plan.

## Goal

Move the Parts Availability app's hourly data feed off LH_Master_Data onto the DP backend, at the same cost and the same freshness, without touching the live app's behaviour except one small, deliberate fix (the stale banner window).

## Current state (verified 2026-10-13/14, read-only)

The app is **not** a Fabric App any more. Earlier memory notes and `projects/parts lookup tool - app/ARCHITECTURE.md` (which stops at 2026-08-06) describe superseded designs.

```
Equip (ODBC dsn=EquipRDB64, gateway)
  → df_InMaster_PartsLookup_Raw (LH_Master_Data, weekdays 07:50–16:50 hourly, ~2 min, ends 2027-08-18)
  → LH table InMaster_PartsLookup_Raw (~1,069,000 rows, Replace)
  → Gateway PC SPI00T4022W11, Task Scheduler "Parts Lookup Refresh" (weekdays 08:00–20:00 hourly, ~18 min):
       run_refresh.py → extract.py (DuckDB over OneLake, SPN 678f50be…) → partition.py → upload.py (Graph)
  → SharePoint library: ~1,380 gzipped prefix files + _manifest.json + _meta.json
  → React PWA on Windows Server 2016 (https://go-parts.spitractor.com), MSAL; each user's browser reads the files via Graph
```

- Pipeline code: `.claude/queries/adhoc/parts-lookup-static-prototype/` (this repo; the Gateway PC runs a clone of `dev`). App code: `parts-lookup-app` repo.
- Alerts (Teams): refresh failure, a 90-minute staleness check, app uptime.
- Unscheduled and unused: `Pipeline_Parts_Lookup_App` (schedule off), `Pipeline_PartsLookup_Incremental`, `df_InMaster_PartsLookup_Incremental`, `df_PartsLookup_Sync`, `df_PartsLookup_Sync_Incremental`, `Update_Watermark_PartsLookup`, `Parts_Availability_App_WaterMark`. The `parts-lookup-app` Fabric App (AppBackend + SQLDatabase in `RP - Fabric Apps`) still exists, but the app no longer reads it. So the earlier Fabric SQL Database concerns (kept-online billing tail, TRUNCATE reseed) don't apply.

### Problems found in the current setup

1. `_meta.json` stores the time the Gateway PC script ran, not the data's age. The last LH load is 16:50, but uploads continue until 20:00 and each one is stamped "fresh". A failed LH load (as on 2026-10-08 at 11:50) also republishes old data as fresh, so no staleness alert fires.
2. The app flags stale data from 08:00, and the first refresh doesn't finish until about 08:18. So the first users of the day see a stale warning.
3. Every run uploads all ~1,380 files, even when the source hasn't changed.

### Why not Bronze or the DP intraday mode (measured)

- **Cost:** Capacity Metrics, F8, 2026-10-01 to 14:
  - `df_InMaster_PartsLookup_Raw`: 72,148 CU(s), about **750 CU(s) per run**.
  - JD `PL_EquipRDB_To_Fabric_Incremental`: 123,069 CU(s), about **6,500 CU(s) per run**. It copies all 19 incremental tables.
  - Hourly JD Incremental would cost about 9–10 times today's feed, before any Spark.
- **Accuracy:** compared LH's 08:50 load with Bronze after JD's 08:56 incremental copy (2026-10-13):
  - 1,068,934 keys match.
  - 63 rows differ, mostly BinQty by ±1.
  - About 30 of those rows have an old `ModifiedDate`, so Pending_Qty changes don't bump the JD watermark.
  - 9 rows (branch 92, franchise BS) were missing from Bronze entirely.
  - So Bronze can't give exact hourly data, and a direct ODBC pull is the justified exception to "Bronze first".
- **`Silver_InMaster`** lacks Bin, SuperFrom/To, VendorCode, NOTE, Pending_Qty and OS_ORDER_QTY. Bronze types also differ: `VENDOR_CODE` is INTEGER and the quantities are DECIMAL(8,2), with 79 fractional rows.
- **Key:** Branch + Franchise + PartNumber has 0 duplicates on the raw values in both LH and Bronze. Trailing-space twin part numbers (6 in this filtered set) are real, separate rows.

## Requirements (Brian, 2026-10-14)

- **Freshness:** hourly during business hours, as today.
- **Days:** weekdays only. Saturday loads aren't needed.
- **No stale banner during normal hours (08:00–17:00)** when the loads are healthy.
- **Cost:** no more than today.

## Design (Option A: DP_Staging ODBC dataflow on its own schedule)

### 1. Dataflow and table

- **New item:** `df_PartsAvailability_Raw`, a Dataflow Gen2 in `DP - Staging - Dev/Raw Data - Dataflows/`. It reaches Prod through "Deploy DP backend".
- **Output:** table `PartsAvailability` in DP_Staging, written with Replace. A plain name, following the `RepairOrderDetail` / `InSalPar_Audit` precedent: the dataflow's own SQL shapes the data, with no Silver notebook and no Gold copy.
- **Query:** the live `df_InMaster_PartsLookup_Raw` SQL copied exactly:
  - same 13 source columns;
  - `VENDOR_CODE IS NOT NULL`, `BRANCH NOT IN ('5','97')`;
  - same types, `BinQty = OnHandQty - PendingQty`.
- **One added column:** `ExtractedAtUtc` (datetimezone). It's taken once per run from `DateTimeZone.UtcNow()`, so every row in a load has the same value.
- **Explicitly not done:** no PartNumber trimming, no dedup, no case folding.
- **Header comment:** purpose, grain, source, business use, and the "why ODBC, not Bronze" reasoning above.
- **Prod binding:** through `parameter.yml`, like the existing ODBC dataflows. That covers the gateway connection `dsn=EquipRDB64` (`70ea8af2-b529-4843-aee6-28297801fe71`) and the lakehouse IDs. SPN-Fabric-CICD-Deploy is already a user of that connection.

### 2. Schedule, DAG entry, alerting

- **DAG entry** in `deploy/dp_refresh_dag.json`:
  ```json
  {"name": "df_PartsAvailability_Raw", "type": "dataflow", "workspace": "staging", "tier": "staging",
   "cadence": "manual", "dependsOn": [], "produces": ["PartsAvailability"]}
  ```
  - `manual` keeps it out of the 06:15 run (same as `df_Dim_BranchUserAccess`).
  - `items` mode can still run it for a repair.
  - It is not flagged `intraday`.
- **Dev:** no schedule (Dev tier rule); tested with manual refreshes.
- **Prod:** Brian sets a Fabric schedule on the dataflow after the deploy:
  - weekdays **06:50–16:50 hourly** (11 loads);
  - end date as far out as Fabric allows. Schedules expire silently, and the current LH one ends 2027-08-18.
  - It runs as the schedule owner, since dataflows refuse service principals.
  - It doesn't clash with the 06:15 DP run, whose dataflows finish well before 06:50.
- **Alerting:**
  1. The Fabric schedule's failure notification, to Brian.
  2. The Gateway PC staleness check (Teams), now measuring `ExtractedAtUtc` age (see section 3).
  3. A backstop in the DP morning summary email: an `orchestrator.freshnessChecks` entry for `PartsAvailability.ExtractedAtUtc` with `maxAgeDays: 4`, which covers a weekend plus a holiday. It catches an expired or disabled schedule. The plan must confirm that `freshnessChecks` handles a timestamp column; today's checks use date columns.
- **No retry pipeline.** The one failure in 31 recent LH runs was transient and the next hourly load fixes it.

### 3. Gateway PC pipeline changes (`parts-lookup-static-prototype/`)

1. **`extract.py`:**
   - **Source switch:** both sources are defined (`LH` as today; `DP` = DP - Staging - Prod `189e5c0a-548a-4feb-93d6-dda9ebbe96c1` / DP_Staging `6713bd45-a4ad-47e6-8bff-1bb0415e9784`, table `PartsAvailability`), selected by one `SOURCE` constant. Rollback is one line plus `git pull`. The plan confirms the OneLake table path (`Tables/PartsAvailability` vs `Tables/dbo/PartsAvailability`).
   - **Extract metadata:** it reads `ExtractedAtUtc` and writes it to `extract_meta.json`.
   - **Guards.** The run fails, with a Teams alert, and publishes nothing, if:
     - there are fewer than 1,000,000 rows;
     - `ExtractedAtUtc` is missing or has more than one value;
     - any key Branch + Franchise + PartNumber is duplicated on the raw values.
   - In `LH` mode, where there's no `ExtractedAtUtc`, the extract time stands in, which keeps rollback working.
2. **`run_refresh.py`:**
   - **Skip if unchanged:** if `ExtractedAtUtc` equals the last published value (`last_published.json`, updated only after a fully successful upload), it logs `SKIPPED - source unchanged` and exits successfully. No partition, no upload.
   - **`_meta.json`:** `generatedAt` = `ExtractedAtUtc`, the data time. A `publishedAt` field is added for diagnostics. **No app change is needed:** it reads `generatedAt`.
   - **Upload order:** `_meta.json` is uploaded **last**, so "Data as of" never moves ahead of the files.
3. **`check_staleness.py`:** no logic change. `generatedAt` now means data age, so a failed load triggers the alert.
4. **Task Scheduler** (PowerShell, run by Brian on the Gateway PC, recorded in `GATEWAY-PC-PIPELINE-DEPLOYMENT.md`):
   - "Parts Lookup Refresh" weekdays **07:00–17:00 hourly** (11 runs);
   - "Parts Lookup Staleness Check" weekdays **07:45–17:45**;
   - uptime check unchanged.
   - The 12-hour repetition was a limit of the GUI dropdown, not of Task Scheduler.
5. **SharePoint target in `.env`:** so tests upload to the **"Test - Part Availability"** library, never the live one.
6. **Access:** SPN `678f50be-0c5a-4e5b-8b46-6357dfb30a23` gets read access to DP_Staging Prod. Least privilege is sharing the lakehouse item with "Read all OneLake data"; the plan first checks how it reads LH today. Brian grants it.
7. **Tests:** pytest for the pure logic: the guards, the skip decision and `_meta` contents.

**Timeline on a normal day:**
- The 06:50 load is published by about 07:20, so at 08:00 the data is about 70 minutes old, under the 90-minute threshold: **no banner at the start of the day.**
- The last load is 16:50, published by about 17:20.
- Runs with no new data skip.

### 4. App change (`parts-lookup-app`)

- **Change:** `BUSINESS_END_HOUR` 20 → **18** in `src/services/dataService.ts`, with its test updated.
- **Why:** once `generatedAt` is the real data time, the 16:50 data crosses 90 minutes at about 18:20. The 08:00–20:00 window would then show a banner every evening.
- **Deploy:** `deploy.ps1` to the Server 2016 box at cutover, with Brian's OK.

### 5. Validation and cutover

**Phase 1: Dev**
1. Build the dataflow on `dev` in fabric-workspace-docs. Run `dag_check` and pytest, then Git sync DP - Staging - Dev.
2. **New read-only check:** `tools/dp-migration/parts_availability_check.py <tier> [date]` (DuckDB). It lines up each DP load with the LH load from the same minute by Delta commit time, and reports:
   - key overlap (both directions);
   - per-column differences;
   - raw-key duplicates;
   - row counts and `ExtractedAtUtc`.

   **Pass:** identical key sets, and any differing rows are few and explained by the seconds between the two queries. **Fail:** the same key differing in two consecutive pairs, or a one-sided key that persists.
3. Run the Dev dataflow by hand at an LH load minute and check it.
4. Gateway PC code on `dev` in this repo, pytest green. Then one end-to-end run from Brian's PC: Dev source → test library. Check it with a local `npm run dev` build pointed at the test library.

**Phase 2: Prod in parallel (about 3 business days)**
1. PR `dev → main`; Brian merges and runs "Deploy DP backend".
2. Brian's steps in Prod:
   - set the schedule (06:50–16:50) and the failure notification;
   - grant SPN access.
3. LH and the live app are unchanged. After each day, run the check over every hourly pair (07:50–16:50), about 10 a day, all expected clean.
4. One publish to the test library from the DP Prod source.

**Phase 3: cutover** (weekday before 06:50, or after 17:00; each step with Brian's OK)
1. `git pull` on the Gateway PC, with `SOURCE = "dp"`.
2. Update the two Task Scheduler tasks.
3. Deploy the app with `BUSINESS_END_HOUR = 18`.
4. Watch the first day:
   - the first publish around 07:20;
   - no banner at 08:00;
   - `SKIPPED` lines after 17:00;
   - the staleness checks OK.

**Rollback:** `SOURCE = "lh"` plus `git pull`. It works as long as the LH schedule is still on.

**Phase 4: retire the LH feed** (after about 5 clean business days on DP, with Brian's OK)
- **Disable** (not delete) the `df_InMaster_PartsLookup_Raw` schedule. LH_Master_Data then has 14 of 14 schedules off.
- The LH table stays frozen as a reference.
- **Separate cleanup list for Brian to approve; nothing is deleted in this project:**
  - the `parts-lookup-app` Fabric App and its SQL DB;
  - the unused LH Parts Lookup items listed above;
  - the disabled fallback task on Brian's PC.

## Cost

- **Steady state:** 11 loads × about 750 CU(s) ≈ 8,250 CU(s) per weekday, against about 7,500 today. The LH dataflow's cost goes away, so the net change is about 0.
- **Parallel run:** briefly doubles the cost (about 3 days).
- **Gateway PC:** uploads drop from 13 a day to 11 at most, and runs with no new data skip.

## Docs and memory to update

- **This repo:**
  - rewrite `projects/parts lookup tool - app/ARCHITECTURE.md` to the real current architecture;
  - the pipeline README and `GATEWAY-PC-PIPELINE-DEPLOYMENT.md`;
  - `docs/architecture/lh-master-data-retirement.md`;
  - `docs/architecture/jd-bronze-raw-sources-catalog.md` (why ODBC).
- **fabric-workspace-docs:** regenerate `docs/TABLE-LINEAGE.md`.
- **Memory:** update `project_parts_lookup_tool`.

## Out of scope / follow-ups

- **Option C:** move partition and upload into a Fabric Python notebook to retire the Gateway PC task. That roughly doubles CU, so revisit only once this is proven.
- **Upload only changed partition files.** This needs deterministic gzip output, since today's files embed a timestamp.
- **Intraday DP mode for Parts Not Re-Ordered:** independent of this work.
- **Unexplained LH SQL endpoint use:** the LH_Master_Data SQL endpoint ("Warehouse") used 143,062 CU(s) over 14 days, from 2 users. That's a lead for the LH retirement tracker, not this project.
- **The 9 Bronze-missing rows (branch 92 BS):** worth raising with JD as a Bronze completeness issue.
