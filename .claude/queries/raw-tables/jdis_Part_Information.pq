/*
============================================================================
Query: jdis_Part_Information (Raw)
Dataflow: df_jdis_Part_Information_Raw
Location: LH_Master_Data → Dataflows → 01 - Raw Sources
============================================================================

📋 METADATA:
Source: SQL Anywhere Database (ODBC connection: EquipRDB64)
Purpose: Master parts price list - most frequently changing table in source system
Created: [Unknown - pre-dates current documentation]
Last Modified: 12/01/2025
Output: Lakehouse table "jdis_Part_Information"

⏱️ REFRESH CHARACTERISTICS:
Refresh Schedule: 3 times daily (7:30 AM, 9:30 AM, 4:00 PM)
Average Refresh Time: ~8 minutes
Refresh Strategy: Full refresh (no reliable incremental field)
Row Count: 1081494 rows (as of 1/14/2026)

🎯 BUSINESS USE CASES:
• Dimension Foundation: Primary data source for dim_Parts dimension table
• Inventory Management: Complete stock levels, reorder points, and availability tracking
• Pricing Analysis: Cost vs sell price analysis and margin tracking
• Parts Performance: Sales activity and turnover analysis
• Supply Chain: On-order, pending, and back-order inventory tracking
• Vendor Analysis: Supplier and source analysis
• Location Management: Bin and bulk bin inventory tracking
• Supersession Management: Part replacement and supersession tracking

📊 COMPLETE DATA STRUCTURE (30 COLUMNS):

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
• OnOrder: On-order quantity
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
• SellPrice1: Primary selling price (pi_Sell_Price_1_Master_File)
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

🔧 DESIGN PRINCIPLES:

**Full Refresh Strategy:**
• Parts master changes frequently (inventory, pricing, costs)
• No reliable incremental date field (no ModifiedDate or LastUpdated)
• Full refresh ensures complete data accuracy
• 8-minute refresh time is acceptable for data accuracy requirements

**Why This Table Is Critical:**
• Most frequently changing table in source system
• No timestamp field for tracking changes (reason for snapshot tables in 05 - Snapshots)
• Contains pricing, cost, and part master data
• Used as source for multiple dimensions across all reports

**Future Optimization Opportunity:**
• If source system adds ModifiedDate field, can implement incremental refresh
• Current 8-minute refresh time could be reduced significantly
• Prepared to implement incremental refresh when field becomes available

⚠️ IMPORTANT NOTES:
• This is the reason daily/weekly snapshots exist (05 - Snapshots folder)
• Changes constantly throughout the day - no change tracking in source
• Critical for inventory accuracy - must refresh multiple times daily
• Used in: dim_Parts, dim_Parts_LowMargin, and other part-based dimensions

Dependencies:
• None (direct source system table)

Used By:
• df_Dim_Parts
• df_Dim_Parts_LowMargin
• df_Snapshot_Parts_Daily
• df_Snapshot_Parts_Weekly
• Other part-related dimensions

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
✅ PRODUCTION STATUS: COMPLETE & OPERATIONAL
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

⚡ PERFORMANCE NOTES:
• 8-minute refresh time with 1M+ rows is reasonable for full refresh
• Full refresh required due to lack of incremental field in source
• Alternative considered: Incremental load would risk missing inventory/price changes
• Trade-off accepted: Accuracy prioritized over refresh speed

🔄 OPTIMIZATION OPPORTUNITIES:
• Request ModifiedDate field in source system (SQL Anywhere database)
• When available, implement incremental refresh with parameters:
  - RangeStart/RangeEnd date parameters
  - Filter: WHERE pi_Modified_Date >= RangeStart AND pi_Modified_Date < RangeEnd
  - Expected time reduction: 8 min → <1 min for typical incremental loads

📝 RECENT UPDATES (12/01/2025):
• Added BulkBinQty: Bulk bin quantity tracking for inventory management
• Added PendingQty: Pending order quantity for supply chain visibility
• Added SuperTo/SuperFrom: Part supersession tracking

🚀 PRODUCTION CHARACTERISTICS:
• Refresh Schedule: 7:30 AM, 9:30 AM, 4:00 PM daily
• Data Accuracy: Full refresh ensures no missed inventory or pricing updates
• Business Alignment: Column set matches confirmed business requirements
• Dimensional Ready: Complete parts master data for dim_Parts dimension table

Current approach prioritizes data completeness and accuracy over refresh speed,
ensuring all business-critical parts analytics requirements are met.

============================================================================
*/
