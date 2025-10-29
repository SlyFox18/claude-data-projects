/*
============================================================================
DIM_MODULETYPE - SIMPLIFIED BUSINESS-FOCUSED DIMENSION
============================================================================

📋 DIMENSION OVERVIEW:
Purpose: Create streamlined ModuleType dimension for stakeholder analysis
Grain: One row per business-relevant ModuleType combination
Source: Invoice table from Lakehouse
Focus: 11 explicit categories with clear business logic

🎯 BUSINESS REQUIREMENTS:
• I = Counter, W = Work Orders, S = Tag (core business operations)
• Internal = CustomerNumbers: 71,72,73,74,76,77,78,81,83,84,85,86,87,9001-9007
• Warranty = CustomerNumbers: 41,42,43,44,46,47,48,51,53,54,55,56,57,9051-9057
• Letter Codes A,C,D,V = Preserved for validation and future classification

📊 SIMPLIFIED STRUCTURE:
• 11 explicit categories with predictable key assignments
• 5-category grouping for high-level analysis: Counter/Work Order/Internal/Warranty/Tag/Other
• Clean naming convention aligned with stakeholder expectations

🎯 BUSINESS USE CASES:
• Primary Analysis: Counter vs Work Orders vs Internal vs Warranty vs Tag
• Detailed Drill-Down: Specific combinations like "Internal - Counter"
• Validation: Letter codes A,C,D,V available for data quality checks
• Reporting: Logical grouping and sort order for consistent presentation

============================================================================
*/

let
    // ========================================================================
    // SOURCE DATA AND BUSINESS RULE DEFINITIONS
    // ========================================================================
    
    Source = Invoice, // Reference your Invoice table from Lakehouse
    
    // Define Internal Customer Numbers (validated from your Query 1B results)
    InternalCustomers = {"71", "72", "73", "74", "76", "77", "78", "81", "83", "84", "85", "86", "87", 
                        "9001", "9002", "9003", "9004", "9005", "9006", "9007"},
    
    // Define Warranty Customer Numbers (validated from your Query 1B results)  
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
ModuleTypeKey | ModuleTypeDescription  | BusinessGrouping | SortOrder | RecordCount
1            | Counter               | Counter          | 1         | ~###
2            | Work Orders           | Work Order       | 4         | ~###  
3            | Tag                   | Tag              | 7         | ~###
4            | Internal - Counter    | Internal         | 2         | ~###
5            | Internal - Work Orders| Internal         | 5         | ~###
6            | Warranty - Counter    | Warranty         | 3         | ~###
7            | Warranty - Work Order | Warranty         | 6         | ~###
8            | A                     | Other            | 8         | ~###
9            | C                     | Other            | 9         | ~###
10           | D                     | Other            | 10        | ~###
11           | V                     | Other            | 11        | ~###

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
• High-Level Analysis: BusinessGrouping provides 5-category view
• Logical Sorting: Intuitive order for reports and presentations
• Data Validation: RecordCount enables quality monitoring
• Future-Proof: Letter codes preserved for potential future classification

🚀 FACT TABLE INTEGRATION:
• Use ModuleTypeKey as foreign key in fact table
• BusinessGrouping column enables high-level analysis
• ModuleTypeDescription provides clear labels for visualizations
• SortOrder ensures consistent presentation across reports

🔧 NEXT STEPS:
1. Implement this dimension query in your dataflow
2. Validate the 11 expected categories are created correctly
3. Verify Internal/Warranty customer logic using RecordCount field
4. Proceed to fact table alignment using identical business logic
5. Test specific customer examples to confirm key assignments

============================================================================
*/