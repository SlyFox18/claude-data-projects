# Unique Parts Customers — Project Summary

## Overview
Tracks parts sales, cost, and margin for the 11 designated "unique" customer groups — providing both line-item (InTrans) and order-level (Invoice) views. Used by sales leadership and CSMs to monitor high-priority customer account activity and YTD/PYTD performance.

**Status:** Production
**Workspace:** RP - Parts Reports
**Refreshed:** Daily (Tier 2 — after 8 AM)

## Report Pages

| Page | Purpose |
|------|---------|
| Unique Parts | Main sales view — all unique customer activity by customer group, branch, and time |
| Comparison | Side-by-side comparison (hidden) |
| Customer Details | Individual customer drill-down (hidden) |

## Data Model

### Tables
| Table | Type | Source | Description |
|-------|------|--------|-------------|
| `Fact_InTrans_UniqueCustomers` | Fact | Lakehouse | Parts transaction line items for unique customers — SaleValue, CostValue, MarginAmount, Qty, SalesType |
| `Fact_Invoice_UniqueCustomers` | Fact | Lakehouse | Invoice-level records for unique customers — PartsSaleValue, PartsCostValue, MarginAmount |
| `dim_UniqueCustomers` | Dimension | Lakehouse | Unique customer group definitions (11 groups) |
| `dim_CustomerList` | Shared Dimension | Lakehouse | Full customer attributes — CSM, route day, engagement level |
| `dim_BranchLocation` | Shared Dimension | Lakehouse | Branch reference |
| `dim_DateTable` | Shared Dimension | Lakehouse | Date dimension |

### Relationships
Both fact tables join to `dim_UniqueCustomers`, `dim_CustomerList`, `dim_BranchLocation`, and `dim_DateTable`. The dual customer relationship (to both `dim_UniqueCustomers` and `dim_CustomerList`) allows filtering by unique customer group while also accessing full customer attributes.

## Key Measures
| Measure | Description |
|---------|-------------|
| `InTrans_Sales` | Total sales from parts transaction lines |
| `Invoice_Sales` | Total sales from invoice records |
| `Total_Sales` | Combined InTrans + Invoice sales |
| `Total_Margin` | Total_Sales - Total_Cost |
| `Total_Margin%` | Margin as a percent of sales |
| `YTD_Sales` | Year-to-date sales (dynamic year selection) |
| `PYTD_Sales` | Prior year-to-date sales |

## Source System Tables
- `InTrans_Incremental` — Parts transaction lines (10M+ rows, incremental refresh)
- `Invoice` — Invoice header data

## Notes
- The 11 unique customer groups are defined in `lookup_UniqueCustomers_Invoice`. See `CROSS-REPORT-FLAGS.md` for full group definitions.
- Several YTD/PYTD measures have hardcoded year values (2024/2025) that need updating annually.
- Two fact table grains coexist in this report: InTrans (line-item) and Invoice (order-level). `Total_Sales` adds both together.
