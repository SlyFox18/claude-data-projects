
/*
============================================================================
RAW_WKROFILE - COMPREHENSIVE WORK ORDER FOUNDATION WITH ENHANCED INTELLIGENCE
============================================================================

📋 TABLE OVERVIEW:
Purpose: Complete work order master data foundation for comprehensive business analytics
Grain: One row per work order (master work order record)
Refresh Strategy: Incremental refresh ready (ModifiedDate filtering for optimal performance)
Current Performance: Target <2 minutes refresh time with enhanced columns
Source Dependencies: wkrofile table (primary work order system)

🎯 BUSINESS USE CASES:
• Comprehensive Work Order Analytics: Complete work order lifecycle tracking and analysis
• Customer Classification: Account class, customer type, and service relationship analysis
• Equipment Intelligence: Vehicle registration, stock numbers, and manufacturer tracking
• Service Type Analysis: Field vs shop service, quotation vs work order analysis
• Financial Authorization: Authorization values and customer billing relationship tracking
• Operational Intelligence: Service scheduling, loaner car management, and resource planning
• Territory Management: Tax regions, branch assignments, and geographic analysis
• Cross-Fact Foundation: Master work order data supporting all fact table relationships

📊 KEY ENHANCEMENTS ADDED:
• Equipment Manufacturer Intelligence: FRANCHISE and STOCK_FRAN for manufacturer analysis
• Service Classification: Field_Service_Flag, Account_Class for service type intelligence
• Financial Context: auth_value, Quotation_Ind for financial and quoting analysis
• Timeline Intelligence: EST_HOURS, Closed_Date for complete lifecycle tracking
• Customer Intelligence: Account_Class, salesman for customer relationship analysis
• Geographic Intelligence: Tax_Region for territory and market analysis
• Operational Flags: Quotation_Ind, ro_closed_ind for operational status tracking

🔗 FACT TABLE RELATIONSHIPS:
• Foundation for Fact_WorkOrderHeader (comprehensive work order analytics)
• Foundation for Fact_WorkOrderParts (parts transaction context)
• Foundation for all labor fact tables (work order context and customer assignment)
• Foundation for Fact_WarrantyClaims (warranty work order context)
• Serves as master reference for dim_WorkOrderMaster dimension

📈 DASHBOARD APPLICATIONS:
• Comprehensive Work Order Management: Complete work order tracking with enhanced intelligence
• Customer Relationship Analytics: Account class and salesperson performance analysis
• Equipment Service Analysis: Manufacturer-specific service patterns and performance
• Territory Performance: Geographic analysis with tax region and branch intelligence
• Service Mix Analysis: Field vs shop service patterns and resource utilization
• Financial Authorization: Authorization value analysis and customer credit management

⚡ PERFORMANCE OPTIMIZATION NOTES:
• ModifiedDate filtering ensures incremental refresh capability and optimal performance
• Essential column selection balances comprehensive intelligence with refresh performance
• SQL query folding optimizes data retrieval from source system
• Strategic column additions provide maximum business value with minimal performance impact

🔧 MAINTENANCE NOTES:
• Monitor refresh performance as enhanced columns are added
• Validate new column data quality and business value periodically
• Review column selection annually based on fact table usage patterns
• Ensure ModifiedDate filtering remains effective for incremental refresh
• Consider additional columns based on evolving business intelligence needs

============================================================================
*/

let
    // ========================================================================
    // INCREMENTAL REFRESH PARAMETERS - STANDARD PATTERN
    // ========================================================================
    /*
    PURPOSE: Consistent date filtering across all raw tables for optimal performance
    APPROACH: ModifiedDate filtering captures recent activity on historical work orders
    BUSINESS LOGIC: Any work order modified since 2023 is relevant for analysis
    */
    
    // Define parameters for refresh control (standard across all raw tables)
    RangeStart = #datetime(2023, 1, 1, 0, 0, 0),
    RangeEnd = DateTime.LocalNow(),

    // Convert to SQL-safe format for query folding optimization
    StartStr = "'" & DateTime.ToText(RangeStart, "yyyy-MM-dd HH:mm:ss") & "'",
    EndStr = "'" & DateTime.ToText(RangeEnd, "yyyy-MM-dd HH:mm:ss") & "'",

    // ========================================================================
    // ENHANCED SQL QUERY - COMPREHENSIVE BUSINESS INTELLIGENCE
    // ========================================================================
    /*
    PURPOSE: Extract comprehensive work order data for complete business analytics
    STRATEGY: Balance comprehensive intelligence with refresh performance
    ENHANCEMENTS: Added key business intelligence fields for fact table development
    */
    
    SQL = 
    "SELECT #(lf)
        -- ===== CORE IDENTIFIERS ===== #(lf)
        BRANCH AS Branch, #(lf)
        RO_NUMBER AS WorkOrder, #(lf)
        REG AS Registration, #(lf)
        STOCK_NO AS StockNumber, #(lf)
        CHARGE_ACCT AS AccountNumber, #(lf)
        
        -- ===== ENHANCED EQUIPMENT INTELLIGENCE ===== #(lf)
        FRANCHISE AS Franchise, #(lf)
        STOCK_FRAN AS StockFranchise, #(lf)
        ODOMETER AS Odometer, #(lf)
        CUST_VEH_FA AS CustomerVehicleFlag, #(lf)
        
        -- ===== STATUS & PROGRESS TRACKING ===== #(lf)
        RO_PROGRESS_STATUS AS ProgressStatus, #(lf)
        ro_closed_ind AS IsClosedIndicator, #(lf)
        
        -- ===== ENHANCED TIMELINE INTELLIGENCE ===== #(lf)
        CREATION_DATE AS CreatedOn, #(lf)
        DATETIME_IN AS JobStartDate, #(lf)
        EXPECTED_DATETIME AS ExpectedDate, #(lf)
        Closed_Date AS ClosedDate, #(lf)
        EST_HOURS AS EstimatedHours, #(lf)
        
        -- ===== CUSTOMER & FINANCIAL INTELLIGENCE ===== #(lf)
        Account_Class AS AccountClass, #(lf)
        auth_value AS AuthorizationValue, #(lf)
        salesman AS Salesperson, #(lf)
        Pay_Method AS PaymentMethod, #(lf)
        
        -- ===== SERVICE TYPE CLASSIFICATION ===== #(lf)
        Field_Service_Flag AS IsFieldService, #(lf)
        Quotation_Ind AS IsQuotation, #(lf)
        Quotation_Exp_Date AS QuotationExpiryDate, #(lf)
        
        -- ===== GEOGRAPHIC & TERRITORY INTELLIGENCE ===== #(lf)
        Tax_Region AS TaxRegion, #(lf)
        Tax_Status AS TaxStatus, #(lf)
        
        -- ===== OPERATIONAL CONTEXT ===== #(lf)
        Team_Code AS TeamCode, #(lf)
        Marketing_Source AS MarketingSource, #(lf)
        
        -- ===== CUSTOMER SERVICE INTELLIGENCE ===== #(lf)
        CUST_ORDER_NO AS CustomerOrderNumber, #(lf)
        concise_history AS ServiceHistory, #(lf)
        
        -- ===== AUDIT & SYSTEM FIELDS ===== #(lf)
        ModifiedDate AS ModifiedDate, #(lf)
        CreatedBy AS CreatedBy, #(lf)
        ModifiedBy AS ModifiedBy #(lf)
        
    FROM wkrofile #(lf)
    WHERE ModifiedDate >= " & StartStr & " #(lf)
      AND ModifiedDate < " & EndStr & " #(lf)
    ORDER BY ModifiedDate DESC, Branch, RO_NUMBER",

    // ========================================================================
    // EXECUTE QUERY WITH ERROR HANDLING
    // ========================================================================
    
    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise 
        error "Failed to connect to WKROFILE. Check connection and table availability.",

    // ========================================================================
    // DATA TYPE OPTIMIZATION & STANDARDIZATION
    // ========================================================================
    /*
    PURPOSE: Optimize data types for performance and ensure consistency
    APPROACH: Use appropriate data types for each field based on business usage
    BENEFIT: Optimal query performance and memory efficiency
    */
    
    StandardizedDataTypes = Table.TransformColumnTypes(Source, {
        // Core identifiers
        {"Branch", type text}, {"WorkOrder", Int64.Type}, {"Registration", type text}, 
        {"StockNumber", type text}, {"AccountNumber", type text},
        
        // Equipment intelligence
        {"Franchise", type text}, {"StockFranchise", type text}, {"Odometer", Int64.Type},
        {"CustomerVehicleFlag", type text},
        
        // Status tracking
        {"ProgressStatus", type text}, {"IsClosedIndicator", type text},
        
        // Timeline intelligence  
        {"CreatedOn", type datetime}, {"JobStartDate", type datetime}, 
        {"ExpectedDate", type datetime}, {"ClosedDate", type datetime}, {"EstimatedHours", type number},
        
        // Customer & financial
        {"AccountClass", type text}, {"AuthorizationValue", type number}, 
        {"Salesperson", type text}, {"PaymentMethod", type text},
        
        // Service classification
        {"IsFieldService", type text}, {"IsQuotation", type text}, {"QuotationExpiryDate", type datetime},
        
        // Geographic intelligence
        {"TaxRegion", type text}, {"TaxStatus", type text},
        
        // Operational context
        {"TeamCode", type text}, {"MarketingSource", type text},
        
        // Customer service
        {"CustomerOrderNumber", type text}, {"ServiceHistory", type text},
        
        // Audit fields
        {"ModifiedDate", type datetime}, {"CreatedBy", type text}, {"ModifiedBy", type text}
    }),
    
    // ========================================================================
    // BUSINESS LOGIC ENHANCEMENT - KEY FLAGS AND CLASSIFICATIONS
    // ========================================================================
    /*
    PURPOSE: Add essential business logic for fact table development
    APPROACH: Pre-calculate key business indicators for optimal fact table performance
    BENEFIT: Enhanced analytical capability and simplified fact table logic
    */
    
    // Create composite work order key for dimensional modeling
    AddWorkOrderKey = Table.AddColumn(StandardizedDataTypes, "WorkOrderKey", each 
        [Branch] & "-" & Text.From([WorkOrder]), type text),
    
    // Standardize boolean flags with robust handling
    AddFieldServiceFlag = Table.AddColumn(AddWorkOrderKey, "FieldServiceFlag", each
        let cleanValue = Text.Trim(Text.Upper([IsFieldService] ?? "")) in
        if cleanValue = "Y" or cleanValue = "YES" or cleanValue = "1" or cleanValue = "TRUE" then true
        else if cleanValue = "N" or cleanValue = "NO" or cleanValue = "0" or cleanValue = "FALSE" or cleanValue = "" then false
        else null, type logical),
        
    AddQuotationFlag = Table.AddColumn(AddFieldServiceFlag, "QuotationFlag", each
        let cleanValue = Text.Trim(Text.Upper([IsQuotation] ?? "")) in
        if cleanValue = "Y" or cleanValue = "YES" or cleanValue = "1" or cleanValue = "TRUE" then true
        else if cleanValue = "N" or cleanValue = "NO" or cleanValue = "0" or cleanValue = "FALSE" or cleanValue = "" then false
        else null, type logical),
        
    AddClosedFlag = Table.AddColumn(AddQuotationFlag, "ClosedFlag", each
        let cleanValue = Text.Trim(Text.Upper([IsClosedIndicator] ?? "")) in
        if cleanValue = "Y" or cleanValue = "YES" or cleanValue = "1" or cleanValue = "TRUE" then true
        else if cleanValue = "N" or cleanValue = "NO" or cleanValue = "0" or cleanValue = "FALSE" or cleanValue = "" then false
        else null, type logical),
    
    // Work order age calculation for business intelligence
    AddWorkOrderAge = Table.AddColumn(AddClosedFlag, "WorkOrderAgeInDays", each 
        if [CreatedOn] <> null then 
            Duration.Days(DateTime.LocalNow() - [CreatedOn])
        else null, type number),
    
    // Service type classification
    AddServiceTypeClassification = Table.AddColumn(AddWorkOrderAge, "ServiceTypeClassification", each
        let
            fieldService = [FieldServiceFlag] ?? false,
            isQuote = [QuotationFlag] ?? false,
            accountClass = Text.Upper([AccountClass] ?? "")
        in
        if isQuote then "Quotation"
        else if fieldService then "Field Service"
        else if Text.Contains(accountClass, "FLEET") then "Fleet Service"
        else if Text.Contains(accountClass, "RETAIL") then "Retail Service"
        else if Text.Contains(accountClass, "WARRANTY") then "Warranty Service"
        else if Text.Contains(accountClass, "INTERNAL") then "Internal Service"
        else "Standard Service", type text),
    
    // Authorization value categories for business analysis
    AddAuthValueCategory = Table.AddColumn(AddServiceTypeClassification, "AuthValueCategory", each
        let authValue = [AuthorizationValue] ?? 0 in
        if authValue >= 10000 then "High Value"
        else if authValue >= 2500 then "Medium Value"
        else if authValue >= 500 then "Low Value"
        else if authValue > 0 then "Minimal Value"
        else "No Authorization", type text),
    
    // Customer classification enhancement
    AddCustomerClassification = Table.AddColumn(AddAuthValueCategory, "CustomerClassification", each
        let
            accountClass = Text.Upper([AccountClass] ?? ""),
            customerFlag = Text.Upper([CustomerVehicleFlag] ?? "")
        in
        if customerFlag = "F" then "Fleet Customer"
        else if customerFlag = "C" then "Retail Customer"
        else if Text.Contains(accountClass, "FLEET") then "Fleet Customer"
        else if Text.Contains(accountClass, "RETAIL") then "Retail Customer"
        else if Text.Contains(accountClass, "INTERNAL") then "Internal Work"
        else if Text.Contains(accountClass, "WARRANTY") then "Warranty Customer"
        else "Standard Customer", type text),
    
    // ========================================================================
    // DATA QUALITY ASSESSMENT
    // ========================================================================
    /*
    PURPOSE: Assess data completeness for business intelligence validation
    APPROACH: Score based on critical field completeness
    BENEFIT: Data quality monitoring and validation for fact table development
    */
    
    AddDataQualityScore = Table.AddColumn(AddCustomerClassification, "DataQualityScore", each
        let
            score = 0 +
                (if [WorkOrder] <> null then 15 else 0) +
                (if [Branch] <> null and [Branch] <> "" then 15 else 0) +
                (if [CreatedOn] <> null then 15 else 0) +
                (if [ProgressStatus] <> null and [ProgressStatus] <> "" then 10 else 0) +
                (if [AccountNumber] <> null and [AccountNumber] <> "" then 10 else 0) +
                (if [AccountClass] <> null and [AccountClass] <> "" then 10 else 0) +
                (if [Franchise] <> null and [Franchise] <> "" then 10 else 0) +
                (if [EstimatedHours] <> null and [EstimatedHours] > 0 then 8 else 0) +
                (if [TaxRegion] <> null and [TaxRegion] <> "" then 4 else 0) +
                (if [Salesperson] <> null and [Salesperson] <> "" then 3 else 0)
        in
            score, type number),
    
    // ========================================================================
    // FINAL COLUMN CLEANUP AND ORGANIZATION
    // ========================================================================
    /*
    PURPOSE: Remove intermediate columns and organize final output
    APPROACH: Clean structure for fact table development
    BENEFIT: Optimal structure for downstream fact table processing
    */
    
    // Remove original flag columns (replaced with clean boolean versions)
    RemoveOriginalFlags = Table.RemoveColumns(AddDataQualityScore, 
        {"IsFieldService", "IsQuotation", "IsClosedIndicator"}),
    
    // Rename logical columns to final names
    RenameLogicalColumns = Table.RenameColumns(RemoveOriginalFlags, {
        {"FieldServiceFlag", "IsFieldService"},
        {"QuotationFlag", "IsQuotation"},
        {"ClosedFlag", "IsClosed"}
    }),
    
    // Text field cleaning for consistency
    CleanTextFields = Table.TransformColumns(RenameLogicalColumns, {
        {"Branch", Text.Trim}, {"Franchise", Text.Trim}, {"StockFranchise", Text.Trim},
        {"ProgressStatus", Text.Trim}, {"AccountClass", Text.Trim}, {"TaxRegion", Text.Trim},
        {"Salesperson", Text.Trim}, {"TeamCode", Text.Trim}
    })

in
    CleanTextFields

/*
============================================================================
🎯 COMPREHENSIVE ENHANCEMENT SUMMARY
============================================================================

✅ STRATEGIC ENHANCEMENTS ADDED:
• Equipment Intelligence: Franchise, StockFranchise for manufacturer analysis
• Financial Context: AuthorizationValue, PaymentMethod for financial intelligence
• Service Classification: IsFieldService, AccountClass for service type analysis
• Timeline Intelligence: EstimatedHours, ClosedDate for complete lifecycle tracking
• Geographic Intelligence: TaxRegion, TaxStatus for territory analysis
• Customer Intelligence: CustomerVehicleFlag, Salesperson for relationship analysis
• Operational Context: TeamCode, MarketingSource for operational intelligence

✅ BUSINESS LOGIC ENHANCEMENTS:
• ServiceTypeClassification: 7-category service type intelligence
• CustomerClassification: Enhanced customer type identification
• AuthValueCategory: Authorization value-based categorization
• Work Order Age: Calculated age in days for operational analysis
• Robust Boolean Conversion: Clean Y/N to true/false handling
• Data Quality Scoring: 100-point completeness assessment

✅ PERFORMANCE OPTIMIZATIONS:
• Strategic Column Selection: Maximum intelligence with optimal performance
• Efficient Data Types: Appropriate types for each field based on usage
• SQL Query Folding: Optimized for source system performance
• ModifiedDate Filtering: Maintains incremental refresh capability
• Text Field Cleaning: Consistent formatting for downstream processing

✅ FACT TABLE FOUNDATION:
• Complete work order master data for comprehensive fact table development
• Enhanced equipment and customer intelligence for cross-dimensional analysis
• Service type and geographic classifications for advanced business intelligence
• Financial authorization context for customer and service analysis
• Operational flags and categories for dashboard and reporting excellence

🚀 EXPECTED BUSINESS VALUE:
• Comprehensive Work Order Analytics: Complete lifecycle and performance tracking
• Advanced Customer Intelligence: Enhanced customer classification and relationship analysis
• Equipment Manufacturer Analysis: Franchise-specific service patterns and performance
• Territory Intelligence: Geographic analysis with tax region and market insights
• Service Mix Optimization: Field vs shop service patterns and resource utilization
• Financial Authorization Intelligence: Customer authorization patterns and credit analysis

============================================================================
*/