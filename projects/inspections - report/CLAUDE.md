# Inspections Report — Claude Context

## Status
**Production** ✅ — V2 live in RP-Service Reports. V1 archive in `reports/archive/` for reference only.
97% performance improvement over V1 (120 min → 14.5 min total pipeline).

**2026-08-13 CU/performance audit and fix (see `docs/superpowers/plans/2026-08-12-inspections-report-rebuild.md` for full detail):** the report had become the capacity's #2 CU consumer (~156K CU(s)/14 days). Two real bottlenecks found and fixed — `Fact_WorkOrderParts` had no incremental refresh (full re-import every time), and `ServiceRecommendations` was a DAX calculated table doing nested `GENERATE`/`CALCULATETABLE` work on every refresh (~8 min by itself). Fixed by adding incremental refresh to `Fact_WorkOrderParts` and replacing the `ServiceRecommendations` calculated table with a Dataflow Gen2/M query (`df_Fact_ServiceRecommendations`) that computes the same logic once, server-side. **Result: full semantic model refresh in the service dropped from ~7-8 min baseline (up to 14.5 min historically) to ~1 minute.** Same session, the measure library was also cleaned up — 54 of 182 measures were confirmed dead (design-iteration leftovers, superseded "-Fixed" versions, debug scaffolding) and deleted, 6 remaining measures had leftover version suffixes normalized, and all 128 survivors were organized into 11 display folders (see `documentation/dax/dax-measures-library.md` for the current folder taxonomy — the measure-by-measure descriptions in that file predate this cleanup and are being refreshed incrementally, not yet complete).

## Business Purpose
Complete inspection lifecycle tracking: Pending → In Progress → Completed. Branch-level goals management, predictive recommendations, real-time pending queue, work order drill-through. 15 branch locations.

## Semantic Model
**Path:** `reports/current/Inspections - V2.SemanticModel/definition/`

### Fact Tables (3)
| Table | Grain | Rows | Refresh | Source |
|-------|-------|------|---------|--------|
| Fact_LaborJobSummary | Job code × Work order | ~380K (actual, not ~50K as previously documented) | fast | wkothsub + wkmechwk + wkrofile |
| Fact_PendingInspections | Work order (pending only) | ~130 | fast | wkothsub + wkrofile |
| Fact_WorkOrderParts | Part × Invoice line | ~150K | **15 sec** (incremental refresh added 2026-08-13, was 10-18 min) | InTrans + Invoice |

### Shared Dimensions (from Lakehouse)
`dim_BranchLocation`, `dim_CustomerList`, `dim_DateTable`, `dim_Parts`

### Other Tables
Goals (Excel-based, 15 branch targets); ServiceRecommendations (**Dataflow Gen2/M-sourced as of 2026-08-13, was a DAX calculated table** — same predictive co-occurrence logic, now computed once via `df_Fact_ServiceRecommendations` instead of recomputed on every model refresh; source query at `queries/fact-tables/Fact_ServiceRecommendations.pq`)

## Critical Bug History — Do Not Re-Introduce
**Fact_WorkOrderParts join bug (FIXED):** Original query joined on work order number. Correct join is on **invoice number** (`InTrans.REF_NO = Invoice.InvoiceNumber`). Using work order produced only 186 rows instead of 150K. See `ARCHITECTURE.md` for full explanation.

## Report Pages (7)
Home, Details, Goals, Pending, Recommendations, Work Order List, Work Order Details (drill-through)

## Key Patterns

### Incremental Refresh (Raw Tables)
- wkothsub, wkmechwk, WKROFILE: incremental from 2023+, filter on `ModifiedDate`
- InTrans: date filter 2024+
- `RangeStart`/`RangeEnd` parameters must be **datetime**, not date

### Performance Optimizations (preserve these)
- Pre-aggregate punch data to job level before joining (prevents row explosion)
- Select only needed columns early in each query
- Explicit TEXT conversion for join keys (prevents type mismatch)
- Preserve query folding — avoid operations that break it

### Data Quality Scores
Validation framework with 0-100 scores for completeness, accuracy, consistency, timeliness, uniqueness. See `documentation/` for full data dictionary and validation reports.

## Pipeline
- Phase 4 of master orchestrator
- **Formerly Fact_WorkOrderParts was the known bottleneck at ~10-18 min — fixed 2026-08-13 via incremental refresh, now 15 sec.** Full semantic model refresh now ~1 min in the service (was ~7-8 min baseline, up to 14.5 min historically).
- Full pipeline docs: `documentation/pipelines/`
- Troubleshooting guide: `documentation/pipelines/troubleshooting-guide.md`

## Key Validation Finding
New report: 10,539 hours vs source 10,540 (-0.01% variance) ✅
Old report inflated by 101% due to vehicle table join duplicates — never use old queries.

## Files to Know
- `README.md` — complete project overview with all performance metrics
- `ARCHITECTURE.md` — grain decisions, optimization strategies, technical decisions log
- `validation-doc-hours.md` — validation methodology and results
- `documentation/dax/dax-measures-library.md` — all DAX measures with descriptions
- `documentation/pipelines/troubleshooting-guide.md` — pipeline failure runbook

## Documentation Status
- Obsidian stakeholder docs: ✅ Complete — `Data Projects/Reports/Inspections.md`
