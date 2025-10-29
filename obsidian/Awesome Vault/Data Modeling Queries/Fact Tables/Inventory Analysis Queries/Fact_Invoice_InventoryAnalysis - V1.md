/*
============================================================================
FACT_INVOICE - PARTS SALES ANALYSIS STRATEGY
============================================================================

📋 BUSINESS REQUIREMENTS:
Purpose: Analyze PartsSaleValue distribution across ModuleTypes
Primary Use Cases:
• Pie Chart: PartsSaleValue by ModuleType (%)
• Bar Chart: Branch vs PartsSaleValue, split by ModuleType
• Time Analysis: PartsSaleValue trends by ModuleType
• Integration: Work with existing dim_Date, dim_Branch relationships

🎯 FACT TABLE STRATEGY:
Grain: One row per invoice (unique by InvoiceNumber)
Focus: PartsSaleValue as primary measure
Complexity: Simple and focused - not comprehensive financial analysis
Integration: Leverage existing dimensions + new dim_ModuleType

============================================================================
*/

let
    // ========================================================================
    // INCREMENTAL REFRESH PARAMETERS - FABRIC OPTIMIZED
    // ========================================================================
    /*
    PURPOSE: 2023+ scope provides relevant business data while optimizing performance
    PERFORMANCE: InvoiceDate filtering provides optimal query folding and SQL pushdown
    SCOPE: 2-year window balances analysis needs with refresh performance
    */
    
    RangeStart = #datetime(2023, 1, 1, 0, 0, 0),
    RangeEnd = DateTime.LocalNow(),

    // ========================================================================
    // REFERENCE SOURCE AND APPLY BUSINESS RULES
    // ========================================================================
    
    Source = Invoice, // Reference your Invoice table from Lakehouse
    
    // Customer classification lists (same as dimension)
    InternalCustomers = 
    WarrantyCustomers = {"41", "42", "43", "44", "46", "47", "48", "51", "53", "54", "55", "56", "57",
                        "9051", "9052", "9053", "9054", "9055", "9056", "9057"},

    // ========================================================================
    // FACT TABLE CORE STRUCTURE - FOCUSED ON BUSINESS REQUIREMENTS
    // ========================================================================
    /*
    STRATEGY: Include only essential fields for PartsSaleValue analysis
    FOCUS: ModuleType analysis with existing dimension integration
    SIMPLICITY: Avoid over-engineering - meet specific business needs
    */
    
    Step1_SelectCoreFields = Table.SelectColumns(Source, {
        // === DIMENSION KEYS ===
        "InvoiceNumber",        // Grain/Primary Key
        "InvoiceDate",          // → dim_Date (existing relationship)
        "Branch",               // → dim_Branch (existing relationship)
        "ModuleType",           // For ModuleTypeKey lookup
        "CustomerNumber",       // For ModuleType classification + customer analysis
        
        // === CUSTOMER INFORMATION ===
        "CompanyName",          // Customer context
        "FirstName",            // Customer context  
        "LastName",             // Customer context
        
        // === MEASURES ===
        "PartsSaleValue",       // PRIMARY MEASURE - Main business focus
        "PartsCostValue",       // For margin analysis
        
        // === AUDIT/REFRESH FIELDS ===
        "ModifiedDate"          // For future incremental refresh capability
    }),
    
    // ========================================================================
    // DATA QUALITY & PERFORMANCE OPTIMIZATION
    // ========================================================================
    /*
    PERFORMANCE: Multiple filters to significantly reduce data size:
    1. PartsSaleValue > 0 (removes zero-value transactions)
    2. InvoiceDate >= 2023 (focuses on recent business data)
    3. Valid core fields (ensures data quality)
    RESULT: Dramatic reduction from 1.2M+ rows for optimal refresh performance
    */
    
    Step2_FilterValidRecords = Table.SelectRows(Step1_SelectCoreFields,
        each [InvoiceNumber] <> null and [InvoiceNumber] <> "" and
             [InvoiceDate] <> null and
             [InvoiceDate] >= RangeStart and
             [InvoiceDate] < RangeEnd and
             [PartsSaleValue] <> null and 
             [PartsSaleValue] > 0), // PERFORMANCE: Only actual parts sales in date range
    
    // ========================================================================
    // ADD MODULETYPE DIMENSION KEY - EXACT MATCH TO DIMENSION LOGIC
    // ========================================================================
    /*
    BUSINESS RULE: Match exactly with dim_ModuleType classification
    LOOKUP: Combine CustomerNumber + ModuleType → ModuleTypeKey
    INTEGRATION: Creates relationship to dim_ModuleType
    */
    
    Step3_AddModuleTypeKey = Table.AddColumn(Step2_FilterValidRecords, "ModuleTypeKey",
        each 
            // Internal Customers
            if List.Contains(InternalCustomers, [CustomerNumber]) then
                if [ModuleType] = "A" then 3      // Internal - A  
                else if [ModuleType] = "W" then 5 // Internal - Work Order
                else if [ModuleType] = "V" then 7 // Internal - V
                else if [ModuleType] = "I" then 8 // Internal - Counter
                else null
            
            // Warranty Customers
            else if List.Contains(WarrantyCustomers, [CustomerNumber]) then
                if [ModuleType] = "W" then 9      // Warranty - Work Order
                else if [ModuleType] = "I" then 12 // Warranty - Counter
                else null
            
            // Standard Customers
            else if [ModuleType] = "C" then 1     // Standard - C
            else if [ModuleType] = "D" then 2     // Standard - D
            else if [ModuleType] = "V" then 4     // Standard - V
            else if [ModuleType] = "I" then 6     // Standard - Counter
            else if [ModuleType] = "W" then 10    // Standard - Work Order
            else if [ModuleType] = "A" then 11    // Standard - A
            else if [ModuleType] = "S" then 13    // Standard - Tag
            else null, Int64.Type),
    
    // ========================================================================
    // ADD CALCULATED FIELDS FOR ANALYSIS
    // ========================================================================
    
    Step4_AddCalculatedFields = Table.AddColumn(Step3_AddModuleTypeKey, "PartsMargin",
        each if [PartsCostValue] <> null and [PartsSaleValue] <> null 
             then [PartsSaleValue] - [PartsCostValue] 
             else null, type number),
    
    Step5_AddMarginPct = Table.AddColumn(Step4_AddCalculatedFields, "PartsMarginPct",
        each if [PartsSaleValue] <> null and [PartsSaleValue] <> 0 and [PartsMargin] <> null
             then [PartsMargin] / [PartsSaleValue]
             else null, type number),
    
    // ========================================================================
    // FINAL FACT TABLE STRUCTURE - OPTIMIZED FOR PARTS SALES ANALYSIS
    // ========================================================================
    
    Step6_FinalFactStructure = Table.SelectColumns(Step5_AddMarginPct, {
        // === DIMENSION KEYS ===
        "InvoiceNumber",        // Grain - Primary Key
        "InvoiceDate",          // FK → dim_Date
        "Branch",               // FK → dim_Branch  
        "ModuleTypeKey",        // FK → dim_ModuleType (NEW)
        
        // === CUSTOMER INFORMATION ===
        "CustomerNumber",       // Customer identification
        "CompanyName",          // Customer context
        "FirstName",            // Customer context
        "LastName",             // Customer context
        
        // === CORE MEASURES ===
        "PartsSaleValue",       // PRIMARY - Main business focus
        "PartsCostValue",       // Supporting measure
        "PartsMargin",          // Calculated measure
        "PartsMarginPct",       // Calculated percentage
        
        // === AUDIT FIELDS ===
        "ModifiedDate"          // For future incremental refresh
    }),
    
    // Set optimal data types
    Step7_SetDataTypes = Table.TransformColumnTypes(Step6_FinalFactStructure, {
        {"InvoiceNumber", type text},
        {"InvoiceDate", type datetime},
        {"Branch", type text},
        {"ModuleTypeKey", Int64.Type},
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
    Step7_SetDataTypes

/*
============================================================================
✅ FACT_INVOICE - OPTIMIZED PARTS SALES ANALYSIS TABLE
============================================================================

🎯 FACT TABLE CHARACTERISTICS:
• Grain: One row per invoice with parts sales (InvoiceNumber = Primary Key)
• Scope: 2023+ data only (2-year business window for optimal performance)
• Focus: PartsSaleValue analysis by ModuleType
• Performance: Dual-filtered (date range + PartsSaleValue > 0) for maximum efficiency
• Integration: Works with existing dim_Date, dim_Branch + new dim_ModuleType
• Customer Context: Includes customer information for detailed analysis

⚡ PERFORMANCE OPTIMIZATIONS:
• InvoiceDate >= 2023 filter focuses on recent 2-year business period
• PartsSaleValue > 0 filter removes zero-value transactions  
• Combined filters dramatically reduce dataset from 1.2M+ rows
• ModifiedDate included for incremental refresh capability
• Focused field selection improves refresh performance
• Optimized data types for storage and query performance
• Query folding maintained for SQL pushdown optimization

📊 DIMENSION RELATIONSHIPS REQUIRED:

🔗 EXISTING RELATIONSHIPS (Leverage Current Model):
• Fact_Invoice[InvoiceDate] → dim_Date[Date] (Many:One)
• Fact_Invoice[Branch] → dim_Branch[Branch] (Many:One)

🔗 NEW RELATIONSHIP (Add to Model):
• Fact_Invoice[ModuleTypeKey] → dim_ModuleType[ModuleTypeKey] (Many:One)

🎯 BUSINESS USE CASES ENABLED:

📈 PIE CHART - PartsSaleValue by ModuleType:
• Measure: SUM(Fact_Invoice[PartsSaleValue])
• Legend: dim_ModuleType[ModuleTypeCategory] 
• Result: Shows % distribution across "Internal - Counter", "Warranty - Work Order", etc.

📊 BAR CHART - Branch vs PartsSaleValue by ModuleType:
• Y-Axis: dim_Branch[Branch]
• X-Axis: SUM(Fact_Invoice[PartsSaleValue])
• Legend: dim_ModuleType[MasterCategory] or [ModuleTypeCategory]
• Result: Stacked/clustered bars showing ModuleType mix per branch

👥 CUSTOMER ANALYSIS - Parts sales by customer:
• Customer details available for detailed analysis
• Can slice by CompanyName or create customer-level insights
• Enables customer profitability analysis within ModuleType categories

📅 TIME ANALYSIS - PartsSaleValue trends by ModuleType:
• X-Axis: dim_Date fields (Month, Quarter, Year)
• Y-Axis: SUM(Fact_Invoice[PartsSaleValue])
• Legend/Filter: dim_ModuleType[MasterCategory]
• Result: Trend analysis of Internal vs Warranty vs Standard parts sales

🔧 FUTURE ENHANCEMENTS:

📈 Incremental Refresh Ready:
• ModifiedDate field enables incremental refresh setup
• Reduces future refresh times as data grows
• Maintains performance with growing dataset

💡 Additional Measures (can be added to measures table):
• Parts Sales %: [PartsSaleValue] / SUM(ALL(Fact_Invoice[PartsSaleValue]))
• Average Parts Sale: AVERAGE(Fact_Invoice[PartsSaleValue])
• Parts Margin %: SUM([PartsMargin]) / SUM([PartsSaleValue])
• Customer Parts Value: SUM(Fact_Invoice[PartsSaleValue]) by customer

🚀 IMPLEMENTATION STEPS:
1. Create Fact_Invoice dataflow using this optimized query
2. Verify significant data size reduction (2023+ date range + PartsSaleValue > 0)
3. Test refresh performance improvement from dual filtering
4. Add relationship: Fact_Invoice[ModuleTypeKey] → dim_ModuleType[ModuleTypeKey]  
5. Create basic measures in Measures table
6. Build pie chart and bar chart visualizations
7. Test with different time periods and branch filters
8. Set up incremental refresh using RangeStart/RangeEnd parameters for ongoing performance

============================================================================
*/