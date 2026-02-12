/*
============================================================================
FACT_OPENWORKORDERS - Open Work Orders for WIP Report
============================================================================

📋 TABLE OVERVIEW:
Purpose: Track open (non-invoiced) work orders with aging analysis
Grain: One row per open work order (unique Branch + WorkOrder)
Report: Open Work Orders / WIP Report
Department: Service

🎯 BUSINESS USE CASES:
• WIP Overview: Cards showing Total/Parts/Labor/Sublet/Other Sales
• Aging Analysis: 60+ Days, 31-60, 15-30, 8-14, 1-7 Days, Not Started
• WIP Details: Drill-down table with work order specifics
• Branch Performance: Open WIP by branch location

📊 DATA SOURCES (NEW LAKEHOUSE):
• RepairOrderDetail: Core work order data (timeline, financials, status)
• WKROFILE: Customer account number, payment method
• TechnicianPunchedDetail: Equipment model, technician name

🔗 RELATIONSHIPS:
• Branch → dim_Branch[Branch] (M:1)
• DateKey → dim_DateTable[Date] (M:1)
• AccountNumber → dim_CustomerList[AccountNumberText] (M:1)

⚡ MIGRATION NOTES:
• Replaces: AgingReport, RepairOrderDetail (old ODBC), TechnicianPunchedDetail (old)
• Old model: ~1.7M rows across 5 tables
• New model: ~2-3K rows in single fact table
• Expected refresh: <30 seconds (was ~3:30 minutes)

============================================================================
*/

let
    // ========================================================================
    // STEP 1: SOURCE DATA FROM LAKEHOUSE (SQL Analytics Endpoint)
    // ========================================================================
    /*
    CONNECTION: Uses Lakehouse SQL analytics endpoint for Power BI Desktop
    SERVER: x6eps4xrq2xudenlfv6naeo3i4-lzqqwvhggkce5c45gst6vgup5a.datawarehouse.fabric.microsoft.com
    DATABASE: LH_Master_Data

    To find your SQL endpoint:
    1. Open Lakehouse in Fabric
    2. Click "SQL analytics endpoint" in the top right
    3. Copy the connection string from Settings
    */

    // SQL Analytics Endpoint connection
    SqlEndpoint = "xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com",
    DatabaseName = "LH_Master_Data",

    // RepairOrderDetail - Core work order data (open orders only)
    RepairOrderDetail =
        let
            Source = Sql.Database(SqlEndpoint, DatabaseName),
            ROD = Source{[Schema = "dbo", Item = "RepairOrderDetail"]}[Data],
            // Filter to open work orders only (not invoiced)
            OpenOnly = Table.SelectRows(ROD, each [StatusDisplay] <> "Invoiced")
        in
            OpenOnly,

    // WKROFILE - Work order master data (customer account, payment method)
    WKROFILE =
        let
            Source = Sql.Database(SqlEndpoint, DatabaseName),
            WKR = Source{[Schema = "dbo", Item = "WKROFILE"]}[Data]
        in
            WKR,

    // TechnicianPunchedDetail - Technician and equipment info
    TechnicianPunched =
        let
            Source = Sql.Database(SqlEndpoint, DatabaseName),
            TPD = Source{[Schema = "dbo", Item = "TechnicianPunchedDetail"]}[Data],
            // Get latest punch per work order (for technician name and model)
            Grouped = Table.Group(TPD, {"WorkOrder"}, {
                {"EquipmentModel", each List.Max([EquipmentModel]), type text},
                {"TechnicianName", each List.Max([TechCode]), type text},
                {"CustomerNamePunch", each List.Max([CustomerName]), type text}
            })
        in
            Grouped,

    // ========================================================================
    // STEP 2: JOIN WKROFILE FOR ACCOUNT NUMBER AND PAYMENT METHOD
    // ========================================================================

    JoinWKROFILE = Table.NestedJoin(
        RepairOrderDetail,
        {"WorkOrder"},
        WKROFILE,
        {"WorkOrder"},
        "WKR",
        JoinKind.LeftOuter
    ),

    ExpandWKROFILE = Table.ExpandTableColumn(JoinWKROFILE, "WKR", {
        "AccountNumber", "PaymentMethod", "Franchise", "Registration"
    }, {
        "AccountNumber", "PayMethod", "Franchise", "Registration"
    }),

    // ========================================================================
    // STEP 3: JOIN TECHNICIAN PUNCHED FOR MODEL AND TECHNICIAN
    // ========================================================================

    JoinTechPunched = Table.NestedJoin(
        ExpandWKROFILE,
        {"WorkOrder"},
        TechnicianPunched,
        {"WorkOrder"},
        "TechPunch",
        JoinKind.LeftOuter
    ),

    ExpandTechPunched = Table.ExpandTableColumn(JoinTechPunched, "TechPunch", {
        "EquipmentModel", "TechnicianName", "CustomerNamePunch"
    }, {
        "Model", "TechCode", "CustomerNamePunch"
    }),

    // ========================================================================
    // STEP 4: ADD CALCULATED COLUMNS
    // ========================================================================

    // Calculate Days Since Last Labor FIRST (needed for aging bucket logic)
    AddDaysSinceLastLaborEarly = Table.AddColumn(ExpandTechPunched, "DaysSinceLastLabor", each
        if [LastLaborPunch] = null or [LastLaborPunch] = #date(1900, 1, 1) then null
        else Duration.Days(Date.From(DateTime.LocalNow()) - Date.From([LastLaborPunch])),
        Int64.Type
    ),

    // Add Aging Bucket - MUTUALLY EXCLUSIVE buckets
    // Logic: "Not Started" takes PRECEDENCE over time buckets
    //   - If no labor punched (DaysSinceLastLabor >= 45000) → "Not Started"
    //   - Otherwise, categorize by DaysSinceCreationDate
    // Note: Source data has DaysSinceLastLabor = 46046 when no labor punch (1/1/1900 default)
    AddAgingBucket = Table.AddColumn(AddDaysSinceLastLaborEarly, "AgingBucket", each
        let
            days = [DaysSinceCreationDate],
            daysLastLabor = [DaysSinceLastLabor]
        in
            // FIRST: Check if no labor has been punched → "Not Started"
            if daysLastLabor = null or daysLastLabor >= 45000 then "Not Started"
            // THEN: Categorize by DaysSinceCreationDate (only for work orders WITH labor)
            else if days > 60 then "60+ Days"
            else if days >= 31 and days <= 60 then "31 - 60 Days"
            else if days >= 15 and days <= 30 then "15 - 30 Days"
            else if days >= 8 and days <= 14 then "8 - 14 Days"
            else if days >= 1 and days <= 7 then "1 - 7 Days"
            else "0 Days",  // Created today or null
        type text
    ),

    // Add Aging Sort Order (60+ at top, Not Started at bottom)
    AddAgingSortOrder = Table.AddColumn(AddAgingBucket, "AgingSortOrder", each
        if [AgingBucket] = "60+ Days" then 1
        else if [AgingBucket] = "31 - 60 Days" then 2
        else if [AgingBucket] = "15 - 30 Days" then 3
        else if [AgingBucket] = "8 - 14 Days" then 4
        else if [AgingBucket] = "1 - 7 Days" then 5
        else 6,  // Not Started
        Int64.Type
    ),

    // Add Progress Status (friendly names)
    AddProgressStatus = Table.AddColumn(AddAgingSortOrder, "ProgressStatusDisplay", each
        let status = [ROProgressStatus]
        in
            if status = "BI" then "Booked In"
            else if status = "BY" then "Booked in on Yard"
            else if status = "CA" then "Customer Advised"
            else if status = "CO" then "Collection"
            else if status = "CP" then "Complete Priced"
            else if status = "CS" then "Complete Service Manager"
            else if status = "CW" then "Customer Waiting"
            else if status = "DA" then "Warranty JAD"
            else if status = "DP" then "In Delay - Part"
            else if status = "MI" then "More Info Needed"
            else if status = "SC" then "Sundry WO - Complete"
            else if status = "WC" then "Warranty Complete"
            else if status = "WF" then "Invoiced"
            else if status = "WJ" then "Warranty JAD"
            else if status = "WO" then "Worked"
            else if status = "WP" then "T-Complete"
            else "Unknown",
        type text
    ),

    // Add DateKey for date dimension relationship
    AddDateKey = Table.AddColumn(AddProgressStatus, "DateKey", each
        if [CreationDate] = null then null else Date.From([CreationDate]),
        type date
    ),

    // Convert AccountNumber to text for dim_CustomerList join
    AddAccountNumberText = Table.AddColumn(AddDateKey, "AccountNumberText", each
        if [AccountNumber] = null then ""
        else Text.From([AccountNumber]),
        type text
    ),

    // ========================================================================
    // STEP 5: SELECT FINAL COLUMNS
    // ========================================================================

    SelectColumns = Table.SelectColumns(AddAccountNumberText, {
        // Core Identifiers
        "Branch",
        "WorkOrder",
        "JobCode",
        "JobType",

        // Timeline
        "CreationDate",
        "JobStartDate",
        "FirstLaborPunch",
        "LastLaborPunch",
        "DateKey",

        // Aging
        "DaysSinceCreationDate",
        "DaysSinceLastLabor",
        "AgingBucket",
        "AgingSortOrder",

        // Status
        "StatusDisplay",
        "ROProgressStatus",
        "ProgressStatusDisplay",

        // Financial
        "LaborRevenue",
        "PartsRevenue",
        "SubletRevenue",
        "OtherRevenue",
        "TotalRevenue",

        // Customer & Equipment (from joins)
        "AccountNumber",
        "AccountNumberText",
        "CustomerNamePunch",
        "PayMethod",
        "Franchise",
        "Registration",
        "Model",
        "TechCode"
    }),

    // ========================================================================
    // STEP 6: SET DATA TYPES
    // ========================================================================

    SetTypes = Table.TransformColumnTypes(SelectColumns, {
        {"Branch", type text},
        {"WorkOrder", type text},
        {"JobCode", type text},
        {"JobType", type text},
        {"CreationDate", type datetime},
        {"JobStartDate", type date},
        {"FirstLaborPunch", type datetime},
        {"LastLaborPunch", type datetime},
        {"DateKey", type date},
        {"DaysSinceCreationDate", Int64.Type},
        {"DaysSinceLastLabor", Int64.Type},
        {"AgingBucket", type text},
        {"AgingSortOrder", Int64.Type},
        {"StatusDisplay", type text},
        {"ROProgressStatus", type text},
        {"ProgressStatusDisplay", type text},
        {"LaborRevenue", type number},
        {"PartsRevenue", type number},
        {"SubletRevenue", type number},
        {"OtherRevenue", type number},
        {"TotalRevenue", type number},
        {"AccountNumber", type text},
        {"AccountNumberText", type text},
        {"CustomerNamePunch", type text},
        {"PayMethod", type text},
        {"Franchise", type text},
        {"Registration", type text},
        {"Model", type text},
        {"TechCode", type text}
    }),

    // Sort by aging (worst first) then by branch
    FinalSort = Table.Sort(SetTypes, {
        {"AgingSortOrder", Order.Ascending},
        {"Branch", Order.Ascending},
        {"WorkOrder", Order.Ascending}
    })

in
    FinalSort

/*
============================================================================
✅ IMPLEMENTATION NOTES
============================================================================

📊 EXPECTED OUTPUT:
• ~2,000-3,000 rows (open work orders only)
• 28 columns covering all WIP report needs
• Pre-calculated aging buckets for fast filtering

🔗 MODEL RELATIONSHIPS TO CREATE:
1. Fact_OpenWorkOrders[Branch] → dim_Branch[Branch] (M:1)
2. Fact_OpenWorkOrders[DateKey] → dim_DateTable[Date] (M:1)
3. Fact_OpenWorkOrders[AccountNumberText] → dim_CustomerList[AccountNumberText] (M:1)

📈 DAX MEASURES NEEDED:
• Sales totals: SUM each revenue field
• Aging counts: COUNTROWS filtered by AgingBucket
• Aging sales: SUM filtered by AgingBucket

🎯 REPORT VISUALS:
• Page 1 (WIP Overview):
  - KPI cards for sales metrics
  - Aging bucket cards with counts
  - Clustered column chart by branch

• Page 2 (WIP Details):
  - Detail table with conditional formatting
  - Aging bucket filter/slicer

⚡ PERFORMANCE:
• Expected refresh: <30 seconds
• Old model refresh: ~3:30 minutes
• Improvement: ~85% reduction in refresh time

============================================================================
*/