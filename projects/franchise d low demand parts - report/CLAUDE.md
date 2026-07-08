# Franchise D — Low Demand Parts with Cross-Branch Activity — Claude Context

## Project Overview
- **Business purpose:** Identifies Franchise D parts at a given branch with low local demand but meaningful demand across all other branches combined. Surfaces stocking opportunities — parts that are clearly moving in the system but are under-stocked or inactive at specific locations.
- **Primary users:** Corp Parts Manager
- **Format:** Ad-hoc Excel analysis (Power Query in Excel's Advanced Editor) — not currently a Power BI report or Fabric dataflow
- **Connection:** ODBC — `dsn=EquipRDB64` (direct source query, not Lakehouse)
- **Status:** Active — used on request, re-run manually as needed

## How Demand Is Calculated

A "demand" = one `InTrans` row where:
- `TYPE = 'I'` (customer invoice — excludes transfers, adjustments, returns)
- `QTY > 0` (outbound sale to customer)
- `Trans_Datetime` between 7 days ago and 18 months ago (recent week excluded so very fresh activity doesn't mask a genuinely low-demand branch)

This counts actual transaction events, not pre-aggregated `pi_sales_request_XX` buckets (which are approximate).

## Criteria (adjustable — see query header for exact lines to change)

| Criterion | Current Value |
|-----------|---------------|
| Franchise | `D` |
| Candidate (local) branches | `7`, `14`, `95`, `91`, `96` — only these branches can be flagged |
| Other-branch universe | excludes `2`, `4` — broader pool used for `OtherBranchDemands`, **not** limited to the 5 candidates |
| Local demand threshold | `< 3` |
| Other-branch demand threshold | `>= 10` |
| On-hand threshold | `< 1` (local branch only) |
| Excluded source | `AN` |
| Excluded SLC prefixes | `21`, `90`, `91`, `99` (any sub-code, e.g. 21A/21B) |
| Time window | 7 days – 18 months |

**Branch scope is asymmetric by design** (per Ben, 2026-07-07): the local/candidate branch is restricted to the 5 branches above, but the other-branch comparison pool stays broad (everyone except 2 & 4) so cross-branch demand totals aren't artificially shrunk. This is implemented as a post-aggregation filter in the M code, not the SQL WHERE — see query header notes.

## Part Filters (from `jdis_Part_Information`)
- `On Order = 0` — only parts with no outstanding purchase orders
- `Package Qty = 1` — only individually-stocked parts (not bundled)
- `Return Indicator = 'R'` — only returnable parts
- `Source <> 'AN'` — excludes Source code "AN"
- `SLC NOT LIKE '21%'/'90%'/'91%'/'99%'` — excludes these SLC families (any sub-code)

## Source Tables
| Table | Role |
|-------|------|
| `InTrans` | Demand — transaction-level detail, joined via `BRANCH` + `PART_NO` |
| `jdis_Part_Information` | Part attributes (description, cost, source, SLC, commodity code, dealer group code, on-hand qty) + the part filters above |

**INNER JOIN** to `jdis` is intentional — part filters require jdis columns, so parts missing a jdis record can't be validated and are correctly excluded.

## Output Columns
`Branch`, `PartNumber`, `Description` (from jdis `pi_Description`, not the InTrans notation field), `Cost`, `Source`, `SLC`, `CommodityCode`, `CommodityGroup` (business-defined group name, e.g. Sprayer/Toys/Tillage; "Other" if unmapped), `DealerGroupCode`, `OnHandQty` (local branch's on-hand qty, always < 1), `Demands` (this branch's count over the 7-day–18-month window), `OtherBranchDemands` (combined count at all other non-excluded branches — broad pool, not limited to the 5 candidates), `OtherLocationCount` (number of other branches with any demand).

## Notes / Gotchas
- **Description source:** `InTrans.DESCRIPTION` is a customer/notation field, not the part description — always pull description from `jdis_Part_Information.pi_Description`.
- **Branch asymmetry:** Candidate/local branch is restricted to 7, 14, 95, 91, 96. `OtherBranchDemands`/`OtherLocationCount` are computed against the broader "exclude 2 & 4" pool, not the 5-branch list — do not collapse this into a single SQL WHERE filter, it would understate cross-branch demand.
- **On-hand is local-only:** `OnHandQty` (`pi_On_Hand_Qty`) is pulled back as a plain column and filtered post-aggregation (like the branch restriction), not in SQL WHERE — putting it in WHERE would drop other branches' demand rows just because those branches happen to be in stock, deflating `OtherBranchDemands`.
- **Source/SLC exclusions are broad:** unlike branch/on-hand, these apply in SQL WHERE and affect both sides of the comparison (consistent with the other part filters).
- **CommodityGroup source:** joined in from `CommodityCodeGroups.csv` on SharePoint (`SouthPlainsImplement-ReportSite`) — the exact same file used by the shared `dim_CommodityCode` Fabric dataflow (see `.claude/queries/dimensions/dim_CommodityCode.pq`, Steps 14-15). One file, two consumers — update it once and both pick up the change (Fabric on its next monthly refresh, this query next time it's run). Unmapped codes show `"Other"`, same convention as the Fabric side.
- **Run timing:** Run during off-peak hours (before 7 AM or after 5 PM) — `InTrans` is large and this queries the ODBC source directly, not the Lakehouse.
- **Last run:** 2026-06-08
- **Last updated:** 2026-07-08 — added `CommodityGroup` (joined from the SharePoint lookup CSV shared with `dim_CommodityCode`)

## Query Library
- Query lives in `queries/FranchiseD_LowDemand_Parts_CrossBranch.pq` in this project folder (moved from `.claude/queries/adhoc/` now that this has its own project).
- `CommodityGroup` lookup data is shared with the Fabric-side `dim_CommodityCode` dimension — see `.claude/queries/dimensions/CommodityCodeGroups.csv` (repo reference copy) and `.claude/queries/dimensions/dim_CommodityCode.pq` for the parallel implementation.
