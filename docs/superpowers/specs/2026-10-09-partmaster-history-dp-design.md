# Part Master History on DP: Design

**Date:** 2026-10-09
**Status:** Approved by Brian (design discussion, 2026-10-09)
**Replaces:** LH_Master_Data `DF_PartMaster_Snapshot_Daily`, `DF_PartMaster_Snapshot_Weekly`, `NB_PartMaster_Retention_Policy`, and the interim `df_JDIS_PART_INFORMATION_Raw` schedule that feeds them.

## Why this exists

`jdis_Part_Information` is a source-system **view** with no history of its own, so the snapshots are the only record of past part-master state. Brian's real uses:

1. **Undoing bad changes.** For example, Curt accidentally set every commodity code at branches 2 and 4 to "COTTON". A weekly snapshot held the originals, so it could be fixed. `CommodityCode` is only in the weekly snapshot, though, so the best possible restore was to the previous Sunday.
2. **"As of" requests.** For example, Shannon asked for Franchise W at branch 1 for the week of 9/8/2026.
3. **Trends over time.** This was the original purpose. Nothing has been built on it yet; it should be easy later.

Brian's guidance: the goal is to improve things, not just move them.

## What exists today (measured 2026-10-09)

| Table | Rows | Range | Columns | Notes |
|---|---|---|---|---|
| `Fact_PartMaster_Snapshot_Daily` | 337M | 2025-10-27 → today, 307 days (41 missing) | 15 + SnapshotDate/DateTime + derived TotalAvailableQty | **No Franchise.** The real key is Branch + Franchise + Part, so ~9K rows per snapshot can't be told apart (2.8M in total) |
| `Fact_PartMaster_Snapshot_Weekly` | 48M | 44 Sundays, none missing | all 33 + SnapshotWeek | |

- Each snapshot holds about 1.1M rows. **Under 1% change from one day to the next** (6.7K–9.0K rows measured on 3 day pairs).
- **Retention:** daily kept 13 months, weekly 24 months. Nothing has been deleted yet. The retention notebook's schedule was **switched off 2026-10-09** (Brian), so no history will be lost while this is built.
- **The LH snapshot schedules end 12/31/2026,** which is enough to cover the build and the side-by-side run.

**Source on DP:** `Silver_PartInformation` (DP_Staging; built daily by `Build_Silver_PartInformation` from JD Bronze using the view's real SQL).
- It has all 33 columns of the old `jdis_Part_Information`.
- Branch + Franchise + PartNumber is unique, with no null key parts. It's already shortcut into DP_Presentation.

## Design

### 1. `Fact_PartMaster_History` (DP_Presentation, Gold)

This table stores only what changed, as dated versions.

| Column | Meaning |
|---|---|
| `Branch`, `Franchise`, `PartNumber` | Key (from Silver, unchanged) |
| the 30 other `Silver_PartInformation` columns | Values for this version, with the same names and types as Silver |
| `ValidFrom` (DATE) | First day this version was observed |
| `ValidTo` (DATE) | The day it stopped being current (exclusive). `9999-12-31` while current |
| `IsCurrent` (BOOLEAN) | `ValidTo = 9999-12-31` |
| `ChangeType` | `Initial` (seed), `New` (first appearance after the seed), `Changed`, `Removed` (the part left Silver; zero-length marker, see below), `Returned` (reappeared after being removed) |
| `ChangedColumns` | Comma-separated names of the columns that differ from the previous version, in schema order. Empty for Initial/New/Removed/Returned |
| `RowHash` | `xxhash64` over the 30 value columns, to detect changes |
| `LoadedAtUtc` | When the row was written |

- **Size:** about 1.1M rows at seed, then ~8K a day, so ~3M rows a year. **Kept forever**; there's no retention step.
- **As of date D:** `ValidFrom <= D AND D < ValidTo`.
- **Removed parts:**
  - The open version is closed (`ValidTo` = run date).
  - A `Removed` marker row is added with `ValidFrom = ValidTo` = the run date, so it's never in an as-of result and the history says when the part disappeared.
  - If the key reappears later, it opens a `Returned` version.

### 2. Daily step: `Build_Gold_PartMasterHistory`

- **DAG item:** gold tier, daily; `dependsOn: ["Build_Silver_PartInformation"]`; produces `Fact_PartMaster_History`.
- **Run date:** the Central date when the notebook runs. The DP refresh runs early on weekdays, so weekend changes land on Monday, the same effective behaviour as today.
- **Logic:**
  1. Read Silver and compute `RowHash`.
  2. Read the current open versions.
  3. Full outer join on the key:
     - **Key only in Silver, no prior version:** `New` (or `Initial` on the very first run).
     - **Key only in Silver, a `Removed` marker exists:** `Returned`.
     - **Both, hash differs:** close the old version and open a `Changed` version. `ChangedColumns` lists the columns that differ, compared null-safe.
     - **Both, hash equal:** nothing.
     - **Key only in the open versions:** close it and add a `Removed` marker.
- **Write:** one Delta `MERGE` closes the old versions, then an append adds the new ones. Same-day re-runs:
  - A version opened **today** that changes again today is **updated in place**, not closed into a zero-length version.
  - A version closed today and then seen again unchanged today is reopened, and today's `Removed` marker for that key is dropped.
  - The result: running the notebook twice on the same input gives identical output (DP notebook rules 1–3).
- **Safety guard:** before writing, compare Silver's row count with the open-version count.
  - If Silver is **more than 2% smaller**, raise an error and write nothing. A partial Silver must not mass-close thousands of parts as Removed.
  - The DP email reports the failure. The threshold is a named constant in the notebook.
- **Determinism:** there are no arbitrary survivors; the key is unique by construction. Assertions after the write:
  - at most one open version per key;
  - no overlapping versions per key;
  - open count = Silver row count.

### 3. Old history: frozen archive copies

- **Tables:** `Fact_PartMaster_Snapshot_Daily_Archive` and `Fact_PartMaster_Snapshot_Weekly_Archive`. They are **exact copies** of the LH tables (same columns and types), with no conversion.
- **Where:** DP_Presentation **Prod** only; one copy of about 385M rows.
  - Dev gets **no** shortcut to them (changed while planning). Dev validation compares against the LH tables directly.
  - A Dev shortcut pointing at Prod would also be copied into Prod by `deploy/sync_shortcuts.py`, where it would collide with the real tables.
- **How:** a one-off notebook under `deploy/oneoff/`, run with `deploy/run_oneoff_notebook.py`, using the 2026-10-02 snapshot-copy pattern.
  - It reads the LH tables by abfss path, writes them to Prod with a path-based `save`, and asserts that row counts and a content fingerprint match the source.
- **Not in the DAG.** They're never rebuilt.
- **Lookups before go-live** use these tables. A later project could merge them into the history table if one seamless timeline is ever wanted. That's not planned: the daily table has no Franchise and the two tables track different columns.

### 4. Lookups

Two documented SQL queries in fabric-workspace-docs `OPERATIONS-GUIDE.md`, run against the DP_Presentation SQL endpoint:
- **As of date D**, filtered by branch, franchise and part. This answers Shannon-type requests.
- **Changes on date D or in column C**: the before and after values per part, from the version that closed that day joined to the one that opened. This answers incidents like Curt's.

Before go-live, the same questions use the archive tables (daily: 15 columns; weekly: all 33).

**Later, not in this build:**
- a "Part Master As-Of" Power BI report with a date picker;
- weekly or monthly trend tables built from the history.

### 5. Rollout

1. **Dev:** build the notebook and seed (`Initial`). Then let the daily runs build versions and check:
   - rebuilding day D from history gives the same values as LH `Fact_PartMaster_Snapshot_Daily` for D on the 15 shared columns;
   - on Sundays, the same against `_Weekly` for all 33 columns.
   - **Expected differences:**
     - **Timing:** LH snapshots at 02:00 from the 01:15 ODBC refresh, while DP reads JD Bronze in the 06:15 run.
     - **Branch + Part keys with two franchises** in the daily table.
   - Anything else is a bug.
2. **Prod:** run the archive copy first, then deploy the notebook (fabric-cicd from main, claim the pipeline) and run it to seed.
3. **Side-by-side:** about 2 weeks, with the LH snapshots still running.
4. **Retire:** with Brian's OK, switch off `DF_PartMaster_Snapshot_Daily`, `_Weekly` and the interim `df_JDIS_PART_INFORMATION_Raw` schedule. The retention notebook is already off. **Nothing is deleted.**

## Out of scope
- The as-of Power BI report and trend tables (later, once the business asks).
- Converting the archive into the history format.
- The other ~170 columns of the source view (60-month history arrays and so on). `Silver_PartInformation` deliberately doesn't carry them.
