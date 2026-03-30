# Customer Anatomy — Project Summary

## Overview
Customer health and engagement dashboard showing parts, service, and equipment revenue by customer across all 15 branches. Tracks CSM assignments, engagement levels, and the 11 designated "unique" customer groups. The flagship customer-facing report.

**Status:** In Development (V2 in RP - Sandbox, pending promotion)
**Workspace:** RP - Sandbox → RP - Parts Reports (after promotion)
**Refreshed:** Daily (Tier 1 target — daily by 8 AM)

## Report Pages

| Page | Purpose |
|------|---------|
| Overview | Customer-level KPI cards — revenue, engagement, CSM assignment |
| Parts Detail | Parts invoice and line-item drill-through |
| Service Detail | Service invoice and work order drill-through |
| Equipment Sales | Equipment revenue by customer |
| (Additional pages) | Comparison views, tooltips |

## Data Model

### Tables
| Table | Type | Source | Description |
|-------|------|--------|-------------|
| `Fact_CustomerPerformance` | Fact (L1) | Invoice | Aggregated customer × month KPIs — main table for summary views |
| `Fact_Parts_Invoices` | Fact (L2) | Invoice | Parts invoice detail — one row per invoice |
| `Fact_Parts_Detail` | Fact (L3) | InTrans | Parts transaction line items |
| `Fact_Service_Invoices` | Fact (L2) | Invoice | Service invoice detail |
| `Fact_Service_Detail` | Fact (L3) | wkothsub/wkmechwk | Work order job detail |
| `Fact_Service_Parts_Detail` | Fact (L3) | InTrans | Service-related parts lines (joins on invoice, not work order) |
| `Fact_Equipment_Sales` | Fact | Invoice | Equipment sales lines |
| `dim_CustomerList` | Shared Dimension | Lakehouse | Primary customer dim — CSM, Route Day, EngagementLevel, UniqueCustomerGroup, IsUniqueCustomer |
| `dim_BranchLocation` | Shared Dimension | Lakehouse | Branch reference |
| `dim_DateTable` | Shared Dimension | Lakehouse | Date dimension |
| `dim_Parts` | Shared Dimension | Lakehouse | Parts master |
| `dim_EngagedAcres` | Dimension | External CSV → Lakehouse | Engagement data (external source) |
| `lookup_UniqueCustomers_Invoice` | Lookup | Lakehouse | 11 unique customer group definitions |

## Key Measures
| Measure | Description |
|---------|-------------|
| Total Revenue | Parts + Service + Equipment revenue |
| Parts Revenue | Parts sales across all transaction types |
| Service Revenue | Service labor and parts revenue |
| YTD Revenue | Year-to-date revenue vs. prior year |
| Engagement Level | Customer engagement tier (from dim_EngagedAcres via LOOKUPVALUE) |
| Unique Customer Group | Which of the 11 special groups this customer belongs to |

## Source System Tables
- `Invoice` — Sales invoices (parts, service, equipment)
- `InTrans_Incremental` — Parts transaction lines (10M+ rows)
- `wkothsub` — Work order job detail (service)
- `wkmechwk` — Mechanic/technician work records

## Notes
- **Multi-level fact pattern:** L1 (aggregated KPIs) → L2 (invoice detail) → L3 (line items). Each level used at different drill-through depths.
- **Unknown Customer issue (~$1.6M service revenue unattributed):** `Invoice.BillToAccount` doesn't match `dim_CustomerList.CustomerNumber` for service invoices. See `INVESTIGATION-PLAN-Unknown-Customers.md` and `IMPLEMENTATION-PLAN-Service-Parts-Detail.md`.
- **Unique customer identification:** 11 groups identified via CustomerOrderNumber patterns, TradeType codes, or direct CustomerNumber matching. See `UNIQUE-CUSTOMER-FLAGS.md`.
- **V1 archive** exists at `reports/archive/` — reference only, different table names.
