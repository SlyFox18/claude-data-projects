/*
============================================================================
DIM_FRANCHISE - COMPREHENSIVE MANUFACTURER & EQUIPMENT BRAND DIMENSION
============================================================================

📋 TABLE OVERVIEW:
Purpose: Master equipment manufacturer dimension for brand performance and business analysis
Grain: One row per unique franchise/manufacturer with comprehensive business intelligence
Refresh Strategy: Full refresh (manufacturer data changes infrequently)
Current Performance: 1m 15s refresh time (excellent)
Source Dependencies: jdis_Part_Information.Franchise field (manufacturer codes from parts data)

🎯 BUSINESS USE CASES:
• Manufacturer Performance: Brand reliability analysis and service pattern identification
• Parts Management: Manufacturer-specific parts analysis and inventory optimization
• Warranty Analysis: Brand-specific warranty claims and reimbursement tracking
• Equipment Strategy: Manufacturer mix analysis for fleet and inventory decisions
• Service Specialization: Technician assignment based on equipment brand expertise
• Customer Analysis: Customer preference tracking by equipment manufacturer
• Territory Planning: Brand presence and market penetration by geographic region
• Financial Analysis: Revenue and profitability analysis by equipment manufacturer

📊 KEY FEATURES PROVIDED:
• Manufacturer Classification: John Deere, Case IH, Caterpillar, Kubota, New Holland categorization
• Equipment Segmentation: Agricultural vs Construction equipment business lines
• Business Priority: Primary brand identification and sort ordering for reports
• Professional Display: Formatted manufacturer names for customer communications
• Business Intelligence: Active status, brand categories, and operational flags

🔗 DIMENSION RELATIONSHIPS:
• Fact_WorkOrderParts.FranchiseKey → dim_Franchise.FranchiseKey (Parts manufacturer analysis)
• Fact_WorkOrderHeader.ManufacturerKey → dim_Franchise.FranchiseKey (Equipment service analysis)
• Fact_WarrantyClaims.FranchiseKey → dim_Franchise.FranchiseKey (Warranty performance by brand)
• dim_Parts.Franchise → dim_Franchise.Franchise (Parts-to-manufacturer relationship)

📈 ANALYTICS STRATEGY:
• Brand Performance: John Deere (Primary) → Case IH → Caterpillar → Kubota → New Holland → Other
• Equipment Categories: Agricultural Equipment (John Deere, Case IH, New Holland, Kubota) vs Construction Equipment (Caterpillar)
• Market Analysis: Primary brand focus with competitive brand tracking
• Service Patterns: Brand-specific service requirements and specialization needs

⚡ PERFORMANCE OPTIMIZATION:
• Efficient manufacturer classification with pattern matching
• Surrogate keys optimize fact table joins and brand analysis queries
• Strategic sort ordering reduces runtime sorting in reports and dashboards
• Professional display names eliminate complex string formatting in visualizations
• Business flags enable fast filtering without complex brand logic

🔧 MAINTENANCE NOTES:
• Monitor manufacturer classification accuracy when new brands added
• Review primary brand designation based on business strategy changes
• Validate equipment category assignments for new manufacturer codes
• Update professional display names to maintain customer communication standards
• Audit sort order relevance for dashboard and report prioritization

============================================================================
📈 MANUFACTURER ANALYTICS & DASHBOARD RECOMMENDATIONS
============================================================================

🏭 MANUFACTURER PERFORMANCE DASHBOARDS:
• Brand Reliability Scorecard: Service frequency and warranty claims by manufacturer
• Equipment Mix Analysis: Brand distribution across customer base and territories
• Parts Performance: Manufacturer-specific parts sales, margins, and inventory turnover
• Service Specialization: Technician expertise and training needs by equipment brand

💰 FINANCIAL ANALYTICS:
• Revenue by Manufacturer: Brand contribution to total business revenue
• Warranty Performance: Manufacturer reimbursement rates and claim resolution efficiency
• Parts Profitability: Brand-specific parts margins and inventory valuation
• Customer Loyalty: Repeat business and brand preference analysis by customer segment

⚙️ OPERATIONAL INTELLIGENCE:
• Service Capacity: Brand-specific service requirements and technician allocation
• Equipment Strategy: Market positioning and competitive analysis by manufacturer
• Territory Analysis: Brand presence and market penetration by geographic region
• Training Programs: Manufacturer certification requirements and skill development

============================================================================
*/

let
    // ========================================================================
    // STEP 1: DATA FOUNDATION & SOURCE PREPARATION
    // ========================================================================
    /*
    PURPOSE: Extract manufacturer data from parts information for comprehensive brand analysis
    BUSINESS LOGIC: Manufacturers identified through parts franchise codes
    DATA SOURCE: Parts data provides comprehensive manufacturer coverage
    */
    
    // Source: Manufacturer data from parts information
    Source = jdis_Part_Information,
    
    // Select manufacturer field for dimension building
    SelectFranchiseColumn = Table.SelectColumns(Source, {"Franchise"}),
    
    // ========================================================================
    // STEP 2: DATA CLEANING & STANDARDIZATION
    // ========================================================================
    /*
    PURPOSE: Clean and standardize manufacturer codes for reliable business analysis
    BUSINESS LOGIC: Consistent formatting enables reliable categorization and reporting
    PERFORMANCE: Efficient text operations with proper null handling
    */
    
    // Clean manufacturer codes with comprehensive text processing
    CleanFranchiseCodes = Table.TransformColumns(SelectFranchiseColumn, {
        {"Franchise", each Text.Upper(Text.Trim(Text.Clean(_ ?? ""))), type text}
    }),
    
    // Remove duplicate manufacturer codes for unique dimension records
    RemoveDuplicates = Table.Distinct(CleanFranchiseCodes, {"Franchise"}),
    
    // Sort manufacturers alphabetically for consistent processing
    SortManufacturers = Table.Sort(RemoveDuplicates, {{"Franchise", Order.Ascending}}),
    
    // ========================================================================
    // STEP 3: SURROGATE KEY GENERATION & UNIQUE IDENTIFICATION
    // ========================================================================
    /*
    PURPOSE: Create artificial primary key for optimal fact table relationships
    BUSINESS BENEFIT: Enables efficient star schema joins and manufacturer analysis
    */
    
    // Add surrogate key for optimal fact table performance
    AddSurrogateKey = Table.AddIndexColumn(SortManufacturers, "FranchiseKey", 1, 1, Int64.Type),
    
    // ========================================================================
    // STEP 4: PROFESSIONAL DISPLAY NAME GENERATION
    // ========================================================================
    /*
    PURPOSE: Create customer-ready manufacturer names for professional communications
    BUSINESS BENEFIT: Consistent, professional appearance in customer-facing reports
    */
    
    // Create professional display names for customer communications
    AddDisplayName = Table.AddColumn(AddSurrogateKey, "FranchiseDisplayName", each 
        if [Franchise] <> null and [Franchise] <> "" then Text.Proper([Franchise])
        else "Unknown Franchise", type text),
    
    // Maintain original franchise code for technical lookups
    AddFranchiseCode = Table.AddColumn(AddDisplayName, "FranchiseCode", each 
        [Franchise], type text),
    
    // ========================================================================
    // STEP 5: INTELLIGENT MANUFACTURER CLASSIFICATION
    // ========================================================================
    /*
    PURPOSE: Classify manufacturers by business importance and equipment specialization
    BUSINESS LOGIC: Primary brands prioritized, with equipment type specialization
    ANALYTICS BENEFIT: Enables strategic manufacturer analysis and business planning
    */
    
    // Comprehensive manufacturer type classification based on business knowledge
    AddFranchiseType = Table.AddColumn(AddFranchiseCode, "FranchiseType", each 
        let 
            Code = Text.Upper([Franchise] ?? "")
        in 
            // Primary agricultural equipment manufacturers
            if Text.Contains(Code, "JOHN DEERE") or Text.Contains(Code, "JD") then "John Deere"
            else if Text.Contains(Code, "CASE") then "Case IH"
            else if Text.Contains(Code, "NEW HOLLAND") or Text.Contains(Code, "NH") then "New Holland"
            else if Text.Contains(Code, "KUBOTA") then "Kubota"
            
            // Construction and industrial equipment
            else if Text.Contains(Code, "CAT") or Text.Contains(Code, "CATERPILLAR") then "Caterpillar"
            
            // Other manufacturers and unclassified
            else "Other", 
        type text),
    
    // ========================================================================
    // STEP 6: EQUIPMENT CATEGORY & BUSINESS SEGMENTATION
    // ========================================================================
    /*
    PURPOSE: Group manufacturers by equipment business segments
    BUSINESS LOGIC: Agricultural vs Construction equipment for market analysis
    STRATEGIC BENEFIT: Enables business line analysis and market positioning
    */
    
    // Equipment category classification for business line analysis
    AddFranchiseCategory = Table.AddColumn(AddFranchiseType, "FranchiseCategory", each 
        let manufacturerType = [FranchiseType] ?? ""
        in if List.Contains({"John Deere", "Case IH", "New Holland", "Kubota"}, manufacturerType) then "Agricultural Equipment"
        else if manufacturerType = "Caterpillar" then "Construction Equipment"
        else "Other Equipment", 
        type text),
    
    // ========================================================================
    // STEP 7: BUSINESS PRIORITY & STRATEGIC ORDERING
    // ========================================================================
    /*
    PURPOSE: Establish manufacturer priority for business analysis and reporting
    BUSINESS LOGIC: Primary brand prioritization with strategic ordering
    REPORTING BENEFIT: Consistent manufacturer ordering across all dashboards
    */
    
    // Strategic sort order for business prioritization
    AddSortOrder = Table.AddColumn(AddFranchiseCategory, "FranchiseSortOrder", each 
        let manufacturerType = [FranchiseType] ?? ""
        in if manufacturerType = "John Deere" then 1          // Primary brand - highest priority
        else if manufacturerType = "Case IH" then 2           // Major agricultural brand
        else if manufacturerType = "Caterpillar" then 3       // Construction equipment leader
        else if manufacturerType = "Kubota" then 4            // Compact equipment specialist
        else if manufacturerType = "New Holland" then 5       // Agricultural equipment brand
        else 99,                                              // Other manufacturers
        type number),
    
    // ========================================================================
    // STEP 8: BUSINESS STATUS & OPERATIONAL FLAGS
    // ========================================================================
    /*
    PURPOSE: Add business intelligence flags for operational and strategic analysis
    BUSINESS LOGIC: Active status determination and primary brand identification
    PERFORMANCE BENEFIT: Pre-calculated flags eliminate complex filtering logic
    */
    
    // Manufacturer status classification
    AddFranchiseStatus = Table.AddColumn(AddSortOrder, "FranchiseStatus", each 
        if [Franchise] <> null and [Franchise] <> "" then "Active"
        else "Inactive", type text),
    
    // Active status flag for efficient filtering
    AddIsActive = Table.AddColumn(AddFranchiseStatus, "IsActive", each 
        [FranchiseStatus] = "Active", type logical),
    
    // Primary brand identification for strategic focus
    AddIsPrimaryBrand = Table.AddColumn(AddIsActive, "IsPrimaryBrand", each 
        [FranchiseType] = "John Deere", type logical),
    
    // Agricultural equipment flag for business line analysis
    AddIsAgriculturalBrand = Table.AddColumn(AddIsPrimaryBrand, "IsAgriculturalBrand", each 
        [FranchiseCategory] = "Agricultural Equipment", type logical),
    
    // Major brand flag for strategic manufacturer focus
    AddIsMajorBrand = Table.AddColumn(AddIsAgriculturalBrand, "IsMajorBrand", each 
        List.Contains({"John Deere", "Case IH", "Caterpillar", "Kubota", "New Holland"}, [FranchiseType] ?? ""), 
        type logical),
    
    // ========================================================================
    // STEP 9: ENHANCED BUSINESS INTELLIGENCE
    // ========================================================================
    /*
    PURPOSE: Add advanced manufacturer intelligence for strategic analysis
    BUSINESS VALUE: Market positioning, competitive analysis, service specialization
    */
    
    // Market position classification based on business strategy
    AddMarketPosition = Table.AddColumn(AddIsMajorBrand, "MarketPosition", each
        let manufacturerType = [FranchiseType] ?? ""
        in if manufacturerType = "John Deere" then "Market Leader"
        else if List.Contains({"Case IH", "Caterpillar"}, manufacturerType) then "Major Competitor"
        else if List.Contains({"Kubota", "New Holland"}, manufacturerType) then "Specialized Brand"
        else "Niche/Other",
        type text),
    
    // Service complexity indicator for technician planning
    AddServiceComplexity = Table.AddColumn(AddMarketPosition, "ServiceComplexity", each
        let category = [FranchiseCategory] ?? ""
        in if category = "Construction Equipment" then "High"      // Complex hydraulics, specialized tools
        else if category = "Agricultural Equipment" then "Medium"  // Seasonal complexity, varied equipment
        else "Standard",                                           // General equipment service
        type text),
    
    // Business priority scoring for resource allocation (1-10 scale)
    AddBusinessPriority = Table.AddColumn(AddServiceComplexity, "BusinessPriority", each
        let manufacturerType = [FranchiseType] ?? ""
        in if manufacturerType = "John Deere" then 10            // Highest business priority
        else if manufacturerType = "Case IH" then 8              // High agricultural priority
        else if manufacturerType = "Caterpillar" then 8          // High construction priority
        else if manufacturerType = "Kubota" then 6               // Medium priority specialist
        else if manufacturerType = "New Holland" then 6          // Medium agricultural priority
        else 3,                                                  // Standard priority
        type number),
    
    // ========================================================================
    // STEP 10: FINAL COLUMN ORGANIZATION & SELECTION
    // ========================================================================
    /*
    PURPOSE: Organize output for optimal reporting and dashboard creation
    STRUCTURE: Keys, identification, classification, business intelligence, operational flags
    */
    
    // Select and organize final columns for business analysis
    SelectFinalColumns = Table.SelectColumns(AddBusinessPriority, {
        // === PRIMARY KEYS & IDENTIFICATION ===
        "FranchiseKey",             // Surrogate key for fact table joins
        "Franchise",                // Original manufacturer code for technical lookups
        "FranchiseCode",            // Duplicate for consistency (maintained from original)
        "FranchiseDisplayName",     // Professional display name for customer communications
        
        // === BUSINESS CLASSIFICATION ===
        "FranchiseType",            // Specific manufacturer identification
        "FranchiseCategory",        // Equipment business line classification
        "MarketPosition",           // Strategic market positioning
        "ServiceComplexity",        // Service requirement classification
        
        // === BUSINESS PRIORITY & ORDERING ===
        "FranchiseSortOrder",       // Strategic sort order for consistent reporting
        "BusinessPriority",         // Business importance scoring (1-10)
        
        // === OPERATIONAL STATUS ===
        "FranchiseStatus",          // Active/Inactive status
        
        // === BUSINESS INTELLIGENCE FLAGS ===
        "IsActive",                 // Active status flag
        "IsPrimaryBrand",           // Primary brand identification
        "IsAgriculturalBrand",      // Agricultural equipment flag
        "IsMajorBrand"              // Major manufacturer flag
    }),
    
    // ========================================================================
    // STEP 11: COLUMN REORDERING FOR LOGICAL PRESENTATION
    // ========================================================================
    /*
    PURPOSE: Organize columns for intuitive business analysis and reporting
    STRATEGY: Keys first, then identification, classification, business intelligence
    */
    
    ReorderColumns = Table.ReorderColumns(SelectFinalColumns, {
        // Primary identification
        "FranchiseKey", "Franchise", "FranchiseCode", "FranchiseDisplayName", 
        
        // Business classification  
        "FranchiseType", "FranchiseCategory", "MarketPosition", "ServiceComplexity",
        
        // Business priority and ordering
        "FranchiseSortOrder", "BusinessPriority",
        
        // Status and flags
        "FranchiseStatus", "IsActive", "IsPrimaryBrand", "IsAgriculturalBrand", "IsMajorBrand"
    }),
    
    // ========================================================================
    // STEP 12: DATA TYPE OPTIMIZATION
    // ========================================================================
    /*
    PURPOSE: Optimize storage and query performance with appropriate data types
    STRATEGY: Consistent types for reliable joins and efficient business analysis
    */
    
    SetDataTypes = Table.TransformColumnTypes(ReorderColumns, {
        // Keys and identification
        {"FranchiseKey", Int64.Type}, {"Franchise", type text}, {"FranchiseCode", type text}, 
        {"FranchiseDisplayName", type text},
        
        // Business classification
        {"FranchiseType", type text}, {"FranchiseCategory", type text}, {"MarketPosition", type text}, 
        {"ServiceComplexity", type text},
        
        // Business priority and ordering
        {"FranchiseSortOrder", type number}, {"BusinessPriority", type number},
        
        // Status and flags
        {"FranchiseStatus", type text}, {"IsActive", type logical}, {"IsPrimaryBrand", type logical}, 
        {"IsAgriculturalBrand", type logical}, {"IsMajorBrand", type logical}
    }),
    
    // ========================================================================
    // STEP 13: SPECIAL RECORDS FOR DATA QUALITY
    // ========================================================================
    /*
    PURPOSE: Create special manufacturer records for robust dimensional modeling
    BUSINESS LOGIC: Handle missing/unknown manufacturers in fact tables gracefully
    BEST PRACTICE: Prevents orphaned records and enables complete business analysis
    */
    
    // Create special manufacturer records for data quality
    SpecialManufacturers = Table.FromRecords({
        // Unknown manufacturer record (FranchiseKey = -1)
        [FranchiseKey = -1, Franchise = "UNKNOWN", FranchiseCode = "UNKNOWN", 
         FranchiseDisplayName = "Unknown Manufacturer", FranchiseType = "Unknown", 
         FranchiseCategory = "Unknown", MarketPosition = "Unknown", ServiceComplexity = "Unknown",
         FranchiseSortOrder = 999, BusinessPriority = 1, FranchiseStatus = "Unknown", 
         IsActive = false, IsPrimaryBrand = false, IsAgriculturalBrand = false, IsMajorBrand = false]
    }),
    
    // Set data types for special records to match main table
    SpecialManufacturersTyped = Table.TransformColumnTypes(SpecialManufacturers, {
        {"FranchiseKey", Int64.Type}, {"Franchise", type text}, {"FranchiseCode", type text}, 
        {"FranchiseDisplayName", type text}, {"FranchiseType", type text}, {"FranchiseCategory", type text}, 
        {"MarketPosition", type text}, {"ServiceComplexity", type text}, {"FranchiseSortOrder", type number}, 
        {"BusinessPriority", type number}, {"FranchiseStatus", type text}, {"IsActive", type logical}, 
        {"IsPrimaryBrand", type logical}, {"IsAgriculturalBrand", type logical}, {"IsMajorBrand", type logical}
    }),
    
    // ========================================================================
    // STEP 14: FINAL INTEGRATION & OPTIMIZATION
    // ========================================================================
    /*
    PURPOSE: Complete manufacturer dimension with comprehensive business intelligence
    RESULT: Enterprise-ready manufacturer dimension for strategic analysis
    */
    
    // Combine special records with regular manufacturers
    CombinedManufacturers = Table.Combine({SpecialManufacturersTyped, SetDataTypes}),
    
    // Final sort by business priority for optimal report ordering
    FinalSort = Table.Sort(CombinedManufacturers, {{"FranchiseSortOrder", Order.Ascending}})

in
    FinalSort