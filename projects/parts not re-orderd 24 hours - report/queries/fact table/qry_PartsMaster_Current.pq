/*
============================================================================
QRY_PARTSMASTER_CURRENT - DEDUPLICATED PARTS MASTER DATA
============================================================================

📋 QUERY OVERVIEW:
Purpose: Provide current parts master data with duplicate records removed
Grain: One row per unique Branch + PartNumber combination (deduplicated)
Source: jdis_Part_Information table from Lakehouse
Deduplication Strategy: Keep most recently used part (DateLastRequested DESC)

🎯 BUSINESS PROBLEM SOLVED:
- jdis_Part_Information contains duplicate records for same Branch + PartNumber
- Duplicates cause fact table records to multiply (1 transaction × 2 parts = 2 fact rows)
- Example: Branch 13, Part AR86745 had 2 records (active + 9-year-old obsolete record)
- Deduplication ensures only current/active part records are used

🔧 DEDUPLICATION LOGIC:
Priority order for keeping records when duplicates exist:
1. DateLastRequested (DESC) - Most recently requested part wins
2. BinQty (DESC) - Tie-breaker: Part with inventory wins
3. OnOrder (DESC) - Tie-breaker: Part being restocked wins

RATIONALE: Parts used recently are most likely to be current and active

📊 COLUMNS PROVIDED (8 COLUMNS):

**Core Part Identification:**
- Branch: Branch location
- PartNumber: Part number identifier
- Description: Part description (accurate source of truth)

**Inventory Status:**
- BinQty: Current bin quantity at branch
- OnOrder: Current on-order quantity (0 or null = not ordered)

**Sales History (NEW):**
- Current12MoSales: Units sold in last 12 months
- Previous12MoSales: Units sold in previous 12 months

**Classification (NEW):**
- DealerGroupCode: Dealer group classification

🔗 USED BY:
- fct_PartsNotReordered: Primary consumer for parts reorder monitoring report

============================================================================
*/

let
    // ========================================================================
    // STEP 1: SOURCE DATA FROM LAKEHOUSE
    // ========================================================================
    
    Source = jdis_Part_Information,
    
    // ========================================================================
    // STEP 2: SELECT REQUIRED COLUMNS (INCLUDING NEW COLUMNS)
    // ========================================================================
    /*
    PURPOSE: Pull only columns needed for parts reorder monitoring
    NEW COLUMNS ADDED:
    - DealerGroupCode: Dealer group classification for reporting
    - Current12MoSales: Recent sales activity (last 12 months)
    - Previous12MoSales: Historical sales comparison (previous 12 months)
    */
    
    SelectColumns = Table.SelectColumns(Source, {
        "Branch",
        "PartNumber",
        "Description",
        "OnOrder",
        "BinQty",
        "DateLastRequested",     // Used for deduplication sorting only
        "DealerGroupCode",       // NEW: Dealer group classification
        "Current12MoSales",      // NEW: Recent sales activity
        "Previous12MoSales"      // NEW: Historical sales comparison
    }),
    
    // ========================================================================
    // STEP 3: DEDUPLICATION STRATEGY - SORT BY PRIORITY
    // ========================================================================
    /*
    PURPOSE: Sort records to prioritize active/current parts before deduplication
    BUSINESS RULE: When duplicates exist, keep the most recently used record
    
    SORT ORDER:
    1. DateLastRequested DESC - Most recent activity indicates current record
    2. BinQty DESC - Parts with inventory more likely to be active
    3. OnOrder DESC - Parts being restocked more likely to be active
    
    EXAMPLE: Branch 13, Part AR86745
    - Record 1: DateLastRequested = 10/23/2025, BinQty = 8 (KEPT)
    - Record 2: DateLastRequested = 7/27/2016, BinQty = 0 (REMOVED)
    */
    
    SortForDeduplication = Table.Sort(SelectColumns, {
        {"DateLastRequested", Order.Descending},
        {"BinQty", Order.Descending},
        {"OnOrder", Order.Descending}
    }),
    
    // ========================================================================
    // STEP 4: REMOVE DUPLICATES - KEEP FIRST (MOST ACTIVE) RECORD
    // ========================================================================
    /*
    PURPOSE: Ensure one record per Branch + PartNumber combination
    METHOD: Keep first row per unique Branch + PartNumber (already sorted by priority)
    RESULT: Obsolete/inactive duplicate records are removed
    */
    
    RemoveDuplicates = Table.Distinct(SortForDeduplication, {"Branch", "PartNumber"}),
    
    // ========================================================================
    // STEP 5: CLEAN UP - REMOVE HELPER COLUMN
    // ========================================================================
    /*
    PURPOSE: Remove DateLastRequested column (only needed for deduplication logic)
    RESULT: Final output contains only business-required columns
    */
    
    RemoveSortColumn = Table.RemoveColumns(RemoveDuplicates, {"DateLastRequested"}),
    
    // ========================================================================
    // STEP 6: SET FINAL DATA TYPES
    // ========================================================================
    /*
    PURPOSE: Ensure proper data types for relationships and calculations
    */
    
    SetDataTypes = Table.TransformColumnTypes(RemoveSortColumn, {
        {"Branch", type text},
        {"PartNumber", type text},
        {"Description", type text},
        {"OnOrder", type number},
        {"BinQty", type number},
        {"DealerGroupCode", type text},
        {"Current12MoSales", type number},
        {"Previous12MoSales", type number}
    })

in
    SetDataTypes

/*
============================================================================
✅ QRY_PARTSMASTER_CURRENT - PRODUCTION READY WITH DEDUPLICATION
============================================================================

🎯 KEY ACHIEVEMENTS:
- Duplicate Elimination: One record per Branch + PartNumber (down from 2-4 duplicates)
- Active Records Only: Keeps recently used parts, removes obsolete records
- Sales History Added: Current and previous 12-month sales for trend analysis
- Classification Added: DealerGroupCode for reporting segmentation

📊 BEFORE vs AFTER DEDUPLICATION:
BEFORE: Branch 13, Part AR86745 = 2 records (1 active + 1 obsolete from 2016)
AFTER: Branch 13, Part AR86745 = 1 record (active record with BinQty=8)

🔗 IMPACT ON FACT TABLE:
BEFORE: 2 transactions × 2 parts master records = 4 fact table rows (duplicates)
AFTER: 2 transactions × 1 parts master record = 2 fact table rows (correct) ✓

⚡ PERFORMANCE:
- Query executes efficiently with deduplication logic
- Reduces downstream fact table size by eliminating duplicate joins
- Sales history columns add minimal overhead

🔧 MAINTENANCE NOTES:
- Deduplication logic is robust and based on DateLastRequested timestamp
- If additional columns needed, add to SelectColumns step
- Deduplication keys (Branch + PartNumber) should remain unchanged

============================================================================
*/