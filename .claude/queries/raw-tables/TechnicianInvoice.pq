/*
============================================================================
Query: TechnicianInvoice (Raw)
Dataflow: df_TechnicianInvoice_Raw
Location: LH_Master_Data → Dataflows → 01 - Raw Sources
============================================================================

METADATA:
Source: SQL Anywhere Database (ODBC connection: EquipRDB64)
View: Administrator.TechnicianInvoice
Purpose: Aggregated technician invoice/billing data for labor efficiency analysis
Created: 01/26/2026
Last Modified: 01/26/2026
Output: Lakehouse table "TechnicianInvoice"

REFRESH CHARACTERISTICS:
Refresh Schedule: TBD (recommend weekdays with other labor tables)
Average Refresh Time: ~1:52 (1:51 and 1:54 observed)
Refresh Strategy: Full refresh with Year filter (2023+ scope)
Row Count: TBD (document after first refresh)
Query Folding: YES (SQL query with WHERE clause filtering)

DATA GRAIN:
One row per: Year + Month + Branch + TechnicianCode + JobCode + JobType
Aggregation Level: Monthly summary by technician and job classification
Time Range: Filtered to 2023+ for performance

BUSINESS USE CASES:
- Labor Efficiency Analysis: EfficiencyRateNumerator / EfficiencyRateDenominator
- Labor Performance Report: Core data source for efficiency calculations
- Technician Productivity: Hours punched vs hours invoiced analysis
- Rework Tracking: ReworkHours for quality analysis
- Delay Analysis: DelayHours for operational bottleneck identification
- Gain/Loss Analysis: GainLossHours for profitability tracking
- Job Type Performance: Efficiency by JobCode and JobType

KEY CALCULATIONS (Done in DAX/Report):
- Efficiency = SUM(EfficiencyRateNumerator) / SUM(EfficiencyRateDenominator)
- Total Invoice Hours = SUM(InvoiceHours)
- YTD Hours = TOTALYTD(SUM(InvoiceHours), dim_DateTable[Date])

DATA STRUCTURE (16 COLUMNS):

**Time Dimensions:**
- Year: Calendar year (2023, 2024, 2025, 2026)
- Month: Calendar month (1-12)
- DateKey: Calculated first-of-month date for dim_DateTable join

**Core Identifiers:**
- Branch: Branch location code (joins to dim_BranchLocation)
- TechCode: Technician code (joins to dim_Technician_Code_Names)
- JobCode: Job classification code (e.g., "GEN-ELECTRICAL")
- JobType: Job type indicator (e.g., "R" = Retail)

**Hours Data:**
- HoursPunched: Actual hours punched/worked by technician
- InvoiceHours: Hours billed to customer
- ReworkHours: Hours spent on rework (quality indicator)
- DelayHours: Hours lost to delays
- LostHours: Other lost/non-productive hours
- OtherHours: Miscellaneous hours category
- GainLossHours: Gain or loss hours (positive = gain)

**Efficiency Calculation Fields:**
- EfficiencyRateNumerator: Numerator for efficiency calculation
- EfficiencyRateDenominator: Denominator for efficiency calculation
- Efficiency = Numerator / Denominator (calculate in DAX)

RELATIONSHIPS:
- Branch → dim_BranchLocation[BranchID] (M:1)
- TechCode → dim_Technician_Code_Names[TechnicianCode] (M:1)
- DateKey → dim_DateTable[Date] (M:1)

DESIGN PRINCIPLES:

**Column Normalization:**
- TechnicianCode renamed to TechCode (consistent with other labor tables)
- DateKey added for dim_DateTable relationship

**Data Filtering:**
- Year >= 2023 to limit data volume
- Enables 3+ years of historical comparison
- Adjust RangeStart parameter for different scope

**Type Safety:**
- Branch and TechCode as text (identifiers, not numbers)
- DateKey as date type for proper relationships
- Hours fields as decimal for precision

Dependencies:
- None (direct source system view)

Used By:
- Labor Performance Report (primary fact data)
- Technician efficiency dashboards
- Management performance reviews
- Quality tracking (rework analysis)

Related Tables:
- TechnicianAttendance (for Productivity calculation)
- TechnicianPunchedTime (for HoursWorked detail)
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
    VIEW: Administrator.TechnicianInvoice
    TYPE: Aggregated view (not detail table)
    */

    Source = Odbc.DataSource("dsn=EquipRDB64", [HierarchicalNavigation = true]),
    Schema = Source{[Name = "Administrator", Kind = "Schema"]}[Data],
    TechnicianInvoice = Schema{[Name = "TechnicianInvoice", Kind = "View"]}[Data],

    // ========================================================================
    // STEP 1: FILTER TO RECENT YEARS
    // ========================================================================
    /*
    PURPOSE: Reduce data volume for faster refresh
    SCOPE: 2023+ (adjustable via RangeStartYear parameter)
    */

    FilterYears = Table.SelectRows(TechnicianInvoice, each [Year] >= RangeStartYear),

    // ========================================================================
    // STEP 2: NORMALIZE COLUMN NAMES
    // ========================================================================
    /*
    PURPOSE: Consistent naming with other labor tables
    CHANGE: TechnicianCode → TechCode (matches TechnicianInvoiceDetail, wkmechwk, etc.)
    */

    RenameColumns = Table.RenameColumns(FilterYears, {
        {"TechnicianCode", "TechCode"}
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
        {"JobCode", type text},
        {"JobType", type text},

        // Hours data (decimal for precision)
        {"HoursPunched", type number},
        {"InvoiceHours", type number},
        {"ReworkHours", type number},
        {"DelayHours", type number},
        {"LostHours", type number},
        {"OtherHours", type number},
        {"GainLossHours", type number},

        // Efficiency calculation fields
        {"EfficiencyRateNumerator", type number},
        {"EfficiencyRateDenominator", type number}
    }),

    // ========================================================================
    // STEP 5: REORDER COLUMNS FOR LOGICAL STRUCTURE
    // ========================================================================
    /*
    PURPOSE: Organize columns for intuitive use
    ORDER: Time → Identifiers → Hours → Efficiency
    */

    ReorderColumns = Table.ReorderColumns(SetDataTypes, {
        // Time dimensions
        "Year",
        "Month",
        "DateKey",

        // Core identifiers
        "Branch",
        "TechCode",
        "JobCode",
        "JobType",

        // Hours data
        "HoursPunched",
        "InvoiceHours",
        "ReworkHours",
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
   - Verify: SELECT Year, COUNT(*) FROM TechnicianInvoice GROUP BY Year

2. Key Field Validation:
   - TechCode should match dim_Technician_Code_Names[TechnicianCode]
   - Branch should match dim_BranchLocation[BranchID]
   - DateKey should match dim_DateTable[Date]

3. Data Quality Checks:
   - EfficiencyRateDenominator should not be 0 (division by zero)
   - InvoiceHours should generally be positive
   - Verify: SELECT COUNT(*) FROM TechnicianInvoice WHERE EfficiencyRateDenominator = 0

4. Efficiency Calculation Validation:
   - In DAX: Efficiency = DIVIDE(SUM(EfficiencyRateNumerator), SUM(EfficiencyRateDenominator), 0)
   - Expected range: 0% to 150%+ (high performers can exceed 100%)

RELATIONSHIP SETUP IN POWER BI:

1. TechnicianInvoice[Branch] → dim_BranchLocation[BranchID]
   - Cardinality: Many-to-One
   - Cross-filter: Single

2. TechnicianInvoice[TechCode] → dim_Technician_Code_Names[TechnicianCode]
   - Cardinality: Many-to-One
   - Cross-filter: Single

3. TechnicianInvoice[DateKey] → dim_DateTable[Date]
   - Cardinality: Many-to-One
   - Cross-filter: Single

DAX MEASURES FOR LABOR PERFORMANCE REPORT:

// Core efficiency measure
Efficiency =
DIVIDE(
    SUM(TechnicianInvoice[EfficiencyRateNumerator]),
    SUM(TechnicianInvoice[EfficiencyRateDenominator]),
    0
)

// Total invoice hours
Total InvoiceHours = SUM(TechnicianInvoice[InvoiceHours])

// YTD Hours
YTD Hours =
TOTALYTD(
    SUM(TechnicianInvoice[InvoiceHours]),
    dim_DateTable[Date]
)

// Prior Year To Date Hours
PYTD Hours =
CALCULATE(
    [YTD Hours],
    SAMEPERIODLASTYEAR(dim_DateTable[Date])
)

// Year-over-Year Difference
YoY Difference = [YTD Hours] - [PYTD Hours]

// Last Year Hours (same period)
LY Hours =
CALCULATE(
    SUM(TechnicianInvoice[InvoiceHours]),
    SAMEPERIODLASTYEAR(dim_DateTable[Date])
)

REFRESH TIME TRACKING:
- Initial refresh: 1:51
- Second refresh: 1:54
- Average: ~1:52 (better than expected)

============================================================================
*/
