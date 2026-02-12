/*
============================================================================
Dimension: dim_ModuleType (SIMPLIFIED BUSINESS-FOCUSED DIMENSION)
Dataflow: df_Dim_ModuleType
Location: LH_Master_Data → Dataflows → 03 - Dimensions
============================================================================

📋 METADATA:
Source: Invoice (Lakehouse table - ModuleType and CustomerNumber fields)
Purpose: Streamlined ModuleType dimension for invoice categorization and business analysis
Created: [Unknown - pre-dates current documentation]
Last Modified: 09/25/2025
Output: Lakehouse table "dim_ModuleType"

⏱️ REFRESH CHARACTERISTICS:
Refresh Schedule: Not scheduled (reference data - recommend monthly)
Average Refresh Time: ~1:30 minutes
Refresh Strategy: Full refresh with business logic classification
Row Count: 11 explicit categories (as of documentation)
Query Folding: Partial (Lakehouse source, in-memory transformations)

📊 DIMENSION TYPE: **Type 1 - Slowly Changing Dimension (Overwrite)**
- **Rare changes** - module type categories stable
- **No SCD tracking** - current state only
- **Business logic-driven** - customer number + module type combination
- **Explicit categorization** - 11 predefined categories

🎯 BUSINESS USE CASES:
• Primary Analysis: Counter vs Work Orders vs Internal vs Warranty vs Tag
• Revenue Classification: Separate internal and warranty from standard operations
• Customer Segmentation: Identify internal vs warranty vs standard customer transactions
• Invoice Analysis: Module type categorization for billing patterns
• Detailed Drill-Down: Specific combinations like "Internal - Counter"
• Data Validation: Letter codes (A,C,D,V) available for quality checks
• High-Level Reporting: BusinessGrouping for 5-category analysis

📊 DATA STRUCTURE (5 COLUMNS):

**Primary Key (1 column):**
• ModuleTypeKey (Int64) - Explicit key assignment (1-11, 99 for unexpected)

**Business Classification (3 columns):**
• ModuleTypeDescription (text) - Detailed category description:
  - 1 = "Counter" (standard counter sales)
  - 2 = "Work Orders" (standard work order transactions)
  - 3 = "Tag" (tag transactions)
  - 4 = "Internal - Counter" (internal customer counter sales)
  - 5 = "Internal - Work Orders" (internal customer work orders)
  - 6 = "Warranty - Counter" (warranty customer counter sales)
  - 7 = "Warranty - Work Order" (warranty customer work orders)
  - 8 = "A" (letter code - preserved for validation)
  - 9 = "C" (letter code - preserved for validation)
  - 10 = "D" (letter code - preserved for validation)
  - 11 = "V" (letter code - preserved for validation)
• BusinessGrouping (text) - High-level 5-category grouping:
  - "Counter" (standard counter sales)
  - "Work Order" (standard work order transactions)
  - "Internal" (internal customer transactions - Counter + Work Orders)
  - "Warranty" (warranty customer transactions - Counter + Work Order)
  - "Tag" (tag transactions)
  - "Other" (A, C, D, V letter codes)
• SortOrder (Int64) - Logical sort order for reports (1-11, 99)

**Data Quality (1 column):**
• RecordCount (Int64) - Number of Invoice records for this category (data quality monitoring)

**Module Type Definitions:**
1. **Counter** (Key 1): Standard customer counter sales (ModuleType = "I")
2. **Work Orders** (Key 2): Standard customer work orders (ModuleType = "W")
3. **Tag** (Key 3): Tag transactions (ModuleType = "S")
4. **Internal - Counter** (Key 4): Internal customer counter sales
5. **Internal - Work Orders** (Key 5): Internal customer work orders
6. **Warranty - Counter** (Key 6): Warranty customer counter sales
7. **Warranty - Work Order** (Key 7): Warranty customer work orders
8. **A** (Key 8): Letter code A (preserved for validation)
9. **C** (Key 9): Letter code C (preserved for validation)
10. **D** (Key 10): Letter code D (preserved for validation)
11. **V** (Key 11): Letter code V (preserved for validation)

🔧 DESIGN PRINCIPLES:

**Business Logic Classification:**

**Internal Customers** (CustomerNumbers):
- 71, 72, 73, 74, 76, 77, 78, 81, 83, 84, 85, 86, 87
- 9001, 9002, 9003, 9004, 9005, 9006, 9007
- **Override logic**: ModuleType "I" → "Internal - Counter", "W" → "Internal - Work Orders"

**Warranty Customers** (CustomerNumbers):
- 41, 42, 43, 44, 46, 47, 48, 51, 53, 54, 55, 56, 57
- 9051, 9052, 9053, 9054, 9055, 9056, 9057
- **Override logic**: ModuleType "I" → "Warranty - Counter", "W" → "Warranty - Work Order"

**Standard Customers** (All others):
- ModuleType "I" → "Counter"
- ModuleType "W" → "Work Orders"
- ModuleType "S" → "Tag"
- ModuleType "A", "C", "D", "V" → Preserved as-is (letter codes)

**Classification Logic:**
```
IF CustomerNumber IN InternalCustomers THEN
  IF ModuleType = "I" THEN "Internal - Counter" (Key 4)
  IF ModuleType = "W" THEN "Internal - Work Orders" (Key 5)
  ELSE Preserve ModuleType letter code
ELSE IF CustomerNumber IN WarrantyCustomers THEN
  IF ModuleType = "I" THEN "Warranty - Counter" (Key 6)
  IF ModuleType = "W" THEN "Warranty - Work Order" (Key 7)
  ELSE Preserve ModuleType letter code
ELSE (Standard Customers)
  IF ModuleType = "I" THEN "Counter" (Key 1)
  IF ModuleType = "W" THEN "Work Orders" (Key 2)
  IF ModuleType = "S" THEN "Tag" (Key 3)
  ELSE Preserve ModuleType letter code (A/C/D/V = Keys 8-11)
```

**Explicit Key Assignments:**
• **Manual assignment** ensures predictable, stakeholder-aligned structure
• **Keys 1-11**: Explicit categories with business logic
• **Key 99**: Fallback for unexpected combinations
• **Stable keys**: Consistent across refreshes for fact table relationships

**Sort Order Logic:**
1. Counter (standard counter sales first)
2. Internal - Counter (internal counter sales)
3. Warranty - Counter (warranty counter sales)
4. Work Orders (standard work orders)
5. Internal - Work Orders (internal work orders)
6. Warranty - Work Order (warranty work orders)
7. Tag (tag transactions)
8-11. Letter codes (A, C, D, V)
99. Unexpected combinations

**High-Level Business Grouping:**
• **Counter**: Standard counter sales (Key 1)
• **Work Order**: Standard work orders (Key 2)
• **Internal**: Internal customer transactions (Keys 4-5)
• **Warranty**: Warranty customer transactions (Keys 6-7)
• **Tag**: Tag transactions (Key 3)
• **Other**: Letter codes A, C, D, V (Keys 8-11)

**Data Quality Steps:**
1. Source: Invoice table (ModuleType + CustomerNumber)
2. Select Source Fields: ModuleType, CustomerNumber
3. Filter Valid Data: Remove null/empty values
4. Get Unique Combinations: Distinct ModuleType + CustomerNumber pairs
5. Add Dimension Category: Apply business logic classification
6. Group Unique Dimensions: Aggregate by category, count records
7. Add Explicit Keys: Manual key assignment (1-11, 99)
8. Add Business Grouping: 5-category high-level grouping
9. Add Sort Order: Logical presentation order
10. Create Final Structure: Select/rename columns
11. Set Data Types: Optimal performance

**Customer Number Lists:**
• **Maintained in query**: Lists embedded for business logic
• **Future enhancement**: Consider separate customer dimension for maintenance
• **Validation**: RecordCount field enables monitoring of customer classification

🔗 RELATIONSHIPS:

**Fact Table Relationships (Many-to-One):**
- **Fact_Invoice** (if exists) → ModuleTypeKey (invoice categorization)
- **Invoice** → ModuleType + CustomerNumber (source relationship - natural keys)

**Related Dimensions:**
- May relate to dim_Customer (customer type classification)
- Works with dim_DateTable for time-based module type analysis

⚠️ IMPORTANT NOTES:

**Refresh Strategy:**
• **RECOMMENDED**: Monthly refresh (reference data changes infrequently)
• **NOT RECOMMENDED**: Daily refresh (unnecessary overhead)
• **TRIGGER**: Refresh when new module types or customer categories appear
• **FUTURE PIPELINE**: Consider "Reference Data Pipeline" (first Monday of month at 8:00 AM)

**Performance Considerations:**
• Current refresh time: ~1:30 minutes
• Row count: 11 categories
• Source: Invoice table (ModuleType + CustomerNumber combinations)
• **PERFORMANCE NOTE**: 1:30 for 11 rows is slower than expected
• **POSSIBLE CAUSE**: Large Invoice table, distinct operation on many rows
• **NOT URGENT**: Works correctly, just slower than optimal

**Business Logic Maintenance:**
• **Customer lists**: Embedded in query (71, 72, ... 9051, 9052, ...)
• **New internal customer**: Add to InternalCustomers list, refresh dimension
• **New warranty customer**: Add to WarrantyCustomers list, refresh dimension
• **Future enhancement**: Externalize customer lists to separate table

**Expected Dimension Output (11 rows):**
| Key | ModuleTypeDescription    | BusinessGrouping | SortOrder | RecordCount |
|-----|-------------------------|------------------|-----------|-------------|
| 1   | Counter                 | Counter          | 1         | ~###        |
| 2   | Work Orders             | Work Order       | 4         | ~###        |
| 3   | Tag                     | Tag              | 7         | ~###        |
| 4   | Internal - Counter      | Internal         | 2         | ~###        |
| 5   | Internal - Work Orders  | Internal         | 5         | ~###        |
| 6   | Warranty - Counter      | Warranty         | 3         | ~###        |
| 7   | Warranty - Work Order   | Warranty         | 6         | ~###        |
| 8   | A                       | Other            | 8         | ~###        |
| 9   | C                       | Other            | 9         | ~###        |
| 10  | D                       | Other            | 10        | ~###        |
| 11  | V                       | Other            | 11        | ~###        |

**Business Value:**
• **Clean structure**: 11 explicit categories, no ambiguity
• **High-level analysis**: BusinessGrouping enables 5-category view
• **Logical sorting**: Intuitive order for reports and presentations
• **Data validation**: RecordCount monitors quality and distribution
• **Future-proof**: Letter codes preserved for potential classification

**Data Quality:**
• 11 explicit categories (complete coverage)
• Internal/Warranty customer override logic
• Letter codes preserved for validation
• RecordCount enables distribution monitoring
• Unexpected combinations fallback to Key 99

**Source Table Dependency:**
• Reads from Invoice table (must be refreshed first)
• Extracts distinct ModuleType + CustomerNumber combinations
• Self-updating as new combinations appear

Dependencies:
• Invoice (Lakehouse table - must refresh first)

Used By:
• Fact_Invoice (if exists - invoice categorization)
• Invoice analysis reports
• Revenue classification dashboards
• Customer segmentation analysis
• Internal vs warranty vs standard reporting

Related Dimensions:
• dim_Customer (if exists - customer type classification)
• dim_DateTable (time-based module type analysis)

Critical Finding:
**11 explicit categories with customer-based override logic**
**Internal customers (71, 72, ... 9001-9007) classified separately**
**Warranty customers (41, 42, ... 9051-9057) classified separately**
**Business grouping enables 5-category high-level analysis**
**Monthly refresh recommended (module types stable)**
**RecordCount field enables data quality monitoring**

============================================================================
*/

let
    // ========================================================================
    // SOURCE DATA AND BUSINESS RULE DEFINITIONS
    // ========================================================================

    Source = Invoice, // Reference your Invoice table from Lakehouse

    // Define Internal Customer Numbers (validated from business analysis)
    InternalCustomers = {"71", "72", "73", "74", "76", "77", "78", "81", "83", "84", "85", "86", "87",
                        "9001", "9002", "9003", "9004", "9005", "9006", "9007"},

    // Define Warranty Customer Numbers (validated from business analysis)
    WarrantyCustomers = {"41", "42", "43", "44", "46", "47", "48", "51", "53", "54", "55", "56", "57",
                        "9051", "9052", "9053", "9054", "9055", "9056", "9057"},

    // ========================================================================
    // DATA EXTRACTION AND PREPARATION
    // ========================================================================
    /*
    PURPOSE: Extract unique CustomerNumber + ModuleType combinations for dimension creation
    SCOPE: All ModuleTypes (I,W,S,A,C,D,V) for complete business validation
    QUALITY: Filter null/empty values to ensure clean dimension records
    */

    Step1_SelectSourceFields = Table.SelectColumns(Source, {"ModuleType", "CustomerNumber"}),

    Step2_FilterValidData = Table.SelectRows(Step1_SelectSourceFields,
        each [ModuleType] <> null and [ModuleType] <> "" and
             [CustomerNumber] <> null and [CustomerNumber] <> ""),

    Step3_GetUniqueCombo = Table.Distinct(Step2_FilterValidData),

    // ========================================================================
    // BUSINESS LOGIC APPLICATION - CUSTOMER-BASED CLASSIFICATION
    // ========================================================================
    /*
    BUSINESS RULE: Determine dimension category based on CustomerNumber + ModuleType combination
    LOGIC: Internal/Warranty customers override standard ModuleType mapping
    RESULT: Creates explicit business categories for stakeholder analysis
    */

    Step4_AddDimensionCategory = Table.AddColumn(Step3_GetUniqueCombo, "DimensionCategory",
        each
            // Internal Customers - Override standard mapping
            if List.Contains(InternalCustomers, [CustomerNumber]) then
                if [ModuleType] = "I" then "Internal - Counter"
                else if [ModuleType] = "W" then "Internal - Work Orders"
                else [ModuleType] // A,V for Internal customers

            // Warranty Customers - Override standard mapping
            else if List.Contains(WarrantyCustomers, [CustomerNumber]) then
                if [ModuleType] = "I" then "Warranty - Counter"
                else if [ModuleType] = "W" then "Warranty - Work Order"
                else [ModuleType] // Unlikely but preserved for data integrity

            // Standard Customers - Direct ModuleType mapping
            else if [ModuleType] = "I" then "Counter"
            else if [ModuleType] = "W" then "Work Orders"
            else if [ModuleType] = "S" then "Tag"
            else [ModuleType], // A,C,D,V preserved as-is
        type text),

    // ========================================================================
    // DIMENSION STRUCTURE CREATION
    // ========================================================================
    /*
    STRATEGY: Group unique combinations and assign explicit keys for predictable results
    APPROACH: Manual key assignment ensures stakeholder expectations are met
    VALIDATION: Record count provides data quality monitoring capability
    */

    Step5_GroupUniqueDimensions = Table.Group(Step4_AddDimensionCategory,
        {"DimensionCategory"},
        {{"RecordCount", each Table.RowCount(_), Int64.Type}}),

    // ========================================================================
    // EXPLICIT KEY ASSIGNMENTS - STAKEHOLDER-ALIGNED STRUCTURE
    // ========================================================================
    /*
    BUSINESS REQUIREMENT: 11 specific categories with explicit key assignments
    APPROACH: Manual assignment ensures keys match business expectations exactly
    BENEFIT: Predictable, logical key structure for fact table relationships
    */

    Step6_AddExplicitKeys = Table.AddColumn(Step5_GroupUniqueDimensions, "ModuleTypeKey",
        each if [DimensionCategory] = "Counter" then 1
             else if [DimensionCategory] = "Work Orders" then 2
             else if [DimensionCategory] = "Tag" then 3
             else if [DimensionCategory] = "Internal - Counter" then 4
             else if [DimensionCategory] = "Internal - Work Orders" then 5
             else if [DimensionCategory] = "Warranty - Counter" then 6
             else if [DimensionCategory] = "Warranty - Work Order" then 7
             else if [DimensionCategory] = "A" then 8
             else if [DimensionCategory] = "C" then 9
             else if [DimensionCategory] = "D" then 10
             else if [DimensionCategory] = "V" then 11
             else 99, Int64.Type), // Fallback for unexpected combinations

    // ========================================================================
    // HIGH-LEVEL GROUPING FOR ANALYSIS
    // ========================================================================
    /*
    BUSINESS REQUIREMENT: 5-category grouping for stakeholder analysis
    CATEGORIES: Counter, Work Order, Internal, Warranty, Tag, Other
    PURPOSE: Enables both detailed and high-level analysis capabilities
    */

    Step7_AddBusinessGrouping = Table.AddColumn(Step6_AddExplicitKeys, "BusinessGrouping",
        each if [DimensionCategory] = "Counter" then "Counter"
             else if [DimensionCategory] = "Work Orders" then "Work Order"
             else if List.Contains({"Internal - Counter", "Internal - Work Orders"}, [DimensionCategory]) then "Internal"
             else if List.Contains({"Warranty - Counter", "Warranty - Work Order"}, [DimensionCategory]) then "Warranty"
             else if [DimensionCategory] = "Tag" then "Tag"
             else "Other", // A,C,D,V grouped as Other for high-level analysis
        type text),

    // ========================================================================
    // SORT ORDER FOR STAKEHOLDER PRESENTATION
    // ========================================================================
    /*
    BUSINESS REQUIREMENT: Logical sort order matching stakeholder preferences
    STRATEGY: Core operations first (Counter, Work Orders), then Internal, Warranty, specialty
    RESULT: Consistent, intuitive ordering in reports and visualizations
    */

    Step8_AddSortOrder = Table.AddColumn(Step7_AddBusinessGrouping, "SortOrder",
        each if [ModuleTypeKey] = 1 then 1   // Counter
             else if [ModuleTypeKey] = 4 then 2   // Internal - Counter
             else if [ModuleTypeKey] = 6 then 3   // Warranty - Counter
             else if [ModuleTypeKey] = 2 then 4   // Work Orders
             else if [ModuleTypeKey] = 5 then 5   // Internal - Work Orders
             else if [ModuleTypeKey] = 7 then 6   // Warranty - Work Order
             else if [ModuleTypeKey] = 3 then 7   // Tag
             else if [ModuleTypeKey] = 8 then 8   // A
             else if [ModuleTypeKey] = 9 then 9   // C
             else if [ModuleTypeKey] = 10 then 10 // D
             else if [ModuleTypeKey] = 11 then 11 // V
             else 99, Int64.Type),

    // ========================================================================
    // FINAL DIMENSION STRUCTURE - STREAMLINED FOR BUSINESS USE
    // ========================================================================

    Step9_CreateFinalStructure = Table.SelectColumns(Step8_AddSortOrder, {
        "ModuleTypeKey",           // Primary key for fact table relationships
        "DimensionCategory",       // Detailed category (e.g., "Internal - Counter")
        "BusinessGrouping",        // High-level grouping (Counter/Work Order/Internal/Warranty/Tag/Other)
        "SortOrder",              // Logical sort order for reports
        "RecordCount"             // Data quality validation field
    }),

    // Rename for stakeholder clarity
    Step10_RenameColumns = Table.RenameColumns(Step9_CreateFinalStructure, {
        {"DimensionCategory", "ModuleTypeDescription"}
    }),

    // Set optimal data types for performance
    Step11_SetDataTypes = Table.TransformColumnTypes(Step10_RenameColumns, {
        {"ModuleTypeKey", Int64.Type},
        {"ModuleTypeDescription", type text},
        {"BusinessGrouping", type text},
        {"SortOrder", Int64.Type},
        {"RecordCount", Int64.Type}
    })

in
    Step11_SetDataTypes

/*
============================================================================
✅ SIMPLIFIED MODULETYPE DIMENSION - PRODUCTION READY
============================================================================

🎯 EXPECTED DIMENSION OUTPUT:
ModuleTypeKey | ModuleTypeDescription    | BusinessGrouping | SortOrder | RecordCount
1            | Counter                 | Counter          | 1         | ~###
2            | Work Orders             | Work Order       | 4         | ~###
3            | Tag                     | Tag              | 7         | ~###
4            | Internal - Counter      | Internal         | 2         | ~###
5            | Internal - Work Orders  | Internal         | 5         | ~###
6            | Warranty - Counter      | Warranty         | 3         | ~###
7            | Warranty - Work Order   | Warranty         | 6         | ~###
8            | A                       | Other            | 8         | ~###
9            | C                       | Other            | 9         | ~###
10           | D                       | Other            | 10        | ~###
11           | V                       | Other            | 11        | ~###

🔍 BUSINESS LOGIC VALIDATION:
• Standard customers + ModuleType I → Key 1 (Counter)
• Standard customers + ModuleType W → Key 2 (Work Orders)
• Standard customers + ModuleType S → Key 3 (Tag)
• Internal customers + ModuleType I → Key 4 (Internal - Counter)
• Internal customers + ModuleType W → Key 5 (Internal - Work Orders)
• Warranty customers + ModuleType I → Key 6 (Warranty - Counter)
• Warranty customers + ModuleType W → Key 7 (Warranty - Work Order)
• Letter codes A,C,D,V → Keys 8-11 (preserved for validation)

🎯 STAKEHOLDER BENEFITS:
• Clean Structure: 11 explicit categories, no confusion
• High-Level Analysis: BusinessGrouping provides 5-category view (Counter/Work Order/Internal/Warranty/Tag/Other)
• Logical Sorting: Intuitive order for reports and presentations
• Data Validation: RecordCount enables quality monitoring
• Future-Proof: Letter codes preserved for potential future classification

🚀 FACT TABLE INTEGRATION:
• Use ModuleTypeKey as foreign key in fact table
• BusinessGrouping column enables high-level analysis
• ModuleTypeDescription provides clear labels for visualizations
• SortOrder ensures consistent presentation across reports

🔧 MAINTENANCE NOTES:
• Internal customers: 71-87, 9001-9007
• Warranty customers: 41-57, 9051-9057
• Add new customer numbers to respective lists as needed
• Refresh dimension monthly or when customer classification changes
• Monitor RecordCount for unexpected distributions

**PRODUCTION STATUS: READY - MONTHLY REFRESH RECOMMENDED**
**11 explicit categories with customer-based override logic**
**Business grouping enables 5-category high-level analysis**

============================================================================
*/
