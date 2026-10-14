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

**Zero-demand branches are included** (fixed 2026-07-09): the candidate branch/part population is now pulled from `jdis_Part_Information` rather than derived from InTrans's `GROUP BY`, so a candidate branch with no qualifying InTrans transactions still produces a row with `Demands = 0` instead of being invisible to the `< 3` filter. See "Two-Query Architecture" below.

## Criteria (adjustable — see query header for exact lines to change)

| Criterion | Current Value |
|-----------|---------------|
| Franchise | `D` |
| Candidate (local) branches | `7`, `14`, `95`, `91`, `96` — only these branches can be flagged |
| Other-branch universe | excludes `2`, `4` — broader pool used for `OtherBranchDemands`/`OtherLocationCount`, **not** limited to the 5 candidates |
| Local demand threshold | `< 3` (now genuinely includes 0) |
| Other-branch demand threshold | `>= 10` |
| Other-location threshold | `>= 5` (added 2026-07-09 per Ben — stacks on top of the `>= 10` demand threshold, does not replace it) |
| On-hand threshold | `< 1` (local branch only) |
| Excluded source | `AN` |
| Excluded SLC prefixes | `21`, `90`, `91`, `99` (any sub-code, e.g. 21A/21B) |
| Time window | 7 days – 18 months |

**Branch scope is asymmetric by design** (per Ben, 2026-07-07): the local/candidate branch is restricted to the 5 branches above, but the other-branch comparison pool stays broad (everyone except 2 & 4) so cross-branch demand totals aren't artificially shrunk. As of 2026-07-09 this is enforced directly in `SQL_Candidates`' WHERE clause (its own standalone query), not a post-aggregation M filter — see "Two-Query Architecture" below.

## Two-Query Architecture (as of 2026-07-09)

The query used to be a single SQL statement that both defined the candidate population (via InTrans `GROUP BY`) and computed other-branch totals — which meant a branch with zero InTrans activity had no row to filter on. It's now two queries:

1. **`SQL_Candidates`** — the base population. Queries `jdis_Part_Information` directly for the 5 candidate branches (on-hand `< 1`, franchise `D`, all part filters). This is what makes zero-demand branches visible: they exist as jdis rows independent of InTrans activity.
2. **`SQL_Demand`** — the broad "other branch" universe (excludes `2`, `4`), grouped from InTrans. Used to (a) look up each candidate branch's own `Demands` via a left join + `COALESCE`-to-0, and (b) build `TotalByPart` for `OtherBranchDemands`/`OtherLocationCount`.

Franchise is now checked via `jdis_Part_Information.pi_Franchise` in `SQL_Candidates` (previously only `InTrans.FRANCHISE`, which doesn't help for branches with zero InTrans rows). The two fields are expected to agree — worth a sanity check on the first live run.

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
`Branch`, `PartNumber`, `Description` (from jdis `pi_Description`, not the InTrans notation field), `Cost`, `Source`, `SLC`, `CommodityCode`, `CommodityGroup` (business-defined group name, e.g. Sprayer/Toys/Tillage; "Other" if unmapped), `DealerGroupCode`, `OnHandQty` (local branch's on-hand qty, always < 1), `Demands` (this branch's count over the 7-day–18-month window — can be 0), `OtherBranchDemands` (combined count at all other non-excluded branches — broad pool, not limited to the 5 candidates), `OtherLocationCount` (number of other branches with any demand, always >= 5 in the output).

## Notes / Gotchas
- **Description source:** `InTrans.DESCRIPTION` is a customer/notation field, not the part description — always pull description from `jdis_Part_Information.pi_Description`.
- **Branch asymmetry:** Candidate/local branch is restricted to 7, 14, 95, 91, 96. `OtherBranchDemands`/`OtherLocationCount` are computed against the broader "exclude 2 & 4" pool, not the 5-branch list — this is inherent now that they come from two separate SQL queries (`SQL_Candidates` vs `SQL_Demand`); collapsing them back into one query would understate cross-branch demand.
- **On-hand is local-only:** `OnHandQty` (`pi_On_Hand_Qty`) is filtered in `SQL_Candidates`' WHERE clause, which only touches the 5 candidate branches — it can't affect `OtherBranchDemands` because `SQL_Demand` is a separate query with no on-hand filter at all.
- **Zero-demand math:** `OtherBranchDemands = TotalDemand - Demands` and `OtherLocationCount = BranchCount - (1 if Demands > 0 else 0)` — both formulas account for the fact that a zero-demand candidate branch was never counted inside `TotalDemand`/`BranchCount` to begin with (see query header for the full walkthrough).
- **Source/SLC exclusions are broad:** applied in both SQL queries' WHERE clauses, affecting both sides of the comparison (consistent with the other part filters).
- **CommodityGroup source:** joined in from `CommodityCodeGroups.csv` on SharePoint (`SouthPlainsImplement-ReportSite`) — the exact same file used by the shared `dim_CommodityCode` Fabric dataflow (see `.claude/queries/dimensions/dim_CommodityCode.pq`, Steps 14-15). One file, two consumers — update it once and both pick up the change (Fabric on its next monthly refresh, this query next time it's run). Unmapped codes show `"Other"`, same convention as the Fabric side.
- **Run timing:** Run during off-peak hours (before 7 AM or after 5 PM) — `InTrans` is large and this queries the ODBC source directly, not the Lakehouse.
- **Last run:** 2026-06-08 (needs a fresh run to validate the 2026-07-09 restructure before sending to Ben)
- **Last updated:** 2026-07-09 — restructured into two SQL queries so zero-demand branches appear instead of being dropped; added `OtherLocationCount >= 5` filter (stacks on top of the `>= 10` demand threshold)

## Query Library
- Query lives in `queries/FranchiseD_LowDemand_Parts_CrossBranch.pq` in this project folder (moved from `.claude/queries/adhoc/` now that this has its own project).
- `CommodityGroup` lookup data is shared with the Fabric-side `dim_CommodityCode` dimension — see `.claude/queries/dimensions/CommodityCodeGroups.csv` (repo reference copy) and `.claude/queries/dimensions/dim_CommodityCode.pq` for the parallel implementation.
