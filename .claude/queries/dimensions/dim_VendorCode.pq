/*
============================================================================
DIM_VENDORCODE - VENDOR CODE CLASSIFICATION DIMENSION
============================================================================

📋 METADATA:
Table Name: dim_VendorCode
Dataflow: df_Dim_VendorCode
Purpose: Standardized vendor code dimension for parts sourcing and supplier analysis
Grain: One row per unique vendor code
Last Modified: 05/29/2025

🔄 REFRESH CHARACTERISTICS:
Row Count: 1,311 distinct vendor codes
Avg Refresh Time: ~1:30 minutes
Refresh Schedule: Not scheduled (recommend monthly reference data pipeline)
Refresh Strategy: Full refresh (self-updating from parts master)
Source Table: jdis_Part_Information (Lakehouse)

📊 DIMENSION TYPE: Type 1 (Overwrite)
Changes: Vendor codes rarely change; new vendors added infrequently
History: No historical tracking needed
Updates: Overwrite existing records when source changes

🎯 BUSINESS USE CASES:
• Supplier Analysis: Track parts sourcing distribution across vendors
• Procurement Analytics: Analyze purchasing patterns by supplier
• Parts Master Filtering: Standard dimension for parts-related reports
• Vendor Performance: Enable vendor-based slicing across all parts facts
• Supply Chain Intelligence: Vendor consolidation and relationship analysis
• Cost Management: Vendor pricing and cost analysis across parts portfolio
• Business Intelligence: Strategic supplier relationships and diversification
• Inventory Planning: Vendor-specific inventory management and ordering

📊 DATA STRUCTURE (2 Columns):

**Primary Key:**
• VendorCodeKey: Surrogate key (1, 2, 3, ..., 1311)

**Descriptive Attributes:**
• VendorCode: Vendor identifier code from jdis_Part_Information

🔧 DESIGN PRINCIPLES:

**Self-Updating Pattern:**
• Automatically discovers new vendor codes from jdis_Part_Information
• No manual maintenance required for new vendors
• Distinct values extracted and sorted alphabetically
• Clean data quality with blank filtering

**Simple Structure:**
• Two-column design: Key + Code
• Lightweight and efficient for joins
• Alphabetically sorted for consistency
• No special "Unknown" record (unlike some other dimensions)

**Data Quality:**
• Blank rows filtered out
• Duplicates removed for guaranteed uniqueness
• Alphabetical sort for consistent output
• Sequential key assignment for predictable relationships

🔗 RELATIONSHIPS:
Related Fact Tables:
• Fact_PartsInventory → dim_VendorCode (via VendorCodeKey)
• Fact_PartsPurchasing → dim_VendorCode (vendor sourcing analysis)
• Fact_PartsAdjustment → dim_VendorCode (vendor-specific adjustments)
• Any parts-based fact tables using vendor classification

Related Dimensions:
• dim_Parts (contains VendorCode as filter column)
• dim_Source (often used together for parts sourcing analysis)
• dim_CommodityCode (vendor specialization by commodity)
• dim_DealerGroupCode (vendor relationships with dealer groups)

Relationship Pattern:
• Fact[VendorCodeKey] → dim_VendorCode[VendorCodeKey]
• Cardinality: Many-to-One
• Cross-filter Direction: Single (dimension filters facts)

📋 IMPORTANT NOTES:

**Refresh Strategy:**
• Monthly refresh recommended (vendor codes change infrequently)
• Should refresh with other parts reference dimensions
• Consider "Reference Data Pipeline" - first Monday of month at 8:00 AM
• 1:30 refresh time is excellent for 1,311 rows

**Source Data:**
• Extracts from jdis_Part_Information lakehouse table
• Self-updating: New vendor codes automatically included
• No hardcoded values (unlike dim_UniqueCustomers)
• 1,311 codes suggests substantial vendor base

**Vendor Code Characteristics:**
• Typically alphanumeric codes (not descriptive names)
• Used for system identification and lookups
• May map to vendor master table for descriptive names
• Critical for parts ordering and procurement systems

**Performance:**
• ~1:30 for 1,311 rows is reasonable (extracting distinct from 1M+ parts)
• Simple query pattern - minimal transformations
• Lightweight memory footprint
• Efficient for fact table joins

**Dependencies:**
• Requires jdis_Part_Information to be refreshed first
• Must refresh before any fact tables using VendorCodeKey
• Part of dimensional pipeline sequence

**Pattern Consistency:**
• Similar to dim_SLC and dim_Source patterns
• All three extract distinct codes from jdis_Part_Information
• Consistent approach across parts classification dimensions
• Part of "parts reference dimension family"

**Notable Difference from Similar Dimensions:**
• **No Unknown record** - Unlike dim_SLC and dim_Source
• May want to add UnknownVendorCode reference in future
• Currently assumes all parts have valid vendor codes
• Consider adding Unknown pattern if NULL vendors exist in facts

============================================================================
*/

let
    // ========================================================================
    // STEP 1: NAVIGATE TO SOURCE TABLE
    // ========================================================================
    /*
    SOURCE: jdis_Part_Information lakehouse table
    PURPOSE: Extract all unique vendor codes from parts master
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
    QUALITY OPERATIONS: Select, deduplicate, filter blanks, sort
    ORDER: Optimal sequence for performance
    SIMPLE: No text cleaning (vendor codes are system-generated)
    */

    // Select only VendorCode column (reduce memory footprint)
    #"Removed other columns" = Table.SelectColumns(#"Navigation 3", {"VendorCode"}),

    // Get distinct VendorCode values only
    #"Removed duplicates" = Table.Distinct(#"Removed other columns", {"VendorCode"}),

    // Filter out blank/null rows
    #"Removed blank rows" = Table.SelectRows(#"Removed duplicates",
        each not List.IsEmpty(List.RemoveMatchingItems(Record.FieldValues(_), {"", null}))),

    // Sort alphabetically for consistent ordering
    #"Sorted rows" = Table.Sort(#"Removed blank rows", {{"VendorCode", Order.Ascending}}),

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
    #"Renamed columns" = Table.RenameColumns(#"Added index", {{"Index", "VendorCodeKey"}}),

    // Put key column first (standard dimension pattern)
    #"Reordered columns" = Table.ReorderColumns(#"Renamed columns", {"VendorCodeKey", "VendorCode"})

in
    #"Reordered columns"

/*
============================================================================
📋 VALIDATION & TESTING
============================================================================

✅ POST-REFRESH VALIDATION:

1. **Row Count Verification:**
   - Should have ~1,311 rows (may increase as new vendors added)
   - Verify: SELECT COUNT(*) FROM dim_VendorCode

2. **No Duplicates:**
   - VendorCodeKey values must be unique (primary key)
   - VendorCode values must be unique (business key)
   - Verify: SELECT VendorCode, COUNT(*) FROM dim_VendorCode
             GROUP BY VendorCode HAVING COUNT(*) > 1

3. **No Blanks:**
   - No NULL or empty string VendorCode values
   - Verify: SELECT * FROM dim_VendorCode
             WHERE VendorCode IS NULL OR VendorCode = ''

4. **Alphabetical Order:**
   - VendorCode should be alphabetically sorted
   - Verify by reviewing sample records

5. **Key Sequence:**
   - VendorCodeKey should be sequential (1, 2, 3, ...)
   - Verify: SELECT MIN(VendorCodeKey), MAX(VendorCodeKey), COUNT(*)
             FROM dim_VendorCode
   - Max should equal Count (no gaps in sequence)

✅ RELATIONSHIP VALIDATION:

After refresh, verify fact table relationships:
```sql
-- Check for orphaned fact records (should return 0 or minimal)
SELECT COUNT(*)
FROM Fact_PartsInventory f
LEFT JOIN dim_VendorCode d ON f.VendorCodeKey = d.VendorCodeKey
WHERE d.VendorCodeKey IS NULL

-- If orphans exist, may need to add Unknown vendor pattern
```

✅ BUSINESS VALIDATION:

Sample expected vendor codes (verify a few exist):
- Check for known major vendor codes from business
- Verify new vendor codes appear if parts added
- Confirm vendor codes match jdis_Part_Information source
- 1,311 codes suggests diverse supplier base (validate expected range)

✅ VENDOR DISTRIBUTION ANALYSIS:

Understand vendor usage patterns:
```sql
-- Top vendors by part count
SELECT
    d.VendorCode,
    COUNT(DISTINCT p.PartNumber) as PartCount,
    SUM(p.QuantityOnHand) as TotalInventory,
    SUM(p.InventoryCost * p.QuantityOnHand) as TotalValue
FROM dim_Parts p
JOIN dim_VendorCode d ON p.VendorCode = d.VendorCode
GROUP BY d.VendorCode
ORDER BY PartCount DESC

-- Vendor concentration analysis
SELECT
    CASE
        WHEN PartCount >= 100 THEN 'Major (100+)'
        WHEN PartCount >= 50 THEN 'Medium (50-99)'
        WHEN PartCount >= 10 THEN 'Small (10-49)'
        ELSE 'Minimal (<10)'
    END as VendorSize,
    COUNT(*) as VendorCount
FROM (
    SELECT d.VendorCode, COUNT(DISTINCT p.PartNumber) as PartCount
    FROM dim_Parts p
    JOIN dim_VendorCode d ON p.VendorCode = d.VendorCode
    GROUP BY d.VendorCode
) vendor_parts
GROUP BY CASE
    WHEN PartCount >= 100 THEN 'Major (100+)'
    WHEN PartCount >= 50 THEN 'Medium (50-99)'
    WHEN PartCount >= 10 THEN 'Small (10-49)'
    ELSE 'Minimal (<10)'
END
```

============================================================================
🚀 DEPLOYMENT NOTES
============================================================================

**Prerequisites:**
1. ✅ jdis_Part_Information must exist in lakehouse
2. ✅ Workspace and Lakehouse IDs must match your environment

**Deployment Steps:**
1. Create df_Dim_VendorCode dataflow with this query
2. Schedule monthly refresh (or add to Reference Data Pipeline)
3. Create relationships in Power BI model
4. Verify row count (~1,311 total)

**Scheduling Recommendation:**
- Add to "Reference Data Pipeline" with other reference dimensions
- Suggested time: First Monday of month, 8:00 AM
- Sequence: After jdis_Part_Information, before fact tables
- Group with: dim_SLC, dim_Source, dim_CommodityCode, dim_DealerGroupCode (parts dimension family)

**Refresh Dependencies:**
- Must refresh AFTER: jdis_Part_Information (source)
- Must refresh BEFORE: Any fact tables using VendorCodeKey
- Can refresh IN PARALLEL with: dim_SLC, dim_Source, dim_CommodityCode, dim_DealerGroupCode

**Performance Notes:**
- Simple query pattern - minimal transformations
- No text cleaning (vendor codes are system-generated)
- ~1:30 for 1,311 rows processing distinct from 1M+ parts
- Lightweight and efficient for fact table joins

**Future Enhancement Consideration:**
- Consider adding "Unknown" vendor pattern if needed
- Could add vendor name lookup from vendor master table
- Could add vendor category/type classification
- Could add vendor status (Active/Inactive) flag

============================================================================
📊 SAMPLE OUTPUT
============================================================================

Expected output structure (first few rows):

VendorCodeKey | VendorCode
--------------|------------
1             | V0001
2             | V0002
3             | V0003
...           | ...
1311          | VZZZZ

**Characteristics:**
- 1,311 total rows (distinct vendor codes from parts master)
- VendorCodeKey = 1 to 1,311 (sequential, alphabetically sorted by code)
- No duplicates, no blanks, alphabetically sorted
- Simple two-column structure for efficient joins

============================================================================
🔍 QUERY PATTERN COMPARISON - PARTS DIMENSION FAMILY
============================================================================

**Comparison with similar dimensions:**

All extract distinct values from jdis_Part_Information:
- **dim_SLC** (123 codes) - Has Unknown record pattern (SLCKey=-1)
- **dim_Source** (267 codes) - Has Unknown record pattern (SourceKey=-1)
- **dim_CommodityCode** (780 codes) - Has Unknown record pattern
- **dim_DealerGroupCode** (1,813 codes) - Has Unknown record pattern
- **dim_VendorCode** (1,311 codes) - **NO Unknown record** ⚠️

**Pattern Difference:**
dim_VendorCode is the only parts classification dimension without Unknown record.
This works IF all parts have valid vendor codes. Consider adding Unknown pattern
for consistency and to handle NULL vendors in fact tables.

**To Add Unknown Pattern (Future Enhancement):**
1. Create UnknownVendorCode helper query:
   ```powerquery
   let
       UnknownRecord = #table(
           type table [VendorCodeKey = Int64.Type, VendorCode = text],
           {{-1, "UNKNOWN"}}
       )
   in
       UnknownRecord
   ```

2. After "Reordered columns" step, add:
   ```powerquery
   #"Appended query" = Table.Combine({#"Reordered columns", UnknownVendorCode}),
   #"Sorted rows 1" = Table.Sort(#"Appended query", {{"VendorCodeKey", Order.Ascending}})
   ```

3. Update final step to return #"Sorted rows 1"

============================================================================
📈 BUSINESS INTELLIGENCE OPPORTUNITIES
============================================================================

**Supplier Analytics:**
• Vendor Concentration Risk: Analyze dependency on top vendors
• Vendor Performance: Quality, delivery time, pricing competitiveness
• Vendor Diversification: Identify single-source parts and risks
• Strategic Relationships: Identify key vendor partnerships

**Procurement Optimization:**
• Vendor Consolidation: Identify opportunities to reduce vendor count
• Volume Discounts: Analyze purchasing power with top vendors
• Cost Analysis: Compare pricing across vendors for similar parts
• Sourcing Strategy: Multi-source vs single-source analysis

**Inventory Management:**
• Vendor-Specific Stock Levels: Optimize inventory by supplier
• Lead Time Analysis: Vendor delivery performance tracking
• Order Patterns: Vendor-specific ordering frequency and volumes
• Parts Availability: Vendor reliability and stockout analysis

**Report Recommendations:**
• Vendor Scorecard: Performance metrics by supplier
• Sourcing Strategy Dashboard: Multi-vendor analysis and risks
• Procurement Analytics: Purchasing patterns and opportunities
• Supplier Diversification Report: Dependency and risk assessment

============================================================================
*/
