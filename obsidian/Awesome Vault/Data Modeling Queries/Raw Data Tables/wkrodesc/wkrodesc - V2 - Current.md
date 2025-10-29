/*
============================================================================
RAW_WKRODESC - PRIMARY JOB CODE EXTRACTION
============================================================================

📋 TABLE OVERVIEW:
Purpose: Extract primary job code information for work order classification
Grain: One row per work order (LINE_NO = 1 filter for primary job only)
Refresh Strategy: Full refresh (no ModifiedDate field available for incremental)
Performance: Fast refresh due to simple 6-column extraction and LINE_NO filter
Source Dependencies: wkrodesc table (job description system)

🎯 BUSINESS USE CASES:
• Primary Job Classification: Main service job code identification for work orders
• Fact Table Foundation: Job code context for work order and labor fact tables
• Service Analysis: Primary job type and value tracking
• Cross-Reference: Job code lookups and work order classification

📊 DATA STRUCTURE (6 COLUMNS - SIMPLE EXTRACTION):

**Core Identifiers:**
• Branch: Work order branch identifier
• WorkOrder: Work order number (RO_NUMBER)
• JobCode: Primary job code classification
• JobType: Job type indicator

**Job Context:**
• LineNumber: Line number (filtered to 1 for primary job)
• JobValue: Job value amount

🔧 DESIGN APPROACH:

**Simple Extraction Strategy:**
• LINE_NO = 1 filter: Extracts only primary/main job per work order
• Minimal columns: Essential fields for downstream fact table integration
• Full refresh required: No incremental date field available in source
• Performance optimized: Simple query structure with strategic filtering

**Field Naming:**
• Consistent with other raw tables: Branch, WorkOrder standard naming
• Clear business context: JobCode, JobType, JobValue descriptive naming
• Integration ready: Names propagate cleanly to fact tables

⚠️ REFRESH CONSIDERATIONS:

**Full Refresh Strategy:**
• No ModifiedDate field: Source table lacks incremental refresh capability
• LINE_NO = 1 filter: Significantly reduces dataset size for performance
• Fast processing: Simple 6-column extraction maintains optimal speed
• Complete coverage: Ensures all primary jobs captured for analytics

============================================================================
*/

let
    // ========================================================================
    // PRIMARY JOB EXTRACTION - SIMPLE AND EFFICIENT
    // ========================================================================
    /*
    PURPOSE: Extract primary job information for work order classification
    STRATEGY: Simple SQL with LINE_NO = 1 filter for primary jobs only
    PERFORMANCE: 6-column extraction with filtering maintains fast refresh
    */
    
    SQL = 
    "SELECT #(lf)
        -- ===== CORE WORK ORDER IDENTIFIERS ===== #(lf)
        RO_BRANCH AS Branch, #(lf)
        RO_NUMBER AS WorkOrder, #(lf)
        
        -- ===== PRIMARY JOB CLASSIFICATION ===== #(lf)
        JOB_CODE AS JobCode, #(lf)
        TYPE AS JobType, #(lf)
        LINE_NO AS LineNumber, #(lf)
        VALUE AS JobValue #(lf)
        
    FROM wkrodesc #(lf)
    WHERE LINE_NO = 1 #(lf)
    ORDER BY Branch, RO_NUMBER",

    // ========================================================================
    // EXECUTE QUERY - SIMPLE EXTRACTION WITH ERROR HANDLING
    // ========================================================================
    
    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise 
        error "Failed to connect to WKRODESC. Verify database connection and table availability.",

    // ========================================================================
    // BASIC DATA TYPE OPTIMIZATION
    // ========================================================================
    /*
    PURPOSE: Essential data type conversions for fact table compatibility
    APPROACH: Minimal transformations to preserve performance
    */
    
    OptimizedData = Table.TransformColumnTypes(Source,{
        {"Branch", type text},
        {"WorkOrder", type text}, 
        {"JobCode", type text},
        {"JobType", type text},
        {"LineNumber", Int64.Type},
        {"JobValue", type number}
    })

in
    OptimizedData

/*
============================================================================
✅ RAW_WKRODESC - PRODUCTION-READY SIMPLE EXTRACTION
============================================================================

🎯 SIMPLICITY SUMMARY:
• Minimal Complexity: 6-column extraction with single filter condition
• Performance Optimized: Simple query structure maintains fast full refresh
• Business Focused: LINE_NO = 1 filter captures primary job classification
• Integration Ready: Clean field naming for downstream fact table usage

🔍 DESIGN RATIONALE:
• Primary job focus: LINE_NO = 1 extracts main service classification per work order
• Essential fields only: Job code, type, and value provide core classification context
• Full refresh required: Source table design necessitates complete refresh approach
• Performance priority: Simple extraction maintains fast processing despite full refresh

🚀 PRODUCTION CHARACTERISTICS:
• Fast Refresh: 6-column simplicity with filtering ensures quick processing
• Complete Coverage: All primary jobs captured for comprehensive work order analytics
• Clean Integration: Standardized naming supports fact table development
• Minimal Maintenance: Simple design requires minimal ongoing optimization

============================================================================
*/