# JD Price Updates

Two related, independently-built ingestion pipelines covering John Deere
parts pricing data — see **Next Steps** at the bottom for how they and a
planned third (analysis) piece fit together.

## Sub-project 1: Branch Price Updates

Ingests John Deere `PRICEUPDATE_*.TXT` branch price-change files from a
network folder into `LH_Master_Data.Raw_PriceUpdate_History`.

**Design spec:** `docs/superpowers/specs/2026-08-06-jd-price-update-ingestion-design.md`
**Implementation plan:** `docs/superpowers/plans/2026-08-06-jd-price-update-ingestion.md`

Status: **live and operating** — with a second caveat now on top of the
first: the daily harvest has silently failed *twice*. First for 13 days
(2026-08-07 to 2026-08-20, a script bug, see Operational gotchas below),
then for 11 more days (2026-08-22 to 2026-09-01, an early-morning
session-availability issue — see the `TriggerTime` note below and in
`Register-HarvestPriceUpdateTask.ps1`). Full historical backfill complete
(2026-08-07) — 4,592 files, 2008-08-25 through 2026-08-03. Gap 1 backfilled
2026-08-20 (42 files). Gap 2 backfilled 2026-09-01 (51 files, 2026-08-23/
08-30/08-31). Current state: 4,685 files, latest `SourceFileDate`
2026-08-31. **Scheduled task moved from 02:00 to 13:00 on 2026-09-01** —
this report isn't on the Tier 1-3 automated pipeline schedule (refreshed
manually in Desktop) and the harvest step has zero Fabric CU cost
regardless of time of day, so there was never a real reason to run it
before dawn; 1 PM lands inside hours this machine has already proven
reliable for unattended tasks. Not yet confirmed clean on a real
unattended 1 PM run.

### Architecture

```
Network share (Price_Update folder — real path known to Brian, passed as
                -SourceFolderPath at runtime, never hardcoded in this repo)
        │  [Harvest-PriceUpdateFiles.ps1, Windows Scheduled Task
        │   "JD Price Update Harvest" \Fabric\, daily 13:00, this machine]
        ▼
OneLake Files/PriceUpdate_Landing/
   ├── New/        (cleared after each successful pipeline run)
   ├── Archive/    (permanent copy of every file ever harvested)
   └── Quarantine/ (files that fail filename or header validation)
        │  [Fabric Pipeline pl_Raw_PriceUpdate_History, LH_Master_Data workspace]
        │  1. Dataflow df_Raw_PriceUpdate_History (Append) — parses New/,
        │     appends to the raw table
        │  2. On success only: Delete data activity clears New/
        ▼
LH_Master_Data: Raw_PriceUpdate_History (5.1M rows)
```

### Scripts

| Script | Purpose |
|---|---|
| `scripts/Inventory-PriceUpdateFolder.ps1` | One-off: counts files, finds oldest/newest date, total size in the source folder. |
| `scripts/Compare-PriceUpdateSchema.ps1` | One-off: compares the header row of two or more files to check for column drift across years. |
| `scripts/Harvest-PriceUpdateFiles.ps1` | Daily scheduled: copies new files into the OneLake landing area, validates filename + header, quarantines anything that fails. |
| `scripts/Register-HarvestPriceUpdateTask.ps1` | One-off setup: registers the daily Windows Scheduled Task for the harvest script. |

### Fabric objects (LH_Master_Data workspace)

- **Dataflow Gen2:** `df_Raw_PriceUpdate_History` — reads
  `Files/PriceUpdate_Landing/New`, parses filename + tab-delimited content,
  writes to the `Raw_PriceUpdate_History` table with **Update method:
  Append**. Reference M code (kept in sync manually — see note below):
  `.claude/queries/raw-tables/Raw_PriceUpdate_History.pq`.
- **Pipeline:** `pl_Raw_PriceUpdate_History` — Dataflow activity → (on
  success) Delete data activity clearing `New/*.TXT` (non-recursive).
- **Scheduled task:** `\Fabric\JD Price Update Harvest`, daily at 13:00
  (moved from 02:00 2026-09-01 — see Status above), runs
  `Harvest-PriceUpdateFiles.ps1` on Brian's machine.

**Important — the `.pq` file in this repo is a reference copy, not a live
sync.** `data-projects` is not Fabric-integrated (see root `CLAUDE.md`).
When the M code is edited directly in the Fabric Dataflow Gen2 Advanced
Editor, the change must be manually copied back into
`Raw_PriceUpdate_History.pq` (or vice versa) — nothing keeps them in sync
automatically.

### Known data realities (confirmed against real files — read before debugging)

- **Sub-branch codes roll up to the main branch.** Filenames/rows
  sometimes carry a trailing letter (`11S`, `93C`, `4B` — a physical
  branch's Service/Bulk/Inside-sales sub-location). Per Brian, these are
  not analytically meaningful on their own: `Branch` in the raw table is
  always the rolled-up main branch number; `SourceFileBranch` preserves
  the full raw code for traceability. ~6% of all files use this shape.
- **Two confirmed historical header shapes.** Files before some point
  between Jan 2018 and Feb 2020 have 19 columns (missing `sell_price_old`);
  everything since has 20. The harvest script accepts both; the M query
  degrades a missing `sell_price_old` to `null` via `MissingField.UseNull`.
- **JD's export has a real, recurring row-shift defect.** Some rows are
  missing 6 consecutive tab-delimited fields entirely (not left blank),
  shifting every field after that point left by 6 positions — e.g. a
  row's real `EffectiveDate` value ends up in what should be
  `DealerReplacePrice`. Confirmed across 800+ rows, multiple files,
  2022-2026. One instance of this crashed an entire table write with an
  Int64 overflow before it was caught and fixed (2026-08-07). Every
  numeric/date/Int64 conversion in the M query now uses `try/otherwise`,
  degrading just the affected fields to `null` per row instead of failing
  the batch, and setting `HasTypeConversionIssue = true` on that row so
  it's identifiable later. Query `Raw_PriceUpdate_History` filtered on
  that flag to find them.
- **`EffectiveDate` can be much older than the file's own date.** It means
  "when this price took effect," not "when this file was generated." A
  part whose price hasn't changed since 2008 will show `EffectiveDate =
  2008-08-25` in a file generated in 2019 — confirmed, not corruption.
  The table's real `MinDate` is 2008-08-25 for exactly this reason.
- **Branch does not affect pricing values, only assortment.** The same
  part's price change on a given day is identical across every branch
  that carries it. Branch-files exist because assortment varies by
  branch. The natural key for future price-trend/margin analysis is
  `PartNumber + EffectiveDate`, not `Branch + PartNumber + EffectiveDate`.

### Operational gotchas (found the hard way during setup — 2026-08-07)

- **The local OneLake File Explorer mount lags the real backend state,
  in both directions** — it has shown folders as both falsely empty and
  falsely full relative to what the Fabric portal (or the SQL analytics
  endpoint) confirms is actually true. Restarting the
  `Microsoft.OneLake.FileExplorer.App` process does not reliably fix it.
  **Always verify folder contents via the Fabric portal's Files browser,
  not the local mounted drive, when the two disagree.**
- **The Fabric Pipeline's "Delete data" activity silently no-ops if
  configured with File path type = "File path" instead of "Wildcard file
  path".** A `*.TXT` filter under "File path" mode gets treated as a
  literal filename (with a stray `^` prepended) rather than a wildcard —
  the activity reports "Succeeded" with `filesDeleted: 0` and no visible
  error. Check the activity's actual run output JSON, not just the green
  checkmark, if `New/` isn't clearing as expected.
- **The SQL analytics endpoint's schema cache can lag well behind the
  real Delta table** after a column is added (e.g. `HasTypeConversionIssue`
  took over an hour to become queryable, and a manual "Refresh" didn't
  help). Use the Lakehouse's own Tables data preview if you need to see a
  new column immediately.
- **`$PSScriptRoot` inside a parameter's default-value expression silently
  broke the daily harvest for 13 days (2026-08-07 to 2026-08-20), with zero
  log output the entire time.** `Harvest-PriceUpdateFiles.ps1` originally
  defaulted `-LogPath` to `(Join-Path $PSScriptRoot ...)` directly in the
  `param()` block. Under Task Scheduler's `-File "full\path"` invocation,
  `$PSScriptRoot` is empty during parameter-default evaluation, so
  `Join-Path` threw before the script body (and its own logging) ever ran —
  no log file, no error visible anywhere except a bare exit code 1 in Task
  Scheduler. This is the exact same bug already documented and fixed in
  sub-project 2's `Send-JDChangeReportReminder.ps1` below, but it was never
  backported here. **Fixed 2026-08-20**: `LogPath` now has no param default;
  it's computed in the script body instead, and was verified with the exact
  `-File` invocation style Task Scheduler uses. **Why this went undetected
  for 13 days:** the Fabric pipeline's own refresh history showed "Succeeded"
  every single day, because it succeeds trivially on an empty `New/` — there
  is currently no check anywhere that new data actually landed, only that
  the job didn't error. See the freshness-check item in Residual risks below.
- **The 2:00 AM trigger time itself was the second, separate cause of a
  silent outage — 11 more days (2026-08-22 to 2026-09-01), right after the
  first outage above was fixed.** `Harvest-PriceUpdateFiles.ps1` uses
  `LogonType = Interactive`, which requires an actively logged-in user
  session to reliably reach network resources — this was flagged as a
  documented risk in `Register-HarvestPriceUpdateTask.ps1`'s own original
  header comment, and it materialized: every run failed with `Cannot find
  path '...\Price_Update' because it does not exist`, even though the
  share was fully reachable moments later during business hours. Confirmed
  it wasn't a general `LogonType=Interactive` problem in this environment —
  two other scheduled tasks on the same machine (`Post-Pipeline Monitoring`,
  `Azure Login Refresh`) use the identical logon type and run successfully
  every day at 7-8 AM. The variable was specifically the early-morning
  timing, not the logon configuration. **Fixed 2026-09-01**: moved the
  trigger to 13:00 (1 PM) — this report isn't on the Tier 1-3 automated
  pipeline schedule and the harvest step costs zero Fabric CU regardless of
  time of day, so there was never a real reason to run it before dawn.
  **Lesson for any future unattended task on this machine**: before
  trusting an early-morning trigger time, check whether other tasks using
  the same logon type already run successfully at that hour — if nothing
  does, don't assume a new one will.
- **`Archive/` tracks "have we ever harvested this file," not "is this
  file's data currently in the table."** If `New/` is ever cleared without
  a file's data having actually landed in a *successful* table write
  (e.g., an early test batch got cleared by a Delete-activity bug fix
  verification run before its data was reloaded), the harvest script's
  idempotency will skip re-copying it from the source share, since it's
  already in `Archive/`. Recovery: copy the specific file(s) directly from
  `Archive/` back into `New/` and re-run the pipeline in Append mode.

### Residual risks (documented, not fixed — deliberate)

- Harvest script's exit code is always `0` unless a setup-level failure
  occurs (missing landing folders, unreachable source) — a run with
  per-file errors still reports success at the process level; only the
  log file shows `Errors: N > 0`. Worth a decision before this matters
  operationally (e.g. if per-file failures start happening regularly).
- No `-WakeToRun` on the scheduled task. If the machine is asleep before
  13:00, the run is delayed to next wake, not skipped, but could land
  after downstream consumers expect fresh data.
- Source-file atomic-write assumption is unverified — unknown whether
  JD's export process could ever be caught mid-write by the 13:00
  schedule.
- A malformed `Branch` value with zero digits after stripping the
  sub-branch letter (i.e., entirely non-numeric) would become `null`
  without setting `HasTypeConversionIssue` — not observed in any real
  file to date.
- **No freshness/gap check.** Nothing verifies day-over-day that
  `Raw_PriceUpdate_History` actually received new rows — only that
  `pl_Raw_PriceUpdate_History` didn't error, which (as the 13-day gap above
  demonstrated) succeeds trivially even when nothing new arrived. Worth a
  cheap addition — e.g. hook into the existing `fabric-monitoring` freshness
  scripts, or a small standalone check on `MAX(IngestedAt)` — not yet built.

## Sub-project 2: JD National Change Report

Ingests JD's national weekly "Change Report" CSVs — covering *all* Deere
parts, not just ones sold here — from a 2FA-gated web portal into
`LH_Master_Data.Raw_JDNationalChangeReport_History`, plus a weekly
reminder (Reynard todo + Outlook email) since 2FA blocks any further
automation of the actual download.

**Design spec:** `docs/superpowers/specs/2026-08-07-jd-change-report-ingestion-design.md`
**Implementation plan:** `docs/superpowers/plans/2026-08-07-jd-change-report-ingestion.md`

Status: **live, but the Fabric pipeline has no recurring schedule** (see
Residual risks below) — it only ever runs when manually triggered. Full
historical backfill complete (2026-08-10) — 5 files, 2026-07-13 through
2026-08-10, 48,453 rows. Weekly reminder scheduled task confirmed firing
correctly (last 2026-08-15, next 2026-08-22). Current state (after a
manual trigger 2026-08-20 caught up a file that had been sitting
downloaded-but-unloaded since the 15th): 6 files, 49,331 rows, latest
`SourceFileDate` 2026-08-17.

### Architecture

```
pricednld.deere.com (2FA via SMS -- manual download only, no automation)
        │  [Brian downloads weekly Change Report CSV by hand, copies into
        │   BOTH New/ and Archive/ -- no harvest script for this source]
        ▼
OneLake Files/JDChangeReports_Landing/
   ├── New/        (cleared after each successful pipeline run)
   └── Archive/    (permanent copy of every file ever downloaded --
                     no Quarantine/ here; nothing sorts rejects into one,
                     since there's no harvest script to do the sorting)
        │  [Fabric Pipeline pl_Raw_JDNationalChangeReport_History,
        │   LH_Master_Data workspace]
        │  1. Dataflow df_Raw_JDNationalChangeReport_History (Append) —
        │     parses New/, appends to the raw table
        │  2. On success only: Delete data activity clears New/
        ▼
LH_Master_Data: Raw_JDNationalChangeReport_History (48.5K rows)

Separately, weekly reminder (no data flow -- pure notification):
Windows Scheduled Task "\Fabric\JD Change Report Reminder", Saturdays 10:00
        │  [Send-JDChangeReportReminder.ps1]
        ├──▶ Reynard todo item (http://localhost:5151/capture)
        └──▶ Outlook COM email
```

### Scripts

| Script | Purpose |
|---|---|
| `scripts/Send-JDChangeReportReminder.ps1` | Weekly scheduled: posts a Reynard todo item and sends an Outlook email reminding Brian to download and place the week's file. Does nothing automated about the download itself. |
| `scripts/Register-JDChangeReportReminderTask.ps1` | One-off setup: registers the weekly Windows Scheduled Task for the reminder script. |

### Fabric objects (LH_Master_Data workspace)

- **Dataflow Gen2:** `df_Raw_JDNationalChangeReport_History` — reads
  `Files/JDChangeReports_Landing/New`, parses filename + comma-delimited
  content, writes to the `Raw_JDNationalChangeReport_History` table with
  **Update method: Append**. Reference M code (kept in sync manually —
  same caveat as sub-project 1 above):
  `.claude/queries/raw-tables/Raw_JDNationalChangeReport_History.pq`.
- **Pipeline:** `pl_Raw_JDNationalChangeReport_History` — Dataflow
  activity → (on success) Delete data activity clearing
  `New/*.csv` (Wildcard file path mode — set correctly from the start
  this time, having learned that lesson the hard way in sub-project 1).
- **Scheduled task:** `\Fabric\JD Change Report Reminder`, weekly
  Saturdays at 10:00, runs `Send-JDChangeReportReminder.ps1` on Brian's
  machine. Requires `LogonType Interactive` (Outlook COM and the Reynard
  HTTP call both need the interactive session's resources) — if this
  machine is regularly logged off on Saturdays, the reminder won't fire
  until next login.

### Known data realities (confirmed against real files — read before debugging)

- **`EffectiveDate` mostly, but not always, matches the filename's date.**
  Confirmed against the full 48,453-row backfill: 21 rows (~0.04%) had
  `EffectiveDate` 1-9 days *before* the filename's date, spread
  proportionally across all 5 files, never the reverse, never off by more
  than 9 days. Read as the weekly report occasionally listing a change
  that took effect a few days before publication — not a parsing defect.
  `FileNameDateMismatchFlag` is a tripwire for this: expect it to fire
  occasionally at low volume with a small gap; a large gap or a volume
  spike would mean a real problem instead.
- **A small number of rows have genuinely malformed (not just blank)
  price/date fields.** 5 of 48,453 rows in the initial backfill had
  `HasTypeConversionIssue = true` — confirmed by inspection to be
  non-blank source text that failed to parse, correctly degraded to
  `null` rather than corrupting the whole load.
- **Some parts carry `CurrentSLP`/`NewSLP` = 0, not null**, e.g. the
  `SWDEF*` part family — read as a legitimate "no suggested list price"
  business case for that part class, not a data quality issue.
- **No Quarantine/ folder for this pipeline, unlike sub-project 1.**
  There's no harvest script to sort rejects into one — a malformed
  filename (wrong pattern, browser duplicate-download suffix) is
  silently dropped by the M query's own filters with zero error signal
  anywhere. The weekly reminder email/Reynard text is the only
  human-facing defense against this; see Residual risks below.

### Operational gotchas (found the hard way during setup — 2026-08-10)

- **A header row can be padded with trailing whitespace on its last
  column, breaking an exact-match column selection even though every
  other column parses fine.** `EFFECTIVE DATE` is the last column in
  this file's header; because the source rows are padded to a fixed
  record length (see the `.pq` file's own header comment), the raw
  header cell came through as `"EFFECTIVE DATE"` plus trailing spaces,
  which didn't exact-match `ExpectedSourceColumns`, so
  `MissingField.UseNull` silently substituted an all-null column in its
  place — 100% empty, zero error, across every file including ones
  already "confirmed" during initial schema review. Fixed by wrapping
  the post-`Table.PromoteHeaders` step in
  `Table.TransformColumnNames(_, Text.Trim)`. **Lesson: trim column
  *names*, not just column *values*, when a source format is known to
  pad fixed-length records — the header row is padded too.**
- **`$PSScriptRoot` can evaluate to an empty string during a parameter's
  default-value expression**, specifically when a script is launched as
  a brand-new process via `powershell.exe -File "C:\full\path\..."` —
  exactly how Windows Task Scheduler invokes scripts. It resolves fine
  once the script *body* starts executing, and it also resolves fine
  under the more common manual-testing invocation style
  (`.\script.ps1` from an already-open console in the script's own
  folder) — which is exactly why this shipped past an implementer, a
  spec reviewer, a code-quality reviewer, and several manual test runs
  undetected: every one of them happened to use the invocation style
  that masks the bug. It only surfaced on the first real Scheduled Task
  run, as a `Join-Path : Cannot bind argument to parameter 'Path'
  because it is an empty string` parameter-binding-time error — before
  a single line of the script's own body ever executed, so there was no
  log file, no Reynard item, no email, and no diagnostic trail beyond
  Task Scheduler's own generic non-zero exit code. **Lesson: never
  reference `$PSScriptRoot` (or similar automatic variables) inside a
  parameter's default-value expression — compute it in the script body
  instead. And when testing a script meant to run under Task Scheduler,
  test it with the exact same `-File "full\path"` invocation Task
  Scheduler will actually use, not a `.\` shortcut.**
- **`New-ScheduledTaskTrigger -RepetitionDuration ([TimeSpan]::MaxValue)`
  exceeds what the Task Scheduler XML schema's `Duration` element
  actually accepts**, failing `Register-ScheduledTask` outright with
  *"The task XML contains a value which is incorrectly formatted or out
  of range."* (This surfaced while applying the companion Reynard
  reliability fix in the separate `personal-dashboard` repo, but is
  recorded here since it directly affects this pipeline's reminder
  dependency.) Per Microsoft's own `RepetitionPattern.Duration` docs,
  **omitting `-RepetitionDuration` entirely already means "repeat
  indefinitely"** — there's no need to pass a value at all, and doing so
  with an out-of-range one breaks registration completely.

### Residual risks (documented, not fixed — deliberate)

- **No recurring freshness/gap check.** Nothing verifies week-over-week
  that a new file actually landed and loaded — unlike sub-project 1's
  daily cadence (where a missed day is easy to backfill from the source
  share), a missed week here is materially higher stakes: JD's portal
  only retains the 4 most recent Change Reports, so a week missed for
  more than ~4 weeks becomes permanently unrecoverable. The weekly
  reminder (Reynard + email) is the only safeguard today.
- **`pl_Raw_JDNationalChangeReport_History` itself has no recurring
  schedule — confirmed 2026-08-20.** The implementation plan only ever
  says "run the pipeline manually once" (for backfill verification); no
  task gives it a recurring trigger. The weekly reminder tells Brian to
  download the file, but nothing tells him (or automates) actually running
  the pipeline afterward — confirmed as the reason the raw table sat at
  its 2026-08-10 state for 10 days despite the 2026-08-15 reminder firing
  and the file being manually copied into `New/`/`Archive/` on time.
  Recommended fix (not yet decided): give the pipeline its own recurring
  schedule (daily or weekly) so it no longer depends on anyone remembering
  a second manual step, mirroring sub-project 1's "safe to run against an
  empty `New/`" pattern.
- **The reminder is the sole human-facing defense against a silently
  malformed filename** (wrong pattern, browser duplicate-download
  suffix like `" (1).csv"`) — the reminder text explicitly calls out the
  exact expected filename and this risk, but there's no automated
  check that a given week's file actually parsed successfully; a
  mis-copied file would only show up as an unexpectedly low row count
  if someone happened to check.
- Source-file atomic-write / partial-download assumption is unverified,
  same as sub-project 1's equivalent risk.

## Next Steps

Per the design spec, this is a three-part effort:

1. **Sub-project 1 — done.** Raw ingestion of the parts we sell.
2. **Sub-project 2 — done.** JD website Change Report collection, all
   Deere parts nationally, weekly reminder-driven manual download.
3. **Analysis layer** (not started) — margin-impact analysis (did a price
   change erode margin?) and slicing price changes by `dim_Parts`
   classifications (SLC, DealerGroupCode, CommodityCode). Depends on
   sub-project 1's data (done) and optionally sub-project 2's (done).
   Remember: join/group on `PartNumber + EffectiveDate`, not
   `Branch + PartNumber + EffectiveDate` — true for both raw tables.
