/*
============================================================================
RAW_FIRSTPASSFILL - SERVICE PARTS FILL RATE DATA EXTRACTION
============================================================================

📋 TABLE OVERVIEW:
Purpose: Extract service parts "First Pass Fill" data from InHist_PmManage
Grain: One row per Branch/Franchise/Job/Part/Period_Date
Refresh Strategy: Incremental refresh using Period_Date filtering (2-year scope)
Performance: Essential aggregated columns (attempts, successes, transfers)
Source Dependencies: InHist_PmManage table (service performance system)

🎯 BUSINESS USE CASES:
• Fill Rate Analytics: Measure parts availability and fulfillment efficiency
• Internal vs Parts vs Workshop: Breakdown of attempts and success metrics
• Trend Analysis: Track First Pass Fill over time
• Operational Insights: Identify performance differences across Branches/Franchises
• Fact Table Support: Provides metrics for service operations reporting

📊 ESSENTIAL DATA STRUCTURE (13 AGGREGATED COLUMNS):

**Core Context Identifiers:**
• Branch – Branch location identifier
• Franchise – Franchise type (filtered to 'D')
• Job_Code – Job classification code
• Job_Type – Job type
• Part_No – Part number reference
• Period_Date – Business period date (basis for incremental refresh)
• Stocked_Ind – Stock availability indicator

**Performance Metrics:**
• Internal Attempt / Internal Success / Internal InTrfs Success
• Parts Attempt / Parts Success / Parts InTrfs Success
• Workshop Attempt / Workshop Success / Workshop InTrfs Success

🔧 DESIGN PRINCIPLES APPLIED:
• Incremental refresh based on Period_Date (rolling 2 years)
• Clean field aliases for reporting readability
• Pre-aggregated attempt/success metrics to optimize downstream modeling
• Business-quality filtering (Franchise = 'D')

============================================================================
*/

let
    // ========================================================================
    // INCREMENTAL REFRESH PARAMETERS - SERVICE DATA SCOPE
    // ========================================================================
    /*
    PURPOSE: 2-year rolling service history scope
    PERFORMANCE: Period_Date filtering ensures efficient incremental refresh
    */
    
    // Define default RangeStart/RangeEnd if not provided (local preview only)
    RangeStart = try RangeStart otherwise #datetime(2022, 1, 1, 0, 0, 0),
    RangeEnd   = try RangeEnd   otherwise DateTime.LocalNow(),

    // Convert to SQL-safe strings for query folding
    StartStr = "'" & DateTime.ToText(RangeStart, "yyyy-MM-dd HH:mm:ss") & "'",
    EndStr   = "'" & DateTime.ToText(RangeEnd, "yyyy-MM-dd HH:mm:ss") & "'",

    // ========================================================================
    // PERFORMANCE-OPTIMIZED SQL QUERY
    // ========================================================================
    /*
    STRATEGY: Aggregate at source for attempt/success counts
    FILTERING: 2-year Period_Date scope + Franchise='D'
    GROUPING: Core identifiers + Period_Date
    */
    
    SQL =
    "SELECT #(lf)
        -- ===== CORE CONTEXT IDENTIFIERS ===== #(lf)
        Branch, #(lf)
        Franchise, #(lf)
        Job_Code AS JobCode, #(lf)
        Job_Type AS JobType, #(lf)
        Part_No AS PartNumber, #(lf)
        Period_Date AS PeriodDate, #(lf)
        Stocked_Ind AS StockedIndicator, #(lf)

        -- ===== PERFORMANCE METRICS ===== #(lf)
        SUM(Internal_FirstPass_Attempt_Cnt)   AS InternalAttempt, #(lf)
        SUM(Internal_FirstPass_Success_Cnt)   AS InternalSuccess, #(lf)
        SUM(Internal_InTrfs_Success_Cnt)      AS InternalInTrfsSuccess, #(lf)

        SUM(Parts_FirstPass_Attempt_Cnt)      AS PartsAttempt, #(lf)
        SUM(Parts_FirstPass_Success_Cnt)      AS PartsSuccess, #(lf)
        SUM(Parts_InTrfs_Success_Cnt)         AS PartsInTrfsSuccess, #(lf)

        SUM(Workshop_FirstPass_Attempt_Cnt)   AS WorkshopAttempt, #(lf)
        SUM(Workshop_FirstPass_Success_Cnt)   AS WorkshopSuccess, #(lf)
        SUM(Workshop_InTrfs_Success_Cnt)      AS WorkshopInTrfsSuccess #(lf)

    FROM InHist_PmManage #(lf)
    WHERE Period_Date >= " & StartStr & " #(lf)
      AND Period_Date < " & EndStr & " #(lf)
      AND Franchise = 'D' #(lf)
    GROUP BY #(lf)
        Branch, #(lf)
        Franchise, #(lf)
        Job_Code, #(lf)
        Job_Type, #(lf)
        Part_No, #(lf)
        Period_Date, #(lf)
        Stocked_Ind",

    // ========================================================================
    // EXECUTE QUERY - MAINTAIN QUERY FOLDING FOR OPTIMAL PERFORMANCE
    // ========================================================================
    
    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise 
        error "Failed to connect to INHIST_PMMANAGE. Verify database connection and table availability."

in
    Source

/*
============================================================================
✅ RAW_FIRSTPASSFILL - PRODUCTION-READY DATA EXTRACTION
============================================================================

🎯 IMPLEMENTATION SUMMARY:
• Incremental refresh enabled (Period_Date scoped by RangeStart/RangeEnd)
• Pre-aggregated at source for performance
• 13 key metrics aligned to Internal, Parts, and Workshop dimensions
• Franchise filter ensures reporting consistency

🔍 DESIGN VALIDATION:
• Clean business naming applied to all metrics
• Supports trend analysis by Branch, Job, and Part
• Data grain: Branch/Franchise/Job/Part/Period_Date
• Fact-table ready: plug-and-play in service performance models

🚀 PRODUCTION CHARACTERISTICS:
• 2-year rolling scope balances history with refresh performance
• Source aggregation minimizes Fabric processing overhead
• Consistent with architectural patterns from other RAW_* tables

============================================================================
*/
