# Power Query Documentation Header Templates

Use these templates at the top of your Power Query (.pq) files for consistent documentation.

---

## Template 1: Fact Table Header

```powerquery
/*
============================================================================
FACT_[TABLE_NAME] - [BRIEF PURPOSE]
============================================================================

📋 TABLE OVERVIEW:
Purpose: [Detailed description of what this fact table tracks]
Grain: [One row per what? E.g., "One row per transaction per part per date"]
Refresh Strategy: [Full | Incremental | Watermark-based]
Performance: [Target refresh time]
Source Dependencies: [List of raw tables and dimensions used]

🎯 BUSINESS USE CASES:
• [Use case 1]: [Description]
• [Use case 2]: [Description]
• [Use case 3]: [Description]

📊 DATA STRUCTURE ([X] COLUMNS):

**Business Keys (Grain Columns):**
• [Column1]: [Description and purpose]
• [Column2]: [Description and purpose]

**Dimension Foreign Keys:**
• DateKey: Links to dim_DateTable for time analysis
• BranchKey: Links to dim_BranchLocation for location filtering
• [OtherKey]: Links to dim_[Name] for [purpose]

**Measures (Numeric Facts):**
• [Measure1]: [What it measures]
• [Measure2]: [What it measures]

**Descriptive Attributes:**
• [Attribute1]: [Description]
• [Attribute2]: [Description]

🔧 DESIGN APPROACH:

**Source Integration:**
• [Description of how sources are combined]
• [Any filtering or business rules applied]

**Data Quality:**
• [Quality checks performed]
• [Null handling strategy]
• [Duplicate prevention]

**Performance Optimization:**
• [Optimization techniques used]
• [Why these choices were made]

🔄 REFRESH CHARACTERISTICS:
Row Count: [X] rows ([X]M+ total, [description])
Avg Refresh Time: [X] minutes
Refresh Schedule: [Daily/Weekly/etc.] at [time]
Last Modified: [MM/DD/YYYY]
Created: [MM/DD/YYYY]

🔗 RELATIONSHIPS:
Related Dimensions:
• dim_DateTable (via DateKey)
• dim_BranchLocation (via BranchKey)
• [Other dimensions]

Related Fact Tables:
• [If this fact relates to other facts]

Used In Reports:
• [Report Name 1]
• [Report Name 2]

============================================================================
*/

let
    // ========================================================================
    // STEP 1: [DESCRIPTION]
    // ========================================================================
    /*
    PURPOSE: [Why this step exists]
    LOGIC: [What it does]
    */

    Source = [Your query here],

    // ========================================================================
    // STEP 2: [DESCRIPTION]
    // ========================================================================
    /*
    PURPOSE: [Why this step exists]
    LOGIC: [What it does]
    */

    NextStep = [Transformation here]

in
    NextStep

/*
============================================================================
✅ VALIDATION & TESTING
============================================================================

**Post-Refresh Validation:**

1. **Row Count Check:**
   - Expected range: [X-Y] rows
   - Verify: SELECT COUNT(*) FROM Fact_[Name]

2. **Date Range Check:**
   - Should include: [date range logic]
   - Verify: SELECT MIN(Date), MAX(Date) FROM Fact_[Name]

3. **Key Totals:**
   - [Measure] should approximately equal: [expected value/range]
   - Cross-reference with [source system]

4. **Grain Validation:**
   - Check for duplicates on grain columns
   - Verify: SELECT [GrainCols], COUNT(*) GROUP BY [GrainCols] HAVING COUNT(*) > 1

**Business Validation:**
- [Specific business rule to verify]
- [Another business rule to verify]

============================================================================
🚀 DEPLOYMENT NOTES
============================================================================

**Prerequisites:**
1. ✅ [Raw table X] must be refreshed first
2. ✅ [Dimension Y] must exist
3. ✅ [Other dependency]

**Deployment Steps:**
1. Create df_Fact_[Name] dataflow with this query
2. Schedule refresh: [Time and frequency]
3. Create relationships in Power BI model
4. Verify row count and key metrics

**Refresh Dependencies:**
- Must refresh AFTER: [Raw tables, dimensions]
- Must refresh BEFORE: [Semantic model, other dependent facts]
- Can refresh IN PARALLEL with: [Other facts if any]

============================================================================
*/
```

---

## Template 2: Dimension Table Header

```powerquery
/*
============================================================================
DIM_[NAME] - [BRIEF PURPOSE]
============================================================================

📋 METADATA:
Table Name: dim_[Name]
Dataflow: df_Dim_[Name]
Purpose: [What this dimension provides]
Grain: One row per [unique entity]
Last Modified: [MM/DD/YYYY]

🔄 REFRESH CHARACTERISTICS:
Row Count: [X] rows
Avg Refresh Time: [X] minutes
Refresh Schedule: [Daily | Monthly | On-demand]
Refresh Strategy: [Full | Incremental]
Source Table: [Source name]

📊 DIMENSION TYPE: Type [0|1|2] ([Static|Overwrite|History])
Changes: [How dimension handles changes]
History: [Historical tracking approach]
Updates: [Update strategy]

🎯 BUSINESS USE CASES:
• [Use case 1]
• [Use case 2]
• [Use case 3]

📊 DATA STRUCTURE ([X] Columns):

**Primary Key:**
• [Name]Key: Surrogate key (1, 2, 3, ...)

**Business Keys:**
• [BusinessKey]: Natural key from source system

**Descriptive Attributes:**
• [Attribute1]: [Description]
• [Attribute2]: [Description]

**Calculated Attributes:**
• [Calculated1]: [How it's calculated and why]
• [Calculated2]: [How it's calculated and why]

🔧 DESIGN PRINCIPLES:
[Explain the design approach and key decisions]

🔗 RELATIONSHIPS:
Related Fact Tables:
• [Fact1] → dim_[Name] (via [Key])
• [Fact2] → dim_[Name] (via [Key])

Related Dimensions:
• [Other dimensions this relates to]

============================================================================
*/

let
    Source = [Query here]
in
    Source

/*
============================================================================
✅ VALIDATION & TESTING
============================================================================

**Post-Refresh Validation:**

1. Row Count: Should have ~[X] rows
2. No Duplicates: Primary key must be unique
3. No Blanks: Critical attributes checked
4. Business Validation: [Specific checks]

============================================================================
*/
```

---

## Template 3: Raw Table Header

```powerquery
/*
============================================================================
RAW_[TABLE_NAME] - [BRIEF PURPOSE]
============================================================================

📋 TABLE OVERVIEW:
Purpose: [What data this extracts]
Grain: [One row per what]
Refresh Strategy: [Full | Incremental | Watermark-based]
Performance: [Target refresh time]
Source Dependencies: [SQL Server table, API, etc.]

🎯 BUSINESS USE CASES:
• [Use case 1]
• [Use case 2]

📊 DATA STRUCTURE ([X] COLUMNS):
[List key columns and their purposes]

🔧 DESIGN APPROACH:
[Explain extraction strategy]

⚠️ [Any performance notes or warnings]

🔄 REFRESH CHARACTERISTICS:
Row Count: [X] rows
Avg Refresh Time: [X] minutes
Refresh Schedule: [Schedule details]
Last Modified: [MM/DD/YYYY]
Created: [MM/DD/YYYY]

🔗 FACT TABLE DEPENDENCIES:
Used By:
• [Fact1]
• [Fact2]

============================================================================
*/

let
    Source = [Query here]
in
    Source
```

---

## Template 4: Helper Query Header

```powerquery
/*
============================================================================
HELPER: [NAME] - [BRIEF PURPOSE]
============================================================================

PURPOSE: [What this helper query provides]
TYPE: [Parameter | Reference table | Function | Watermark]
USED BY: [List queries that reference this]

USAGE EXAMPLE:
[Show how to use this helper]

============================================================================
*/

let
    Result = [Query here]
in
    Result
```

---

## Best Practices for Query Documentation

### **Header Comments:**
- Always include purpose and business context
- Document the grain clearly
- List dependencies (what must run first)
- Include validation queries

### **Inline Comments:**
- Explain WHY, not just WHAT
- Document business rules
- Explain complex transformations
- Note performance considerations

### **Step Naming:**
- Use descriptive step names (not "Changed Type 1", "Changed Type 2")
- Good: `FilterToActiveBranches`, `AddCalculatedMargin`, `RemoveDuplicateTransactions`
- Bad: `Table.SelectRows`, `Table.AddColumn`, `Table.Distinct`

### **Validation:**
- Always include post-refresh validation queries
- Document expected row counts and ranges
- List key business rules to verify
- Include troubleshooting tips

---

## When to Use Each Template

| Template | Use For | Example |
|----------|---------|---------|
| **Fact Table** | Transaction data, metrics, measurements | Fact_PartsInventory, Fact_WorkOrderParts |
| **Dimension** | Reference data, lookups, classifications | dim_BranchLocation, dim_Parts |
| **Raw Table** | Data extraction from sources | Raw_InTrans_Incremental, Raw_WKROFILE |
| **Helper** | Parameters, functions, watermarks | GetWatermark, UnknownCustomer |
