# Inspections Report — Claude Context

## Status
**Production** ✅ — V2 live in RP-Service Reports. V1 archive in `reports/archive/` for reference only.
97% performance improvement over V1 (120 min → 14.5 min total pipeline).

## Business Purpose
Complete inspection lifecycle tracking: Pending → In Progress → Completed. Branch-level goals management, predictive recommendations, real-time pending queue, work order drill-through. 15 branch locations.

## Semantic Model
**Path:** `reports/current/Inspections - V2.SemanticModel/definition/`

### Fact Tables (3)
| Table | Grain | Rows | Refresh | Source |
|-------|-------|------|---------|--------|
| Fact_LaborJobSummary | Job code × Work order | ~50K | 3 min | wkothsub + wkmechwk + wkrofile |
| Fact_PendingInspections | Work order (pending only) | ~100 | 1.5 min | wkothsub + wkrofile |
| Fact_WorkOrderParts | Part × Invoice line | ~150K | 10 min | InTrans + Invoice |

### Shared Dimensions (from Lakehouse)
`dim_BranchLocation`, `dim_CustomerList`, `dim_DateTable`, `dim_Parts`

### Other Tables
Goals (Excel-based, 15 branch targets), Recommendations (DAX calculated table, predictive)

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
- Fact_WorkOrderParts is the **known bottleneck** at ~10-18 min (target for incremental refresh)
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
