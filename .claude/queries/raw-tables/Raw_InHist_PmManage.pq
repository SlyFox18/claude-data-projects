/*
============================================================================
RAW_INHIST_PMMANAGE - FIRST PASS FILL PARTS AVAILABILITY DATA EXTRACTION
============================================================================

📋 TABLE OVERVIEW:
Purpose: Extract parts availability and first pass fill performance data from SQL Server database
Grain: One row per Branch+Franchise+Job+Part+Date+Stock combination (detailed transaction grain)
Refresh Strategy: Incremental refresh using Period_Date filtering (2-year rolling scope)
Performance: Target <5m refresh time with strategic column selection and optimized date range
Source Dependencies: InHist_PmManage table via SQL Server ODBC connection

🎯 BUSINESS USE CASES:
• First Pass Fill Analysis: Track parts availability success rates across operational areas
• Performance Trending: Monitor month-over-month and rolling 12-month performance
• Operational Insights: Compare Internal, Parts, and Workshop performance metrics
• Inventory Planning: Analyze stocked vs non-stocked parts performance patterns
• Branch Performance: Evaluate parts availability performance by location
• Job Type Analytics: Parts availability patterns by job classification and service type

📊 ESSENTIAL DATA STRUCTURE (22 COLUMNS - STRATEGIC PERFORMANCE DATA):

**Core Business Dimensions:**
• PeriodDate: Business date for time-based analysis (primary incremental refresh key)
• Branch: Branch location identifier (links to Dim_Branch)
• Franchise: Equipment manufacturer/brand classification
• PartNumber: Parts inventory identifier (links to Dim_Parts)
• JobCode: Job classification code (links to Dim_JobCode)
• JobType: Service type classification (S=Service, W=Warranty, etc.)
• StockedIndicator: Parts stocking indicator (Y/N) for inventory analysis

**Internal Operations Metrics (Counter/Internal):**
• InternalFirstPassAttempts: Internal first pass attempts
• InternalFirstPassSuccesses: Internal first pass successes
• InternalTransferSuccesses: Internal transfer successes (for transfer rate analysis)
• Internal24HourAttempts: Internal 24-hour service attempts
• Internal24HourSuccesses: Internal 24-hour service successes

**Parts Department Metrics:**
• PartsFirstPassAttempts: Parts department first pass attempts
• PartsFirstPassSuccesses: Parts department first pass successes
• PartsTransferSuccesses: Parts transfer successes (for transfer rate analysis)
• Parts24HourAttempts: Parts 24-hour service attempts
• Parts24HourSuccesses: Parts 24-hour service successes

**Workshop Operations Metrics:**
• WorkshopFirstPassAttempts: Workshop first pass attempts
• WorkshopFirstPassSuccesses: Workshop first pass successes
• WorkshopTransferSuccesses: Workshop transfer successes (for transfer rate analysis)
• Workshop24HourAttempts: Workshop 24-hour service attempts
• Workshop24HourSuccesses: Workshop 24-hour service successes

🔧 DESIGN APPROACH:

**Strategic Column Selection:**
• Core dimensions: All 7 business keys for proper grain and dimensional linkage
• Essential metrics: FirstPass (current report focus) + InTrfs (transfer analysis) + 24Hour (operational efficiency)
• Performance optimization: 22 of 62 columns selected (65% reduction) for refresh efficiency
• Future expansion: Additional metrics available in source for future enhancements

**Incremental Refresh Strategy:**
• PeriodDate filtering with 2-year rolling window for historical analysis needs
• 7-day future buffer accommodates system processing delays and data corrections
• Franchise='D' filter maintained for current business scope
• Date-based partitioning ready for Fabric incremental refresh implementation

⚠️ PERFORMANCE OPTIMIZATION:
Strategic column selection (22 vs 62 columns) combined with targeted date range and franchise
filtering should provide optimal balance of data completeness and refresh performance.

🔄 REFRESH CHARACTERISTICS:
Row Count: 722,579 rows
Avg Refresh Time: ⚠️ 7-9 minutes (increased from original 3-4 minutes)
Refresh Schedule: Daily at 7:30 AM (part of problematic 7:30 AM pipeline)
Last Modified: 09/02/2025
Created: 08/29/2025

⚠️ PART OF 7:30 AM PERFORMANCE BOTTLENECK:
This table is part of the daily 7:30 AM pipeline that experiences systemic performance issues.
Original refresh time was 3-4 minutes but has increased to 7-9 minutes. This pipeline needs
architectural review and potential restructuring to resolve performance degradation.

🔗 FACT TABLE DEPENDENCIES:
Used By:
• Fact_FirstPassFill (First Pass Fill report)
• Analysis of parts availability and operational efficiency metrics

Related Dimensions:
• dim_DateTable (via PeriodDate)
• dim_BranchLocation (via Branch)
• dim_Parts (via PartNumber)
• dim_JobCode (via JobCode)

============================================================================
*/

let
    // ========================================================================
    // INCREMENTAL REFRESH PARAMETERS - PERFORMANCE OPTIMIZED
    // ========================================================================
    /*
    PURPOSE: 2-year rolling window with future buffer for data completeness
    STRATEGY: Balance historical analysis needs with acceptable refresh performance
    INCREMENTAL: PeriodDate field optimized for Fabric incremental refresh implementation
    */

    // 2-year rolling window for First Pass Fill historical analysis
    RangeStart = Date.AddYears(Date.From(DateTime.LocalNow()), -2),        // 2 years historical data
    RangeEnd = Date.AddDays(Date.From(DateTime.LocalNow()), 7),           // Current + 7 day buffer for processing delays

    // Convert to SQL Server compatible format
    StartStr = "'" & Date.ToText(RangeStart, "yyyy-MM-dd") & "'",
    EndStr = "'" & Date.ToText(RangeEnd, "yyyy-MM-dd") & "'",

    // ========================================================================
    // PERFORMANCE-OPTIMIZED SQL QUERY - STRATEGIC FIRST PASS FILL DATA
    // ========================================================================
    /*
    STRATEGY: Essential first pass fill metrics with strategic column selection
    PERFORMANCE: 22 of 62 columns selected for optimal refresh efficiency
    COMPLETENESS: All current report metrics + key operational metrics for future analysis
    GRAIN: Maintains detailed Branch+Franchise+Job+Part+Date+Stock grain for flexibility
    */

    SQL =
    "SELECT #(lf)
        -- ===== CORE BUSINESS DIMENSIONS ===== #(lf)
        Period_Date AS PeriodDate, #(lf)
        Branch, #(lf)
        Franchise, #(lf)
        PART_NO AS PartNumber, #(lf)
        Job_Code AS JobCode, #(lf)
        Job_Type AS JobType, #(lf)
        Stocked_Ind AS StockedIndicator, #(lf)

        -- ===== INTERNAL OPERATIONS METRICS ===== #(lf)
        Internal_FirstPass_Attempt_Cnt AS InternalFirstPassAttempts, #(lf)
        Internal_FirstPass_Success_Cnt AS InternalFirstPassSuccesses, #(lf)
        Internal_InTrfs_Success_Cnt AS InternalTransferSuccesses, #(lf)
        Internal_24Hour_Attempt_Cnt AS Internal24HourAttempts, #(lf)
        Internal_24Hour_Success_Cnt AS Internal24HourSuccesses, #(lf)

        -- ===== PARTS DEPARTMENT METRICS ===== #(lf)
        Parts_FirstPass_Attempt_Cnt AS PartsFirstPassAttempts, #(lf)
        Parts_FirstPass_Success_Cnt AS PartsFirstPassSuccesses, #(lf)
        Parts_InTrfs_Success_Cnt AS PartsTransferSuccesses, #(lf)
        Parts_24Hour_Attempt_Cnt AS Parts24HourAttempts, #(lf)
        Parts_24Hour_Success_Cnt AS Parts24HourSuccesses, #(lf)

        -- ===== WORKSHOP OPERATIONS METRICS ===== #(lf)
        Workshop_FirstPass_Attempt_Cnt AS WorkshopFirstPassAttempts, #(lf)
        Workshop_FirstPass_Success_Cnt AS WorkshopFirstPassSuccesses, #(lf)
        Workshop_InTrfs_Success_Cnt AS WorkshopTransferSuccesses, #(lf)
        Workshop_24Hour_Attempt_Cnt AS Workshop24HourAttempts, #(lf)
        Workshop_24Hour_Success_Cnt AS Workshop24HourSuccesses #(lf)

    FROM InHist_PmManage #(lf)
    WHERE Period_Date >= " & StartStr & " #(lf)
      AND Period_Date <= " & EndStr & " #(lf)
      AND Franchise = 'D'",

    // ========================================================================
    // EXECUTE QUERY - SQL SERVER ODBC CONNECTION
    // ========================================================================

    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise
        error "Failed to connect to InHist_PmManage. Verify SQL Server database connection and table availability.",

    // ========================================================================
    // DATA TYPE OPTIMIZATION - FABRIC LAKEHOUSE PERFORMANCE
    // ========================================================================
    /*
    PURPOSE: Optimize data types for Fabric Lakehouse storage and query performance
    STRATEGY: Proper typing reduces storage size and improves compression ratios
    PERFORMANCE: Optimized data types improve both storage efficiency and query speed
    */

    // Convert PeriodDate to proper date type for partitioning
    DateTyped = Table.TransformColumnTypes(Source, {{"PeriodDate", type date}}),

    // Optimize numeric columns for storage efficiency
    OptimizedTypes = Table.TransformColumnTypes(DateTyped, {
        {"InternalFirstPassAttempts", Int64.Type},
        {"InternalFirstPassSuccesses", Int64.Type},
        {"InternalTransferSuccesses", Int64.Type},
        {"Internal24HourAttempts", Int64.Type},
        {"Internal24HourSuccesses", Int64.Type},
        {"PartsFirstPassAttempts", Int64.Type},
        {"PartsFirstPassSuccesses", Int64.Type},
        {"PartsTransferSuccesses", Int64.Type},
        {"Parts24HourAttempts", Int64.Type},
        {"Parts24HourSuccesses", Int64.Type},
        {"WorkshopFirstPassAttempts", Int64.Type},
        {"WorkshopFirstPassSuccesses", Int64.Type},
        {"WorkshopTransferSuccesses", Int64.Type},
        {"Workshop24HourAttempts", Int64.Type},
        {"Workshop24HourSuccesses", Int64.Type}
    })

in
    OptimizedTypes

/*
============================================================================
✅ RAW_INHIST_PMMANAGE - STRATEGIC FIRST PASS FILL DATA EXTRACTION
============================================================================

🎯 PERFORMANCE OPTIMIZATION RESULTS:
• Column Selection: 22 of 62 columns (65% reduction) for optimal refresh efficiency
• Essential Metrics: All current report metrics + strategic operational metrics preserved
• Data Type Optimization: Proper typing for Fabric Lakehouse storage and query performance
• Incremental Ready: PeriodDate filtering optimized for future incremental refresh implementation

🔍 CRITICAL BUSINESS NOTES:
• Grain Preservation: Maintains detailed Branch+Franchise+Job+Part+Date+Stock grain
• Franchise Filter: 'D' franchise scope maintained for current business requirements
• Transfer Analysis: InTrfs metrics included for comprehensive first pass + transfer analysis
• Operational Metrics: 24Hour metrics added for expanded operational performance insights

🚀 PRODUCTION CHARACTERISTICS:
• Strategic Data Selection: Balance of completeness and performance optimization
• Dimensional Linkage: Proper keys for integration with existing Dim_Branch, Dim_Parts, etc.
• Future Expansion: Additional source metrics available when business requirements expand
• Fabric Optimized: Data types and structure optimized for Lakehouse storage and performance

🔄 MAINTENANCE GUIDANCE:
• Monitor refresh performance: Target <5m refresh time with current column selection
• Incremental refresh: Implement PeriodDate-based incremental refresh when ready
• Column expansion: Additional metrics available in source for future analytical needs
• Date range management: 2-year rolling window provides optimal historical context

🧮 DIMENSIONAL MODEL INTEGRATION:
• Date Dimension: PeriodDate → Dim_Date[Date] relationship
• Branch Dimension: Branch → Dim_Branch[BranchID] relationship
• Parts Dimension: PartNumber → Dim_Parts[PartNumber] relationship
• Job Dimensions: JobCode/JobType → respective dimension tables

⚠️ PERFORMANCE INVESTIGATION NEEDED:
This table's refresh time increased from 3-4 minutes to 7-9 minutes. Part of systemic
7:30 AM pipeline performance issues. Recommended actions:
1. Investigate SQL Server database performance during 7:30 AM window
2. Analyze query execution plans for optimization opportunities
3. Consider time-shifting this refresh outside the 7:30 AM bottleneck window
4. Evaluate source table indexing on Period_Date and Franchise columns
5. Monitor for database lock contention during peak refresh times

============================================================================
*/
