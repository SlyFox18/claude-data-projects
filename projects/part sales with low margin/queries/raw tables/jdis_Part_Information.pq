/*
============================================================================
RAW_JDIS_PART_INFORMATION - PARTS MASTER DATA EXTRACTION
============================================================================

📋 TABLE OVERVIEW:
Purpose: Extract complete parts master data for inventory and parts analytics
Grain: One row per part per branch (parts master record)
Refresh Strategy: Full refresh (parts master data changes frequently, no reliable incremental field)
Performance: Target refresh time with complete business-required column set
Source Dependencies: jdis_Part_Information table (parts master system)

🎯 BUSINESS USE CASES:
• Dimension Foundation: Primary data source for dim_Parts dimension table
• Inventory Management: Complete stock levels, reorder points, and availability tracking
• Pricing Analysis: Cost vs sell price analysis and margin tracking
• Parts Performance: Sales activity and turnover analysis
• Supply Chain: On-order, pending, and back-order inventory tracking
• Vendor Analysis: Supplier and source analysis
• Location Management: Bin and bulk bin inventory tracking
• Supersession Management: Part replacement and supersession tracking

📊 COMPLETE DATA STRUCTURE (30 COLUMNS - BUSINESS REQUIRED):

**Core Parts Identification:**
• Branch: Parts branch location
• PartNumber: Part number identifier (pi_Part_No)
• Description: Part description
• Franchise: Manufacturer/franchise code
• Source: Part source classification
• SLC: Service Level Code classification
• CommodityCode: Commodity classification
• DealerGroupCode: Dealer group classification

**Inventory Management:**
• QuantityOnHand: Current inventory level (pi_On_Hand_Qty)
• BinQty: Bin quantity
• BulkBinQty: Bulk bin quantity (pi_Bulk_Bin_Qty)
• PendingQty: Pending order quantity (pi_Pending_Qty)
• BackOrderQty: Back-ordered quantity
• BulkBin: Bulk bin location
• Bin: Primary bin location
• PackageQty: Package quantity
• Returnable: Return indicator flag

**Part Supersession:**
• SuperTo: Supersession to part number (replacement part)
• SuperFrom: Supersession from part number (original part)

**Financial Data:**
• InventoryCost: Current inventory cost
• Cost: Standard cost (pi_Cost)
• SellPrice1: Primary selling price
• ListPrice: List price
• Current12MoSales: Recent sales volume
• Current12MoDollars: Recent sales revenue
• Previous12MoSales: Previous period sales volume
• Previous12MoDollars: Previous period sales revenue

**Business Context:**
• VendorCode: Supplier identifier

**Timeline Intelligence:**
• DateCreated: Part creation date
• DateLastRequested: Last request date
• StocktakeDate: Last stocktake date

🔧 DESIGN PRINCIPLES APPLIED:

**Full Refresh Strategy:**
• Parts master changes frequently (inventory, pricing, costs)
• No reliable incremental date field for comprehensive updates
• Full refresh ensures complete data accuracy
• Complete business-required column set

**Future Incremental Refresh Preparation:**
• Ready to implement incremental refresh when ModifiedDate field becomes available
• Current approach ensures no data is missed during transition period

============================================================================
*/

let
    // ========================================================================
    // PERFORMANCE-FOCUSED SQL QUERY - COMPLETE BUSINESS REQUIREMENTS
    // ========================================================================
    /*
    STRATEGY: Complete parts master data as required by business analytics
    APPROACH: Full refresh with all business-essential fields
    FUTURE: Ready for incremental refresh implementation when ModifiedDate available
    */
    
    SQL = 
    "SELECT #(lf)
        -- ===== CORE PARTS IDENTIFICATION ===== #(lf)
        pi_Branch AS Branch, #(lf)
        pi_Part_No AS PartNumber, #(lf)
        pi_Description AS Description, #(lf)
        pi_Franchise AS Franchise, #(lf)
        pi_Source AS Source, #(lf)
        pi_SLC AS SLC, #(lf)
        pi_Commodity_Code AS CommodityCode, #(lf)
        pi_Dealer_Group_Code AS DealerGroupCode, #(lf)
        
        -- ===== INVENTORY MANAGEMENT ===== #(lf)
        pi_On_Hand_Qty AS QuantityOnHand, #(lf)
        pi_Bin_Qty AS BinQty, #(lf)
        pi_Bulk_Bin_Qty AS BulkBinQty, #(lf)
        pi_Pending_Qty AS PendingQty, #(lf)
        pi_Back_Ord_Qty AS BackOrderQty, #(lf)
        pi_Bulk_Bin AS BulkBin, #(lf)
        pi_Bin AS Bin, #(lf)
        pi_Package_Qty AS PackageQty, #(lf)
        pi_Return_Indicator AS Returnable, #(lf)
        pi_On_Order AS OnOrder, #(lf)
        
        -- ===== PART SUPERSESSION ===== #(lf)
        pi_Super_To AS SuperTo, #(lf)
        pi_Super_From AS SuperFrom, #(lf)
        
        -- ===== FINANCIAL DATA ===== #(lf)
        pi_Inventory_Cost AS InventoryCost, #(lf)
        pi_Cost AS Cost, #(lf)
        pi_Sell_Price_1_Master_File AS SellPrice1, #(lf)
        pi_List_Price_Master_File AS ListPrice, #(lf)
        pi_current_12_mo_sales AS Current12MoSales, #(lf)
        pi_current_12_dollars AS Current12MoDollars, #(lf)
        pi_previous_12_mo_sales AS Previous12MoSales, #(lf)
        pi_previous_12_dollars AS Previous12MoDollars, #(lf)
        
        -- ===== BUSINESS CONTEXT ===== #(lf)
        pi_Vendor_Code AS VendorCode, #(lf)
        
        -- ===== TIMELINE INTELLIGENCE ===== #(lf)
        pi_Date_Created AS DateCreated, #(lf)
        pi_Date_Last_Request AS DateLastRequested, #(lf)
        pi_Stocktake_Date AS StocktakeDate #(lf)
        
    FROM jdis_Part_Information #(lf)
    ORDER BY pi_Branch, pi_Part_No",
    
    // ========================================================================
    // EXECUTE QUERY - FULL REFRESH FOR COMPLETE ACCURACY
    // ========================================================================
    
    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise 
        error "Failed to connect to JDIS_PART_INFORMATION. Verify database connection and table availability."

in
    Source

/*
============================================================================
✅ RAW_JDIS_PART_INFORMATION - COMPLETE BUSINESS-REQUIRED DATA
============================================================================

🎯 IMPLEMENTATION SUMMARY:
• Complete Column Set: All 30 business-required columns included
• Full Refresh Strategy: Ensures complete data accuracy for frequently changing parts data
• Business Requirements Met: All essential parts master data captured
• Future-Ready: Prepared for incremental refresh when ModifiedDate field available

🔍 DATA COMPLETENESS:
• Core Identification: Complete part identification and classification data
• Inventory Intelligence: Full inventory management including bin locations, pending qty, and bulk bin qty
• Part Supersession: Complete supersession tracking for part replacements
• Financial Analysis: Complete cost, pricing, and sales activity data
• Timeline Context: Creation, request, and stocktake date tracking

📝 RECENT UPDATES:
• Added BulkBinQty: Bulk bin quantity tracking for inventory management
• Added PendingQty: Pending order quantity for supply chain visibility
• Added SuperTo: Supersession to part number (replacement part tracking)
• Added SuperFrom: Supersession from part number (original part tracking)

🚀 PRODUCTION CHARACTERISTICS:
• Data Accuracy: Full refresh ensures no missed inventory or pricing updates
• Business Alignment: Column set matches confirmed business requirements
• Dimensional Ready: Complete parts master data for dim_Parts dimension table
• Analytics Foundation: All required fields for inventory and parts performance analysis

🔄 INCREMENTAL REFRESH PREPARATION:
When ModifiedDate field becomes available in source system:
• Add incremental refresh parameters (RangeStart/RangeEnd)
• Implement ModifiedDate filtering in WHERE clause
• Maintain same complete column set
• Expected performance improvement with incremental approach

Current approach prioritizes data completeness and accuracy over refresh speed,
ensuring all business-critical parts analytics requirements are met.

============================================================================
*/