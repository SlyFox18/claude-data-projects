# Parts Promo — Project Summary

## Overview
Tracks promotional parts discounts — which parts are being discounted, how much, and the net impact on sales and margin. Compares rolling 12 months of promo activity against the prior year rolling 12. Used by parts managers and sales leadership to understand the cost and scope of promotional pricing.

**Status:** Sandbox (pending promotion to production)
**Workspace:** RP - Sandbox → RP - Parts Reports (after promotion)
**Refreshed:** Daily (Tier 1 target — not yet in production pipeline)

## Report Pages

| Page | Purpose |
|------|---------|
| R12 -PY R12 | Rolling 12 months vs. prior year rolling 12 — discount amounts, net sales, margin impact |
| Details | Transaction-level detail view (hidden) |
| Net Sales % | Net margin percentage analysis (hidden) |

## Data Model

### Tables
| Table | Type | Source | Description |
|-------|------|--------|-------------|
| `Fact_PartsPromo` | Fact | Lakehouse | One row per promo line item — REF_NO, PART_NO, SaleValue (negative = discount), CostValue, Branch, CustomerNo, Franchise |
| `Fact_InTrans_AllPromo` | Fact | Lakehouse | All InTrans lines for orders that included promos — provides full order context |
| `dim_RepairOrder` | Dimension | Lakehouse | Order-level aggregates: TotalPartsSales, TotalPartsCost, OriginalMargin, NetOrderValue, NetMargin |
| `dim_PromoType` | Dimension | Lakehouse | Classifies which parts are promotional parts |
| `dim_Parts` | Shared Dimension | Lakehouse | Parts master — descriptions, pricing |
| `dim_CustomerList` | Shared Dimension | Lakehouse | Customer reference |
| `dim_BranchLocation` | Shared Dimension | Lakehouse | Branch reference |
| `dim_DateTable` | Shared Dimension | Lakehouse | Date dimension |
| `Sales Category` | Reference | Lakehouse | Sales type categories |

## Key Measures
| Measure | Description |
|---------|-------------|
| `Discount` | Total discount amount (absolute value — promo SaleValues are negative) |
| `Discount %` | Discount as a percentage of original sales |
| `Original Sale Value` | Total parts sales from orders that had promo discounts |
| `Net Sales Value` | Original sales minus the discount |
| `Net Margin $` | Net margin after discounts are applied |
| `Net Margin %` | Net margin as a percentage of net sales |
| `Promo Count` | Number of promo line items |
| `Orders with Promos` | Count of distinct orders that included a promo |
| `Rolling 12M Discount` | Last 12 months of discount activity |
| `Rolling 12M Net Sales` | Last 12 months net sales on promo orders |

## Source System Tables
- `dbo.Fact_PartsPromo` — Promo discount transactions
- `dbo.Fact_InTrans_AllPromo` — Full InTrans lines for promo orders

## Notes
- Promo discounts are stored as **negative SaleValues** in Fact_PartsPromo. All discount measures use ABS().
- The cost/sales/margin measures use a LOOKUPVALUE (detail context) / TREATAS (aggregate context) dual pattern because dim_RepairOrder stores order-level totals rather than line-level amounts.
- See `PROJECT-STATUS.md` and `MIGRATION-NOTES.md` for migration history and promotion checklist.
- An archived V2 version exists at `report/archive/` with different table names — use `report/current/` only.
