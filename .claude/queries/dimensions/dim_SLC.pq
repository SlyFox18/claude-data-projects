/*
============================================================================
DIM_SLC - SLC CLASSIFICATION DIMENSION
============================================================================

📋 METADATA:
Table Name: dim_SLC
Dataflow: df_Dim_SLC
Purpose: Standardized SLC (Stock Location Code / Stock Line Code) classification dimension
Grain: One row per unique SLC value
Last Modified: 06/23/2025

🔄 REFRESH CHARACTERISTICS:
Row Count: 123 distinct SLC values
Avg Refresh Time: ~1:30 minutes
Refresh Schedule: Not scheduled (recommend monthly reference data pipeline)
Refresh Strategy: Full refresh with special "Unknown" record pattern
Source Table: jdis_Part_Information (Lakehouse)

📊 DIMENSION TYPE: Type 1 (Overwrite)
Changes: SLC codes rarely change; new codes added infrequently
History: No historical tracking needed
Updates: Overwrite existing records when source changes

🎯 BUSINESS USE CASES:
• Parts Classification: Categorize parts by stock line classification
• Inventory Analysis: Filter and group inventory by SLC codes
• Parts Master Filtering: Standard dimension for parts-related reports
• Business Intelligence: Enable SLC-based slicing across all parts facts
• Report Consistency: Standardized SLC values across all reports
• Unknown Handling: Special record for parts with missing SLC values

📊 DATA STRUCTURE (2 Columns):

**Primary Key:**
• SLCKey: Surrogate key (1, 2, 3, ..., 123, plus -1 for Unknown)

**Descriptive Attributes:**
• SLC: Stock Location Code / Stock Line Code from jdis_Part_Information

🔧 DESIGN PRINCIPLES:

**Self-Updating Pattern:**
• Automatically discovers new SLC codes from jdis_Part_Information
• No manual maintenance required for new codes
• Distinct values extracted and sorted alphabetically
• Clean, trimmed values ensure data quality

**Special Record Pattern:**
• "Unknown" record (SLCKey = -1) for handling missing values
• Prevents fact table orphans when parts have NULL/blank SLC
• Standard dimensional modeling best practice

**Data Quality:**
• Text.Trim removes leading/trailing spaces
• Text.Clean removes non-printable characters
• Blank rows filtered out before key assignment
• Duplicates removed for guaranteed uniqueness

🔗 RELATIONSHIPS:
Related Fact Tables:
• Fact_PartsInventory → dim_SLC (via SLCKey)
• Any parts-based fact tables using SLC classification

Related Dimensions:
• dim_Parts (contains SLC as filter column)
• dim_CommodityCode (often used together for parts classification)
• dim_DealerGroupCode (another parts classification dimension)

Relationship Pattern:
• Fact[SLCKey] → dim_SLC[SLCKey]
• Cardinality: Many-to-One
• Cross-filter Direction: Single (dimension filters facts)

📋 IMPORTANT NOTES:

**Refresh Strategy:**
• Monthly refresh recommended (codes change infrequently)
• Could refresh with other reference dimensions (CommodityCode, DealerGroupCode)
• Consider "Reference Data Pipeline" - first Monday of month at 8:00 AM
• 1:30 refresh time is acceptable for 123 rows

**Source Data:**
• Extracts from jdis_Part_Information lakehouse table
• Self-updating: New SLC codes automatically included
• No hardcoded values (except Unknown record)

**Performance:**
• ~1:30 for 123 rows is reasonable (extracting distinct from 1M+ parts)
• Simple query pattern - no complex transformations
• Minimal memory footprint

**Dependencies:**
• Requires jdis_Part_Information to be refreshed first
• Must refresh before any fact tables using SLCKey
• Part of dimensional pipeline sequence

============================================================================
*/

let
    // ========================================================================
    // STEP 1: NAVIGATE TO SOURCE TABLE
    // ========================================================================
    /*
    SOURCE: jdis_Part_Information lakehouse table
    PURPOSE: Extract all unique SLC values from parts master
    PATTERN: Standard Fabric Lakehouse navigation
    */

    Source = Lakehouse.Contents([]),
    #"Navigation 1" = Source{[workspaceId = "b48cdb35-7ce3-46de-96df-d70db77649cb"]}[Data],
    #"Navigation 2" = #"Navigation 1"{[lakehouseId = "3e74497b-8c51-4a1a-91a1-888c59118f48"]}[Data],
    #"Navigation 3" = #"Navigation 2"{[Id = "jdis_Part_Information", ItemKind = "Table"]}[Data],

    // ========================================================================
    // STEP 2: DATA QUALITY TRANSFORMATIONS
    // ========================================================================
    /*
    QUALITY OPERATIONS: Clean and prepare SLC values
    ORDER: Select → Trim → Clean → Distinct → Sort → Filter blanks
    RATIONALE: Process in optimal sequence for performance
    */

    // Select only SLC column (reduce memory footprint)
    #"Removed other columns" = Table.SelectColumns(#"Navigation 3", {"SLC"}),

    // Remove leading/trailing whitespace
    #"Trimmed text" = Table.TransformColumns(#"Removed other columns", {
        {"SLC", each Text.Trim(_), type nullable text}
    }),

    // Remove non-printable characters
    #"Cleaned text" = Table.TransformColumns(#"Trimmed text", {
        {"SLC", each Text.Clean(_), type nullable text}
    }),

    // Get distinct SLC values only
    #"Removed duplicates" = Table.Distinct(#"Cleaned text", {"SLC"}),

    // Sort alphabetically for consistent ordering
    #"Sorted rows" = Table.Sort(#"Removed duplicates", {{"SLC", Order.Ascending}}),

    // Filter out blank/null rows
    #"Removed blank rows" = Table.SelectRows(#"Sorted rows",
        each not List.IsEmpty(List.RemoveMatchingItems(Record.FieldValues(_), {"", null}))),

    // ========================================================================
    // STEP 3: ADD SURROGATE KEY
    // ========================================================================
    /*
    PURPOSE: Create unique integer key for fact table relationships
    LOGIC: Sequential numbering starting from 1
    BENEFIT: Efficient joins and consistent key assignment
    */

    #"Added index" = Table.AddIndexColumn(#"Removed blank rows", "Index", 1, 1, Int64.Type),

    // Rename to semantic name
    #"Renamed columns" = Table.RenameColumns(#"Added index", {{"Index", "SLCKey"}}),

    // Put key column first (standard dimension pattern)
    #"Reordered columns" = Table.ReorderColumns(#"Renamed columns", {"SLCKey", "SLC"}),

    // ========================================================================
    // STEP 4: ADD SPECIAL "UNKNOWN" RECORD
    // ========================================================================
    /*
    DIMENSIONAL MODELING BEST PRACTICE: Handle missing values
    PATTERN: Add special record with negative key (-1)
    PURPOSE: Prevent fact table orphans when parts have no SLC
    USAGE: Fact tables use SLCKey = -1 when source SLC is null/blank
    */

    #"Appended query" = Table.Combine({#"Reordered columns", UnknownSLC}),

    // ========================================================================
    // STEP 5: FINAL SORT FOR CONSISTENCY
    // ========================================================================
    /*
    ENSURES: Unknown record (-1) appears first, then regular codes (1, 2, 3...)
    BENEFIT: Consistent output order across all refreshes
    */

    #"Sorted rows 1" = Table.Sort(#"Appended query", {{"SLCKey", Order.Ascending}})

in
    #"Sorted rows 1"

/*
============================================================================
📋 VALIDATION & TESTING
============================================================================

✅ POST-REFRESH VALIDATION:

1. **Row Count Verification:**
   - Should have ~123 rows (plus 1 Unknown record = 124 total)
   - Count may increase slightly as new SLC codes are added to parts
   - Verify: SELECT COUNT(*) FROM dim_SLC

2. **Unknown Record Exists:**
   - SLCKey = -1 should exist
   - SLC = "UNKNOWN" (or similar)
   - Verify: SELECT * FROM dim_SLC WHERE SLCKey = -1

3. **No Duplicates:**
   - SLCKey values must be unique (primary key)
   - SLC values must be unique (business key)
   - Verify: SELECT SLC, COUNT(*) FROM dim_SLC GROUP BY SLC HAVING COUNT(*) > 1

4. **No Blanks (except Unknown):**
   - No NULL or empty string SLC values (except Unknown record)
   - Verify: SELECT * FROM dim_SLC WHERE SLC IS NULL OR SLC = ''

5. **Alphabetical Order:**
   - Regular SLC codes should be alphabetically sorted
   - Unknown record should be first (SLCKey = -1)

✅ RELATIONSHIP VALIDATION:

After refresh, verify fact table relationships:
```sql
-- Check for orphaned fact records (should return 0)
SELECT COUNT(*)
FROM Fact_PartsInventory f
LEFT JOIN dim_SLC d ON f.SLCKey = d.SLCKey
WHERE d.SLCKey IS NULL
```

✅ BUSINESS VALIDATION:

Sample expected SLC codes (verify a few exist):
- Check for common SLC values from your business
- Verify new SLC codes appear if parts added
- Confirm SLC codes match jdis_Part_Information source

============================================================================
🔗 REFERENCE QUERY: UnknownSLC
============================================================================

This query references "UnknownSLC" query which should exist separately:

**UnknownSLC Query Structure:**
```powerquery
let
    UnknownRecord = #table(
        type table [SLCKey = Int64.Type, SLC = text],
        {{-1, "UNKNOWN"}}
    )
in
    UnknownRecord
```

**Purpose:** Provides special "Unknown" record for handling missing values
**Key:** -1 (negative to avoid conflicts with regular sequential keys)
**Usage:** Fact tables reference this when source SLC is null/blank

============================================================================
🚀 DEPLOYMENT NOTES
============================================================================

**Prerequisites:**
1. ✅ jdis_Part_Information must exist in lakehouse
2. ✅ UnknownSLC helper query must exist
3. ✅ Workspace and Lakehouse IDs must match your environment

**Deployment Steps:**
1. Create UnknownSLC helper query first
2. Create df_Dim_SLC dataflow with this query
3. Schedule monthly refresh (or add to Reference Data Pipeline)
4. Create relationships in Power BI model
5. Verify row count (~124 total)

**Scheduling Recommendation:**
- Add to "Reference Data Pipeline" with other reference dimensions
- Suggested time: First Monday of month, 8:00 AM
- Sequence: After jdis_Part_Information, before fact tables
- Group with: dim_CommodityCode, dim_DealerGroupCode (similar patterns)

**Refresh Dependencies:**
- Must refresh AFTER: jdis_Part_Information (source)
- Must refresh BEFORE: Any fact tables using SLCKey
- Can refresh IN PARALLEL with: dim_CommodityCode, dim_DealerGroupCode

============================================================================
📊 SAMPLE OUTPUT
============================================================================

Expected output structure (first few rows):

SLCKey | SLC
-------|----------
-1     | UNKNOWN
1      | A01
2      | B23
3      | C45
...    | ...
123    | Z99

**Characteristics:**
- 124 total rows (123 distinct SLC codes + 1 Unknown)
- SLCKey = -1 for Unknown (appears first when sorted)
- SLCKey = 1 to 123 for regular codes (alphabetically sorted)
- No duplicates, no blanks (except Unknown), clean text

============================================================================
*/
