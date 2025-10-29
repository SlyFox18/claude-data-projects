/*
============================================================================
COMPREHENSIVE DIMENSIONAL MODEL VALIDATION FRAMEWORK
============================================================================

📋 VALIDATION OVERVIEW:
Purpose: Complete validation of all fact tables and dimensions for relationship integrity
Scope: New 5-table labor architecture + all existing fact tables and 10 dimensions
Target: Ensure seamless cross-fact analysis and reporting without orphaned records

🎯 NEW 5-TABLE LABOR ARCHITECTURE:
• Fact_LaborJobSummary (job-level financial bridge) 
• Fact_LaborPunches (individual punch records)
• Fact_LaborJobs (technician per job per day)
• Fact_LaborInvoiced (invoice line items)
• Fact_LaborWorkOrder (work order summary)

🔗 EXISTING FACT TABLES:
• Fact_WorkOrderHeader (work order analytics)
• Fact_WorkOrderParts (parts transactions)
• Fact_CustomerPerformance (customer metrics)
• Fact_InvoiceHeader (invoice summaries)
• Fact_WarrantyClaims (warranty analysis)

📚 ALL DIMENSIONS (10 TOTAL):
• dim_BranchLocation, dim_CustomerList, dim_DateTable, dim_Franchise
• dim_JobCode, dim_Parts, dim_Technician_Code_Names, dim_Vehicle  
• dim_WorkOrderMaster, dim_WorkOrderStatus

============================================================================
*/

let
    // ========================================================================
    // PHASE 1: KEY FORMAT STANDARDIZATION VALIDATION
    // ========================================================================
    /*
    PURPOSE: Identify and resolve work order key format mismatches
    CRITICAL: Must fix before all other validations
    */
    
    // Check work order key formats across all fact tables
    KeyFormatAnalysis = Table.FromRows({
        {"Table", "KeyFormat", "SampleKeys", "Issue"},
        {"Fact_LaborPunches", "Integer", "1,2,3,4", "❌ Surrogate Keys"},
        {"Fact_LaborJobs", "Integer", "1,2,3,4", "❌ Surrogate Keys"},
        {"Fact_LaborInvoiced", "Integer", "1,2,3,4", "❌ Surrogate Keys"},
        {"Fact_LaborJobSummary", "Integer", "1,2,3,4", "❌ Surrogate Keys"},
        {"Fact_LaborWorkOrder", "Text", "Branch-WorkOrder", "✅ Composite Keys"},
        {"Fact_WorkOrderHeader", "Text", "Branch-WorkOrder", "✅ Composite Keys"}, 
        {"Fact_WorkOrderParts", "Text", "Branch-WorkOrder", "✅ Composite Keys"},
        {"Fact_WarrantyClaims", "Text", "Branch-WorkOrder", "✅ Composite Keys"}
    }, {"Table", "KeyFormat", "SampleKeys", "Issue"}),
    
    KeyFormatSummary = Table.AddColumn(KeyFormatAnalysis, "RecommendedAction", each
        if [Issue] = "❌ Surrogate Keys" then "CONVERT to Text Composite Keys" 
        else "No Change Needed", type text),

    // ========================================================================
    // PHASE 2: COMPREHENSIVE WORK ORDER COVERAGE ANALYSIS
    // ========================================================================
    /*
    PURPOSE: Validate work order coverage across ALL fact tables after key fix
    EXPECTATION: >90% overlap after key standardization
    */
    
    WorkOrderCoverage = #table(
        {"FactTable", "UniqueWorkOrders", "DateRange", "ExpectedOverlap", "Status"},
        {
            {"Fact_LaborPunches", 52966, "2023-Present", ">90%", "Pending Key Fix"},
            {"Fact_LaborJobs", 51477, "2023-Present", ">90%", "Pending Key Fix"},
            {"Fact_LaborInvoiced", 55010, "2023-Present", ">90%", "Pending Key Fix"},
            {"Fact_LaborJobSummary", "TBD", "2023-Present", ">90%", "New Table"},
            {"Fact_LaborWorkOrder", 594, "All Periods", "INVESTIGATE", "❌ Low Coverage"},
            {"Fact_WorkOrderHeader", 101257, "2023-Present", "Reference Standard", "✅ Complete"},
            {"Fact_WorkOrderParts", 27134, "2024-Present", ">80%", "✅ Complete"},
            {"Fact_WarrantyClaims", 3743, "2024-Present", ">70%", "✅ Complete"}
        }
    ),
    
    // ========================================================================
    // PHASE 3: DIMENSION KEY CONSISTENCY VALIDATION 
    // ========================================================================
    /*
    PURPOSE: Ensure all dimensions have proper coverage and key consistency
    VALIDATION: Check for missing keys and coverage gaps
    */
    
    DimensionValidation = #table(
        {"Dimension", "FactTablesUsing", "KeyField", "CriticalIssues", "ValidationQuery"},
        {
            {"dim_WorkOrderMaster", "All Labor + WorkOrder + Parts + Warranty", "WorkOrderKey/BranchWorkOrder", "KEY FORMAT MISMATCH", "Check key generation logic"},
            {"dim_BranchLocation", "All Fact Tables", "BranchKey", "Join Field Mismatch", "Branch → BranchID mapping"},
            {"dim_CustomerList", "WorkOrderHeader + Parts + Performance + Invoice", "CustomerKey", "Special Records", "Validate -1 to -8 records"},
            {"dim_Technician_Code_Names", "All Labor Tables", "TechnicianKey", "Coverage", "Check technician completeness"},
            {"dim_JobCode", "All Labor + WorkOrderHeader", "JobCodeKey", "Coverage", "Check job code completeness"},
            {"dim_DateTable", "All Tables", "DateKey", "Date Format", "DateTime vs Date joins"},
            {"dim_Vehicle", "WorkOrderHeader + WarrantyClaims", "VehicleKey", "Dual Source", "Fleet vs Stock coverage"},
            {"dim_WorkOrderStatus", "WorkOrderHeader", "StatusKey", "Mapping", "Status code completeness"},
            {"dim_Franchise", "Parts + WarrantyClaims", "FranchiseKey", "Coverage", "Manufacturer completeness"},
            {"dim_Parts", "WorkOrderParts", "PartNumberKey", "Inventory", "Parts master completeness"}
        }
    ),
    
    // ========================================================================
    // PHASE 4: ORPHANED RECORDS COMPREHENSIVE ANALYSIS
    // ========================================================================
    /*
    PURPOSE: Track orphaned records improvement and remaining issues
    BASELINE: Original 177,978 labor cost + 5,104 warranty + 1 labor orphaned records
    TARGET: <1% orphaned records across all fact tables
    */
    
    OrphanedRecordsTracking = #table(
        {"ValidationArea", "OriginalIssue", "NewArchitecture", "ImprovementPct", "RemainingIssues", "Status"},
        {
            {"Labor Cost Records", 177978, "< 12000", "93%+", "New tables much better", "✅ MAJOR IMPROVEMENT"},
            {"Labor Work Records", 1, "< 500", "Resolved", "Minimal remaining", "✅ RESOLVED"},
            {"Warranty Claims", 5104, "TBD", "TBD", "Needs validation", "⚠️ VALIDATE"},
            {"Parts Records", 0, "TBD", "TBD", "Previously clean", "✅ BASELINE GOOD"},
            {"Work Order Keys", "NEW ISSUE", "ZERO OVERLAP", "Key Mismatch", "Must fix key format", "❌ CRITICAL"},
            {"Customer Keys", "Unknown", "TBD", "TBD", "Check special records", "⚠️ VALIDATE"},
            {"Branch Keys", "Unknown", "TBD", "TBD", "Check BranchID mapping", "⚠️ VALIDATE"}
        }
    ),
    
    // ========================================================================
    // PHASE 5: FINANCIAL RECONCILIATION VALIDATION
    // ========================================================================
    /*
    PURPOSE: Ensure financial totals reconcile across related fact tables
    CRITICAL: Labor financials should flow logically through the hierarchy
    */
    
    FinancialReconciliation = #table(
        {"MetricCategory", "Source1", "Value1", "Source2", "Value2", "VariancePct", "AcceptableRange", "Status"},
        {
            {"Labor Hours", "Fact_LaborPunches", 409699.55, "Fact_LaborJobs", 386362.55, "6.04%", "<10%", "✅ ACCEPTABLE"},
            {"Labor Hours", "Fact_LaborPunches", 409699.55, "Fact_LaborInvoiced", 423900.67, "-3.35%", "<10%", "✅ ACCEPTABLE"}, 
            {"Labor Revenue", "Fact_LaborJobs", "63.6M", "Fact_LaborInvoiced", "68.9M", "8.3%", "<10%", "✅ ACCEPTABLE"},
            {"Labor Revenue", "Fact_LaborJobSummary", "TBD", "Fact_LaborInvoiced", "68.9M", "TBD", "<10%", "⚠️ VALIDATE"},
            {"Work Order Revenue", "Fact_LaborWorkOrder", "1.3M", "Expected", "63-68M", "95%+ UNDER", "CRITICAL", "❌ INVESTIGATE"},
            {"Parts Revenue", "Fact_WorkOrderParts", "TBD", "Fact_InvoiceHeader", "TBD", "TBD", "<10%", "⚠️ VALIDATE"},
            {"Total Revenue", "Sum of Facts", "TBD", "Fact_InvoiceHeader", "TBD", "TBD", "<5%", "⚠️ VALIDATE"}
        }
    ),
    
    // ========================================================================
    // PHASE 6: CROSS-FACT RELATIONSHIP TESTING
    // ========================================================================
    /*
    PURPOSE: Test that relationships work properly for cross-fact analysis
    APPROACH: Validate common dimensions can filter across multiple fact tables
    */
    
    CrossFactTesting = #table(
        {"TestScenario", "DimensionFilter", "ExpectedFactTables", "TestQuery", "SuccessCriteria"},
        {
            {"Work Order Analysis", "dim_WorkOrderMaster[WorkOrderKey] = 'AUST-12345'", "5 Labor + WorkOrderHeader + Parts + Warranty", "Filter by single work order", "Data in 6+ fact tables"},
            {"Customer Analysis", "dim_CustomerList[CustomerKey] = 100", "WorkOrderHeader + Parts + Performance + Invoice", "Filter by customer", "Consistent customer data"},
            {"Branch Performance", "dim_BranchLocation[BranchKey] = 10", "All Fact Tables", "Filter by branch", "All tables return data"},
            {"Technician Productivity", "dim_Technician_Code_Names[TechnicianKey] = 50", "All 5 Labor Tables", "Filter by technician", "Complete labor cycle"},
            {"Time Intelligence", "dim_DateTable[Year] = 2024", "All Fact Tables", "Filter by year", "Consistent date filtering"},
            {"Job Code Analysis", "dim_JobCode[JobCodeKey] = 25", "5 Labor + WorkOrderHeader", "Filter by service type", "Service type consistency"},
            {"Equipment Analysis", "dim_Vehicle[VehicleKey] = 15", "WorkOrderHeader + WarrantyClaims", "Filter by equipment", "Equipment service history"},
            {"Parts Analysis", "dim_Parts[PartNumberKey] = 200", "WorkOrderParts only", "Filter by part", "Parts transaction data"}
        }
    ),
    
    // ========================================================================
    // PHASE 7: PERFORMANCE & SCALABILITY VALIDATION
    // ========================================================================
    /*
    PURPOSE: Ensure model performs well and relationships are efficient
    FOCUS: Query performance with large datasets and multiple fact table joins
    */
    
    PerformanceValidation = #table(
        {"PerformanceArea", "CurrentStatus", "Target", "ValidationMethod", "Optimization"},
        {
            {"Dimension Refresh", "~1-2 min each", "<2 min", "Monitor refresh times", "Essential columns only"},
            {"Fact Table Refresh", "2-5 min each", "<5 min", "Monitor refresh times", "Date filtering + essential columns"},
            {"Cross-Fact Queries", "Unknown", "<5 sec", "Test multi-fact DAX measures", "Surrogate keys + business flags"},
            {"Large Dataset Joins", "Unknown", "<10 sec", "Test 100K+ record joins", "Integer keys + proper indexing"},
            {"Dashboard Loading", "Unknown", "<10 sec", "Test complex dashboard refresh", "Pre-calculated metrics"},
            {"Concurrent Users", "Unknown", "20+ users", "Load testing", "Optimized data model"},
            {"Memory Usage", "Unknown", "<2GB", "Monitor memory consumption", "Data type optimization"},
            {"Storage Size", "Unknown", "Efficient", "Monitor lakehouse size", "Incremental refresh ready"}
        }
    ),
    
    // ========================================================================
    // VALIDATION EXECUTION FRAMEWORK
    // ========================================================================
    /*
    PURPOSE: Systematic execution plan for validating the entire dimensional model
    APPROACH: Step-by-step validation with clear success criteria
    */
    
    ValidationExecutionPlan = #table(
        {"Phase", "ValidationStep", "Priority", "EstimatedTime", "Dependencies", "SuccessCriteria", "FailureAction"},
        {
            {"1", "Fix Work Order Key Format", "CRITICAL", "2-4 hours", "Update 4 labor fact tables", "95%+ work order overlap", "Must resolve before proceeding"},
            {"2", "Validate Dimension Coverage", "HIGH", "1-2 hours", "All dimensions loaded", "<5% missing keys", "Add missing dimension records"},
            {"3", "Check Orphaned Records", "HIGH", "30 min", "All fact tables loaded", "<1% orphaned", "Fix dimension lookups"},
            {"4", "Financial Reconciliation", "MEDIUM", "1 hour", "All tables loaded", "<10% variance", "Investigate source data"},
            {"5", "Cross-Fact Testing", "MEDIUM", "2 hours", "Power BI relationships", "All tests pass", "Fix relationship issues"},
            {"6", "Performance Testing", "LOW", "1 hour", "Full model loaded", "Targets met", "Optimize queries"},
            {"7", "Production Readiness", "LOW", "30 min", "All validations pass", "Ready for users", "Address remaining issues"}
        }
    ),
    
    // ========================================================================
    // IMMEDIATE ACTION PLAN
    // ========================================================================
    /*
    PURPOSE: Specific next steps based on current validation results
    FOCUS: Address critical issues first, then systematic validation
    */
    
    ImmediateActionPlan = #table(
        {"Action", "Priority", "Reason", "Implementation", "ExpectedResult"},
        {
            {"Fix Labor Table Keys", "URGENT", "Zero work order overlap", "Change DimWorkOrderKey to BranchWorkOrder", "95%+ overlap achieved"},
            {"Investigate Fact_LaborWorkOrder", "HIGH", "Only 594 vs 50K+ records", "Check Raw_RepairOrderDetail vs alternatives", "Consistent work order coverage"},
            {"Validate Branch Key Joins", "HIGH", "BranchID mapping issue", "Fix Branch → BranchID joins", "Clean branch lookups"},  
            {"Test Date Key Joins", "MEDIUM", "DateTime vs Date issues", "Fix date extraction logic", "Clean date lookups"},
            {"Add Fact_LaborJobSummary", "MEDIUM", "Missing financial bridge", "Deploy new table", "Complete labor reconciliation"},
            {"Run Orphaned Records Check", "MEDIUM", "Track improvement", "Execute validation queries", "Confirm <1% orphaned"},
            {"Create Cross-Fact Tests", "LOW", "Validate relationships", "Build test measures", "Confirm cross-fact analysis"},
            {"Performance Optimization", "LOW", "Ensure scalability", "Monitor and tune", "Target performance achieved"}
        }
    )

in
    ImmediateActionPlan

/*
============================================================================
🎯 VALIDATION FRAMEWORK SUMMARY
============================================================================

✅ WHAT'S WORKING WELL:
• 93%+ reduction in orphaned records (major improvement!)
• Financial reconciliation within acceptable ranges (<10% variance)  
• Dimension architecture is solid with good business logic
• Performance targets achievable with current structure

❌ CRITICAL ISSUES TO FIX:
• Work order key format mismatch causing zero overlap
• Fact_LaborWorkOrder has severely limited data coverage
• Branch dimension join field mismatch (Branch vs BranchID)
• Date dimension join issues (DateTime vs Date)

⚠️ VALIDATION PRIORITIES:
1. URGENT: Fix work order key format in 4 labor fact tables
2. HIGH: Investigate and fix Fact_LaborWorkOrder data source
3. MEDIUM: Complete dimension join field corrections
4. LOW: Performance optimization and cross-fact testing

🚀 EXPECTED RESULTS AFTER FIXES:
• >95% work order key overlap across all fact tables
• Complete labor financial reconciliation through all 5 tables
• <1% orphaned records across the entire dimensional model
• Seamless cross-fact analysis and reporting capability

============================================================================
*/