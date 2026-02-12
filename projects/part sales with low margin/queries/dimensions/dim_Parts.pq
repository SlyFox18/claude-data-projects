/*
============================================================================
DIM_PARTS - ENHANCED PARTS DIMENSION WITH PRACTICAL BUSINESS INTELLIGENCE
============================================================================

📋 TABLE OVERVIEW:
Purpose: Master parts dimension with practical inventory, pricing, and sales intelligence
Grain: One row per unique part number with essential business data and operational insights
Refresh Strategy: Full refresh (parts data changes infrequently)
Target Performance: <2 minutes (enhanced but performance-focused)
Source Dependencies: jdis_Part_Information (Raw lakehouse table)

🎯 BUSINESS USE CASES:
• Parts Lookup: Primary parts identification for work orders and transactions
• Inventory Awareness: Stock status and availability for service planning
• Pricing Analysis: Cost and pricing information for margin analysis
• Sales Intelligence: Active vs obsolete parts identification
• Business Filtering: Source, SLC, DealerGroup, Commodity, Vendor classification
• Operational Decisions: Returnable parts identification and processing

📊 KEY ENHANCEMENTS ADDED:
• Inventory Intelligence: Stock status (In Stock/Out of Stock/Backordered)
• Pricing Information: Inventory cost, sell price, list price for analysis
• Sales Activity: Recent sales indicator for obsolescence management
• Operational Flags: Returnable parts boolean for easier filtering
• Business Filters: Source, SLC, DealerGroup, Commodity, Vendor (as requested)

🔗 DIMENSION RELATIONSHIPS:
• Fact_WorkOrderParts.PartNumberKey → dim_Parts.PartNumberKey
• Fact_Inventory.PartNumberKey → dim_Parts.PartNumberKey  
• Fact_PartTransactions.PartNumberKey → dim_Parts.PartNumberKey

📈 DASHBOARD APPLICATIONS:
• Parts Availability Dashboard: Stock status and backorder monitoring
• Pricing Analysis: Cost and margin review by vendor and commodity
• Inventory Management: Active vs obsolete parts identification
• Service Planning: Parts availability for work order scheduling
• Business Intelligence: Filtering by all business classification codes

⚡ PERFORMANCE OPTIMIZATIONS:
• Simple business logic only - no complex categorization
• Strategic column selection for essential business value
• Efficient data cleaning with proper null handling
• Raw pricing data without complex calculations
- Minimal conditional logic for maximum performance

🔧 MAINTENANCE NOTES:
• Monitor stock status accuracy for service operations
• Review pricing data completeness for financial analysis
• Validate business filter codes when new classifications added
• Maintain returnable flag accuracy for parts processing

============================================================================
📈 BUSINESS VALUE & DASHBOARD RECOMMENDATIONS
============================================================================

📦 INVENTORY INTELLIGENCE:
• Service Planning: Real-time parts availability for work order scheduling
• Stock Monitoring: Quick identification of out-of-stock and backordered parts
• Procurement: Active parts vs obsolete parts for purchasing decisions

💰 PRICING INTELLIGENCE:
• Cost Analysis: Inventory cost tracking and vendor cost comparison
• Pricing Strategy: Sell price vs list price analysis for margin optimization
• Financial Planning: Parts value assessment and inventory valuation

📊 OPERATIONAL INTELLIGENCE:
• Business Filtering: Advanced filtering by Source, SLC, Vendor, Commodity codes
• Parts Processing: Returnable parts identification for customer service
• Sales Analysis: Active parts identification for inventory optimization

============================================================================
*/

let
    // ========================================================================
    // STEP 1: ENHANCED DATA FOUNDATION WITH BUSINESS INTELLIGENCE
    // ========================================================================
    /*
    PURPOSE: Select essential columns plus practical business intelligence fields
    BUSINESS LOGIC: Core parts data + inventory + pricing + sales + business filters
    PERFORMANCE: Strategic selection of high-value fields
    */
    
    // Source: Parts information from lakehouse
    Source = jdis_Part_Information,
    
    // Enhanced column selection - practical business intelligence
    EnhancedColumns = Table.SelectColumns(Source, {
        // === CORE PARTS IDENTIFICATION ===
        "PartNumber",           // Primary part identifier
        "Description",          // Part description  
        "Franchise",            // Manufacturer/brand
        
        // === BUSINESS FILTER COLUMNS (REQUESTED) ===
        "Source",               // Source classification
        "SLC",                  // SLC classification
        "DealerGroupCode",      // Dealer group identifier
        "CommodityCode",        // Commodity classification
        "VendorCode",           // Vendor identifier
        
        // === INVENTORY INTELLIGENCE (NEW - HIGH VALUE) ===
        "QuantityOnHand",       // Current stock level
        "BackOrderQty",         // Backorder quantity
        "Returnable",           // Returnable indicator (Y/N)
        
        // === PRICING INFORMATION (NEW - HIGH VALUE) ===
        "InventoryCost",        // Inventory cost value
        "SellPrice1",           // Primary selling price
        "ListPrice",            // Manufacturer list price
        
        // === SALES ACTIVITY (NEW - PRACTICAL VALUE) ===
        "Current12MoSales"      // 12-month sales quantity for activity indicator
    }),
    
    // ========================================================================
    // STEP 2: ENHANCED DATA CLEANING WITH SAFE TYPE CONVERSION
    // ========================================================================
    /*
    PURPOSE: Comprehensive cleaning with proper null and type handling
    PERFORMANCE: Simple text operations with error prevention
    ERROR PREVENTION: Safe conversion for all data types
    */
    
    // Clean part number (maintained from original approach)
    CleanPartNumber = Table.TransformColumns(EnhancedColumns, {
        {"PartNumber", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text}
    }),
    
    // Clean description with proper formatting
    CleanDescription = Table.TransformColumns(CleanPartNumber, {
        {"Description", each Text.Proper(Text.Trim(Text.From(_ ?? ""))), type text}
    }),
    
    // Clean franchise/manufacturer
    CleanFranchise = Table.TransformColumns(CleanDescription, {
        {"Franchise", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text}
    }),
    
    // Clean business filter fields with safe text conversion
    CleanBusinessFields = Table.TransformColumns(CleanFranchise, {
        {"Source", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"SLC", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"DealerGroupCode", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"CommodityCode", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"VendorCode", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text}
    }),
    
    // Clean returnable field for boolean conversion
    CleanReturnable = Table.TransformColumns(CleanBusinessFields, {
        {"Returnable", each Text.Upper(Text.Trim(Text.From(_ ?? "N"))), type text}
    }),
    
    // ========================================================================
    // STEP 3: PRACTICAL INVENTORY INTELLIGENCE (SIMPLE LOGIC)
    // ========================================================================
    /*
    PURPOSE: Add practical inventory status for service operations
    BUSINESS LOGIC: Simple, reliable stock status assessment
    PERFORMANCE: Minimal conditional logic for fast processing
    */
    
    // Simple inventory status assessment
    AddStockStatus = Table.AddColumn(CleanReturnable, "StockStatus", each
        let
            onHand = [QuantityOnHand] ?? 0,
            backOrder = [BackOrderQty] ?? 0
        in
            if onHand > 0 then "In Stock"              // Available now
            else if backOrder > 0 then "Backordered"   // Coming soon
            else "Out of Stock",                       // Not available
        type text),
    
    // Service availability flag for operations
    AddIsAvailable = Table.AddColumn(AddStockStatus, "IsAvailable", each
        ([QuantityOnHand] ?? 0) > 0, type logical),
    
    // ========================================================================
    // STEP 4: SALES ACTIVITY INTELLIGENCE (SIMPLE FLAG)
    // ========================================================================
    /*
    PURPOSE: Identify active vs obsolete parts for inventory management
    BUSINESS LOGIC: Simple sales activity indicator
    PERFORMANCE: Single boolean calculation
    */
    
    // Sales activity indicator for obsolescence management
    AddHasRecentSales = Table.AddColumn(AddIsAvailable, "HasRecentSales", each
        ([Current12MoSales] ?? 0) > 0, type logical),
    
    // Simple activity status for business analysis
    AddActivityStatus = Table.AddColumn(AddHasRecentSales, "ActivityStatus", each
        if [HasRecentSales] then "Active" else "No Recent Sales", type text),
    
    // ========================================================================
    // STEP 5: OPERATIONAL FLAGS (SIMPLE CONVERSIONS)
    // ========================================================================
    /*
    PURPOSE: Convert operational indicators to business-friendly formats
    BUSINESS LOGIC: Simple boolean conversions for easier filtering
    PERFORMANCE: Minimal string comparison operations
    */
    
    // Convert returnable Y/N to boolean for easier filtering
    AddIsReturnable = Table.AddColumn(AddActivityStatus, "IsReturnable", each
        [Returnable] = "Y", type logical),
    
    // High-value parts flag (simple threshold)
    AddIsHighValue = Table.AddColumn(AddIsReturnable, "IsHighValue", each
        ([InventoryCost] ?? 0) >= 500, type logical),
    
    // ========================================================================
    // STEP 6: DATA QUALITY & DEDUPLICATION (MAINTAINED FROM ORIGINAL)
    // ========================================================================
    /*
    PURPOSE: Ensure dimension integrity with unique part numbers
    APPROACH: Maintained original logic for consistency and performance
    */
    
    // Remove duplicates by part number (original approach maintained)
    RemoveDuplicates = Table.Distinct(AddIsHighValue, {"PartNumber"}),
    
    // Remove blank/invalid records (original approach maintained)
    RemoveBlankRows = Table.SelectRows(RemoveDuplicates, each 
        not List.IsEmpty(List.RemoveMatchingItems(Record.FieldValues(_), {"", null})) and
        ([PartNumber] ?? "") <> ""),
    
    // Sort for consistent processing (original approach maintained)
    SortByPartNumber = Table.Sort(RemoveBlankRows, {{"PartNumber", Order.Ascending}}),
    
    // ========================================================================
    // STEP 7: SURROGATE KEY & SPECIAL RECORDS (ORIGINAL PATTERN)
    // ========================================================================
    /*
    PURPOSE: Create efficient primary key following dimensional modeling best practices
    BUSINESS LOGIC: Maintained approach from successful original dimension
    */
    
    // Add surrogate key (original approach maintained)
    AddSurrogateKey = Table.AddIndexColumn(SortByPartNumber, "PartNumberKey", 1, 1, Int64.Type),
    
    // Reorder columns for logical business presentation
    ReorderColumns = Table.ReorderColumns(AddSurrogateKey, {
        // === PRIMARY KEYS & IDENTIFICATION ===
        "PartNumberKey",        // Surrogate key for fact joins
        "PartNumber",           // Business key for lookups
        "Description",          // Part description
        "Franchise",            // Manufacturer/brand
        
        // === BUSINESS FILTER COLUMNS ===
        "Source",               // Source classification
        "SLC",                  // SLC classification
        "DealerGroupCode",      // Dealer group
        "CommodityCode",        // Commodity classification
        "VendorCode",           // Vendor identifier
        
        // === INVENTORY INTELLIGENCE ===
        "QuantityOnHand",       // Raw stock quantity
        "BackOrderQty",         // Raw backorder quantity
        "StockStatus",          // Calculated status
        "IsAvailable",          // Availability flag
        
        // === PRICING INFORMATION ===
        "InventoryCost",        // Cost basis
        "SellPrice1",           // Selling price
        "ListPrice",            // Manufacturer price
        
        // === SALES & ACTIVITY ===
        "Current12MoSales",     // Raw sales data
        "HasRecentSales",       // Activity flag
        "ActivityStatus",       // Activity description
        
        // === OPERATIONAL FLAGS ===
        "Returnable",           // Original Y/N field
        "IsReturnable",         // Boolean conversion
        "IsHighValue"           // Value-based flag
    }),
    
    // Create special "Unknown Parts" record (dimensional modeling best practice)
    UnknownPartsRecord = Table.FromRecords({
        [PartNumberKey = -1, PartNumber = "UNKNOWN", Description = "Unknown Part", 
         Franchise = "UNKNOWN", Source = "UNKNOWN", SLC = "UNKNOWN", 
         DealerGroupCode = "UNKNOWN", CommodityCode = "UNKNOWN", VendorCode = "UNKNOWN",
         QuantityOnHand = 0, BackOrderQty = 0, StockStatus = "Unknown", IsAvailable = false,
         InventoryCost = 0, SellPrice1 = 0, ListPrice = 0, Current12MoSales = 0,
         HasRecentSales = false, ActivityStatus = "Unknown", Returnable = "N", 
         IsReturnable = false, IsHighValue = false]
    }),
    
    // Set data types for special record
    UnknownPartsTyped = Table.TransformColumnTypes(UnknownPartsRecord, {
        {"PartNumberKey", Int64.Type}, {"PartNumber", type text}, {"Description", type text},
        {"Franchise", type text}, {"Source", type text}, {"SLC", type text},
        {"DealerGroupCode", type text}, {"CommodityCode", type text}, {"VendorCode", type text},
        {"QuantityOnHand", type number}, {"BackOrderQty", type number}, {"StockStatus", type text}, 
        {"IsAvailable", type logical}, {"InventoryCost", type number}, {"SellPrice1", type number}, 
        {"ListPrice", type number}, {"Current12MoSales", type number}, {"HasRecentSales", type logical}, 
        {"ActivityStatus", type text}, {"Returnable", type text}, {"IsReturnable", type logical}, 
        {"IsHighValue", type logical}
    }),
    
    // ========================================================================
    // STEP 8: FINAL INTEGRATION & OPTIMIZATION
    // ========================================================================
    /*
    PURPOSE: Complete enhanced dimension with practical business intelligence
    RESULT: High-value parts dimension optimized for business operations
    */
    
    // Combine special records with regular parts (original pattern)
    CombinedParts = Table.Combine({UnknownPartsTyped, ReorderColumns}),
    
    // Set final data types for optimal performance
    FinalDataTypes = Table.TransformColumnTypes(CombinedParts, {
        // Keys and identification
        {"PartNumberKey", Int64.Type}, {"PartNumber", type text}, {"Description", type text},
        {"Franchise", type text},
        
        // Business filters
        {"Source", type text}, {"SLC", type text}, {"DealerGroupCode", type text},
        {"CommodityCode", type text}, {"VendorCode", type text},
        
        // Inventory data
        {"QuantityOnHand", type number}, {"BackOrderQty", type number}, 
        {"StockStatus", type text}, {"IsAvailable", type logical},
        
        // Pricing data
        {"InventoryCost", type number}, {"SellPrice1", type number}, {"ListPrice", type number},
        
        // Sales and activity
        {"Current12MoSales", type number}, {"HasRecentSales", type logical}, 
        {"ActivityStatus", type text},
        
        // Operational flags
        {"Returnable", type text}, {"IsReturnable", type logical}, {"IsHighValue", type logical}
    }),
    
    // Final sort for consistent output (original pattern)
    FinalSort = Table.Sort(FinalDataTypes, {{"PartNumberKey", Order.Ascending}}),

    // ========================================================================
    // CRITICAL FIX: Final deduplication to prevent relationship errors
    // ========================================================================
    /*
    PURPOSE: Ensure absolutely no duplicate PartNumber values exist
    REASON: PartNumber is on the "one" side of relationships - must be unique
    APPROACH: Keep first occurrence of each PartNumber (preserves lowest PartNumberKey)
    */

    FinalDeduplication = Table.Distinct(FinalSort, {"PartNumber"})

in
    FinalDeduplication