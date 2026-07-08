# Franchise D — Low Demand Parts with Cross-Branch Activity — Project Summary

## Overview
This is an ad-hoc analysis (run via Power Query in Excel, not a Power BI report) that flags Franchise D parts with low demand at one branch but strong combined demand at all other branches. It's a stocking-opportunity finder: parts that are clearly selling well somewhere in the system but are under-stocked or inactive at a specific location.

**Status:** Active — re-run manually on request
**Requested by:** Corp Parts Manager
**Last run:** 2026-06-08
**Source:** ODBC (`dsn=EquipRDB64`) for `InTrans`/`jdis_Part_Information`, plus a SharePoint CSV (`CommodityCodeGroups.csv`) for the `CommodityGroup` lookup — no Lakehouse involved

## Logic Summary
1. Count Franchise D customer-invoice demand (`TYPE = 'I'`, `QTY > 0`) per branch/part over a window of 7 days ago to 18 months ago, excluding branches 2 and 4, and excluding Source "AN" and SLC families 21/90/91/99 (any sub-code).
2. Join to `jdis_Part_Information` to pull part attributes and apply stocking filters (no open PO, individually-stocked, returnable).
3. Roll up total demand and branch count per part across the broad other-branch pool (all branches except 2 & 4).
4. Flag branch/part combinations where **all** of the following hold: the branch is one of the 5 candidates (7, 14, 95, 91, 96), local demand is low (`< 3`), combined demand at all other branches is high (`>= 10`), and the local branch's on-hand quantity is `< 1`.

**Important asymmetry:** the 5-branch restriction and the on-hand filter only narrow *which branch/part rows get flagged* — they do not shrink the pool used to calculate the other-branches' combined demand. That pool always excludes just branches 2 & 4.

## Output
One row per branch/part flagged, with part attributes (description, cost, source, SLC, commodity code, commodity group, dealer group code, on-hand qty) and three demand metrics: this branch's demand, all-other-branches' combined demand, and how many other branches have any demand at all.

## Query
`queries/FranchiseD_LowDemand_Parts_CrossBranch.pq` — full header documentation of adjustable criteria is in the file itself and mirrored in this project's `CLAUDE.md`.

## Open Items
- Not yet converted to a Fabric dataflow / Power BI report — still a manual Excel Advanced Editor query.
- 2026-07-07 changes (7-day exclusion, 5-branch candidate restriction, on-hand filter, Source/SLC exclusions) implemented per Ben's clarified requirements — pending his review of results before further iteration or before this graduates to a full report.
- 2026-07-08: added `CommodityGroup` via the same SharePoint lookup CSV feeding the shared `dim_CommodityCode` Fabric dimension — one source file, kept in sync between this query and Fabric.
