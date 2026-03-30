# Physical Inventory — Project Summary

## Overview
This report manages the annual physical inventory count process across all branches. Rather than a single year-end count, the inventory is counted on a rolling basis throughout the year — parts are assigned to suggested count weeks, and the report tracks progress (bins counted vs. total) with a year-end deadline. The header shows a live countdown of weeks remaining.

**Status:** Production (V2)
**Workspace:** RP - Parts Reports
**Refreshed:** Daily (Tier 2)

## Report Pages

| Page | Purpose |
|------|---------|
| Physical Inventory | Main dashboard — count progress by branch, bins counted, target completion % |
| Not Counted | List of parts and bins not yet counted this year (hidden, accessible within report) |

## Data Model

### Tables
| Table | Type | Source | Description |
|-------|------|--------|-------------|
| `Physical Inventory` | Main | `dbo.Physical Inventory` (Lakehouse) | All inventory positions with stocktake date, bin/on-hand quantities, and count flags |
| `Weeks` | Reference | Local | 52-week schedule helper — maps suggested week numbers to display labels |
| `dim_BranchLocation` | Shared Dimension | Shared | Branch/location reference |
| `dim_DateTable` | Shared Dimension | Shared | Date dimension (no direct relationship — count logic uses TODAY()) |

### Relationships
- `Physical Inventory.Branch` → `dim_BranchLocation.BranchID`
- `Physical Inventory.[Suggested Week]` → `Weeks.[Week Number]`

## Key Measures

| Measure | Description |
|---------|-------------|
| Total Bins | Total distinct bin locations to count |
| Bins Counted | Bins where at least one part has been counted this calendar year |
| Weeks Remaining | Weeks left until December 31 — live countdown |
| Weeks Passed | Current week number — used to calculate expected completion |
| Target % | Expected completion based on elapsed time (Weeks Passed ÷ 52) |

## Source System Tables
| ERP Source | Description |
|-----------|-------------|
| Physical inventory / bin records | Part-by-bin inventory snapshot with last stocktake date |

## Notes
- **Annual reset:** The count resets on January 1 each year. A part counted December 31 is uncounted again on January 1.
- **Suggested Week scheduling:** Parts are pre-assigned to a suggested count week (1–52). This distributes the work evenly across the year rather than creating a year-end crunch.
- **V2 vs. non-V2:** Two versions exist in `reports/current/`. V2 (`Physical Inventory - V2`) is the active version with the week-scheduling feature. Confirm which is deployed in production.
- **Page name typo:** The main page is internally named "Pysical Inventory" (missing "h") — this is in the source file and not user-visible.
