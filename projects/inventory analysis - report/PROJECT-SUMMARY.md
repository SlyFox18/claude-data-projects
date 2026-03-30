# Inventory Analysis — Project Summary

## Overview
Parts inventory health analysis across all branches — on-hand quantities, transaction history, invoice analysis, and part performance. High data volume report (10M+ transaction rows) requiring incremental refresh. Used by parts managers and leadership to understand what's on the shelf and how parts are moving.

**Status:** Sandbox (V3 in RP - Sandbox, pending promotion)
**Workspace:** RP - Sandbox → RP - Parts Reports (after promotion)
**Refreshed:** Daily (Tier 1 target — daily by 8 AM)

## Report Pages

| Page | Purpose |
|------|---------|
| On Hand | Current inventory snapshot by branch and part |
| Transaction History | Parts movement history — sales, returns, adjustments |
| Invoice Analysis | Invoice-level parts sales detail |
| Part Performance | Individual part turn, margin, and activity metrics |

## Data Model

### Tables
| Table | Type | Source | Description |
|-------|------|--------|-------------|
| `Fact_Inventory` | Fact | Lakehouse | On-hand snapshot — one row per part × branch |
| `Fact_Invoice_InventoryAnalysis` | Fact | Lakehouse | Parts invoice line detail — large table |
| `Fact_Part_Transactions` | Fact | Lakehouse (InTrans) | Parts transaction lines — **10M+ rows, incremental refresh** |
| `dim_BranchLocation` | Shared Dimension | Lakehouse | Branch reference |
| `dim_Parts` | Shared Dimension | Lakehouse | Parts master |
| `dim_Date` | Shared Dimension | Lakehouse | Primary date dimension |
| `dim_DateFilter` | Dimension | Lakehouse | User-controlled date range slicer (independent of dim_Date) |
| `dim_CommodityCode` | Dimension | Lakehouse | Parts commodity classification |
| `dim_DealerGroupCode` | Dimension | Lakehouse | Dealer group classification |
| `dim_Franchise` | Shared Dimension | Lakehouse | Franchise (JD, Case, etc.) |
| `dim_ModuleType` | Dimension | Lakehouse | Module/department type |
| `dim_SLC` | Dimension | Lakehouse | Stock level code |
| `dim_Source` | Dimension | Lakehouse | Transaction source |
| `dim_VendorCode` | Dimension | Lakehouse | Vendor reference |
| `dim_PaymentMethod` | Dimension | Lakehouse | Payment method classification |
| `BranchFranchiseSlicer` | Helper | Lakehouse | Synchronized branch/franchise slicer |
| `HeroCard Settings` | Helper | Calculated | Drives conditional formatting thresholds |
| `ConditionalFormatMeasures` | Helper | Calculated | Conditional formatting configuration |

## Key Measures
| Measure | Description |
|---------|-------------|
| On Hand Qty | Current quantity in stock |
| On Hand Value | On-hand quantity × cost |
| Parts Sales $ | Total parts sales revenue |
| Parts Margin % | Margin as percent of sales |
| Inventory Turn | 12-month sales / average on-hand value |

## Source System Tables
- `InTrans_Incremental` — Parts transaction lines (10M+ rows, incremental refresh)
- `Invoice` — Invoice header and line data
- `jdis_Part_Information` — Parts master data from John Deere Information System

## Notes
- **Incremental refresh is critical:** `Fact_Part_Transactions` (10M+ rows) must use RangeStart/RangeEnd datetime parameters. Full refresh will timeout and spike CU usage on F4 capacity.
- **Two date tables:** `dim_Date` for standard date filtering; `dim_DateFilter` for independent date range controls on specific visuals.
- **BranchFranchiseSlicer:** Do not remove — required by multiple visuals for synchronized filtering.
- See CLAUDE.md promotion checklist before moving to production.
