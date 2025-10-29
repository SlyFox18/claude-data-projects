/*
============================================================================
RAW_TECHNICIANPUNCHEDDETAIL - COMPREHENSIVE TIME PUNCH FOUNDATION
============================================================================

📋 TABLE OVERVIEW:
Purpose: Complete technician time punch tracking with work order type hour breakdowns
Grain: Individual punch records per technician (finest grain labor data)
Refresh Strategy: Incremental refresh ready (CreationDate filtering)
Dependencies: Source system TechnicianPunchedDetail table
Target Performance: <3 minutes refresh time

🎯 CRITICAL BUSINESS VALUE:
• Work Order Type Hours: The EXACT hour breakdowns your complex SQL query recreates
• Individual Punch Tracking: Finest grain labor data for detailed analysis
• Customer Context: Direct customer assignment per punch
• Equipment Context: Model information for equipment-based analysis
• Complete Time Intelligence: Start/End times with duration calculations

📊 WORK ORDER TYPE HOUR BREAKDOWNS (KEY FEATURE):
• HoursInternal: Internal company work
• HoursWarranty: Warranty claim work  
• HoursRetail: Regular customer work
• HoursFleet: Fleet customer work
• HoursSundry: Miscellaneous work
• HoursAgreement: Agreement/contract work
• HoursOther: Other classified work

⚡ WHY THIS TABLE IS CRITICAL:
• Replaces complex SQL aggregations with direct data access
• Enables work order type analysis (Customer vs Internal vs Warranty)
• Provides foundation for WIP reporting hour classifications
• Finest grain data for detailed technician performance analysis

============================================================================
*/

let
    // ========================================================================
    // CONFIGURATION PARAMETERS
    // ========================================================================
    /*
    PURPOSE: Date filtering critical for punch data which can be very voluminous
    BUSINESS LOGIC: Align with other raw tables for consistent data ranges
    PERFORMANCE: Punch data grows rapidly, date filtering essential for performance
    */
    
    // Date range parameters (align with other raw tables)
    RangeStart = #datetime(2023, 1, 1, 0, 0, 0),    // Consistent with other tables
    RangeEnd = DateTime.LocalNow(),                   // Always current data
    
    // Convert to SQL-safe format for query folding
    StartStr = "'" & DateTime.ToText(RangeStart, "yyyy-MM-dd HH:mm:ss") & "'",
    EndStr = "'" & DateTime.ToText(RangeEnd, "yyyy-MM-dd HH:mm:ss") & "'",
    
    // ========================================================================
    // COMPREHENSIVE SQL QUERY - COMPLETE PUNCH DATA
    // ========================================================================
    /*
    PURPOSE: Extract complete time punch data with work order type hour breakdowns
    STRATEGY: Include ALL columns for complete punch analysis and work type classification
    PERFORMANCE: Date filtering essential for this high-volume table
    */
    
    SQL = 
    "SELECT #(lf)
        -- ===== PRIMARY IDENTIFIERS ===== #(lf)
        Branch AS Branch, #(lf)
        RepairOrderNumber AS WorkOrder, #(lf)
        TechnicianCode AS TechCode, #(lf)
        SequenceID AS SequenceID, #(lf)
        JobCode AS JobCode, #(lf)
        JobType AS JobType, #(lf)
        ROBranch AS ROBranch, #(lf)
        
        -- ===== CUSTOMER & EQUIPMENT CONTEXT ===== #(lf)
        Model AS EquipmentModel, #(lf)
        CustomerName AS CustomerName, #(lf)
        
        -- ===== TIME TRACKING ===== #(lf)
        WorkDate AS WorkDate, #(lf)
        StartTime AS StartTime, #(lf)
        EndTime AS EndTime, #(lf)
        
        -- ===== CORE LABOR HOURS ===== #(lf)
        HoursWorked AS HoursWorked, #(lf)
        HoursSold AS HoursSold, #(lf)
        
        -- ===== WORK ORDER TYPE HOUR BREAKDOWNS (CRITICAL!) ===== #(lf)
        HoursInternal AS HoursInternal, #(lf)
        HoursWarranty AS HoursWarranty, #(lf)
        HoursRetail AS HoursRetail, #(lf)
        HoursSundry AS HoursSundry, #(lf)
        HoursFleet AS HoursFleet, #(lf)
        HoursAgreement AS HoursAgreement, #(lf)
        HoursOther AS HoursOther, #(lf)
        
        -- ===== AUDIT TRAIL ===== #(lf)
        CreationDate AS CreationDate #(lf)
        
    FROM TechnicianPunchedDetail #(lf)
    WHERE CreationDate >= " & StartStr & " #(lf)
      AND CreationDate < " & EndStr & " #(lf)
    ORDER BY CreationDate DESC, Branch, RepairOrderNumber, TechnicianCode, SequenceID",
    
    // ========================================================================
    // EXECUTE QUERY WITH ERROR HANDLING
    // ========================================================================
    
    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise 
        error "Failed to connect to TechnicianPunchedDetail. Check connection and table availability.",
    
    // ========================================================================
    // DATA TYPE OPTIMIZATION & STANDARDIZATION
    // ========================================================================
    
    StandardizedDataTypes = Table.TransformColumnTypes(Source, {
        // Primary identifiers
        {"Branch", type text}, {"WorkOrder", Int64.Type}, {"TechCode", type text}, 
        {"SequenceID", Int64.Type}, {"JobCode", type text}, {"JobType", type text}, {"ROBranch", type text},
        
        // Context information
        {"EquipmentModel", type text}, {"CustomerName", type text},
        
        // Time tracking
        {"WorkDate", type datetime}, {"StartTime", type datetime}, {"EndTime", type datetime},
        
        // Core hours
        {"HoursWorked", type number}, {"HoursSold", type number},
        
        // Work order type hours (THE CRITICAL BUSINESS LOGIC!)
        {"HoursInternal", type number}, {"HoursWarranty", type number}, {"HoursRetail", type number},
        {"HoursSundry", type number}, {"HoursFleet", type number}, {"HoursAgreement", type number}, {"HoursOther", type number},
        
        // Audit trail
        {"CreationDate", type datetime}
    }),
    
    // ========================================================================
    // ENHANCED BUSINESS LOGIC COLUMNS
    // ========================================================================
    /*
    PURPOSE: Add calculated columns that provide immediate business value
    PERFORMANCE: Calculate once in ETL vs multiple times in DAX
    BUSINESS LOGIC: Implement work order type classifications and efficiency metrics
    */
    
    // Create composite work order key for dimensional modeling
    AddWorkOrderKey = Table.AddColumn(StandardizedDataTypes, "WorkOrderKey", each 
        [ROBranch] & "-" & Text.From([WorkOrder]), type text),
    
    // Calculate actual punch duration
    AddPunchDurationHours = Table.AddColumn(AddWorkOrderKey, "PunchDurationHours", each 
        if [StartTime] <> null and [EndTime] <> null and [EndTime] > [StartTime] then
            Duration.TotalHours([EndTime] - [StartTime])
        else null, type number),
    
    // Calculate total classified hours (sum of all work type hours)
    AddTotalClassifiedHours = Table.AddColumn(AddPunchDurationHours, "TotalClassifiedHours", each 
        ([HoursInternal] ?? 0) + ([HoursWarranty] ?? 0) + ([HoursRetail] ?? 0) + 
        ([HoursSundry] ?? 0) + ([HoursFleet] ?? 0) + ([HoursAgreement] ?? 0) + ([HoursOther] ?? 0), type number),
    
    // Calculate customer hours (Retail + Fleet + Agreement - external customer work)
    AddCustomerHours = Table.AddColumn(AddTotalClassifiedHours, "CustomerHours", each 
        ([HoursRetail] ?? 0) + ([HoursFleet] ?? 0) + ([HoursAgreement] ?? 0), type number),
    
    // Calculate billing efficiency (sold vs worked)
    AddBillingEfficiency = Table.AddColumn(AddCustomerHours, "BillingEfficiency", each 
        if ([HoursWorked] ?? 0) > 0 then 
            Number.Round(([HoursSold] ?? 0) / [HoursWorked], 4)
        else null, type number),
    
    // ========================================================================
    // WORK ORDER TYPE CLASSIFICATION (CRITICAL BUSINESS LOGIC)
    // ========================================================================
    /*
    PURPOSE: Implement the work order type logic from your complex SQL query
    BUSINESS LOGIC: Classify work by primary type based on hour distributions
    */
    
    // Primary work type classification (based on which hour type is largest)
    AddPrimaryWorkType = Table.AddColumn(AddBillingEfficiency, "PrimaryWorkType", each
        let
            internal = [HoursInternal] ?? 0,
            warranty = [HoursWarranty] ?? 0,
            retail = [HoursRetail] ?? 0,
            fleet = [HoursFleet] ?? 0,
            sundry = [HoursSundry] ?? 0,
            agreement = [HoursAgreement] ?? 0,
            other = [HoursOther] ?? 0,
            maxHours = List.Max({internal, warranty, retail, fleet, sundry, agreement, other})
        in
        if maxHours = 0 then "No Hours"
        else if maxHours = internal then "Internal"
        else if maxHours = warranty then "Warranty"
        else if maxHours = retail then "Retail"
        else if maxHours = fleet then "Fleet"
        else if maxHours = sundry then "Sundry"
        else if maxHours = agreement then "Agreement"
        else "Other", type text),
    
    // Work type category (matches your complex SQL business logic)
    AddWorkTypeCategory = Table.AddColumn(AddPrimaryWorkType, "WorkTypeCategory", each
        let
            customerHours = [CustomerHours] ?? 0,
            internalHours = [HoursInternal] ?? 0,
            warrantyHours = [HoursWarranty] ?? 0,
            totalHours = [TotalClassifiedHours] ?? 0
        in
        if totalHours = 0 then "No Work"
        else if customerHours > (totalHours * 0.5) then "Customer Work"  // Majority customer
        else if internalHours > (totalHours * 0.5) then "Internal Work"  // Majority internal
        else if warrantyHours > (totalHours * 0.5) then "Warranty Work"  // Majority warranty
        else "Mixed Work", type text),  // Mixed types
    
    // Revenue classification
    AddRevenueClassification = Table.AddColumn(AddWorkTypeCategory, "RevenueClassification", each
        let category = [WorkTypeCategory] in
        if category = "Customer Work" then "Revenue Generating"
        else if category = "Warranty Work" then "Warranty Recovery"
        else if category = "Internal Work" then "Non-Revenue"
        else "Mixed Revenue", type text),
    
    // ========================================================================
    // OPERATIONAL ANALYTICS & PERFORMANCE METRICS
    // ========================================================================
    
    // Efficiency categorization
    AddEfficiencyCategory = Table.AddColumn(AddRevenueClassification, "EfficiencyCategory", each
        let efficiency = [BillingEfficiency] ?? 0 in
        if efficiency >= 1.2 then "Excellent"      // 120%+ efficiency
        else if efficiency >= 1.0 then "Good"      // 100-119% efficiency
        else if efficiency >= 0.8 then "Fair"      // 80-99% efficiency
        else if efficiency > 0 then "Poor"         // Below 80% efficiency
        else "No Data", type text),
    
    // Work complexity indicator
    AddWorkComplexity = Table.AddColumn(AddEfficiencyCategory, "WorkComplexity", each
        let
            duration = [PunchDurationHours] ?? 0,
            workTypes = 0 +
                (if ([HoursInternal] ?? 0) > 0 then 1 else 0) +
                (if ([HoursWarranty] ?? 0) > 0 then 1 else 0) +
                (if ([HoursRetail] ?? 0) > 0 then 1 else 0) +
                (if ([HoursFleet] ?? 0) > 0 then 1 else 0) +
                (if ([HoursSundry] ?? 0) > 0 then 1 else 0) +
                (if ([HoursAgreement] ?? 0) > 0 then 1 else 0) +
                (if ([HoursOther] ?? 0) > 0 then 1 else 0)
        in
        if duration > 8 or workTypes > 2 then "Complex"     // Long duration or multiple work types
        else if duration > 4 or workTypes = 2 then "Moderate"   // Medium duration or two work types
        else "Simple", type text),
    
    // Time utilization analysis
    AddTimeUtilization = Table.AddColumn(AddWorkComplexity, "TimeUtilization", each
        let
            punchHours = [PunchDurationHours] ?? 0,
            workedHours = [HoursWorked] ?? 0
        in
        if punchHours > 0 and workedHours > 0 then
            Number.Round(workedHours / punchHours, 4)
        else null, type number),
    
    // Date keys for time intelligence
    AddWorkDateKey = Table.AddColumn(AddTimeUtilization, "WorkDateKey", each 
        if [WorkDate] <> null then 
            Date.Year([WorkDate]) * 10000 + 
            Date.Month([WorkDate]) * 100 + 
            Date.Day([WorkDate])
        else 99999999, Int64.Type),
    
    // ========================================================================
    // FINAL OPTIMIZATION & QUALITY VALIDATION
    // ========================================================================
    
    // Clean text fields
    CleanTextFields = Table.TransformColumns(AddWorkDateKey, {
        {"JobCode", Text.Trim}, {"JobType", Text.Trim}, {"TechCode", Text.Trim},
        {"EquipmentModel", Text.Trim}, {"CustomerName", Text.Trim}
    }),
    
    // Add comprehensive data quality score
    AddDataQualityScore = Table.AddColumn(CleanTextFields, "DataQualityScore", each
        let
            score = 0 +
                (if [WorkOrder] <> null then 15 else 0) +
                (if [TechCode] <> null and [TechCode] <> "" then 15 else 0) +
                (if [WorkDate] <> null then 15 else 0) +
                (if [StartTime] <> null and [EndTime] <> null then 15 else 0) +
                (if [HoursWorked] <> null and [HoursWorked] > 0 then 15 else 0) +
                (if [TotalClassifiedHours] > 0 then 10 else 0) +
                (if [CustomerName] <> null and [CustomerName] <> "" then 10 else 0) +
                (if [EquipmentModel] <> null and [EquipmentModel] <> "" then 5 else 0)
        in
            score, type number)

in
    AddDataQualityScore

/*
============================================================================
🎯 BUSINESS VALUE SUMMARY
============================================================================

✅ WORK ORDER TYPE HOUR BREAKDOWNS (CRITICAL FEATURE):
• HoursInternal, HoursWarranty, HoursRetail, HoursFleet, HoursSundry, HoursAgreement, HoursOther
• Replaces complex SQL aggregations with direct data access
• Enables Customer vs Internal vs Warranty analysis
• Foundation for WIP reporting hour classifications

✅ FINEST GRAIN LABOR TRACKING:
• Individual punch records per technician
• Complete start/end time tracking with duration calculations
• Direct customer and equipment context per punch
• Billing efficiency analysis (HoursSold vs HoursWorked)

✅ WORK TYPE CLASSIFICATION (BUSINESS LOGIC):
• Primary Work Type: Identifies dominant work type per punch
• Work Type Category: Customer/Internal/Warranty/Mixed classification
• Revenue Classification: Revenue/Warranty/Non-Revenue/Mixed
• Matches complex SQL query business logic

✅ OPERATIONAL ANALYTICS:
• Efficiency categorization (Excellent/Good/Fair/Poor)
• Work complexity assessment (Simple/Moderate/Complex)
• Time utilization analysis (worked hours vs punch duration)
• Performance metrics for technician management

✅ CUSTOMER & EQUIPMENT INTELLIGENCE:
• Direct customer assignment per punch
• Equipment model context for analysis
• Customer hours calculation (Retail + Fleet + Agreement)
• Equipment-based performance analysis ready

✅ DIMENSIONAL MODELING FOUNDATION:
• WorkOrderKey for fact table relationships
• Date keys for time intelligence integration  
• Standardized naming conventions across all raw tables
• Pre-calculated business metrics for dashboard efficiency

============================================================================

🚀 THIS TABLE ENABLES:
• Complete replication of complex SQL query logic in dimensional form
• WIP reporting with accurate work type hour breakdowns
• Detailed technician performance and efficiency analysis
• Customer vs Internal vs Warranty work analysis
• Equipment-based service analysis and optimization

============================================================================
*/