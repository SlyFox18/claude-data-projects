# SPI Corparate Stocking — Franchise D Zero Stock, Company-Wide Demand

**Workbook:** `SPI Corparate Stocking.xlsx` (SharePoint → Corp Parts Excel Reports)
**Requested by:** Ben (Corp Parts Manager) via Brian, 2026-08-27
**Purpose:** Company-wide reorder-candidate view — Franchise D parts with
ZERO on-hand and ZERO on-order at every branch that still generate demand
at 3+ distinct branches. Different grain from Border Stores (`../Border
Stores/`), which flags a low-demand *branch* against a candidate list; this
one drops Branch entirely and looks at the whole company per part.

## How it fits together

```
build_report.py  ──(DuckDB over OneLake)──►  SharePoint: Corp Parts Excel Reports/Source Data/
   (run manually)                              Franchise D - Zero Stock Company-Wide Demand.xlsx
                                                          │
                                   SPI Corparate Stocking.pq (in the workbook) reads it
                                                          ▼
                                         SPI Corparate Stocking.xlsx  ← Ben / Barry / Curt refresh
```

**Refreshing the workbook only re-reads the source file.** New data only
appears after `build_report.py` is run. The script writes into Brian's
OneDrive-synced copy of the SharePoint library, so OneDrive uploads it
automatically — no manual upload step.

To update: run `python build_report.py` (needs an active `az login`; output
path is fixed, run from anywhere), then anyone can Data > Refresh All.

## Why this is a script, not a live Power Query

The same SQL as a live ODBC query (`history/FranchiseD_ZeroStock_CompanyWide
(ODBC attempt - hung).pq`, kept for reference — don't use it) hung for 30+
minutes, twice. Not a query-shape problem: Franchise D is ~80% of the whole
parts catalog, so there's no way to narrow scope.

| Stage | Row count (2026-08-27) |
|---|---|
| `jdis_Part_Information` total | 1,110,498 |
| ...filtered to `Franchise = 'D'` | 886,523 (**80%** of the table) |
| ...+ eligibility filters | 516,567 rows / 109,240 distinct parts |
| InTrans, demand-def filtered | 770,691 rows / 59,830 parts |
| Final (`LocationCount >= 3`) | ~1,800 |

DuckDB over OneLake (columnar) runs it in ~30 seconds; the row-store ODBC
source can't.

## Logic (unchanged since 2026-08-27, confirmed with Ben)

- **Eligibility (part info):** Franchise D, branches 2 & 4 excluded, Package
  Qty = 1, Returnable = 'R', Source <> 'AN', SLC not 21%/90%/91%/99%, AND
  zero on-hand + zero on-order at **every** remaining branch that carries
  the part (every branch = 0, not the sum across branches).
- **Demand (InTrans):** Type = 'I', Qty > 0, Franchise D, branches 2 & 4
  excluded, 7 days to 18 months back.
- **Filter:** `LocationCount >= 3` (distinct branches with demand); no floor
  on total demand.
- Judgment call (not explicitly discussed with Ben): a branch excluded by
  Source/SLC or the 2/4 exclusion doesn't count against "zero everywhere".

## Data source — DP - Staging - Prod (switched 2026-10-07)

`build_report.py` reads **DP - Staging - Prod → DP_Staging** (`Silver_PartInformation`
+ `Silver_InTrans`). It used to read `LH_Master_Data` (`jdis_Part_Information` +
`InTrans_Incremental`); the column names are identical, so only the lakehouse
path and two table names changed.

Why, tested 2026-10-07 with the identical logic:

| | LH_Master_Data (old) | DP Prod (now) |
|---|---|---|
| Parts returned | 1,819 | 1,808 (1,805 in common) |
| Total demand (shared parts) | 8,332 | 7,672 |
| Matches live EquipRDB? | **No** — 1–2 too high on all 12 sampled differing parts | **Yes** — exact on all 15 sampled parts |
| Refresh | Scheduled daily | **Manual** until DP cutover |

`LH_Master_Data.InTrans_Incremental` double-counts some transactions (523 of
~1,805 parts over-counted, usually by 1). JD Bronze alone can't serve this —
`jdis_Part_Information` isn't in JD's mirror, so part info has to come from DP's
own `Silver_PartInformation`.

**Freshness:** until DP's refresh schedule is live, DP Prod Silver only updates
when the DP notebooks are run. The script prints each input's freshness and
flags anything older than 2 days — if it flags, run the DP Prod Silver
notebooks (Silver_InTrans, PartInformation dataflows + Silver_PartInformation)
first, then re-run the script.

**Next step (proposed, not built):** move this logic into a DP Gold notebook run
by the DP orchestrator and point the workbook at the DP_Presentation SQL
endpoint, so Refresh in Excel = latest data with no script. Needs read access
to that lakehouse for Ben/Barry/Curt.

## Run history

- 2026-08-27: first build — 1,809 parts (after Ben confirmed 2 & 4 excluded; was 3,118)
- 2026-09-15: last run before the workbook split
- 2026-10-07: re-run from LH_Master_Data — 1,819 parts (source file had been stale since 9/15)
- 2026-10-07: switched to DP Prod and re-run — 1,808 parts (corrected demand counts)
