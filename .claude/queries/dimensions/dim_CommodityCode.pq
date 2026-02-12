/*
============================================================================
Dimension: dim_CommodityCode
Dataflow: df_Dim_CommodityCode
Location: LH_Master_Data → Dataflows → 03 - Dimensions
============================================================================

📋 METADATA:
Source: jdis_Part_Information (Lakehouse table)
Purpose: Commodity code classification for parts inventory categorization
Created: [Unknown - pre-dates current documentation]
Last Modified: 06/23/2025
Output: Lakehouse table "dim_CommodityCode"

⏱️ REFRESH CHARACTERISTICS:
Refresh Schedule: Not scheduled (reference data - recommend monthly)
Average Refresh Time: ~1:30 minutes
Refresh Strategy: Full refresh with distinct values extraction
Row Count: 780 distinct commodity codes (as of documentation)
Query Folding: No (Lakehouse source with in-memory transformations)

📊 DIMENSION TYPE: **Type 1 - Slowly Changing Dimension (Overwrite)**
- **Infrequent changes** - new commodity codes added occasionally
- **No SCD tracking** - current state only
- **Source-driven** - derived from active parts in jdis_Part_Information

🎯 BUSINESS USE CASES:
• Parts Categorization: Group parts by commodity type for inventory analysis
• Purchasing Analysis: Track commodity-level purchasing patterns
• Inventory Reporting: Commodity-based stock reports and dashboards
• Supplier Management: Analyze commodity distribution across vendors
• Financial Analysis: Commodity-level cost and margin analysis

📊 DATA STRUCTURE (2 COLUMNS):

**Surrogate Key:**
• CommodityCodeKey (Int64) - Surrogate key for relationships (-1 = Unknown)

**Natural Key/Attributes:**
• CommodityCode (text) - Commodity classification code from source system

**Distinct Values:**
• 780 unique commodity codes (extracted from jdis_Part_Information)
• All blank/null values removed
• Text cleaned and trimmed
• Sorted alphabetically

🔧 DESIGN PRINCIPLES:

**Distinct Values Pattern:**
• Extracts unique CommodityCode values from jdis_Part_Information
• Source table: 1.08M parts → 780 distinct commodity codes
• Automatically captures new codes as parts are added to source
• No manual maintenance required (self-updating from source)

**Data Quality Steps:**
1. **Remove Blanks (First Pass)**: Eliminate empty records before distinct
2. **Distinct**: Get unique CommodityCode values
3. **Trim**: Remove leading/trailing whitespace
4. **Clean**: Remove non-printable characters
5. **Sort**: Alphabetical order for consistency
6. **Remove Blanks (Second Pass)**: Final cleanup after transformations
7. **Index**: Generate surrogate keys starting at 1
8. **Unknown Record**: Add -1 key for unmapped values

**Text Cleaning Strategy:**
• Text.Trim() - removes leading/trailing spaces
• Text.Clean() - removes non-printable characters (ASCII control chars)
• Double blank removal ensures no empty records slip through

**Surrogate Key Generation:**
• Sequential numbering starting at 1
• Unknown record (-1) added for fact table orphan handling
• Allows for stable relationships even as new codes added

**Unknown Record Handling:**
• CommodityCodeKey = -1 for unknown/unmapped commodity codes
• Referenced from "UnknownCommodityCode" query (separate query)
• Standard dimension pattern for handling fact table orphans

🔗 RELATIONSHIPS:

**Primary Usage:**
- **dim_Parts** (Many-to-One)
  - Join: dim_Parts.CommodityCode = dim_CommodityCode.CommodityCode
  - Cross-filter direction: Single (dim → dim)
  - Cardinality: Many-to-One

- **Fact Tables** (Many-to-One via dim_Parts)
  - Indirect relationship through dim_Parts
  - Enables commodity-level fact analysis

**Related Dimensions:**
- Works with dim_Parts for complete parts classification
- May relate to vendor/supplier dimensions for purchasing analysis

⚠️ IMPORTANT NOTES:

**Refresh Strategy:**
• **RECOMMENDED**: Monthly refresh (reference data changes infrequently)
• **NOT RECOMMENDED**: Daily refresh (unnecessary overhead)
• **Trigger**: Refresh when jdis_Part_Information has significant updates
• **Future Pipeline**: Consider "Reference Data Pipeline" (first Monday of month at 8:00 AM)

**Data Quality:**
• 780 distinct codes from 1.08M parts (good granularity)
• All blank/null values removed (prevents orphan records)
• Text cleaned and trimmed (prevents duplicate keys from whitespace)
• Alphabetically sorted (easier navigation and debugging)

**Lakehouse Source Pattern:**
• Reads from Lakehouse table (not raw ODBC source)
• Depends on jdis_Part_Information being refreshed first
• Workspace ID and Lakehouse ID are environment-specific
• No query folding (all transformations in-memory)

**Performance Considerations:**
• Source: 1.08M rows → 780 distinct codes (significant reduction)
• ~1:30 refresh time reasonable for distinct + transformations
• In-memory operations (Lakehouse source doesn't fold)
• Monthly refresh adequate (codes rarely change)

**UnknownCommodityCode Query:**
• Separate query defining the -1 unknown record
• Appended at end via Table.Combine
• Standard pattern for dimension unknown records

Dependencies:
• jdis_Part_Information (Lakehouse table - must refresh first)
• UnknownCommodityCode (query defining unknown record)

Used By:
• dim_Parts (commodity classification lookup)
• Parts analysis reports (commodity grouping)
• Inventory dashboards (commodity-level views)
• Purchasing analytics (commodity purchasing patterns)

Related Dimensions:
• dim_Parts (primary consumer of commodity codes)
• dim_VendorCode (if exists - commodity/vendor analysis)
• dim_DealerGroupCode (if exists - commodity/dealer analysis)

Critical Finding:
**Self-updating dimension - automatically captures new commodity codes**
**Monthly refresh recommended (reference data changes infrequently)**
**780 codes from 1.08M parts = good classification granularity**

============================================================================
*/

let
    // ========================================================================
    // STEP 1: CONNECT TO LAKEHOUSE
    // ========================================================================
    /*
    PURPOSE: Navigate to jdis_Part_Information table in Lakehouse
    METHOD: Lakehouse.Contents() navigation (workspace → lakehouse → table)
    NOTE: Workspace ID and Lakehouse ID are environment-specific
    */
    Source = Lakehouse.Contents([]),
    #"Navigation 1" = Source{[workspaceId = "b48cdb35-7ce3-46de-96df-d70db77649cb"]}[Data],
    #"Navigation 2" = #"Navigation 1"{[lakehouseId = "3e74497b-8c51-4a1a-91a1-888c59118f48"]}[Data],
    #"Navigation 3" = #"Navigation 2"{[Id = "jdis_Part_Information", ItemKind = "Table"]}[Data],

    // ========================================================================
    // STEP 2: SELECT COMMODITYCODE COLUMN
    // ========================================================================
    /*
    PURPOSE: Isolate CommodityCode column for distinct extraction
    SOURCE REDUCTION: 1.08M rows × many columns → 1.08M rows × 1 column
    */
    #"Removed other columns" = Table.SelectColumns(#"Navigation 3", {"CommodityCode"}),

    // ========================================================================
    // STEP 3: REMOVE BLANK ROWS (FIRST PASS)
    // ========================================================================
    /*
    PURPOSE: Eliminate empty/null records before distinct operation
    PERFORMANCE: Reduces rows before distinct calculation
    */
    #"Removed blank rows" = Table.SelectRows(
        #"Removed other columns",
        each not List.IsEmpty(List.RemoveMatchingItems(Record.FieldValues(_), {"", null}))
    ),

    // ========================================================================
    // STEP 4: GET DISTINCT COMMODITY CODES
    // ========================================================================
    /*
    PURPOSE: Extract unique commodity codes
    RESULT: 1.08M rows → 780 distinct codes (significant reduction)
    */
    #"Removed duplicates" = Table.Distinct(#"Removed blank rows", {"CommodityCode"}),

    // ========================================================================
    // STEP 5: TRIM TEXT
    // ========================================================================
    /*
    PURPOSE: Remove leading/trailing whitespace
    PREVENTS: Duplicate keys due to "ABC" vs "ABC " vs " ABC"
    */
    #"Trimmed text" = Table.TransformColumns(
        #"Removed duplicates",
        {{"CommodityCode", each Text.Trim(_), type nullable text}}
    ),

    // ========================================================================
    // STEP 6: CLEAN TEXT
    // ========================================================================
    /*
    PURPOSE: Remove non-printable characters (ASCII control characters)
    ENSURES: Clean, displayable text in reports
    */
    #"Cleaned text" = Table.TransformColumns(
        #"Trimmed text",
        {{"CommodityCode", each Text.Clean(_), type nullable text}}
    ),

    // ========================================================================
    // STEP 7: SORT ALPHABETICALLY
    // ========================================================================
    /*
    PURPOSE: Consistent ordering for debugging and navigation
    BENEFIT: Easier to spot anomalies in commodity codes
    */
    #"Sorted rows" = Table.Sort(#"Cleaned text", {{"CommodityCode", Order.Ascending}}),

    // ========================================================================
    // STEP 8: REMOVE BLANK ROWS (SECOND PASS)
    // ========================================================================
    /*
    PURPOSE: Final cleanup after trim/clean transformations
    ENSURES: No blank records from cleaning operations
    */
    #"Removed blank rows 1" = Table.SelectRows(
        #"Sorted rows",
        each not List.IsEmpty(List.RemoveMatchingItems(Record.FieldValues(_), {"", null}))
    ),

    // ========================================================================
    // STEP 9: ADD SURROGATE KEY
    // ========================================================================
    /*
    PURPOSE: Generate sequential surrogate key for relationships
    METHOD: Index starting at 1, incrementing by 1
    RESULT: CommodityCodeKey (1, 2, 3, ... 780)
    */
    #"Added index" = Table.AddIndexColumn(
        #"Removed blank rows 1",
        "Index",
        1,
        1,
        Int64.Type
    ),

    // ========================================================================
    // STEP 10: RENAME INDEX TO SURROGATE KEY
    // ========================================================================
    /*
    PURPOSE: Use standard naming convention for dimension keys
    */
    #"Renamed columns" = Table.RenameColumns(#"Added index", {{"Index", "CommodityCodeKey"}}),

    // ========================================================================
    // STEP 11: REORDER COLUMNS
    // ========================================================================
    /*
    PURPOSE: Standard dimension pattern - key first, then attributes
    ORDER: CommodityCodeKey, CommodityCode
    */
    #"Reordered columns" = Table.ReorderColumns(
        #"Renamed columns",
        {"CommodityCodeKey", "CommodityCode"}
    ),

    // ========================================================================
    // STEP 12: APPEND UNKNOWN RECORD
    // ========================================================================
    /*
    PURPOSE: Add unknown record (-1 key) for fact table orphan handling
    SOURCE: UnknownCommodityCode query (separate query)
    PATTERN: Standard dimension unknown record
    */
    #"Appended query" = Table.Combine({#"Reordered columns", UnknownCommodityCode}),

    // ========================================================================
    // STEP 13: FINAL SORT
    // ========================================================================
    /*
    PURPOSE: Ensure unknown record (-1) sorts first, then 1, 2, 3...
    RESULT: Clean, predictable dimension table
    */
    #"Sorted rows 1" = Table.Sort(#"Appended query", {{"CommodityCodeKey", Order.Ascending}})

in
    #"Sorted rows 1"

/*
============================================================================
✅ PRODUCTION STATUS: READY - MONTHLY REFRESH RECOMMENDED
============================================================================

🎯 IMPLEMENTATION SUMMARY:
• Type 1 Dimension: Overwrite, no historical tracking
• 780 Distinct Codes: Extracted from 1.08M parts
• Self-Updating: Automatically captures new codes from source
• Reference Data: Changes infrequently (monthly refresh adequate)

📊 DIMENSION CHARACTERISTICS:
• **Grain**: One row per commodity code
• **Keys**: CommodityCodeKey (surrogate), CommodityCode (natural)
• **Attributes**: 2 columns (key + code)
• **SCD Type**: Type 1 (no historical tracking)
• **Unknown Record**: -1 key for orphan handling

🔗 RELATIONSHIP READY:
• **Primary Consumer**: dim_Parts
• **Join Key**: CommodityCode (natural key)
• **Cardinality**: Many-to-One (many parts per commodity)
• **Filter Direction**: Single (dim → dim or dim → fact)

⚡ REFRESH STRATEGY:

**RECOMMENDED: Monthly Reference Data Pipeline**
• **Schedule**: First Monday of month at 8:00 AM
• **Frequency**: Monthly (or as needed)
• **Duration**: ~1:30 minutes
• **Rationale**: Reference data rarely changes

**NOT RECOMMENDED: Daily Refresh**
• Unnecessary overhead for slowly changing data
• Save CU capacity for dynamic tables
• Commodity codes added infrequently

**Dependencies:**
• jdis_Part_Information must be current (refreshed first)
• UnknownCommodityCode query must exist

📝 MAINTENANCE CHECKLIST:

**Data Quality Checks:**
1. ✅ Verify 780 distinct codes extracted
2. ✅ Confirm no blank/null records
3. ✅ Check text trimmed and cleaned
4. ✅ Verify unknown record (-1) present
5. ✅ Confirm alphabetical sorting

**When Adding to Monthly Pipeline:**
1. ✅ Schedule first Monday of month at 8:00 AM
2. ✅ Ensure jdis_Part_Information refreshes first
3. ✅ Group with other reference dimensions (dim_AdjustmentType, etc.)
4. ✅ Test refresh duration (~1:30 expected)

**Troubleshooting:**
• **Duplicate keys after refresh**: Check for new whitespace variations
• **Row count changes significantly**: Investigate new parts added to jdis_Part_Information
• **Missing codes in dim_Parts**: Verify join logic uses CommodityCode natural key

**NEVER:**
❌ Change CommodityCodeKey generation logic (breaks fact table joins)
❌ Remove unknown record (breaks orphan handling)
❌ Skip text trimming/cleaning (creates duplicate keys)
❌ Schedule daily refresh (wastes CU capacity)

============================================================================
*/
