# Labor Performance — Project Summary

## Overview
This report measures technician performance across three dimensions: Efficiency (billable hours produced vs. benchmark), Productivity (hours worked vs. hours scheduled), and the combined Labor Performance score. Branch managers and service managers use it to monitor individual technician output and identify performance trends.

**Status:** Production (V2 — V1 archived)
**Workspace:** RP - Service Reports
**Refreshed:** Daily (Tier 2)

## Report Pages

| Page | Purpose |
|------|---------|
| Labor Performance | Main dashboard — KPI matrix by branch and technician with current period metrics |
| Monthly Trends | Trend view over time (hidden in standard navigation) |

## Data Model

### Tables
| Table | Type | Source | Description |
|-------|------|--------|-------------|
| `TechnicianEfficiency` | Fact | `dbo.TechnicianEfficiency` (Lakehouse) | Monthly aggregated: invoice hours, rework hours, billed hours, delay hours, efficiency rate numerator/denominator |
| `TechnicianPunchedTime` | Fact | `dbo.TechnicianPunchedTime` (Lakehouse) | Actual hours punched into the time system by technician |
| `TechnicianAttendance` | Fact | `dbo.TechnicianAttendance` (Lakehouse) | Scheduled/available hours by technician |
| `dim_Technician_Code_Names` | Dedicated Dimension | Dedicated to this report | Technician code → name lookup |
| `dim_BranchLocation` | Shared Dimension | Shared | Branch/location reference |
| `dim_DateTable` | Shared Dimension | Shared | Date dimension |

### Relationships
- All three fact tables relate independently to `dim_DateTable`, `dim_BranchLocation`, and `dim_Technician_Code_Names`
- Date slicers filter all three tables simultaneously

## Key Measures

| Measure | Description |
|---------|-------------|
| Efficiency | Invoice hours produced ÷ benchmark denominator — how much billable work they produced |
| Productivity | Hours worked ÷ hours scheduled — how much of their scheduled time they were actively working |
| Labor Performance | Efficiency × Productivity — composite score |
| Total Hours | Invoice hours from efficiency data |
| Available Hours | Scheduled attendance hours |
| Worked Hours | Actual punched-in hours |
| Rework Hours | Hours spent on rework or warranty re-do |
| LY Hours | Prior year total hours for comparison |

## Source System Tables
| ERP Source | Description |
|-----------|-------------|
| Work order / invoice data | Technician hours billed per invoice |
| Time punch system | Technician clock-in/out records |
| Scheduling system | Planned attendance hours |

## Notes
- **V2 redesign:** The current model uses shared Lakehouse dimensions (`dim_BranchLocation`, `dim_DateTable`) unlike V1 which had local dimension tables. The archive folder contains the V1 model for reference only.
- **Efficiency numerator/denominator pattern:** Efficiency is stored as two additive columns (numerator and denominator) so it aggregates correctly across any grouping — this is intentional, do not simplify to a pre-computed % column.
