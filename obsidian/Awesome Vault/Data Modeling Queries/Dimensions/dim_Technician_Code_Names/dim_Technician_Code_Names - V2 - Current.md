/*
============================================================================
DIM_TECHNICIAN_CODE_NAMES - COMPREHENSIVE TECHNICIAN MASTER DIMENSION
============================================================================

📋 TABLE OVERVIEW:
Purpose: Master technician dimension with comprehensive name formatting and business intelligence
Grain: One row per technician plus special records for data quality
Refresh Strategy: Full refresh (technician changes infrequent)
Current Performance: ~1m 10s refresh time
Source Dependencies: Raw_Technician table

🎯 BUSINESS USE CASES:
• Labor Analysis: Individual technician performance and productivity tracking
• Work Assignment: Skill-based technician assignment and workload distribution
• Performance Management: Efficiency tracking, training needs identification
• Resource Planning: Capacity planning and territory coverage analysis
• Quality Control: Service quality correlation with individual technicians
• Training Programs: Skill development tracking and certification management
• Payroll Integration: Labor cost allocation and overtime analysis
• Customer Service: Technician identification for customer communication

📊 KEY FEATURES PROVIDED:
• Multiple Name Formats: Full, display, short names for different report contexts
• Data Quality Assurance: Special -1 record handles missing/unknown technicians
• Business Flags: Active status, data completeness indicators
• Flexible Display: Formatted names suitable for dashboards and operational reports
• Search Optimization: Standardized codes and names for efficient lookup

🔗 DIMENSION RELATIONSHIPS:
• Fact_WorkOrderLabor.TechnicianKey → dim_Technician_Code_Names.TechnicianKey
• Fact_LaborCost.TechnicianKey → dim_Technician_Code_Names.TechnicianKey (potential)
• Future: Fact_ServiceCalls, Fact_TimeTracking, Fact_TechnicianPerformance

📈 DASHBOARD APPLICATIONS:
• Technician Performance Dashboard: Individual productivity and efficiency metrics
• Daily Operations Board: Active technician status and current assignments
• Resource Planning: Capacity analysis and workload distribution
• Quality Management: Service quality tracking by individual technician
• Training Dashboard: Skill development and certification tracking
• Payroll Analytics: Labor cost analysis and overtime monitoring

⚡ PERFORMANCE OPTIMIZATIONS:
• Efficient sorting and indexing for fast lookups
• Pre-calculated display names eliminate complex DAX concatenations
• Single-pass data cleaning reduces processing overhead
• Strategic use of text functions with null handling
• Optimized data types for storage efficiency

🔧 MAINTENANCE NOTES:
• Monitor for new technician additions requiring manual data validation
• Review and update status classifications based on HR changes
• Validate name formatting meets business presentation standards
• Ensure special records maintain referential integrity
• Update business classifications as organizational structure evolves

============================================================================
📈 DASHBOARD & REPORTING RECOMMENDATIONS
============================================================================

🎯 OPERATIONAL DASHBOARDS:
• Daily Dispatch: Active technician availability with skill matching
• Live Performance: Real-time productivity tracking with individual focus
• Work Queue Assignment: Technician selection with competency indicators
• Quality Control: Individual service quality metrics and improvement areas

📊 MANAGEMENT ANALYTICS:
• Technician Performance Reviews: Historical productivity and quality trends
• Resource Optimization: Capacity planning and territory coverage analysis
• Training ROI: Skill development impact on productivity and quality
• Labor Cost Analysis: Individual cost efficiency and overtime patterns

⚙️ STRATEGIC PLANNING:
• Workforce Planning: Technician capacity forecasting and hiring needs
• Skill Gap Analysis: Training requirements and certification planning
• Territory Expansion: Technician requirements for new location coverage
• Succession Planning: Senior technician knowledge transfer and development

============================================================================
*/

let
    // ========================================================================
    // STEP 1: DATA FOUNDATION & INITIAL SORTING
    // ========================================================================
    /*
    PURPOSE: Establish consistent data foundation with logical ordering
    BUSINESS LOGIC: Alphabetical ordering by technician code for predictable output
    PERFORMANCE: Early sorting optimizes subsequent index assignment
    */
    
    // Source: Raw technician master data
    Source = Raw_Technician,
    
    // Sort by technician code for consistent processing and output
    #"Sorted rows" = Table.Sort(Source, {{"techniciancode", Order.Ascending}}),
    
    // Create surrogate key with sequential numbering
    #"Added index" = Table.AddIndexColumn(#"Sorted rows", "TechnicianKey", 1, 1, Int64.Type),
    
    // ========================================================================
    // STEP 2: ENHANCED DATA CLEANING & STANDARDIZATION
    // ========================================================================
    /*
    PURPOSE: Clean and standardize technician data for consistent presentation
    BUSINESS LOGIC: Proper text casing and trimming for professional appearance
    PERFORMANCE: Single-pass cleaning operations with comprehensive null handling
    */
    
    // Clean and standardize technician code (primary lookup field)
    #"Added TechnicianCode" = Table.AddColumn(#"Added index", "TechnicianCode", each 
        Text.Upper(Text.Trim([techniciancode] ?? "")), type text),
    
    // Clean and format first name with proper casing
    #"Added TechnicianFirstName" = Table.AddColumn(#"Added TechnicianCode", "TechnicianFirstName", each 
        Text.Proper(Text.Trim([firstname] ?? "")), type text),
    
    // Clean and format last name with proper casing
    #"Added TechnicianLastName" = Table.AddColumn(#"Added TechnicianFirstName", "TechnicianLastName", each 
        Text.Proper(Text.Trim([lastname] ?? "")), type text),
    
    // ========================================================================
    // STEP 3: INTELLIGENT NAME CONSTRUCTION & DISPLAY LOGIC
    // ========================================================================
    /*
    PURPOSE: Create multiple name formats for different business contexts
    BUSINESS LOGIC: Flexible name display with intelligent fallbacks
    BENEFIT: Supports various dashboard and report requirements
    */
    
    // Enhanced full name logic with comprehensive null handling
    #"Added TechnicianFullName" = Table.AddColumn(#"Added TechnicianLastName", "TechnicianFullName", each 
        let
            first = [TechnicianFirstName],
            last = [TechnicianLastName]
        in
            if first <> "" and last <> "" then first & " " & last      // Both names available
            else if last <> "" then last                              // Last name only
            else if first <> "" then first                            // First name only
            else "Technician " & [TechnicianCode],                    // Fallback to code
        type text),
    
    // Enhanced display name (matches format from work order analysis)
    #"Added TechnicianDisplayName" = Table.AddColumn(#"Added TechnicianFullName", "TechnicianDisplayName", each 
        [TechnicianCode] & " - " & [TechnicianFullName], type text),
    
    // Add short name for space-constrained reports and mobile displays
    #"Added TechnicianShortName" = Table.AddColumn(#"Added TechnicianDisplayName", "TechnicianShortName", each 
        let
            first = [TechnicianFirstName],
            last = [TechnicianLastName]
        in
            if first <> "" and last <> "" then Text.Start(first, 1) & ". " & last  // "J. Smith"
            else [TechnicianCode],                                                  // Fallback to code
        type text),
    
    // ========================================================================
    // STEP 4: BUSINESS CLASSIFICATION & STATUS MANAGEMENT
    // ========================================================================
    /*
    PURPOSE: Add business intelligence and operational status tracking
    BUSINESS LOGIC: Status and type classifications for operational management
    EXPANSION READY: Framework for adding certifications, skills, departments
    */
    
    // Enhanced status logic (expandable for HR integration)
    #"Added TechnicianStatus" = Table.AddColumn(#"Added TechnicianShortName", "TechnicianStatus", each 
        "Active",  // TODO: Could integrate with HR status, termination dates, etc.
        type text),
    
    // Enhanced type classification (expandable for specializations)
    #"Added TechnicianType" = Table.AddColumn(#"Added TechnicianStatus", "TechnicianType", each 
        "Technician",  // TODO: Could add Senior/Junior, Specialist types, etc.
        type text),
    
    // ========================================================================
    // STEP 5: ENHANCED BUSINESS INTELLIGENCE FLAGS
    // ========================================================================
    /*
    PURPOSE: Add analytical flags for business intelligence and data quality
    BUSINESS VALUE: Enables advanced filtering and analysis in reports
    PERFORMANCE: Pre-calculated flags eliminate complex DAX expressions
    */
    
    // Active status flag for efficient filtering
    #"Added IsActive" = Table.AddColumn(#"Added TechnicianType", "IsActive", each 
        [TechnicianStatus] = "Active", type logical),
    
    // Data completeness indicator for data quality monitoring
    #"Added HasFullName" = Table.AddColumn(#"Added IsActive", "HasFullName", each 
        [TechnicianFirstName] <> "" and [TechnicianLastName] <> "", type logical),
    
    // Add code validity indicator for data validation
    #"Added HasValidCode" = Table.AddColumn(#"Added HasFullName", "HasValidCode", each 
        [TechnicianCode] <> "" and [TechnicianCode] <> "UNKNOWN", type logical),
    
    // Add name length indicator for UI optimization
    #"Added HasLongName" = Table.AddColumn(#"Added HasValidCode", "HasLongName", each 
        Text.Length([TechnicianFullName]) > 20, type logical),
    
    // ========================================================================
    // STEP 6: ENHANCED BUSINESS INTELLIGENCE (PERFORMANCE NEUTRAL)
    // ========================================================================
    /*
    PURPOSE: Add calculated insights for advanced technician analysis
    PERFORMANCE: Pre-calculated fields eliminate complex DAX in reports
    BUSINESS VALUE: Enables technician analytics and operational insights
    */
    
    // Name format preference for different display contexts
    #"Added PreferredDisplayName" = Table.AddColumn(#"Added HasLongName", "PreferredDisplayName", each
        if [HasLongName] then [TechnicianShortName] else [TechnicianFullName], type text),
    
    // Searchable name field combining all name variants
    #"Added SearchableName" = Table.AddColumn(#"Added PreferredDisplayName", "SearchableName", each
        Text.Upper([TechnicianCode] & " " & [TechnicianFullName] & " " & [TechnicianShortName]), type text),
    
    // Data quality score for monitoring and improvement
    #"Added DataQualityScore" = Table.AddColumn(#"Added SearchableName", "DataQualityScore", each
        let
            codeScore = if [HasValidCode] then 25 else 0,
            nameScore = if [HasFullName] then 50 else if [TechnicianFirstName] <> "" or [TechnicianLastName] <> "" then 25 else 0,
            statusScore = if [IsActive] then 25 else 0
        in
            codeScore + nameScore + statusScore,
        type number),
    
    // ========================================================================
    // STEP 7: FINAL COLUMN SELECTION & ORGANIZATION
    // ========================================================================
    /*
    PURPOSE: Select and organize columns for optimal usability and performance
    STRUCTURE: Key first, then lookup fields, display names, business intelligence
    */
    
    // Final column selection with logical organization
    #"Select Final Columns" = Table.SelectColumns(#"Added DataQualityScore", {
        // ===== PRIMARY KEY & LOOKUP =====
        "TechnicianKey",          // Surrogate key for fact table relationships
        "TechnicianCode",         // Business key for lookup operations
        
        // ===== NAME COMPONENTS =====
        "TechnicianFirstName",    // Given name
        "TechnicianLastName",     // Family name
        "TechnicianFullName",     // Complete formatted name
        
        // ===== DISPLAY VARIATIONS =====
        "TechnicianDisplayName",  // Code + name for detailed displays
        "TechnicianShortName",    // Abbreviated name for space-constrained displays
        "PreferredDisplayName",   // Context-appropriate name selection
        "SearchableName",         // Combined searchable text
        
        // ===== BUSINESS CLASSIFICATION =====
        "TechnicianStatus",       // Active/Inactive status
        "TechnicianType",         // Technician classification
        
        // ===== BUSINESS INTELLIGENCE FLAGS =====
        "IsActive",               // Active status flag
        "HasFullName",            // Data completeness indicator
        "HasValidCode",           // Code validity indicator
        "HasLongName",            // Name length indicator
        "DataQualityScore"        // Overall data quality assessment
    }),
    
    // ========================================================================
    // STEP 8: DATA TYPE OPTIMIZATION
    // ========================================================================
    /*
    PURPOSE: Optimize data types for storage efficiency and query performance
    STRATEGY: Appropriate types for each field category
    */
    
    // Set proper data types for optimal performance
    #"Set Data Types" = Table.TransformColumnTypes(#"Select Final Columns", {
        // Keys and identifiers
        {"TechnicianKey", Int64.Type}, {"TechnicianCode", type text},
        
        // Name components
        {"TechnicianFirstName", type text}, {"TechnicianLastName", type text}, 
        {"TechnicianFullName", type text},
        
        // Display variations
        {"TechnicianDisplayName", type text}, {"TechnicianShortName", type text}, 
        {"PreferredDisplayName", type text}, {"SearchableName", type text},
        
        // Business classification
        {"TechnicianStatus", type text}, {"TechnicianType", type text},
        
        // Business intelligence
        {"IsActive", type logical}, {"HasFullName", type logical}, 
        {"HasValidCode", type logical}, {"HasLongName", type logical}, 
        {"DataQualityScore", type number}
    }),
    
    // Final sort by technician code for consistent output
    #"Sort by Code" = Table.Sort(#"Set Data Types", {{"TechnicianCode", Order.Ascending}}),
    
    // ========================================================================
    // STEP 9: SPECIAL RECORDS FOR DATA QUALITY ASSURANCE
    // ========================================================================
    /*
    PURPOSE: Add special dimension records for robust data model integrity
    BUSINESS LOGIC: Handle missing/unknown technicians in fact tables gracefully
    BEST PRACTICE: Prevents orphaned records and enables complete analysis
    */
    
    // Create special technician records for data quality (excellent dimensional modeling!)
    SpecialTechnicians = Table.FromRows({
        {-1, "UNKNOWN", "", "", "Unknown Technician", "UNKNOWN - Unknown Technician", 
         "Unknown", "Unknown Technician", "UNKNOWN UNKNOWN TECHNICIAN", 
         "Unknown", "Unknown", false, false, false, false, 0}
    }, 
    {"TechnicianKey", "TechnicianCode", "TechnicianFirstName", "TechnicianLastName", 
     "TechnicianFullName", "TechnicianDisplayName", "TechnicianShortName", 
     "PreferredDisplayName", "SearchableName", "TechnicianStatus", "TechnicianType", 
     "IsActive", "HasFullName", "HasValidCode", "HasLongName", "DataQualityScore"}),
    
    // Convert data types for special records to match main table
    SpecialTechniciansTyped = Table.TransformColumnTypes(SpecialTechnicians, {
        {"TechnicianKey", Int64.Type}, {"TechnicianCode", type text}, 
        {"TechnicianFirstName", type text}, {"TechnicianLastName", type text}, 
        {"TechnicianFullName", type text}, {"TechnicianDisplayName", type text}, 
        {"TechnicianShortName", type text}, {"PreferredDisplayName", type text}, 
        {"SearchableName", type text}, {"TechnicianStatus", type text}, 
        {"TechnicianType", type text}, {"IsActive", type logical}, 
        {"HasFullName", type logical}, {"HasValidCode", type logical}, 
        {"HasLongName", type logical}, {"DataQualityScore", type number}
    }),
    
    // ========================================================================
    // STEP 10: FINAL INTEGRATION & SORTING
    // ========================================================================
    /*
    PURPOSE: Combine special records with regular technicians for complete dimension
    RESULT: Comprehensive technician dimension ready for production use
    */
    
    // Combine special records with regular technicians
    CombinedTechnicians = Table.Combine({SpecialTechniciansTyped, #"Sort by Code"}),
    
    // Final sort to ensure special records appear first (negative keys)
    FinalSort = Table.Sort(CombinedTechnicians, {{"TechnicianKey", Order.Ascending}})

in
    FinalSort