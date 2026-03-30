# Bin Location Report — Project Summary

## Overview
This is a parts bin location lookup tool. Parts staff use it to find where a specific part is physically located within a branch's bin system. Given a part number and branch, it shows the bin assignment, quantities, and pricing.

**Status:** Production
**Workspace:** RP - Parts Reports
**Refreshed:** Weekly (Monday — Tier 3)

## Report Pages

| Page | Purpose |
|------|---------|
| Bin Location report | Single-page lookup — search/filter by part number, branch, franchise, dealer group |

## Data Model

### Tables
| Table | Type | Source | Description |
|-------|------|--------|-------------|
| `jdis_Part_Information` | Main | `dbo.jdis_Part_Information` (Lakehouse) | Parts with bin assignments, quantities, and pricing — 1M+ rows from JDIS source |
| `dim_Parts` | Shared Dimension | Shared | Parts catalog with attributes |
| `dim_BranchLocation` | Shared Dimension | Shared | Branch/location reference |
| `dim_Franchise` | Dedicated Dimension | Dedicated | Franchise lookup (JD, Kubota, etc.) |
| `dim_DealerGroupCode` | Dedicated Dimension | Dedicated | Dealer group classification |

## Key Columns (from `jdis_Part_Information`)
| Column | Description |
|--------|-------------|
| Branch | Branch identifier |
| PartNumber | Part number |
| Bin | Primary bin location |
| BulkBin | Bulk/overflow bin location |
| BinQty | Quantity in bin |
| QuantityOnHand | Total on-hand quantity |
| PackageQty | Package/unit quantity |
| InventoryCost | Total inventory cost at this location |
| Cost | Unit cost |
| SellPrice1 | Standard sell price |
| ListPrice | List/MSRP price |

## Source System Tables
| ERP Source | Description |
|-----------|-------------|
| JDIS (jdis_Part_Information) | John Deere Information System — parts master with bin assignments and quantities |

## Notes
- **Weekly refresh:** This report refreshes weekly on Monday, not daily. Bin location changes during the week will not appear until the next Monday refresh.
- **JDIS source:** The `jdis_` prefix on the source table indicates this data comes from the John Deere Information System rather than the standard ODBC connection.
- **Large dataset:** 1M+ parts — always filter by branch, franchise, or dealer group before exploring the full table.
