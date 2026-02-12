/*
============================================================================
RAW_INMASTER - PARTS MASTER SUPPLEMENTAL DATA EXTRACTION
============================================================================

📋 TABLE OVERVIEW:
Purpose: Extract supplemental parts master data focusing on pricing and custom fields
Grain: One row per part per branch
Refresh Strategy: Full refresh (no reliable incremental date field)
Source Dependencies: InMaster table (parts master system - supplemental data)

🎯 BUSINESS USE CASES:
• Low Margin Identification: user_field_3 marks parts as "Low" margin by parts managers
• Stock Ordering: STK_ORDER_PRICE provides original/base pricing for margin analysis
• Inventory Valuation: Cost and pricing data for financial analysis
• Pricing Strategy: List price and sell price analysis
• Parts Classification: Product groups, sales classes, and categories

🔑 CRITICAL BUSINESS INSIGHT:
**user_field_3 = "Low"**: Parts managers manually flag parts with margin issues
This is THE KEY FIELD for identifying low-margin parts in the report!

📊 RECOMMENDED COLUMNS FOR LOW MARGIN ANALYSIS (20 COLUMNS):

**Core Identification:**
• Branch: Parts branch location
• PartNumber: Part number identifier (PART_NO)
• Franchise: Manufacturer/franchise code
• PartDescription: Part description (PART_DESC)

**Low Margin Flag (CRITICAL):**
• LowMarginFlag: Manual low margin indicator (user_field_3) ⭐⭐⭐

**Pricing & Cost Data:**
• Cost (via LIST_PRICE - actual cost field name TBD)
• ListPrice: Manufacturer's list price (LIST_PRICE)
• SellPrice1: Primary selling price (SELL_PRICE1)
• StockOrderPrice: Original/base order price (STK_ORDER_PRICE) ⭐
• ListPriceManuf: Manufacturer list price reference

**Inventory Levels:**
• OnHandQty: Current stock on hand (ON_HAND_QTY)
• BackOrderQty: Quantity on backorder (BACK_ORD_QTY)
• PendingQty: Pending quantity (may need from jdis table)

**Classification & Context:**
• ProductGroup: Product classification (PROD_GROUP)
• SalesClass: Sales classification (SALES_CLASS)
• Category: Category classification (CATEGORY)
• ManufacturerCode: Manufacturer code (MANUF_CODE)

**Additional Custom Fields (for future flexibility):**
• UserField1: Custom field 1 (user_field_1)
• UserField2: Custom field 2 (user_field_2)

**Timeline Intelligence:**
• LastUpdatedDatetime: Last update timestamp (Last_Upd_Datetime)

🚨 DATA SCOPE CONSIDERATIONS:

**Historical Data Range:**
Based on business requirements for low margin analysis:
• RECOMMENDED: All active parts (current inventory + parts sold in last 2 years)
• RATIONALE: Need to match InTrans 2-year transaction window
• ALTERNATIVE: Could filter to only parts with recent activity

**Filtering Strategy:**
OPTION 1 - Full Master (RECOMMENDED for initial load):
• Load ALL parts from InMaster
• Let fact table relationships filter to relevant parts
• Ensures no missing data when analyzing historical transactions

OPTION 2 - Filtered (Performance optimization):
• Only parts with OnHandQty > 0 OR recent transaction activity
• Reduces row count but requires careful validation
• Risk: May miss parts that were recently sold out

**RECOMMENDATION: Start with Option 1 (Full Master), optimize later if needed**

🔧 DESIGN PRINCIPLES:

**Full Refresh Strategy:**
• InMaster changes infrequently for most fields
• user_field_3 (Low Margin Flag) can change as managers adjust
• No reliable ModifiedDate field for incremental refresh
• Full refresh ensures complete accuracy

**Column Selection:**
• Focus on fields needed for low margin analysis
• Exclude unnecessary operational fields
• Normalize column names to match other raw tables
• Preserve all pricing/cost fields for margin calculations

============================================================================
*/

let
    // ========================================================================
    // PERFORMANCE-FOCUSED SQL QUERY - LOW MARGIN ANALYSIS ESSENTIALS
    // ========================================================================
    /*
    STRATEGY: Extract all parts with focus on pricing and low margin indicators
    APPROACH: Full master refresh with essential columns for margin analysis
    SCOPE: All parts (no date filter - this is master data)
    */

    SQL =
    "SELECT #(lf)
        -- ===== CORE PARTS IDENTIFICATION ===== #(lf)
        BRANCH AS Branch, #(lf)
        PART_NO AS PartNumber, #(lf)
        PART_DESC AS PartDescription, #(lf)
        FRANCHISE AS Franchise, #(lf)

        -- ===== CLASSIFICATION ===== #(lf)
        PROD_GROUP AS ProductGroup, #(lf)
        SALES_CLASS AS SalesClass, #(lf)
        CATEGORY AS Category, #(lf)
        MANUF_CODE AS ManufacturerCode, #(lf)

        -- ===== PRICING & COST DATA ===== #(lf)
        LIST_PRICE AS ListPrice, #(lf)
        SELL_PRICE1 AS SellPrice1, #(lf)
        STK_ORDER_PRICE AS StockOrderPrice, #(lf)
        -- Note: Actual cost field may be in jdis_Part_Information #(lf)

        -- ===== INVENTORY LEVELS ===== #(lf)
        ON_HAND_QTY AS OnHandQty, #(lf)
        BACK_ORD_QTY AS BackOrderQty, #(lf)

        -- ===== CRITICAL: LOW MARGIN INDICATOR ===== #(lf)
        user_field_3 AS LowMarginFlag, #(lf)

        -- ===== ADDITIONAL CUSTOM FIELDS ===== #(lf)
        user_field_1 AS UserField1, #(lf)
        user_field_2 AS UserField2, #(lf)

        -- ===== TIMELINE INTELLIGENCE ===== #(lf)
        Last_Upd_Datetime AS LastUpdatedDatetime, #(lf)
        CREATION_DATE AS CreationDate, #(lf)
        LAST_DEM_DATE AS LastDemandDate #(lf)

    FROM InMaster #(lf)
    ORDER BY Branch, PART_NO",

    // ========================================================================
    // EXECUTE QUERY - FULL MASTER REFRESH
    // ========================================================================

    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise
        error "Failed to connect to INMASTER table. Verify database connection and table availability.",

    // ========================================================================
    // DATA TYPE OPTIMIZATION
    // ========================================================================
    /*
    Ensure proper data types for downstream processing
    Critical for joins and calculations in fact tables
    */

    TypedTable = Table.TransformColumnTypes(Source, {
        {"Branch", type text},
        {"PartNumber", type text},
        {"PartDescription", type text},
        {"Franchise", type text},
        {"ProductGroup", type text},
        {"SalesClass", type text},
        {"Category", type text},
        {"ManufacturerCode", type text},
        {"ListPrice", type number},
        {"SellPrice1", type number},
        {"StockOrderPrice", type number},
        {"OnHandQty", type number},
        {"BackOrderQty", type number},
        {"LowMarginFlag", type text},  // ⭐ KEY FIELD
        {"UserField1", type text},
        {"UserField2", type text},
        {"LastUpdatedDatetime", type datetime},
        {"CreationDate", type datetime},
        {"LastDemandDate", type datetime}
    })

in
    TypedTable

/*
============================================================================
✅ RAW_INMASTER - SUPPLEMENTAL PARTS MASTER DATA
============================================================================

🎯 IMPLEMENTATION SUMMARY:
• Essential Columns: 20 columns focused on low margin analysis
• Full Master Strategy: All parts included for comprehensive analysis
• Business Requirements Met: user_field_3 (Low Margin Flag) captured
• Future-Ready: Can add filters or incremental refresh if needed

🔍 KEY DATA ELEMENTS:

**Low Margin Identification:**
• LowMarginFlag (user_field_3): Parts managers mark parts as "Low"
  - Values: "Low" = flagged as low margin part
  - This is manually maintained by parts managers
  - Critical for filtering low margin parts in report

**Pricing Structure:**
• StockOrderPrice: Original base price for the part ⭐
• ListPrice: Current list price
• SellPrice1: Current selling price
• Used to calculate margin discrepancies and target margins

**Inventory Context:**
• OnHandQty: Current stock levels
• BackOrderQty: Parts on backorder
• Helps identify financial impact of low margin parts in inventory

📊 DATA VALIDATION CHECKPOINTS:

**Row Count Validation:**
Expected: ~5,000-50,000 parts (all parts across all branches)
Compare to: SELECT COUNT(*) FROM InMaster

**LowMarginFlag Distribution:**
Check distribution: How many parts marked as "Low"?
SELECT LowMarginFlag, COUNT(*) FROM InMaster GROUP BY LowMarginFlag

**Pricing Completeness:**
Verify: StockOrderPrice and ListPrice have values
SELECT COUNT(*) FROM InMaster WHERE StockOrderPrice IS NULL OR StockOrderPrice = 0

🔄 REFRESH STRATEGY:

**Current Approach: Full Refresh**
• Frequency: Daily (align with other raw tables)
• Duration: Expected <5 minutes (master table, not huge)
• Dependencies: None (standalone master table)

**Rationale:**
• InMaster is relatively small compared to transactions
• Low margin flags can change as managers adjust
• Full refresh ensures complete accuracy
• No reliable incremental date field

🚀 PRODUCTION CHARACTERISTICS:

**Join Keys:**
• Branch + PartNumber → Joins to jdis_Part_Information
• Branch + PartNumber → Joins to InTrans transactions
• Composite key ensures branch-specific part data

**Usage in Fact Tables:**
This raw table feeds:
• dim_Parts: LEFT JOIN to add LowMarginFlag, StockOrderPrice
• Fact_Part_Sales_Txns: Lookup for original margin calculations

**Performance:**
• Full master refresh: <5 min expected
• Row count: 5K-50K rows (manageable size)
• No complex transformations (straight extraction)

💡 BUSINESS INSIGHTS ENABLED:

**Low Margin Analysis:**
• Identify which parts are manually flagged as low margin
• Calculate margin discrepancy: (ListPrice - StockOrderPrice) vs actual margin
• Track inventory value tied up in low margin parts

**Margin Calculations:**
• Original Margin = ListPrice - StockOrderPrice
• Actual Margin = SellPrice - Cost (from jdis_Part_Information)
• Margin Discrepancy = Actual - Original

**Report Filtering:**
• Filter to LowMarginFlag = "Low" for parts manager focus
• Cross-reference with transaction data for sales patterns
• Identify pricing opportunities

📝 NEXT STEPS AFTER LOADING:

1. **Validate Data:**
   - Check row counts match source
   - Verify LowMarginFlag values ("Low", blank, other?)
   - Confirm StockOrderPrice has values

2. **Join Testing:**
   - Test join to jdis_Part_Information (Branch + PartNumber)
   - Verify all InTrans parts have InMaster records
   - Check for orphaned parts

3. **Build Dimension:**
   - Create dim_Parts with LEFT JOIN to this table
   - Include LowMarginFlag as filter dimension
   - Add StockOrderPrice for margin calculations

4. **Document Findings:**
   - Record row counts
   - Document LowMarginFlag value distribution
   - Note any data quality issues

============================================================================
*/
