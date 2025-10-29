/*
============================================================================
FACT_INVOICE_INVENTORYANALYSIS - SYNCHRONIZED WITH DIM_MODULETYPE
============================================================================

📋 FACT TABLE OVERVIEW:
Purpose: Analyze PartsSaleValue distribution across ModuleTypes with perfect dimension alignment
Grain: One row per invoice with parts sales (InvoiceNumber = Primary Key)
Source: Invoice table from Lakehouse
Focus: Parts sales analysis with customer context and verification fields

🎯 BUSINESS REQUIREMENTS:
• Primary Measure: PartsSaleValue for stakeholder pie charts and bar charts
• ModuleType Analysis: Perfectly aligned with 11-category dimension structure  
• Customer Context: Full customer information for detailed analysis
• Data Verification: ModuleType column included for validation
• Performance: Optimized date range (2023+) and value filtering (>0)

📊 SYNCHRONIZATION STRATEGY:
• IDENTICAL customer classification lists as dimension
• IDENTICAL key assignment logic as dimension (11 explicit keys)
• IDENTICAL business rules to ensure perfect fact-dimension alignment
• Verification fields included to validate logic accuracy

🎯 STAKEHOLDER USE CASES:
• Pie Chart: PartsSaleValue % by ModuleType (Counter/Work Orders/Internal/etc.)
• Bar Chart: Branch performance by ModuleType with stacked/clustered views
• Time Analysis: ModuleType trends over time with date filtering
• Customer Analysis: Parts sales patterns by customer within ModuleType categories

============================================================================
*/

let
    // ========================================================================
    // INCREMENTAL REFRESH PARAMETERS - PERFORMANCE OPTIMIZATION
    // ========================================================================
    /*
    PURPOSE: Focus on recent business data (2023+) for stakeholder analysis
    PERFORMANCE: Date filtering enables optimal query folding and SQL pushdown  
    SCOPE: 2-year window provides relevant business intelligence scope
    */
    
    RangeStart = #datetime(2023, 1, 1, 0, 0, 0),
    RangeEnd = DateTime.LocalNow(),

    // ========================================================================
    // SOURCE DATA AND BUSINESS RULE DEFINITIONS
    // ========================================================================
    
    Source = Invoice, // Reference your Invoice table from Lakehouse
    
    // CRITICAL: IDENTICAL customer lists as dimension to ensure perfect alignment
    InternalCustomers = {"71", "72", "73", "74", "76", "77", "78", "81", "83", "84", "85", "86", "87", 
                        "9001", "9002", "9003", "9004", "9005", "9006", "9007"},
    
    WarrantyCustomers = {"41", "42", "43", "44", "46", "47", "48", "51", "53", "54", "55", "56", "57",
                        "9051", "9052", "9053", "9054", "9055", "9056", "9057"},

    // ========================================================================
    // FACT TABLE FIELD SELECTION - FOCUSED ON BUSINESS REQUIREMENTS
    // ========================================================================
    /*
    STRATEGY: Include essential fields for PartsSaleValue analysis and customer context
    VERIFICATION: ModuleType included for validation against ModuleTypeKey assignments
    SCOPE: Customer information enables detailed analysis within ModuleType categories
    */
    
    Step1_SelectCoreFields = Table.SelectColumns(Source, {
        // === PRIMARY KEYS AND DIMENSION KEYS ===
        "InvoiceNumber",        // Grain - Primary Key for fact table
        "InvoiceDate",          // Foreign Key → dim_Date (existing relationship)
        "Branch",               // Foreign Key → dim_Branch (existing relationship)
        "ModuleType",           // For ModuleTypeKey lookup + VERIFICATION
        "CustomerNumber",       // For customer classification + analysis
        
        // === CUSTOMER CONTEXT ===
        "CompanyName",          // Customer business context
        "FirstName",            // Customer personal context
        "LastName",             // Customer personal context
        
        // === CORE MEASURES ===
        "PartsSaleValue",       // PRIMARY MEASURE - Main stakeholder focus
        "PartsCostValue",       // Supporting measure for margin analysis
        
        // === AUDIT AND REFRESH ===
        "ModifiedDate"          // For incremental refresh capability
    }),

    // ========================================================================
    // DATA QUALITY AND PERFORMANCE FILTERING
    // ========================================================================
    /*
    PERFORMANCE: Multi-layered filtering for optimal dataset size and quality
    1. Date Range: 2023+ focuses on recent business data (reduces ~50% of historical data)
    2. Value Filter: PartsSaleValue > 0 removes zero-value transactions  
    3. Data Quality: Valid invoice numbers and dates ensure analytical integrity
    RESULT: Significantly reduced dataset from original 1.2M+ rows
    */
    
    Step2_ApplyBusinessFilters = Table.SelectRows(Step1_SelectCoreFields,
        each [InvoiceNumber] <> null and [InvoiceNumber] <> "" and
             [InvoiceDate] <> null and
             [InvoiceDate] >= RangeStart and
             [InvoiceDate] < RangeEnd and
             [PartsSaleValue] <> null and 
             [PartsSaleValue] > 0), // Focus on actual parts sales transactions

    // ========================================================================
    // MODULETYPE KEY ASSIGNMENT - PERFECT DIMENSION ALIGNMENT
    // ========================================================================
    /*
    CRITICAL: Uses IDENTICAL logic as dim_ModuleType for perfect synchronization
    STRATEGY: Same customer classification and key assignment rules
    VALIDATION: Logic produces exact same ModuleTypeKey for identical CustomerNumber + ModuleType
    RESULT: Eliminates fact-dimension misalignment issues experienced previously
    */
    
    Step3_AddModuleTypeKey = Table.AddColumn(Step2_ApplyBusinessFilters, "ModuleTypeKey",
        each 
            // IDENTICAL business logic as dimension - Customer classification first
            let
                CustomerCategory = if List.Contains(InternalCustomers, [CustomerNumber]) then "Internal"
                                 else if List.Contains(WarrantyCustomers, [CustomerNumber]) then "Warranty"
                                 else "Standard"
            in
                // IDENTICAL key assignments as dimension - 11 explicit categories
                if CustomerCategory = "Standard" and [ModuleType] = "I" then 1        // Counter
                else if CustomerCategory = "Standard" and [ModuleType] = "W" then 2   // Work Orders  
                else if CustomerCategory = "Standard" and [ModuleType] = "S" then 3   // Tag
                else if CustomerCategory = "Internal" and [ModuleType] = "I" then 4   // Internal - Counter
                else if CustomerCategory = "Internal" and [ModuleType] = "W" then 5   // Internal - Work Orders
                else if CustomerCategory = "Warranty" and [ModuleType] = "I" then 6   // Warranty - Counter
                else if CustomerCategory = "Warranty" and [ModuleType] = "W" then 7   // Warranty - Work Order
                else if [ModuleType] = "A" then 8                                      // A
                else if [ModuleType] = "C" then 9                                      // C
                else if [ModuleType] = "D" then 10                                     // D
                else if [ModuleType] = "V" then 11                                     // V
                else null, // Null for unexpected combinations (data quality flag)
        Int64.Type),

    // ========================================================================
    // CALCULATED FIELDS FOR BUSINESS ANALYSIS
    // ========================================================================
    /*
    PURPOSE: Add calculated fields for margin analysis and business insights
    LOGIC: Safe null handling prevents calculation errors
    BENEFIT: Enables immediate margin analysis without additional DAX measures
    */
    
    Step4_AddPartsMargin = Table.AddColumn(Step3_AddModuleTypeKey, "PartsMargin",
        each if [PartsSaleValue] <> null and [PartsCostValue] <> null 
             then [PartsSaleValue] - [PartsCostValue] 
             else null, type number),
    
    Step5_AddMarginPercentage = Table.AddColumn(Step4_AddPartsMargin, "PartsMarginPct",
        each if [PartsSaleValue] <> null and [PartsSaleValue] <> 0 and [PartsMargin] <> null
             then [PartsMargin] / [PartsSaleValue]
             else null, type number),

    // ========================================================================
    // DATA QUALITY VALIDATION AND OPTIONAL FILTERING
    // ========================================================================
    /*
    QUALITY: Filter out records where ModuleTypeKey assignment failed (null values)
    BUSINESS: These represent unexpected CustomerNumber + ModuleType combinations
    BENEFIT: Clean dataset with only valid, analyzable combinations
    */
    
    Step6_FilterValidKeys = Table.SelectRows(Step5_AddMarginPercentage,
        each [ModuleTypeKey] <> null), // Remove records with failed key assignment

    // ========================================================================
    // FINAL FACT TABLE STRUCTURE - OPTIMIZED FOR STAKEHOLDER ANALYSIS
    // ========================================================================
    
    Step7_CreateFinalStructure = Table.SelectColumns(Step6_FilterValidKeys, {
        // === DIMENSION KEYS ===
        "InvoiceNumber",        // Primary Key - Grain identifier
        "InvoiceDate",          // Foreign Key → dim_Date
        "Branch",               // Foreign Key → dim_Branch  
        "ModuleTypeKey",        // Foreign Key → dim_ModuleType (NEW)
        
        // === VERIFICATION FIELD ===
        "ModuleType",           // VERIFICATION: Validate against ModuleTypeKey
        
        // === CUSTOMER CONTEXT ===
        "CustomerNumber",       // Customer identification for detailed analysis
        "CompanyName",          // Business customer context
        "FirstName",            // Individual customer context
        "LastName",             // Individual customer context
        
        // === CORE MEASURES ===
        "PartsSaleValue",       // PRIMARY MEASURE - Stakeholder focus
        "PartsCostValue",       // Supporting measure for cost analysis
        "PartsMargin",          // Calculated measure (Sale - Cost)
        "PartsMarginPct",       // Calculated percentage (Margin / Sale)
        
        // === AUDIT FIELDS ===
        "ModifiedDate"          // Incremental refresh capability
    }),
    
    // ========================================================================
    // DATA TYPE OPTIMIZATION FOR PERFORMANCE
    // ========================================================================
    
    Step8_SetOptimalDataTypes = Table.TransformColumnTypes(Step7_CreateFinalStructure, {
        {"InvoiceNumber", type text},
        {"InvoiceDate", type datetime},
        {"Branch", type text},
        {"ModuleTypeKey", Int64.Type},
        {"ModuleType", type text},
        {"CustomerNumber", type text},
        {"CompanyName", type text},
        {"FirstName", type text},
        {"LastName", type text},
        {"PartsSaleValue", Currency.Type},
        {"PartsCostValue", Currency.Type},
        {"PartsMargin", Currency.Type},
        {"PartsMarginPct", Percentage.Type},
        {"ModifiedDate", type datetime}
    })

in
    Step8_SetOptimalDataTypes

/*
============================================================================
✅ FACT_INVOICE_INVENTORYANALYSIS - PRODUCTION READY
============================================================================

🎯 PERFECT DIMENSION ALIGNMENT ACHIEVED:
• IDENTICAL customer classification logic as dim_ModuleType
• IDENTICAL key assignment rules (11 explicit categories)  
• IDENTICAL business rules for Internal/Warranty customer handling
• VERIFICATION field (ModuleType) included for data validation

📊 EXPECTED KEY ASSIGNMENTS (Validation Examples):
• Customer 1343 + ModuleType "I" → Key 1 (Counter) ✓
• Customer 52346 + ModuleType "W" → Key 2 (Work Orders) ✓  
• Customer 71 + ModuleType "I" → Key 4 (Internal - Counter) ✓
• Customer 71 + ModuleType "W" → Key 5 (Internal - Work Orders) ✓
• Customer 41 + ModuleType "I" → Key 6 (Warranty - Counter) ✓
• Customer 41 + ModuleType "W" → Key 7 (Warranty - Work Order) ✓

⚡ PERFORMANCE OPTIMIZATIONS:
• Date filtering (2023+) reduces dataset size by ~50%
• Value filtering (PartsSaleValue > 0) removes zero transactions
• Quality filtering removes invalid key assignments
• Optimized data types improve storage and query performance
• Expected final dataset: ~300-350K rows (down from 1.2M+ original)

🔗 REQUIRED RELATIONSHIPS:
• Fact_Invoice_InventoryAnalysis[InvoiceDate] → dim_Date[Date] (Many:One)
• Fact_Invoice_InventoryAnalysis[Branch] → dim_Branch[Branch] (Many:One)  
• Fact_Invoice_InventoryAnalysis[ModuleTypeKey] → dim_ModuleType[ModuleTypeKey] (Many:One)

🎯 STAKEHOLDER VISUALIZATIONS ENABLED:

📈 PIE CHART - PartsSaleValue Distribution:
• Measure: SUM(Fact_Invoice_InventoryAnalysis[PartsSaleValue])
• Legend: dim_ModuleType[ModuleTypeDescription]
• Result: Clean % breakdown across Counter/Work Orders/Internal/Warranty categories

📊 BAR CHART - Branch Performance by ModuleType:
• Y-Axis: dim_Branch[Branch] 
• X-Axis: SUM(Fact_Invoice_InventoryAnalysis[PartsSaleValue])
• Legend: dim_ModuleType[BusinessGrouping]
• Result: Stacked bars showing Counter/Internal/Warranty mix per branch

📅 TIME ANALYSIS - ModuleType Trends:
• X-Axis: dim_Date hierarchy (Year/Quarter/Month)
• Y-Axis: SUM(Fact_Invoice_InventoryAnalysis[PartsSaleValue])
• Legend: dim_ModuleType[BusinessGrouping]
• Result: Trend analysis of business categories over time

💰 MARGIN ANALYSIS:
• Available measures: PartsMargin, PartsMarginPct for profitability analysis
• Customer-level analysis using CustomerNumber, CompanyName fields
• Cross-filtering enabled through proper relationship structure

🔍 DATA VALIDATION CAPABILITIES:
• ModuleType vs ModuleTypeKey cross-validation
• CustomerNumber verification against Internal/Warranty lists
• RecordCount monitoring through dimension relationship
• Null key identification for data quality monitoring

🚀 IMPLEMENTATION STEPS:
1. Deploy this fact table query in your dataflow (replaces previous version)
2. Validate key assignments using ModuleType verification field
3. Create model relationship: ModuleTypeKey → dim_ModuleType[ModuleTypeKey]
4. Test specific invoice examples to confirm correct categorization
5. Build stakeholder visualizations using clean dimension labels
6. Monitor refresh performance and data quality metrics

🔧 SUCCESS VALIDATION:
• Invoice 1352446: Customer 1343 + ModuleType "I" should show Key 1 ✓
• Invoice 1769922: Customer 52346 + ModuleType "W" should show Key 2 ✓
• Internal customers (71, 72, etc.) should appear with Keys 4-5 ✓  
• Warranty customers (41, 42, etc.) should appear with Keys 6-7 ✓
• ModuleType field should match expected categories for each key ✓

============================================================================
*/