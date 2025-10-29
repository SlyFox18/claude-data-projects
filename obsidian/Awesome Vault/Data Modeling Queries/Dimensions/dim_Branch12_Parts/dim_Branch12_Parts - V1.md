/*
============================================================================
DIM_BRANCH12_PARTS - BRANCH 12 SPECIFIC PARTS DIMENSION
============================================================================

📋 PURPOSE:
Dedicated parts dimension for Branch 12 (R12 - Mobile Parts Trailer) with
Branch 12-specific inventory, pricing, and sales intelligence.

🎯 KEY FEATURES:
• Branch 12-filtered parts only
• Accurate Branch 12 inventory levels (QuantityOnHand, BinQty, etc.)
• Branch 12-specific pricing and cost data
• 12-month sales history for Branch 12
• Demand intelligence (Current12MoSales = "Demands" in report)
• Stock status and availability flags

📊 SOURCE:
jdis_Part_Information filtered to Branch = '12'

🔗 RELATIONSHIPS:
• fact_Branch12_Transactions[PartNumber] → dim_Branch12_Parts[PartNumber]

============================================================================
*/

let
    // ========================================================================
    // STEP 1: SOURCE DATA WITH BRANCH 12 FILTER
    // ========================================================================
    
    // Start with raw parts information
    Source = jdis_Part_Information,
    
    // CRITICAL: Filter to Branch 12 only to get accurate inventory levels
    FilterBranch12 = Table.SelectRows(Source, each ([Branch] = "12")),
    
    // ========================================================================
    // STEP 2: SELECT COLUMNS FOR BRANCH 12 INTELLIGENCE
    // ========================================================================
    
    SelectColumns = Table.SelectColumns(FilterBranch12, {
        // === CORE IDENTIFICATION ===
        "PartNumber",
        "Description", 
        "Franchise",
        
        // === BUSINESS CLASSIFICATIONS ===
        "Source",
        "SLC",
        "DealerGroupCode",
        "CommodityCode",
        "VendorCode",
        
        // === BRANCH 12 INVENTORY (CRITICAL FOR R12 REPORT) ===
        "QuantityOnHand",      // Current stock at Branch 12
        "BinQty",              // Bin quantity at Branch 12
        "BulkBinQty",          // Bulk bin quantity at Branch 12
        "PendingQty",          // Pending orders for Branch 12
        "BackOrderQty",        // Backorders at Branch 12
        "Bin",                 // Bin location at Branch 12
        "BulkBin",             // Bulk bin location
        "Returnable",          // Return indicator
        
        // === BRANCH 12 PRICING ===
        "Cost",                // Current cost at Branch 12
        "SellPrice1",          // Selling price at Branch 12
        "ListPrice",           // List price
        "InventoryCost",       // Total inventory value at Branch 12
        
        // === BRANCH 12 SALES ACTIVITY (12-MONTH HISTORY) ===
        "Current12MoSales",    // This is "Demands" in your report!
        "Current12MoDollars",  // Sales dollars last 12 months
        "Previous12MoSales",   // Prior period sales
        "Previous12MoDollars"  // Prior period dollars
    }),
    
    // ========================================================================
    // STEP 3: DATA CLEANING
    // ========================================================================
    
    CleanPartNumber = Table.TransformColumns(SelectColumns, {
        {"PartNumber", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text}
    }),
    
    CleanDescription = Table.TransformColumns(CleanPartNumber, {
        {"Description", each Text.Proper(Text.Trim(Text.From(_ ?? ""))), type text}
    }),
    
    CleanFranchise = Table.TransformColumns(CleanDescription, {
        {"Franchise", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text}
    }),
    
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
    // STEP 4: BRANCH 12 STOCK STATUS INTELLIGENCE
    // ========================================================================
    
    AddStockStatus = Table.AddColumn(CleanBusinessFields, "StockStatus", each
        let
            onHand = [QuantityOnHand] ?? 0,
            backOrder = [BackOrderQty] ?? 0
        in
            if onHand > 0 then "In Stock"
            else if backOrder > 0 then "Backordered"
            else "Out of Stock",
        type text),
    
    AddIsAvailable = Table.AddColumn(AddStockStatus, "IsAvailable", each
        ([QuantityOnHand] ?? 0) > 0, type logical),
    
    // ========================================================================
    // STEP 5: SALES ACTIVITY INTELLIGENCE (FOR R12 REPORT)
    // ========================================================================
    
    // "Demands" in your report = Current12MoSales
    AddDemands = Table.AddColumn(AddIsAvailable, "Demands", each
        [Current12MoSales] ?? 0, type number),
    
    AddHasRecentSales = Table.AddColumn(AddDemands, "HasRecentSales", each
        ([Current12MoSales] ?? 0) > 0, type logical),
    
    AddActivityStatus = Table.AddColumn(AddHasRecentSales, "ActivityStatus", each
        if [HasRecentSales] then "Active" else "No Recent Sales", type text),
    
    // ========================================================================
    // STEP 6: MARGIN INTELLIGENCE FOR R12 REPORT
    // ========================================================================
    
    // Calculate margin $ and % at part level (based on current pricing)
    AddMarginDollars = Table.AddColumn(AddActivityStatus, "MarginDollars", each
        let
            sellPrice = [SellPrice1] ?? 0,
            cost = [Cost] ?? 0
        in
            sellPrice - cost, type number),
    
    AddMarginPercent = Table.AddColumn(AddMarginDollars, "MarginPercent", each
        let
            sellPrice = [SellPrice1] ?? 0,
            margin = [MarginDollars] ?? 0
        in
            if sellPrice > 0 then margin / sellPrice else 0, type number),
    
    // ========================================================================
    // STEP 7: OPERATIONAL FLAGS
    // ========================================================================
    
    AddIsReturnable = Table.AddColumn(AddMarginPercent, "IsReturnable", each
        [Returnable] = "Y", type logical),
    
    AddIsHighValue = Table.AddColumn(AddIsReturnable, "IsHighValue", each
        ([InventoryCost] ?? 0) >= 500, type logical),
    
    AddIsFastMoving = Table.AddColumn(AddIsHighValue, "IsFastMoving", each
        ([Current12MoSales] ?? 0) >= 12, type logical),  // Sold at least monthly
    
    // ========================================================================
    // STEP 8: INVENTORY HEALTH INDICATORS
    // ========================================================================
    
    // Days of supply calculation (simplified)
    AddDaysOfSupply = Table.AddColumn(AddIsFastMoving, "DaysOfSupply", each
        let
            onHand = [QuantityOnHand] ?? 0,
            monthlySales = ([Current12MoSales] ?? 0) / 12,
            dailySales = monthlySales / 30
        in
            if dailySales > 0 then onHand / dailySales else null,
        type number),
    
    // Stock health indicator
    AddStockHealth = Table.AddColumn(AddDaysOfSupply, "StockHealth", each
        let
            daysSupply = [DaysOfSupply] ?? 0,
            hasBackorder = ([BackOrderQty] ?? 0) > 0
        in
            if [QuantityOnHand] = 0 and hasBackorder then "Critical - Backordered"
            else if [QuantityOnHand] = 0 then "Out of Stock"
            else if daysSupply < 30 then "Low Stock"
            else if daysSupply > 180 then "Overstock"
            else "Healthy",
        type text),
    
    // ========================================================================
    // STEP 9: DATA QUALITY & DEDUPLICATION
    // ========================================================================
    
    RemoveDuplicates = Table.Distinct(AddStockHealth, {"PartNumber"}),
    
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
    
    ReorderColumns = Table.ReorderColumns(AddSurrogateKey, {
        // === KEYS & IDENTIFICATION ===
        "PartNumberKey", "PartNumber", "Description", "Franchise",
        
        // === BUSINESS CLASSIFICATIONS ===
        "Source", "SLC", "DealerGroupCode", "CommodityCode", "VendorCode",
        
        // === BRANCH 12 INVENTORY ===
        "QuantityOnHand", "BinQty", "BulkBinQty", "PendingQty", "BackOrderQty",
        "Bin", "BulkBin", "StockStatus", "IsAvailable", "StockHealth", "DaysOfSupply",
        
        // === PRICING & MARGIN ===
        "Cost", "SellPrice1", "ListPrice", "InventoryCost",
        "MarginDollars", "MarginPercent",
        
        // === SALES ACTIVITY (R12 REPORT METRICS) ===
        "Demands", "Current12MoSales", "Current12MoDollars",
        "Previous12MoSales", "Previous12MoDollars",
        "HasRecentSales", "ActivityStatus", "IsFastMoving",
        
        // === OPERATIONAL FLAGS ===
        "Returnable", "IsReturnable", "IsHighValue"
    }),
    
    // ========================================================================
    // STEP 12: SPECIAL UNKNOWN RECORD
    // ========================================================================
    
    UnknownRecord = Table.FromRecords({
        [PartNumberKey = -1, PartNumber = "UNKNOWN", Description = "Unknown Part",
         Franchise = "UNKNOWN", Source = "UNKNOWN", SLC = "UNKNOWN",
         DealerGroupCode = "UNKNOWN", CommodityCode = "UNKNOWN", VendorCode = "UNKNOWN",
         QuantityOnHand = 0, BinQty = 0, BulkBinQty = 0, PendingQty = 0, BackOrderQty = 0,
         Bin = "", BulkBin = "", StockStatus = "Unknown", IsAvailable = false,
         StockHealth = "Unknown", DaysOfSupply = null, Cost = 0, SellPrice1 = 0,
         ListPrice = 0, InventoryCost = 0, MarginDollars = 0, MarginPercent = 0,
         Demands = 0, Current12MoSales = 0, Current12MoDollars = 0,
         Previous12MoSales = 0, Previous12MoDollars = 0, HasRecentSales = false,
         ActivityStatus = "Unknown", IsFastMoving = false, Returnable = "N",
         IsReturnable = false, IsHighValue = false]
    }),
    
    // ========================================================================
    // STEP 13: FINAL INTEGRATION & DATA TYPES
    // ========================================================================
    
    CombinedData = Table.Combine({UnknownRecord, ReorderColumns}),
    
    FinalDataTypes = Table.TransformColumnTypes(CombinedData, {
        // Keys and identification
        {"PartNumberKey", Int64.Type}, {"PartNumber", type text},
        {"Description", type text}, {"Franchise", type text},
        
        // Business classifications
        {"Source", type text}, {"SLC", type text}, {"DealerGroupCode", type text},
        {"CommodityCode", type text}, {"VendorCode", type text},
        
        // Inventory
        {"QuantityOnHand", type number}, {"BinQty", type number},
        {"BulkBinQty", type number}, {"PendingQty", type number},
        {"BackOrderQty", type number}, {"Bin", type text}, {"BulkBin", type text},
        {"StockStatus", type text}, {"IsAvailable", type logical},
        {"StockHealth", type text}, {"DaysOfSupply", type number},
        
        // Pricing and margin
        {"Cost", type number}, {"SellPrice1", type number}, {"ListPrice", type number},
        {"InventoryCost", type number}, {"MarginDollars", type number},
        {"MarginPercent", type number},
        
        // Sales activity
        {"Demands", type number}, {"Current12MoSales", type number},
        {"Current12MoDollars", type number}, {"Previous12MoSales", type number},
        {"Previous12MoDollars", type number}, {"HasRecentSales", type logical},
        {"ActivityStatus", type text}, {"IsFastMoving", type logical},
        
        // Operational flags
        {"Returnable", type text}, {"IsReturnable", type logical},
        {"IsHighValue", type logical}
    }),
    
    FinalSort = Table.Sort(FinalDataTypes, {{"PartNumberKey", Order.Ascending}})

in
    FinalSort

/*
============================================================================
✅ DIM_BRANCH12_PARTS - READY FOR R12 REPORT
============================================================================

🎯 KEY FEATURES FOR R12 REPORT:
• Branch 12-specific inventory levels (QuantityOnHand, BinQty, etc.)
• "Demands" column mapped to Current12MoSales (matches your report)
• Margin calculations (MarginDollars, MarginPercent) for report table
• Stock status and health indicators
• 12-month sales history for analysis
• Days of supply calculations for inventory planning

📊 REPORT TABLE MAPPING:
Your Report Column → This Dimension Column
- Part No → PartNumber
- Description → Description
- Qty → QuantityOnHand
- Demands → Demands (or Current12MoSales)
- Sales → Current12MoDollars
- Sales $ → (Calculate from transactions in fact table)
- Margin $ → MarginDollars (unit level, multiply by qty sold for total)
- Margin % → MarginPercent
- Bin Qty → BinQty
- Pending Qty → PendingQty

🔗 USAGE IN REPORT:
• Use this dimension for the parts table visual
• Join fact_Branch12_Transactions to this dimension on PartNumber
• Branch 12 inventory values are accurate and current
• Can calculate rolling metrics using dim_DateTable

⚡ PERFORMANCE:
• Filtered to Branch 12 only - lightweight dimension
• All intelligence pre-calculated for fast report rendering
• Refresh time: <30 seconds (small dataset, Branch 12 only)

============================================================================
*/