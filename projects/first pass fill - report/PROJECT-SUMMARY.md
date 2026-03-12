# First Pass Fill Report — Project Summary

## Purpose

Measures how often parts are filled on the first attempt — when a technician requests a part, does the branch have it in stock to fulfill immediately? Tracks Counter (over-the-counter), Shop (workshop/internal), and Total fill rates by branch, with rolling 12-month trends and prior-year comparison.

**Key question answered:** "Are we stocking the right parts to fill requests the first time — by branch, by channel, over the last 12 months?"

## Current Status (March 2026)

Production report, refreshed daily by 5 AM. Two main pages: branch scorecard and Rolling 12 trend chart.

Recent fixes:
- **Year rollover fix (March 2026):** All 13 Rolling 12 "Working" measures had hardcoded `DATE(2025, ...)`. Fixed to dynamic year resolution: `IF(selectedMonth <= MONTH(TODAY()), YEAR(TODAY()), YEAR(TODAY()) - 1)`.

## Report Pages

| Page | Purpose |
|------|---------|
| Branch Scorecard | Current R12 fill rate by branch — Counter %, Shop %, Total % with YOY trend |
| Rolling 12 Chart | Month-selector driven column chart — R12 vs. PY side-by-side |

## Semantic Model

**Location:** `report/current/First Pass Fill.SemanticModel/`

### Tables

| Table | Source | Notes |
|-------|--------|-------|
| `Fact_FirstPassFill` | `LH_Master_Data.Fact_FirstPassFill` | Pre-aggregated by branch/date/part/job code |
| `dim_BranchLocation` | `LH_Master_Data.dim_BranchLocation` | Branch filter |
| `dim_DateTable` | `LH_Master_Data.dim_DateTable` | Date dimension; includes `IsRolling12Months`, `IsRolling24Months` flags |
| `dim_Parts` | `LH_Master_Data.dim_Parts` | Parts lookup |
| `dim_JobCode` | Lakehouse | Job code lookup |
| `MeasuresTable` | Calculated (dummy partition) | Holds all DAX measures |

### Key Columns in Fact_FirstPassFill

Three channels × three metric types = 9 base columns, plus Total rollups:

| Channel | Attempts | Successes | Transfer Successes | Rate (pre-calc) |
|---------|----------|-----------|-------------------|-----------------|
| Counter | `CounterFirstPassAttempts` | `CounterFirstPassSuccesses` | `CounterTransferSuccesses` | `CounterFirstPassRate` |
| Workshop (Shop) | `WorkshopFirstPassAttempts` | `WorkshopFirstPassSuccesses` | `WorkshopTransferSuccesses` | `WorkshopFirstPassRate` |
| Total | `TotalFirstPassAttempts` | `TotalFirstPassSuccesses` | `TotalTransferSuccesses` | `TotalFirstPassRate` |

Additional: `StockedIndicator`, `StockImpactFlag`, `MeetsCounterTarget`, `MeetsTotalTarget`, `HasAnyActivity`

### Base Measures (in MeasuresTable.tmdl)

| Measure | Formula |
|---------|---------|
| `01. Counter %` | `CounterFirstPassSuccesses / CounterFirstPassAttempts` |
| `Counter+Transfer %` | `(CounterFirstPassSuccesses + CounterTransferSuccesses) / CounterFirstPassAttempts` |
| `Shop %` | `WorkshopFirstPassSuccesses / WorkshopFirstPassAttempts` |
| `Shop + Transfer %` | `(WorkshopFirstPassSuccesses + WorkshopTransferSuccesses) / WorkshopFirstPassAttempts` |
| `Total %` | `TotalFirstPassSuccesses / TotalFirstPassAttempts` |
| `Total + Transfer %` | `(TotalFirstPassSuccesses + TotalTransferSuccesses) / TotalFirstPassAttempts` |

### Rolling 12 Measure Pattern

The "Working" measures on page 2 use a month selector + dynamic year logic:

```dax
-- R12 end date (dynamic year to avoid hardcoded year bug)
SelectedMaxDate =
    EOMONTH(
        DATE(
            IF(MONTH(MAX(dim_DateTable[Date])) <= MONTH(TODAY()), YEAR(TODAY()), YEAR(TODAY()) - 1),
            MONTH(MAX(dim_DateTable[Date])),
            1
        ),
        0
    )
-- Rolling window: 12 months ending at SelectedMaxDate
RollingStartDate = EOMONTH(SelectedMaxDate, -12) + 1
```

PY measures shift the window back 12 months. `Period Verification` measure drives the subtitle text showing the selected period.

### dim_DateTable Boolean Flags

- `IsRolling12Months` — TRUE for dates in the last 12 months from today
- `IsRolling24Months` — TRUE for dates in the last 24 months from today
- Used by the simple R12/PY-R12 measures (branch scorecard page)

## Business Logic

- **First Pass Fill %:** Percentage of parts requests fulfilled from branch stock on first attempt
- **Transfer successes:** Parts transferred from another branch to fill the request (counted separately)
- **+Transfer %:** Fill rate including inter-branch transfers (higher than pure first pass)
- **Counter:** Over-the-counter sales channel
- **Shop/Workshop:** Internal shop/technician parts requests

## Refresh Schedule

- **Tier 1 — Daily:** Runs in Phase 5 of master pipeline, complete by ~5 AM
- Data sourced from `Fact_FirstPassFill` in `LH_Master_Data`

## Files in This Project

```
projects/first pass fill - report/
├── PROJECT-SUMMARY.md                    # This file
└── report/current/
    ├── First Pass Fill.pbix
    ├── First Pass Fill.Report/
    └── First Pass Fill.SemanticModel/
        └── definition/
            └── tables/
                ├── Fact_FirstPassFill.tmdl
                ├── MeasuresTable.tmdl
                ├── dim_BranchLocation.tmdl
                ├── dim_DateTable.tmdl
                ├── dim_Parts.tmdl
                └── dim_JobCode.tmdl
```
