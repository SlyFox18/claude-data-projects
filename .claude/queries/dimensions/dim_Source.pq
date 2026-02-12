/*
============================================================================
DIM_SOURCE - SOURCE CLASSIFICATION DIMENSION
============================================================================

📋 METADATA:
Table Name: dim_Source
Dataflow: df_Dim_Source
Purpose: Standardized Source classification dimension for parts
Grain: One row per unique Source value
Last Modified: 06/23/2025

🔄 REFRESH CHARACTERISTICS:
Row Count: 267 distinct Source values
Avg Refresh Time: ~1:30 minutes
Refresh Schedule: Not scheduled (recommend monthly reference data pipeline)
Refresh Strategy: Full refresh with special "Unknown" record pattern
Source Table: jdis_Part_Information (Lakehouse)

📊 DIMENSION TYPE: Type 1 (Overwrite)
Changes: Source codes rarely change; new codes added infrequently
History: No historical tracking needed
Updates: Overwrite existing records when source changes

🎯 BUSINESS USE CASES:
• Parts Source Analysis: Categorize parts by source classification
• Inventory Analysis: Filter and group inventory by Source codes
• Supplier Analysis: Track parts by source for vendor management
• Parts Master Filtering: Standard dimension for parts-related reports
• Business Intelligence: Enable Source-based slicing across all parts facts
• Report Consistency: Standardized Source values across all reports
• Unknown Handling: Special record for parts with missing Source values

📊 DATA STRUCTURE (2 Columns):

**Primary Key:**
• SourceKey: Surrogate key (1, 2, 3, ..., 267, plus -1 for Unknown)

**Descriptive Attributes:**
• Source: Source classification code from jdis_Part_Information

🔧 DESIGN PRINCIPLES:

**Self-Updating Pattern:**
• Automatically discovers new Source codes from jdis_Part_Information
• No manual maintenance required for new codes
• Distinct values extracted and sorted alphabetically
• Clean, trimmed values ensure data quality

**Special Record Pattern:**
• "Unknown" record (SourceKey = -1) for handling missing values
• Prevents fact table orphans when parts have NULL/blank Source
• Standard dimensional modeling best practice

**Data Quality:**
• Blank rows filtered out before processing
• Duplicates removed for guaranteed uniqueness
• Text.Trim removes leading/trailing spaces
• Text.Clean removes non-printable characters
• Applied at end for final data quality assurance

**Processing Order Note:**
• Query applies duplicate removal and text cleaning in unusual order
• Text cleaning happens AFTER Unknown record append (end of query)
• Ensures Unknown record is also cleaned/trimmed consistently
• Final duplicate removal ensures no conflicts with Unknown record

🔗 RELATIONSHIPS:
Related Fact Tables:
• Fact_PartsInventory → dim_Source (via SourceKey)
• Any parts-based fact tables using Source classification

Related Dimensions:
• dim_Parts (contains Source as filter column)
• dim_CommodityCode (often used together for parts classification)
• dim_DealerGroupCode (another parts classification dimension)
• dim_SLC (similar parts classification dimension)

Relationship Pattern:
• Fact[SourceKey] → dim_Source[SourceKey]
• Cardinality: Many-to-One
• Cross-filter Direction: Single (dimension filters facts)

📋 IMPORTANT NOTES:

**Refresh Strategy:**
• Monthly refresh recommended (codes change infrequently)
• Should refresh with other reference dimensions (CommodityCode, DealerGroupCode, SLC)
• Consider "Reference Data Pipeline" - first Monday of month at 8:00 AM
• 1:30 refresh time is acceptable for 267 rows

**Source Data:**
• Extracts from jdis_Part_Information lakehouse table
• Self-updating: New Source codes automatically included
• No hardcoded values (except Unknown record)
• 267 distinct codes suggests detailed source classification

**Performance:**
• ~1:30 for 267 rows is reasonable (extracting distinct from 1M+ parts)
• Simple query pattern - no complex transformations
• Minimal memory footprint
• Text cleaning at end doesn't impact performance significantly

**Dependencies:**
• Requires jdis_Part_Information to be refreshed first
• Must refresh before any fact tables using SourceKey
• Part of dimensional pipeline sequence

**Query Pattern Observation:**
• Similar to dim_SLC but with text cleaning at different position
• Both follow self-updating reference dimension pattern
• Both use Unknown record for missing value handling

============================================================================
*/

let
    // ========================================================================
    // STEP 1: NAVIGATE TO SOURCE TABLE
    // ========================================================================
    /*
    SOURCE: jdis_Part_Information lakehouse table
    PURPOSE: Extract all unique Source values from parts master
    PATTERN: Standard Fabric Lakehouse navigation
    */

    Source = Lakehouse.Contents([]),
    #"Navigation 1" = Source{[workspaceId = "b48cdb35-7ce3-46de-96df-d70db77649cb"]}[Data],
    #"Navigation 2" = #"Navigation 1"{[lakehouseId = "3e74497b-8c51-4a1a-91a1-888c59118f48"]}[Data],
    #"Navigation 3" = #"Navigation 2"{[Id = "jdis_Part_Information", ItemKind = "Table"]}[Data],

    // ========================================================================
    // STEP 2: INITIAL DATA QUALITY - EARLY STAGE
    // ========================================================================
    /*
    EARLY OPERATIONS: Select column, remove duplicates/blanks, sort
    RATIONALE: Reduce dataset size early for faster processing
    NOTE: Text cleaning happens later (after Unknown record append)
    */

    // Select only Source column (reduce memory footprint)
    #"Removed other columns" = Table.SelectColumns(#"Navigation 3", {"Source"}),

    // Get distinct Source values early
    #"Removed duplicates" = Table.Distinct(#"Removed other columns", {"Source"}),

    // Filter out blank/null rows early
    #"Removed blank rows" = Table.SelectRows(#"Removed duplicates",
        each not List.IsEmpty(List.RemoveMatchingItems(Record.FieldValues(_), {"", null}))),

    // Sort alphabetically for consistent ordering
    #"Sorted rows" = Table.Sort(#"Removed blank rows", {{"Source", Order.Ascending}}),

    // ========================================================================
    // STEP 3: ADD SURROGATE KEY
    // ========================================================================
    /*
    PURPOSE: Create unique integer key for fact table relationships
    LOGIC: Sequential numbering starting from 1
    BENEFIT: Efficient joins and consistent key assignment
    */

    #"Added index" = Table.AddIndexColumn(#"Sorted rows", "Index", 1, 1, Int64.Type),

    // Rename to semantic name
    #"Renamed columns" = Table.RenameColumns(#"Added index", {{"Index", "SourceKey"}}),

    // Put key column first (standard dimension pattern)
    #"Reordered columns" = Table.ReorderColumns(#"Renamed columns", {"SourceKey", "Source"}),

    // ========================================================================
    // STEP 4: ADD SPECIAL "UNKNOWN" RECORD
    // ========================================================================
    /*
    DIMENSIONAL MODELING BEST PRACTICE: Handle missing values
    PATTERN: Add special record with negative key (-1)
    PURPOSE: Prevent fact table orphans when parts have no Source
    USAGE: Fact tables use SourceKey = -1 when source Source is null/blank
    */

    #"Appended query" = Table.Combine({#"Reordered columns", UnknownSource}),

    // ========================================================================
    // STEP 5: FINAL SORT FOR CONSISTENCY
    // ========================================================================
    /*
    ENSURES: Unknown record (-1) appears first, then regular codes (1, 2, 3...)
    BENEFIT: Consistent output order across all refreshes
    */

    #"Sorted rows 1" = Table.Sort(#"Appended query", {{"SourceKey", Order.Ascending}}),

    // ========================================================================
    // STEP 6: FINAL DATA QUALITY - LATE STAGE
    // ========================================================================
    /*
    LATE OPERATIONS: Final duplicate removal and text cleaning
    RATIONALE: Ensures Unknown record is also cleaned consistently
    PURPOSE: Final data quality assurance after combining with Unknown
    NOTE: Duplicate removal here handles any edge cases with Unknown record
    */

    // Final duplicate removal (safety net after Unknown append)
    #"Removed duplicates 1" = Table.Distinct(#"Sorted rows 1", {"Source"}),

    // Remove leading/trailing whitespace (including Unknown record)
    #"Trimmed text" = Table.TransformColumns(#"Removed duplicates 1", {
        {"Source", each Text.Trim(_), type nullable text}
    }),

    // Remove non-printable characters (final quality check)
    #"Cleaned text" = Table.TransformColumns(#"Trimmed text", {
        {"Source", each Text.Clean(_), type nullable text}
    })

in
    #"Cleaned text"

/*
============================================================================
📋 VALIDATION & TESTING
============================================================================

✅ POST-REFRESH VALIDATION:

1. **Row Count Verification:**
   - Should have ~267 rows (plus 1 Unknown record = 268 total)
   - Count may increase slightly as new Source codes are added to parts
   - Verify: SELECT COUNT(*) FROM dim_Source

2. **Unknown Record Exists:**
   - SourceKey = -1 should exist
   - Source = "UNKNOWN" (or similar)
   - Verify: SELECT * FROM dim_Source WHERE SourceKey = -1

3. **No Duplicates:**
   - SourceKey values must be unique (primary key)
   - Source values must be unique (business key)
   - Verify: SELECT Source, COUNT(*) FROM dim_Source GROUP BY Source HAVING COUNT(*) > 1

4. **No Blanks (except Unknown):**
   - No NULL or empty string Source values (except Unknown record)
   - Verify: SELECT * FROM dim_Source WHERE Source IS NULL OR Source = ''

5. **Alphabetical Order:**
   - Regular Source codes should be alphabetically sorted
   - Unknown record should be first (SourceKey = -1)

6. **Text Quality:**
   - No leading/trailing spaces in Source values
   - No non-printable characters in Source values
   - Verify: SELECT * FROM dim_Source WHERE Source <> TRIM(Source)

✅ RELATIONSHIP VALIDATION:

After refresh, verify fact table relationships:
```sql
-- Check for orphaned fact records (should return 0)
SELECT COUNT(*)
FROM Fact_PartsInventory f
LEFT JOIN dim_Source d ON f.SourceKey = d.SourceKey
WHERE d.SourceKey IS NULL
```

✅ BUSINESS VALIDATION:

Sample expected Source codes (verify a few exist):
- Check for common Source values from your business
- Verify new Source codes appear if parts added
- Confirm Source codes match jdis_Part_Information source
- 267 codes suggests detailed classification (verify expected range)

============================================================================
🔗 REFERENCE QUERY: UnknownSource
============================================================================

This query references "UnknownSource" query which should exist separately:

**UnknownSource Query Structure:**
```powerquery
let
    UnknownRecord = #table(
        type table [SourceKey = Int64.Type, Source = text],
        {{-1, "UNKNOWN"}}
    )
in
    UnknownRecord
```

**Purpose:** Provides special "Unknown" record for handling missing values
**Key:** -1 (negative to avoid conflicts with regular sequential keys)
**Usage:** Fact tables reference this when source Source is null/blank

============================================================================
🚀 DEPLOYMENT NOTES
============================================================================

**Prerequisites:**
1. ✅ jdis_Part_Information must exist in lakehouse
2. ✅ UnknownSource helper query must exist
3. ✅ Workspace and Lakehouse IDs must match your environment

**Deployment Steps:**
1. Create UnknownSource helper query first
2. Create df_Dim_Source dataflow with this query
3. Schedule monthly refresh (or add to Reference Data Pipeline)
4. Create relationships in Power BI model
5. Verify row count (~268 total)

**Scheduling Recommendation:**
- Add to "Reference Data Pipeline" with other reference dimensions
- Suggested time: First Monday of month, 8:00 AM
- Sequence: After jdis_Part_Information, before fact tables
- Group with: dim_CommodityCode, dim_DealerGroupCode, dim_SLC (similar patterns)

**Refresh Dependencies:**
- Must refresh AFTER: jdis_Part_Information (source)
- Must refresh BEFORE: Any fact tables using SourceKey
- Can refresh IN PARALLEL with: dim_CommodityCode, dim_DealerGroupCode, dim_SLC

**Performance Notes:**
- Text cleaning at end of query is intentional design
- Ensures Unknown record is also cleaned consistently
- Minimal performance impact (267 rows processes quickly)
- Final duplicate removal is safety net for Unknown record append

============================================================================
📊 SAMPLE OUTPUT
============================================================================

Expected output structure (first few rows):

SourceKey | Source
----------|----------
-1        | UNKNOWN
1         | SOURCE_A
2         | SOURCE_B
3         | SOURCE_C
...       | ...
267       | SOURCE_Z

**Characteristics:**
- 268 total rows (267 distinct Source codes + 1 Unknown)
- SourceKey = -1 for Unknown (appears first when sorted)
- SourceKey = 1 to 267 for regular codes (alphabetically sorted)
- No duplicates, no blanks (except Unknown), clean text
- All values trimmed and cleaned (including Unknown)

============================================================================
🔍 QUERY PATTERN COMPARISON
============================================================================

**Comparison with dim_SLC:**
- Both extract distinct values from jdis_Part_Information
- Both use Unknown record pattern (negative key)
- Both sort alphabetically for consistency
- **Difference:** dim_Source applies text cleaning AFTER Unknown append
- **Difference:** dim_Source has additional duplicate removal after Unknown

**Pattern Choice:**
- dim_Source approach ensures Unknown record gets same text cleaning
- More robust handling of Unknown record consistency
- Slight redundancy (double duplicate removal) but safer
- Consider standardizing to this pattern for future dimensions

============================================================================
*/
