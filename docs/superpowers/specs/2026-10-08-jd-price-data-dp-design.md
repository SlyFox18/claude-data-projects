# JD Price Data on the DP Backend: Design

**Date:** 2026-10-08
**Status:** Draft for Brian's review
**Replaces:** the LH_Master_Data price ingestion (`df_Raw_PriceUpdate_History`, `df_Raw_JDNationalChangeReport_History`, their two pipelines, the PC harvest task) and the empty `Fact_PriceUpdate_Enriched`.

## Goal

1. Move JD's two price feeds onto the DP medallion backend so LH_Master_Data can retire.
2. Fix the problems the current loading has.
3. Shape the data so the JD Price Updates report is easy to build. The report is local-only and unpublished, so it can change freely.

## What's wrong today (found 2026-10-08)

| Problem | Effect |
|---|---|
| The harvest runs on Brian's PC and copies through the OneLake File Explorer mount. | 3 silent outages so far (13 days, 11 days, and 1 day on 10/8). |
| Loading appends whatever is in `New/`, then deletes `New/`. | Price Update: 93 files loaded twice, 6,003 duplicate rows. Change Report: the 8/17 file is in the table 5 times, 8/24 4 times and 9/07 twice (about 4,650 duplicate rows). |
| `Archive/` and the table can disagree. | The 8/31 Change Report is in `Archive/` but not in the table. |
| The Change Report pipeline has no schedule. | It only loads when Brian remembers to run it. |
| `HasTypeConversionIssue` is calculated but missing from the dataflow's output column list. | The flag the README tells you to filter on doesn't exist in the table. |
| No freshness check. | Every outage was found by eye. |

Once the double loads are removed, the Price Update table has **no** repeated rows. JD's files are clean, so nothing needs collapsing.

## Sources

| Feed | Location | Cadence | History |
|---|---|---|---|
| Branch price updates `PRICEUPDATE_MM_DD_YYYY_<branch>.TXT` (tab-delimited) | `\\Eqsvc01-sp2010\equip\UWS\Poll\Daily_Reports\Price_Update` | Written by the source system each weekend (Sunday about 00:06) | 4,792 files on the share, back to 2016 |
| JD National Change Report `US.UPDCOMP.UPDATE.V2-YYYY-MM-DD.csv` | `\\Eqsvc01-sp2010\equip\UWS\Poll\Daily_Reports\JD_Change_Report` (created 2026-10-08) | Brian downloads it weekly from pricednld.deere.com (2FA) and saves it here | All 13 files 7/13–10/5 copied there 2026-10-08 (hash-verified) |

**The share is the system of record for both feeds,** like JD Bronze for the ODBC tables. Dev and Prod each pull from it on their own. No landing folder is shared between tiers, and no files are ever deleted.

The share also holds `PARTNOUPDATE_`, `PARTCONVERT_` and `SUBUPDATE_` files. They are out of scope here, but the same pattern would cover them later.

## Architecture

```
Network share (Price_Update, JD_Change_Report)
   │  SPI-Data-Gateway (server gateway; already hosts the Network_Folder connection)
   ▼
df_JDPriceFiles_Raw            Dataflow Gen2, DP - Staging - <tier>, daily
   │  Reads files only, no parsing: one row per text line
   ▼
Landing_PriceUpdate_Lines      Replace each run; only files from the last 35 days
Landing_JDChangeReport_Lines   Replace each run; all files (small)
   ▼
Build_Silver_JDPriceFiles      Notebook, DP_Staging, daily
   │  Parses and types; loads each file exactly once
   ▼
Silver_PriceUpdate_History, Silver_JDChangeReport_History
   │  Shortcuts into DP_Presentation
   ▼
Build_Gold_JDPriceChanges      Notebook, DP_Presentation, daily
   ▼
Fact_PartPriceChange, Fact_PartPriceChange_Branch, Fact_JDNationalPriceChange
   ▼
JD Price Updates report (local PBIP), joined to DP dim_Parts / dim_DateTable / dim_BranchLocation
```

### Why a dataflow only for the gateway step

- Notebooks can't reach an on-prem share. A Dataflow Gen2 can, through SPI-Data-Gateway.
- The orchestrator already runs Staging dataflows: `df_ServiceTimeSheets_Raw` and others run in both Dev and Prod.
- Keeping the dataflow to "file name, line number, line text" puts all the logic in Spark. That logic is testable, follows the DP notebook rules, and Git holds the parsing. The fragile parts of today's M (JD's row-shift defect, type conversions) move into code we control.
- Adding a "pipeline" item type to the orchestrator (a Copy activity) would also work. It needs orchestrator, config-validation and test changes for no gain.

### Loading each file exactly once (Silver)

For every file in the landing table, the notebook compares the landing row count with Silver's row count for that `SourceFileName`:
- **New file:** insert its rows.
- **Different count** (for example a file caught mid-write and later completed): replace that file's rows in one atomic `replaceWhere` write.
- **Same count:** skip.

Files older than the 35-day window stay in Silver untouched. Re-running a day, a missed day or a failed run can't duplicate anything, and the next run fills any gap.

**Backfill:** in Dev, the dataflow runs once with `LookbackDays = 100000`, then it goes back to 35. Prod gets its history through a one-off notebook that copies the two Silver tables from Dev, the same pattern as the 2026-10-02 snapshot copy. After that, Prod runs on its own.

### Parsing rules

**Price Update:**
- The header must be the known 20-column layout, or the legacy 19-column layout without `sell_price_old`.
  - Any other header **fails the notebook** with the file names. JD changing the format needs a person to look at it, and the daily email says which files.
- A row with a different number of fields from its header is JD's known row-shift defect.
  - It keeps Branch, Franchise and PartNumber, with every other field null, and `IsMalformedRow = true`.
  - Today's M query mis-maps these rows instead.
- Numbers use `try_cast`. Dates are `M/d/yyyy` through `try_to_timestamp`.
  - A non-blank value that fails to parse becomes null and sets `HasTypeConversionIssue = true`. This time the flag is actually written.
- `Branch` is the digits only, rolled up to the main branch (`11S` → 11). The raw filename branch is kept as `SourceFileBranch`.
- **Column meaning** (checked against a real file):
  - `Manufacturer*` = JD's incoming price.
  - `Dealer*` = our current system price.
  - `CostDiff` = ManufacturerReplacePrice − DealerReplacePrice, per unit. `ListDiff` and `SellPrice1Diff` work the same way.
  - Silver keeps today's column names so the report's measures carry over.

**Change Report:**
- Comma-delimited. Header cells are trimmed, because JD pads records to a fixed width.
- The header must be exactly `PART NUMBER, CURRENT DNP, CURRENT SLP, NEW DNP, NEW SLP, EFFECTIVE DATE`.
- `FileNameDateMismatchFlag` is kept as it is today.

### Gold tables

| Table | Grain | Rows (approx.) | Contents |
|---|---|---|---|
| `Fact_PartPriceChange` | PartNumber + EffectiveDate | 1.3M | JD list, cost (replace) and sell price; our prices at the time; change $ and %; `PriorEffectiveDate`, `DaysSincePriorChange` and prior JD list/cost (window function in Spark); `ChangeDirection` (Increase / Decrease / NoChange); `BranchCount`; `HasBranchPriceDisagreement`; `PartKey` for dim_Parts |
| `Fact_PartPriceChange_Branch` | Branch + PartNumber + EffectiveDate | 5.09M | OnHandQty, BinLocation, our prices at that branch, CostDiff, **`InventoryCostImpact = OnHandQty × CostDiff`** (value change of stock on hand), `BranchKey` |
| `Fact_JDNationalPriceChange` | PartNumber + EffectiveDate | ~55K, growing about 1K/week | Current and new DNP/SLP, change $ and %, `IsStockedPart` (part exists in dim_Parts) |

**Survivor rules** (decided, written into the notebook as comments):
- **Same part and effective date at several branches:**
  - JD's price is the **most common value across branches**, ties going to the lowest. This is the same rule dim_Parts uses.
  - It differs for only 1,961 of 1.29M changes, and `HasBranchPriceDisagreement` marks those.
  - Our prices in the company-wide fact are also the most common value; per-branch values live in the branch fact.
- **Same branch, part and effective date in several files:** keep the row from the latest `SourceFileDate`, then the highest `SourceFileName`.
- **Same part and effective date in several Change Report files:** keep the latest `SourceFileDate`.
- **Null EffectiveDate** (856 rows): use `SourceFileDate` instead and set `EffectiveDateFromFile = true`.

Keys use `xxhash64` on the business key (DP notebook rule 3). Every date is DATE, never a timestamp (memory: Gold timestamp keys break relationships).

### Freshness warning

The orchestrator gains an optional config list `orchestrator.freshnessChecks`. After Silver, it reads `max(<column>)` from each listed table and adds a **Warning** to the daily DP email when the data is too old:

| Check | Table / column | Max age |
|---|---|---|
| JD branch price update files | `Silver_PriceUpdate_History.SourceFileDate` | 8 days |
| JD National Change Report | `Silver_JDChangeReport_History.SourceFileDate` | 10 days |

- A warning doesn't change the run's status; it's listed under Warnings, as today.
- Pure logic goes in `orchestrator_core.freshness_warnings()` with unit tests; the glue only runs the queries.
- The config list is generic, so any future file-fed source can use it.

## Report

- The JD Price Updates PBIP is repointed (TMDL edited while Desktop is closed) to the DP_Presentation Dev SQL endpoint: the three new facts plus Gold dim_Parts, dim_DateTable and dim_BranchLocation.
- Measures that recomputed LAG, disagreement flags and so on in DAX are simplified to use the Gold columns.
- It stays local. Publishing it is a separate decision for Brian and Ben.

## Retirement (after a side-by-side check)

**Side-by-side check:** Silver against the LH tables. The row counts must match the LH counts minus the known duplicates, plus the missing 8/31 Change Report rows.

Then:
1. Turn off the `pl_Raw_PriceUpdate_History` schedule.
2. Disable the scheduled task `\Fabric\JD Price Update Harvest`.
3. Update `Send-JDChangeReportReminder.ps1`'s text so it points at the new share folder. The reminder stays.
4. The LH items (2 dataflows, 2 pipelines, `Fact_PriceUpdate_Enriched`, the 3 tables and the landing folders) are deleted **only with Brian's explicit OK**, as part of retiring LH_Master_Data.

## Risks and checks during the build

- **Gateway access to `JD_Change_Report`.** The gateway's credential must be able to read the new folder. It reads `Price_Update` in the same parent folder, so it almost certainly can.
  - The first dataflow run proves it. If not, Brian adds a Folder connection on the parent `Daily_Reports` path.
- **Row-shift defect position.** Before trusting "first 3 fields are good", the build checks the malformed rows' Branch/PartNumber values against dim_Parts.
- **Share retention.** If someone ever purges old files from the share, Silver keeps them, because rows are never deleted for files outside the window. A brand-new tier could then no longer rebuild from the share, but it could be copied from the other tier.
- **The source writes files around midnight Sunday** and the DP refresh runs at 6:15, so a file is never caught mid-write in practice. The count check covers it anyway.

## Out of scope

- Margin-impact analysis joined to sales (next step, after Ben says which questions matter).
- The `PARTNOUPDATE`, `PARTCONVERT` and `SUBUPDATE` feeds.
- Publishing the report.
