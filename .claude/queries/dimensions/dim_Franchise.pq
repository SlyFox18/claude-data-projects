/*
============================================================================
Dimension: dim_Franchise (COMPREHENSIVE MANUFACTURER & EQUIPMENT BRAND DIMENSION)
Dataflow: df_Dim_Franchise
Location: LH_Master_Data → Dataflows → 03 - Dimensions
============================================================================

📋 METADATA:
Source: jdis_Part_Information (Lakehouse table - Franchise field)
Purpose: Master equipment manufacturer dimension for brand performance and business analysis
Created: [Unknown - pre-dates current documentation]
Last Modified: 08/20/2025
Output: Lakehouse table "dim_Franchise"

⏱️ REFRESH CHARACTERISTICS:
Refresh Schedule: Not scheduled (reference data - recommend monthly)
Average Refresh Time: ~1:30 minutes
Refresh Strategy: Full refresh with distinct values + business intelligence enrichment
Row Count: 43 distinct franchises/manufacturers (as of documentation)
Query Folding: No (Lakehouse source with extensive in-memory transformations)

📊 DIMENSION TYPE: **Type 1 - Slowly Changing Dimension (Overwrite)**
- **Infrequent changes** - new manufacturers added occasionally
- **No SCD tracking** - current state only
- **Source-driven** - derived from active parts in jdis_Part_Information
- **Business intelligence enrichment** - extensive classification and scoring

🎯 BUSINESS USE CASES:
• Manufacturer Performance: Brand reliability analysis and service pattern identification
• Parts Management: Manufacturer-specific parts analysis and inventory optimization
• Warranty Analysis: Brand-specific warranty claims and reimbursement tracking
• Equipment Strategy: Manufacturer mix analysis for fleet and inventory decisions
• Service Specialization: Technician assignment based on equipment brand expertise
• Customer Analysis: Customer preference tracking by equipment manufacturer
• Territory Planning: Brand presence and market penetration by geographic region
• Financial Analysis: Revenue and profitability analysis by equipment manufacturer

📊 DATA STRUCTURE (15 COLUMNS - COMPREHENSIVE BUSINESS INTELLIGENCE):

**Primary Keys & Identification (4 columns):**
• FranchiseKey (Int64) - Surrogate key for relationships (-1 = Unknown)
• Franchise (text) - Original manufacturer code (UPPERCASE normalized)
• FranchiseCode (text) - Duplicate of Franchise (maintained for consistency)
• FranchiseDisplayName (text) - Professional display name (proper case)

**Business Classification (4 columns):**
• FranchiseType (text) - Specific manufacturer identification:
  - "John Deere" (primary agricultural brand)
  - "Case IH" (major agricultural brand)
  - "Caterpillar" (construction equipment leader)
  - "Kubota" (compact equipment specialist)
  - "New Holland" (agricultural equipment brand)
  - "Other" (other manufacturers)
• FranchiseCategory (text) - Equipment business line:
  - "Agricultural Equipment" (John Deere, Case IH, New Holland, Kubota)
  - "Construction Equipment" (Caterpillar)
  - "Other Equipment" (unclassified)
• MarketPosition (text) - Strategic market positioning:
  - "Market Leader" (John Deere)
  - "Major Competitor" (Case IH, Caterpillar)
  - "Specialized Brand" (Kubota, New Holland)
  - "Niche/Other" (all other manufacturers)
• ServiceComplexity (text) - Service requirement classification:
  - "High" (Construction equipment - complex hydraulics, specialized tools)
  - "Medium" (Agricultural equipment - seasonal complexity, varied equipment)
  - "Standard" (general equipment service)

**Business Priority & Ordering (2 columns):**
• FranchiseSortOrder (number) - Strategic sort order:
  - 1 = John Deere (primary brand)
  - 2 = Case IH
  - 3 = Caterpillar
  - 4 = Kubota
  - 5 = New Holland
  - 99 = Other manufacturers
  - 999 = Unknown
• BusinessPriority (number) - Business importance scoring (1-10 scale):
  - 10 = John Deere (highest priority)
  - 8 = Case IH, Caterpillar (high priority)
  - 6 = Kubota, New Holland (medium priority)
  - 3 = Other manufacturers (standard priority)
  - 1 = Unknown

**Operational Status (1 column):**
• FranchiseStatus (text) - Active/Inactive/Unknown status

**Business Intelligence Flags (4 columns):**
• IsActive (logical) - Active status flag
• IsPrimaryBrand (logical) - Primary brand identification (John Deere = true)
• IsAgriculturalBrand (logical) - Agricultural equipment flag
• IsMajorBrand (logical) - Major manufacturer flag (John Deere, Case IH, Caterpillar, Kubota, New Holland)

**Special Records:**
• Unknown Manufacturer (FranchiseKey = -1) - Data quality/orphan handling

🔧 DESIGN PRINCIPLES:

**Distinct Values Pattern:**
• Extracts unique Franchise values from jdis_Part_Information
• Source table: 1.08M parts → 43 distinct franchises
• Automatically captures new manufacturers as parts are added
• Self-updating from source (no manual maintenance)

**Business Intelligence Enrichment:**
• **Text Normalization**: UPPERCASE, trimmed, cleaned for consistency
• **Professional Display**: Proper case for customer-facing reports
• **Manufacturer Classification**: Pattern matching (contains "JOHN DEERE", "JD", etc.)
• **Equipment Segmentation**: Agricultural vs Construction business lines
• **Market Positioning**: Strategic classification (Leader, Competitor, Specialist, Niche)
• **Service Complexity**: Service requirement classification for technician planning
• **Business Priority Scoring**: 1-10 scale for resource allocation
• **Strategic Ordering**: Consistent sort order across all reports

**Manufacturer Classification Logic:**
1. **John Deere**: Contains "JOHN DEERE" or "JD" → Type: "John Deere"
2. **Case IH**: Contains "CASE" → Type: "Case IH"
3. **New Holland**: Contains "NEW HOLLAND" or "NH" → Type: "New Holland"
4. **Kubota**: Contains "KUBOTA" → Type: "Kubota"
5. **Caterpillar**: Contains "CAT" or "CATERPILLAR" → Type: "Caterpillar"
6. **Other**: All other values → Type: "Other"

**Equipment Category Logic:**
• **Agricultural Equipment**: John Deere, Case IH, New Holland, Kubota
• **Construction Equipment**: Caterpillar
• **Other Equipment**: All other manufacturers

**Data Quality Steps:**
1. Select Franchise column from source
2. Clean: UPPERCASE, Trim, Clean (null handling)
3. Distinct: Get unique manufacturer codes
4. Sort: Alphabetical for processing
5. Add Surrogate Key: Sequential starting at 1
6. Add Display Name: Proper case for customer communications
7. Classify: Manufacturer type, category, market position
8. Score: Business priority and sort order
9. Add Flags: Active, Primary, Agricultural, Major brand
10. Append Unknown: -1 key for orphan handling
11. Final Sort: By FranchiseSortOrder

**Unknown Record Handling:**
• FranchiseKey = -1 for unknown/unmapped manufacturers
• Complete attribute set (all flags = false, priority = 1, sort = 999)
• Prevents orphaned records in fact tables
• Enables complete business analysis

🔗 RELATIONSHIPS:

**Fact Table Relationships (Many-to-One):**
- **Fact_WorkOrderParts** → FranchiseKey (parts manufacturer analysis)
- **Fact_WorkOrderHeader** → ManufacturerKey = FranchiseKey (equipment service analysis)
- **Fact_WarrantyClaims** → FranchiseKey (warranty performance by brand)
- **dim_Parts** → Franchise (natural key - parts-to-manufacturer relationship)

**Related Dimensions:**
- Works with dim_Parts for complete parts classification
- May relate to customer dimensions for equipment preference analysis
- May relate to territory dimensions for brand market penetration

⚠️ IMPORTANT NOTES:

**Refresh Strategy:**
• **RECOMMENDED**: Monthly refresh (reference data changes infrequently)
• **NOT RECOMMENDED**: Daily refresh (unnecessary overhead)
• **TRIGGER**: Refresh when new manufacturers appear in jdis_Part_Information
• **FUTURE PIPELINE**: Consider "Reference Data Pipeline" (first Monday of month at 8:00 AM)

**Performance Considerations:**
• Current refresh time: ~1:30 minutes
• Row count: 43 (very small - excellent performance)
• Source: 1.08M parts → 43 distinct franchises (excellent reduction)
• Extensive transformations: Classification, scoring, flags
• ~1:30 is reasonable given business intelligence enrichment

**Business Intelligence Value:**
• **15 columns** of manufacturer intelligence (vs 2 for simple dimension)
• **Pattern-based classification** captures business knowledge
• **Pre-calculated flags** eliminate complex DAX in reports
• **Strategic ordering** provides consistent brand presentation
• **Business priority scoring** enables resource allocation analysis

**Manufacturer Classification Accuracy:**
• Pattern matching may need refinement for edge cases
• New manufacturers default to "Other" (manual review needed)
• Review classification periodically for business accuracy
• Update patterns if manufacturer codes change

**Strategic Business Alignment:**
• **Primary Brand**: John Deere (Sort: 1, Priority: 10, IsPrimaryBrand: true)
• **Major Agricultural**: Case IH (Sort: 2, Priority: 8)
• **Construction Leader**: Caterpillar (Sort: 3, Priority: 8)
• **Specialists**: Kubota, New Holland (Sort: 4-5, Priority: 6)
• **Other**: Niche manufacturers (Sort: 99, Priority: 3)

**Service Complexity Intelligence:**
• **High Complexity**: Construction equipment (specialized tools, hydraulics)
• **Medium Complexity**: Agricultural equipment (seasonal, varied)
• **Standard Complexity**: General equipment (routine service)
• Enables technician assignment and training planning

**Data Quality:**
• 43 distinct franchises from 1.08M parts (good coverage)
• UPPERCASE normalization prevents "JD" vs "jd" duplicates
• Text cleaning removes non-printable characters
• Unknown record ensures complete fact table coverage

**Lakehouse Source Pattern:**
• Reads from Lakehouse table (not raw ODBC source)
• Depends on jdis_Part_Information being refreshed first
• No query folding (extensive in-memory transformations)
• Transformations add significant business value

Dependencies:
• jdis_Part_Information (Lakehouse table - must refresh first)

Used By:
• Fact_WorkOrderParts (parts manufacturer analysis)
• Fact_WorkOrderHeader (equipment service analysis)
• Fact_WarrantyClaims (warranty performance analysis)
• dim_Parts (manufacturer classification lookup)
• Manufacturer performance dashboards
• Brand reliability scorecards
• Equipment mix analysis reports
• Territory and market penetration analysis

Related Dimensions:
• dim_Parts (primary consumer of franchise codes)
• dim_DateTable (time-based manufacturer analysis)
• dim_BranchLocation (territory-based brand analysis)

Critical Finding:
**Most comprehensive manufacturer dimension - 15 columns of business intelligence**
**Self-updating dimension - automatically captures new manufacturers**
**Strategic classification enables brand performance and market analysis**
**Monthly refresh recommended (reference data changes infrequently)**
**43 manufacturers from 1.08M parts = complete coverage**

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

/*
============================================================================
✅ PRODUCTION STATUS: READY - MONTHLY REFRESH RECOMMENDED
============================================================================

🎯 IMPLEMENTATION SUMMARY:
• Type 1 Dimension: Overwrite, no historical tracking
• 43 Distinct Manufacturers: Extracted from 1.08M parts
• 15 Columns: Comprehensive business intelligence
• Self-Updating: Automatically captures new manufacturers from source
• Reference Data: Changes infrequently (monthly refresh adequate)

📊 DIMENSION CHARACTERISTICS:
• **Grain**: One row per manufacturer/franchise
• **Keys**: FranchiseKey (surrogate), Franchise (natural)
• **Attributes**: 15 columns (identification, classification, business intelligence, flags)
• **SCD Type**: Type 1 (no historical tracking)
• **Unknown Record**: -1 key for orphan handling
• **Business Intelligence**: Pattern-based classification, scoring, flags

🔗 RELATIONSHIP READY:
• **Primary Consumers**: Fact_WorkOrderParts, Fact_WorkOrderHeader, Fact_WarrantyClaims, dim_Parts
• **Join Keys**: FranchiseKey (surrogate), Franchise (natural)
• **Cardinality**: Many-to-One (many parts/work orders per manufacturer)
• **Filter Direction**: Single (dim → fact)

⚡ REFRESH STRATEGY:

**RECOMMENDED: Monthly Reference Data Pipeline**
• **Schedule**: First Monday of month at 8:00 AM
• **Frequency**: Monthly (or as needed)
• **Duration**: ~1:30 minutes (reasonable given 15 columns of business intelligence)
• **Rationale**: Reference data rarely changes

**NOT RECOMMENDED: Daily Refresh**
• Unnecessary overhead for slowly changing data
• Save CU capacity for dynamic tables
• Manufacturers added infrequently

**Dependencies:**
• jdis_Part_Information must be current (refreshed first)

📝 MAINTENANCE CHECKLIST:

**Data Quality Checks:**
1. ✅ Verify 43 distinct manufacturers extracted
2. ✅ Confirm no blank/null records
3. ✅ Check text UPPERCASE normalized
4. ✅ Verify unknown record (-1) present
5. ✅ Confirm FranchiseSortOrder accuracy (John Deere = 1)
6. ✅ Validate manufacturer classification logic

**When Adding to Monthly Pipeline:**
1. ✅ Schedule first Monday of month at 8:00 AM
2. ✅ Ensure jdis_Part_Information refreshes first
3. ✅ Group with other reference dimensions
4. ✅ Test refresh duration (~1:30 expected)

**Manufacturer Classification Review:**
1. 📋 Review pattern matching accuracy for new manufacturers
2. 📋 Update classification logic if manufacturer codes change
3. 📋 Validate business priority scoring aligns with strategy
4. 📋 Confirm equipment category assignments

**Troubleshooting:**
• **New manufacturers classified as "Other"**: Review pattern matching logic
• **Incorrect equipment category**: Check FranchiseType classification
• **Sort order issues**: Verify FranchiseSortOrder values
• **Missing manufacturers in reports**: Check IsActive flag

**NEVER:**
❌ Change FranchiseKey generation logic (breaks fact table joins)
❌ Remove unknown record (breaks orphan handling)
❌ Skip text normalization (creates duplicate keys)
❌ Schedule daily refresh (wastes CU capacity)

**BUSINESS INTELLIGENCE NOTES:**
This is one of the most sophisticated dimensions in the model with 15 columns of business intelligence.
The extensive classification, scoring, and flagging eliminates complex DAX calculations in reports.
Pattern-based manufacturer classification captures critical business knowledge.
Monthly refresh adequate - manufacturers change infrequently.

============================================================================
*/
