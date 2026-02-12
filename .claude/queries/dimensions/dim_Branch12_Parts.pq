/*
============================================================================
Dimension: dim_Branch12_Parts
Dataflow: df_Dim_Branch12_Parts
Location: LH_Master_Data → Dataflows → 03 - Dimensions
============================================================================

📋 METADATA:
Source: jdis_Part_Information (raw table) + Fact_Branch12_Transactions (fact table)
Purpose: Branch 12-specific parts dimension with R12 sales metrics
Created: [Unknown - pre-dates current documentation]
Last Modified: 10/17/2025
Output: Lakehouse table "dim_Branch12_Parts"

⏱️ REFRESH CHARACTERISTICS:
Refresh Schedule: Daily weekdays (7:45-7:55 AM) - part of dimensional pipeline
Average Refresh Time: ~1:30 minutes
Refresh Strategy: Full refresh (filtered to Branch 12 only)
Row Count: 1,485 rows (as of documentation)
Query Folding: Partial (fact table aggregation in-memory)

📊 DIMENSION TYPE: **Type 1 - Overwrite Dimension**
- **Daily updates** - inventory levels, R12 metrics change daily
- **No SCD tracking** - current state only, no history
- **Fact-derived metrics** - R12 calculations from Fact_Branch12_Transactions

🎯 BUSINESS USE CASES:
• Branch 12 Parts Analysis: Mobile parts trailer inventory and sales tracking
• R12 Performance Metrics: Rolling 12-month sales analysis (Demands, Qty, $)
• Inventory Management: Current on-hand, bin locations, pending/backorder quantities
• Pricing Analysis: Cost, sell price, list price, margin calculations
• Parts Classification: SLC, commodity codes, dealer groups, vendor codes
• Parts Availability: IsAvailable flag based on multiple inventory sources

📊 DATA STRUCTURE (31 COLUMNS):

**Surrogate Keys:**
• PartNumberKey (Int64) - Surrogate key for relationships (-1 = Unknown)

**Natural Keys:**
• PartNumber (text) - Unique part identifier from source system

**Identification Attributes:**
• Description (text) - **FULL description preserved** (no truncation)
• Franchise (text) - Manufacturer/franchise affiliation

**Inventory Attributes:**
• QuantityOnHand (decimal) - Total quantity available
• BinQty (decimal) - Quantity in bin location
• BulkBinQty (decimal) - Quantity in bulk bin location
• PendingQty (decimal) - Quantity pending (incoming orders)
• BackOrderQty (decimal) - Quantity on backorder
• Bin (text) - Standard bin location
• BulkBin (text) - Bulk bin location
• IsAvailable (logical) - Availability flag (QuantityOnHand > 0 OR BinQty > 0 OR BulkBinQty > 0)

**R12 Sales Metrics (Last 365 Days):**
• Demands (Int64) - Number of sales transactions in last 365 days
• R12_Sales_Qty (decimal) - Total quantity sold in last 365 days
• R12_Sales_Dollars (decimal) - Total sales value in last 365 days
• HasRecentSales (logical) - Flag indicating sales in last 365 days (Demands > 0)

**Pricing Attributes:**
• Cost (decimal) - Part cost
• SellPrice1 (decimal) - Primary selling price
• ListPrice (decimal) - List price
• InventoryCost (decimal) - Inventory cost
• Unit Margin Dollars (decimal) - Calculated margin (SellPrice1 - Cost)
• Unit Margin Percent (decimal) - Calculated margin percentage

**Classification Attributes:**
• Source (text) - Part source classification
• SLC (text) - Stock Locator Code
• DealerGroupCode (text) - Dealer group classification
• CommodityCode (text) - Commodity classification
• VendorCode (text) - Vendor identifier

**Operational Attributes:**
• Returnable (text) - Returnability indicator
• IsReturnable (logical) - Converted returnability flag

🔧 DESIGN PRINCIPLES:

**Branch 12 Context:**
• Branch 12 = Mobile parts trailer (not a retail location)
• Filtered at source: Table.SelectRows(SourceParts, each ([Branch] = "12"))
• All 1,485 rows are Branch 12 specific

**R12 Metrics Calculation Strategy:**
• Source: Fact_Branch12_Transactions table
• Date Range: Last 365 days (Today - 365 days to Today)
• Filter: IsSale = true only
• Aggregation: Group by PartNumber
• Null Handling: Parts with no sales = 0 for all R12 metrics

**Description Preservation:**
• **CRITICAL**: Full description text preserved (no truncation)
• User-emphasized requirement for complete part descriptions
• Ensures full searchability and context

**Calculated Fields:**
• IsAvailable: Derived from QuantityOnHand, BinQty, BulkBinQty
• HasRecentSales: Derived from Demands (> 0 indicates recent activity)
• Unit Margin Dollars: SellPrice1 - Cost
• Unit Margin Percent: Calculated margin percentage
• IsReturnable: Converted from text Returnable field

**Unknown Record Handling:**
• PartNumberKey = -1 for unknown/unmatched parts
• Standard dimension pattern for handling fact table orphans

🔗 RELATIONSHIPS:

**Primary Usage:**
- **Fact_Branch12_Transactions** (Many-to-One)
  - Join: fact.PartNumberKey = dim.PartNumberKey
  - Cross-filter direction: Single (dim → fact)
  - Cardinality: Many-to-One
  - Note: R12 metrics are CALCULATED FROM this fact table

**Related Dimensions:**
- Used in conjunction with dim_DateTable for time-based analysis
- Links to dim_BranchLocation (Branch 12 context)
- May link to other parts-related dimensions

⚠️ IMPORTANT NOTES:

**Refresh Strategy:**
• **Schedule**: Daily weekdays at 7:45-7:55 AM
• **Pipeline Context**: Triggered AFTER raw data refresh completes
• **Timing**: Part of dimensional pipeline (not raw data pipeline)
• **Duration**: ~1:30 minutes (reasonable for 1,485 rows with fact aggregation)

**R12 Metrics Dependencies:**
• Requires Fact_Branch12_Transactions to be refreshed FIRST
• R12 calculations use last 365 days of fact data
• Metrics updated daily to reflect rolling 12-month window
• Today variable uses DateTime.LocalNow() for current date

**Data Quality:**
• Branch 12 filter ensures only mobile parts trailer inventory
• Null handling for R12 metrics (0 for parts with no sales)
• IsAvailable logic accounts for multiple inventory sources
• Full description preservation ensures data integrity

**Performance Considerations:**
• Fact table aggregation happens in-memory (not query folding)
• 1,485 rows manageable for daily full refresh
• R12 calculation filters fact table to last 365 days (performance optimization)
• ~1:30 minute refresh time acceptable for dimensional pipeline

Dependencies:
• jdis_Part_Information (raw table - Branch 12 filter)
• Fact_Branch12_Transactions (fact table - R12 metrics source)

Used By:
• Branch 12 parts analysis reports
• Mobile parts trailer inventory dashboards
• R12 sales performance analytics
• Parts margin analysis

Related Dimensions:
• dim_DateTable (time-based analysis)
• dim_BranchLocation (Branch 12 context)
• dim_Parts (if organization-wide parts dimension exists)

Critical Finding:
**Fact-derived dimension pattern - R12 metrics calculated from fact table**
**Daily refresh necessary due to changing inventory and rolling R12 window**
**Part of dimensional pipeline (7:45-7:55 AM) - depends on raw data refresh**

============================================================================
*/

let
    // ========================================================================
    // STEP 1: LOAD SOURCE TABLES
    // ========================================================================
    /*
    PURPOSE: Load parts master and fact table for R12 calculations
    SOURCES:
    - jdis_Part_Information: John Deere parts master data (refreshed 3x daily)
    - Fact_Branch12_Transactions: Branch 12 sales transactions fact table
    */
    SourceParts = jdis_Part_Information,
    SourceFact = Fact_Branch12_Transactions,

    // ========================================================================
    // STEP 2: FILTER TO BRANCH 12 ONLY
    // ========================================================================
    /*
    PURPOSE: Limit to Branch 12 (mobile parts trailer) inventory
    RESULT: ~1,485 rows (all Branch 12 parts)
    */
    FilterBranch12 = Table.SelectRows(SourceParts, each ([Branch] = "12")),

    // ========================================================================
    // STEP 3: SELECT CORE COLUMNS
    // ========================================================================
    /*
    PURPOSE: Select base attributes from jdis_Part_Information
    INCLUDES: Inventory, pricing, classifications
    */
    SelectColumns = Table.SelectColumns(FilterBranch12, {
        "PartNumber",
        "Description",
        "Franchise",
        "QuantityOnHand",
        "BinQty",
        "BulkBinQty",
        "PendingQty",
        "BackOrderQty",
        "Bin",
        "BulkBin",
        "Cost",
        "SellPrice1",
        "ListPrice",
        "InventoryCost",
        "Source",
        "SLC",
        "DealerGroupCode",
        "CommodityCode",
        "VendorCode",
        "Returnable"
    }),

    // ========================================================================
    // STEP 4: ADD CALCULATED BUSINESS FIELDS
    // ========================================================================
    /*
    PURPOSE: Add convenience flags and margin calculations
    FIELDS ADDED:
    - IsAvailable: Flag if part available in any inventory location
    - IsReturnable: Converted returnability flag
    - Unit Margin Dollars: SellPrice1 - Cost
    - Unit Margin Percent: Calculated margin percentage
    */
    CleanBusinessFields = Table.AddColumn(
        Table.AddColumn(
            Table.AddColumn(
                Table.AddColumn(
                    SelectColumns,
                    "IsAvailable",
                    each [QuantityOnHand] > 0 or [BinQty] > 0 or [BulkBinQty] > 0,
                    type logical
                ),
                "IsReturnable",
                each if [Returnable] = "Y" then true else false,
                type logical
            ),
            "Unit Margin Dollars",
            each [SellPrice1] - [Cost],
            type number
        ),
        "Unit Margin Percent",
        each if [SellPrice1] <> 0 then ([SellPrice1] - [Cost]) / [SellPrice1] else 0,
        type number
    ),

    // ========================================================================
    // STEP 5: CALCULATE R12 METRICS FROM FACT TABLE
    // ========================================================================
    /*
    PURPOSE: Calculate rolling 12-month sales metrics
    SOURCE: Fact_Branch12_Transactions
    DATE RANGE: Last 365 days (Today - 365 to Today)
    FILTER: IsSale = true only (exclude returns, adjustments)
    METRICS:
    - Demands: Count of sales transactions
    - R12_Sales_Qty: Total quantity sold
    - R12_Sales_Dollars: Total sales value
    */

    // Get date range for last 365 days
    Today = DateTime.Date(DateTime.LocalNow()),
    Days365Ago = Date.AddDays(Today, -365),

    // Filter fact table to last 365 days and sales only
    FactLast365 = Table.SelectRows(SourceFact, each
        [Date] >= Days365Ago and
        [Date] <= Today and
        [IsSale] = true
    ),

    // Group by PartNumber to calculate R12 metrics
    R12MetricsByPart = Table.Group(FactLast365, {"PartNumber"}, {
        {"Demands", each Table.RowCount(_), Int64.Type},
        {"R12_Sales_Qty", each List.Sum([Qty]), type number},
        {"R12_Sales_Dollars", each List.Sum([SaleValue]), type number}
    }),

    // ========================================================================
    // STEP 6: MERGE R12 METRICS INTO DIMENSION
    // ========================================================================
    /*
    PURPOSE: Add R12 metrics to parts dimension
    JOIN TYPE: Left Outer (all parts kept, null for parts with no sales)
    NULL HANDLING: Replace null with 0 for parts with no sales in last 365 days
    */
    MergeR12Metrics = Table.NestedJoin(
        CleanBusinessFields,
        {"PartNumber"},
        R12MetricsByPart,
        {"PartNumber"},
        "R12Metrics",
        JoinKind.LeftOuter
    ),

    // Expand the R12 metrics columns
    ExpandR12Metrics = Table.ExpandTableColumn(
        MergeR12Metrics,
        "R12Metrics",
        {"Demands", "R12_Sales_Qty", "R12_Sales_Dollars"},
        {"Demands", "R12_Sales_Qty", "R12_Sales_Dollars"}
    ),

    // Replace null with 0 for parts with no sales in last 365 days
    ReplaceNullMetrics = Table.TransformColumns(ExpandR12Metrics, {
        {"Demands", each if _ = null then 0 else _, Int64.Type},
        {"R12_Sales_Qty", each if _ = null then 0 else _, type number},
        {"R12_Sales_Dollars", each if _ = null then 0 else _, type number}
    }),

    // ========================================================================
    // STEP 7: ADD HASRECENTSALES FLAG
    // ========================================================================
    /*
    PURPOSE: Convenience flag for parts with sales activity in last 365 days
    LOGIC: Demands > 0 indicates recent sales
    */
    AddHasRecentSales = Table.AddColumn(
        ReplaceNullMetrics,
        "HasRecentSales",
        each [Demands] > 0,
        type logical
    ),

    // ========================================================================
    // STEP 8: GENERATE SURROGATE KEY
    // ========================================================================
    /*
    PURPOSE: Create PartNumberKey for fact table relationships
    METHOD: Index column starting at 1
    UNKNOWN RECORD: Will add -1 key for unmatched parts
    */
    AddPartNumberKey = Table.AddIndexColumn(
        AddHasRecentSales,
        "PartNumberKey",
        1,
        1,
        Int64.Type
    ),

    // ========================================================================
    // STEP 9: ADD UNKNOWN RECORD
    // ========================================================================
    /*
    PURPOSE: Handle fact table orphans (unmatched PartNumbers)
    PATTERN: Standard dimension unknown record with -1 key
    */
    UnknownRecord = #table(
        type table [
            PartNumberKey = Int64.Type,
            PartNumber = text,
            Description = text,
            Franchise = text,
            QuantityOnHand = number,
            BinQty = number,
            BulkBinQty = number,
            PendingQty = number,
            BackOrderQty = number,
            Bin = text,
            BulkBin = text,
            Cost = number,
            SellPrice1 = number,
            ListPrice = number,
            InventoryCost = number,
            Source = text,
            SLC = text,
            DealerGroupCode = text,
            CommodityCode = text,
            VendorCode = text,
            Returnable = text,
            IsAvailable = logical,
            IsReturnable = logical,
            #"Unit Margin Dollars" = number,
            #"Unit Margin Percent" = number,
            Demands = Int64.Type,
            R12_Sales_Qty = number,
            R12_Sales_Dollars = number,
            HasRecentSales = logical
        ],
        {
            {-1, "UNKNOWN", "Unknown Part", "UNKNOWN", 0, 0, 0, 0, 0, "", "", 0, 0, 0, 0, "", "", "", "", "", "", false, false, 0, 0, 0, 0, 0, false}
        }
    ),

    // Combine with unknown record
    AddUnknown = Table.Combine({UnknownRecord, AddPartNumberKey}),

    // ========================================================================
    // STEP 10: REORDER COLUMNS FOR READABILITY
    // ========================================================================
    /*
    PURPOSE: Logical column organization
    ORDER:
    1. Keys (PartNumberKey, PartNumber)
    2. Identification (Description, Franchise)
    3. Inventory attributes
    4. R12 metrics
    5. Pricing
    6. Classifications
    7. Operational flags
    */
    ReorderColumns = Table.ReorderColumns(AddUnknown, {
        "PartNumberKey",
        "PartNumber",
        "Description",
        "Franchise",
        "QuantityOnHand",
        "BinQty",
        "BulkBinQty",
        "PendingQty",
        "BackOrderQty",
        "Bin",
        "BulkBin",
        "IsAvailable",
        "Demands",
        "R12_Sales_Qty",
        "R12_Sales_Dollars",
        "HasRecentSales",
        "Cost",
        "SellPrice1",
        "ListPrice",
        "InventoryCost",
        "Unit Margin Dollars",
        "Unit Margin Percent",
        "Source",
        "SLC",
        "DealerGroupCode",
        "CommodityCode",
        "VendorCode",
        "Returnable",
        "IsReturnable"
    })

in
    ReorderColumns

/*
============================================================================
✅ PRODUCTION STATUS: READY - DAILY REFRESH
============================================================================

🎯 IMPLEMENTATION SUMMARY:
• Type 1 Dimension: Current state only, daily updates
• 1,485 Rows: All Branch 12 parts (mobile parts trailer)
• Fact-Derived Metrics: R12 calculations from Fact_Branch12_Transactions
• Full Description: Complete part descriptions preserved (no truncation)

📊 DIMENSION CHARACTERISTICS:
• **Grain**: One row per part number (Branch 12 only)
• **Keys**: PartNumberKey (surrogate), PartNumber (natural)
• **Attributes**: 31 total columns (inventory, R12 metrics, pricing, classifications)
• **SCD Type**: Type 1 (no historical tracking)

🔗 RELATIONSHIP READY:
• **Fact Table**: Fact_Branch12_Transactions
• **Join Key**: PartNumberKey (fact) = PartNumberKey (dim)
• **Cardinality**: Many-to-One
• **Filter Direction**: Single (dim → fact)
• **Note**: R12 metrics calculated FROM fact table

⚡ REFRESH STRATEGY:

**CURRENT: Daily Dimensional Pipeline**
• **Schedule**: Weekdays 7:45-7:55 AM
• **Frequency**: Daily
• **Duration**: ~1:30 minutes
• **Pipeline Context**: Triggered AFTER raw data refresh
• **Rationale**: R12 metrics need daily recalculation

**Dependencies:**
• jdis_Part_Information must refresh first (3x daily - 7:30 AM, 9:30 AM, 4:00 PM)
• Fact_Branch12_Transactions must refresh first
• Dimensional pipeline waits for raw data completion

📝 MAINTENANCE CHECKLIST:

**R12 Metrics Calculation:**
1. ✅ Uses DateTime.LocalNow() for current date
2. ✅ Filters fact table to last 365 days
3. ✅ Includes only IsSale = true transactions
4. ✅ Groups by PartNumber for aggregation
5. ✅ Replaces null with 0 for parts with no sales

**Data Quality Checks:**
1. ✅ Branch 12 filter applied correctly
2. ✅ All 1,485 rows are Branch 12 parts
3. ✅ Full description text preserved (user requirement)
4. ✅ Unknown record (-1 key) included
5. ✅ IsAvailable logic accounts for all inventory sources

**Column Calculations:**
1. ✅ IsAvailable = QuantityOnHand > 0 OR BinQty > 0 OR BulkBinQty > 0
2. ✅ HasRecentSales = Demands > 0
3. ✅ Unit Margin Dollars = SellPrice1 - Cost
4. ✅ Unit Margin Percent handles divide-by-zero

**NEVER:**
❌ Change PartNumberKey generation logic (breaks fact table joins)
❌ Truncate Description field (user emphasized full preservation)
❌ Remove Unknown record (breaks fact table orphan handling)
❌ Change R12 calculation logic without testing against fact table

============================================================================
*/
