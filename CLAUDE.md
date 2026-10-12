# Data Projects - Claude Code Context

## Project Overview

Power BI reporting for South Plains Implement (John Deere and other brands), built on Microsoft Fabric. **As of 2026-10-07, every production report reads the DP backend** (a medallion lakehouse platform). The original `LH_Master_Data` lakehouse is being retired.

- **Owner:** Brian Fox (sole developer).
- **Fabric capacity:** F8 (`fabric1cap1`).
- **Source system:** Equip (SQL Anywhere), mirrored by John Deere into JD Bronze. Direct ODBC (`dsn=EquipRDB64`, through gateway SPI-Data-Gateway) is used only where Bronze can't help.

This repo (`data-projects`) is the **development and documentation workspace**: specs, plans, architecture docs, query library, check scripts and local report copies. **It is not Fabric-integrated**, so changes here never reach Fabric. All Fabric code (notebooks, dataflows, pipelines, report/model definitions, deploy tooling) lives in **`fabric-workspace-docs`** (see below).

## Architecture (current)

```
Equip (SQL Anywhere)
  → JD Bronze (JD_FabricOneLake / JD_EquipRDB_Production_Bronze; JD's own pipelines + gateway)
  → DP_Staging   (Silver: OneLake shortcuts to Bronze + Build_Silver_* notebooks; a few Dataflow Gen2 items
                  for sources not in Bronze: ODBC tables, SharePoint, the JD price files on the network share)
  → DP_Presentation (Gold: Build_Gold_* notebooks → dim_* / Fact_*; shortcuts to the Silver tables Gold reads)
  → Semantic models (Import, via the DP_Presentation SQL endpoint)
  → Reports in RP - Parts Reports / RP - Service Reports / RP - Financial Reports, reached by users through org apps
```

| Tier | Workspaces | Code gets there by | Refresh |
|---|---|---|---|
| **Dev** | DP - Staging - Dev, DP - Presentation - Dev, RP - Dev | Git sync from `dev` (`tools/dp-migration/git_sync.py <workspaceId>`) | **Manual only** (no schedule) |
| **Prod** | DP - Staging - Prod, DP - Presentation - Prod | GitHub Actions **"Deploy DP backend"** (fabric-cicd) from `main`. Not Git-connected | **Pipeline_DP_Refresh weekdays 06:15**, ~35 min, plus a summary email |
| **Reports** | RP - Sandbox → RP - Parts / Service / Financial Reports | GitHub Actions **"Deploy reports"** from `main` (`deploy/report_promotion.json`) | DP models refresh at the end of each DP run. Shannon's Aftermarket model is hourly ODBC |

**Pipeline_DP_Refresh**, one per tier, in the DP Presentation workspace:
- **What it runs:** JD incremental → staging dataflows → Silver DAG → Gold DAG → report model refresh → summary email (Graph).
- **Generated code:** `Run_DP_Refresh` / `Notify_DP_Refresh` are generated from `deploy/orchestrator_core.py`, `orchestrator_glue.py` and `notify_*.py` by `deploy/render_orchestrator.py`. Don't hand-edit the notebooks.
- **Config:** `fabric-workspace-docs/deploy/dp_refresh_dag.json`: items, cadences, dependencies, report→table map, `freshnessChecks`.
- **Modes:** `scheduled`, `all`, `items` (with `items=a,b`), `rerun_failed`, `intraday` (built; no items use it yet), plus `dry_run`.
- **After every Prod deploy**, run `python deploy/claim_prod_pipeline.py` (notebooks run as the pipeline's last modifier).

**Users:** report workspaces are **authoring-only**. Users reach reports through one **org app** per workspace, granted via Entra groups `PBI - Parts Reports`, `PBI - Service Reports`, `PBI - Financial Reports`.
- **When a report goes live:** add it to that workspace's org app and audience.
- See fabric-workspace-docs `OPERATIONS-GUIDE.md` → "Report Org Apps".

**LH_Master_Data is retiring.** Its Master Orchestrator was switched off 2026-10-09. A few schedules stay on until their DP replacements are proven: PartMaster snapshots + `df_JDIS_PART_INFORMATION_Raw` (04:15), `pl_Raw_PriceUpdate_History` + the PC harvest task, and `df_InMaster_PartsLookup_Raw` (Parts Availability app). The tracker is `docs/architecture/lh-master-data-retirement.md`. **Don't build anything new on LH_Master_Data.**

## Where things are documented

| Topic | Location |
|---|---|
| Day-to-day operations (releases, re-claim, shortcuts, one-offs, org apps, Part Master lookups) | `fabric-workspace-docs/OPERATIONS-GUIDE.md` |
| **Rules every DP notebook must follow** (JD keys, no arbitrary survivors, determinism) | `docs/architecture/dp-notebook-rules.md` |
| DP workspaces, lakehouses, IDs, early build history | `docs/architecture/data-platform-workspaces.md` |
| LH_Master_Data retirement status (what's still on and why) | `docs/architecture/lh-master-data-retirement.md` |
| Report migration / promotion validation | `docs/architecture/report-migration-catalog.md`, `report-promotion-validation.md` |
| Specs and plans (with progress notes at the top) | `docs/superpowers/specs/`, `docs/superpowers/plans/` |
| JD Bronze health and runbook | `projects/jd-bronze-pipelines/README.md`, `python tools/dp-migration/jd_bronze_check.py` |
| Fact/dim catalogs from the migration audit | `docs/architecture/lh-master-data-facts-catalog.md`, `...-dimensions-catalog.md` |

## Repository Structure

```
data-projects/
├── .claude/queries/          # Query library (.pq reference copies; mostly LH-era, see below)
├── docs/
│   ├── architecture/         # Current-state reference docs (see table above)
│   └── superpowers/specs|plans/  # Design specs and implementation plans
├── projects/<report or project>/  # Per-project docs, scripts, local PBIP copies (some frozen as reference)
├── tools/dp-migration/       # git_sync.py, run_item.py, jd_bronze_check.py, check scripts (DuckDB)
└── CLAUDE.md
```

**Live report definitions are in `fabric-workspace-docs/workspaces/RP - Dev/`**, not here. Some `projects/*/reports/` folders are frozen pre-DP copies kept only for reference (e.g. `projects/jd-price-updates/`). Their READMEs say so.

## Key DP tables (DP_Presentation Gold unless noted)

- **Dimensions:**
  - `dim_BranchLocation` (69 rows; `BranchID` text, unique; `BranchKey` surrogate);
  - `dim_DateTable` (2020–2030; no "today-relative" columns; those are report-layer DAX);
  - `dim_Parts` (`PartNumberKey` = xxhash64(PartNumber));
  - `dim_CustomerList`, plus small lookups.
- **Silver (DP_Staging):**
  - `Silver_InTrans`: key **Branch + Franchise + PartNumber + TransDatetime + TransId**.
  - `Silver_PartInformation`: DP's `jdis_Part_Information`. 33 columns, key **Branch + Franchise + PartNumber**.
  - `Silver_Invoice`: `InvoiceNumber` is NOT unique.
- **Recent additions:**
  - `Fact_PartMaster_History`: change-only part-master history, kept forever. The old snapshots are archived as `Fact_PartMaster_Snapshot_*_Archive` in Prod.
  - `Fact_PartPriceChange` / `_Branch` and `Fact_JDNationalPriceChange`: JD price data.
- **Finding a table's builder:** `deploy/dp_refresh_dag.json` (`produces`).

## Conventions

### Notebooks (DP)
- Follow `docs/architecture/dp-notebook-rules.md`:
  - take the key from JD's PK;
  - no `dropDuplicates` / `first`;
  - ordering must be unique;
  - surrogate keys use xxhash64;
  - snapshot appends cast to the existing schema.
- **Always run twice / compare tiers** (`deploy/compare_tiers.py`).
- **Writing tables:** path-based `.save("Tables/Name")` (not `saveAsTable`, which lowercases names). After an overwrite, `VACUUM ... RETAIN 0 HOURS` (orphaned files confuse the SQL endpoint). History tables keep 7 days.
- **Dates:** set `spark.sql.parquet.datetimeRebaseModeInRead/Write = CORRECTED` (the source has pre-1900 sentinel dates).
- **Declaring outputs:** every item lists its outputs in `dp_refresh_dag.json`. `python deploy/dag_check.py` validates it against the code; the scanner needs literal `.save("Tables/X")`. Otherwise set `dynamicReviewed: true`.

### Power Query
- Header comments: purpose, grain, source, business use.
- PascalCase column names; Delta rejects spaces.
- Incremental refresh `RangeStart`/`RangeEnd` must be **datetime**.

### DAX / Semantic models (.tmdl)
- **TMDL does NOT support `//` comment lines.** DAX `//` inside expressions is fine. Descriptions are `///` lines before the object.
- **UTF-8 without BOM;** keep each file's line endings.
- **DP models:** connect `Sql.Database("<DP_Presentation SQL endpoint>", "DP_Presentation")`. `parameter.yml` swaps the Dev endpoint for Prod and binds `SQL_DP_Presentation_Prod`, plus any gateway connections per model.
- **Cross-table flags:** prefer `LOOKUPVALUE` on calculated columns over relationships to lookup tables.
- **Avoid** bidirectional relationships.

## Git Workflow

**Two repos:**
- **`data-projects`** (this one; GitHub SlyFox18/claude-data-projects): docs, specs, plans, tools. `main` is protected (PR required).
- **`fabric-workspace-docs`** (GitHub SlyFox18/fabric-workspace-docs): all Fabric code and the `deploy/` tooling.

**Releasing DP or report changes:**
1. Work on `dev` in fabric-workspace-docs. Run `python deploy/dag_check.py` and `python -m pytest deploy -q`. Push, then git sync the Dev workspace(s) and test in Dev.
2. `python deploy/merge_preview.py`, then open a PR `dev → main` (template `.github/PULL_REQUEST_TEMPLATE/dev_to_main.md`). **Brian merges with "Create a merge commit"**, never squash.
3. **Brian runs** GitHub Actions "Deploy DP backend" (backend) and/or "Deploy reports" (`sandbox`, or `production` + workspace).
4. After a backend deploy: `python deploy/claim_prod_pipeline.py`, fast-forward dev (`git fetch origin && git merge --ff-only origin/main && git push origin dev`), and `python deploy/sync_shortcuts.py --apply` if shortcuts were added.
5. **Reports:** Dev → Sandbox (validate; a newly deployed model needs a refresh before it shows data) → set `"live": true` in `report_promotion.json` → production deploy → add to the org app.

**Rules for Claude:**
- Work on `dev`.
- Stage only named files; both repos often hold unrelated uncommitted user changes.
- Never `fab import` into Dev (Git sync is the single writer).
- **No deletes** of Fabric items or Git content without Brian's explicit OK.
- **LH schedules:** switch off only after verifying no live reader.

### Session Start Orientation (automated)
A `SessionStart` hook (`~/.claude/scripts/git-status-check.sh`) prints both repos' git status and open High/Medium todos from `C:/Users/bfox/todo.md`. If its output is missing, the hook is broken (check for a stray `"async": true`). `todo.html` is generated from `todo.md` by hooks; edit `todo.md` only.

## Known Issues & Gotchas (current)

- **Reused source IDs:** `TransId`, `DocRef`, `RONumber` and `InvoiceNumber` are reused by the source system. Always use the full key. A 2026-10-12 Prod failure came from `(TransId, TransDatetime)`.
- **Trailing spaces in part numbers:**
  - Spark treats `"X"` and `"X "` as different; Power BI and SQL ignore trailing spaces.
  - 29 source part records are twins differing only by a trailing space. Some carry duplicate InTrans rows.
  - DP Gold ports of SQL `=` comparisons must trim.
- **JD Bronze status lies:** JD's pipelines report "Completed" even when copies fail. Check with `jd_bronze_check.py` (gateway on SPI01SR2034W). DP's refresh also checks Bronze before building.
- **Gold timestamps as "dates" break relationships.** Report date keys must be DATE.
- **Shortcut column drift:** a Silver shortcut can rename columns relative to old LH tables. Diff schemas before repointing.
- **New PBIP tables** need a Desktop close/reopen. **Edit TMDL only while Desktop is closed.**
- **Scheduled refresh on a CI-deployed model:** setting a schedule requires the owner (the deploy takes models over to the CI SPN). Take over first.
- **ODBC at night:** an LH ODBC dataflow failed at 01:15 two nights running; 04:15 is fine. The DP runs at 06:15.
- **Fabric schedules expire silently at their end date.** Check end dates on anything critical (Parts Availability's ends 8/18/2027).
- **Fabric Gen2 dataflow REST:** use `/items/{id}/jobs/instances?jobType=Refresh`, not `/dataflows/{id}/refreshes`.

## CLI Tools Available

In Bash use `export PATH="$HOME/.local/bin:$PATH"`; in PowerShell `$env:Path += ";C:\Users\bfox\.local\bin"`.

- **pbir** (report layer, local PBIR + Fabric):
  - `pbir tree|fields list|validate "X.Report"`;
  - `pbir download/publish`;
  - skill `pbir-cli`.
- **pbi** (model via a running Desktop / XMLA): `pbi connect`, `pbi dax execute`, `pbi measure ...`. Note: `pbi dax execute` can drop rows; see memory.
- **fab** (Fabric CLI, signed in as bfox@spitractor.com):
  - `fab ls`, `fab get ... -q id`, `fab api`;
  - always pass `-f` on overwrite/destructive commands;
  - **don't use `fab import` for Dev**.
- **Python + DuckDB `delta_scan` over OneLake** (`azure` + `delta` extensions, `credential_chain` with `cli`) is the standard read-only check tool. Compare timestamps in a UTC session.

## Skills Available

| Skill | Command | Use When |
|---|---|---|
| Check refresh status | `/check-refresh` | Morning check (written for the LH era; for DP read `dp_refresh_log` / the summary email) |
| New report scaffold | `/new-report "Name"` | Starting a brand new report project |
| Promote to production | `/promote-sandbox "Name"` | LH-era flow; current promotion is `report_promotion.json` + "Deploy reports" |
| Add DAX measure | `/add-measure "report" "description"` | Adding a measure |
| Debug pipeline failure | `/debug-pipeline "problem"` | Pipeline failed or data is stale |
| Sync query library | `/sync-query` | After modifying a .pq dataflow query |
| Document report | `/document-report "report"` | Stakeholder Obsidian docs |
| Wrap up session | `/wrap-up` | End of a work session |

## Related Repositories & Knowledge Bases

- **fabric-workspace-docs:** `C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs`. All Fabric item definitions (`workspaces/`), deploy tooling (`deploy/`), `parameter.yml`, the operations guide.
- **Fabric monitoring:** `projects/fabric-monitoring/` (in this repo). LH-era post-pipeline scripts; the "Post-Pipeline Monitoring" scheduled task was disabled 2026-10-09 with the LH orchestrator. The DP refresh sends its own summary email.
- **Obsidian vault:** `C:\Users\bfox\Documents\Obsidian Vault` (query library history, the Inspections KB). Update it when Brian asks.
