# Negative On Hand / On Hand No Bin — Project Summary

## Overview
This report surfaces two types of inventory exceptions across all branches: parts showing a negative quantity in their bin location, and parts that have quantity on hand but no bin location assigned. Both conditions signal a gap between physical reality and the ERP system, which can cause fulfillment errors and inaccurate inventory valuation.

**Status:** Production
**Workspace:** RP - Parts Reports
**Refreshed:** Daily by 5 AM (Tier 1)

## Report Pages

| Page | Purpose |
|------|---------|
| Negative on Hand - On Hand no Bin | Single-page exception dashboard with KPI cards, part/branch breakdown, severity counts, and financial impact |

## Data Model

### Tables
| Table | Type | Source | Description |
|-------|------|--------|-------------|
| `Fact_NegativeOnHand_OnHandNoBin` | Fact | `dbo.Fact_NegativeOnHand_OnHandNoBin` (Lakehouse) | One row per part-branch with an inventory exception. Includes pre-classified issue type, severity, and financial impact computed in the dataflow. |
| `dim_BranchLocation` | Shared Dimension | `dbo.dim_BranchLocation` (Lakehouse) | Branch/location reference |
| `dim_DateTable` | Shared Dimension | `dbo.dim_DateTable` (Lakehouse) | Date dimension (no direct relationship to fact) |

### Relationships
- `Fact_NegativeOnHand_OnHandNoBin.Branch` → `dim_BranchLocation.BranchID`

## Key Measures

| Measure | Description |
|---------|-------------|
| Total Parts with Issues | Total count of parts with either exception type |
| Parts with Negative Bin Qty | Parts where the bin quantity has gone below zero |
| Parts with On Hand No Bin | Parts with quantity on hand but no bin location assigned |
| Parts with Both Issues | Parts flagged for both exception types simultaneously |
| Total Negative Inventory Value | Dollar value of the negative-bin discrepancy (ABS qty × cost) |
| Total Value No Bin | Dollar value of inventory with no bin assignment |
| Total Inventory Value at Risk | Pre-computed at-risk dollar value from the dataflow |
| Critical Issues | Count of parts classified as Critical severity |
| High Severity Issues | Count classified as High or High Volume severity |
| Parts Recently Requested | Issue parts that have had a customer request within 30 days |
| Parts with Back Orders | Issue parts that also have open backorders |

## Source System Tables
| ERP Source | Description |
|-----------|-------------|
| Parts inventory / bin location tables | Bin quantities, on-hand quantities, bin assignments, pending orders |

## Notes
- **Classification in dataflow:** `IssueType`, `IssueSeverity`, and `InventoryValueAtRisk` are computed in the dataflow before landing in the Lakehouse. DAX measures reference these as static values — changes to classification logic require a dataflow edit.
- **Point-in-time snapshot:** No date filter applies to the fact table. The report always shows the current state as of the latest daily refresh.
- **`DaysSinceLastRequest`:** Pre-computed integer column in the fact table. Measures like `Parts Recently Requested` use `<= 30` as the threshold.
