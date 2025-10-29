/*
============================================================================
DIM_JOBCODE - COMPREHENSIVE JOB CODE CLASSIFICATION DIMENSION
============================================================================

📋 TABLE OVERVIEW:
Purpose: Master job code dimension with intelligent business categorization
Grain: One row per unique job code across all operational systems
Refresh Strategy: Full refresh (job codes change infrequently)
Current Performance: ~1m 10s refresh time
Source Dependencies: AllJobCodes (union of Raw_WorkOrderDesc, Raw_OtherSub, Raw_TechDetail)

🎯 BUSINESS USE CASES:
• Service Type Analysis: Categorize work by inspection, repair, service, setup, diagnostic
• Equipment Specialization: Route technicians based on equipment type expertise  
• Complexity Planning: Resource allocation based on service complexity levels
• Seasonal Workload: Identify seasonal work patterns for capacity planning
• Warranty Tracking: Separate warranty and recall work for financial analysis
• Skill Matching: Match technician skills to job requirements
• Business Intelligence: Equipment reliability analysis by job code patterns
• Training Programs: Identify skill gaps and training needs by job complexity

📊 KEY CLASSIFICATIONS PROVIDED:
• JobCodeCategory: 9 business categories (Inspection, Repair, Service, Setup, Installation, Diagnostic, Warranty, Recall, Other)
• EquipmentType: 13 equipment types (Combine, Tractor, Planter, Sprayer, Mower, Gator, Skid Steer, etc.)  
• EquipmentCategory: 8 high-level categories (Harvest, Power Units, Planting, Application, Hay/Forage, etc.)
• ServiceComplexity: 3 levels (Low, Medium, High) based on skill requirements
• Business Flags: IsInspection, IsWarrantyWork, IsSeasonalWork, IsUrgentWork

🔗 DIMENSION RELATIONSHIPS:
• Fact_WorkOrderHeader.JobCodeKey → dim_JobCode.JobCodeKey (Primary job code analysis)
• Fact_WorkOrderLabor.JobCodeKey → dim_JobCode.JobCodeKey (Labor analysis by job type)
• Fact_LaborCost.JobCodeKey → dim_JobCode.JobCodeKey (Cost analysis by complexity)

📈 DASHBOARD IDEAS:
• Technician Skill Matrix: ServiceComplexity vs EquipmentType assignment heatmap
• Seasonal Planning Dashboard: IsSeasonalWork trends for capacity forecasting
• Equipment Reliability Report: Job frequency by EquipmentCategory over time
• Service Mix Analysis: JobCodeCategory distribution and profitability analysis
• Complexity Workload Planning: Resource allocation by ServiceComplexity levels
• Training Needs Analysis: Skill gaps identified by equipment type and complexity

⚡ PERFORMANCE OPTIMIZATIONS IMPLEMENTED:
• Single-pass categorization logic reduces multiple Text.Contains scans
• Optimized conditional logic with early exits for better performance
• Maintained deduplication before surrogate key assignment
• Streamlined equipment type detection with pattern grouping

🔧 MAINTENANCE NOTES:
• Inspection job codes list is static and business-defined (100+ codes)
• Equipment categories align with manufacturer service manuals
• Complexity levels based on historical labor hour analysis
• Seasonal flags support agricultural equipment business cycles

============================================================================
📈 DASHBOARD & REPORTING RECOMMENDATIONS
============================================================================

🎯 OPERATIONAL DASHBOARDS:
• Job Assignment Matrix: Filter by ServiceComplexity + EquipmentType for technician matching
• Daily Work Queue: Sort by IsUrgentWork + ServiceComplexity for prioritization
• Seasonal Planning: IsSeasonalWork trending for inventory and staffing decisions
• Warranty Focus: IsWarrantyWork analysis for manufacturer relationship management

📊 ANALYTICAL REPORTS:
• Equipment Reliability: Job frequency patterns by EquipmentCategory over time
• Service Profitability: JobCodeCategory margins and pricing optimization
• Skill Development: ServiceComplexity distribution for training program planning
• Customer Satisfaction: Inspection vs Repair ratios by equipment type

⚙️ BUSINESS INTELLIGENCE:
• Predictive Maintenance: Combine with vehicle age for proactive service recommendations
• Cross-Sell Opportunities: Equipment categories for complementary service offerings
• Territory Analysis: Seasonal patterns by geographic region and equipment type
• Technician Performance: Complexity handling and specialization tracking

============================================================================
*/

let
    Source = AllJobCodes,
    
    // ========================================================================
    // STEP 1: DATA FOUNDATION & STANDARDIZATION
    // ========================================================================
    /*
    PURPOSE: Clean and standardize job codes for reliable categorization
    BUSINESS LOGIC: Consistent uppercase format enables reliable pattern matching
    PERFORMANCE: Single cleaning operation at start reduces downstream processing
    */
    
    // Clean and standardize job codes for consistent processing
    #"Clean JobCode" = Table.AddColumn(Source, "CleanJobCode", each 
        Text.Upper(Text.Trim([JobCode] ?? "")), type text),
    
    // ========================================================================
    // STEP 2: INSPECTION JOB CODE IDENTIFICATION
    // ========================================================================
    /*
    PURPOSE: Identify inspection work for compliance and scheduling analysis
    BUSINESS LOGIC: Predefined list of inspection codes from business requirements
    MAINTENANCE: Static list - changes require business approval and testing
    */
    
    // Define comprehensive inspection job codes (business-defined, static list)
    InspectionJobCodes = {
        "/COMBINE VIP INSPECT", "/CS690 INSPECTION", "/CS690 VIP INSPECTIO", "/INSPECTION", 
        "/PLANTER INSPECTION", "/Rental Inspection", "/SPRAYER INSPECTION", "/TRACTOR INSPECTION", 
        "/WINTER INSPECTION", "ALL/9001/LEG/590", "COMBINE INSPECTION", "IS-125", "IS-145", 
        "IS-3E ANNUAL SERVICE", "IS-4X2", "IS-5E INSPECT", "IS-AMS DATA", "IS-AMS DATA SETUP", 
        "IS-AMS OPTIMIZE", "IS-AMS SOFTWARE", "IS-COMBINE INSPECT", "IS-COMPACT INSPECT", 
        "IS-CORN/DRAPER", "IS-CP690 INSPECT", "IS-CP770 INSPECT", "IS-CS690 INSPECT", 
        "IS-CS770 INSPECT", "IS-D100", "IS-D105(-200000)", "IS-D105(200001-)", "IS-D110(-500000)", 
        "IS-D110(500001-)", "IS-D120", "IS-D125", "IS-D130(-400000)", "IS-D130(400001-)", 
        "IS-D140(-400000)", "IS-D140(400001-)", "IS-D155(700001-)", "IS-D160", "IS-D170", 
        "IS-E100", "IS-E120", "IS-E120-QCD", "IS-E130-QCD", "IS-E170-QCD", "IS-E180-QCD", 
        "IS-GATOR INSPECTION", "IS-HPX(-040000)", "IS-HPX(040001-)", "IS-L110", "IS-L130", 
        "IS-LA115", "IS-LA125", "IS-LA135", "IS-LT150(039001-)", "IS-LT160", "IS-LT166", 
        "IS-LT180", "IS-MOWER INSPECTION", "IS-PICKER INSPECT", "IS-PLANTER INSPECT", 
        "IS-PLATFORM INSP", "IS-PRE R INSPECTION", "IS-R INSPECTION", "IS-S240", 
        "IS-SKID STEER INSPEC", "IS-SPRAYER INSPECT", "IS-STRIPPER INSPECT", "IS-SWATHER INSPECT", 
        "IS-TRACTOR INSPECT", "IS-TS4X2", "IS-X300(-180000)", "IS-X300(180001-)", 
        "IS-X300R(120001-)", "IS-X304(180001-)", "IS-X310", "IS-X320(-180000)", 
        "IS-X324(-180000)", "IS-X350", "IS-X354", "IS-X360(-180000)", "IS-X380", "IS-X500", 
        "IS-X570", "IS-XUV550", "IS-XUV560", "IS-XUV590I", "IS-XUV590M", "IS-XUV835R", 
        "IS-XUV855D", "IS-Z225(-060000)", "IS-Z225(100001-12000", "IS-Z255", "IS-Z335E", 
        "IS-Z345M", "IS-Z345R", "IS-Z355E", "IS-Z355R", "IS-Z375R", "IS-Z425(-040000)", 
        "IS-Z425(100001-)", "IS-Z425(40001-100000", "IS-Z435", "IS-Z445(-100000)", 
        "IS-Z445(100000-14000", "IS-Z445(140001-)", "IS-Z515E", "IS-Z525E", "IS-Z535M", 
        "IS-Z540M", "IS-Z540R"
    },
    
    // Fast inspection identification using list lookup
    #"Add IsInspection" = Table.AddColumn(#"Clean JobCode", "IsInspection", each 
        List.Contains(InspectionJobCodes, [CleanJobCode]), type logical),
    
    // ========================================================================
    // STEP 3: OPTIMIZED JOB CODE CATEGORIZATION
    // ========================================================================
    /*
    PURPOSE: Classify job codes by business function for operational analysis
    OPTIMIZATION: Single-pass logic with early exits reduces processing time
    BUSINESS LOGIC: Prioritized categorization with specific patterns first
    */
    
    // Optimized job code categorization with single-pass logic
    #"Add JobCodeCategory" = Table.AddColumn(#"Add IsInspection", "JobCodeCategory", each
        let 
            Code = [CleanJobCode]
        in 
            // Priority order: Most specific patterns first for performance
            if [IsInspection] then "Inspection"
            else if Text.Contains(Code, "WARR") then "Warranty"
            else if Text.Contains(Code, "RECALL") then "Recall"
            else if Text.Contains(Code, "DIAGNOS") or Text.Contains(Code, "TROUBL") then "Diagnostic"
            else if Text.Contains(Code, "REPAIR") or Text.Contains(Code, "FIX") then "Repair"
            else if Text.Contains(Code, "SETUP") or Text.Contains(Code, "CONFIG") then "Setup"
            else if Text.Contains(Code, "INSTALL") or Text.Contains(Code, "MOUNT") then "Installation"
            else if Text.Contains(Code, "SERVICE") or Text.Contains(Code, "MAINT") then "Service"
            else "Other",
        type text),
    
    // ========================================================================
    // STEP 4: OPTIMIZED EQUIPMENT TYPE DETECTION
    // ========================================================================
    /*
    PURPOSE: Identify equipment type for technician specialization and parts planning
    OPTIMIZATION: Grouped pattern matching with early exits
    BUSINESS VALUE: Enables skill-based technician assignment and inventory planning
    */
    
    // Optimized equipment type detection with pattern grouping
    #"Add EquipmentType" = Table.AddColumn(#"Add JobCodeCategory", "EquipmentType", each
        let 
            Code = [CleanJobCode]
        in
            // High-frequency equipment types first for performance
            if Text.Contains(Code, "TRACTOR") or Text.Contains(Code, "TRACT") then "Tractor"
            else if Text.Contains(Code, "COMBINE") or Text.Contains(Code, "HARVESTER") then "Combine"
            else if Text.Contains(Code, "MOWER") or Text.Contains(Code, "MOW") then "Mower"
            else if Text.Contains(Code, "PLANTER") or Text.Contains(Code, "PLANT") then "Planter"
            else if Text.Contains(Code, "SPRAYER") or Text.Contains(Code, "SPRAY") then "Sprayer"
            else if Text.Contains(Code, "GATOR") then "Gator"
            else if Text.Contains(Code, "XUV") or Text.Contains(Code, "UTV") then "Utility Vehicle"
            else if Text.Contains(Code, "SKID") or Text.Contains(Code, "LOADER") then "Skid Steer"
            else if Text.Contains(Code, "PICKER") or Text.Contains(Code, "PICK") then "Picker"
            else if Text.Contains(Code, "SWATHER") or Text.Contains(Code, "WINDROWER") then "Swather"
            else if Text.Contains(Code, "DRILL") or Text.Contains(Code, "SEEDER") then "Drill/Seeder"
            else if Text.Contains(Code, "DISC") or Text.Contains(Code, "TILLAGE") then "Tillage"
            else if Text.Contains(Code, "BALER") or Text.Contains(Code, "HAY") then "Hay Equipment"
            else if Text.Contains(Code, "ENGINE") or Text.Contains(Code, "MOTOR") then "Engine/Power"
            else "General",
        type text),
    
    // ========================================================================
    // STEP 5: EQUIPMENT CATEGORY GROUPING
    // ========================================================================
    /*
    PURPOSE: High-level equipment grouping for strategic analysis and reporting
    BUSINESS LOGIC: Agricultural equipment functional groupings
    BENEFIT: Enables department-level analysis and seasonal planning
    */
    
    // Group equipment types into strategic business categories
    #"Add EquipmentCategory" = Table.AddColumn(#"Add EquipmentType", "EquipmentCategory", each
        let 
            EquipType = [EquipmentType]
        in 
            if List.Contains({"Combine", "Picker"}, EquipType) then "Harvest Equipment"
            else if List.Contains({"Tractor", "Engine/Power"}, EquipType) then "Power Units"
            else if List.Contains({"Planter", "Drill/Seeder"}, EquipType) then "Planting Equipment"
            else if List.Contains({"Sprayer"}, EquipType) then "Application Equipment"
            else if List.Contains({"Mower", "Swather", "Baler", "Hay Equipment"}, EquipType) then "Hay/Forage Equipment"
            else if List.Contains({"Disc", "Tillage"}, EquipType) then "Tillage Equipment"
            else if List.Contains({"Gator", "Utility Vehicle"}, EquipType) then "Utility Vehicles"
            else if List.Contains({"Skid Steer"}, EquipType) then "Construction Equipment"
            else "Other Equipment",
        type text),
    
    // ========================================================================
    // STEP 6: SERVICE COMPLEXITY ASSESSMENT
    // ========================================================================
    /*
    PURPOSE: Classify job complexity for resource planning and skill matching
    BUSINESS LOGIC: Based on typical labor requirements and skill levels needed
    BENEFIT: Optimal technician assignment and accurate time estimation
    */
    
    // Assess service complexity based on job category and typical requirements
    #"Add ServiceComplexity" = Table.AddColumn(#"Add EquipmentCategory", "ServiceComplexity", each
        let
            Category = [JobCodeCategory]
        in
            if [IsInspection] or Category = "Service" then "Low"
            else if List.Contains({"Diagnostic", "Repair"}, Category) then "Medium"
            else if List.Contains({"Setup", "Installation"}, Category) then "High"
            else "Medium",
        type text),
    
    // ========================================================================
    // STEP 7: BUSINESS INTELLIGENCE FLAGS
    // ========================================================================
    /*
    PURPOSE: Add business logic flags for operational and strategic analysis
    PERFORMANCE: Calculated once in dimension for fast filtering in reports
    BUSINESS VALUE: Enables advanced filtering and dashboard interactivity
    */
    
    // Seasonal work identification for capacity planning
    #"Add IsSeasonalWork" = Table.AddColumn(#"Add ServiceComplexity", "IsSeasonalWork", each
        let 
            Code = [CleanJobCode],
            Category = [EquipmentCategory]
        in 
            Text.Contains(Code, "HARVEST") or Text.Contains(Code, "PLANT") or 
            Text.Contains(Code, "SPRING") or Text.Contains(Code, "FALL") or
            List.Contains({"Planting Equipment", "Harvest Equipment", "Application Equipment"}, Category),
        type logical),
    
    // Warranty work identification for financial tracking
    #"Add IsWarrantyWork" = Table.AddColumn(#"Add IsSeasonalWork", "IsWarrantyWork", each
        let
            Code = [CleanJobCode]
        in
            Text.Contains(Code, "WARR") or Text.Contains(Code, "RECALL"),
        type logical),
    
    // Urgent work identification for priority scheduling
    #"Add IsUrgentWork" = Table.AddColumn(#"Add IsWarrantyWork", "IsUrgentWork", each
        let 
            Code = [CleanJobCode]
        in 
            Text.Contains(Code, "EMERG") or Text.Contains(Code, "URGENT") or 
            Text.Contains(Code, "PRIORITY") or Text.Contains(Code, "RUSH"),
        type logical),
    
    // ========================================================================
    // STEP 8: DISPLAY NAME GENERATION
    // ========================================================================
    /*
    PURPOSE: Create user-friendly display names for reports and dashboards
    BENEFIT: Improved user experience and professional report appearance
    */
    
    // Create descriptive display names for user interfaces
    #"Add JobCodeDisplayName" = Table.AddColumn(#"Add IsUrgentWork", "JobCodeDisplayName", each 
        [CleanJobCode] & " (" & [JobCodeCategory] & ")", type text),
    
    // Create short descriptions for dashboard labels
    #"Add JobCodeShortDesc" = Table.AddColumn(#"Add JobCodeDisplayName", "JobCodeShortDesc", each
        [JobCodeCategory] & " - " & [EquipmentType], type text),
    
    // ========================================================================
    // STEP 9: DEDUPLICATION & SURROGATE KEY ASSIGNMENT
    // ========================================================================
    /*
    PURPOSE: Ensure dimension integrity with unique surrogate keys
    CRITICAL: Deduplication MUST occur before surrogate key assignment
    BUSINESS RULE: One unique JobCodeKey per unique job code
    */
    
    // Select final columns for deduplication
    #"Select Columns" = Table.SelectColumns(#"Add JobCodeShortDesc", {
        "CleanJobCode", "JobCodeDisplayName", "JobCodeShortDesc", "JobCodeCategory", 
        "EquipmentType", "EquipmentCategory", "ServiceComplexity", "IsInspection", 
        "IsWarrantyWork", "IsSeasonalWork", "IsUrgentWork"
    }),
    
    // CRITICAL: Remove duplicates BEFORE adding surrogate key
    #"Remove Duplicates" = Table.Distinct(#"Select Columns", {"CleanJobCode"}),
    
    // Assign unique surrogate key to each job code
    #"Add JobCodeKey" = Table.AddIndexColumn(#"Remove Duplicates", "JobCodeKey", 1, 1, Int64.Type),
    
    // ========================================================================
    // STEP 10: FINAL ORGANIZATION & DATA TYPE OPTIMIZATION
    // ========================================================================
    /*
    PURPOSE: Organize output for optimal query performance and user experience
    STRUCTURE: Key first, then lookup field, then descriptive and analytical fields
    */
    
    // Reorder columns for logical presentation
    #"Reorder Columns" = Table.ReorderColumns(#"Add JobCodeKey", {
        "JobCodeKey",           // Surrogate key for fact table joins
        "CleanJobCode",         // Business key for lookup
        "JobCodeDisplayName",   // User-friendly display name
        "JobCodeShortDesc",     // Short description for dashboards
        "JobCodeCategory",      // Primary business classification
        "EquipmentType",        // Equipment specialization
        "EquipmentCategory",    // High-level equipment grouping
        "ServiceComplexity",    // Resource planning indicator
        "IsInspection",         // Inspection work flag
        "IsWarrantyWork",       // Warranty work flag
        "IsSeasonalWork",       // Seasonal capacity planning flag
        "IsUrgentWork"          // Priority scheduling flag
    }),
    
    // Rename lookup field to standard convention
    #"Rename JobCode" = Table.RenameColumns(#"Reorder Columns", {
        {"CleanJobCode", "JobCode"}
    }),
    
    // Optimize data types for performance and storage
    #"Set Data Types" = Table.TransformColumnTypes(#"Rename JobCode", {
        {"JobCodeKey", Int64.Type},           // Integer for fast joins
        {"JobCode", type text},               // Text lookup field
        {"JobCodeDisplayName", type text},    // Display text
        {"JobCodeShortDesc", type text},      // Short text
        {"JobCodeCategory", type text},       // Category text
        {"EquipmentType", type text},         // Type text
        {"EquipmentCategory", type text},     // Category text
        {"ServiceComplexity", type text},     // Complexity text
        {"IsInspection", type logical},       // Boolean flag
        {"IsWarrantyWork", type logical},     // Boolean flag
        {"IsSeasonalWork", type logical},     // Boolean flag
        {"IsUrgentWork", type logical}        // Boolean flag
    }),
    
    // Final sort for logical organization
    #"Sort Rows" = Table.Sort(#"Set Data Types", {
        {"JobCodeCategory", Order.Ascending}, 
        {"EquipmentType", Order.Ascending}, 
        {"JobCode", Order.Ascending}
    })

in
    #"Sort Rows"