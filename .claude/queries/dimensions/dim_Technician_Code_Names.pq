/*
============================================================================
DIM_TECHNICIAN_CODE_NAMES - COMPREHENSIVE TECHNICIAN MASTER DIMENSION
============================================================================

📋 METADATA:
Table Name: dim_Technician_Code_Names
Dataflow: df_Dim_Technicans
Purpose: Master technician dimension with comprehensive name formatting and business intelligence
Grain: One row per technician plus special records for data quality
Last Modified: 01/27/2026
Fix Applied: Added Table.Distinct to remove duplicate techniciancode values

🔄 REFRESH CHARACTERISTICS:
Row Count: 1,417 technicians
Avg Refresh Time: ~1:30 minutes (1m 10s observed)
Refresh Schedule: Not scheduled (recommend monthly reference data pipeline)
Refresh Strategy: Full refresh with special "Unknown" record pattern
Source Table: Raw_Technician

📊 DIMENSION TYPE: Type 1 (Overwrite)
Changes: Technician additions/departures infrequent
History: No historical tracking needed
Updates: Overwrite existing records when source changes

🎯 BUSINESS USE CASES:
• Labor Analysis: Individual technician performance and productivity tracking
• Work Assignment: Skill-based technician assignment and workload distribution
• Performance Management: Efficiency tracking, training needs identification
• Resource Planning: Capacity planning and territory coverage analysis
• Quality Control: Service quality correlation with individual technicians
• Training Programs: Skill development tracking and certification management
• Payroll Integration: Labor cost allocation and overtime analysis
• Customer Service: Technician identification for customer communication

📊 DATA STRUCTURE (16 Columns):

**Primary Key:**
• TechnicianKey: Surrogate key (1, 2, 3, ..., 1417, plus -1 for Unknown)

**Business Key & Name Components:**
• TechnicianCode: Standardized technician code (UPPERCASE, trimmed)
• TechnicianFirstName: Given name (Proper case)
• TechnicianLastName: Family name (Proper case)
• TechnicianFullName: Complete formatted name with intelligent fallbacks

**Display Variations (Multiple formats for different contexts):**
• TechnicianDisplayName: "CODE - Full Name" format for detailed displays
• TechnicianShortName: Abbreviated "F. LastName" for space-constrained displays
• PreferredDisplayName: Context-appropriate name (short if long, full if short)
• SearchableName: UPPERCASE combined searchable text (all name variants)

**Business Classification:**
• TechnicianStatus: Active/Inactive status (expandable for HR integration)
• TechnicianType: Technician classification (expandable for specializations)

**Business Intelligence Flags (Pre-calculated for performance):**
• IsActive: Active status boolean flag
• HasFullName: Data completeness indicator (both first and last names present)
• HasValidCode: Code validity indicator (not blank/UNKNOWN)
• HasLongName: Name length indicator (>20 characters for UI optimization)
• DataQualityScore: Overall data quality assessment (0-100 scale)

🔧 DESIGN PRINCIPLES:

**Multiple Name Formats:**
• Full Name: "John Smith" - Complete professional format
• Display Name: "JS001 - John Smith" - Code + name for detailed reports
• Short Name: "J. Smith" - Abbreviated for space-constrained displays
• Preferred Display: Automatically selects best format based on name length
• Searchable: Combined uppercase text for efficient search operations

**Intelligent Fallbacks:**
• If both names: "FirstName LastName"
• If last name only: "LastName"
• If first name only: "FirstName"
• If no names: "Technician CODE"
• Ensures every technician has displayable name

**Special Record Pattern:**
• "Unknown" record (TechnicianKey = -1) for handling missing values
• Prevents fact table orphans when labor records have NULL/blank technician
• Standard dimensional modeling best practice

**Data Quality Intelligence:**
• DataQualityScore calculation: Code validity (25) + Name completeness (50) + Status (25)
• Pre-calculated flags eliminate complex DAX expressions
• Enables data quality monitoring and improvement tracking
• HasFullName flag identifies incomplete records needing attention

**Performance Optimizations:**
• Pre-calculated display names eliminate complex DAX concatenations
• Single-pass data cleaning reduces processing overhead
• Strategic use of text functions with comprehensive null handling
• Optimized data types for storage efficiency
• Early sorting optimizes index assignment

🔗 RELATIONSHIPS:
Related Fact Tables:
• Fact_WorkOrderLabor → dim_Technician_Code_Names (via TechnicianKey)
• Fact_LaborCost → dim_Technician_Code_Names (via TechnicianKey)
• Future: Fact_ServiceCalls, Fact_TimeTracking, Fact_TechnicianPerformance

Relationship Pattern:
• Fact[TechnicianKey] → dim_Technician_Code_Names[TechnicianKey]
• Cardinality: Many-to-One
• Cross-filter Direction: Single (dimension filters facts)

📈 DASHBOARD APPLICATIONS:

**Operational Dashboards:**
• Daily Dispatch: Active technician availability with skill matching
• Live Performance: Real-time productivity tracking with individual focus
• Work Queue Assignment: Technician selection with competency indicators
• Quality Control: Individual service quality metrics and improvement areas

**Management Analytics:**
• Technician Performance Reviews: Historical productivity and quality trends
• Resource Optimization: Capacity planning and territory coverage analysis
• Training ROI: Skill development impact on productivity and quality
• Labor Cost Analysis: Individual cost efficiency and overtime patterns

**Strategic Planning:**
• Workforce Planning: Technician capacity forecasting and hiring needs
• Skill Gap Analysis: Training requirements and certification planning
• Territory Expansion: Technician requirements for new location coverage
• Succession Planning: Senior technician knowledge transfer and development

📋 IMPORTANT NOTES:

**Refresh Strategy:**
• Monthly refresh recommended (technician changes infrequent)
• ~1:30 refresh time is excellent for 1,417 rows
• Could refresh with other reference dimensions
• Consider "Reference Data Pipeline" - first Monday of month at 8:00 AM

**Source Data:**
• Extracts from Raw_Technician table
• Comprehensive cleaning: Trim, Proper case for names, UPPERCASE for codes
• Special Unknown record prevents orphaned fact records

**Extensibility:**
• Framework ready for HR integration (termination dates, hire dates)
• Can add certifications, skills, departments as separate columns
• Type classification expandable (Senior/Junior, Specialist types)
• Status expandable (Active/On Leave/Terminated with effective dates)

**Dependencies:**
• Requires Raw_Technician to be refreshed first
• Must refresh before any fact tables using TechnicianKey
• Part of dimensional pipeline sequence

**Display Name Usage Guide:**
• **TechnicianDisplayName**: Use in detailed reports, drill-through pages (shows code + name)
• **TechnicianFullName**: Use in standard reports, dashboards (clean full name)
• **TechnicianShortName**: Use in mobile displays, compact visuals (abbreviated)
• **PreferredDisplayName**: Use when space varies (automatically adapts)
• **TechnicianCode**: Use for technical reports, data validation

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

    // STEP 1a: Normalize techniciancode to UPPERCASE for consistent deduplication
    // This ensures "t200" and "T200" are treated as the same code
    #"Normalized Code" = Table.TransformColumns(Source, {{"techniciancode", each Text.Upper(Text.Trim(_ ?? "")), type text}}),

    // Sort by normalized technician code for consistent processing and output
    #"Sorted rows" = Table.Sort(#"Normalized Code", {{"techniciancode", Order.Ascending}}),

    // DEDUPLICATION FIX: Remove duplicate techniciancode values (now case-insensitive)
    // Keep first occurrence after sort to ensure unique business key
    // This prevents "duplicate value on one side of many-to-one relationship" errors
    #"Removed Duplicates" = Table.Distinct(#"Sorted rows", {"techniciancode"}),

    // Create surrogate key with sequential numbering
    #"Added index" = Table.AddIndexColumn(#"Removed Duplicates", "TechnicianKey", 1, 1, Int64.Type),

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

/*
============================================================================
📋 VALIDATION & TESTING
============================================================================

✅ POST-REFRESH VALIDATION:

1. **Row Count Verification:**
   - Should have ~1,417 rows (plus 1 Unknown record = 1,418 total)
   - Count may increase as new technicians are hired
   - Verify: SELECT COUNT(*) FROM dim_Technician_Code_Names

2. **Unknown Record Exists:**
   - TechnicianKey = -1 should exist
   - TechnicianCode = "UNKNOWN"
   - Verify: SELECT * FROM dim_Technician_Code_Names WHERE TechnicianKey = -1

3. **No Duplicate Codes:**
   - TechnicianKey values must be unique (primary key)
   - TechnicianCode values must be unique (business key)
   - Verify: SELECT TechnicianCode, COUNT(*) FROM dim_Technician_Code_Names
             GROUP BY TechnicianCode HAVING COUNT(*) > 1

4. **Name Formatting Quality:**
   - First/Last names should be Proper case
   - TechnicianCode should be UPPERCASE
   - SearchableName should be UPPERCASE
   - Verify sample records for formatting consistency

5. **Data Quality Scores:**
   - Scores should range from 0-100
   - Active technicians with full names should score 100
   - Verify: SELECT MIN(DataQualityScore), MAX(DataQualityScore), AVG(DataQualityScore)
             FROM dim_Technician_Code_Names

6. **Display Name Variations:**
   - All display name fields should be populated (no NULLs)
   - TechnicianDisplayName format: "CODE - Full Name"
   - TechnicianShortName format: "F. LastName" or CODE
   - Verify: SELECT * FROM dim_Technician_Code_Names
             WHERE TechnicianDisplayName IS NULL OR TechnicianFullName IS NULL

✅ RELATIONSHIP VALIDATION:

After refresh, verify fact table relationships:
```sql
-- Check for orphaned fact records (should return 0)
SELECT COUNT(*)
FROM Fact_WorkOrderLabor f
LEFT JOIN dim_Technician_Code_Names d ON f.TechnicianKey = d.TechnicianKey
WHERE d.TechnicianKey IS NULL
```

✅ BUSINESS INTELLIGENCE VALIDATION:

Verify flags are calculating correctly:
```sql
-- Check IsActive flag
SELECT TechnicianStatus, IsActive, COUNT(*)
FROM dim_Technician_Code_Names
GROUP BY TechnicianStatus, IsActive

-- Check HasFullName flag
SELECT HasFullName, COUNT(*),
       AVG(DataQualityScore) as AvgQuality
FROM dim_Technician_Code_Names
GROUP BY HasFullName

-- Check data quality distribution
SELECT
    CASE
        WHEN DataQualityScore = 100 THEN 'Perfect (100)'
        WHEN DataQualityScore >= 75 THEN 'Good (75-99)'
        WHEN DataQualityScore >= 50 THEN 'Fair (50-74)'
        ELSE 'Poor (<50)'
    END as QualityCategory,
    COUNT(*) as TechnicianCount
FROM dim_Technician_Code_Names
GROUP BY CASE
    WHEN DataQualityScore = 100 THEN 'Perfect (100)'
    WHEN DataQualityScore >= 75 THEN 'Good (75-99)'
    WHEN DataQualityScore >= 50 THEN 'Fair (50-74)'
    ELSE 'Poor (<50)'
END
```

============================================================================
🚀 DEPLOYMENT NOTES
============================================================================

**Prerequisites:**
1. ✅ Raw_Technician must exist and be refreshed
2. ✅ Workspace and Lakehouse access configured

**Deployment Steps:**
1. Create df_Dim_Technicans dataflow with this query
2. Schedule monthly refresh (or add to Reference Data Pipeline)
3. Create relationships in Power BI model
4. Verify row count (~1,418 total)
5. Test all name format variations in sample reports

**Scheduling Recommendation:**
- Add to monthly reference data refresh schedule
- Suggested time: First Monday of month, 8:00 AM
- Sequence: After Raw_Technician refresh, before fact tables
- Can run in parallel with other dimension refreshes

**Refresh Dependencies:**
- Must refresh AFTER: Raw_Technician (source)
- Must refresh BEFORE: Fact_WorkOrderLabor, Fact_LaborCost
- Can refresh IN PARALLEL with: Other dimension tables

**Performance Expectations:**
- ~1:30 for 1,417 rows is excellent
- Comprehensive transformations with minimal overhead
- Pre-calculated intelligence eliminates DAX complexity

============================================================================
📊 USAGE RECOMMENDATIONS
============================================================================

**Report Display Name Selection Guide:**

1. **Detailed Reports** → Use TechnicianDisplayName
   - Format: "CODE - Full Name"
   - Best for: Drill-through pages, detailed work order reports
   - Example: "T123 - John Smith"

2. **Standard Dashboards** → Use TechnicianFullName
   - Format: "FirstName LastName"
   - Best for: Executive dashboards, summary reports
   - Example: "John Smith"

3. **Mobile/Compact Views** → Use TechnicianShortName
   - Format: "F. LastName" or CODE
   - Best for: Mobile apps, compact visualizations
   - Example: "J. Smith"

4. **Dynamic/Adaptive** → Use PreferredDisplayName
   - Automatically selects best format based on name length
   - Best for: Mixed contexts where space varies
   - Example: "J. Smith" if long, "John Smith" if short

5. **Search/Filter** → Use SearchableName
   - UPPERCASE combined text of all variants
   - Best for: Search functionality, filter operations
   - Example: "T123 JOHN SMITH J. SMITH"

**Slicer Configuration:**
- Visual display: TechnicianDisplayName (shows code + name)
- Sort by: TechnicianCode (alphabetical by code)
- Filter: IsActive = TRUE (show only active technicians)

**Data Quality Monitoring:**
- Create visual showing DataQualityScore distribution
- Filter for HasFullName = FALSE to identify incomplete records
- Alert on low-quality scores for data stewardship

============================================================================
*/
