/*
============================================================================
RAW_TECHNICIANPUNCHEDDETAIL - PERFORMANCE-OPTIMIZED TIME PUNCH EXTRACTION
============================================================================

📋 TABLE OVERVIEW:
Purpose: Clean, efficient extraction of technician time punch data with work order type breakdowns
Grain: Individual punch records per technician (finest grain labor data)
Refresh Strategy: Incremental refresh using CreationDate filtering (2023+ scope)
Performance: Target <3m refresh time with optimized column selection
Source Dependencies: TechnicianPunchedDetail table (time punch tracking system)

🎯 BUSINESS USE CASES:
• Fact Table Foundation: Primary data source for detailed labor punch fact tables
• Work Type Analysis: HoursInternal, HoursWarranty, HoursRetail, etc. breakdowns
• Time Tracking: Individual punch start/end times and duration data
• Technician Performance: Hours worked vs hours sold baseline data
• Customer Context: Direct customer assignment per individual punch
• Equipment Analytics: Model-specific service time tracking

📊 ESSENTIAL DATA STRUCTURE (TARGET: ~20 COLUMNS):

**Core Punch Identifiers:**
• Branch: Punch branch location
• ROBranch: Punch branch location
• WorkOrder: Associated work order number
• TechCode: Technician identifier
• SequenceID: Punch sequence number
• JobCode: Job code classification
• JobType: Job type indicator

**Work Order Type Hours (Key Business Data):**
• HoursInternal: Internal company work time
• HoursWarranty: Warranty work time
• HoursRetail: Retail customer work time
• HoursFleet: Fleet customer work time
• HoursSundry: Sundry work time
• HoursAgreement: Agreement work time
• HoursOther: Other classified work time

**Time Tracking:**
• WorkDate: Punch work date
• StartTime: Punch start time
• EndTime: Punch end time
• HoursWorked: Actual work hours
• HoursSold: Billable hours

**Business Context:**
• CustomerName: Customer assignment
• EquipmentModel: Equipment context

**Data Governance:**
• CreationDate: Creation timestamp for incremental refresh

🔧 DESIGN PRINCIPLES APPLIED:

**Raw Table Architecture:**
• Simple extraction: No business logic calculations or classifications
• Essential fields: Focus on source data that fact tables actually need
• Performance priority: Within tested column count thresholds
• Clean naming: Consistent with other optimized raw tables

============================================================================
*/

let
    // ========================================================================
    // INCREMENTAL REFRESH PARAMETERS - STANDARD PATTERN
    // ========================================================================
    
    RangeStart = #datetime(2023, 1, 1, 0, 0, 0),
    RangeEnd = DateTime.LocalNow(),
    
    // Convert to SQL-safe format
    StartStr = "'" & DateTime.ToText(RangeStart, "yyyy-MM-dd HH:mm:ss") & "'",
    EndStr = "'" & DateTime.ToText(RangeEnd, "yyyy-MM-dd HH:mm:ss") & "'",
    
    // ========================================================================
    // PERFORMANCE-OPTIMIZED SQL QUERY - ESSENTIAL COLUMNS ONLY
    // ========================================================================
    /*
    STRATEGY: Essential punch data with work order type hours
    PERFORMANCE: ~20 columns to stay within tested performance thresholds
    FOCUS: Source data extraction without business logic processing
    */
    
    SQL = 
    "SELECT #(lf)
        -- ===== CORE PUNCH IDENTIFIERS ===== #(lf)
        Branch AS Branch, #(lf)
        ROBranch AS ROBranch, #(lf)
        RepairOrderNumber AS WorkOrder, #(lf)
        TechnicianCode AS TechCode, #(lf)
        SequenceID AS SequenceID, #(lf)
        JobCode AS JobCode, #(lf)
        JobType AS JobType, #(lf)
        
        -- ===== WORK ORDER TYPE HOURS (KEY BUSINESS DATA) ===== #(lf)
        HoursInternal AS HoursInternal, #(lf)
        HoursWarranty AS HoursWarranty, #(lf)
        HoursRetail AS HoursRetail, #(lf)
        HoursFleet AS HoursFleet, #(lf)
        HoursSundry AS HoursSundry, #(lf)
        HoursAgreement AS HoursAgreement, #(lf)
        HoursOther AS HoursOther, #(lf)
        
        -- ===== TIME TRACKING ===== #(lf)
        WorkDate AS WorkDate, #(lf)
        StartTime AS StartTime, #(lf)
        EndTime AS EndTime, #(lf)
        HoursWorked AS HoursWorked, #(lf)
        HoursSold AS HoursSold, #(lf)
        
        -- ===== BUSINESS CONTEXT ===== #(lf)
        CustomerName AS CustomerName, #(lf)
        Model AS EquipmentModel, #(lf)
        
        -- ===== DATA GOVERNANCE ===== #(lf)
        CreationDate AS CreationDate #(lf)
        
    FROM TechnicianPunchedDetail #(lf)
    WHERE CreationDate >= " & StartStr & " #(lf)
      AND CreationDate < " & EndStr & " #(lf)
    ORDER BY CreationDate DESC, Branch, RepairOrderNumber, TechnicianCode, SequenceID",
    
    // ========================================================================
    // EXECUTE QUERY - MAINTAIN QUERY FOLDING FOR OPTIMAL PERFORMANCE
    // ========================================================================
    
    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise 
        error "Failed to connect to TECHNICIANPUNCHEDDETAIL. Verify database connection and table availability.",

    ConvertWorkOrderToText = Table.TransformColumnTypes(Source, {{"WorkOrder", type text}})

in
    ConvertWorkOrderToText

/*
============================================================================
✅ RAW_TECHNICIANPUNCHEDDETAIL - OPTIMIZED FOR PERFORMANCE & SIMPLICITY
============================================================================

🎯 OPTIMIZATION RESULTS:
• Removed Massive Business Logic: All calculated fields moved to fact table layer
• Essential Fields Only: 20 columns focused on actual source data needs
• Performance Priority: Simple extraction maintains target <3m refresh time
• Fact Table Ready: Clean data foundation with essential work order type hours

🔍 BUSINESS LOGIC MOVED TO FACT TABLES:
• Work Type Classifications: PrimaryWorkType, WorkTypeCategory analysis in fact tables
• Efficiency Calculations: BillingEfficiency, EfficiencyCategory in fact tables
• Performance Metrics: WorkComplexity, TimeUtilization in fact tables
• Revenue Classifications: RevenueClassification analysis in fact tables
• Data Quality Scoring: Comprehensive scoring in fact tables
• Composite Keys: WorkOrderKey generation in fact tables

🚀 KEY SOURCE DATA PRESERVED:
• Work Order Type Hours: Complete HoursInternal, HoursWarranty, HoursRetail, etc.
• Time Tracking: Essential WorkDate, StartTime, EndTime, HoursWorked, HoursSold
• Business Context: CustomerName, EquipmentModel for analytical context
• Core Identifiers: All essential punch and technician identification

============================================================================
*/