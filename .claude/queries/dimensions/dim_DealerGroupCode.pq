/*
============================================================================
Dimension: dim_DealerGroupCode
Dataflow: df_Dim_DealerGroupCode
Location: LH_Master_Data → Dataflows → 03 - Dimensions
============================================================================

📋 METADATA:
Source: jdis_Part_Information (Lakehouse table)
Purpose: Dealer group classification for parts inventory categorization
Created: [Unknown - pre-dates current documentation]
Last Modified: 06/23/2025
Output: Lakehouse table "dim_DealerGroupCode"

⏱️ REFRESH CHARACTERISTICS:
Refresh Schedule: Not scheduled (reference data - recommend monthly)
Average Refresh Time: ~1:40 minutes
Refresh Strategy: Full refresh with distinct values extraction
Row Count: 1,813 distinct dealer group codes (as of documentation)
Query Folding: No (Lakehouse source with in-memory transformations)

⚠️ OPTIMIZATION OPPORTUNITY:
Current refresh time (~1:40) is higher than expected for 1,813 rows
Query contains redundant operations that could be streamlined:
• Multiple distinct operations (4 total - lines redundant)
• Multiple unknown record appends (3 total - should be 1)
• Multiple sort operations (3 total - only final sort needed)
• Double blank removal (before and after distinct)
Estimated optimization potential: Reduce to ~1:00 or less
Recommendation: Review and simplify query logic when time permits

📊 DIMENSION TYPE: **Type 1 - Slowly Changing Dimension (Overwrite)**
- **Infrequent changes** - new dealer group codes added occasionally
- **No SCD tracking** - current state only
- **Source-driven** - derived from active parts in jdis_Part_Information

🎯 BUSINESS USE CASES:
• Parts Categorization: Group parts by dealer group for inventory analysis
• Dealer Network Analysis: Track parts distribution across dealer groups
• Inventory Reporting: Dealer group-based stock reports and dashboards
• Supplier Management: Analyze dealer group distribution across vendors
• Pricing Strategy: Dealer group-level pricing and margin analysis

📊 DATA STRUCTURE (2 COLUMNS):

**Surrogate Key:**
• DealerGroupKey (Int64) - Surrogate key for relationships (-1 = Unknown)

**Natural Key/Attributes:**
• DealerGroupCode (text) - Dealer group classification code from source system
  - **Normalized**: UPPERCASE for consistency
  - **Cleaned**: Trimmed and cleaned of non-printable characters

**Distinct Values:**
• 1,813 unique dealer group codes (extracted from jdis_Part_Information)
• All blank/null values removed
• Text cleaned, trimmed, and uppercased for consistency
• Sorted alphabetically

🔧 DESIGN PRINCIPLES:

**Distinct Values Pattern:**
• Extracts unique DealerGroupCode values from jdis_Part_Information
• Source table: 1.08M parts → 1,813 distinct dealer group codes
• Automatically captures new codes as parts are added to source
• No manual maintenance required (self-updating from source)

**Data Quality Steps:**
1. **Select Column**: Isolate DealerGroupCode for processing
2. **Remove Blanks (First Pass)**: Eliminate empty records before processing
3. **Trim**: Remove leading/trailing whitespace
4. **Clean**: Remove non-printable characters
5. **Distinct (First Pass)**: Get unique values
6. **Sort (First Pass)**: Alphabetical order
7. **Remove Blanks (Second Pass)**: Final cleanup after transformations
8. **Uppercase**: Normalize to UPPERCASE for consistency
9. **Index**: Generate surrogate keys starting at 1
10. **Append Unknown**: Add -1 key for unmapped values
11. **Multiple Redundant Operations**: Sort/distinct/append repeated (OPTIMIZATION TARGET)

**Text Normalization Strategy:**
• Text.Trim() - removes leading/trailing spaces
• Text.Clean() - removes non-printable characters (ASCII control chars)
• Text.Upper() - normalizes to UPPERCASE (prevents "ABC" vs "abc" duplicates)
• Triple blank removal ensures no empty records

**Surrogate Key Generation:**
• Sequential numbering starting at 1
• Unknown record (-1) added for fact table orphan handling
• Allows for stable relationships even as new codes added

**Unknown Record Handling:**
• DealerGroupKey = -1 for unknown/unmapped dealer group codes
• Referenced from "UnknownDealerGroupCode" query (separate query)
• Standard dimension pattern for handling fact table orphans
• **NOTE**: Currently appended 3 times (redundant - optimization target)

🔗 RELATIONSHIPS:

**Primary Usage:**
- **dim_Parts** (Many-to-One)
  - Join: dim_Parts.DealerGroupCode = dim_DealerGroupCode.DealerGroupCode
  - Cross-filter direction: Single (dim → dim)
  - Cardinality: Many-to-One

- **Fact Tables** (Many-to-One via dim_Parts)
  - Indirect relationship through dim_Parts
  - Enables dealer group-level fact analysis

**Related Dimensions:**
- Works with dim_Parts for complete parts classification
- May relate to dim_CommodityCode for cross-classification analysis
- May relate to vendor/supplier dimensions for dealer network analysis

⚠️ IMPORTANT NOTES:

**Refresh Strategy:**
• **RECOMMENDED**: Monthly refresh (reference data changes infrequently)
• **NOT RECOMMENDED**: Daily refresh (unnecessary overhead)
• **TRIGGER**: Refresh when jdis_Part_Information has significant updates
• **FUTURE PIPELINE**: Consider "Reference Data Pipeline" (first Monday of month at 8:00 AM)

**Performance Considerations:**
• Current refresh time: ~1:40 minutes (higher than expected)
• Row count: 1,813 (should be faster)
• Source: 1.08M rows → 1,813 distinct codes (good reduction)
• **BOTTLENECK**: Redundant operations in query logic
• **OPTIMIZATION POTENTIAL**: Streamline to ~1:00 or less

**Query Optimization Opportunities (FUTURE ENHANCEMENT):**

**Current Issues:**
1. **Multiple Distinct Operations** (4 total):
   - Line: #"Removed duplicates" (after clean)
   - Line: #"Removed duplicates 1" (after first append)
   - Line: #"Removed duplicates 2" (after second append)
   - Line: #"Removed duplicates 3" (final - on DealerGroupCode)
   - **RECOMMENDATION**: Single distinct operation after all transformations

2. **Multiple Unknown Record Appends** (3 total):
   - Line: #"Appended query" (first append)
   - Line: #"Appended query 1" (second append)
   - **RECOMMENDATION**: Single append at end

3. **Multiple Sort Operations** (3 total):
   - Line: #"Sorted rows" (after first distinct)
   - Line: #"Sorted rows 1" (after first append)
   - Line: #"Sorted rows 2" (after second append)
   - **RECOMMENDATION**: Single sort at end for final ordering

4. **Double Blank Removal**:
   - Line: #"Removed blank rows" (before distinct)
   - Line: #"Removed blank rows 1" (after sort)
   - **ACCEPTABLE**: First pass before processing, second after transformations

**Proposed Optimized Query Structure:**
```powerquery
// 1. Source navigation (unchanged)
// 2. Select DealerGroupCode column
// 3. Remove blanks (first pass)
// 4. Trim text
// 5. Clean text
// 6. Uppercase text
// 7. Remove blanks (second pass)
// 8. Distinct (SINGLE operation)
// 9. Sort (SINGLE operation)
// 10. Add index
// 11. Rename to DealerGroupKey
// 12. Reorder columns
// 13. Append unknown (SINGLE operation)
// 14. Final sort (SINGLE operation - if needed)
```

**Expected Performance Gain:**
• Eliminate 3 redundant distinct operations
• Eliminate 2 redundant unknown appends
• Eliminate 2 redundant sort operations
• Estimated time reduction: 1:40 → ~1:00 (40% improvement)

**Data Quality:**
• 1,813 distinct codes from 1.08M parts (good granularity)
• All blank/null values removed (prevents orphan records)
• Text cleaned, trimmed, and uppercased (prevents duplicate keys)
• Alphabetically sorted (easier navigation and debugging)

**Lakehouse Source Pattern:**
• Reads from Lakehouse table (not raw ODBC source)
• Depends on jdis_Part_Information being refreshed first
• Workspace ID and Lakehouse ID are environment-specific
• No query folding (all transformations in-memory)

**UnknownDealerGroupCode Query:**
• Separate query defining the -1 unknown record
• Appended at end via Table.Combine
• Standard pattern for dimension unknown records
• **NOTE**: Currently appended 3 times (optimization target)

Dependencies:
• jdis_Part_Information (Lakehouse table - must refresh first)
• UnknownDealerGroupCode (query defining unknown record)

Used By:
• dim_Parts (dealer group classification lookup)
• Parts analysis reports (dealer group grouping)
• Inventory dashboards (dealer group-level views)
• Dealer network analytics (dealer group distribution patterns)

Related Dimensions:
• dim_Parts (primary consumer of dealer group codes)
• dim_CommodityCode (cross-classification analysis)
• dim_VendorCode (if exists - dealer/vendor analysis)

Critical Finding:
**Self-updating dimension - automatically captures new dealer group codes**
**Monthly refresh recommended (reference data changes infrequently)**
**OPTIMIZATION OPPORTUNITY: Redundant operations increase refresh time by ~40%**
**1,813 codes from 1.08M parts = good classification granularity**

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
    // STEP 2: SELECT DEALERGROUPCODE COLUMN
    // ========================================================================
    /*
    PURPOSE: Isolate DealerGroupCode column for distinct extraction
    SOURCE REDUCTION: 1.08M rows × many columns → 1.08M rows × 1 column
    */
    #"Choose columns" = Table.SelectColumns(#"Navigation 3", {"DealerGroupCode"}),

    // ========================================================================
    // STEP 3: REMOVE BLANK ROWS (FIRST PASS)
    // ========================================================================
    /*
    PURPOSE: Eliminate empty/null records before processing
    PERFORMANCE: Reduces rows before transformations
    */
    #"Removed blank rows" = Table.SelectRows(
        #"Choose columns",
        each not List.IsEmpty(List.RemoveMatchingItems(Record.FieldValues(_), {"", null}))
    ),

    // ========================================================================
    // STEP 4: TRIM TEXT
    // ========================================================================
    /*
    PURPOSE: Remove leading/trailing whitespace
    PREVENTS: Duplicate keys due to "ABC" vs "ABC " vs " ABC"
    */
    #"Trimmed text" = Table.TransformColumns(
        #"Removed blank rows",
        {{"DealerGroupCode", each Text.Trim(_), type nullable text}}
    ),

    // ========================================================================
    // STEP 5: CLEAN TEXT
    // ========================================================================
    /*
    PURPOSE: Remove non-printable characters (ASCII control characters)
    ENSURES: Clean, displayable text in reports
    */
    #"Cleaned text" = Table.TransformColumns(
        #"Trimmed text",
        {{"DealerGroupCode", each Text.Clean(_), type nullable text}}
    ),

    // ========================================================================
    // STEP 6: GET DISTINCT DEALER GROUP CODES (FIRST DISTINCT)
    // ========================================================================
    /*
    PURPOSE: Extract unique dealer group codes
    RESULT: 1.08M rows → ~1,813 distinct codes (significant reduction)
    OPTIMIZATION NOTE: First of 4 distinct operations (3 redundant)
    */
    #"Removed duplicates" = Table.Distinct(#"Cleaned text", {"DealerGroupCode"}),

    // ========================================================================
    // STEP 7: SORT ALPHABETICALLY (FIRST SORT)
    // ========================================================================
    /*
    PURPOSE: Consistent ordering for debugging and navigation
    OPTIMIZATION NOTE: First of 3 sort operations (2 redundant)
    */
    #"Sorted rows" = Table.Sort(#"Removed duplicates", {{"DealerGroupCode", Order.Ascending}}),

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
    // STEP 9: UPPERCASE TEXT
    // ========================================================================
    /*
    PURPOSE: Normalize to UPPERCASE for consistency
    PREVENTS: Duplicate keys due to "ABC" vs "abc" vs "Abc"
    BUSINESS BENEFIT: Consistent display in reports and dashboards
    */
    #"Uppercased text" = Table.TransformColumns(
        #"Removed blank rows 1",
        {{"DealerGroupCode", each Text.Upper(_), type nullable text}}
    ),

    // ========================================================================
    // STEP 10: ADD SURROGATE KEY
    // ========================================================================
    /*
    PURPOSE: Generate sequential surrogate key for relationships
    METHOD: Index starting at 1, incrementing by 1
    RESULT: DealerGroupKey (1, 2, 3, ... 1813)
    */
    #"Added index" = Table.AddIndexColumn(
        #"Uppercased text",
        "Index",
        1,
        1,
        Int64.Type
    ),

    // ========================================================================
    // STEP 11: RENAME INDEX TO SURROGATE KEY
    // ========================================================================
    /*
    PURPOSE: Use standard naming convention for dimension keys
    */
    #"Renamed columns" = Table.RenameColumns(#"Added index", {{"Index", "DealerGroupKey"}}),

    // ========================================================================
    // STEP 12: REORDER COLUMNS
    // ========================================================================
    /*
    PURPOSE: Standard dimension pattern - key first, then attributes
    ORDER: DealerGroupKey, DealerGroupCode
    */
    #"Reordered columns" = Table.ReorderColumns(
        #"Renamed columns",
        {"DealerGroupKey", "DealerGroupCode"}
    ),

    // ========================================================================
    // STEP 13: APPEND UNKNOWN RECORD (FIRST APPEND)
    // ========================================================================
    /*
    PURPOSE: Add unknown record (-1 key) for fact table orphan handling
    SOURCE: UnknownDealerGroupCode query (separate query)
    OPTIMIZATION NOTE: First of 3 appends (2 redundant)
    */
    #"Appended query" = Table.Combine({#"Reordered columns", UnknownDealerGroupCode}),

    // ========================================================================
    // STEP 14: SORT AFTER FIRST APPEND (SECOND SORT - REDUNDANT)
    // ========================================================================
    /*
    PURPOSE: Sort after appending unknown record
    OPTIMIZATION NOTE: Redundant - final sort would suffice
    */
    #"Sorted rows 1" = Table.Sort(#"Appended query", {{"DealerGroupKey", Order.Ascending}}),

    // ========================================================================
    // STEP 15: DISTINCT ON KEY (SECOND DISTINCT - REDUNDANT)
    // ========================================================================
    /*
    PURPOSE: Remove duplicate keys (shouldn't exist if index worked correctly)
    OPTIMIZATION NOTE: Redundant - index generates unique keys
    */
    #"Removed duplicates 1" = Table.Distinct(#"Sorted rows 1", {"DealerGroupKey"}),

    // ========================================================================
    // STEP 16: APPEND UNKNOWN RECORD AGAIN (SECOND APPEND - REDUNDANT)
    // ========================================================================
    /*
    PURPOSE: Re-append unknown record (unclear why needed)
    OPTIMIZATION NOTE: Redundant - unknown already appended in step 13
    */
    #"Appended query 1" = Table.Combine({#"Removed duplicates 1", UnknownDealerGroupCode}),

    // ========================================================================
    // STEP 17: SORT AFTER SECOND APPEND (THIRD SORT - REDUNDANT)
    // ========================================================================
    /*
    PURPOSE: Sort after second append
    OPTIMIZATION NOTE: Redundant - final sort would suffice
    */
    #"Sorted rows 2" = Table.Sort(#"Appended query 1", {{"DealerGroupKey", Order.Ascending}}),

    // ========================================================================
    // STEP 18: DISTINCT ON KEY AGAIN (THIRD DISTINCT - REDUNDANT)
    // ========================================================================
    /*
    PURPOSE: Remove duplicate keys again
    OPTIMIZATION NOTE: Redundant - attempting to fix duplicate unknown records
    */
    #"Removed duplicates 2" = Table.Distinct(#"Sorted rows 2", {"DealerGroupKey"}),

    // ========================================================================
    // STEP 19: FINAL DISTINCT ON CODE (FOURTH DISTINCT - CLEANUP)
    // ========================================================================
    /*
    PURPOSE: Final cleanup of duplicate dealer group codes
    OPTIMIZATION NOTE: Attempting to remove duplicates from multiple appends
    */
    #"Removed duplicates 3" = Table.Distinct(#"Removed duplicates 2", {"DealerGroupCode"})

in
    #"Removed duplicates 3"

/*
============================================================================
✅ PRODUCTION STATUS: READY - MONTHLY REFRESH RECOMMENDED (OPTIMIZATION PENDING)
============================================================================

🎯 IMPLEMENTATION SUMMARY:
• Type 1 Dimension: Overwrite, no historical tracking
• 1,813 Distinct Codes: Extracted from 1.08M parts
• Self-Updating: Automatically captures new codes from source
• Reference Data: Changes infrequently (monthly refresh adequate)
• **OPTIMIZATION PENDING**: Query contains redundant operations

📊 DIMENSION CHARACTERISTICS:
• **Grain**: One row per dealer group code
• **Keys**: DealerGroupKey (surrogate), DealerGroupCode (natural)
• **Attributes**: 2 columns (key + code)
• **SCD Type**: Type 1 (no historical tracking)
• **Unknown Record**: -1 key for orphan handling
• **Normalization**: UPPERCASE for consistency

🔗 RELATIONSHIP READY:
• **Primary Consumer**: dim_Parts
• **Join Key**: DealerGroupCode (natural key)
• **Cardinality**: Many-to-One (many parts per dealer group)
• **Filter Direction**: Single (dim → dim or dim → fact)

⚡ REFRESH STRATEGY:

**RECOMMENDED: Monthly Reference Data Pipeline**
• **Schedule**: First Monday of month at 8:00 AM
• **Frequency**: Monthly (or as needed)
• **Duration**: ~1:40 minutes (OPTIMIZATION TARGET: reduce to ~1:00)
• **Rationale**: Reference data rarely changes

**NOT RECOMMENDED: Daily Refresh**
• Unnecessary overhead for slowly changing data
• Save CU capacity for dynamic tables
• Dealer group codes added infrequently

**Dependencies:**
• jdis_Part_Information must be current (refreshed first)
• UnknownDealerGroupCode query must exist

📝 MAINTENANCE CHECKLIST:

**Data Quality Checks:**
1. ✅ Verify 1,813 distinct codes extracted
2. ✅ Confirm no blank/null records
3. ✅ Check text trimmed, cleaned, and uppercased
4. ✅ Verify unknown record (-1) present (only once!)
5. ✅ Confirm alphabetical sorting

**When Adding to Monthly Pipeline:**
1. ✅ Schedule first Monday of month at 8:00 AM
2. ✅ Ensure jdis_Part_Information refreshes first
3. ✅ Group with other reference dimensions (dim_CommodityCode, etc.)
4. ✅ Test refresh duration (~1:40 expected, optimize to ~1:00 when time permits)

**Future Optimization (WHEN TIME PERMITS):**
1. 📋 Remove redundant distinct operations (reduce from 4 to 1)
2. 📋 Remove redundant unknown appends (reduce from 3 to 1)
3. 📋 Remove redundant sort operations (reduce from 3 to 1)
4. 📋 Test optimized query for correctness
5. 📋 Verify refresh time improvement (~40% reduction expected)

**Troubleshooting:**
• **Duplicate keys after refresh**: Multiple unknown appends causing duplicates
• **Row count changes significantly**: Investigate new parts added to jdis_Part_Information
• **Missing codes in dim_Parts**: Verify join logic uses DealerGroupCode natural key
• **Slow refresh**: Redundant operations are bottleneck (see optimization notes)

**NEVER:**
❌ Change DealerGroupKey generation logic (breaks fact table joins)
❌ Remove unknown record (breaks orphan handling)
❌ Skip text trimming/cleaning/uppercasing (creates duplicate keys)
❌ Schedule daily refresh (wastes CU capacity)

**OPTIMIZATION NOTES FOR FUTURE:**
Current query was written a long time ago and contains redundant operations.
When time permits, streamline the query to improve refresh performance.
Expected improvement: 1:40 → ~1:00 (40% reduction).
See detailed optimization recommendations in documentation above.

============================================================================
*/
