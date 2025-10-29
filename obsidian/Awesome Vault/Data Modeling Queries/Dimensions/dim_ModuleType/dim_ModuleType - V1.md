/*
============================================================================
DIM_MODULETYPE - HIERARCHICAL MODULE TYPE DIMENSION
============================================================================

📋 DIMENSION OVERVIEW:
Purpose: Create comprehensive ModuleType dimension with hierarchical business logic
Grain: One row per unique ModuleType combination (MasterCategory + SubCategory)
Source: Invoice table from Lakehouse
Business Rules: Customer-based Internal/Warranty classification + ModuleType mapping

🎯 BUSINESS LOGIC REQUIREMENTS:
• Internal = CustomerNumbers: 71,72,73,74,76,77,78,81,83,84,85,86,87,9001-9007
• Warranty = CustomerNumbers: 41,42,43,44,46,47,48,51,53,54,55,56,57,9051-9057
• Standard = All other customers
• SubCategory based on ModuleType: I=Counter, W=Work Order, S=Tag
• Additional ModuleTypes (A,C,D,V) preserved for future classification

📊 HIERARCHICAL STRUCTURE:
**Level 1 - MasterCategory:** Internal/Warranty/Standard (CustomerNumber-based)
**Level 2 - SubCategory:** Counter/Work Order/Tag/etc. (ModuleType-based)
**Combined:** Creates detailed categories like "Internal - Counter", "Warranty - Work Order"

🎯 BUSINESS USE CASES:
• Revenue Analysis: Compare Internal vs Warranty vs Standard operations
• Operational Insights: Counter vs Work Order performance within each category  
• Customer Analytics: Internal customer service patterns vs external
• Financial Reporting: Warranty claim analysis by service delivery method
• Hierarchical Reporting: Drill from Master Category → Sub Category → Transactions

============================================================================
*/

let
    // ========================================================================
    // REFERENCE SOURCE TABLE AND DEFINE BUSINESS RULES
    // ========================================================================
    
    Source = Invoice, // Reference your Invoice table from Lakehouse
    
    // Define Internal Customer Numbers (as text to match CustomerNumber field)
    InternalCustomers = {"71", "72", "73", "74", "76", "77", "78", "81", "83", "84", "85", "86", "87", 
                        "9001", "9002", "9003", "9004", "9005", "9006", "9007"},
    
    // Define Warranty Customer Numbers (as text to match CustomerNumber field)
    WarrantyCustomers = {"41", "42", "43", "44", "46", "47", "48", "51", "53", "54", "55", "56", "57",
                        "9051", "9052", "9053", "9054", "9055", "9056", "9057"},

    // ========================================================================
    // DATA PREPARATION - EXTRACT AND CLEAN SOURCE DATA
    // ========================================================================
    /*
    PURPOSE: Get unique combinations of CustomerNumber and ModuleType
    QUALITY: Filter out null/empty values to ensure valid dimension records
    SCOPE: Only the fields needed for dimension logic
    */
    
    Step1_SelectColumns = Table.SelectColumns(Source, {"ModuleType", "CustomerNumber"}),
    
    Step2_FilterValidData = Table.SelectRows(Step1_SelectColumns, 
        each [ModuleType] <> null and [ModuleType] <> "" and 
             [CustomerNumber] <> null and [CustomerNumber] <> ""),
    
    Step3_GetUniqueCombo = Table.Distinct(Step2_FilterValidData),

    // ========================================================================
    // HIERARCHICAL BUSINESS LOGIC - APPLY CUSTOMER-BASED CLASSIFICATION
    // ========================================================================
    /*
    BUSINESS RULE 1: Master Category determined by CustomerNumber
    - Internal: Specific customer numbers for internal operations
    - Warranty: Specific customer numbers for warranty claims
    - Standard: All other customers (normal business operations)
    */
    
    Step4_AddMasterCategory = Table.AddColumn(Step3_GetUniqueCombo, "MasterCategory", 
        each if List.Contains(InternalCustomers, [CustomerNumber]) then "Internal"
             else if List.Contains(WarrantyCustomers, [CustomerNumber]) then "Warranty"
             else "Standard", type text),

    // ========================================================================
    // SUB-CATEGORY LOGIC - APPLY MODULETYPE-BASED CLASSIFICATION  
    // ========================================================================
    /*
    BUSINESS RULE 2: Sub Category determined by ModuleType
    - I = Counter (over-the-counter transactions)
    - W = Work Order (service work orders)
    - S = Tag (tag sales)
    - A,C,D,V = Preserved for future classification
    */
    
    Step5_AddSubCategory = Table.AddColumn(Step4_AddMasterCategory, "SubCategory",
        each if [ModuleType] = "I" then "Counter"
             else if [ModuleType] = "W" then "Work Order"
             else if [ModuleType] = "S" then "Tag"
             else [ModuleType], type text),

    // ========================================================================
    // COMBINED CATEGORIZATION - CREATE HIERARCHICAL DIMENSION KEYS
    // ========================================================================
    /*
    PURPOSE: Create unique dimension categories combining Master + Sub
    EXAMPLES: "Internal - Counter", "Warranty - Work Order", "Standard - Tag"
    BENEFIT: Enables hierarchical reporting and drill-down analysis
    */
    
    Step6_AddCombinedCategory = Table.AddColumn(Step5_AddSubCategory, "ModuleTypeCategory",
        each [MasterCategory] & " - " & [SubCategory], type text),
    
    Step7_AddDescription = Table.AddColumn(Step6_AddCombinedCategory, "ModuleTypeDescription",
        each if [MasterCategory] = "Standard" and [SubCategory] = "Counter" then "Counter"
             else if [MasterCategory] = "Standard" and [SubCategory] = "Work Order" then "Work Orders"
             else if [MasterCategory] = "Standard" and [SubCategory] = "Tag" then "Tag"
             else if [MasterCategory] = "Standard" and [SubCategory] = "A" then "Standard - A"
             else if [MasterCategory] = "Standard" and [SubCategory] = "C" then "Standard - C"
             else if [MasterCategory] = "Standard" and [SubCategory] = "D" then "Standard - D"
             else if [MasterCategory] = "Standard" and [SubCategory] = "V" then "Standard - V"
             else if [MasterCategory] = "Internal" and [SubCategory] = "Counter" then "Internal - Counter"
             else if [MasterCategory] = "Internal" and [SubCategory] = "Work Order" then "Internal - Work Orders"
             else if [MasterCategory] = "Internal" and [SubCategory] = "A" then "Internal - A"
             else if [MasterCategory] = "Internal" and [SubCategory] = "V" then "Internal - V"
             else if [MasterCategory] = "Warranty" and [SubCategory] = "Counter" then "Warranty - Counter"
             else if [MasterCategory] = "Warranty" and [SubCategory] = "Work Order" then "Warranty - Work Order"
             else [MasterCategory] & " - " & [SubCategory], type text),

    // ========================================================================
    // DIMENSION FINALIZATION - CREATE UNIQUE DIMENSION TABLE
    // ========================================================================
    /*
    STRATEGY: Group by unique combinations to create dimension grain
    METRICS: Include record count for validation and analysis
    STRUCTURE: One row per unique ModuleType combination
    */
    
    Step8_CreateUniqueDimension = Table.Group(Step7_AddDescription, 
        {"ModuleTypeCategory", "MasterCategory", "SubCategory", "ModuleTypeDescription"}, 
        {
            {"RecordCount", each Table.RowCount(_), Int64.Type},
            {"SampleCustomerNumber", each List.First([CustomerNumber]), type nullable text},
            {"SampleModuleType", each List.First([ModuleType]), type nullable text}
        }),
    
    Step9_AddSurrogateKey = Table.AddIndexColumn(Step8_CreateUniqueDimension, "ModuleTypeKey", 1, 1, Int64.Type),
    
    // Add business category for high-level grouping
    Step10_AddBusinessCategory = Table.AddColumn(Step9_AddSurrogateKey, "BusinessCategory",
        each if [MasterCategory] = "Internal" then "Internal Operations"
             else if [MasterCategory] = "Warranty" then "Warranty Services"
             else "Standard Operations", type text),
    
    // Add sort order for stakeholder-friendly grouping (by service type, then hierarchy)
    Step11_AddSortOrder = Table.AddColumn(Step10_AddBusinessCategory, "SortOrder",
        each if [MasterCategory] = "Standard" and [SubCategory] = "Counter" then 1        // Counter
             else if [MasterCategory] = "Internal" and [SubCategory] = "Counter" then 2   // Internal - Counter
             else if [MasterCategory] = "Warranty" and [SubCategory] = "Counter" then 3   // Warranty - Counter
             else if [MasterCategory] = "Standard" and [SubCategory] = "Work Order" then 4 // Work Orders
             else if [MasterCategory] = "Internal" and [SubCategory] = "Work Order" then 5 // Internal - Work Orders
             else if [MasterCategory] = "Warranty" and [SubCategory] = "Work Order" then 6 // Warranty - Work Order
             else if [MasterCategory] = "Standard" and [SubCategory] = "Tag" then 7        // Tag
             else if [MasterCategory] = "Standard" and [SubCategory] = "A" then 8          // Standard - A
             else if [MasterCategory] = "Standard" and [SubCategory] = "C" then 9          // Standard - C
             else if [MasterCategory] = "Standard" and [SubCategory] = "D" then 10         // Standard - D
             else if [MasterCategory] = "Standard" and [SubCategory] = "V" then 11         // Standard - V
             else if [MasterCategory] = "Internal" and [SubCategory] = "A" then 12         // Internal - A
             else if [MasterCategory] = "Internal" and [SubCategory] = "V" then 13         // Internal - V
             else 99, Int64.Type),

    // ========================================================================
    // FINAL DIMENSION STRUCTURE - PRODUCTION-READY OUTPUT
    // ========================================================================
    
    Step12_FinalDimensionStructure = Table.SelectColumns(Step11_AddSortOrder, {
        "ModuleTypeKey",           // Surrogate key for fact table relationships
        "ModuleTypeCategory",      // Combined category (e.g., "Internal - Counter")
        "MasterCategory",          // High-level category (Internal/Warranty/Standard)
        "SubCategory",             // Detailed category (Counter/Work Order/Tag/etc.)
        "ModuleTypeDescription",   // Business-friendly description
        "BusinessCategory",        // Highest-level business grouping
        "SortOrder",              // For consistent sorting in reports and visuals
        "RecordCount",            // Number of source combinations for validation
        "SampleCustomerNumber",   // Reference customer for business validation
        "SampleModuleType"        // Reference ModuleType for technical validation
    }),
    
    // Set proper data types for optimal performance
    Step13_SetDataTypes = Table.TransformColumnTypes(Step12_FinalDimensionStructure, {
        {"ModuleTypeKey", Int64.Type},
        {"ModuleTypeCategory", type text},
        {"MasterCategory", type text},
        {"SubCategory", type text},
        {"ModuleTypeDescription", type text}, 
        {"BusinessCategory", type text},
        {"SortOrder", Int64.Type},
        {"RecordCount", Int64.Type},
        {"SampleCustomerNumber", type text},
        {"SampleModuleType", type text}
    })

in
    Step13_SetDataTypes

/*
============================================================================
✅ PRODUCTION-READY HIERARCHICAL MODULETYPE DIMENSION - STAKEHOLDER OPTIMIZED
============================================================================

🎯 EXPECTED OUTPUT STRUCTURE (Business-Friendly Grouping):
ModuleTypeKey | ModuleTypeDescription | MasterCategory | SubCategory | SortOrder
6            | Counter               | Standard       | Counter     | 1
8            | Internal - Counter    | Internal       | Counter     | 2  
12           | Warranty - Counter    | Warranty       | Counter     | 3
10           | Work Orders           | Standard       | Work Order  | 4
5            | Internal - Work Orders| Internal       | Work Order  | 5
9            | Warranty - Work Order | Warranty       | Work Order  | 6
13           | Tag                   | Standard       | Tag         | 7
11           | Standard - A          | Standard       | A           | 8
1            | Standard - C          | Standard       | C           | 9
2            | Standard - D          | Standard       | D           | 10
4            | Standard - V          | Standard       | V           | 11
3            | Internal - A          | Internal       | A           | 12
7            | Internal - V          | Internal       | V           | 13

🔍 BUSINESS LOGIC VALIDATION:
• Internal customers (71,72,73,74,76,77,78,81,83,84,85,86,87,9001-9007) → "Internal" MasterCategory
• Warranty customers (41,42,43,44,46,47,48,51,53,54,55,56,57,9051-9057) → "Warranty" MasterCategory  
• All other customers → "Standard" MasterCategory
• ModuleType I → "Counter" SubCategory
• ModuleType W → "Work Order" SubCategory
• ModuleType S → "Tag" SubCategory
• Other ModuleTypes (A,C,D,V) → Preserved with clear "Standard/Internal/Warranty - [Letter]" naming

🎯 STAKEHOLDER-FRIENDLY FEATURES:
• Clean Descriptions: "Counter", "Work Orders", "Tag" instead of verbose names
• Logical Grouping: Service types first (Counter → Work Orders → Tag), then letter codes
• Clear Hierarchy: Standard → Internal → Warranty within each service type
• Consistent Naming: Clear distinction between standard operations and internal/warranty

🚀 REPORTING BENEFITS:
• Intuitive Sorting: Service types grouped logically for stakeholder understanding
• Clean Labels: Simple, business-friendly names in charts and visuals
• Logical Flow: Counter services → Work Order services → Specialty categories
• Easy Filtering: Clear distinction between operational categories

============================================================================
*/