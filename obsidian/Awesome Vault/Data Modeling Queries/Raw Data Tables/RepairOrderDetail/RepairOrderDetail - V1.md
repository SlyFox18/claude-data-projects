/*
============================================================================
RAW_REPAIRORDERDETAIL - COMPREHENSIVE WORK ORDER LIFECYCLE FOUNDATION
============================================================================

📋 TABLE OVERVIEW:
Purpose: Complete work order lifecycle tracking for WIP and operational analytics
Grain: One row per work order with complete lifecycle and financial summary
Refresh Strategy: Full refresh (excellent 1-minute performance, no filtering needed)
Dependencies: Source system RepairOrderDetail view/table
Target Performance: Maintain 1-minute refresh time

🎯 ESSENTIAL FEATURES:
• Complete financial summary (all revenue streams)
• Critical date intelligence (Creation, JobStart, FirstPunch, LastPunch)
• Progress status mapping with business-specific descriptions
• Aging analysis with exact business categories
• Work started intelligence (handles 1/1/1900 date logic)

📊 BUSINESS VALUE:
• WIP Analysis: Complete aging and status tracking
• Financial Intelligence: Revenue analysis by category
• Operational Metrics: Work progression and timing
• Resource Planning: Priority and complexity assessment

============================================================================
*/

let
    // ========================================================================
    // SIMPLIFIED SQL QUERY - ESSENTIAL COLUMNS ONLY
    // ========================================================================
    /*
    PURPOSE: Extract only the essential columns for business analytics
    PERFORMANCE: Maintain excellent 1-minute refresh by avoiding over-selection
    */
    
    SQL = 
    "SELECT #(lf)
        -- ===== PRIMARY IDENTIFIERS ===== #(lf)
        Branch AS Branch, #(lf)
        RONumber AS WorkOrder, #(lf)
        JobCode AS JobCode, #(lf)
        JobType AS JobType, #(lf)
        InvoiceNumber AS InvoiceNumber, #(lf)
        
        -- ===== STATUS TRACKING ===== #(lf)
        StatusDisplay AS StatusDisplay, #(lf)
        ROProgressStatus AS ROProgressStatus, #(lf)
        
        -- ===== ESSENTIAL TIMELINE (4 CRITICAL DATES ONLY) ===== #(lf)
        CreationDate AS CreationDate, #(lf)
        JobStartDate AS JobStartDate, #(lf)
        FirstLaborPunch AS FirstLaborPunch, #(lf)
        LastLaborPunch AS LastLaborPunch, #(lf)
        
        -- ===== AGING METRICS ===== #(lf)
        DaysSinceCreationDate AS DaysSinceCreationDate, #(lf)
        
        -- ===== FINANCIAL SUMMARY ===== #(lf)
        LaborSale AS LaborRevenue, #(lf)
        PartSale AS PartsRevenue, #(lf)
        SubletSale AS SubletRevenue, #(lf)
        OtherSale AS OtherRevenue, #(lf)
        TotalSale AS TotalRevenue, #(lf)
        
        -- ===== BUSINESS INDICATORS ===== #(lf)
        QuotationIndicator AS QuotationIndicator, #(lf)
        NonRevenueIndicator AS NonRevenueIndicator #(lf)
        
    FROM RepairOrderDetail #(lf)
    ORDER BY CreationDate DESC, Branch, RONumber",
    
    // ========================================================================
    // EXECUTE QUERY WITH ERROR HANDLING
    // ========================================================================
    
    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise 
        error "Failed to connect to RepairOrderDetail. Check connection and table availability.",
    
    // ========================================================================
    // DATA TYPE OPTIMIZATION
    // ========================================================================
    
    StandardizedDataTypes = Table.TransformColumnTypes(Source, {
        // Primary identifiers
        {"Branch", type text}, {"WorkOrder", Int64.Type}, {"JobCode", type text}, 
        {"JobType", type text}, {"InvoiceNumber", type text},
        
        // Status tracking
        {"StatusDisplay", type text}, {"ROProgressStatus", type text},
        
        // Essential timeline
        {"CreationDate", type datetime}, {"JobStartDate", type datetime}, 
        {"FirstLaborPunch", type datetime}, {"LastLaborPunch", type datetime},
        
        // Aging metrics
        {"DaysSinceCreationDate", Int64.Type},
        
        // Financial data
        {"LaborRevenue", type number}, {"PartsRevenue", type number}, 
        {"SubletRevenue", type number}, {"OtherRevenue", type number}, {"TotalRevenue", type number},
        
        // Business indicators
        {"QuotationIndicator", type text}, {"NonRevenueIndicator", type text}
    }),
    
    // ========================================================================
    // BUSINESS LOGIC IMPLEMENTATION - EXACT REQUIREMENTS
    // ========================================================================
    
    // Create composite work order key for dimensional modeling
    AddWorkOrderKey = Table.AddColumn(StandardizedDataTypes, "WorkOrderKey", each 
        [Branch] & "-" & Text.From([WorkOrder]), type text),
    
    // EXACT Progress Status mapping as requested
    AddProgressStatusDisplay = Table.AddColumn(AddWorkOrderKey, "ProgressStatusDisplay", each
        let status = [ROProgressStatus] ?? "" in
        if status = "BI" then "Booked In"
        else if status = "BY" then "Booked in on Yard"
        else if status = "CA" then "Customer Advised"
        else if status = "CO" then "Collection"
        else if status = "CP" then "Complete Priced"
        else if status = "CS" then "Complete Service Manager"
        else if status = "CW" then "Customer Waiting"
        else if status = "DA" then "Warranty JAD"
        else if status = "DP" then "In Delay - Part"
        else if status = "MI" then "More Info Needed"
        else if status = "SC" then "Sundry WO - Complete"
        else if status = "WC" then "Warranty Complete"
        else if status = "WF" then "Invoiced"
        else if status = "WJ" then "Warranty JAD"
        else if status = "WO" then "Worked"
        else if status = "WP" then "T-Complete"
        else "Unknown", type text),
    
    // Work started indicator (handles 1/1/1900 logic)
    AddWorkStarted = Table.AddColumn(AddProgressStatusDisplay, "WorkStarted", each
        let
            jobStart = [JobStartDate],
            firstPunch = [FirstLaborPunch],
            lastPunch = [LastLaborPunch],
            // 1/1/1900 indicates no work done
            minDate = #datetime(1900, 1, 2, 0, 0, 0)  // Day after 1/1/1900
        in
        (jobStart <> null and jobStart >= minDate) or 
        (firstPunch <> null and firstPunch >= minDate) or 
        (lastPunch <> null and lastPunch >= minDate), type logical),
    
    // CORRECTED Aging logic - Only age work orders where work has started
    AddAging = Table.AddColumn(AddWorkStarted, "Aging", each
        if [WorkStarted] = false then "Not Started"
        else
            let daysSince = [DaysSinceCreationDate] ?? 0 in
            if daysSince >= 1 and daysSince <= 7 then "1 - 7 Days"
            else if daysSince >= 8 and daysSince <= 14 then "8 - 14 Days"
            else if daysSince >= 15 and daysSince <= 30 then "15 - 30 Days"
            else if daysSince >= 31 and daysSince <= 60 then "31 - 60 Days"
            else if daysSince > 60 and daysSince <= 45887 then "60+ Days"
            else "Not Started", type text),
    
    // CORRECTED Aging sort order - "Not Started" gets highest priority (5)
    AddAgingSortOrder = Table.AddColumn(AddAging, "AgingSortOrder", each
        if [WorkStarted] = false then 5  // Highest priority for not started work
        else
            let daysSince = [DaysSinceCreationDate] ?? 0 in
            if daysSince >= 1 and daysSince <= 7 then 4
            else if daysSince >= 8 and daysSince <= 14 then 3
            else if daysSince >= 15 and daysSince <= 30 then 2
            else if daysSince >= 31 and daysSince <= 60 then 1
            else if daysSince > 60 and daysSince <= 45887 then 0
            else 5, Int64.Type),
    
    // Revenue categorization
    AddRevenueCategory = Table.AddColumn(AddAgingSortOrder, "RevenueCategory", each
        let revenue = [TotalRevenue] ?? 0 in
        if revenue >= 10000 then "High Value"
        else if revenue >= 2500 then "Medium Value"
        else if revenue >= 500 then "Low Value"
        else if revenue > 0 then "Minimal Value"
        else "No Revenue", type text),
    
    // Active work order indicator (not invoiced)
    AddIsActiveWorkOrder = Table.AddColumn(AddRevenueCategory, "IsActiveWorkOrder", each 
        [ROProgressStatus] <> "WF", type logical),  // WF = Invoiced
    
    // Revenue mix analysis
    AddPartsPercentage = Table.AddColumn(AddIsActiveWorkOrder, "PartsPercentage", each 
        if ([TotalRevenue] ?? 0) > 0 then 
            Number.Round(([PartsRevenue] ?? 0) / [TotalRevenue], 4)
        else null, type number),
    
    AddLaborPercentage = Table.AddColumn(AddPartsPercentage, "LaborPercentage", each 
        if ([TotalRevenue] ?? 0) > 0 then 
            Number.Round(([LaborRevenue] ?? 0) / [TotalRevenue], 4)
        else null, type number),
    
    // Service mix classification
    AddServiceMixType = Table.AddColumn(AddLaborPercentage, "ServiceMixType", each
        let
            laborPct = [LaborPercentage] ?? 0,
            partsPct = [PartsPercentage] ?? 0
        in
        if laborPct >= 0.7 then "Labor Heavy"
        else if partsPct >= 0.7 then "Parts Heavy"
        else if laborPct >= 0.4 and partsPct >= 0.4 then "Balanced Mix"
        else "Other Mix", type text),
    
    // ========================================================================
    // DATA QUALITY AND FINAL OPTIMIZATION
    // ========================================================================
    
    // Clean text fields
    CleanTextFields = Table.TransformColumns(AddServiceMixType, {
        {"JobCode", Text.Trim}, {"JobType", Text.Trim}, {"StatusDisplay", Text.Trim},
        {"ROProgressStatus", Text.Trim}
    }),
    
    // Add data quality score
    AddDataQualityScore = Table.AddColumn(CleanTextFields, "DataQualityScore", each
        let
            score = 0 +
                (if [WorkOrder] <> null then 20 else 0) +
                (if [CreationDate] <> null then 20 else 0) +
                (if [StatusDisplay] <> null and [StatusDisplay] <> "" then 20 else 0) +
                (if [JobCode] <> null and [JobCode] <> "" then 20 else 0) +
                (if [TotalRevenue] <> null then 20 else 0)
        in
            score, type number)

in
    AddDataQualityScore

/*
============================================================================
🎯 BUSINESS VALUE SUMMARY
============================================================================

✅ EXACT BUSINESS LOGIC IMPLEMENTED:
• Progress Status Display: Complete mapping (BI→"Booked In", etc.)
• Aging: Exact categories (1-7, 8-14, 15-30, 31-60, 60+ Days, Not Started)
• Work Started Logic: Handles 1/1/1900 date indicators correctly
• Essential dates only: CreationDate, JobStartDate, FirstLaborPunch, LastLaborPunch

✅ WIP ANALYSIS READY:
• Active Work Order identification (ROProgressStatus <> "WF")
• Aging categories with proper sort order (0-5)
• Revenue categorization for priority management
• Work started vs not started distinction

✅ FINANCIAL INTELLIGENCE:
• Complete revenue breakdown (Labor, Parts, Sublet, Other, Total)
• Revenue percentage analysis by category
• Service mix classification (Labor Heavy, Parts Heavy, Balanced)
• Value-based categorization (High, Medium, Low, Minimal, No Revenue)

✅ PERFORMANCE OPTIMIZED:
• Essential columns only for 1-minute refresh maintenance
• No unnecessary date filtering
• Proper data types for optimal performance
• Clean business logic implementation

============================================================================
*/