# SPI Corparate Stocking — Franchise D Zero Stock, Company-Wide Demand

**Workbook:** `SPI Corparate Stocking.xlsx` (SharePoint → Corp Parts Excel Reports)
**Requested by:** Ben (Corp Parts Manager) via Brian, 2026-08-27
**Purpose:** Company-wide reorder-candidate view — Franchise D parts with
ZERO on-hand and ZERO on-order at every branch that still generate demand
at 3+ distinct branches. Different grain from Border Stores (`../Border
Stores/`), which flags a low-demand *branch* against a candidate list; this
one drops Branch entirely and looks at the whole company per part.

## How it fits together (since 2026-10-13: live ODBC)

`SPI Corparate Stocking.pq` queries Equip live over `dsn=EquipRDB`, like every
other Corp Parts workbook. **Refresh = Equip as it is right now**; Ben, Barry
and Curt refresh on demand, no script involved. It runs two plain queries
(jdis eligibility ~11–16s, InTrans demand ~5–8s) and combines them in Power
Query — see the `.pq` header for why the combine must stay out of SQL.

**Retired 2026-10-13, kept for reference only (don't delete without Brian):**
`build_report.py` (DuckDB over DP Prod) and the SharePoint file it wrote,
`Source Data/Franchise D - Zero Stock Company-Wide Demand.xlsx`. Nothing reads
that file any more. The script/DP sections below are history.

## Why this USED to be a script (superseded 2026-10-13)

The 2026-08-27 live ODBC query (`history/FranchiseD_ZeroStock_CompanyWide
(ODBC attempt - hung).pq`, kept for reference — don't use it) hung for 30+
minutes, twice. It was blamed on volume (below), but on 2026-10-13 the real
cause turned out to be query **shape**: `pi_Part_No IN (subquery)` on jdis and
a LEFT JOIN between two derived tables both crawl on SQL Anywhere. Two plain
single-table GROUP BY queries combined in Power Query run in ~20s total.

| Stage | Row count (2026-08-27) |
|---|---|
| `jdis_Part_Information` total | 1,110,498 |
| ...filtered to `Franchise = 'D'` | 886,523 (**80%** of the table) |
| ...+ eligibility filters | 516,567 rows / 109,240 distinct parts |
| InTrans, demand-def filtered | 770,691 rows / 59,830 parts |
| Final (`LocationCount >= 3`) | ~1,800 |

DuckDB over OneLake (columnar) runs it in ~30 seconds; the row-store ODBC
source can't.

## Logic (confirmed with Ben)

- **Eligibility (part info):** Franchise D, branches 2 & 4 excluded, Package
  Qty = 1, Returnable = 'R', Source <> 'AN', SLC not 21%/90%/91%/99%, AND
  zero on-hand + zero on-order at **every** remaining branch that carries
  the part (every branch = 0, not the sum across branches).
- **Demand (InTrans):** Type = 'I', Qty > 0, Franchise D, branches 2 & 4
  excluded, 7 days to 18 months back. **Since 2026-10-13** a demand is one
  *invoice* per part + branch (split lines count once), net of credits:
  Type 'C' rows are matched to the invoice they return via
  `OriginalInvoiceNo`, and an invoice credited down to net qty ≤ 0 drops out.
  Same rule in every Corp Parts report.
- **Filter:** `LocationCount >= 3` (distinct branches with demand); no floor
  on total demand.
- **Superseded parts excluded (added 2026-10-08, per Ben — same rule as MLPF
  Gaps):** a part drops out if **any** eligible branch has a Super To value.
  Super To is set per branch and often only at some (2026-10-08: 44 affected
  parts, only 5 superseded at every branch, e.g. RE586742 at 15 of 16), so
  "any branch" rather than dropping just the superseded rows — a part that's
  been replaced at most branches isn't a company-wide stocking candidate.
  Blanks are `''` or spaces-only, hence `TRIM`. To switch to per-branch
  instead, move the SuperTo condition from the `eligible` HAVING into its WHERE.
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
- 2026-10-08: Super To exclusion added — 1,837 → 1,793 parts (44 superseded parts removed)
- 2026-10-13: demand = invoices net of credits; new `DemandBranches` column
  (shown as "Locations with Demands"); workbook headers renamed to "R18 Demands" /
  "Count of Locations with Demands". Same-day data: 1,776 → 1,774 parts (2 fell
  below 3 locations), 176 parts' demand lowered (7,257 → 7,056 total).
  DE18732: 6 → 4 demands (one invoice had 2 lines; one sale fully credited).
- 2026-10-13: switched the workbook to live ODBC (no script). Live: 1,785 parts
  vs 1,774 in the same morning's DP file (1,768 in common, 1,758 with identical
  demand; the rest is Equip changing since the 06:15 DP refresh).
