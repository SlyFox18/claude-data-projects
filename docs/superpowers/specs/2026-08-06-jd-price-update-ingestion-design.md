# JD Price Update Ingestion — Design

## Overview

New project (name TBD) covering John Deere parts pricing. This spec covers
**only the first of three sub-projects** identified during brainstorming:

1. **This spec** — ingest the daily `PRICEUPDATE_*.TXT` files that already
   land on a network share into `LH_Master_Data` as a clean raw table.
2. *(Separate, future spec)* — investigate automating collection of JD's
   Global Parts Pricing website weekly Change Reports (`.csv`, all Deere
   parts, not just ones we sell; 2FA-gated, only 4 reports retained online
   at a time). Likely a smaller, more exploratory spec once #1 is proven
   out, and may end up partly/fully manual.
3. *(Separate, future spec)* — analysis layer: margin-impact analysis (did a
   price change erode margin, e.g. 30% → 25%), and slicing price changes by
   `dim_Parts` classifications (SLC, DealerGroupCode, CommodityCode) to
   answer questions like "how has Planter pricing moved." Depends on real
   data from #1 (and optionally #2) being available first.

**Business driver:** Deere sends parts price changes down as branch-level
text files. There's currently no historical record of these changes in the
Lakehouse — this spec establishes one, cheaply, so future trend and margin
analysis has real data to work with.

## Source Data

- **Location:** a network folder reachable from Brian's machine
  (`\\<server>\...\Price_Update`), which also hosts the `SPI-Data-Gateway`
  on-premises data gateway and the existing `fabric-monitoring` Windows Task
  Scheduler jobs. A `Network_Folder` gateway data source already exists and
  shows Online, confirming the share is reachable from Fabric's network
  path (not used directly by this design — see Architecture — but good
  confirmation the environment is sound).
- **File naming:** `PRICEUPDATE_MM_DD_YYYY_BRANCH.TXT`, e.g.
  `PRICEUPDATE_08_02_2026_97.TXT` (branch 97) or `PRICEUPDATE_08_02_2026_1.TXT`
  (branch 1). Branch is 1–3 digits, optionally followed by a single letter
  sub-branch/department code, e.g. `PRICEUPDATE_08_28_2022_11S.TXT` (branch
  11, sub-location "S"). Confirmed 2026-08-07 against the real folder: ~6%
  of all files across all 10 years use this letter-suffixed shape, and the
  in-file `branch` column itself carries the same suffix (verified against
  `PRICEUPDATE_08_28_2022_11S.TXT`'s content, where every row's `branch`
  value is literally `11S`). Per Brian, the sub-branch letter is not
  meaningful for this data and is always rolled up to the main branch
  number for analysis — see Raw Table Schema for how this is implemented.
  The folder contains other, unrelated files — only files starting with
  `PRICEUPDATE` are in scope.
- **File format:** tab-delimited text, first row is a header (`branch`,
  `inmaster_franchise`, `part_no`, `inmanuf_list_price`,
  `inmaster_list_price`, `cc_price_decrease`, `bin_location`, `category`,
  `inmaster_on_hand_qty`, `inmanuf_replace_price`, `inmaster_replace_price`,
  `inmanuf_sell_price1`, `inmaster_sell_price1`, `cost_diff`, `list_diff`,
  `sel1_diff`, `effective_date`, `update_code`, `part_desc`,
  `sell_price_old`).
- **History depth:** confirmed 2026-08-07 via `Inventory-PriceUpdateFolder.ps1`
  against the real folder: 4,592 total files, all 4,592 matching the (now
  letter-suffix-aware) filename pattern, 0 failures — before the sub-branch
  regex fix, the old digits-only pattern wrongly failed 278 of these (the
  letter-suffixed ones). Spans **2016-12-25 to 2026-08-02** (further back
  than the "~2018" originally recalled), 548 MB total, 22 distinct main
  branches. Well under the plan's chunking threshold (~2 GB / ~20,000
  files) — the historical backfill (Task 10) can run as a single unchunked
  pass.
- **Column stability across years:** confirmed 2026-08-07 via
  `Compare-PriceUpdateSchema.ps1` against real 2018/2020/2022/2026 sample
  files: one clean, single drift event — files before some point between
  Jan 2018 and Feb 2020 have 19 columns (missing `sell_price_old`); every
  file from ~2020 onward consistently has all 20. No other column
  differences found across the sampled years. Already handled correctly by
  the existing by-name, `MissingField.UseNull`-defended parsing (see Raw
  Table Schema / Error Handling) — older files simply get `SellPriceOld =
  null`, no further changes needed.
- **Important business fact about branch:** pricing fields
  (list/replace/sell prices, the `*_diff` columns) are attributes of
  **part + effective date**, not of branch — the same part's price change on
  the same day is identical across every branch's file for that day. Branch
  files exist because **assortment varies by branch** (a file for
  branch X + part Y only exists if branch X actually carries part Y), so the
  *set* of branch-files for a given part+date is itself a signal (which
  branches carry that part). `bin_location` and `inmaster_on_hand_qty` are
  genuinely branch-specific (inventory-level) fields.
  **Implication carried forward to the future analysis phase:** the natural
  key for price-trend/margin analysis is `PartNumber + EffectiveDate`, not
  `Branch + PartNumber + EffectiveDate`. Branch only matters there for
  assortment/inventory questions. This raw ingestion phase still captures
  full per-branch fidelity (see Raw Table Schema) — nothing is deduplicated
  at this stage.

## Non-Goals (this spec)

- Building a curated Fact table, or any `dim_Parts`/`dim_BranchLocation`
  relationships. Scope stops at a clean raw table.
- Automating or designing the JD website Change Report collection (sub-project 2).
- Any margin or trend analysis (sub-project 3).
- Deciding a final project name/folder for the overall JD pricing effort —
  can be settled once sub-project 1 is built and something concrete exists
  to name.

## Architecture

```
Network share (\\...\Price_Update)
        │  [PowerShell script, scheduled daily on Brian's machine —
        │   same box as the gateway + existing fabric-monitoring tasks]
        │  - lists files matching PRICEUPDATE_*.TXT
        │  - diffs against filenames already in OneLake Archive/
        │  - copies any new files into BOTH New/ and Archive/
        │  - never modifies/deletes anything on the source share
        ▼
OneLake Files/PriceUpdate_Landing/   (written via the mounted OneLake File
                                       Explorer client, C:\Users\bfox\OneLake
                                       - Microsoft — plain file copy, no API)
   ├── New/        ← only not-yet-successfully-ingested files (rotates small)
   ├── Archive/    ← permanent copy of every file ever harvested
   └── Quarantine/ ← files that fail filename or header-schema parsing
        │  [Fabric Pipeline, two sequential steps]
        │  1. Dataflow Gen2 refresh: reads New/, promotes headers, parses
        │     branch+date from filename, appends parsed rows to the raw
        │     table (never replaces)
        │  2. On success only: pipeline activity clears New/
        ▼
LH_Master_Data: Raw_PriceUpdate_History
```

**Why this shape (CU-conscious):** the only expensive step — scanning years
of small files — happens as a plain OS file operation on Brian's machine, at
zero Fabric CU cost. The Dataflow Gen2 never re-reads full history; it only
ever sees whatever is currently in `New/` (a handful of KB-sized files on a
normal day), because `New/` is cleared only after a confirmed successful
append. Daily CU cost stays flat and tiny regardless of how much history
accumulates in `Archive/`. This was chosen over two alternatives:

- **Dataflow Gen2 folder-connector directly against the network share via
  gateway** — rejected because folder-combine connectors don't cleanly skip
  "already seen" files, so every refresh risks re-listing/re-combining the
  entire historical folder (tens of thousands of files). Given CU has
  already been a live operational problem (see Parts Lookup capacity
  incident), repeatedly re-touching full history was judged too risky.
- **Notebook-based end-to-end (harvest + parse in one place)** — rejected
  because Fabric notebooks have no native way to reach an on-prem UNC path;
  it would still need a script or gateway-backed connector to get bytes into
  OneLake first, collapsing back into this same two-stage shape but with the
  parsing half moved into a notebook instead of a dataflow. No clear benefit
  given headers are present and Power Query can parse by column name.

**Self-healing property:** if the pipeline's dataflow step ever fails, files
simply remain in `New/` and get swept up (plus whatever the harvest script
adds the next day) on the next successful run. Nothing is lost and nothing
is double-counted, because `New/` only clears after a confirmed successful
append, and the harvest script's copy step is filename-based (skip if
already in `Archive/`), so re-running either side is always safe.

## Raw Table Schema — `Raw_PriceUpdate_History`

Grain: one row per branch + part + effective date + source file. No
deduplication across files or branches — this is intentionally a raw event
log, since the same part can legitimately reappear across multiple update
files over time (that's exactly what trend analysis needs later), and the
same part+date can legitimately appear in multiple branches' files (that's
the assortment signal described above).

| Source column | Raw table column | Notes |
|---|---|---|
| `branch` | `Branch` | From file content, **rolled up to the main branch number** (e.g. `11S` → `11`) — sub-branch letter is not meaningful for this data per Brian; the full raw code is preserved separately in `SourceFileBranch` |
| `inmaster_franchise` | `Franchise` | |
| `part_no` | `PartNumber` | |
| `inmanuf_list_price` | `ManufacturerListPrice` | |
| `inmaster_list_price` | `DealerListPrice` | |
| `cc_price_decrease` | `ListPriceChangePercent` | Signed %; negative = decrease, positive = increase |
| `bin_location` | `BinLocation` | Branch-specific |
| `category` | `Category` | Passed through as-is; mapping to `dim_Parts.CommodityCode`/`SLC` is an analysis-phase question |
| `inmaster_on_hand_qty` | `OnHandQty` | Branch-specific |
| `inmanuf_replace_price` | `ManufacturerReplacePrice` | |
| `inmaster_replace_price` | `DealerReplacePrice` | |
| `inmanuf_sell_price1` | `ManufacturerSellPrice1` | |
| `inmaster_sell_price1` | `DealerSellPrice1` | |
| `cost_diff` | `CostDiff` | |
| `list_diff` | `ListDiff` | |
| `sel1_diff` | `SellPrice1Diff` | |
| `effective_date` | `EffectiveDate` | |
| `update_code` | `UpdateCode` | Blank in samples seen so far; passed through in case it's populated for other update types |
| `part_desc` | `PartDescription` | |
| `sell_price_old` | `SellPriceOld` | |
| *(new)* | `SourceFileName` | Full filename, for traceability/reprocessing |
| *(new)* | `SourceFileBranch` | Full raw branch code parsed from the **filename** (not file content), including any sub-branch letter (e.g. `11S`) — unlike `Branch`, this is NOT rolled up |
| *(new)* | `SourceFileDate` | Date parsed from the **filename** (not file content) — paired with `SourceFileBranch`, same "from filename, not content" pattern |
| *(new)* | `BranchMismatchFlag` | `true` if `SourceFileBranch` ≠ the raw in-file branch value (compared before either side is rolled up or type-converted) — data-quality tripwire only, does not block ingestion |
| *(new)* | `IngestedAt` | Load timestamp, using the existing DST-aware UTC→Central pattern (`.claude/queries/DATA-REFRESH-TEMPLATE.pq`) |

## Error Handling & Edge Cases

- **Schema drift:** parsing promotes headers and selects known columns *by
  name*, not position. A file missing an expected column gets that field as
  `null` rather than failing the row. A file whose header row doesn't match
  a recognizable pattern at all routes to `Quarantine/` instead of blocking
  the day's whole batch.
- **Filename parsing:** branch suffix is 1–3 digits, optionally followed by
  a single sub-branch letter (e.g. `11S`); date is `MM_DD_YYYY`. Filenames
  that don't match the expected pattern route to `Quarantine/`.
- **Duplicate/re-run safety:** `New/` only clears after a confirmed
  successful append; the harvest script's copy step is filename-based (skip
  if already in `Archive/`). Re-running either side never double-copies or
  double-appends.
- **Historical backfill volume risk:** the first run copies potentially
  thousands of files into `New/` at once. If a single Dataflow Gen2 refresh
  can't handle that volume cleanly, the initial backfill may need to be
  chunked (e.g., by year) rather than done as one pipeline run. This is a
  decision point for implementation, not resolved here, since the real file
  count/volume isn't known yet.
- **Source folder integrity:** every operation against the network share is
  read-only. No risk to the production Equip system regardless of what goes
  wrong on the Fabric side.

## Open Items for the Implementation Plan

- Confirm actual oldest file date and total file count in the source folder
  (needed to size the historical backfill).
- Spot-check a 2018-era file's header row against a current one to confirm
  or refute the schema-drift assumption before finalizing the parsing logic.
- Decide historical backfill chunking strategy once real file count is known.
- Decide daily schedule time for the harvest script (no hard dependency on
  the main pipeline's timing since this doesn't feed Tier 1/2/3 reports).
