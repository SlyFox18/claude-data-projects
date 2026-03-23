# First Pass Fill Report — Project Summary

## Purpose

Measures how often parts are filled on the first attempt — when a technician requests a part, does the branch have it in stock to fulfill immediately? Tracks Counter (over-the-counter), Shop (workshop/internal), and Total fill rates by branch, with rolling 12-month trends and prior-year comparison.

**Key question answered:** "Are we stocking the right parts to fill requests the first time — by branch, by channel, over the last 12 months?"

## Current Status (March 2026)

Production report, refreshed daily by 5 AM (Tier 1, Phase 4 Wave B).

Recent fixes:
- **Year rollover fix (March 2026):** All 13 Rolling 12 "Working" measures had hardcoded `DATE(2025, ...)`. Fixed to dynamic year resolution: `IF(selectedMonth <= MONTH(TODAY()), YEAR(TODAY()), YEAR(TODAY()) - 1)`.
- **Rolling 12 Trend fix (March 2026):** The Trends page line chart measure was anchored to `MAX(dim_DateTable[Date])` which (1) responded to year slicers and (2) plotted future months because the date table has forward dates. Fixed to use `TODAY()` as the anchor with `REMOVEFILTERS(dim_DateTable)` + `FILTER(ALL(...))` so the measure is slicer-independent and caps at today. See `CLAUDE.md` for full details.

## Report Pages

| Page | Visibility | Purpose |
|------|-----------|---------|
| First Pass Fill | Visible | Main scorecard: R12 fill rates by branch for Counter, Shop, and Total channels with conditional formatting |
| Rolling 12 vs PY | Hidden (button nav) | Month-selector bar chart — R12 vs prior-year R12 side-by-side by branch |
| YTD | Hidden (button nav) | Year-to-date fill rates by branch |
| Summary | Hidden (button nav) | Aggregated summary; date slicer has `NoFilter` interactions with several chart visuals |
| Trends | Hidden (button nav) | Month-by-month rolling 12-month trend line, anchored to TODAY(); navigated via "Show Rolling 12 Trend" button |

Pages other than "First Pass Fill" are hidden from normal page navigation (`HiddenInViewMode`) and are reached via buttons on the main page.

## Semantic Model

**Location:** `report/current/First Pass Fill.SemanticModel/`

### Tables

| Table | Type | Source | Notes |
|-------|------|--------|-------|
| `Fact_FirstPassFill` | Fact | `LH_Master_Data.Fact_FirstPassFill` | Pre-aggregated by branch/date/part/job code; ~734K rows |
| `dim_BranchLocation` | Dimension | `LH_Master_Data` (shared) | Branch filter |
| `dim_DateTable` | Dimension | `LH_Master_Data` (shared) | Date dimension with `IsRolling12Months`, `IsRolling24Months`, `IsYearToDate` flags |
| `dim_Parts` | Dimension | `LH_Master_Data` (shared) | Parts catalog lookup |
| `dim_JobCode` | Dimension | `LH_Master_Data` (dedicated) | Job codes with equipment type, service complexity, work type flags |
| `Date_Supplemental` | Calculated DAX table | In-model | Supplemental date attributes; hardcoded range 2022–2024 — stale as of 2025 |
| `Metric Names` | Slicer table | In-model | Channel selector: Counter, Shop, Total (and +Transfer variants) |
| `Performance Metrics` | Slicer table | In-model | Metric selector for performance comparison pages |
| `MeasuresTable` | Calculated (dummy partition) | In-model | Holds all DAX measures |

### Key Columns in Fact_FirstPassFill

Three channels × three metric types, plus Total rollups:

| Channel | Attempts | Successes | Transfer Successes | Pre-calc Rate |
|---------|----------|-----------|-------------------|--------------|
| Counter | `CounterFirstPassAttempts` | `CounterFirstPassSuccesses` | `CounterTransferSuccesses` | `CounterFirstPassRate` |
| Workshop (Shop) | `WorkshopFirstPassAttempts` | `WorkshopFirstPassSuccesses` | `WorkshopTransferSuccesses` | `WorkshopFirstPassRate` |
| Total | `TotalFirstPassAttempts` | `TotalFirstPassSuccesses` | `TotalTransferSuccesses` | `TotalFirstPassRate` |

Also: `StockedIndicator`, `StockImpactFlag`, `MeetsCounterTarget`, `MeetsTotalTarget`, `HasAnyActivity`, `Franchise`, `JobType`

### Base Measures (in MeasuresTable.tmdl)

| Measure | Formula |
|---------|---------|
| `01. Counter %` | `CounterFirstPassSuccesses / CounterFirstPassAttempts` |
| `Counter+Transfer %` | `(CounterFirstPassSuccesses + CounterTransferSuccesses) / CounterFirstPassAttempts` |
| `Shop %` | `WorkshopFirstPassSuccesses / WorkshopFirstPassAttempts` |
| `Shop + Transfer %` | `(WorkshopFirstPassSuccesses + WorkshopTransferSuccesses) / WorkshopFirstPassAttempts` |
| `Total %` | `TotalFirstPassSuccesses / TotalFirstPassAttempts` |
| `Total + Transfer %` | `(TotalFirstPassSuccesses + TotalTransferSuccesses) / TotalFirstPassAttempts` |

### Rolling 12 Measure Pattern (Scorecard Page)

The R12 measures on the branch scorecard use `dim_DateTable` boolean flags:

```dax
R12-Counter = CALCULATE([01. Counter %], dim_DateTable[IsRolling12Months] = TRUE)
PY-R12-Counter = CALCULATE([01. Counter %], dim_DateTable[IsRolling24Months] = TRUE, dim_DateTable[IsRolling12Months] = FALSE)
```

### Rolling 12 "Working" Measures (Rolling 12 vs PY Page)

The month-selector page uses dynamic year resolution to avoid hardcoded year bugs:

```dax
-- R12 end date (dynamic year — avoids hardcoded year bug fixed March 2026)
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

PY measures shift the window back 12 months. `Period Verification` drives the subtitle text.

### Rolling 12 Trend Measure (Trends Page)

Fixed March 2026 — anchored to `TODAY()`, ignores page slicers:

```dax
Rolling 12 Trend =
    VAR Today = TODAY()
    VAR CurrentMonthEnd = MAX(dim_DateTable[Date])   -- visual axis month
    VAR WindowStart = EDATE(Today, -12) + 1
    RETURN
    IF(
        CurrentMonthEnd >= WindowStart && CurrentMonthEnd <= Today,
        CALCULATE(
            DIVIDE(SUM(Fact_FirstPassFill[TotalFirstPassSuccesses]), SUM(Fact_FirstPassFill[TotalFirstPassAttempts]), 0),
            REMOVEFILTERS(dim_DateTable),
            FILTER(ALL(dim_DateTable[Date]), dim_DateTable[Date] >= EDATE(CurrentMonthEnd, -12) + 1 && dim_DateTable[Date] <= CurrentMonthEnd)
        )
    )
```

**Visual isolation:** The `NoFilter` interactions in `pages/baebf534639ecc1467d8/page.json` prevent the year slicer from collapsing the Trends visual's X-axis. Do not remove these entries.

### dim_DateTable Boolean Flags

- `IsRolling12Months` — TRUE for dates in the last 12 months from today
- `IsRolling24Months` — TRUE for dates in the last 24 months from today
- `IsYearToDate` — TRUE for dates within the current calendar year up to today

## Business Logic

- **First Pass Fill %:** Percentage of parts requests fulfilled from branch stock on first attempt
- **Transfer successes:** Parts transferred from another branch to fill the request (tracked separately — not a true first-pass fill)
- **+Transfer %:** Fill rate including inter-branch transfers (always higher than pure first pass)
- **Counter:** Over-the-counter sales channel
- **Shop/Workshop:** Internal shop/technician parts requests
- **Channel composition:** Counter = Internal + Parts combined; Shop = Workshop only; Total = all three
- **Targets:** Counter = 85%, Shop = 80%, Total = 85% (hardcoded DAX constants)
- **Target discrepancy:** `MeetsCounterTarget` flag in Power Query uses `>= 0.80`, but the DAX `Counter Target` measure is `0.85`. If targets change, update both the DAX measures and the Power Query.

## Refresh Schedule

- **Tier 1 — Daily:** Phase 4 Wave B, complete by ~5 AM
- **Dataflow:** `df_Fact_First_Pass_Fill` in LH_Master_Data
- **Source table:** `Raw_InHist_PmManage` (PM Management history)
- **Query:** `queries/fact table/Fact_FirstPassFill.pq`
- **Approximate runtime:** ~5 min

## Files in This Project

```
projects/first pass fill - report/
├── CLAUDE.md                             # Developer/Claude context and gotchas
├── PROJECT-SUMMARY.md                    # This file
└── report/current/
    ├── First Pass Fill.Report/           # Report pages and visuals
    └── First Pass Fill.SemanticModel/
        └── definition/
            ├── relationships.tmdl
            └── tables/
                ├── Fact_FirstPassFill.tmdl
                ├── MeasuresTable.tmdl
                ├── dim_BranchLocation.tmdl
                ├── dim_DateTable.tmdl
                ├── dim_Parts.tmdl
                ├── dim_JobCode.tmdl
                └── Date_Supplemental.tmdl
```
