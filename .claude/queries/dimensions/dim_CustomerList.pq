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
• Fact_Service_Invoices: CustomerVehicleFlag determines Stock (-9) vs Customer assignment
• Work Order Types: Special customers (-1 to -9) handle system scenarios
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
🔧 SPECIAL CUSTOMER ASSIGNMENT LOGIC (SERVICE INVOICES)
============================================================================

BACKGROUND (Investigation 2026-02-09):
Service invoices with BillToAccount = '0' represent work on dealership-owned
equipment (stock), not customer equipment. This was causing ~$19M to appear
as "Unknown Customer" in the Customer Anatomy report.

ROOT CAUSE:
- WKROFILE.CustomerVehicleFlag = 'S' indicates Stock equipment (dealership-owned)
- WKROFILE.CustomerVehicleFlag = 'C' indicates Customer equipment
- Stock equipment has no customer in ArMaster (it belongs to the dealership)
- BillToAccount = '0' because there's no customer to bill

SPECIAL CUSTOMER KEYS:
| Key | AccountNumber | Purpose                                              |
|-----|---------------|------------------------------------------------------|
| -1  | UNKNOWN       | Unmatched customers (data quality issue)             |
| -2  | INTERNAL      | Generic internal work                                |
| -3  | WARRANTY      | Warranty claims                                      |
| -4  | FLEET         | Fleet customers                                      |
| -5  | EXCESS        | Excess work                                          |
| -6  | POLICY        | Policy adjustments                                   |
| -7  | BILLING       | Billing purposes                                     |
| -8  | MISC          | Miscellaneous                                        |
| -9  | STOCK         | Stock Equipment (demos, PDI, damaged in transit)     |

FACT TABLE CUSTOMER ASSIGNMENT (SERVICE):
1. Join Invoice → wkothsub → WKROFILE to get CustomerVehicleFlag
2. If CustomerVehicleFlag = 'S' → CustomerKey = -9 (Stock Equipment)
3. If CustomerVehicleFlag = 'C' → Use normal CustomerLookup matching
4. If no match found → CustomerKey = -1 (Unknown Customer)

STOCK EQUIPMENT EXAMPLES ($44M in service revenue):
- Demo units being serviced
- Equipment damaged in transit (before delivery to customer)
- PDI (Pre-Delivery Inspection) work
- Units awaiting delivery on dealer lot
- Company-owned shop equipment

REPORTING FILTER GUIDANCE:
- Customer Anatomy Report: Filter CustomerKey > 0 (real customers only)
- Stock Equipment Analysis: Filter CustomerKey = -9
- All Service Work: Include all CustomerKey values
- Unknown Customer Audit: Filter CustomerKey = -1

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


CRITICAL FIX: Added deduplication on AccountNumber BEFORE adding CustomerKey

ISSUE: Multiple INNER JOINs on ContactID created duplicate AccountNumber records
- One ContactID could have multiple records in Raw_ArMaster_Customer
- This caused cartesian product in the result set
- CustomerKey was added AFTER joins, creating multiple keys per account

SOLUTION: Deduplicate on AccountNumber before adding CustomerKey surrogate

All other functionality preserved from original query.

============================================================================
*/

let
    // ========================================================================
    // STEP 1: FOUNDATION DATA INTEGRATION & CUSTOMER CORE
    // ========================================================================

    // Start with ArMaster as the foundation (accounts receivable master)
    ArMaster = Raw_ARMaster,

    // INNER JOIN with Contact using ContactID for complete contact information
    JoinArMasterContact = Table.NestedJoin(
        ArMaster, {"ContactID"},
        Raw_Contact, {"ContactID"},
        "ContactInfo", JoinKind.Inner),

    // Extract essential contact information for customer communication
    // Note: AccountClass added for Customer Anatomy report "Class" field
    ExpandContact = Table.ExpandTableColumn(JoinArMasterContact, "ContactInfo", {
        "LastName", "FirstName", "CompanyName", "BusinessPhone", "MobilePhone",
        "Email", "Street", "City", "State", "PostalCode", "Country", "AccountClass"
    }),

    // INNER JOIN with ArMaster_Customer for customer-specific business details
    JoinCustomerMaster = Table.NestedJoin(
        ExpandContact, {"ContactID"},
        Raw_ArMaster_Customer, {"ContactID"},
        "CustomerInfo", JoinKind.Inner),

    // Extract customer business relationship details
    ExpandCustomerMaster = Table.ExpandTableColumn(JoinCustomerMaster, "CustomerInfo", {
        "CustomerNumber", "StatusCode", "AccountType", "TradeType", "DiscountType",
        "TaxExemptNumber", "Territory", "PriceLevel", "CustomerNotes"
    }),

    // INNER JOIN with ArMaster_Contact for customer classification details
    JoinContactClass = Table.NestedJoin(
        ExpandCustomerMaster, {"ContactID"},
        Raw_ArMaster_Contact, {"ContactID"},
        "ContactClassInfo", JoinKind.Inner),

    // Extract customer classification for business segmentation
    ExpandContactClass = Table.ExpandTableColumn(JoinContactClass, "ContactClassInfo", {"ContactClass"}),

    // ========================================================================
    // STEP 2: CRITICAL DEDUPLICATION (BEFORE SURROGATE KEY)
    // ========================================================================
    /*
    CRITICAL FIX: Remove duplicate AccountNumber records caused by multiple JOINs
    TIMING: Must happen BEFORE adding CustomerKey to ensure one key per account
    APPROACH: Sort by AccountNumber, then deduplicate keeping first occurrence
    BUSINESS LOGIC: First occurrence has the earliest/primary contact record
    */

    // Sort by AccountNumber to ensure consistent deduplication
    SortByAccountNumber = Table.Sort(ExpandContactClass, {{"AccountNumber", Order.Ascending}}),

    // Deduplicate on AccountNumber - keeps first (primary) record per account
    DeduplicateAccounts = Table.Distinct(SortByAccountNumber, {"AccountNumber"}),

    // ========================================================================
    // STEP 3: SURROGATE KEY GENERATION (AFTER DEDUPLICATION)
    // ========================================================================
    /*
    PURPOSE: Create artificial primary key for optimal fact table joins
    TIMING: After deduplication ensures one unique key per unique AccountNumber
    */

    // Add surrogate key starting from 1 (positive keys for real customers)
    AddSurrogateKey = Table.AddIndexColumn(DeduplicateAccounts, "CustomerKey", 1, 1, Int64.Type),

    // ========================================================================
    // STEP 4-15: ALL REMAINING TRANSFORMATIONS (UNCHANGED)
    // ========================================================================

    // Build primary customer name using business naming conventions
    AddCustomerName = Table.AddColumn(AddSurrogateKey, "Customer", each
        if ([CompanyName] ?? "") <> "" then [CompanyName]
        else ([LastName] ?? "") & ", " & ([FirstName] ?? ""), type text),

    // Key Customer identification and trade type intelligence
    AddKeyCustomerFlag = Table.AddColumn(AddCustomerName, "IsKeyCustomer", each
        ([ContactClass] ?? "") = "KEY", type logical),

    // Trade type business descriptions with comprehensive mapping
    AddCustomerTypeDescription = Table.AddColumn(AddKeyCustomerFlag, "CustomerTypeDescription", each
        let tradeType = Text.Upper(Text.Trim([TradeType] ?? ""))
        in if tradeType = "E" then "Excess"
        else if tradeType = "F" then "Fleet"
        else if tradeType = "I" then "Internal"
        else if tradeType = "P" then "Policy"
        else if tradeType = "B" then "Billing"
        else if tradeType = "R" then "Retail"
        else if tradeType = "S" then "Misc"
        else if tradeType = "W" then "Warranty"
        else if tradeType <> "" then tradeType
        else "Unknown", type text),

    // Account status business descriptions
    AddAccountStatus = Table.AddColumn(AddCustomerTypeDescription, "AccountStatus", each
        let statusCode = Text.Upper(Text.Trim([StatusCode] ?? ""))
        in if statusCode = "A" then "Active"
        else if statusCode = "I" then "Inactive"
        else if statusCode = "H" then "Hold"
        else if statusCode = "C" then "Closed"
        else if statusCode <> "" then statusCode
        else "Unknown", type text),

    // Company vs individual account classification
    AddIsCompany = Table.AddColumn(AddAccountStatus, "IsCompany", each
        ([CompanyName] ?? "") <> "", type logical),

    // Credit availability indicator
    AddHasCreditLimit = Table.AddColumn(AddIsCompany, "HasCreditLimit", each
        ([CreditLimit] ?? 0) > 0, type logical),

    // Credit utilization calculation with null safety
    AddCreditUtilization = Table.AddColumn(AddHasCreditLimit, "CreditUtilization", each
        let creditLimit = [CreditLimit] ?? 0, accountBalance = [AccountBalance] ?? 0
        in if creditLimit > 0 then accountBalance / creditLimit else 0, type number),

    // Financial risk level assessment based on credit utilization
    AddFinancialRiskLevel = Table.AddColumn(AddCreditUtilization, "FinancialRiskLevel", each
        let utilization = [CreditUtilization] ?? 0
        in if utilization > 0.9 then "High"
        else if utilization > 0.7 then "Medium"
        else if utilization > 0.5 then "Low"
        else "Minimal", type text),

    // Overdue balance detection across all aging buckets
    AddHasOverdueBalance = Table.AddColumn(AddFinancialRiskLevel, "HasOverdueBalance", each
        (([Aging30] ?? 0) > 0) or (([Aging60] ?? 0) > 0) or (([Aging90] ?? 0) > 0), type logical),

    // Multi-tier customer classification system
    AddCustomerTier = Table.AddColumn(AddHasOverdueBalance, "CustomerTier", each
        let creditLimit = [CreditLimit] ?? 0
        in if ([IsKeyCustomer] ?? false) = true then "Key Account"
        else if creditLimit >= 50000 then "Premium"
        else if creditLimit >= 10000 then "Standard"
        else "Basic", type text),

    // High-value customer identification for priority handling
    AddIsHighValue = Table.AddColumn(AddCustomerTier, "IsHighValue", each
        List.Contains({"Key Account", "Premium"}, [CustomerTier] ?? ""), type logical),

    // Marketing campaign eligibility assessment
    AddIsMarketingEligible = Table.AddColumn(AddIsHighValue, "IsMarketingEligible", each
        (([Email] ?? "") <> "") and (([AccountStatus] ?? "") = "Active"), type logical),

    // Optimal communication method determination
    AddPreferredContactMethod = Table.AddColumn(AddIsMarketingEligible, "PreferredContactMethod", each
        if ([Email] ?? "") <> "" then "Email"
        else if ([MobilePhone] ?? "") <> "" then "Mobile"
        else if ([BusinessPhone] ?? "") <> "" then "Business Phone"
        else "Mail", type text),

    // Full name construction for individual customers
    AddFullName = Table.AddColumn(AddPreferredContactMethod, "FullName", each
        let firstName = Text.Trim([FirstName] ?? ""), lastName = Text.Trim([LastName] ?? "")
        in if firstName <> "" and lastName <> "" then firstName & " " & lastName
        else if lastName <> "" then lastName
        else if firstName <> "" then firstName
        else "", type text),

    // Primary name for business displays (company priority)
    AddPrimaryName = Table.AddColumn(AddFullName, "PrimaryName", each
        let companyName = Text.Trim([CompanyName] ?? ""), customerName = Text.Trim([Customer] ?? "")
        in if companyName <> "" then companyName
        else if customerName <> "" then customerName
        else "Account " & Text.From([AccountNumber]), type text),

    // Display name with intelligent fallback logic
    AddDisplayName = Table.AddColumn(AddPrimaryName, "DisplayName", each
        let primaryName = [PrimaryName] ?? "", accountNumber = Text.From([AccountNumber]),
            customerType = [CustomerTypeDescription] ?? "Customer"
        in if primaryName <> ("Account " & accountNumber) then primaryName
        else customerType & " " & accountNumber, type text),

    // Primary phone number with mobile preference
    AddPrimaryPhone = Table.AddColumn(AddDisplayName, "PrimaryPhone", each
        if ([MobilePhone] ?? "") <> "" then [MobilePhone]
        else if ([BusinessPhone] ?? "") <> "" then [BusinessPhone]
        else "", type text),

    // Comprehensive text field cleaning and standardization
    CleanTextFields = Table.TransformColumns(AddPrimaryPhone, {
        {"Customer", each Text.Proper(Text.Trim(_ ?? "")), type text},
        {"CompanyName", each Text.Proper(Text.Trim(_ ?? "")), type text},
        {"FirstName", each Text.Proper(Text.Trim(_ ?? "")), type text},
        {"LastName", each Text.Proper(Text.Trim(_ ?? "")), type text},
        {"Street", each Text.Proper(Text.Trim(_ ?? "")), type text},
        {"City", each Text.Proper(Text.Trim(_ ?? "")), type text},
        {"State", each Text.Upper(Text.Trim(_ ?? "")), type text},
        {"PostalCode", each Text.Trim(_ ?? ""), type text},
        {"Email", each Text.Lower(Text.Trim(_ ?? "")), type text},
        {"TradeType", each Text.Upper(Text.Trim(_ ?? "")), type text},
        {"ContactClass", each Text.Upper(Text.Trim(_ ?? "")), type text}
    }),

    // Account number as text for string-based lookups
    AddAccountNumberText = Table.AddColumn(CleanTextFields, "AccountNumberText", each
        Text.From([AccountNumber]), type text),

    // Customer number as text for additional lookup scenarios
    AddCustomerNumberText = Table.AddColumn(AddAccountNumberText, "CustomerNumberText", each
        if [CustomerNumber] <> null then Text.From([CustomerNumber]) else "", type text),

    // Add missing address and contact fields for complete customer profile
    AddMissingContactFields = Table.AddColumn(
        Table.AddColumn(AddCustomerNumberText, "Street2", each "", type text),
        "HomePhone", each "", type text),

    // Add account classification from contact table (used by Customer Anatomy "Class" field)
    AddAccountClass = Table.AddColumn(AddMissingContactFields, "Account_Class", each
        Text.Upper(Text.Trim([AccountClass] ?? "")), type text),

    // Data quality scoring
    AddDataQualityScore = Table.AddColumn(AddAccountClass, "DataQualityScore", each
        let hasName = if (([CompanyName] ?? "") <> "" or ([FirstName] ?? "") <> "") then 25 else 0,
            hasContact = if (([Email] ?? "") <> "" or ([BusinessPhone] ?? "") <> "" or ([MobilePhone] ?? "") <> "") then 25 else 0,
            hasAddress = if (([Street] ?? "") <> "" and ([City] ?? "") <> "" and ([State] ?? "") <> "") then 25 else 0,
            hasFinancial = if (([CreditLimit] ?? 0) > 0 or ([AccountBalance] ?? 0) <> 0) then 25 else 0
        in hasName + hasContact + hasAddress + hasFinancial, type number),

    // Select and organize final columns
    SelectFinalColumns = Table.SelectColumns(AddDataQualityScore, {
        "CustomerKey", "AccountNumber", "AccountNumberText", "CustomerNumber", "CustomerNumberText", "ContactID",
        "DisplayName", "Customer", "PrimaryName", "CompanyName", "FirstName", "LastName", "FullName",
        "TradeType", "CustomerTypeDescription", "StatusCode", "AccountStatus", "AccountType", "Territory",
        "CreditLimit", "AccountBalance", "Aging30", "Aging60", "Aging90", "CreditTerm", "PaymentMethod", "PriceLevel",
        "Street", "Street2", "City", "State", "PostalCode", "Country", "Email", "PrimaryPhone", "BusinessPhone", "MobilePhone", "HomePhone",
        "IsCompany", "HasCreditLimit", "Account_Class", "ContactClass", "IsKeyCustomer",
        "CreditUtilization", "FinancialRiskLevel", "HasOverdueBalance",
        "CustomerTier", "IsHighValue", "IsMarketingEligible", "PreferredContactMethod",
        "DiscountType", "TaxExemptNumber", "CustomerNotes", "DataQualityScore"
    }),

    // Rename Customer to CustomerName for consistency
    RenameCustomerColumn = Table.RenameColumns(SelectFinalColumns, {{"Customer", "CustomerName"}}),

    // Set data types
    SetDataTypes = Table.TransformColumnTypes(RenameCustomerColumn, {
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

    // Sort real customers before combining with special customers
    SortRealCustomers = Table.Sort(SetDataTypes, {{"AccountNumber", Order.Ascending}}),

    // ========================================================================
    // SPECIAL SYSTEM CUSTOMERS (UNCHANGED)
    // ========================================================================

    SpecialCustomers = Table.FromRecords({
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
         DiscountType = "", TaxExemptNumber = "", CustomerNotes = "", DataQualityScore = 50],

        // Stock Equipment - Work on dealership-owned inventory (Added 2026-02-09)
        // Identified via WKROFILE.CustomerVehicleFlag = 'S'
        // Examples: demos, PDI, damaged in transit, units awaiting delivery
        [CustomerKey = -9, AccountNumber = "STOCK", AccountNumberText = "STOCK",
         CustomerNumber = "", CustomerNumberText = "", ContactID = "",
         DisplayName = "Stock Equipment", CustomerName = "Stock Equipment",
         PrimaryName = "Stock Equipment", CompanyName = "Stock Equipment",
         FirstName = "", LastName = "", FullName = "",
         TradeType = "K", CustomerTypeDescription = "Stock",
         StatusCode = "A", AccountStatus = "Active", AccountType = "STK", Territory = "",
         CreditLimit = null, AccountBalance = null, Aging30 = null, Aging60 = null, Aging90 = null,
         CreditTerm = "", PaymentMethod = "", PriceLevel = "",
         Street = "", Street2 = "", City = "", State = "", PostalCode = "", Country = "",
         Email = "", PrimaryPhone = "", BusinessPhone = "", MobilePhone = "", HomePhone = "",
         IsCompany = false, HasCreditLimit = false, Account_Class = "STK", ContactClass = "", IsKeyCustomer = false,
         CreditUtilization = 0, FinancialRiskLevel = "Minimal", HasOverdueBalance = false,
         CustomerTier = "Basic", IsHighValue = false, IsMarketingEligible = false, PreferredContactMethod = "Mail",
         DiscountType = "", TaxExemptNumber = "",
         CustomerNotes = "Work on dealership-owned inventory: demos, PDI, damaged in transit, awaiting delivery. Identified by WKROFILE.CustomerVehicleFlag = S",
         DataQualityScore = 50]
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

    // Combine special system customers with real customer data
    CombinedCustomers = Table.Combine({SpecialCustomersTyped, SortRealCustomers}),

    // Final sort to ensure special customers appear at top, then real customers by account number
    FinalSort = Table.Sort(CombinedCustomers, {{"CustomerKey", Order.Ascending}})

in
    FinalSort

/*
============================================================================
CHANGE HISTORY
============================================================================

2026-02-09: Added Stock Equipment Special Customer (CustomerKey = -9)
- ROOT CAUSE: ~$19M in "Unknown Customer" service revenue was actually work
  on dealership-owned stock equipment (CustomerVehicleFlag = 'S' in WKROFILE)
- SOLUTION: Added CustomerKey = -9 "Stock Equipment" to categorize this work
- IMPACT: Fact_Service_Invoices can now properly assign CustomerKey based on
  CustomerVehicleFlag, reducing Unknown Customer to legitimate edge cases only
- DOCUMENTATION: Added comprehensive special customer assignment logic section

PREVIOUS: Added deduplication on AccountNumber BEFORE adding CustomerKey
- SortByAccountNumber: Sort before deduplication for consistency
- DeduplicateAccounts: Table.Distinct on AccountNumber
- RESULT: Ensures one unique AccountNumber per row BEFORE CustomerKey is assigned
- Prevents many-to-many relationships when joining on AccountNumber
- Keeps first (primary) contact record when duplicates exist

PERFORMANCE IMPACT:
- Special customers: Negligible (static table of 9 records)
- Deduplication: Minimal (<5 seconds)
- Essential for data quality and relationship integrity

SPECIAL CUSTOMERS SUMMARY:
| Key | AccountNumber | Purpose                                          |
|-----|---------------|--------------------------------------------------|
| -1  | UNKNOWN       | Unmatched customers (data quality issue)         |
| -2  | INTERNAL      | Generic internal work                            |
| -3  | WARRANTY      | Warranty claims                                  |
| -4  | FLEET         | Fleet customers                                  |
| -5  | EXCESS        | Excess work                                      |
| -6  | POLICY        | Policy adjustments                               |
| -7  | BILLING       | Billing purposes                                 |
| -8  | MISC          | Miscellaneous                                    |
| -9  | STOCK         | Stock Equipment (demos, PDI, damaged in transit) |

============================================================================
*/