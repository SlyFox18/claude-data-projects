/*
============================================================================
DIM_BRANCH12_PARTS - BRANCH 12 PARTS DIMENSION (SIMPLIFIED)
============================================================================

📋 PURPOSE:
Clean, simple parts dimension for Branch 12 with accurate sales metrics.
All intelligence and categorization is handled in DAX measures for flexibility.

🎯 KEY FEATURES:
- Branch 12-filtered parts only
- Accurate inventory levels (QuantityOnHand, BinQty, etc.)
- R12 sales metrics calculated from fact table (Demands, Sales Qty, Sales $)
- Clean, complete descriptions (no truncation)
- Simple structure - easy to maintain and extend

📊 SOURCE:
- jdis_Part_Information (filtered to Branch = '12')
- Fact_Branch12_Transactions (for accurate R12 metrics)

🔗 RELATIONSHIPS:
- Fact_Branch12_Transactions[PartNumber] → dim_Branch12_Parts[PartNumber]

📄 SUPPORTS:
- Page 1: Sales analysis, margin analysis, inventory KPIs
- Page 2: Restocking tool with stock status (calculated in DAX)

============================================================================
*/

let
    // ========================================================================
    // STEP 1: LOAD SOURCE TABLES
    // ========================================================================
    
    SourceParts = jdis_Part_Information,
    SourceFact = Fact_Branch12_Transactions,
    
    // ========================================================================
    // STEP 2: FILTER TO BRANCH 12 PARTS
    // ========================================================================
    /*
    PURPOSE: Get only Branch 12 parts for accurate inventory levels
    CRITICAL: Branch 12 is a mobile parts trailer, not a retail location
    */
    
    FilterBranch12 = Table.SelectRows(SourceParts, each ([Branch] = "12")),
    
    // ========================================================================
    // STEP 3: SELECT ESSENTIAL COLUMNS FROM PARTS MASTER
    // ========================================================================
    /*
    PURPOSE: Include all columns needed for both report pages
    COVERAGE:
    - Page 1: Inventory values, pricing, margins
    - Page 2: Stock levels, bin locations, vendor info
    */
    
    SelectColumns = Table.SelectColumns(FilterBranch12, {
        // === CORE IDENTIFICATION ===
        "PartNumber",
        "Description",        // Full description (no truncation)
        "Franchise",
        
        // === BUSINESS CLASSIFICATIONS ===
        "Source",
        "SLC",
        "DealerGroupCode",
        "CommodityCode",
        "VendorCode",
        
        // === BRANCH 12 INVENTORY (CURRENT SNAPSHOT) ===
        "QuantityOnHand",     // Current stock at Branch 12
        "BinQty",             // Bin quantity at Branch 12
        "BulkBinQty",         // Bulk bin quantity at Branch 12
        "PendingQty",         // Pending orders for Branch 12
        "BackOrderQty",       // Backorders at Branch 12
        "Bin",                // Bin location at Branch 12
        "BulkBin",            // Bulk bin location
        "Returnable",         // Return indicator
        
        // === BRANCH 12 PRICING & COSTS ===
        "Cost",               // Current cost at Branch 12
        "SellPrice1",         // Selling price at Branch 12
        "ListPrice",          // List price
        "InventoryCost"       // Total inventory value (Qty × Cost)
    }),
    
    // ========================================================================
    // STEP 4: DATA CLEANING
    // ========================================================================
    /*
    PURPOSE: Clean and standardize all text fields
    CRITICAL: Description must not be truncated - preserve full text
    */
    
    // Clean PartNumber - uppercase and trim
    CleanPartNumber = Table.TransformColumns(SelectColumns, {
        {"PartNumber", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text}
    }),
    
    // Clean Description - proper case and trim, NO TRUNCATION
    CleanDescription = Table.TransformColumns(CleanPartNumber, {
        {"Description", each 
            let
                rawText = if _ = null then "" else Text.From(_),
                trimmedText = Text.Trim(rawText),
                properCase = if trimmedText = "" then "" else Text.Proper(trimmedText)
            in
                properCase, 
            type text
        }
    }),
    
    // Clean Franchise - uppercase and trim
    CleanFranchise = Table.TransformColumns(CleanDescription, {
        {"Franchise", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text}
    }),
    
    // Clean all other text fields
    CleanBusinessFields = Table.TransformColumns(CleanFranchise, {
        {"Source", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"SLC", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"DealerGroupCode", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"CommodityCode", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"VendorCode", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"Bin", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"BulkBin", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"Returnable", each Text.Upper(Text.Trim(Text.From(_ ?? "N"))), type text}
    }),
    
    // ========================================================================
    // STEP 5: CALCULATE R12 METRICS FROM FACT TABLE
    // ========================================================================
    /*
    PURPOSE: Calculate accurate sales metrics from actual transactions
    BUSINESS LOGIC: 
    - Demands = Count of sale transactions in last 365 days
    - R12_Sales_Qty = Total quantity sold in last 365 days
    - R12_Sales_Dollars = Total $ sold in last 365 days
    - Uses fact table since Branch 12 sales are transfers, not retail
    
    USAGE:
    - Page 1: Sales analysis, trending
    - Page 2: Velocity calculations for reordering
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
    // STEP 6: MERGE R12 METRICS INTO PARTS DIMENSION
    // ========================================================================
    /*
    PURPOSE: Join the calculated R12 metrics back to each part
    LOGIC: Left join so parts with no sales still appear (with 0 metrics)
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
    // STEP 7: ADD CONVENIENCE FLAGS
    // ========================================================================
    /*
    PURPOSE: Simple boolean flags for common filters
    USAGE: Easy filtering in visuals and DAX measures
    */
    
    AddIsAvailable = Table.AddColumn(ReplaceNullMetrics, "IsAvailable", each
        if [QuantityOnHand] = null then false else [QuantityOnHand] > 0, 
        type logical),
    
    AddHasRecentSales = Table.AddColumn(AddIsAvailable, "HasRecentSales", each
        if [Demands] = null then false else [Demands] > 0, 
        type logical),
    
    AddIsReturnable = Table.AddColumn(AddHasRecentSales, "IsReturnable", each
        [Returnable] = "Y", 
        type logical),
    
    // ========================================================================
    // STEP 8: ADD UNIT-LEVEL MARGIN CALCULATIONS
    // ========================================================================
    /*
    PURPOSE: Pre-calculate unit margin for reference
    NOTE: Actual margin $ totals are calculated in DAX from fact table
    USAGE: Reference for pricing analysis
    */
    
    AddUnitMarginDollars = Table.AddColumn(AddIsReturnable, "Unit Margin Dollars", each
        let
            sellPrice = if [SellPrice1] = null then 0 else [SellPrice1],
            cost = if [Cost] = null then 0 else [Cost]
        in
            sellPrice - cost, 
        type number),
    
    AddUnitMarginPercent = Table.AddColumn(AddUnitMarginDollars, "Unit Margin Percent", each
        let
            sellPrice = if [SellPrice1] = null then 0 else [SellPrice1],
            margin = if [Unit Margin Dollars] = null then 0 else [Unit Margin Dollars]
        in
            if sellPrice > 0 then margin / sellPrice else 0, 
        type number),
    
    // ========================================================================
    // STEP 9: DATA QUALITY & DEDUPLICATION
    // ========================================================================
    
    RemoveDuplicates = Table.Distinct(AddUnitMarginPercent, {"PartNumber"}),
    
    RemoveBlankRows = Table.SelectRows(RemoveDuplicates, each 
        ([PartNumber] ?? "") <> ""),
    
    SortByPartNumber = Table.Sort(RemoveBlankRows, {{"PartNumber", Order.Ascending}}),
    
    // ========================================================================
    // STEP 10: SURROGATE KEY GENERATION
    // ========================================================================
    
    AddSurrogateKey = Table.AddIndexColumn(SortByPartNumber, "PartNumberKey", 1, 1, Int64.Type),
    
    // ========================================================================
    // STEP 11: COLUMN ORGANIZATION
    // ========================================================================
    /*
    PURPOSE: Organize columns logically for easy navigation
    ORDER: Keys → Identification → Inventory → Metrics → Pricing → Classifications
    */
    
    ReorderColumns = Table.ReorderColumns(AddSurrogateKey, {
        // === KEYS & IDENTIFICATION ===
        "PartNumberKey",
        "PartNumber",
        "Description",
        "Franchise",
        
        // === BRANCH 12 INVENTORY (CURRENT SNAPSHOT) ===
        "QuantityOnHand",
        "BinQty",
        "BulkBinQty",
        "PendingQty",
        "BackOrderQty",
        "Bin",
        "BulkBin",
        "IsAvailable",
        
        // === R12 SALES METRICS (FROM FACT TABLE) ===
        "Demands",              // Transaction count last 365 days
        "R12_Sales_Qty",        // Total quantity sold last 365 days
        "R12_Sales_Dollars",    // Total $ sold last 365 days
        "HasRecentSales",
        
        // === PRICING & COSTS ===
        "Cost",
        "SellPrice1",
        "ListPrice",
        "InventoryCost",        // Total inventory value (Qty × Cost)
        "Unit Margin Dollars",  // Unit-level margin
        "Unit Margin Percent",  // Unit-level margin %
        
        // === BUSINESS CLASSIFICATIONS ===
        "Source",
        "SLC",
        "DealerGroupCode",
        "CommodityCode",
        "VendorCode",
        
        // === OPERATIONAL FLAGS ===
        "Returnable",
        "IsReturnable"
    }),
    
    // ========================================================================
    // STEP 12: SPECIAL UNKNOWN RECORD
    // ========================================================================
    /*
    PURPOSE: Placeholder for unmatched parts in fact table
    USAGE: PartNumberKey = -1 for any orphaned transactions
    */
    
    UnknownRecord = Table.FromRecords({
        [
            PartNumberKey = -1,
            PartNumber = "UNKNOWN",
            Description = "Unknown Part",
            Franchise = "UNKNOWN",
            QuantityOnHand = 0,
            BinQty = 0,
            BulkBinQty = 0,
            PendingQty = 0,
            BackOrderQty = 0,
            Bin = "",
            BulkBin = "",
            IsAvailable = false,
            Demands = 0,
            R12_Sales_Qty = 0,
            R12_Sales_Dollars = 0,
            HasRecentSales = false,
            Cost = 0,
            SellPrice1 = 0,
            ListPrice = 0,
            InventoryCost = 0,
            #"Unit Margin Dollars" = 0,
            #"Unit Margin Percent" = 0,
            Source = "UNKNOWN",
            SLC = "UNKNOWN",
            DealerGroupCode = "UNKNOWN",
            CommodityCode = "UNKNOWN",
            VendorCode = "UNKNOWN",
            Returnable = "N",
            IsReturnable = false
        ]
    }),
    
    // ========================================================================
    // STEP 13: FINAL INTEGRATION & DATA TYPES
    // ========================================================================
    
    CombinedData = Table.Combine({UnknownRecord, ReorderColumns}),
    
    FinalDataTypes = Table.TransformColumnTypes(CombinedData, {
        // Keys and identification
        {"PartNumberKey", Int64.Type},
        {"PartNumber", type text},
        {"Description", type text},
        {"Franchise", type text},
        
        // Inventory
        {"QuantityOnHand", type number},
        {"BinQty", type number},
        {"BulkBinQty", type number},
        {"PendingQty", type number},
        {"BackOrderQty", type number},
        {"Bin", type text},
        {"BulkBin", type text},
        {"IsAvailable", type logical},
        
        // R12 sales metrics
        {"Demands", Int64.Type},
        {"R12_Sales_Qty", type number},
        {"R12_Sales_Dollars", type number},
        {"HasRecentSales", type logical},
        
        // Pricing and costs
        {"Cost", type number},
        {"SellPrice1", type number},
        {"ListPrice", type number},
        {"InventoryCost", type number},
        {"Unit Margin Dollars", type number},
        {"Unit Margin Percent", type number},
        
        // Classifications
        {"Source", type text},
        {"SLC", type text},
        {"DealerGroupCode", type text},
        {"CommodityCode", type text},
        {"VendorCode", type text},
        
        // Operational flags
        {"Returnable", type text},
        {"IsReturnable", type logical}
    }),
    
    FinalSort = Table.Sort(FinalDataTypes, {{"PartNumberKey", Order.Ascending}})

in
    FinalSort

/*
============================================================================
✅ DIM_BRANCH12_PARTS - READY FOR USE
============================================================================

📊 COLUMNS PROVIDED:

KEYS & IDENTIFICATION:
- PartNumberKey - Surrogate key for relationships
- PartNumber - Part number (cleaned, uppercase)
- Description - FULL description (no truncation)
- Franchise - Manufacturer/brand

INVENTORY (Current Snapshot):
- QuantityOnHand - Current stock at Branch 12
- BinQty - Bin quantity
- BulkBinQty - Bulk bin quantity
- PendingQty - Pending orders
- BackOrderQty - Backorders
- Bin - Bin location
- BulkBin - Bulk bin location
- IsAvailable - Boolean: Has stock (Qty > 0)

R12 SALES METRICS (Last 365 Days from Fact Table):
- Demands - Transaction count (# of times sold)
- R12_Sales_Qty - Total quantity sold
- R12_Sales_Dollars - Total $ sold
- HasRecentSales - Boolean: Has demand (Demands > 0)

PRICING & COSTS:
- Cost - Current cost per unit
- SellPrice1 - Selling price per unit
- ListPrice - List price
- InventoryCost - Total inventory value (Qty × Cost)
- Unit Margin Dollars - Sell price - Cost
- Unit Margin Percent - Margin / Sell price

CLASSIFICATIONS:
- Source - Part source
- SLC - Service Level Code
- DealerGroupCode - Dealer group
- CommodityCode - Commodity classification
- VendorCode - Vendor/supplier code

OPERATIONAL:
- Returnable - Return flag (Y/N)
- IsReturnable - Boolean version

🔗 RELATIONSHIPS:
- Fact_Branch12_Transactions[PartNumber] → dim_Branch12_Parts[PartNumber]

📄 PAGE 1 USAGE (Current - Won't Break):
- Sales analysis: R12_Sales_Qty, R12_Sales_Dollars
- Inventory KPIs: QuantityOnHand, InventoryCost
- Margin analysis: Unit Margin Dollars/Percent
- Parts table: All identification and metric columns

📄 PAGE 2 USAGE (Restocking Tool):
- Stock levels: QuantityOnHand, BinQty, PendingQty
- Velocity: Demands, R12_Sales_Qty
- Reorder calculations: Done in DAX measures
- Stock Status: Calculated as DAX measure

⚡ WHAT'S DIFFERENT FROM BEFORE:
✓ Removed: Current12MoSales columns (inaccurate for Branch 12)
✓ Removed: Complex Stock Status calculated column (moved to DAX)
✓ Removed: Months of Supply calculated column (moved to DAX)
✓ Removed: Suggested Order Qty calculated column (moved to DAX)
✓ Fixed: Description field - NO TRUNCATION, full text preserved
✓ Kept: All columns needed for Page 1 (won't break existing visuals)
✓ Added: Clean R12 metrics from fact table (Demands, Sales Qty, Sales $)
✓ Simplified: Clean structure, easy to maintain

⚙️ MAINTENANCE:
- To change R12 period: Modify Days365Ago calculation in Step 5
- To add new metrics: Add to Step 5 grouping and Step 6 expansion
- All intelligence/categorization: Done in DAX (flexible, easy to adjust)

🧪 VALIDATION CHECKLIST:
After refresh, verify:
1. ✅ Description column shows full text (not truncated)
2. ✅ Demands column has values for parts with sales
3. ✅ R12_Sales_Qty matches transaction quantities
4. ✅ IsAvailable = true for parts with Qty > 0
5. ✅ HasRecentSales = true for parts with Demands > 0
6. ✅ Page 1 visuals still work (no broken references)

============================================================================
*/