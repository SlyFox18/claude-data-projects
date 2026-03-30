# Labor Performance — Claude Context

## Report Overview
- **Business purpose:** Tracks technician efficiency, productivity, and overall labor performance by branch — answers "how much billable work did our technicians produce relative to what they were scheduled and what they punched in for?"
- **Primary users:** Service managers, branch managers
- **Workspace:** RP - Service Reports
- **Refresh tier:** Tier 2 — Daily
- **Status:** Production (current version is "Labor Performance V2"; archive folder contains V1)

## Semantic Model

### Fact Tables
| Table | Grain | Key Fields | Notes |
|-------|-------|------------|-------|
| `TechnicianEfficiency` | One row per technician-branch-month | TechCode, Branch, DateKey, InvoiceHours, ReworkHours, BilledHours, EfficiencyRateNumerator, EfficiencyRateDenominator | Pre-aggregated by month in the dataflow. `EfficiencyRateNumerator` / `EfficiencyRateDenominator` columns exist so Efficiency measure can aggregate correctly across groups. |
| `TechnicianPunchedTime` | One row per technician-branch-day (or period) | TechCode, Branch, DateKey, HoursWorked | Actual time punched into the system |
| `TechnicianAttendance` | One row per technician-branch-period | TechCode, Branch, DateKey, AttendanceHours | Scheduled/available hours — what they were supposed to be there for |

### Dimensions
| Table | Source | Key Relationship |
|-------|--------|-----------------|
| `dim_Technician_Code_Names` | Dedicated dimension | `TechCode` → `TechnicianCode` (all 3 fact tables) |
| `dim_BranchLocation` | Shared Lakehouse dimension | `Branch` → `BranchID` (all 3 fact tables) |
| `dim_DateTable` | Shared Lakehouse dimension | `DateKey` → `Date` (all 3 fact tables) |
| `Data Refresh` | Calculated table | Refresh timestamp display |

### Key Measures
| Measure | Formula Description |
|---------|---------------------|
| `Efficiency` | `SUM(EfficiencyRateNumerator) / SUM(EfficiencyRateDenominator)` — billable hours produced relative to benchmark |
| `Productivity` | `SUM(HoursWorked) / SUM(AttendanceHours)` — hours worked vs. hours scheduled |
| `Labor Performance` | `[Efficiency] * [Productivity]` — composite KPI |
| `Total Hours` | Sum of `InvoiceHours` from TechnicianEfficiency |
| `Available Hours` | Sum of `AttendanceHours` from TechnicianAttendance |
| `Worked Hours` | Sum of `HoursWorked` from TechnicianPunchedTime |
| `Rework Hours` | Sum of `ReworkHours` — hours spent on warranty/rework |
| `LY Hours` | Prior year Total Hours (CALCULATE with DATEADD -1 YEAR) |

## Report Pages
| Page | Display Name | Purpose | Visibility |
|------|-------------|---------|------------|
| e384167396533ecc066e | Labor Performance | Main dashboard — branch/technician matrix with KPIs | Visible |
| 17efffb5c281fb10f304 | Monthly Trends | Trend charts over time | Hidden in view mode |

## Data Flow
```
EquipRDB (ODBC)
  └─ Technician work order/invoice data → TechnicianEfficiency
  └─ Time punch records → TechnicianPunchedTime
  └─ Scheduling/attendance records → TechnicianAttendance
                │
                ▼
  LH_Master_Data (Lakehouse)
  └─ TechnicianEfficiency, TechnicianPunchedTime, TechnicianAttendance
  └─ dim_Technician_Code_Names (technician name lookup)
  └─ dim_BranchLocation, dim_DateTable (shared)
                │
                ▼
            Labor Performance V2 Report
```

## Known Issues & Gotchas

### Three Fact Tables — All Join to Same Dims
All three fact tables (`TechnicianEfficiency`, `TechnicianPunchedTime`, `TechnicianAttendance`) are independently related to `dim_DateTable`, `dim_BranchLocation`, and `dim_Technician_Code_Names`. Filter context from slicers on branch/date/technician propagates to all three simultaneously — this is the intended pattern.

### `EfficiencyRateNumerator` / `EfficiencyRateDenominator` Design
Rather than storing a pre-computed Efficiency%, the dataflow stores the numerator and denominator separately. This allows the Efficiency measure to sum-then-divide correctly across any grouping without weighted average errors. Do not replace this with a simple average of a pre-computed % column.

### V1 Archive
An older version of the report exists in `report/archive/`. The archive uses different table names (`TechnicianInvoice`, `Dim_Branch`, `dDate`) and a different model structure. The current V2 uses shared Lakehouse dimensions. Do not use archive TMDL as reference for V2.

### `Monthly Trends` Page Hidden
The Monthly Trends page is hidden in view mode but exists in the report file. It may be accessible via bookmarks or URL parameters.

## Refresh Pipeline Position
- **Phase:** Phase 5 (Semantic Models) in Master Orchestrator — Tier 2, can finish after 8 AM
- **Dependencies:** `TechnicianEfficiency`, `TechnicianPunchedTime`, `TechnicianAttendance` must refresh (Phase 4 Facts); `dim_Technician_Code_Names` must refresh (Phase 3 Dims)
- Service-side fact tables

## Documentation Status
- In-repo docs: ✅ CLAUDE.md | ✅ PROJECT-SUMMARY.md
- Obsidian stakeholder docs: ✅ Complete — `Data Projects/Reports/Labor Performance.md`
