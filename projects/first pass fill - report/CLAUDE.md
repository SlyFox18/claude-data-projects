# First Pass Fill — Claude Context

## Report Overview
- **Business purpose:** Measures how often parts requests (counter and shop) are fulfilled from branch stock on the first attempt, without transfers or back orders. Tracks fill rates by branch, channel, and time period.
- **Primary users:** Parts managers, branch managers, operations leadership
- **Workspace:** RP - Parts Reports
- **Refresh tier:** Tier 1 — daily by 5 AM (Phase 4, Wave B)
- **Status:** Production

## Semantic Model

### Fact Tables
| Table | Grain | Key Fields | Row Count (approx) |
|-------|-------|------------|-------------------|
| Fact_FirstPassFill | One row per branch × period (month) × part × job code | PeriodDateKey, BranchKey, PartNumberKey, JobCodeKey | ~734K rows |

The fact table is **pre-aggregated** — it stores attempt/success counts by the four dimensions above. No transaction-level drill-through is possible. Counts exist for each channel: Counter, Workshop (Shop), Internal, and Total.

Key measure columns per channel:
- `[Channel]FirstPassAttempts` — requests made
- `[Channel]FirstPassSuccesses` — filled from local stock on first attempt
- `[Channel]TransferSuccesses` — filled via inter-branch transfer (not true first-pass)
- `[Channel]24HourAttempts/Successes` — 24-hour fill window variant
- Pre-calculated rates also stored: `[Channel]FirstPassRate`
- Boolean flags: `MeetsCounterTarget`, `MeetsTotalTarget`, `HasAnyActivity`
- `StockedIndicator`, `Franchise`, `JobType` — filtering attributes

### Dimensions
| Table | Source | Key Relationship |
|-------|--------|-----------------|
| dim_BranchLocation | LH_Master_Data (shared) | BranchKey → Fact_FirstPassFill.BranchKey |
| dim_DateTable | LH_Master_Data (shared) | DateKey → Fact_FirstPassFill.PeriodDateKey |
| dim_Parts | LH_Master_Data (shared) | PartNumberKey → Fact_FirstPassFill.PartNumberKey |
| dim_JobCode | LH_Master_Data (dedicated — only 2 reports use it) | JobCodeKey → Fact_FirstPassFill.JobCodeKey |
| Date_Supplemental | Calculated DAX table | dim_DateTable.Date ↔ Date_Supplemental.Date (bidirectional — see gotchas) |

### Slicer/Selector Tables (no relationships to fact)
- `Metric Names` — in-model table; values: Counter, Counter + Transfer, Shop, Shop + Transfer, Total, Total + Transfer
- `Performance Metrics` — similar metric selector used on different pages
- `TBL Time Period`, `Time Period Table`, `Time Granularity Table` — time period slicer tables

### Key Measures
| Measure | Description |
|---------|-------------|
| `01. Counter %` | Counter channel first pass fill rate (successes / attempts) |
| `Counter+Transfer %` | Counter fill rate including transfer successes in numerator |
| `Shop %` | Workshop/shop channel fill rate |
| `Shop + Transfer %` | Shop fill rate including transfers |
| `Total %` | Combined all-channel fill rate |
| `Total + Transfer %` | Total fill rate including transfers |
| `R12-Counter/Shop/Total` | Rolling 12-month rate using `dim_DateTable[IsRolling12Months] = TRUE` |
| `PY-R12-Counter/Shop/Total` | Prior-year R12 using `IsRolling24Months = TRUE AND IsRolling12Months = FALSE` |
| `Counter/Shop/Total Target` | Hardcoded targets: Counter = 85%, Shop = 80%, Total = 85% |
| `Performance Target` | SWITCH on `Performance Metrics` slicer → returns correct target |
| `Current Period Performance` | SWITCH on `Performance Metrics` → current period rate |
| `Prior Year Performance` | SWITCH on `Performance Metrics` → prior year rate |
| `Counter/Shop/Total Variance` | Current % minus Same Period LY % |
| `Counter/Shop/Total Variance Label` | Formatted variance with +/- and "pp" suffix |
| `Counter % Same Period LY` | Custom PY calc using explicit date range (not SAMEPERIODLASTYEAR) to match exact period |
| `Rolling 12 Trend` | Trend line for Trends page — see gotcha below |
| `02. Counter % YTD` | YTD counter rate using `IsYearToDate = TRUE` |
| `Performance by Metric R12` | SWITCH for R12 metric on Rolling 12 vs PY page |
| `Home - Header` | Personalized greeting using USERPRINCIPALNAME() |

## Report Pages
| Page | Visibility | Purpose | Key Visuals |
|------|-----------|---------|-------------|
| First Pass Fill | Visible | Main scorecard — R12 rates by branch for all three channels | Branch matrix with conditional formatting, KPI cards, date slicer |
| Rolling 12 vs PY | Hidden in view mode | Month-selector column chart comparing R12 vs prior year by branch | Month slicer, grouped bar chart per branch |
| YTD | Hidden in view mode | Year-to-date fill rates by branch | Similar to main page but YTD context |
| Summary | Hidden in view mode | Aggregated summary view; date slicer has NoFilter interaction with several visuals | Summary KPIs |
| Trends | Hidden in view mode | Rolling 12 trend line — shows 12-month FPF rate per month, anchored to TODAY() | Line chart using `Rolling 12 Trend` measure; navigated via "Show Rolling 12 Trend" button |

Hidden pages are navigated to via buttons on the main page — they do not appear in the standard page navigation bar.

## Data Flow
```
EquipRDB (ODBC) → Raw_InHist_PmManage (Lakehouse) → Fact_FirstPassFill (df_Fact_First_Pass_Fill)
dim_BranchLocation, dim_DateTable, dim_Parts, dim_JobCode → Semantic Model → Report
```
Source: `Raw_InHist_PmManage` — the PM Management raw table in LH_Master_Data. Query is at `queries/fact table/Fact_FirstPassFill.pq`.

**Channel composition (from Power Query):**
- **Counter** = Internal + Parts (two sub-channels combined)
- **Shop/Workshop** = Workshop only
- **Total** = Internal + Parts + Workshop (all three)

## Known Issues & Gotchas

### Rolling 12 Trend measure (fixed March 2026)
The original measure used `MAX(dim_DateTable[Date])` as the anchor, which caused two problems:
1. Future dates in the date table produced data points for months that haven't happened
2. Year slicers on the page moved the anchor date

**Fix applied:** Measure now uses `TODAY()` as the anchor, `REMOVEFILTERS(dim_DateTable)` to strip page slicers, and `FILTER(ALL(...))` to re-apply a clean 12-month window. Returns `BLANK()` for months outside the rolling 12 window.

**Visual isolation:** Even with the fixed DAX, the Trends page visual's X-axis will collapse to the filtered year if a year slicer is active. The `page.json` for the Trends page has `"type": "NoFilter"` interaction set from the year slicer to the trend line visual — this must be preserved. Do not remove those `visualInteractions` entries.

### Date_Supplemental bidirectional relationship
`Date_Supplemental` has `crossFilteringBehavior: bothDirections` with `dim_DateTable`. Per known issues in CLAUDE.md root: bidirectional relationships risk ambiguous filter paths and performance degradation. Also, `Date_Supplemental` is a calculated DAX table hardcoded to 2022–2024 (`__LastYear = 2024`) — it is stale as of 2025+. The `DateWithTransactions` flag uses `TODAY()` so it stays current, but the date range itself only covers through 2024. This may cause issues if any visual uses `Date_Supplemental` directly for dates after 2024.

### Target values are hardcoded — and mismatched between PQ and DAX
`Counter Target = 0.85`, `Shop Target = 0.80`, `Total Target = 0.85` are hardcoded DAX measures.

**Discrepancy:** `MeetsCounterTarget` in Power Query is calculated as `CounterFirstPassRate >= 0.80`, but the DAX `Counter Target` measure is `0.85`. The boolean flag in the fact table uses a lower threshold than what the report displays as the target line. If targets change, update both the DAX measures **and** the Power Query flags.

### dim_JobCode is dedicated
Unlike most shared dimensions, `dim_JobCode` is only used by First Pass Fill and Top 50 Jobs. It has service-specific classifications (IsInspection, IsWarranty, IsSeasonalWork, IsUrgentWork, ServiceComplexity).

## Refresh Pipeline Position
- **Phase:** 4, Wave B (parallel with Part Sales Low Margin, 60+ Past Due, Open Parts Tickets, Parts Adjustments)
- **Dataflow:** `df_Fact_First_Pass_Fill` in LH_Master_Data
- **Dependencies:** dim_DateTable, dim_BranchLocation, dim_Parts, dim_JobCode must complete (Phase 3) before this runs
- **Approximate refresh time:** ~5 min
- **Semantic model refresh:** Phase 5, position 7 of 17

## Documentation Status
- In-repo docs: ✅ CLAUDE.md | ✅ PROJECT-SUMMARY.md
- Obsidian stakeholder docs: ✅ Complete — `Data Projects/Reports/First Pass Fill.md`
