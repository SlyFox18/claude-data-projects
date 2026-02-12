/*
============================================================================
Query: TechnicianEfficiency (Raw)
Dataflow: df_TechnicianEfficiency_Raw
Location: LH_Master_Data → Dataflows → 01 - Raw Sources
============================================================================

METADATA:
Source: SQL Anywhere Database (ODBC connection: EquipRDB64)
View: Administrator.TechnicianEfficiency
Purpose: Pre-aggregated technician efficiency data combining attendance, worked, and invoice hours
Created: 01/27/2026
Last Modified: 01/27/2026
Output: Lakehouse table "TechnicianEfficiency"

REFRESH CHARACTERISTICS:
Refresh Schedule: TBD (recommend weekdays with other labor tables)
Average Refresh Time: TBD (document after first refresh)
Refresh Strategy: Full refresh with Year filter (2023+ scope)
Row Count: TBD (document after first refresh)
Query Folding: YES (SQL query with WHERE clause filtering)

DATA GRAIN:
One row per: Year + Month + Branch + TechnicianCode
Aggregation Level: Monthly summary by technician (NO JobCode/JobType detail)
Time Range: Filtered to 2023+ for performance

IMPORTANT - TABLE RELATIONSHIP TO OTHER RAW TABLES:
This table is a PRE-AGGREGATED view that combines data from:
- TechnicianAttendance (AvailableHours)
- TechnicianPunchedTime (WorkedHours)
- TechnicianInvoice (InvoiceHours, ReworkHours, etc.)
- Technician dimension (TechnicianName)

KEY DIFFERENCE: This table aggregates to Year/Month/Branch/TechCode level,
losing the JobCode/JobType detail available in TechnicianInvoice and TechnicianPunchedTime.

USE CASE DECISION:
- Use TechnicianEfficiency for: Simple technician-level reports, quick KPI dashboards
- Use separate raw tables for: Job type analysis, detailed breakdowns by JobCode

BUSINESS USE CASES:
- Labor Performance KPIs: Combined efficiency and productivity in one table
- Technician Scorecards: All metrics per technician/month
- Management Dashboards: Quick overview without joins
- Simpler DAX: All measures from single fact table

KEY CALCULATIONS (Done in DAX/Report):
- Efficiency = SUM(EfficiencyRateNumerator) / SUM(EfficiencyRateDenominator)
- Productivity = SUM(WorkedHours) / SUM(AvailableHours)
- Labor Performance = Efficiency × Productivity

DATA STRUCTURE (17 COLUMNS):

**Time Dimensions:**
- Year: Calendar year (2023, 2024, 2025, 2026)
- Month: Calendar month (1-12)
- DateKey: Calculated first-of-month date for dim_DateTable join

**Core Identifiers:**
- Branch: Branch location code (joins to dim_BranchLocation)
- TechCode: Technician code (joins to dim_Technician_Code_Names)
- TechnicianName: Technician name (denormalized from dimension)

**Hours Data:**
- AvailableHours: Attendance/scheduled hours (from TechnicianAttendance)
- WorkedHours: Actual hours worked (from TechnicianPunchedTime)
- InvoiceHours: Hours billed to customer
- ReworkHours: Hours spent on rework
- BilledHours: Total billed hours
- DelayHours: Hours lost to delays
- GainLossHours: Gain or loss hours
- OtherHours: Miscellaneous hours
- LostHours: Other lost/non-productive hours

**Efficiency Calculation Fields:**
- EfficiencyRateNumerator: Numerator for efficiency calculation
- EfficiencyRateDenominator: Denominator for efficiency calculation

RELATIONSHIPS:
- Branch → dim_BranchLocation[BranchID] (M:1)
- TechCode → dim_Technician_Code_Names[TechnicianCode] (M:1)
- DateKey → dim_DateTable[Date] (M:1)

DESIGN PRINCIPLES:

**Column Normalization (Source has mixed casing):**
- branch → Branch
- techniciancode → TechCode
- year → Year
- month → Month
- invoicehours → InvoiceHours
- reworkhours → ReworkHours
- delayhours → DelayHours
- gainlosshours → GainLossHours
- otherhours → OtherHours
- losthours → LostHours
- efficiencyratenumerator → EfficiencyRateNumerator
- efficiencyratedenominator → EfficiencyRateDenominator
- DateKey added for dim_DateTable relationship

**Data Filtering:**
- Year >= 2023 to limit data volume
- Enables 3+ years of historical comparison

**Type Safety:**
- Branch and TechCode as text (identifiers)
- DateKey as date type for proper relationships
- All hours fields as decimal for precision

Dependencies:
- None (direct source system view)

Used By:
- Labor Performance Report (simplified single-fact option)
- Technician efficiency dashboards
- Management KPI reports

Related Tables:
- TechnicianInvoice (detail by JobCode/JobType)
- TechnicianAttendance (source for AvailableHours)
- TechnicianPunchedTime (source for WorkedHours, detail by JobCode/JobType)
- dim_Technician_Code_Names (technician dimension)
- dim_BranchLocation (branch dimension)
- dim_DateTable (date dimension)

============================================================================
*/

let
    // ========================================================================
    // PARAMETERS - YEAR FILTERING FOR PERFORMANCE
    // ========================================================================
    /*
    PURPOSE: Limit data to recent years for optimal refresh performance
    ADJUST: Change RangeStartYear for different historical scope
    */

    RangeStartYear = 2023,

    // ========================================================================
    // SOURCE CONNECTION
    // ========================================================================
    /*
    SOURCE: SQL Anywhere via ODBC
    VIEW: Administrator.TechnicianEfficiency
    TYPE: Pre-aggregated view combining multiple source tables
    */

    Source = Odbc.DataSource("dsn=EquipRDB64", [HierarchicalNavigation = true]),
    Schema = Source{[Name = "Administrator", Kind = "Schema"]}[Data],
    TechnicianEfficiency = Schema{[Name = "TechnicianEfficiency", Kind = "View"]}[Data],

    // ========================================================================
    // STEP 1: FILTER TO RECENT YEARS
    // ========================================================================
    /*
    PURPOSE: Reduce data volume for faster refresh
    SCOPE: 2023+ (adjustable via RangeStartYear parameter)
    */

    FilterYears = Table.SelectRows(TechnicianEfficiency, each [year] >= RangeStartYear),

    // ========================================================================
    // STEP 2: NORMALIZE COLUMN NAMES
    // ========================================================================
    /*
    PURPOSE: Consistent PascalCase naming with other labor tables
    SOURCE: View has mixed casing (lowercase and PascalCase)
    */

    RenameColumns = Table.RenameColumns(FilterYears, {
        // Lowercase to PascalCase
        {"branch", "Branch"},
        {"techniciancode", "TechCode"},
        {"year", "Year"},
        {"month", "Month"},
        {"invoicehours", "InvoiceHours"},
        {"reworkhours", "ReworkHours"},
        {"delayhours", "DelayHours"},
        {"gainlosshours", "GainLossHours"},
        {"otherhours", "OtherHours"},
        {"losthours", "LostHours"},
        {"efficiencyratenumerator", "EfficiencyRateNumerator"},
        {"efficiencyratedenominator", "EfficiencyRateDenominator"}
        // Already PascalCase: TechnicianName, AvailableHours, WorkedHours, BilledHours
    }),

    // ========================================================================
    // STEP 3: ADD DATE KEY FOR DIMENSION RELATIONSHIP
    // ========================================================================
    /*
    PURPOSE: Create proper date column for dim_DateTable join
    LOGIC: First day of each month (Year, Month, 1)
    BENEFIT: Enables time intelligence in DAX (YTD, SAMEPERIODLASTYEAR, etc.)
    */

    AddDateKey = Table.AddColumn(RenameColumns, "DateKey", each
        #date([Year], [Month], 1),
        type date
    ),

    // ========================================================================
    // STEP 4: ENSURE PROPER DATA TYPES
    // ========================================================================
    /*
    PURPOSE: Optimize for storage and ensure proper join behavior
    IDENTIFIERS: Text type for Branch, TechCode (not numeric operations)
    MEASURES: Decimal for hours fields (precision)
    */

    SetDataTypes = Table.TransformColumnTypes(AddDateKey, {
        // Time dimensions
        {"Year", Int64.Type},
        {"Month", Int64.Type},
        {"DateKey", type date},

        // Core identifiers (text for proper joins)
        {"Branch", type text},
        {"TechCode", type text},
        {"TechnicianName", type text},

        // Hours data (decimal for precision)
        {"AvailableHours", type number},
        {"WorkedHours", type number},
        {"InvoiceHours", type number},
        {"ReworkHours", type number},
        {"BilledHours", type number},
        {"DelayHours", type number},
        {"GainLossHours", type number},
        {"OtherHours", type number},
        {"LostHours", type number},

        // Efficiency calculation fields
        {"EfficiencyRateNumerator", type number},
        {"EfficiencyRateDenominator", type number}
    }),

    // ========================================================================
    // STEP 5: REORDER COLUMNS FOR LOGICAL STRUCTURE
    // ========================================================================
    /*
    PURPOSE: Organize columns for intuitive use
    ORDER: Time → Identifiers → Productivity Hours → Invoice Hours → Efficiency
    */

    ReorderColumns = Table.ReorderColumns(SetDataTypes, {
        // Time dimensions
        "Year",
        "Month",
        "DateKey",

        // Core identifiers
        "Branch",
        "TechCode",
        "TechnicianName",

        // Productivity hours (from Attendance & PunchedTime)
        "AvailableHours",
        "WorkedHours",

        // Invoice hours (from TechnicianInvoice)
        "InvoiceHours",
        "ReworkHours",
        "BilledHours",
        "DelayHours",
        "GainLossHours",
        "OtherHours",
        "LostHours",

        // Efficiency calculation fields
        "EfficiencyRateNumerator",
        "EfficiencyRateDenominator"
    }),

    // ========================================================================
    // STEP 6: SORT FOR CONSISTENT OUTPUT
    // ========================================================================
    /*
    PURPOSE: Predictable ordering for validation and debugging
    ORDER: Year DESC, Month DESC, Branch, TechCode
    */

    SortOutput = Table.Sort(ReorderColumns, {
        {"Year", Order.Descending},
        {"Month", Order.Descending},
        {"Branch", Order.Ascending},
        {"TechCode", Order.Ascending}
    })

in
    SortOutput

/*
============================================================================
IMPLEMENTATION NOTES
============================================================================

POST-REFRESH VALIDATION:

1. Row Count Check:
   - Should have data for years 2023-2026
   - Verify: SELECT Year, COUNT(*) FROM TechnicianEfficiency GROUP BY Year

2. Key Field Validation:
   - TechCode should match dim_Technician_Code_Names[TechnicianCode]
   - Branch should match dim_BranchLocation[BranchID]
   - DateKey should match dim_DateTable[Date]

3. Data Quality Checks:
   - AvailableHours should be positive
   - WorkedHours should be <= AvailableHours (typically)
   - EfficiencyRateDenominator should not be 0

4. Cross-Table Validation:
   - SUM(AvailableHours) should match SUM(TechnicianAttendance[AttendanceHours])
   - SUM(WorkedHours) should match SUM(TechnicianPunchedTime[HoursWorked])

RELATIONSHIP SETUP IN POWER BI:

1. TechnicianEfficiency[Branch] → dim_BranchLocation[BranchID]
   - Cardinality: Many-to-One
   - Cross-filter: Single

2. TechnicianEfficiency[TechCode] → dim_Technician_Code_Names[TechnicianCode]
   - Cardinality: Many-to-One
   - Cross-filter: Single

3. TechnicianEfficiency[DateKey] → dim_DateTable[Date]
   - Cardinality: Many-to-One
   - Cross-filter: Single

DAX MEASURES FOR LABOR PERFORMANCE REPORT:

// Efficiency calculation
Efficiency =
DIVIDE(
    SUM(TechnicianEfficiency[EfficiencyRateNumerator]),
    SUM(TechnicianEfficiency[EfficiencyRateDenominator]),
    0
)

// Productivity calculation
Productivity =
DIVIDE(
    SUM(TechnicianEfficiency[WorkedHours]),
    SUM(TechnicianEfficiency[AvailableHours]),
    0
)

// Labor Performance (the key KPI)
Labor Performance = [Efficiency] * [Productivity]

// YTD measures
YTD Efficiency =
CALCULATE(
    [Efficiency],
    DATESYTD(dim_DateTable[Date])
)

YTD Productivity =
CALCULATE(
    [Productivity],
    DATESYTD(dim_DateTable[Date])
)

// Prior Year comparisons
PY Efficiency =
CALCULATE(
    [Efficiency],
    SAMEPERIODLASTYEAR(dim_DateTable[Date])
)

PY Productivity =
CALCULATE(
    [Productivity],
    SAMEPERIODLASTYEAR(dim_DateTable[Date])
)

// Variance measures
Efficiency Variance = [Efficiency] - [PY Efficiency]
Productivity Variance = [Productivity] - [PY Productivity]

REFRESH TIME TRACKING:
- Initial refresh: 2:03
- Second refresh: 2:08
- Average: ~2:06
- Row count: 29,853

============================================================================

DESIGN DECISION: WHEN TO USE THIS TABLE VS. SEPARATE TABLES

USE TechnicianEfficiency (this table) when:
- Building simple technician scorecards
- Need all KPIs in one place without complex DAX
- Don't need JobCode/JobType breakdown
- Want simpler model with single fact table

USE SEPARATE TABLES (TechnicianInvoice, TechnicianAttendance, TechnicianPunchedTime) when:
- Need analysis by JobCode or JobType
- Need detailed hours breakdown by category
- Building drill-through reports to job-level detail
- Want maximum flexibility for future analysis

RECOMMENDED APPROACH:
Consider using TechnicianEfficiency as the PRIMARY fact table for the Labor Performance
report, with TechnicianInvoice and TechnicianPunchedTime available for drill-through
or detailed analysis pages.

============================================================================
*/
