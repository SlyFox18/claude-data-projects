# JD Price Updates

Ingests John Deere `PRICEUPDATE_*.TXT` branch price-change files from a
network folder into `LH_Master_Data.Raw_PriceUpdate_History`.

**Design spec:** `docs/superpowers/specs/2026-08-06-jd-price-update-ingestion-design.md`
**Implementation plan:** `docs/superpowers/plans/2026-08-06-jd-price-update-ingestion.md`

Status: **live and operating.** Full historical backfill complete
(2026-08-07) — 4,592 files, 2008-08-25 through 2026-08-03,
5,096,264 rows. Daily scheduled harvest running unattended since
2026-08-07.

## Architecture

```
Network share (Price_Update folder — real path known to Brian, passed as
                -SourceFolderPath at runtime, never hardcoded in this repo)
        │  [Harvest-PriceUpdateFiles.ps1, Windows Scheduled Task
        │   "JD Price Update Harvest" \Fabric\, daily 02:00, this machine]
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

## Scripts

| Script | Purpose |
|---|---|
| `scripts/Inventory-PriceUpdateFolder.ps1` | One-off: counts files, finds oldest/newest date, total size in the source folder. |
| `scripts/Compare-PriceUpdateSchema.ps1` | One-off: compares the header row of two or more files to check for column drift across years. |
| `scripts/Harvest-PriceUpdateFiles.ps1` | Daily scheduled: copies new files into the OneLake landing area, validates filename + header, quarantines anything that fails. |
| `scripts/Register-HarvestPriceUpdateTask.ps1` | One-off setup: registers the daily Windows Scheduled Task for the harvest script. |

## Fabric objects (LH_Master_Data workspace)

- **Dataflow Gen2:** `df_Raw_PriceUpdate_History` — reads
  `Files/PriceUpdate_Landing/New`, parses filename + tab-delimited content,
  writes to the `Raw_PriceUpdate_History` table with **Update method:
  Append**. Reference M code (kept in sync manually — see note below):
  `.claude/queries/raw-tables/Raw_PriceUpdate_History.pq`.
- **Pipeline:** `pl_Raw_PriceUpdate_History` — Dataflow activity → (on
  success) Delete data activity clearing `New/*.TXT` (non-recursive).
- **Scheduled task:** `\Fabric\JD Price Update Harvest`, daily at 02:00,
  runs `Harvest-PriceUpdateFiles.ps1` on Brian's machine.

**Important — the `.pq` file in this repo is a reference copy, not a live
sync.** `data-projects` is not Fabric-integrated (see root `CLAUDE.md`).
When the M code is edited directly in the Fabric Dataflow Gen2 Advanced
Editor, the change must be manually copied back into
`Raw_PriceUpdate_History.pq` (or vice versa) — nothing keeps them in sync
automatically.

## Known data realities (confirmed against real files — read before debugging)

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

## Operational gotchas (found the hard way during setup — 2026-08-07)

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
- **`Archive/` tracks "have we ever harvested this file," not "is this
  file's data currently in the table."** If `New/` is ever cleared without
  a file's data having actually landed in a *successful* table write
  (e.g., an early test batch got cleared by a Delete-activity bug fix
  verification run before its data was reloaded), the harvest script's
  idempotency will skip re-copying it from the source share, since it's
  already in `Archive/`. Recovery: copy the specific file(s) directly from
  `Archive/` back into `New/` and re-run the pipeline in Append mode.

## Residual risks (documented, not fixed — deliberate)

- Harvest script's exit code is always `0` unless a setup-level failure
  occurs (missing landing folders, unreachable source) — a run with
  per-file errors still reports success at the process level; only the
  log file shows `Errors: N > 0`. Worth a decision before this matters
  operationally (e.g. if per-file failures start happening regularly).
- No `-WakeToRun` on the scheduled task. If the machine is asleep before
  02:00, the run is delayed to next wake, not skipped, but could land
  after downstream consumers expect fresh data.
- Source-file atomic-write assumption is unverified — unknown whether
  JD's export process could ever be caught mid-write by the 02:00
  schedule.
- A malformed `Branch` value with zero digits after stripping the
  sub-branch letter (i.e., entirely non-numeric) would become `null`
  without setting `HasTypeConversionIssue` — not observed in any real
  file to date.

## Next Steps

Per the design spec, this is sub-project 1 of a three-part effort:

1. **This project — done.** Raw ingestion of the parts we sell.
2. **JD website Change Report collection** (not started) — JD's Global
   Parts Pricing portal publishes weekly Change Reports covering *all*
   Deere parts, not just ones sold here; 2FA-gated, only 4 reports
   retained online at a time. Likely a smaller, more exploratory spec,
   possibly partly manual.
3. **Analysis layer** (not started) — margin-impact analysis (did a price
   change erode margin?) and slicing price changes by `dim_Parts`
   classifications (SLC, DealerGroupCode, CommodityCode). Depends on this
   project's data (done) and optionally #2. Remember: join/group on
   `PartNumber + EffectiveDate`, not `Branch + PartNumber + EffectiveDate`.
