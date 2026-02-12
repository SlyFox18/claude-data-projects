/*
============================================================================
Query: TechnicianPunchedTime (Raw)
Dataflow: df_TechnicianPunchedTime_Raw
Location: LH_Master_Data → Dataflows → 01 - Raw Sources
============================================================================

METADATA:
Source: SQL Anywhere Database (ODBC connection: EquipRDB64)
View: Administrator.TechnicianPunchedTime
Purpose: Technician worked hours by job type for productivity calculation
Created: 01/26/2026
Last Modified: 01/26/2026
Output: Lakehouse table "TechnicianPunchedTime"

REFRESH CHARACTERISTICS:
Refresh Schedule: TBD (recommend weekdays with other labor tables)
Average Refresh Time: ~3:03 (2:48 and 3:17 observed)
Refresh Strategy: Full refresh with Year filter (2023+ scope)
Row Count: TBD (document after first refresh)
Query Folding: YES (SQL query with WHERE clause filtering)

DATA GRAIN:
One row per: Year + Month + Branch + TechnicianCode + JobType + JobCode
Aggregation Level: Monthly summary by technician and job classification
Time Range: Filtered to 2023+ for performance

BUSINESS USE CASES:
- Productivity Calculation: HoursWorked / AttendanceHours (this table provides numerator)
- Labor Performance Report: Core data source for productivity calculations
- Job Type Analysis: Hours breakdown by Internal, Warranty, Retail, etc.
- Technician Utilization: Compare worked hours to available hours

KEY CALCULATIONS (Done in DAX/Report):
- Productivity = SUM(HoursWorked) / SUM(TechnicianAttendance[AttendanceHours])
- Total HoursWorked = SUM(HoursWorked)
- YTD HoursWorked = TOTALYTD(SUM(HoursWorked), dim_DateTable[Date])

DATA STRUCTURE (16 COLUMNS):

**Time Dimensions:**
- Year: Calendar year (2023, 2024, 2025, 2026)
- Month: Calendar month (1-12)
- DateKey: Calculated first-of-month date for dim_DateTable join

**Core Identifiers:**
- Branch: Branch location code (joins to dim_BranchLocation)
- TechCode: Technician code (joins to dim_Technician_Code_Names)
- JobCode: Job classification code (e.g., "R4038/5105/BOF/E/10")
- JobType: Job type indicator (e.g., "R" = Retail)

**Hours Data (Worked):**
- HoursWorked: Total hours worked (productivity numerator)
- HoursSold: Hours sold/billed

**Hours Data (By Category):**
- HoursInternal: Internal/shop work hours
- HoursWarranty: Warranty work hours
- HoursRetail: Retail customer work hours
- HoursSundry: Sundry/miscellaneous hours
- HoursFleet: Fleet service hours
- HoursAgreement: Service agreement hours
- HoursOther: Other category hours

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
- All hours fields as decimal for precision

Dependencies:
- None (direct source system view)

Used By:
- Labor Performance Report (productivity numerator)
- Technician productivity dashboards
- Job type analysis reports

Related Tables:
- TechnicianInvoice (for Efficiency calculation)
- TechnicianAttendance (for AttendanceHours - productivity denominator)
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
    VIEW: Administrator.TechnicianPunchedTime
    TYPE: Aggregated view (not detail table)
    */

    Source = Odbc.DataSource("dsn=EquipRDB64", [HierarchicalNavigation = true]),
    Schema = Source{[Name = "Administrator", Kind = "Schema"]}[Data],
    TechnicianPunchedTime = Schema{[Name = "TechnicianPunchedTime", Kind = "View"]}[Data],

    // ========================================================================
    // STEP 1: FILTER TO RECENT YEARS
    // ========================================================================
    /*
    PURPOSE: Reduce data volume for faster refresh
    SCOPE: 2023+ (adjustable via RangeStartYear parameter)
    */

    FilterYears = Table.SelectRows(TechnicianPunchedTime, each [Year] >= RangeStartYear),

    // ========================================================================
    // STEP 2: NORMALIZE COLUMN NAMES
    // ========================================================================
    /*
    PURPOSE: Consistent naming with other labor tables
    CHANGE: TechnicianCode → TechCode (matches TechnicianInvoice, TechnicianAttendance, etc.)
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
        {"HoursWorked", type number},
        {"HoursSold", type number},
        {"HoursInternal", type number},
        {"HoursWarranty", type number},
        {"HoursRetail", type number},
        {"HoursSundry", type number},
        {"HoursFleet", type number},
        {"HoursAgreement", type number},
        {"HoursOther", type number}
    }),

    // ========================================================================
    // STEP 5: REORDER COLUMNS FOR LOGICAL STRUCTURE
    // ========================================================================
    /*
    PURPOSE: Organize columns for intuitive use
    ORDER: Time → Identifiers → Core Hours → Category Hours
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

        // Core hours data
        "HoursWorked",
        "HoursSold",

        // Hours by category
        "HoursInternal",
        "HoursWarranty",
        "HoursRetail",
        "HoursSundry",
        "HoursFleet",
        "HoursAgreement",
        "HoursOther"
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
   - Verify: SELECT Year, COUNT(*) FROM TechnicianPunchedTime GROUP BY Year

2. Key Field Validation:
   - TechCode should match dim_Technician_Code_Names[TechnicianCode]
   - Branch should match dim_BranchLocation[BranchID]
   - DateKey should match dim_DateTable[Date]

3. Data Quality Checks:
   - HoursWorked should be positive
   - Category hours should sum to approximately HoursWorked
   - Check: SUM(HoursInternal + HoursWarranty + HoursRetail + HoursSundry + HoursFleet + HoursAgreement + HoursOther)

RELATIONSHIP SETUP IN POWER BI:

1. TechnicianPunchedTime[Branch] → dim_BranchLocation[BranchID]
   - Cardinality: Many-to-One
   - Cross-filter: Single

2. TechnicianPunchedTime[TechCode] → dim_Technician_Code_Names[TechnicianCode]
   - Cardinality: Many-to-One
   - Cross-filter: Single

3. TechnicianPunchedTime[DateKey] → dim_DateTable[Date]
   - Cardinality: Many-to-One
   - Cross-filter: Single

DAX MEASURES FOR LABOR PERFORMANCE REPORT:

// Total worked hours (productivity numerator)
Total HoursWorked = SUM(TechnicianPunchedTime[HoursWorked])

// Productivity calculation
Productivity =
DIVIDE(
    SUM(TechnicianPunchedTime[HoursWorked]),
    SUM(TechnicianAttendance[AttendanceHours]),
    0
)

// YTD Worked Hours
YTD HoursWorked =
TOTALYTD(
    SUM(TechnicianPunchedTime[HoursWorked]),
    dim_DateTable[Date]
)

// Prior Year To Date Worked Hours
PYTD HoursWorked =
CALCULATE(
    [YTD HoursWorked],
    SAMEPERIODLASTYEAR(dim_DateTable[Date])
)

// Hours by Category measures
Retail Hours = SUM(TechnicianPunchedTime[HoursRetail])
Warranty Hours = SUM(TechnicianPunchedTime[HoursWarranty])
Internal Hours = SUM(TechnicianPunchedTime[HoursInternal])
Fleet Hours = SUM(TechnicianPunchedTime[HoursFleet])

// Retail % of Total
Retail % =
DIVIDE(
    SUM(TechnicianPunchedTime[HoursRetail]),
    SUM(TechnicianPunchedTime[HoursWorked]),
    0
)

REFRESH TIME TRACKING:
- Initial refresh: 2:48
- Second refresh: 3:17
- Average: ~3:03 (larger dataset than expected)

============================================================================
*/
