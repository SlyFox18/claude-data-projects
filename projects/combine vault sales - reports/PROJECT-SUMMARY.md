# Combine Vault Sales — Project Summary

## Overview
This report focuses exclusively on Branch 12 — the "Combine Vault" — a specialized parts location for combine equipment. It tracks sales performance, inventory value, turn rate, margin, and inter-branch transfer activity. The report also includes a restocking tool and transfer management view for the branch team.

**Status:** Production
**Workspace:** RP - Parts Reports
**Refreshed:** Daily (Tier 2)

## Report Pages

| Page | Purpose |
|------|---------|
| Combine Vault Sales | Main dashboard — sales, rolling 12-month metrics, inventory turns, YTD growth |
| Restock Tool | Hidden — inventory restocking analysis tool (action page) |
| Transfer Branch | Hidden — transfer activity detail by destination branch |
| Information | Hidden — reference/help information |

*Two tooltip pages exist (hidden) for hover context.*

## Data Model

### Tables
| Table | Type | Source | Description |
|-------|------|--------|-------------|
| `Fact_Branch12_Transactions` | Fact | `dbo.Fact_Branch12_Transactions` (Lakehouse) | All Branch 12 parts transactions — sales and transfers with value, cost, margin |
| `dim_Branch12_Parts` | Dedicated Dimension | `dbo.dim_Branch12_Parts` (Lakehouse) | Branch 12 parts inventory snapshot with current inventory cost |
| `dim_Parts` | Shared Dimension | Shared | Full parts catalog (linked through dim_Branch12_Parts) |
| `dim_BranchLocation` | Shared Dimension | Shared | Branch reference (used for transfer destination) |
| `dim_DateTable` | Shared Dimension | Shared | Date dimension |
| `Stock Status Categories` | Reference | Local | Stock status classification categories |
| `YTD Metrics` | Reference | Local | YTD comparison benchmarks |

### Relationships
- `Fact_Branch12_Transactions.PartNumberKey` → `dim_Branch12_Parts.PartNumberKey`
- `dim_Branch12_Parts.PartNumberKey` ↔ `dim_Parts.PartNumberKey` (bidirectional)
- `Fact_Branch12_Transactions.TransferBranch` → `dim_BranchLocation.BranchID`
- `Fact_Branch12_Transactions.DateKey` → `dim_DateTable.DateKey`

## Key Measures

| Measure | Description |
|---------|-------------|
| Sales | Branch 12 parts sales (IsSale = TRUE) for selected period |
| Sales R12 | Rolling 12-month sales total |
| Inventory Value | Current inventory at cost from Branch 12 parts dimension |
| Current Turn | Cost of sales R12 ÷ Inventory Value — how fast stock is turning |
| Margin $ | Sales margin dollars |
| Margin % | Margin as a percentage of sales |
| Previous Year Sales | Same period prior year for comparison |
| Sales YTD Growth $ | Current YTD vs. same period last year |

## Source System Tables
| ERP Source | Description |
|-----------|-------------|
| InTrans / parts transactions (Branch 12 only) | Sales and transfer transactions at Branch 12 |
| Parts inventory (Branch 12) | On-hand quantities and inventory cost for Branch 12 parts |

## Notes
- **Branch 12 only:** This report is scoped exclusively to Branch 12 (the Combine Vault). It is not a report about all branches — use Inventory Analysis or Parts on Open Orders for cross-branch views.
- **`IsSale` / `IsTransfer` flags:** Transactions are pre-classified in the dataflow. Sales and transfers are in the same fact table but separated by these boolean flags.
- **`dim_Branch12_Parts` vs. `dim_Parts`:** Branch 12 has its own parts dimension (with current inventory cost) that bridges to the shared `dim_Parts` catalog. Part filtering normally goes through `dim_Branch12_Parts`.
