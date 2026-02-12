/*
============================================================================
Query: TechnicianAttendance (Raw)
Dataflow: df_TechnicianAttendance_Raw
Location: LH_Master_Data → Dataflows → 01 - Raw Sources
============================================================================

METADATA:
Source: SQL Anywhere Database (ODBC connection: EquipRDB64)
View: Administrator.TechnicianAttendance
Purpose: Technician attendance/available hours for productivity calculation
Created: 01/26/2026
Last Modified: 01/26/2026
Output: Lakehouse table "TechnicianAttendance"

REFRESH CHARACTERISTICS:
Refresh Schedule: TBD (recommend weekdays with other labor tables)
Average Refresh Time: ~1:17 (1:10 and 1:23 observed)
Refresh Strategy: Full refresh with Year filter (2023+ scope)
Row Count: TBD (document after first refresh)
Query Folding: YES (SQL query with WHERE clause filtering)

DATA GRAIN:
One row per: Year + Month + Branch + TechnicianCode
Aggregation Level: Monthly summary by technician
Time Range: Filtered to 2023+ for performance

BUSINESS USE CASES:
- Productivity Calculation: HoursWorked / AttendanceHours (this table provides denominator)
- Labor Performance Report: Core data source for productivity calculations
- Capacity Planning: Available hours by technician and location
- Utilization Analysis: Compare available hours to worked/billed hours

KEY CALCULATIONS (Done in DAX/Report):
- Productivity = SUM(TechnicianPunchedTime[HoursWorked]) / SUM(TechnicianAttendance[AttendanceHours])
- Total Available Hours = SUM(AttendanceHours)
- YTD Available Hours = TOTALYTD(SUM(AttendanceHours), dim_DateTable[Date])

DATA STRUCTURE (6 COLUMNS):

**Time Dimensions:**
- Year: Calendar year (2023, 2024, 2025, 2026)
- Month: Calendar month (1-12)
- DateKey: Calculated first-of-month date for dim_DateTable join

**Core Identifiers:**
- Branch: Branch location code (joins to dim_BranchLocation)
- TechCode: Technician code (joins to dim_Technician_Code_Names)

**Hours Data:**
- AttendanceHours: Available/scheduled hours for the technician (productivity denominator)

RELATIONSHIPS:
- Branch → dim_BranchLocation[BranchID] (M:1)
- TechCode → dim_Technician_Code_Names[TechnicianCode] (M:1)
- DateKey → dim_DateTable[Date] (M:1)

DESIGN PRINCIPLES:

**Column Normalization:**
- TechnicianCode renamed to TechCode (consistent with other labor tables)
- Hours renamed to AttendanceHours (clearer business meaning)
- DateKey added for dim_DateTable relationship

**Data Filtering:**
- Year >= 2023 to limit data volume
- Enables 3+ years of historical comparison
- Adjust RangeStart parameter for different scope

**Type Safety:**
- Branch and TechCode as text (identifiers, not numbers)
- DateKey as date type for proper relationships
- AttendanceHours as decimal for precision

Dependencies:
- None (direct source system view)

Used By:
- Labor Performance Report (productivity denominator)
- Technician productivity dashboards
- Capacity planning reports

Related Tables:
- TechnicianInvoice (for Efficiency calculation)
- TechnicianPunchedTime (for HoursWorked - productivity numerator)
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
    VIEW: Administrator.TechnicianAttendance
    TYPE: Aggregated view (not detail table)
    */

    Source = Odbc.DataSource("dsn=EquipRDB64", [HierarchicalNavigation = true]),
    Schema = Source{[Name = "Administrator", Kind = "Schema"]}[Data],
    TechnicianAttendance = Schema{[Name = "TechnicianAttendance", Kind = "View"]}[Data],

    // ========================================================================
    // STEP 1: FILTER TO RECENT YEARS
    // ========================================================================
    /*
    PURPOSE: Reduce data volume for faster refresh
    SCOPE: 2023+ (adjustable via RangeStartYear parameter)
    */

    FilterYears = Table.SelectRows(TechnicianAttendance, each [Year] >= RangeStartYear),

    // ========================================================================
    // STEP 2: NORMALIZE COLUMN NAMES
    // ========================================================================
    /*
    PURPOSE: Consistent naming with other labor tables
    CHANGES:
    - TechnicianCode → TechCode (matches TechnicianInvoice, wkmechwk, etc.)
    - Hours → AttendanceHours (clearer business meaning)
    */

    RenameColumns = Table.RenameColumns(FilterYears, {
        {"TechnicianCode", "TechCode"},
        {"Hours", "AttendanceHours"}
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

        // Hours data (decimal for precision)
        {"AttendanceHours", type number}
    }),

    // ========================================================================
    // STEP 5: REORDER COLUMNS FOR LOGICAL STRUCTURE
    // ========================================================================
    /*
    PURPOSE: Organize columns for intuitive use
    ORDER: Time → Identifiers → Hours
    */

    ReorderColumns = Table.ReorderColumns(SetDataTypes, {
        // Time dimensions
        "Year",
        "Month",
        "DateKey",

        // Core identifiers
        "Branch",
        "TechCode",

        // Hours data
        "AttendanceHours"
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
   - Verify: SELECT Year, COUNT(*) FROM TechnicianAttendance GROUP BY Year

2. Key Field Validation:
   - TechCode should match dim_Technician_Code_Names[TechnicianCode]
   - Branch should match dim_BranchLocation[BranchID]
   - DateKey should match dim_DateTable[Date]

3. Data Quality Checks:
   - AttendanceHours should be positive
   - Typical range: 160-200 hours/month for full-time technician
   - Check for outliers: SELECT * FROM TechnicianAttendance WHERE Hours > 250 OR Hours < 40

RELATIONSHIP SETUP IN POWER BI:

1. TechnicianAttendance[Branch] → dim_BranchLocation[BranchID]
   - Cardinality: Many-to-One
   - Cross-filter: Single

2. TechnicianAttendance[TechCode] → dim_Technician_Code_Names[TechnicianCode]
   - Cardinality: Many-to-One
   - Cross-filter: Single

3. TechnicianAttendance[DateKey] → dim_DateTable[Date]
   - Cardinality: Many-to-One
   - Cross-filter: Single

DAX MEASURES FOR LABOR PERFORMANCE REPORT:

// Total available hours
Total AttendanceHours = SUM(TechnicianAttendance[AttendanceHours])

// Productivity calculation (requires TechnicianPunchedTime for numerator)
Productivity =
DIVIDE(
    SUM(TechnicianPunchedTime[HoursWorked]),
    SUM(TechnicianAttendance[AttendanceHours]),
    0
)

// YTD Available Hours
YTD AttendanceHours =
TOTALYTD(
    SUM(TechnicianAttendance[AttendanceHours]),
    dim_DateTable[Date]
)

// Prior Year To Date Available Hours
PYTD AttendanceHours =
CALCULATE(
    [YTD AttendanceHours],
    SAMEPERIODLASTYEAR(dim_DateTable[Date])
)

REFRESH TIME TRACKING:
- Initial refresh: 1:10
- Second refresh: 1:23
- Average: ~1:17 (as expected for simple table)

============================================================================
*/
