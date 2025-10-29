/*
============================================================================
DIM_CUSTOMERLIST - COMPREHENSIVE CUSTOMER MASTER DIMENSION
============================================================================

📋 TABLE OVERVIEW:
Purpose: Central customer dimension for all customer-related analysis and reporting
Grain: One row per customer account with complete contact and financial profile
Refresh Strategy: Full refresh with comprehensive data integration
Dependencies: Raw_ARMaster, Raw_Contact, Raw_ArMaster_Customer, Raw_ArMaster_Contact
Key Integration: Critical for Fact_WorkOrderHeader customer assignment logic

🎯 BUSINESS USE CASES:
• Customer Analytics: Segmentation, profitability analysis, retention tracking
• Financial Management: Credit monitoring, aging analysis, payment behavior
• Marketing Campaigns: Customer targeting, communication preferences, eligibility
• Sales Operations: Account management, territory planning, customer hierarchy
• Service Operations: Work order customer assignment with intelligent fallbacks
• Risk Management: Credit utilization monitoring, financial health assessment

📊 KEY FEATURES PROVIDED:
• Customer Identification: Multiple naming strategies for display flexibility
• Financial Intelligence: Credit utilization, risk scoring, aging analysis
• Business Segmentation: Customer tiers, trade types, account classifications
• Contact Management: Multi-channel communication preferences and readiness
• Data Quality Indicators: Completeness scoring and validation flags
• System Integration: Special customer records for work order type fallbacks

🔗 INTEGRATION POINTS:
• Fact_WorkOrderHeader: CustomerLookupKey matches AccountNumberText field
• Fact_CustomerPerformance: CustomerKey enables performance tracking
• Fact_InvoiceHeader: Customer billing and payment analysis
• Work Order Types: Special customers (-1 to -8) handle system scenarios
• Marketing Systems: IsMarketingEligible and PreferredContactMethod

📈 SEGMENTATION STRATEGY:
• Customer Tiers: Key Account > Premium > Standard > Basic (by credit limit)
• Financial Risk: Minimal > Low > Medium > High (by credit utilization)
• Trade Types: Retail, Fleet, Internal, Warranty, Policy, Billing, Excess, Misc
• Account Status: Active, Inactive, Hold, Closed
• Marketing Readiness: Email availability and active status

⚡ PERFORMANCE NOTES:
• Uses INNER JOINs for data completeness - review if customers missing
• Text cleaning applied efficiently in batch operations
• Special customer records created separately for performance
• Surrogate keys (CustomerKey) optimize fact table joins

🔧 MAINTENANCE GUIDELINES:
• Monitor INNER JOIN results - switch to LEFT JOIN if missing valid customers
• Review CustomerTier thresholds quarterly based on business growth
• Validate TradeType mappings when new work order types introduced
• Update communication preferences when new channels added
• Audit special customer records alignment with work order fallback logic

============================================================================
📈 REPORTING & ANALYTICS RECOMMENDATIONS
============================================================================

🎯 CUSTOMER ANALYTICS DASHBOARDS:
• Customer Portfolio: Distribution by tier, status, and trade type
• Financial Health: Credit utilization analysis and aging summaries
• Geographic Analysis: Territory performance and customer concentration
• Communication Audit: Contact completeness and marketing readiness

💼 SALES & MARKETING APPLICATIONS:
• Target List Generation: IsMarketingEligible + CustomerTier filtering
• Account Management: Key customer identification and contact prioritization
• Territory Planning: Geographic distribution and customer value analysis
• Campaign Effectiveness: Communication preference optimization

🔍 OPERATIONAL INTELLIGENCE:
• Work Order Assignment: CustomerLookupKey enables intelligent customer matching
• Credit Management: Real-time risk assessment and utilization monitoring
• Data Quality Monitoring: Customer record completeness tracking
• System Integration: Special customer handling for various business scenarios

============================================================================
*/

let
    // ========================================================================
    // STEP 1: FOUNDATION DATA INTEGRATION & CUSTOMER CORE
    // ========================================================================
    /*
    PURPOSE: Build comprehensive customer profile from multiple source systems
    BUSINESS LOGIC: Integrate AR master, contact info, customer details, and classifications
    JOIN STRATEGY: INNER JOINs ensure data completeness (monitor for missing customers)
    PERFORMANCE: Single-pass integration with efficient nested joins
    */
    
    // Start with ArMaster as the foundation (accounts receivable master)
    ArMaster = Raw_ARMaster,
    
    // INNER JOIN with Contact using ContactID for complete contact information
    JoinArMasterContact = Table.NestedJoin(
        ArMaster, {"ContactID"}, 
        Raw_Contact, {"ContactID"}, 
        "ContactInfo", JoinKind.Inner),
    
    // Extract essential contact information for customer communication
    ExpandContact = Table.ExpandTableColumn(JoinArMasterContact, "ContactInfo", {
        "LastName",       // Individual last name for personal accounts
        "FirstName",      // Individual first name for personal accounts  
        "CompanyName",    // Business name for corporate accounts
        "BusinessPhone",  // Primary business contact number
        "MobilePhone",    // Mobile contact for urgent communications
        "Email",          // Primary email for digital communications
        "Street",         // Primary address line 1
        "City",           // City for geographic analysis
        "State",          // State/province for territory management
        "PostalCode",     // ZIP/postal code for geographic segmentation
        "Country"         // Country for international account management
    }),
    
    // INNER JOIN with ArMaster_Customer for customer-specific business details
    JoinCustomerMaster = Table.NestedJoin(
        ExpandContact, {"ContactID"},
        Raw_ArMaster_Customer, {"ContactID"},
        "CustomerInfo", JoinKind.Inner),
    
    // Extract customer business relationship details
    ExpandCustomerMaster = Table.ExpandTableColumn(JoinCustomerMaster, "CustomerInfo", {
        "CustomerNumber",    // Secondary customer identifier
        "StatusCode",        // Account status (Active/Inactive/Hold/Closed)
        "AccountType",       // Account classification type
        "TradeType",         // Business relationship type (Retail/Fleet/etc.)
        "DiscountType",      // Pricing discount classification
        "TaxExemptNumber",   // Tax exemption identifier if applicable
        "Territory",         // Sales territory assignment
        "PriceLevel",        // Pricing tier assignment
        "CustomerNotes"      // Additional customer service notes
    }),
    
    // INNER JOIN with ArMaster_Contact for customer classification details
    JoinContactClass = Table.NestedJoin(
        ExpandCustomerMaster, {"ContactID"},
        Raw_ArMaster_Contact, {"ContactID"},
        "ContactClassInfo", JoinKind.Inner),

    // Extract customer classification for business segmentation
    ExpandContactClass = Table.ExpandTableColumn(JoinContactClass, "ContactClassInfo", {"ContactClass"}),
    
    // ========================================================================
    // STEP 2: SURROGATE KEY GENERATION & CORE IDENTIFICATION
    // ========================================================================
    /*
    PURPOSE: Create artificial primary key for optimal fact table joins
    BUSINESS BENEFIT: Enables efficient star schema relationships and referential integrity
    */
    
    // Add surrogate key starting from 1 (positive keys for real customers)
    AddSurrogateKey = Table.AddIndexColumn(ExpandContactClass, "CustomerKey", 1, 1, Int64.Type),
    
    // ========================================================================
    // STEP 3: INTELLIGENT CUSTOMER NAMING STRATEGY
    // ========================================================================
    /*
    PURPOSE: Create consistent customer display names following business rules
    BUSINESS LOGIC: Priority to company name, fallback to "LastName, FirstName" format
    MATCHES: Original SQL CASE statement logic exactly
    */
    
    // Build primary customer name using business naming conventions
    AddCustomerName = Table.AddColumn(AddSurrogateKey, "Customer", each
        if ([CompanyName] ?? "") <> "" then [CompanyName]
        else ([LastName] ?? "") & ", " & ([FirstName] ?? ""), type text),
    
    // ========================================================================
    // STEP 4: BUSINESS CLASSIFICATION & INTELLIGENCE FRAMEWORK
    // ========================================================================
    /*
    PURPOSE: Add comprehensive business intelligence and classification metrics
    CATEGORIES: Customer value, account status, company type, financial health
    BUSINESS BENEFIT: Enables sophisticated segmentation and targeting strategies
    */
    
    // Key Customer identification and trade type intelligence
    AddKeyCustomerFlag = Table.AddColumn(AddCustomerName, "IsKeyCustomer", each 
        ([ContactClass] ?? "") = "KEY", type logical),
    
    // Trade type business descriptions with comprehensive mapping
    AddCustomerTypeDescription = Table.AddColumn(AddKeyCustomerFlag, "CustomerTypeDescription", each 
        let tradeType = Text.Upper(Text.Trim([TradeType] ?? ""))
        in if tradeType = "E" then "Excess"           // Excess inventory sales
        else if tradeType = "F" then "Fleet"          // Fleet account management
        else if tradeType = "I" then "Internal"       // Internal company work
        else if tradeType = "P" then "Policy"         // Policy-related work
        else if tradeType = "B" then "Billing"        // Billing adjustments
        else if tradeType = "R" then "Retail"         // Standard retail customers
        else if tradeType = "S" then "Misc"           // Miscellaneous work
        else if tradeType = "W" then "Warranty"       // Warranty claim work
        else if tradeType <> "" then tradeType        // Pass through unknown codes
        else "Unknown",                               // Default for empty/null
        type text),
    
    // Account status business descriptions
    AddAccountStatus = Table.AddColumn(AddCustomerTypeDescription, "AccountStatus", each 
        let statusCode = Text.Upper(Text.Trim([StatusCode] ?? ""))
        in if statusCode = "A" then "Active"          // Active accounts
        else if statusCode = "I" then "Inactive"      // Inactive accounts
        else if statusCode = "H" then "Hold"          // Accounts on hold
        else if statusCode = "C" then "Closed"        // Closed accounts
        else if statusCode <> "" then statusCode      // Pass through unknown codes
        else "Unknown",                               // Default for empty/null
        type text),
    
    // Company vs individual account classification
    AddIsCompany = Table.AddColumn(AddAccountStatus, "IsCompany", each 
        ([CompanyName] ?? "") <> "", type logical),
    
    // Credit availability indicator
    AddHasCreditLimit = Table.AddColumn(AddIsCompany, "HasCreditLimit", each 
        ([CreditLimit] ?? 0) > 0, type logical),
    
    // ========================================================================
    // STEP 5: ADVANCED FINANCIAL HEALTH & RISK ASSESSMENT
    // ========================================================================
    /*
    PURPOSE: Calculate sophisticated financial health indicators for risk management
    METRICS: Credit utilization, risk levels, overdue analysis
    BUSINESS BENEFIT: Proactive credit management and customer retention
    */
    
    // Credit utilization calculation with null safety
    AddCreditUtilization = Table.AddColumn(AddHasCreditLimit, "CreditUtilization", each 
        let 
            creditLimit = [CreditLimit] ?? 0,
            accountBalance = [AccountBalance] ?? 0
        in
            if creditLimit > 0 then accountBalance / creditLimit else 0, 
        type number),
    
    // Financial risk level assessment based on credit utilization
    AddFinancialRiskLevel = Table.AddColumn(AddCreditUtilization, "FinancialRiskLevel", each 
        let utilization = [CreditUtilization] ?? 0
        in if utilization > 0.9 then "High"          // >90% utilization - high risk
        else if utilization > 0.7 then "Medium"      // >70% utilization - medium risk
        else if utilization > 0.5 then "Low"         // >50% utilization - low risk
        else "Minimal",                               // ≤50% utilization - minimal risk
        type text),
    
    // Overdue balance detection across all aging buckets
    AddHasOverdueBalance = Table.AddColumn(AddFinancialRiskLevel, "HasOverdueBalance", each 
        (([Aging30] ?? 0) > 0) or 
        (([Aging60] ?? 0) > 0) or 
        (([Aging90] ?? 0) > 0), 
        type logical),
    
    // ========================================================================
    // STEP 6: CUSTOMER VALUE SEGMENTATION & TIERING STRATEGY
    // ========================================================================
    /*
    PURPOSE: Sophisticated customer segmentation for account management prioritization
    BUSINESS LOGIC: Key customers prioritized, then by credit limit thresholds
    BENEFIT: Enables differentiated service levels and resource allocation
    */
    
    // Multi-tier customer classification system
    AddCustomerTier = Table.AddColumn(AddHasOverdueBalance, "CustomerTier", each 
        let creditLimit = [CreditLimit] ?? 0
        in if ([IsKeyCustomer] ?? false) = true then "Key Account"      // Manually designated key accounts
        else if creditLimit >= 50000 then "Premium"                     // High credit limit accounts
        else if creditLimit >= 10000 then "Standard"                    // Medium credit limit accounts
        else "Basic",                                                    // Low/no credit limit accounts
        type text),
    
    // High-value customer identification for priority handling
    AddIsHighValue = Table.AddColumn(AddCustomerTier, "IsHighValue", each 
        List.Contains({"Key Account", "Premium"}, [CustomerTier] ?? ""), type logical),
    
    // ========================================================================
    // STEP 7: MARKETING & COMMUNICATION INTELLIGENCE
    // ========================================================================
    /*
    PURPOSE: Enable sophisticated marketing campaigns and communication strategies
    CRITERIA: Email availability, account status, communication preferences
    BUSINESS BENEFIT: Targeted marketing and optimal customer communication
    */
    
    // Marketing campaign eligibility assessment
    AddIsMarketingEligible = Table.AddColumn(AddIsHighValue, "IsMarketingEligible", each 
        (([Email] ?? "") <> "") and (([AccountStatus] ?? "") = "Active"), type logical),
    
    // Optimal communication method determination
    AddPreferredContactMethod = Table.AddColumn(AddIsMarketingEligible, "PreferredContactMethod", each 
        if ([Email] ?? "") <> "" then "Email"                    // Email preferred for efficiency
        else if ([MobilePhone] ?? "") <> "" then "Mobile"        // Mobile for urgent communications
        else if ([BusinessPhone] ?? "") <> "" then "Business Phone"  // Business phone for formal contact
        else "Mail",                                              // Physical mail as last resort
        type text),
    
    // ========================================================================
    // STEP 8: COMPREHENSIVE CUSTOMER IDENTIFICATION FRAMEWORK
    // ========================================================================
    /*
    PURPOSE: Create multiple naming and identification strategies for reporting flexibility
    BUSINESS BENEFIT: Supports various dashboard and report requirements
    */
    
    // Full name construction for individual customers
    AddFullName = Table.AddColumn(AddPreferredContactMethod, "FullName", each 
        let 
            firstName = Text.Trim([FirstName] ?? ""),
            lastName = Text.Trim([LastName] ?? "")
        in
            if firstName <> "" and lastName <> "" then firstName & " " & lastName
            else if lastName <> "" then lastName  
            else if firstName <> "" then firstName
            else "", 
        type text),
    
    // Primary name for business displays (company priority)
    AddPrimaryName = Table.AddColumn(AddFullName, "PrimaryName", each 
        let companyName = Text.Trim([CompanyName] ?? ""),
            customerName = Text.Trim([Customer] ?? "")
        in
            if companyName <> "" then companyName
            else if customerName <> "" then customerName
            else "Account " & Text.From([AccountNumber]), 
        type text),
    
    // Display name with intelligent fallback logic
    AddDisplayName = Table.AddColumn(AddPrimaryName, "DisplayName", each 
        let 
            primaryName = [PrimaryName] ?? "",
            accountNumber = Text.From([AccountNumber]),
            customerType = [CustomerTypeDescription] ?? "Customer"
        in
            if primaryName <> ("Account " & accountNumber) then primaryName
            else customerType & " " & accountNumber, 
        type text),
    
    // Primary phone number with mobile preference
    AddPrimaryPhone = Table.AddColumn(AddDisplayName, "PrimaryPhone", each 
        if ([MobilePhone] ?? "") <> "" then [MobilePhone]
        else if ([BusinessPhone] ?? "") <> "" then [BusinessPhone]
        else "", 
        type text),
    
    // ========================================================================
    // STEP 9: DATA QUALITY & STANDARDIZATION FRAMEWORK
    // ========================================================================
    /*
    PURPOSE: Ensure consistent data quality and standardization across all text fields
    APPROACH: Batch transformation for optimal performance
    BUSINESS BENEFIT: Reliable reporting and consistent customer experience
    */
    
    // Comprehensive text field cleaning and standardization
    CleanTextFields = Table.TransformColumns(AddPrimaryPhone, {
        {"Customer", each Text.Proper(Text.Trim(_ ?? "")), type text},           // Proper case for names
        {"CompanyName", each Text.Proper(Text.Trim(_ ?? "")), type text},        // Proper case for companies
        {"FirstName", each Text.Proper(Text.Trim(_ ?? "")), type text},          // Proper case for first names
        {"LastName", each Text.Proper(Text.Trim(_ ?? "")), type text},           // Proper case for last names
        {"Street", each Text.Proper(Text.Trim(_ ?? "")), type text},             // Proper case for addresses
        {"City", each Text.Proper(Text.Trim(_ ?? "")), type text},               // Proper case for cities
        {"State", each Text.Upper(Text.Trim(_ ?? "")), type text},               // Upper case for state codes
        {"PostalCode", each Text.Trim(_ ?? ""), type text},                      // Trimmed postal codes
        {"Email", each Text.Lower(Text.Trim(_ ?? "")), type text},               // Lower case for emails
        {"TradeType", each Text.Upper(Text.Trim(_ ?? "")), type text},           // Upper case for codes
        {"ContactClass", each Text.Upper(Text.Trim(_ ?? "")), type text}         // Upper case for classifications
    }),
    
    // ========================================================================
    // STEP 10: LOOKUP KEY GENERATION & SYSTEM INTEGRATION
    // ========================================================================
    /*
    PURPOSE: Create text-based lookup keys for fact table joins and system integration
    CRITICAL: AccountNumberText is essential for Fact_WorkOrderHeader customer assignment
    */
    
    // Account number as text for string-based lookups
    AddAccountNumberText = Table.AddColumn(CleanTextFields, "AccountNumberText", each 
        Text.From([AccountNumber]), type text),
    
    // Customer number as text for additional lookup scenarios
    AddCustomerNumberText = Table.AddColumn(AddAccountNumberText, "CustomerNumberText", each 
        if [CustomerNumber] <> null then Text.From([CustomerNumber]) else "", type text),
    
    // ========================================================================
    // STEP 11: SCHEMA COMPLETENESS & COMPATIBILITY
    // ========================================================================
    /*
    PURPOSE: Add placeholder fields for complete schema compatibility
    RATIONALE: Ensures compatibility with existing reports and future enhancements
    */
    
    // Add missing address and contact fields for complete customer profile
    AddMissingContactFields = Table.AddColumn(
        Table.AddColumn(AddCustomerNumberText, "Street2", each "", type text),
        "HomePhone", each "", type text),
    
    // Add account classification placeholder for future business logic
    AddAccountClass = Table.AddColumn(AddMissingContactFields, "Account_Class", each "", type text),
    
    // ========================================================================
    // STEP 12: DATA QUALITY SCORING & COMPLETENESS ASSESSMENT
    // ========================================================================
    /*
    PURPOSE: Provide data quality indicators for customer record assessment
    SCORING: 0-100 scale based on critical field completeness
    BUSINESS BENEFIT: Identify customers needing data enhancement
    */
    
    AddDataQualityScore = Table.AddColumn(AddAccountClass, "DataQualityScore", each
        let
            // Core identification (25 points)
            hasName = if (([CompanyName] ?? "") <> "" or ([FirstName] ?? "") <> "") then 25 else 0,
            
            // Contact information (25 points)
            hasContact = if (([Email] ?? "") <> "" or ([BusinessPhone] ?? "") <> "" or ([MobilePhone] ?? "") <> "") then 25 else 0,
            
            // Address information (25 points)  
            hasAddress = if (([Street] ?? "") <> "" and ([City] ?? "") <> "" and ([State] ?? "") <> "") then 25 else 0,
            
            // Financial information (25 points)
            hasFinancial = if (([CreditLimit] ?? 0) > 0 or ([AccountBalance] ?? 0) <> 0) then 25 else 0
        in
            hasName + hasContact + hasAddress + hasFinancial,
        type number),
    
    // ========================================================================
    // STEP 13: OPTIMIZED COLUMN SELECTION & ORGANIZATION
    // ========================================================================
    /*
    PURPOSE: Select and organize final columns for optimal reporting and performance
    STRUCTURE: Keys, identifiers, names, business data, contact info, analytics
    */
    
    SelectFinalColumns = Table.SelectColumns(AddDataQualityScore, {
        // ===== PRIMARY KEYS & IDENTIFIERS =====
        "CustomerKey",              // Surrogate key for fact table joins
        "AccountNumber",            // Primary business account identifier
        "AccountNumberText",        // Text version for string-based lookups
        "CustomerNumber",           // Secondary customer identifier
        "CustomerNumberText",       // Text version of customer number
        "ContactID",                // Contact system identifier
        
        // ===== CUSTOMER IDENTIFICATION & NAMING =====
        "DisplayName",              // Primary display name for reports
        "Customer",                 // Core customer name (will rename to CustomerName)
        "PrimaryName",              // Business primary name
        "CompanyName",              // Company name for corporate accounts
        "FirstName",                // Individual first name
        "LastName",                 // Individual last name
        "FullName",                 // Complete individual name
        
        // ===== BUSINESS CLASSIFICATION =====
        "TradeType",                // Business relationship type code
        "CustomerTypeDescription",  // Trade type description
        "StatusCode",               // Account status code
        "AccountStatus",            // Account status description
        "AccountType",              // Account type classification
        "Territory",                // Sales territory assignment
        
        // ===== FINANCIAL INFORMATION =====
        "CreditLimit",              // Credit limit amount
        "AccountBalance",           // Current account balance
        "Aging30",                  // 30-day aging amount
        "Aging60",                  // 60-day aging amount
        "Aging90",                  // 90+ day aging amount
        "CreditTerm",               // Payment terms
        "PaymentMethod",            // Preferred payment method
        "PriceLevel",               // Pricing level assignment
        
        // ===== CONTACT INFORMATION =====
        "Street",                   // Primary address line 1
        "Street2",                  // Secondary address line
        "City",                     // City
        "State",                    // State/province
        "PostalCode",               // ZIP/postal code
        "Country",                  // Country
        "Email",                    // Email address
        "PrimaryPhone",             // Primary phone number
        "BusinessPhone",            // Business phone number
        "MobilePhone",              // Mobile phone number
        "HomePhone",                // Home phone number
        
        // ===== BUSINESS INTELLIGENCE FLAGS =====
        "IsCompany",                // Company vs individual flag
        "HasCreditLimit",           // Credit limit availability flag
        "Account_Class",            // Account classification
        "ContactClass",             // Contact classification
        "IsKeyCustomer",            // Key customer designation
        
        // ===== FINANCIAL ANALYTICS =====
        "CreditUtilization",        // Credit utilization ratio
        "FinancialRiskLevel",       // Financial risk assessment
        "HasOverdueBalance",        // Overdue balance indicator
        
        // ===== CUSTOMER SEGMENTATION =====
        "CustomerTier",             // Customer tier classification
        "IsHighValue",              // High-value customer flag
        "IsMarketingEligible",      // Marketing campaign eligibility
        "PreferredContactMethod",   // Optimal communication method
        
        // ===== ADDITIONAL BUSINESS DATA =====
        "DiscountType",             // Discount classification
        "TaxExemptNumber",          // Tax exemption number
        "CustomerNotes",            // Customer service notes
        
        // ===== DATA QUALITY INDICATORS =====
        "DataQualityScore"          // Data completeness score (0-100)
    }),
    
    // ========================================================================
    // STEP 14: COLUMN RENAMING FOR CONSISTENCY
    // ========================================================================
    /*
    PURPOSE: Ensure consistent naming conventions across dimension tables
    STANDARD: CustomerName instead of Customer for clarity
    */
    
    RenameCustomerColumn = Table.RenameColumns(SelectFinalColumns, {{"Customer", "CustomerName"}}),
    
    // ========================================================================
    // STEP 15: DATA TYPE OPTIMIZATION
    // ========================================================================
    /*
    PURPOSE: Optimize storage and query performance with appropriate data types
    STRATEGY: Consistent types across all customer-related fields
    */
    
    SetDataTypes = Table.TransformColumnTypes(RenameCustomerColumn, {
        // Keys and identifiers
        {"CustomerKey", Int64.Type}, {"AccountNumber", type text}, {"AccountNumberText", type text}, 
        {"CustomerNumber", type text}, {"CustomerNumberText", type text}, {"ContactID", type text},
        
        // Names and identification
        {"DisplayName", type text}, {"CustomerName", type text}, {"PrimaryName", type text},
        {"CompanyName", type text}, {"FirstName", type text}, {"LastName", type text}, {"FullName", type text},
        
        // Business classification
        {"TradeType", type text}, {"CustomerTypeDescription", type text}, 
        {"StatusCode", type text}, {"AccountStatus", type text}, {"AccountType", type text}, {"Territory", type text},
        
        // Financial data
        {"CreditLimit", type number}, {"AccountBalance", type number}, {"Aging30", type number}, 
        {"Aging60", type number}, {"Aging90", type number}, {"CreditTerm", type text}, 
        {"PaymentMethod", type text}, {"PriceLevel", type text},
        
        // Contact information
        {"Street", type text}, {"Street2", type text}, {"City", type text}, {"State", type text}, 
        {"PostalCode", type text}, {"Country", type text}, {"Email", type text}, {"PrimaryPhone", type text}, 
        {"BusinessPhone", type text}, {"MobilePhone", type text}, {"HomePhone", type text},
        
        // Business intelligence flags
        {"IsCompany", type logical}, {"HasCreditLimit", type logical}, {"Account_Class", type text}, 
        {"ContactClass", type text}, {"IsKeyCustomer", type logical},
        
        // Financial analytics
        {"CreditUtilization", type number}, {"FinancialRiskLevel", type text}, {"HasOverdueBalance", type logical},
        
        // Customer segmentation
        {"CustomerTier", type text}, {"IsHighValue", type logical}, {"IsMarketingEligible", type logical}, 
        {"PreferredContactMethod", type text},
        
        // Additional business data
        {"DiscountType", type text}, {"TaxExemptNumber", type text}, {"CustomerNotes", type text},
        
        // Data quality
        {"DataQualityScore", type number}
    }),
    
    // ========================================================================
    // STEP 16: REAL CUSTOMER DATA PREPARATION
    // ========================================================================
    /*
    PURPOSE: Sort real customer data before combining with special system customers
    RATIONALE: Ensures consistent ordering and easy identification of real vs system customers
    */
    
    SortRealCustomers = Table.Sort(SetDataTypes, {{"AccountNumber", Order.Ascending}}),
    
    // ========================================================================
    // STEP 17: SPECIAL SYSTEM CUSTOMER CREATION
    // ========================================================================
    /*
    PURPOSE: Create special customer records for work order type fallback scenarios
    BUSINESS LOGIC: Negative CustomerKey values (-1 to -8) for system customers
    INTEGRATION: Critical for Fact_WorkOrderHeader CustomerLookupKey logic
    MAPPING: UNKNOWN, INTERNAL, WARRANTY, FLEET, EXCESS, POLICY, BILLING, MISC
    */
    
    SpecialCustomers = Table.FromRecords({
        // Unknown customer fallback (CustomerKey = -1)
        [CustomerKey = -1, AccountNumber = "UNKNOWN", AccountNumberText = "UNKNOWN", 
         CustomerNumber = "", CustomerNumberText = "", ContactID = "", 
         DisplayName = "Unknown Customer", CustomerName = "Unknown Customer", 
         PrimaryName = "Unknown Customer", CompanyName = "Unknown Customer", 
         FirstName = "", LastName = "", FullName = "",
         TradeType = "U", CustomerTypeDescription = "Unknown", 
         StatusCode = "", AccountStatus = "Unknown", AccountType = "", Territory = "", 
         CreditLimit = 0, AccountBalance = 0, Aging30 = 0, Aging60 = 0, Aging90 = 0, 
         CreditTerm = "", PaymentMethod = "", PriceLevel = "", 
         Street = "", Street2 = "", City = "", State = "", PostalCode = "", Country = "", 
         Email = "", PrimaryPhone = "", BusinessPhone = "", MobilePhone = "", HomePhone = "",
         IsCompany = false, HasCreditLimit = false, Account_Class = "", ContactClass = "", IsKeyCustomer = false, 
         CreditUtilization = 0, FinancialRiskLevel = "Minimal", HasOverdueBalance = false, 
         CustomerTier = "Basic", IsHighValue = false, IsMarketingEligible = false, PreferredContactMethod = "Mail", 
         DiscountType = "", TaxExemptNumber = "", CustomerNotes = "", DataQualityScore = 25],
        
        // Internal work customer (CustomerKey = -2)
        [CustomerKey = -2, AccountNumber = "INTERNAL", AccountNumberText = "INTERNAL", 
         CustomerNumber = "", CustomerNumberText = "", ContactID = "", 
         DisplayName = "Internal Work", CustomerName = "Internal Work", 
         PrimaryName = "Internal Work", CompanyName = "Internal", 
         FirstName = "", LastName = "", FullName = "",
         TradeType = "I", CustomerTypeDescription = "Internal", 
         StatusCode = "A", AccountStatus = "Active", AccountType = "INT", Territory = "", 
         CreditLimit = null, AccountBalance = null, Aging30 = null, Aging60 = null, Aging90 = null, 
         CreditTerm = "", PaymentMethod = "", PriceLevel = "", 
         Street = "", Street2 = "", City = "", State = "", PostalCode = "", Country = "", 
         Email = "", PrimaryPhone = "", BusinessPhone = "", MobilePhone = "", HomePhone = "",
         IsCompany = false, HasCreditLimit = false, Account_Class = "INT", ContactClass = "", IsKeyCustomer = false, 
         CreditUtilization = 0, FinancialRiskLevel = "Minimal", HasOverdueBalance = false, 
         CustomerTier = "Basic", IsHighValue = false, IsMarketingEligible = false, PreferredContactMethod = "Mail", 
         DiscountType = "", TaxExemptNumber = "", CustomerNotes = "", DataQualityScore = 50],
        
        // Warranty work customer (CustomerKey = -3)
        [CustomerKey = -3, AccountNumber = "WARRANTY", AccountNumberText = "WARRANTY", 
         CustomerNumber = "", CustomerNumberText = "", ContactID = "", 
         DisplayName = "Warranty Work", CustomerName = "Warranty Work", 
         PrimaryName = "Warranty Work", CompanyName = "Warranty", 
         FirstName = "", LastName = "", FullName = "",
         TradeType = "W", CustomerTypeDescription = "Warranty", 
         StatusCode = "A", AccountStatus = "Active", AccountType = "WAR", Territory = "", 
         CreditLimit = null, AccountBalance = null, Aging30 = null, Aging60 = null, Aging90 = null,
         CreditTerm = "", PaymentMethod = "", PriceLevel = "", 
         Street = "", Street2 = "", City = "", State = "", PostalCode = "", Country = "", 
         Email = "", PrimaryPhone = "", BusinessPhone = "", MobilePhone = "", HomePhone = "",
         IsCompany = false, HasCreditLimit = false, Account_Class = "WAR", ContactClass = "", IsKeyCustomer = false, 
         CreditUtilization = 0, FinancialRiskLevel = "Minimal", HasOverdueBalance = false, 
         CustomerTier = "Basic", IsHighValue = false, IsMarketingEligible = false, PreferredContactMethod = "Mail", 
         DiscountType = "", TaxExemptNumber = "", CustomerNotes = "", DataQualityScore = 50],
        
        // Fleet account customer (CustomerKey = -4)
        [CustomerKey = -4, AccountNumber = "FLEET", AccountNumberText = "FLEET", 
         CustomerNumber = "", CustomerNumberText = "", ContactID = "", 
         DisplayName = "Fleet Account", CustomerName = "Fleet Account", 
         PrimaryName = "Fleet Account", CompanyName = "Fleet", 
         FirstName = "", LastName = "", FullName = "",
         TradeType = "F", CustomerTypeDescription = "Fleet", 
         StatusCode = "A", AccountStatus = "Active", AccountType = "FLT", Territory = "", 
         CreditLimit = null, AccountBalance = null, Aging30 = null, Aging60 = null, Aging90 = null,
         CreditTerm = "", PaymentMethod = "", PriceLevel = "", 
         Street = "", Street2 = "", City = "", State = "", PostalCode = "", Country = "", 
         Email = "", PrimaryPhone = "", BusinessPhone = "", MobilePhone = "", HomePhone = "",
         IsCompany = false, HasCreditLimit = false, Account_Class = "FLT", ContactClass = "", IsKeyCustomer = false, 
         CreditUtilization = 0, FinancialRiskLevel = "Minimal", HasOverdueBalance = false, 
         CustomerTier = "Basic", IsHighValue = false, IsMarketingEligible = false, PreferredContactMethod = "Mail", 
         DiscountType = "", TaxExemptNumber = "", CustomerNotes = "", DataQualityScore = 50],
        
        // Excess work customer (CustomerKey = -5)
        [CustomerKey = -5, AccountNumber = "EXCESS", AccountNumberText = "EXCESS", 
         CustomerNumber = "", CustomerNumberText = "", ContactID = "", 
         DisplayName = "Excess Work", CustomerName = "Excess Work", 
         PrimaryName = "Excess Work", CompanyName = "Excess", 
         FirstName = "", LastName = "", FullName = "",
         TradeType = "E", CustomerTypeDescription = "Excess", 
         StatusCode = "A", AccountStatus = "Active", AccountType = "EXC", Territory = "", 
         CreditLimit = null, AccountBalance = null, Aging30 = null, Aging60 = null, Aging90 = null,
         CreditTerm = "", PaymentMethod = "", PriceLevel = "", 
         Street = "", Street2 = "", City = "", State = "", PostalCode = "", Country = "", 
         Email = "", PrimaryPhone = "", BusinessPhone = "", MobilePhone = "", HomePhone = "",
         IsCompany = false, HasCreditLimit = false, Account_Class = "EXC", ContactClass = "", IsKeyCustomer = false, 
         CreditUtilization = 0, FinancialRiskLevel = "Minimal", HasOverdueBalance = false, 
         CustomerTier = "Basic", IsHighValue = false, IsMarketingEligible = false, PreferredContactMethod = "Mail", 
         DiscountType = "", TaxExemptNumber = "", CustomerNotes = "", DataQualityScore = 50],
        
        // Policy work customer (CustomerKey = -6)
        [CustomerKey = -6, AccountNumber = "POLICY", AccountNumberText = "POLICY", 
         CustomerNumber = "", CustomerNumberText = "", ContactID = "", 
         DisplayName = "Policy Work", CustomerName = "Policy Work", 
         PrimaryName = "Policy Work", CompanyName = "Policy", 
         FirstName = "", LastName = "", FullName = "",
         TradeType = "P", CustomerTypeDescription = "Policy", 
         StatusCode = "A", AccountStatus = "Active", AccountType = "POL", Territory = "", 
         CreditLimit = null, AccountBalance = null, Aging30 = null, Aging60 = null, Aging90 = null,
         CreditTerm = "", PaymentMethod = "", PriceLevel = "", 
         Street = "", Street2 = "", City = "", State = "", PostalCode = "", Country = "", 
         Email = "", PrimaryPhone = "", BusinessPhone = "", MobilePhone = "", HomePhone = "",
         IsCompany = false, HasCreditLimit = false, Account_Class = "POL", ContactClass = "", IsKeyCustomer = false, 
         CreditUtilization = 0, FinancialRiskLevel = "Minimal", HasOverdueBalance = false, 
         CustomerTier = "Basic", IsHighValue = false, IsMarketingEligible = false, PreferredContactMethod = "Mail", 
         DiscountType = "", TaxExemptNumber = "", CustomerNotes = "", DataQualityScore = 50],
        
        // Billing account customer (CustomerKey = -7)
        [CustomerKey = -7, AccountNumber = "BILLING", AccountNumberText = "BILLING", 
         CustomerNumber = "", CustomerNumberText = "", ContactID = "", 
         DisplayName = "Billing Account", CustomerName = "Billing Account", 
         PrimaryName = "Billing Account", CompanyName = "Billing", 
         FirstName = "", LastName = "", FullName = "",
         TradeType = "B", CustomerTypeDescription = "Billing", 
         StatusCode = "A", AccountStatus = "Active", AccountType = "BIL", Territory = "", 
         CreditLimit = null, AccountBalance = null, Aging30 = null, Aging60 = null, Aging90 = null,
         CreditTerm = "", PaymentMethod = "", PriceLevel = "", 
         Street = "", Street2 = "", City = "", State = "", PostalCode = "", Country = "", 
         Email = "", PrimaryPhone = "", BusinessPhone = "", MobilePhone = "", HomePhone = "",
         IsCompany = false, HasCreditLimit = false, Account_Class = "BIL", ContactClass = "", IsKeyCustomer = false, 
         CreditUtilization = 0, FinancialRiskLevel = "Minimal", HasOverdueBalance = false, 
         CustomerTier = "Basic", IsHighValue = false, IsMarketingEligible = false, PreferredContactMethod = "Mail", 
         DiscountType = "", TaxExemptNumber = "", CustomerNotes = "", DataQualityScore = 50],
        
        // Miscellaneous work customer (CustomerKey = -8)
        [CustomerKey = -8, AccountNumber = "MISC", AccountNumberText = "MISC", 
         CustomerNumber = "", CustomerNumberText = "", ContactID = "", 
         DisplayName = "Miscellaneous", CustomerName = "Miscellaneous", 
         PrimaryName = "Miscellaneous", CompanyName = "Miscellaneous", 
         FirstName = "", LastName = "", FullName = "",
         TradeType = "S", CustomerTypeDescription = "Misc", 
         StatusCode = "A", AccountStatus = "Active", AccountType = "MSC", Territory = "", 
         CreditLimit = null, AccountBalance = null, Aging30 = null, Aging60 = null, Aging90 = null,
         CreditTerm = "", PaymentMethod = "", PriceLevel = "", 
         Street = "", Street2 = "", City = "", State = "", PostalCode = "", Country = "", 
         Email = "", PrimaryPhone = "", BusinessPhone = "", MobilePhone = "", HomePhone = "",
         IsCompany = false, HasCreditLimit = false, Account_Class = "MSC", ContactClass = "", IsKeyCustomer = false, 
         CreditUtilization = 0, FinancialRiskLevel = "Minimal", HasOverdueBalance = false, 
         CustomerTier = "Basic", IsHighValue = false, IsMarketingEligible = false, PreferredContactMethod = "Mail", 
         DiscountType = "", TaxExemptNumber = "", CustomerNotes = "", DataQualityScore = 50]
    }),
    
    // Apply consistent data types to special customers
    SpecialCustomersTyped = Table.TransformColumnTypes(SpecialCustomers, {
        {"CustomerKey", Int64.Type}, {"AccountNumber", type text}, {"AccountNumberText", type text}, 
        {"CustomerNumber", type text}, {"CustomerNumberText", type text}, {"ContactID", type text},
        {"DisplayName", type text}, {"CustomerName", type text}, {"PrimaryName", type text},
        {"CompanyName", type text}, {"FirstName", type text}, {"LastName", type text}, {"FullName", type text},
        {"TradeType", type text}, {"CustomerTypeDescription", type text}, 
        {"StatusCode", type text}, {"AccountStatus", type text}, {"AccountType", type text}, {"Territory", type text},
        {"CreditLimit", type number}, {"AccountBalance", type number}, {"Aging30", type number}, 
        {"Aging60", type number}, {"Aging90", type number}, {"CreditTerm", type text}, 
        {"PaymentMethod", type text}, {"PriceLevel", type text},
        {"Street", type text}, {"Street2", type text}, {"City", type text}, {"State", type text}, 
        {"PostalCode", type text}, {"Country", type text}, {"Email", type text}, {"PrimaryPhone", type text}, 
        {"BusinessPhone", type text}, {"MobilePhone", type text}, {"HomePhone", type text},
        {"IsCompany", type logical}, {"HasCreditLimit", type logical}, {"Account_Class", type text}, 
        {"ContactClass", type text}, {"IsKeyCustomer", type logical},
        {"CreditUtilization", type number}, {"FinancialRiskLevel", type text}, {"HasOverdueBalance", type logical},
        {"CustomerTier", type text}, {"IsHighValue", type logical}, {"IsMarketingEligible", type logical}, 
        {"PreferredContactMethod", type text},
        {"DiscountType", type text}, {"TaxExemptNumber", type text}, {"CustomerNotes", type text},
        {"DataQualityScore", type number}
    }),
    
    // ========================================================================
    // STEP 18: FINAL INTEGRATION & OPTIMIZATION
    // ========================================================================
    /*
    PURPOSE: Combine special system customers with real customer data
    STRATEGY: Special customers first (negative keys), then real customers (positive keys)
    BUSINESS BENEFIT: Easy identification and consistent system behavior
    */
    
    // Combine special system customers with real customer data
    CombinedCustomers = Table.Combine({SpecialCustomersTyped, SortRealCustomers}),
    
    // Final sort to ensure special customers appear at top, then real customers by account number
    FinalSort = Table.Sort(CombinedCustomers, {{"CustomerKey", Order.Ascending}})

in
    FinalSort