# Non-JD Parts Order Tool: Prod release runbook (Plan A Task 15, with round 1)

> **Status: DONE 2026-10-26 (option A).** Steps 1–13 completed as written.
> - Release: PR #44, merged as `ec43d479`; the deploy succeeded with both pipelines still claimed.
> - First Prod runs: staging items OK, 4 shortcuts created, Gold OK.
> - Gold check: `nonjd_reorder_check.py --tier prod` PASS on 199,524 parts.
> - Publish: the dry decision passed against Prod; the Gateway PC was switched to `NONJD_SOURCE=prod` (41 files + `_meta`, then "already published").
> - Step 15 (compare_tiers) skipped by decision.
> - Still to do from Step 14: check the first automatic morning (2026-10-27), and Brian's own PC `.env`.
> - Seen on the day: one Dev orchestrator run crashed at startup because Fabric's `currentWorkspaceName` was None. The retry was OK. Follow-up: fall back to the workspace ID.
>
> Originally: This replaces the steps in Plan A Task 15. Plan A's Step 3 (copy `rop_matrix.csv` to Prod) is **obsolete**: Gold reads Ben's rules list now, not the matrix, and doesn't read `Files/`. Plan A's Step 4 also left out `df_NonJD_OrderRules_Raw`.
>
> **Who does what:** Brian does the merge, the GitHub Actions deploy, the Gateway PC and anything run as Brian. Claude does the read-only checks, the PR text, the shortcut sync (as Brian's `fab` login, with Brian's OK), the pipeline starts, and the verification.

## 1. What ships (merge_preview, 2026-10-26)

fabric-workspace-docs `dev` (25bb5fc9) is 23 commits ahead of `main` (603a12e7). The real content change is 17 files: 4 repo files, 3 in DP - Presentation - Dev, and 10 in DP - Staging - Dev. No production report workspace changes, and no pipeline or `parameter.yml` change.

**(a) Non-JD order tool (all of the content change):**

| Where | Item | What |
|---|---|---|
| DP - Staging | `df_NonJD_PartSettings_Raw` (new dataflow) | SharePoint list `NonJD_PartSettings` (Report Site) → table `NonJD_PartSettings`. Round 1 columns (ManualOrder, MaskedOn) |
| DP - Staging | `df_NonJD_OrderRules_Raw` (new dataflow) | SharePoint list `NonJD_OrderRules` → `NonJD_OrderRules`. Round 1 columns (MinDemands, SupplyUnit, Min/MaxLineValue, Archived); blank SupplyUnit → null |
| DP - Staging | `Build_Silver_PartSalesHistory` (new notebook) | 60 months from Bronze `InHistMQT` → `Silver_PartSalesHistory` |
| DP - Staging | `Build_Silver_PartStockingRules` (new notebook) | min/max/reorder/activity from Bronze `InMaster` → `Silver_PartStockingRules` |
| DP - Presentation | `Build_Gold_NonJD_Reorder` (new notebook, round 1 / C3) | → `Fact_NonJD_Reorder`, `Fact_NonJD_SalesHistory` |
| DP - Presentation | `DP_Presentation.Lakehouse/shortcuts.metadata.json` | 4 new shortcuts: `Silver_PartSalesHistory`, `Silver_PartStockingRules`, `NonJD_PartSettings`, `NonJD_OrderRules` |
| repo | `deploy/dp_refresh_dag.json` | 5 new items, all `cadence: daily` |
| repo | `deploy/test_inmaster_guard.py` | The new InMaster reader is added to the identical-guard test |
| repo | `docs/TABLE-LINEAGE.md` | Regenerated |

**(b) Other work riding along:**

| Item | Finished? | Safe? |
|---|---|---|
| `docs/TROUBLESHOOTING.md`: 2 rows (DP_Presentation lakehouse "changed on both sides" on shortcut changes; `InvalidShortcutPayloadBatchErrors` "Target path doesn't exist") | Yes (b7ac0870, lessons from the Dev build) | Yes, docs only |
| Bronze check blocks on TimedOut/Cancelled (4e62ac9c) and the WkRoFile TROUBLESHOOTING row (fdeef853) | Already on `main` as hotfix PR #43 and **already deployed to Prod** (Deploy DP backend run 39621383641, 2026-10-21). `dev` has it through the merge e2e3fbca | No diff. They only show in `git log main..dev` because the hotfix commits were cherry-picked |

Nothing else is on `dev`. **Nothing in (b) needs a decision.**

**Prod today:** Pipeline_DP_Refresh ran OK this morning (06:15, 40 min, 94 items, 27 models). Both Prod pipelines are claimed (`claimed:2026-10-21T15:03Z`). Prod Staging has none of the new items. `sync_shortcuts.py` (dry run) shows DP_Staging 34/34, so the Bronze shortcuts `InHistMQT` and `InMaster` already exist in Prod. DP_Presentation has 33 of 37: the 4 new ones are missing, as expected.

## 2. Decisions for Brian

1. **When to release.** The app reads Dev today, and Dev only refreshes when someone runs it, so the app's data goes stale. Releasing moves the app onto the daily 06:15 Prod run. Round 1 Gold and the contract v2 publish are already together on the Gateway PC since C10, so nothing else needs to change first.
2. **How to do the first Prod run.** Pick one:
   - **A, same day (recommended):** two `items` runs today, the staging items and then Gold, with the shortcut sync in between. Then the check, then the publish switch. Cost: `items` mode also refreshes all 27 Prod report models each time (about 10 minutes, during the day; the data in them doesn't change).
   - **B, overnight:** one `items` run today (the staging items) plus the shortcut sync. Gold first runs in the next 06:15, and the publish switch happens the next morning. One model refresh during the day, but verification waits a day.
3. **Brian's own PC as a publisher.** Brian's PC also has a publish `.env` (source `dev`) and its own `publish_state.json`. Once the Gateway PC publishes Prod, a by-hand run on Brian's PC would overwrite the library with Dev data. Either change Brian's `.env` to `prod` too (Step 13), or don't run `run_publish.py` there any more.
4. **Tier comparison (optional).** `compare_tiers` needs Dev run right after a Prod run on the same Bronze (Step 15). It only touches Dev. Do it or skip it? The required correctness check is `nonjd_reorder_check.py --tier prod` (Step 11).

## 3. Facts the runbook relies on

- **The deploy publishes** the 2 dataflows and 2 Silver notebooks to DP - Staging - Prod, and the Gold notebook to DP - Presentation - Prod. `parameter.yml` swaps the Dev lakehouse and workspace IDs, including the dataflows' Lakehouse destination.
  - **Shortcuts are not deployed.** `sync_shortcuts.py --apply` creates them.
  - **No pipeline is re-published:** the pipeline content and `parameter.yml` are unchanged, so the hash matches. Both pipelines stay claimed and the run summary should say "unchanged → still claimed". The claim step is still in the runbook as a check.
- **The DAG picks the new items up by itself.** All 5 are `daily`, so the scheduled 06:15 run includes them. The orchestrator finds dataflows by name in the staging workspace (`ForEach_Dataflows`), so the pipeline needs no change.
- **SharePoint connection:**
  - Both new dataflows use the same SharePoint cloud connection (DatasourceId `42db34a4-…`) as `df_ServiceTimeSheets_Raw`, which already runs daily in Prod. There's nothing to create and no `parameter.yml` binding (dataflows aren't bound there).
  - Dataflows run as the pipeline's last modifier or invoker: Brian for the scheduled run (claimed) and for runs he starts. Brian's connection already reads the Report Site lists; Dev ran them through the same connection.
- **New shortcuts fail until their target exists.** Each new DP_Presentation shortcut points at a Prod DP_Staging table that doesn't exist until its staging item has run once in Prod ("Target path doesn't exist", seen in Dev). Order: staging items → shortcuts → Gold.
- **`items` mode:**
  - It skips the JD Bronze check and the JD Incremental load.
  - It refreshes **all** Prod report models (`models_for_run`).
  - It writes `dp_refresh_log` rows, which the publish needs. **Don't use `run_item.py` for the Prod Gold**: an unlogged run makes the publish guard refuse.
- **The publish:**
  - `config.py` maps `NONJD_SOURCE` (`dev` or `prod`, default `dev`) to the DP_Presentation workspace and lakehouse. Prod is `7836042d-…` / `29d9df80-…`, already in the code, so only `.env` changes.
  - When the source changes, `decide_publish` treats it as "new data" and `previous` hashes are dropped, so **every file is re-sent with no `--force` needed**. `--force` is only for repairing files.
  - The guard looks back 14 days in that tier's `dp_refresh_log` for the latest `Build_Gold_NonJD_Reorder` row, needs it Succeeded, and needs `BuiltAtUtc` inside that run.
  - `check_columns` also needs `NonJD_OrderRules` readable through the Prod DP_Presentation shortcut.
- **The publish SPN can read Prod.** The Parts Availability SPN (…b30a23) is Viewer on DP - Presentation - Prod. It read `dim_BranchLocation` and `dp_refresh_log` there on 2026-10-20 (Plan A Task 1 note), and it already reads DP_Staging Prod for Parts Availability, which the shortcuts point at.
- **Timing:** Prod 06:15 finishes about 06:55 (40 min today). The new items run in parallel inside the Silver and Gold steps and add a few minutes at most. The Gateway PC task runs weekdays at 07:15 and repeats every 30 minutes for 3 hours, so a late run is still picked up by 10:15.
- **compare_tiers:**
  - `Fact_NonJD_Reorder` always shows DIFF there, because its `BuiltAtUtc` column isn't one of the load-timestamp names the tool ignores. Use `nonjd_reorder_check.py --fingerprint-only` (it excludes `BuiltAtUtc`) for that table.
  - `Fact_NonJD_SalesHistory` compares normally.

IDs: Prod Pipeline_DP_Refresh `1fa19eb8-7d5f-465e-b7e7-b31e02e56a2c` (workspace `7836042d-adb1-4846-b70d-bd42980054c5`). Dev Pipeline_DP_Refresh `4e73d626-d1e4-47ce-976c-3361d3d5ecf6` (workspace `73fd5443-240e-410a-990a-98827f32c087`).

---

## 4. Runbook

Repos: `FWD` = `C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs`, `DPJ` = `C:\Users\bfox\Documents\Git-Projects\data-projects`. In Bash, run `export PATH="$HOME/.local/bin:$PATH"` first.

### Step 1: Pre-checks (Claude, read-only)

In FWD on `dev`, clean, with `dev` = `origin/dev`:
```bash
git fetch origin && git status --short && git log --oneline origin/main..dev | wc -l
python deploy/merge_preview.py
python deploy/dag_check.py
python -m pytest deploy -q
python deploy/hygiene_audit.py
python deploy/sync_shortcuts.py
```
Expect (as on 2026-10-26):
- merge_preview: `(repo): 4 files`, `DP - Presentation - Dev: 3 files`, `DP - Staging - Dev: 10 files`, and every production report folder "no changes".
- dag_check: `114 items (105 notebooks), 28 reports, 4 excluded`, `OK`.
- pytest: `359 passed`.
- hygiene_audit: `0 gold notebook(s) with problems`.
- sync_shortcuts: Staging `34 wanted, 34 exist, 0 to create`, Presentation `37 wanted, 33 exist, 4 to create` (the 4 listed in section 1).

Also confirm last Dev Gold is good (Plan C C10: PASS on 199,555 parts):
```bash
cd DPJ && python tools/dp-migration/nonjd_reorder_check.py --tier dev
```
Expect `PASS`. And check that Prod ran OK today: `python tools/dp-migration/dp_refresh_status.py prod`. Don't release on a morning Prod failed.

### Step 2: Open the PR (Claude writes, Brian or Claude opens)

`dev → main` in fabric-workspace-docs, title **"Non-JD Parts Order Tool backend to Prod (round 1)"**. Body:

```markdown
## What changed and why

- New DP backend for the Non-JD Parts Order Tool web app: two SharePoint dataflows (part settings and Ben's reorder rules, Report Site), two Silver notebooks (60-month sales history from InHistMQT, stocking rules from InMaster) and one Gold notebook (`Fact_NonJD_Reorder`, `Fact_NonJD_SalesHistory`).
- Gold is on the round 1 calculation from Ben's feedback (Plan C3: demand counts, weeks/months of supply, Equip minimums always, branch exclusions, line value limits, mask/manual order). It matches the independent DuckDB reference with 0 differences on 199,555 parts in Dev, and two runs gave the same fingerprint.
- Prod lets the app's daily publish (Gateway PC, contract v2, already deployed) read the 06:15 Prod run instead of manually refreshed Dev.
- No report reads these tables; no existing item changes.

## Workspaces / Items Changed

| Workspace | Item | Change |
|-----------|------|--------|
| DP - Staging | `df_NonJD_PartSettings_Raw` | New dataflow (SharePoint list → `NonJD_PartSettings`) |
| DP - Staging | `df_NonJD_OrderRules_Raw` | New dataflow (SharePoint list → `NonJD_OrderRules`) |
| DP - Staging | `Build_Silver_PartSalesHistory` | New notebook → `Silver_PartSalesHistory` |
| DP - Staging | `Build_Silver_PartStockingRules` | New notebook → `Silver_PartStockingRules` |
| DP - Presentation | `Build_Gold_NonJD_Reorder` | New notebook → `Fact_NonJD_Reorder`, `Fact_NonJD_SalesHistory` |
| DP - Presentation | `DP_Presentation.Lakehouse` shortcuts | 4 new shortcuts to the staging tables (created in Prod by `sync_shortcuts.py`) |
| (repo) | `deploy/dp_refresh_dag.json` | 5 new daily items |
| (repo) | `deploy/test_inmaster_guard.py` | New InMaster reader added to the guard test |
| (repo) | `docs/TABLE-LINEAGE.md`, `docs/TROUBLESHOOTING.md` | Regenerated lineage; 2 rows on DP_Presentation shortcut sync |

## Pipeline / Dataflow Changes

- [x] New dataflow added — wave assignment confirmed in Pipeline_Facts or Pipeline_Dims

Details (if any): two new staging dataflows, registered in `dp_refresh_dag.json` (daily); Pipeline_DP_Refresh runs them by name, so the pipeline JSON is unchanged and stays claimed. They use the existing SharePoint cloud connection (same as `df_ServiceTimeSheets_Raw`). The 2026-10-21 Bronze-check hotfix in the commit list is already on `main` (#43); it adds no diff.

## Checklist

- [x] All changes already validated in Fabric (these were made in the workspace, not deploying new changes): run in DP Dev (Plan C C10 `mode=all` OK; `nonjd_reorder_check.py --tier dev` PASS)
- [x] `dag_check.py` OK, `python -m pytest deploy -q` 359 passed, `hygiene_audit.py` 0 problems
- [x] dev branch in `data-projects` is also up to date (docs, TMDL, queries match)

## Post-Merge Actions Required

- [ ] Run **Deploy DP backend** from `main`; confirm both pipelines "unchanged → still claimed"
- [ ] Fast-forward `dev`
- [ ] Prod `Pipeline_DP_Refresh` `mode=items` with the 4 staging items, then `python deploy/sync_shortcuts.py --apply` (4 shortcuts), then Gold
- [ ] `nonjd_reorder_check.py --tier prod` PASS, then switch the Gateway PC publish to `NONJD_SOURCE=prod`
- [x] Other: no report workspace syncs needed

## Notes

Runbook: data-projects `docs/superpowers/plans/2026-10-26-non-jd-parts-order-tool-prod-release.md`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

To open it from the CLI: `gh pr create --base main --head dev --title "..." --body-file <file>`.

### Step 3: Merge (Brian)

Review the PR, then merge with **Create a merge commit** (never squash).

### Step 4: Deploy (Brian)

GitHub → Actions → **Deploy DP backend** → Run workflow → Use workflow from **`main`** → Run workflow.
- Expect about 1.5 minutes. The tests, dag_check and hygiene steps pass.
- The summary should list `Pipeline_DP_Refresh: unchanged → still claimed` and `Pipeline_PartsAvailability: unchanged → still claimed`.
- The staging deploy publishes the new items alongside the existing ones.

If it fails with "job was not acquired by Runner", re-run it later (a GitHub problem).

### Step 5: Claim check (Claude checks, Brian acts only if needed)

```bash
fab api "workspaces/7836042d-adb1-4846-b70d-bd42980054c5/items?type=DataPipeline"
```
Expect both descriptions to still end `claimed:2026-10-21T15:03Z` (or later). If either shows `claimed:no`, the claim task claims it within 15 minutes. If the PC task isn't running, Brian runs `python deploy/claim_prod_pipeline.py` in FWD **before Step 7**. Otherwise the new dataflows fail with `SPNBasedRefreshNotAllowed`.

### Step 6: Fast-forward dev (Claude)

In FWD:
```bash
git fetch origin && git merge --ff-only origin/main && git push origin dev
```
Expect a fast-forward to the merge commit. This keeps the claim task's working copy matching `main`.

Confirm the 5 items exist in Prod:
```bash
fab api "workspaces/189e5c0a-548a-4feb-93d6-dda9ebbe96c1/items"
fab api "workspaces/7836042d-adb1-4846-b70d-bd42980054c5/items"
```
Expect `df_NonJD_PartSettings_Raw`, `df_NonJD_OrderRules_Raw`, `Build_Silver_PartSalesHistory` and `Build_Silver_PartStockingRules` in Staging, and `Build_Gold_NonJD_Reorder` in Presentation.

### Step 7: Build the new staging tables in Prod (Claude starts, with Brian's OK)

Run Prod `Pipeline_DP_Refresh` with `mode=items`. Either:
- **in the UI** (Brian): DP - Presentation - Prod → Pipeline_DP_Refresh → Run, with `mode` = `items` and `items` = `df_NonJD_PartSettings_Raw,df_NonJD_OrderRules_Raw,Build_Silver_PartSalesHistory,Build_Silver_PartStockingRules`; or
- **with the API** (as Brian's `fab` login): write `run_body.json` in the scratchpad:
  ```json
  {"executionData": {"parameters": {"mode": "items", "items": "df_NonJD_PartSettings_Raw,df_NonJD_OrderRules_Raw,Build_Silver_PartSalesHistory,Build_Silver_PartStockingRules", "reason": "Non-JD order tool Prod release: first staging build"}}}
  ```
  ```bash
  fab api -X post "workspaces/7836042d-adb1-4846-b70d-bd42980054c5/items/1fa19eb8-7d5f-465e-b7e7-b31e02e56a2c/jobs/instances?jobType=Pipeline" -i run_body.json
  ```
  Expect HTTP 202.

Wait for the summary email, or run `python tools/dp-migration/dp_refresh_status.py prod`. Expect "OK", `mode=items`, and all 4 items Succeeded. In Dev each took about 75–100 s; the model-refresh step that follows takes about 10 minutes.

Check the tables (DuckDB on Prod DP_Staging, `6713bd45-…`):
- `Silver_PartSalesHistory` and `Silver_PartStockingRules` have row counts close to Dev's.
- `NonJD_OrderRules` has the same rows as the SharePoint list (4 rules today: Default, Cotton in, Cotton off, Test).
- `NonJD_PartSettings` has the list's rows, including the test row 1/BS/09-1785273.

**If a dataflow fails:**
- **Credentials or connection error:** Brian opens it in DP - Staging - Prod and binds the SharePoint source to the existing connection (the one `df_ServiceTimeSheets_Raw` uses). Save, then re-run Step 7.
- **`SPNBasedRefreshNotAllowed`:** go back to Step 5.

### Step 8: Create the 4 shortcuts (Claude, with Brian's OK)

In FWD:
```bash
python deploy/sync_shortcuts.py          # dry run: 4 to create
python deploy/sync_shortcuts.py --apply
python deploy/sync_shortcuts.py          # again: 37 wanted, 37 exist, 0 to create
```
If one fails with "Target path doesn't exist", its staging table wasn't built: check Step 7 for that item, re-run it, then apply again.

> **Option B** (decision 2) stops here for the day. The next 06:15 run builds Gold, then continue at Step 10.

### Step 9: First Prod Gold (Claude starts, with Brian's OK)

Same as Step 7 with `items` = `Build_Gold_NonJD_Reorder` (reason "Non-JD order tool Prod release: first Gold"). In Dev it took 2.5–4.5 minutes, plus the model-refresh step.

Expect Succeeded in `dp_refresh_status.py prod`. A `WARN: … rule(s) skipped as invalid` line means a rule in the list is invalid. It still counts as succeeded; fix the rule in SharePoint.

### Step 10: Confirm the run is logged (Claude)

`dp_refresh_status.py prod` shows the run. The publish needs a `Build_Gold_NonJD_Reorder` item row with status Succeeded in Prod `dp_refresh_log`, and `Fact_NonJD_Reorder.BuiltAtUtc` between the run's start and that row's end. Step 12's dry decision prints this.

### Step 11: Check Prod Gold (Claude)

In DPJ:
```bash
python tools/dp-migration/nonjd_reorder_check.py --tier prod
```
Expect **PASS** with 0 differences, a part count near Dev's 199,555, and "all active rules valid". Record the totals by status and the total suggested value. Check the test part 1/BS/09-1785273: it should show MinOverride 5.

If it FAILS, stop: don't switch the publish (see Rollback R1).

### Step 12: Dry decision against Prod (Claude, on Brian's PC, uploads nothing)

This runs the publish's own guard against Prod without uploading anything: only the decision and the column check, not `run_publish.py`.
- Brian's PC `.env` has the SPN's `CLIENT_SECRET`, so `extract.connect()` reads as the SPN. That also proves the SPN can read the Prod tables and shortcuts.
- `config.py` loads `.env` with `override=True` at import, so set `config.SOURCE` **after** the import. `extract` reads it on every call through `config.table_path`.

A scratchpad script:
```python
import sys
sys.path.insert(0, r"C:\Users\bfox\Documents\Git-Projects\data-projects\projects\part order tool - app\publish")
import config, extract, publish_logic as pl
config.SOURCE = "prod"
con = extract.connect()
rows = extract.log_rows(con); latest = pl.latest_item_run(rows)
print("latest:", latest)
extract.check_columns(con)
built = extract.built_at(con); start = pl.run_start(rows, latest["run_id"])
print("built in run:", pl.built_in_run(built, start, latest["end_utc"]), built, start, latest["end_utc"])
```
Expect `status Succeeded`, no missing columns, and `built in run: True`. A permissions error here means the SPN can't read Prod. In that case Brian checks that it's Viewer on DP - Presentation - Prod, and has read on DP - Staging - Prod for the shortcuts.

### Step 13: Switch the publish to Prod (Brian, on the Gateway PC SPI00T4022W11)

1. Open `…\data-projects\projects\part order tool - app\publish\.env` and change `NONJD_SOURCE=dev` to `NONJD_SOURCE=prod`. Nothing else changes: same SPN, site and drive.
2. Run it once by hand from the publish folder: `.venv\Scripts\python.exe run_publish.py`.
   - Expect `publish start, source=prod`, then `decision: True (new data)` (the source changed, so the old state doesn't match).
   - Then `uploading 42 file(s)` (41 data files + `_meta.json`, as in C10; the count follows the included branches) and `done: … data as of <Prod Gold end_utc>`.
   - **No `--force` is needed.** The source change already re-sends every file.
3. Run it again. Expect `decision: False (already published)`.
4. Decision 3: on Brian's PC, either set the same `NONJD_SOURCE=prod` in its `.env` or stop running the publish there.

The scheduled task (07:15 weekdays, every 30 minutes for 3 hours) needs no change. From tomorrow it publishes each morning after Prod's run, about 06:55.

### Step 14: Verify (Claude checks, Brian looks at the app)

- **Graph, as the SPN:** `_meta.json` has `"source": "prod"`, `contractVersion` 2, `dataAsOf` equal to the Prod Gold item's `end_utc`, and the included branches (5 branches excluded per D6). Every data file is newer than the switch.
- **App (Brian):**
  - The Home page date is today's Prod time.
  - Branch 1's Home totals equal Prod Gold for Branch 1: a DuckDB sum of `EstOrderValue` where Status is in OutOfStock/Reorder, excluding MinimumNoDemand lines while the switch is off.
  - The test part 1/BS/09-1785273 shows the override.
  - The Rules page shows the 4 rules.
- **Next morning:** in the 06:15 Prod email, the 5 new items Succeeded, and the total time is still about 40 minutes. The Gateway PC log (`publish.log`) shows the 07:15 run with `source=prod`, `new data`, then `already published` on the repeats.

### Step 15: compare_tiers (Claude; optional, decision 4)

After a scheduled Prod run (06:15–06:55), and before any JD run, start Dev `Pipeline_DP_Refresh` (`4e73d626-…`) with `mode=items` and the whole chain:
```
items = df_NonJD_PartSettings_Raw,df_NonJD_OrderRules_Raw,Build_Silver_PartSalesHistory,Build_Silver_PartStockingRules,Build_Silver_PartInformation,Build_Silver_InMaster,Build_Silver_InSalOrd,Build_Silver_InSalPar,Build_Gold_OutstandingTransfers,Build_Gold_NonJD_Reorder
```
Then:
```bash
cd FWD && python deploy/compare_tiers.py Fact_NonJD_SalesHistory Fact_NonJD_Reorder
cd DPJ && python tools/dp-migration/nonjd_reorder_check.py --tier prod --fingerprint-only
python tools/dp-migration/nonjd_reorder_check.py --tier dev --fingerprint-only
```
Expect:
- `Fact_NonJD_SalesHistory` OK.
- `Fact_NonJD_Reorder` **DIFF on every row** in compare_tiers. That's expected (BuiltAtUtc), so ignore it.
- The two fingerprints are **identical** (same row count and hash).

A fingerprint difference has three possible causes:
- someone edited a SharePoint setting or rule between the two runs;
- a JD load ran in between;
- a real nondeterminism bug (dp-notebook-rules).

Only the last needs a fix. Find it with a DuckDB `EXCEPT ALL` excluding `BuiltAtUtc`.

### Step 16: Record it (Claude)

- **Plan A:** add a progress line to Task 15 (done, with the PR number, deploy run ID, Prod part count and check result), and note that Steps 3–4 were replaced by this runbook.
- **Plan C:** add a progress line saying the Prod release is done.
- **Memory file:** update `project_nonjd_parts_order_tool_paused.md` (source=prod; Dev now only for development).
- **`publish/README.md`:** change "NONJD_SOURCE (default dev)" to note that production is `prod`.
- Commit to `dev` in data-projects.

---

## 5. Risks and rollback

**What a Prod failure can and can't touch:**
- No report, model, flow or other DP item reads the new tables (TABLE-LINEAGE: no readers). The only new dependency is `Build_Gold_NonJD_Reorder` on existing items, and that's read-only.
- A failure in any of the 5 new items only skips that item and its downstream, which is just Gold. The other 94 items and the 27 models carry on.
- The email shows the failed item, and `rerun_failed` or catch-up can repeat it.
- No user-facing report changes.

**R1: Prod Gold fails or the check fails on day one.**
- The publish refuses on its own:
  - a failed latest run gives `latest … run ended Failed; keeping the old files` (exit 0);
  - a run whose BuiltAtUtc is outside the run, or with missing columns, gives exit 1.
- So the app keeps its last good files, and shows their date and the "older than one business day" flag.
- If the switch (Step 13) hasn't happened yet, the app stays on Dev data. Fix the item in Dev, then release again.
- If it has happened, go to R2 when the problem won't be fixed the same day.

**R2: Put the publish back on Dev (Brian, Gateway PC, 2 minutes).**
1. Set `NONJD_SOURCE=dev` in `.env`.
2. Run `run_publish.py`. The source changed, so it re-sends every file from Dev's latest logged Gold run. That's C10's run (2026-10-26), which the 14-day look-back covers until about 2026-11-09. After that, first run Dev `Pipeline_DP_Refresh` `mode=items` with `items=Build_Gold_NonJD_Reorder` (or the whole chain from Step 15). A `run_item.py` run isn't logged and won't publish.
3. Switching back to `prod` later is the same: one by-hand run, everything re-sent.

**R3: Stop the new items running in Prod.**
- Not needed for safety (they're isolated). If the failure emails are a nuisance, set the 5 items to `"cadence": "manual"` in `dp_refresh_dag.json` on `dev`, then PR and deploy.
- **Don't delete any Prod items or shortcuts without Brian's explicit OK.** Leaving them in place costs nothing.

**R4: Dataflows fail with `SPNBasedRefreshNotAllowed` or a credentials error.** Claim (Step 5), or bind the connection (Step 7 note), then `mode=rerun_failed`. The claim task does the re-run itself if it did the claim.

**Smaller risks:**
- **Daytime model refresh:** `items` runs refresh all 27 Prod models during the day (about 10 minutes of F8 load per run). They show the same data. Avoid running during Shannon's busiest hour if that matters.
- **Run time:** the 06:15 run may get a few minutes longer. If it ever ends after about 10:00, the publish's 3-hour retry window (07:15–10:15) misses that day; run `run_publish.py` by hand.
- **Two publishers:** Brian's PC with `source=dev` would overwrite the Prod files (decision 3).
- **Shared lists:** both tiers read the same SharePoint lists. Edits made in the app reach Prod Gold at the next 06:15, as they reached Dev before.
