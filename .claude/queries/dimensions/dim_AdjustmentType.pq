/*
============================================================================
Dimension: dim_AdjustmentType
Dataflow: df_Dim_AdjustmentType
Location: LH_Master_Data → Dataflows → 03 - Dimensions
============================================================================

📋 METADATA:
Source: Static/hard-coded dimension (based on GlTrans.SubAccount values)
Purpose: Parts adjustment type classification for inventory reconciliation
Created: [Unknown - pre-dates current documentation]
Last Modified: 12/23/2025
Output: Lakehouse table "dim_AdjustmentType"

⏱️ REFRESH CHARACTERISTICS:
Refresh Schedule: Not scheduled (static/reference data)
Average Refresh Time: ~1 minute
Refresh Strategy: Full refresh (hard-coded table)
Row Count: 7 rows (as of 1/14/2026)
Query Folding: N/A (in-memory table creation)

📊 DIMENSION TYPE: **Type 0 - Static Dimension**
- **No changes expected** - hard-coded lookup values
- **No SCD tracking** - values are permanent
- **Manual updates only** - add new types as business requires

🎯 BUSINESS USE CASES:
• Parts Inventory Adjustments: Classify why inventory quantities were adjusted
• Stock Reconciliation: Track physical count adjustments vs system
• Loss Prevention: Identify damaged or lost parts
• Customer Bin Management: Track customer-owned inventory adjustments
• Audit Trail: Provide context for GL adjustments via SubAccount classification

📊 DATA STRUCTURE (5 COLUMNS):

**Surrogate Key:**
• AdjustmentTypeKey (Int64) - Matches GlTrans.SubAccount values (1-6, 0=Unknown)

**Descriptive Attributes:**
• AdjustmentTypeName (text) - Short display name ("Stock Check", "Damaged", etc.)
• AdjustmentTypeDescription (text) - Full business description
• SortOrder (Int64) - Display order for reports and visuals
• IsActive (logical) - Whether type is currently in use (all true currently)

**Adjustment Types:**
1. **Stock Check** - Physical inventory count adjustments to match actual quantities
2. **Customer BIN** - Customer-owned inventory bins
3. **Damaged** - Parts written down/off due to damage
4. **Lost** - Parts written off due to loss or theft
5. **Overage** - Surplus inventory found during reconciliation
6. **Count Off** - Inventory count discrepancies
0. **Unknown** - Not classified or missing SubAccount mapping

🔧 DESIGN PRINCIPLES:

**Static Dimension Pattern:**
• Created entirely in Power Query using #table() function
• No source system dependency
• Values derived from GlTrans.SubAccount domain knowledge
• Type 0 dimension (no historical tracking needed)

**Key Matching Strategy:**
• AdjustmentTypeKey matches GlTrans.SubAccount directly
• 0 = "Unknown" handles NULL or unmapped values
• 1-6 represent specific business adjustment categories

**Extensibility:**
• Easy to add new adjustment types as business needs evolve
• Can add attributes: Color coding, GL account mapping, approval requirements
• IsActive flag allows for future deprecation without deleting types

**Sort Order Logic:**
• 1-6: Active adjustment types in business priority order
• 99: Unknown type sorts last in reports

🔗 RELATIONSHIPS:

**Primary Usage:**
- **fact_PartsAdjustments** (Many-to-One)
  - Join: fact.SubAccount = dim.AdjustmentTypeKey
  - Cross-filter direction: Single (dim → fact)
  - Cardinality: Many-to-One

**Related Dimensions:**
- Used in conjunction with dim_Parts for complete adjustment context
- Links to GlTrans for financial impact analysis

⚠️ IMPORTANT NOTES:

**Refresh Strategy:**
• **RECOMMENDED**: Monthly or quarterly refresh (reference data rarely changes)
• **NOT RECOMMENDED**: Daily refresh (unnecessary overhead)
• Static dimension - only refresh when adding new types
• Consider "Reference Data Pipeline" at 8:00 AM first Monday of month

**Maintenance Procedures:**
1. **Adding New Type**: Edit source code to add row with next available key
2. **Deprecating Type**: Set IsActive = false (preserve historical joins)
3. **Modifying Description**: Safe to update - doesn't affect relationships
4. **Changing Key**: NEVER change AdjustmentTypeKey (breaks fact table joins)

**Data Quality:**
• All 7 types currently active (IsActive = true)
• Key 0 reserved for Unknown/unmapped
• Keys 1-6 mapped to specific business categories
• No duplicates or gaps in active keys

**Fact Table Integration:**
• fact_PartsAdjustments.SubAccount must contain values 0-6 or NULL
• NULL SubAccount maps to AdjustmentTypeKey = 0 (Unknown)
• Invalid SubAccount values (7+) should be handled in fact table ETL

Dependencies:
• None (static hard-coded table)

Used By:
• fact_PartsAdjustments (primary fact table)
• Parts inventory adjustment reports
• GL reconciliation analytics

Related Dimensions:
• dim_Parts (what parts were adjusted)
• dim_DateTable (when adjustments occurred)
• dim_BranchLocation (where adjustments occurred)

Critical Finding:
**Perfect candidate for Reference Data Pipeline (monthly/quarterly refresh)**
**No performance concerns - 7 rows, hard-coded, instant refresh**

============================================================================
*/

let
    // ========================================================================
    // STATIC DIMENSION - HARD-CODED LOOKUP TABLE
    // ========================================================================
    /*
    PURPOSE: Classify parts inventory adjustments by type
    STRATEGY: In-memory table creation using #table() function
    MAINTENANCE: Update source code when new adjustment types needed
    */

    // Create the dimension table from scratch
    Source = #table(
        type table [
            AdjustmentTypeKey = Int64.Type,
            AdjustmentTypeName = text,
            AdjustmentTypeDescription = text,
            SortOrder = Int64.Type,
            IsActive = logical
        ],
        {
            {1, "Stock Check", "Physical inventory count adjustments to match actual on-hand quantities", 1, true},
            {2, "Customer BIN", "Adjustments related to customer-owned inventory bins", 2, true},
            {3, "Damaged", "Parts written down or off due to damage", 3, true},
            {4, "Lost", "Parts written off due to loss or theft", 4, true},
            {5, "Overage", "Adjustments for surplus inventory found during reconciliation", 5, true},
            {6, "Count Off", "Adjustments from inventory count discrepancies", 6, true},
            {0, "Unknown", "Adjustment type not classified or missing SubAccount mapping", 99, true}
        }
    )

in
    Source

/*
============================================================================
✅ PRODUCTION STATUS: READY - STATIC DIMENSION
============================================================================

🎯 IMPLEMENTATION SUMMARY:
• Type 0 Dimension: Static lookup, no historical tracking
• 7 Adjustment Types: 6 active categories + Unknown
• Hard-Coded: No source system dependency
• Key Matching: AdjustmentTypeKey = GlTrans.SubAccount

📊 DIMENSION CHARACTERISTICS:
• **Grain**: One row per adjustment type
• **Keys**: Integer surrogate keys (0-6)
• **Attributes**: Name, Description, SortOrder, IsActive
• **SCD Type**: Type 0 (no changes tracked)

🔗 RELATIONSHIP READY:
• **Fact Table**: fact_PartsAdjustments
• **Join Key**: SubAccount (fact) = AdjustmentTypeKey (dim)
• **Cardinality**: Many-to-One
• **Filter Direction**: Single (dim → fact)

⚡ REFRESH STRATEGY:

**RECOMMENDED: Reference Data Pipeline**
• **Schedule**: First Monday of month at 8:00 AM
• **Frequency**: Monthly (or less)
• **Duration**: ~1 minute (instant - hard-coded)
• **Rationale**: Static data rarely changes

**NOT RECOMMENDED: Daily Refresh**
• Unnecessary overhead for static data
• No benefit from frequent refresh
• Save CU capacity for dynamic tables

📝 MAINTENANCE CHECKLIST:

**When Adding New Adjustment Type:**
1. ✅ Assign next available AdjustmentTypeKey (7, 8, etc.)
2. ✅ Add descriptive AdjustmentTypeName
3. ✅ Write clear AdjustmentTypeDescription
4. ✅ Set appropriate SortOrder
5. ✅ Set IsActive = true
6. ✅ Refresh dataflow
7. ✅ Verify fact table relationships still work

**When Deprecating Type:**
1. ✅ Set IsActive = false (preserve historical joins)
2. ✅ Do NOT delete row (breaks fact table history)
3. ✅ Update SortOrder to 99 if needed (sort to bottom)

**NEVER:**
❌ Change AdjustmentTypeKey of existing row (breaks fact joins)
❌ Delete rows (breaks historical fact data)
❌ Duplicate keys (violates dimension integrity)

============================================================================
*/
