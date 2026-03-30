# Parts Not Re-Ordered 24 Hours — Project Summary

## Overview
This report identifies parts that were sold at the counter or on an invoice but were not placed back on order within 24 business hours of the sale. It's an operational tool — parts managers check it daily to catch restocking gaps before inventory runs short. The 24-hour window is in business hours (weekends excluded).

**Status:** Production
**Workspace:** RP - Parts Reports
**Refreshed:** Daily by 5 AM (Tier 1) + intraday via `PartsNotReordered_QuickRefresh` pipeline

## Report Pages

| Page | Purpose |
|------|---------|
| Parts not on Order | Main dashboard — KPI hero card + part/branch detail table with hover tooltips showing sales history |

*Three tooltip pages exist (hidden) providing sales history context on hover.*

## Data Model

### Tables
| Table | Type | Source | Description |
|-------|------|--------|-------------|
| `Fact_PartsNotReordered` | Fact | `dbo.Fact_PartsNotReordered` (Lakehouse) | Parts transactions (counter + invoice only) with sale details, current on-order qty, bin qty, and 12-month sales history |
| `dim_BranchLocation` | Shared Dimension | `dbo.dim_BranchLocation` (Lakehouse) | Branch/location reference |
| `dim_DateTable` | Shared Dimension | `dbo.dim_DateTable` (Lakehouse) | Date dimension — used by the business hours calculation to identify weekends |

### Relationships
- `Fact_PartsNotReordered.Branch` → `dim_BranchLocation.BranchID`
- `Fact_PartsNotReordered.TransDatetime` → `dim_DateTable.Date`

## Key Measures

| Measure | Description |
|---------|-------------|
| Parts Not Reordered | Count of distinct parts sold within 24 business hours that have no active reorder |
| Branches Affected | Count of branches with at least one unreordered part |
| Total Qty Not Reordered | Total units sold across all unreordered parts |
| Times This Part Not Reordered | How many times this specific part has gone unreordered (context-sensitive — for use in detail table) |

*Tooltip measures (Sales History HTML, Trend Arrow, etc.) provide hover context cards on the main table.*

## Source System Tables
| ERP Source | Description |
|-----------|-------------|
| Parts transactions (counter + invoice) | Sale date/time, part number, branch, quantity, on-order status |
| Parts master | 12-month and prior 12-month sales units for trend context |

## Notes
- **Business hours logic:** Weekend days are excluded from the 24-hour window. A part sold Friday at 4 PM and not reordered by Monday at 4 PM is within the 24 business-hour window (Saturday and Sunday don't count).
- **Filter:** Only counter (`C`) and invoice (`I`) transaction types are included. Returns and adjustments are excluded.
- **`OnOrder` blank = not reordered:** If the on-order quantity is missing or zero, the part is considered unreordered.
- **Quick-refresh pipeline:** This report refreshes both in the nightly pipeline and via a separate intraday pipeline, making it more current than most Tier 1 reports.
