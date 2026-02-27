# Inventory Analysis Report — Claude Context

## Status
**Sandbox** — V3 in RP-Sandbox, pending promotion to RP-Parts Reports (production).

## Business Purpose
Parts inventory health analysis across all branches. On-hand quantities, transaction history, invoice analysis, part performance. Heavy data volume requiring incremental refresh strategy.

## Semantic Model
**Path:** `report/current/Inventory Analysis V3.SemanticModel/definition/`

### Fact Tables (3)
| Table | Grain | Rows | Notes |
|-------|-------|------|-------|
| Fact_Inventory | Part × Branch | Medium | On-hand snapshot |
| Fact_Invoice_InventoryAnalysis | Invoice line item | Large | Parts invoice detail |
| Fact_Part_Transactions | Part transaction | **10M+** | InTrans — incremental refresh required |

### Dimension Tables (10+)
`dim_BranchLocation`, `dim_Parts`, `dim_Date`, `dim_DateFilter`, `dim_CommodityCode`, `dim_DealerGroupCode`, `dim_Franchise`, `dim_ModuleType`, `dim_SLC`, `dim_Source`, `dim_VendorCode`, `dim_PaymentMethod`

### Helper Tables
`BranchFranchiseSlicer`, `ConditionalFormatMeasures`, `HeroCard Settings`, `Measures Table`, `PackageQtyMeasures`, `Relationships Table`, `Tables`, `Data Refresh`

## Critical — Incremental Refresh
`Fact_Part_Transactions` sources from `InTrans_Incremental` (10M+ rows). This table **must** use `RangeStart`/`RangeEnd` datetime parameters. Do not switch to full refresh — it will time out and spike CU usage.

## Key Patterns

### Extra Dimensions vs Other Reports
This report has more classification dimensions than others (SLC, CommodityCode, DealerGroupCode, Franchise, VendorCode, PaymentMethod). These are all pre-built in Lakehouse and available as shared dimensions.

### DateFilter Dimension
Separate `dim_DateFilter` table (in addition to `dim_Date`) — used for user-controlled date range slicers independent of the main date dimension. Common pattern in inventory reports.

### BranchFranchiseSlicer
Helper table for synchronized branch/franchise filtering. Do not remove — used by multiple visuals.

### HeroCard Settings / ConditionalFormatMeasures
Configuration tables for visual formatting. Values here drive conditional formatting rules and hero card thresholds in the report. Changes affect visual appearance, not data.

## Queries
**Path:** `queries/fact tables/*.pq`
- `Fact_Inventory.pq` — on-hand snapshot
- `Fact_Invoice_InventoryAnalysis.pq` — invoice detail
- `Fact_Part_Transactions_Incremental.pq` — uses RangeStart/RangeEnd, sources from InTrans_Incremental

## Documentation Status
- Obsidian stakeholder docs: ✅ Complete — `Data Projects/Reports/Inventory Analysis.md`

## Promotion Checklist (before moving to production)
- [ ] Validate row counts match between Sandbox and expected production values
- [ ] Confirm InTrans_Incremental refresh completes within F4 capacity limits
- [ ] Verify all 10+ dimension relationships are intact after promotion
- [ ] Check Fact_Part_Transactions row count (expect ~10M)
- [ ] Test all slicer combinations (Branch × Franchise, CommodityCode, DateFilter)
- [ ] Confirm conditional formatting thresholds are set correctly in HeroCard Settings
