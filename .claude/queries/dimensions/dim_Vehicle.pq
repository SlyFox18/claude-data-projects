/*
============================================================================
DIM_VEHICLE - COMPREHENSIVE VEHICLE & EQUIPMENT MASTER DIMENSION
============================================================================

📋 METADATA:
Table Name: dim_Vehicle
Dataflow: df_Dim_Vehicle
Purpose: Central vehicle and equipment dimension for service operations and fleet management
Grain: One row per unique vehicle/equipment unit (fleet vehicles + stock inventory)
Last Modified: 08/15/2025

🔄 REFRESH CHARACTERISTICS:
Row Count: 71,640 vehicles/equipment units
Avg Refresh Time: ~2 minutes
Refresh Schedule: Not scheduled (not yet in use - awaiting future requirements)
Refresh Strategy: Full refresh with dual-source integration (prepared for incremental)
Source Tables: Raw_VehicleFleet, Raw_VehicleStock

📊 DIMENSION TYPE: Type 1 (Overwrite) with Dual-Source Integration
Changes: Vehicle updates overwrite existing records
History: No historical tracking (current state only)
Updates: Full refresh combines fleet and stock vehicles

🎯 BUSINESS CONTEXT:

**Future Potential (Not Yet Deployed):**
This dimension is prepared for future service reporting requirements and represents
significant potential for enhanced operations management. Currently built and tested
but not scheduled for production use pending business requirements finalization.

**When Deployed, Will Support:**
• Service Operations: Vehicle identification for work order assignment and service history
• Fleet Management: Vehicle age analysis, replacement planning, utilization tracking
• Maintenance Planning: Equipment reliability analysis and preventive maintenance scheduling
• Parts Management: Equipment-specific parts inventory and ordering optimization
• Asset Management: Vehicle portfolio analysis, depreciation tracking, lifecycle management
• Performance Analytics: Service frequency patterns and equipment reliability scoring

📊 DATA STRUCTURE (26 Columns - Comprehensive Intelligence):

**Primary Keys & Identifiers:**
• VehicleKey: Surrogate key for fact table joins
• VehicleIdentifier: Unique vehicle identifier from source
• PrimaryLookup: **CRITICAL** - Matches Fact_WorkOrderHeader VehicleLookupKey

**Vehicle Identification:**
• Registration: Vehicle registration number (primary identifier for fleet)
• StockNumber: Stock/inventory number (primary identifier for stock)
• VIN: Vehicle Identification Number (legal/warranty compliance)

**Vehicle Specifications:**
• VehicleSource: "Fleet" (customer-owned) or "Stock" (dealer inventory)
• Make: Manufacturer name (Proper case)
• Model: Vehicle model (Proper case)
• MakeModel: Combined "Make Model" for display
• Year: Model year (integer)
• Engine: Engine specifications

**Age & Lifecycle Analysis:**
• VehicleAge: Calculated age in years
• AgeCategory: Lifecycle stage (New/Recent/Mature/Older)

**Status & Availability:**
• Status: Current vehicle status from source
• IsActive: Boolean - Available for service (filters out Inactive/Disposed/Sold/Scrapped)

**Business Classification:**
• VehicleType: "Fleet Vehicle" or "Stock Vehicle"
• VehicleCategory: Equipment type (Heavy Equipment/Commercial Truck/Domestic/Import/Other)

**Service Intelligence (Pre-calculated Business Logic):**
• ServiceComplexity: Service difficulty (High/Medium/Standard)
• WarrantyLikelihood: Warranty coverage probability (Very High/High/Medium/Low/Unlikely)
• PartsAvailability: Parts availability assessment (Excellent/Good/Fair/Limited)
• MaintenancePriority: Maintenance priority score (1-10 scale, higher = more critical)

**Identification Flags:**
• HasVIN: Boolean - VIN availability for warranty processing

**Display Options (Multiple naming strategies):**
• VehicleDisplayName: Comprehensive "YYYY Make Model (Registration)" format
• VehicleShortName: Compact display (Registration or "S" + StockNumber)

**Data Quality:**
• DataQualityScore: Completeness score (0-100) for service readiness

🔧 KEY DESIGN FEATURES:

**1. Dual-Source Integration:**
- **Fleet Vehicles**: Customer-owned equipment with Registration numbers
- **Stock Vehicles**: Dealer inventory with Stock numbers
- Unified lookup strategy: Registration first, then "Stk# " + StockNumber
- Consistent identification across both sources

**2. PrimaryLookup Field (CRITICAL):**
- Must exactly match Fact_WorkOrderHeader VehicleLookupKey logic
- Logic: Registration → "Stk# " + StockNumber → VehicleIdentifier (priority order)
- Enables accurate work order vehicle assignment
- Essential for service operations integration

**3. Sophisticated Equipment Categorization:**
- **Heavy Equipment**: Caterpillar, John Deere, Case, New Holland, Kubota, Bobcat, etc.
- **Commercial Truck**: Freightliner, Peterbilt, Kenworth, Volvo, Mack, International
- **Domestic**: Ford, Chevrolet, GMC, Dodge, RAM, Chrysler, Jeep
- **Import**: Toyota, Honda, Nissan, Subaru, BMW, Mercedes, Audi, etc.
- **Other**: Unrecognized manufacturers

**4. Age Analysis & Lifecycle Categories:**
- **New (0-2 years)**: Latest technology, warranty coverage, minimal maintenance
- **Recent (3-5 years)**: Optimal reliability, moderate maintenance
- **Mature (6-10 years)**: Increased maintenance, proven reliability
- **Older (10+ years)**: High maintenance, replacement candidates

**5. Service Intelligence (Pre-calculated):**
- **ServiceComplexity**: Based on equipment category
  - Heavy Equipment/Commercial Truck = High (specialized skills, expensive parts)
  - Import = Medium (specialized parts, diagnostic tools)
  - Other = Standard (standard automotive service)

- **WarrantyLikelihood**: Based on age, category, VIN availability
  - Age ≤ 1 year + HasVIN = Very High (manufacturer warranty)
  - Age ≤ 3 years + Heavy Equipment = High (extended warranties)
  - Age ≤ 2 years = Medium (standard warranty period)
  - No VIN or older = Low/Unlikely

- **PartsAvailability**: Based on make, category, age
  - Ford/Chevy/Toyota/Honda = Excellent (common makes)
  - Heavy Equipment ≤ 15 years = Good (equipment parts networks)
  - Import ≤ 10 years = Good (import distribution)
  - Age ≤ 8 years = Good (general availability)
  - Older vehicles = Fair/Limited

- **MaintenancePriority** (1-10 scale):
  - Inactive = 1 (lowest priority)
  - Heavy Equipment ≥ 8 years = 9 (critical aging equipment)
  - Commercial Truck ≥ 7 years = 8 (compliance critical)
  - Age ≥ 12 years = 7 (very old, needs attention)
  - Progressive scoring based on age and category

**6. Data Quality Scoring (0-100):**
- Identification (40 points): Registration (20) + VIN (20)
- Vehicle Details (30 points): Make/Model (15) + Year (15)
- Service Readiness (30 points): Engine (10) + Status (10) + Source (10)
- Enables identification of records needing data enhancement

**7. Multiple Display Name Strategies:**
- **VehicleDisplayName**: "2020 Ford F-150 (ABC123)" - Professional, comprehensive
- **VehicleShortName**: "ABC123" or "S1234" - Compact, space-efficient
- **MakeModel**: "Ford F-150" - Simple, clean
- Different contexts require different naming approaches

🔗 RELATIONSHIPS (When Deployed):

**Planned Fact Table Relationships:**
• Fact_WorkOrderHeader → dim_Vehicle (via PrimaryLookup/VehicleLookupKey)
• Fact_WorkOrderParts → dim_Vehicle (equipment-specific parts analysis)
• Fact_WarrantyClaims → dim_Vehicle (via VIN for warranty tracking)
• Fact_ServiceHistory → dim_Vehicle (maintenance history tracking)

Relationship Pattern:
• Fact[VehicleLookupKey] → dim_Vehicle[PrimaryLookup]
• Cardinality: Many-to-One
• Cross-filter Direction: Single (dimension filters facts)

�� FUTURE APPLICATIONS (When Deployed):

**Fleet Analytics Dashboards:**
• Fleet Portfolio: Age distribution and replacement planning
• Equipment Utilization: Service frequency and downtime patterns
• Manufacturer Performance: Reliability comparison by make
• Maintenance Scheduling: Age-based preventive maintenance calendar

**Service Operations:**
• Work Order Assignment: PrimaryLookup enables accurate vehicle identification
• Parts Planning: Equipment-specific inventory management
• Warranty Management: VIN-based warranty claim processing
• Customer Communications: Professional vehicle identification

**Business Intelligence:**
• Equipment ROI Analysis: Service costs vs age and utilization
• Replacement Planning: Age category analysis for capital decisions
• Service Pattern Recognition: Equipment type/age correlation with maintenance
• Manufacturer Evaluation: Brand performance for future purchases

📋 IMPORTANT NOTES:

**Current Status:**
- **Not yet in production use** - awaiting business requirements
- Built and tested, ready for deployment
- Refresh strategy to be determined when use cases are defined
- ~2 minute refresh time is excellent for 71,640 vehicles

**Deployment Considerations:**
- Determine refresh schedule based on service reporting needs
  - Daily if real-time work order assignment needed
  - Weekly if used for analytics only
  - Monthly if used for strategic planning

**Performance:**
- 71,640 rows in ~2 minutes = excellent performance
- Dual-source combination optimized
- Ready for incremental refresh if needed (RangeStart/RangeEnd parameters)
- Multiple calculated fields pre-computed for report performance

**Critical Integration Point:**
- **PrimaryLookup field** must match Fact_WorkOrderHeader logic exactly
- Test thoroughly before production deployment
- Validate vehicle matching accuracy with sample work orders

**Extensibility:**
- Framework ready for additional intelligence
- Can add customer ownership tracking
- Can add maintenance cost history
- Can add depreciation calculations
- Can add GPS/location tracking (if available)

**Data Quality:**
- Monitor DataQualityScore distribution
- Identify vehicles with low scores needing data enhancement
- VIN completeness critical for warranty processing
- Registration completeness critical for fleet vehicle identification

============================================================================
*/

let
    // ========================================================================
    // STEP 1: INCREMENTAL REFRESH SETUP & FOUNDATION PARAMETERS
    // ========================================================================
    /*
    PURPOSE: Establish refresh parameters and business constants for vehicle analysis
    PERFORMANCE: Ready for incremental refresh when source tables support modification tracking
    BUSINESS LOGIC: Current year calculation enables dynamic age analysis
    */

    // Incremental refresh parameters (ready for future implementation)
    RangeStart = #datetime(2023, 1, 1, 0, 0, 0),
    RangeEnd = DateTime.LocalNow(),
    CurrentYear = Date.Year(DateTime.Date(DateTime.LocalNow())),

    // ========================================================================
    // STEP 2: DUAL-SOURCE DATA PREPARATION & LOOKUP KEY GENERATION
    // ========================================================================
    /*
    PURPOSE: Prepare both fleet and stock vehicle data with consistent lookup strategies
    BUSINESS LOGIC: Fleet vehicles use Registration, Stock vehicles use "Stk# " prefix
    INTEGRATION: Lookup keys must match Fact_WorkOrderHeader VehicleLookupKey logic
    PERFORMANCE: Early key generation optimizes downstream join operations
    */

    // Enhance Raw_VehicleFleet with registration-based lookup keys
    FleetEnhanced = Table.AddColumn(Raw_VehicleFleet, "LookupKey", each
        Text.Upper(Text.Trim([Registration] ?? "")), type text),

    // Enhance Raw_VehicleStock with stock number-based lookup keys
    StockEnhanced = Table.AddColumn(Raw_VehicleStock, "LookupKey", each
        "Stk# " & Text.Trim(Text.From([StockNumber] ?? "")), type text),

    // ========================================================================
    // STEP 3: INTELLIGENT DATA COMBINATION & DEDUPLICATION
    // ========================================================================
    /*
    PURPOSE: Combine fleet and stock vehicles while maintaining data integrity
    BUSINESS LOGIC: Prioritize most complete records when duplicates exist
    DATA QUALITY: Filter out records without valid identification
    */

    // Combine both vehicle sources into unified dataset
    CombinedTables = Table.Combine({FleetEnhanced, StockEnhanced}),

    // Remove duplicates based on comprehensive vehicle identifier
    RemoveDuplicates = Table.Distinct(CombinedTables, {"VehicleIdentifier"}),

    // Filter for valid vehicle records (must have Registration OR StockNumber)
    FilterValidRecords = Table.SelectRows(RemoveDuplicates, each
        (([Registration] ?? "") <> "") or
        (([StockNumber] ?? "") <> "") or
        (([VehicleIdentifier] ?? "") <> "")),

    // ========================================================================
    // STEP 4: SURROGATE KEY GENERATION & UNIQUE IDENTIFICATION
    // ========================================================================
    /*
    PURPOSE: Create artificial primary key for optimal fact table relationships
    BUSINESS BENEFIT: Enables efficient star schema joins and referential integrity
    */

    // Add surrogate key for optimal database performance
    AddSurrogateKey = Table.AddIndexColumn(FilterValidRecords, "VehicleKey", 1, 1, Int64.Type),

    // ========================================================================
    // STEP 5: COMPREHENSIVE DATA CLEANING & STANDARDIZATION
    // ========================================================================
    /*
    PURPOSE: Ensure consistent data quality across all vehicle identification fields
    BUSINESS BENEFIT: Reliable vehicle identification and professional reporting
    APPROACH: Batch transformations for optimal performance with proper null handling
    */

    // Clean and standardize vehicle registration (uppercase for consistency)
    CleanRegistration = Table.TransformColumns(AddSurrogateKey, {
        {"Registration", each Text.Upper(Text.Trim(_ ?? "")), type text}
    }),

    // Clean and standardize stock numbers (preserve original format)
    CleanStockNumber = Table.TransformColumns(CleanRegistration, {
        {"StockNumber", each Text.Trim(Text.From(_ ?? "")), type text}
    }),

    // Clean and standardize manufacturer names (proper case for professional display)
    CleanMake = Table.TransformColumns(CleanStockNumber, {
        {"Make", each Text.Proper(Text.Trim(_ ?? "Unknown")), type text}
    }),

    // Clean and standardize model names (proper case for professional display)
    CleanModel = Table.TransformColumns(CleanMake, {
        {"Model", each Text.Proper(Text.Trim(_ ?? "Unknown")), type text}
    }),

    // Clean and standardize VIN numbers (uppercase for legal compliance)
    CleanVIN = Table.TransformColumns(CleanModel, {
        {"VIN", each Text.Upper(Text.Trim(_ ?? "")), type text}
    }),

    // Clean status information (proper case for business display) - SKIP Engine for now
    CleanStatus = Table.TransformColumns(CleanVIN, {
        {"Status", each Text.Proper(Text.Trim(_ ?? "Unknown")), type text}
    }),

    // SAFELY add Engine field as calculated column (handles missing field gracefully)
    AddEngineField = Table.AddColumn(CleanStatus, "EngineSpec", each
        try [Engine] otherwise "", type text),

    // ========================================================================
    // STEP 6: CRITICAL LOOKUP KEY GENERATION FOR FACT TABLE INTEGRATION
    // ========================================================================
    /*
    PURPOSE: Create PrimaryLookup field that exactly matches Fact_WorkOrderHeader logic
    BUSINESS LOGIC: Registration first, then "Stk# " + StockNumber, then VehicleIdentifier
    CRITICAL: This field is essential for work order vehicle assignment functionality
    */

    // Create primary lookup field matching work order assignment logic
    AddPrimaryLookup = Table.AddColumn(AddEngineField, "PrimaryLookup", each
        let
            registration = Text.Trim([Registration] ?? ""),
            stockNumber = Text.Trim(Text.From([StockNumber] ?? "")),
            vehicleId = Text.Trim([VehicleIdentifier] ?? "")
        in
            if registration <> "" then registration                         // Priority 1: Registration
            else if stockNumber <> "" then "Stk# " & stockNumber           // Priority 2: Stock with prefix
            else vehicleId,                                                 // Priority 3: Vehicle identifier
        type text),

    // ========================================================================
    // STEP 7: VEHICLE AGE ANALYSIS & LIFECYCLE CATEGORIZATION
    // ========================================================================
    /*
    PURPOSE: Calculate vehicle age and categorize for lifecycle management
    BUSINESS BENEFIT: Replacement planning, maintenance scheduling, depreciation analysis
    ANALYTICS: Enables age-based service pattern analysis and cost optimization
    */

    // Calculate vehicle age in years with null safety
    AddVehicleAge = Table.AddColumn(AddPrimaryLookup, "VehicleAge", each
        let
            vehicleYear = [Year] ?? 0
        in
            if vehicleYear > 1900 and vehicleYear <= CurrentYear then
                CurrentYear - vehicleYear
            else null,
        type number),

    // Categorize vehicles by age for lifecycle management
    AddAgeCategory = Table.AddColumn(AddVehicleAge, "AgeCategory", each
        let age = [VehicleAge] ?? 999
        in if age = 999 then "Unknown"
        else if age <= 2 then "New (0-2 years)"           // Latest technology, warranty coverage
        else if age <= 5 then "Recent (3-5 years)"        // Optimal reliability, moderate maintenance
        else if age <= 10 then "Mature (6-10 years)"      // Increased maintenance, proven reliability
        else "Older (10+ years)",                          // High maintenance, replacement candidates
        type text),

    // ========================================================================
    // STEP 8: VEHICLE IDENTIFICATION & DISPLAY NAME GENERATION
    // ========================================================================
    /*
    PURPOSE: Create multiple naming strategies for different reporting requirements
    BUSINESS BENEFIT: Professional customer communications and flexible report displays
    */

    // Create comprehensive make and model combination
    AddMakeModel = Table.AddColumn(AddAgeCategory, "MakeModel", each
        ([Make] ?? "Unknown") & " " & ([Model] ?? "Unknown"), type text),

    // Enhanced vehicle type classification based on source
    AddVehicleTypeEnhanced = Table.AddColumn(AddMakeModel, "VehicleTypeEnhanced", each
        let source = Text.Trim([VehicleSource] ?? "")
        in if source = "Fleet" then "Fleet Vehicle"       // Customer-owned equipment
        else if source = "Stock" then "Stock Vehicle"     // Dealer inventory
        else "Unknown",                                    // Unclassified vehicles
        type text),

    // VIN availability flag for warranty and legal compliance
    AddHasVIN = Table.AddColumn(AddVehicleTypeEnhanced, "HasVIN", each
        ([VIN] ?? "") <> "", type logical),

    // Active status determination for service scheduling
    AddIsActive = Table.AddColumn(AddHasVIN, "IsActive", each
        let status = Text.Upper([Status] ?? "")
        in not List.Contains({"INACTIVE", "DISPOSED", "SOLD", "SCRAPPED"}, status),
        type logical),

    // ========================================================================
    // STEP 9: PROFESSIONAL DISPLAY NAME STRATEGIES
    // ========================================================================
    /*
    PURPOSE: Generate professional vehicle identification for customer communications
    BUSINESS BENEFIT: Consistent, professional appearance in all customer-facing reports
    */

    // Comprehensive display name for detailed reports and customer communications
    AddDisplayName = Table.AddColumn(AddIsActive, "VehicleDisplayName", each
        let
            year = [Year] ?? 0,
            yearText = if year > 1900 then Text.From(year) & " " else "",
            makeModel = ([Make] ?? "Unknown") & " " & ([Model] ?? "Unknown"),
            registration = Text.Trim([Registration] ?? ""),
            stockNumber = Text.Trim(Text.From([StockNumber] ?? "")),
            vehicleId = Text.Trim([VehicleIdentifier] ?? ""),

            identifier = if registration <> "" then " (" & registration & ")"
                        else if stockNumber <> "" then " (Stk# " & stockNumber & ")"
                        else if vehicleId <> "" then " (" & vehicleId & ")"
                        else ""
        in
            yearText & makeModel & identifier,
        type text),

    // Compact display name for space-constrained reports and mobile interfaces
    AddShortDisplayName = Table.AddColumn(AddDisplayName, "VehicleShortName", each
        let
            registration = Text.Trim([Registration] ?? ""),
            stockNumber = Text.Trim(Text.From([StockNumber] ?? "")),
            vehicleId = Text.Trim([VehicleIdentifier] ?? "")
        in
            if registration <> "" then registration                    // Preferred: Registration
            else if stockNumber <> "" then "S" & stockNumber          // Compact: S + stock number
            else Text.Start(vehicleId, 10),                           // Fallback: Truncated ID
        type text),

    // ========================================================================
    // STEP 10: SOPHISTICATED EQUIPMENT CATEGORIZATION
    // ========================================================================
    /*
    PURPOSE: Classify vehicles by business category for service specialization
    BUSINESS LOGIC: Equipment type determines service requirements, parts inventory, technician skills
    ANALYTICS: Enables manufacturer performance analysis and service pattern optimization
    */

    // Advanced vehicle categorization based on manufacturer and business use
    AddVehicleCategory = Table.AddColumn(AddShortDisplayName, "VehicleCategory", each
        let makeUpper = Text.Upper([Make] ?? "")
        in
            // Heavy Equipment (construction, agriculture, industrial)
            if List.Contains({
                "CATERPILLAR", "CAT", "JOHN DEERE", "DEERE", "CASE", "NEW HOLLAND",
                "KUBOTA", "BOBCAT", "KOMATSU", "HITACHI", "VOLVO CONSTRUCTION"
            }, makeUpper) then "Heavy Equipment"

            // Commercial Trucks (freight, delivery, commercial transport)
            else if List.Contains({
                "FREIGHTLINER", "PETERBILT", "KENWORTH", "VOLVO", "MACK",
                "INTERNATIONAL", "WESTERN STAR", "STERLING"
            }, makeUpper) then "Commercial Truck"

            // Domestic Vehicles (US manufacturers)
            else if List.Contains({
                "FORD", "CHEVROLET", "CHEVY", "GMC", "DODGE", "RAM", "CHRYSLER",
                "CADILLAC", "BUICK", "LINCOLN", "JEEP"
            }, makeUpper) then "Domestic"

            // Import Vehicles (international manufacturers)
            else if List.Contains({
                "TOYOTA", "HONDA", "NISSAN", "SUBARU", "MAZDA", "MITSUBISHI",
                "HYUNDAI", "KIA", "BMW", "MERCEDES", "AUDI", "VOLKSWAGEN"
            }, makeUpper) then "Import"

            // Default category for unrecognized manufacturers
            else "Other",
        type text),

    // ========================================================================
    // STEP 11: ADVANCED EQUIPMENT INTELLIGENCE & SERVICE ANALYTICS
    // ========================================================================
    /*
    PURPOSE: Add sophisticated business intelligence for equipment management
    BUSINESS BENEFIT: Proactive maintenance, service optimization, cost management
    */

    // Service complexity classification based on equipment type
    AddServiceComplexity = Table.AddColumn(AddVehicleCategory, "ServiceComplexity", each
        let category = [VehicleCategory] ?? ""
        in if category = "Heavy Equipment" then "High"      // Specialized skills, expensive parts
        else if category = "Commercial Truck" then "High"   // DOT compliance, commercial requirements
        else if category = "Import" then "Medium"           // Specialized parts, diagnostic tools
        else "Standard",                                     // Standard automotive service
        type text),

    // Warranty likelihood based on age and equipment type
    AddWarrantyLikelihood = Table.AddColumn(AddServiceComplexity, "WarrantyLikelihood", each
        let
            age = [VehicleAge] ?? 999,
            category = [VehicleCategory] ?? "",
            hasVIN = [HasVIN] ?? false
        in
            if not hasVIN then "Unlikely"                   // No VIN = no warranty tracking
            else if age <= 1 then "Very High"               // New equipment under manufacturer warranty
            else if age <= 3 and category = "Heavy Equipment" then "High"  // Extended equipment warranties
            else if age <= 2 then "Medium"                  // Standard vehicle warranties
            else "Low",                                      // Out of typical warranty period
        type text),

    // Parts availability assessment based on manufacturer and age
    AddPartsAvailability = Table.AddColumn(AddWarrantyLikelihood, "PartsAvailability", each
        let
            age = [VehicleAge] ?? 0,
            category = [VehicleCategory] ?? "",
            make = Text.Upper([Make] ?? "")
        in
            if List.Contains({"FORD", "CHEVROLET", "TOYOTA", "HONDA"}, make) then "Excellent"  // Common makes
            else if category = "Heavy Equipment" and age <= 15 then "Good"     // Equipment parts availability
            else if category = "Import" and age <= 10 then "Good"              // Import parts networks
            else if age <= 8 then "Good"                                       // General availability
            else if age <= 15 then "Fair"                                      // Older vehicle challenges
            else "Limited",                                                     // Very old equipment
        type text),

    // Maintenance priority scoring (1-10 scale, higher = more critical)
    AddMaintenancePriority = Table.AddColumn(AddPartsAvailability, "MaintenancePriority", each
        let
            age = [VehicleAge] ?? 0,
            category = [VehicleCategory] ?? "",
            isActive = [IsActive] ?? false
        in
            if not isActive then 1                          // Inactive vehicles = lowest priority
            else if category = "Heavy Equipment" and age >= 8 then 9    // Critical equipment aging
            else if category = "Commercial Truck" and age >= 7 then 8   // Commercial compliance critical
            else if age >= 12 then 7                        // Very old vehicles need attention
            else if age >= 8 then 6                         // Aging vehicles
            else if age >= 5 then 4                         // Mature vehicles
            else if age >= 2 then 3                         // Recent vehicles
            else 2,                                          // New vehicles = minimal priority
        type number),

    // ========================================================================
    // STEP 12: DATA QUALITY ASSESSMENT & COMPLETENESS SCORING
    // ========================================================================
    /*
    PURPOSE: Evaluate vehicle record completeness for service operations
    SCORING: 0-100 scale based on critical field availability
    BUSINESS BENEFIT: Identify vehicles needing data enhancement for optimal service
    */

    AddDataQualityScore = Table.AddColumn(AddMaintenancePriority, "DataQualityScore", each
        let
            // Identification completeness (40 points max)
            hasRegistration = if ([Registration] ?? "") <> "" then 20 else 0,
            hasVIN = if ([VIN] ?? "") <> "" then 20 else 0,

            // Vehicle details completeness (30 points max)
            hasMakeModel = if ([Make] ?? "") <> "" and ([Model] ?? "") <> "" then 15 else 0,
            hasYear = if ([Year] ?? 0) > 1900 then 15 else 0,

            // Service readiness (30 points max)
            hasEngine = if ([EngineSpec] ?? "") <> "" then 10 else 0,
            hasStatus = if ([Status] ?? "") <> "" and ([Status] ?? "") <> "Unknown" then 10 else 0,
            hasSource = if ([VehicleSource] ?? "") <> "" then 10 else 0
        in
            hasRegistration + hasVIN + hasMakeModel + hasYear + hasEngine + hasStatus + hasSource,
        type number),

    // ========================================================================
    // STEP 13: OPTIMIZED COLUMN SELECTION & ORGANIZATION
    // ========================================================================
    /*
    PURPOSE: Select and organize final columns for optimal reporting and performance
    STRUCTURE: Keys, identification, specifications, analytics, business intelligence
    */

    SelectFinalColumns = Table.SelectColumns(AddDataQualityScore, {
        // ===== PRIMARY KEYS & IDENTIFIERS =====
        "VehicleKey",               // Surrogate key for fact table joins
        "VehicleIdentifier",        // Unique vehicle identifier
        "PrimaryLookup",            // Critical field for work order assignment

        // ===== VEHICLE IDENTIFICATION =====
        "Registration",             // Vehicle registration number
        "StockNumber",              // Stock/inventory number
        "VIN",                      // Vehicle identification number

        // ===== VEHICLE SPECIFICATIONS =====
        "VehicleSource",            // Fleet vs Stock classification
        "Make",                     // Manufacturer name
        "Model",                    // Vehicle model
        "MakeModel",                // Combined make and model
        "Year",                     // Model year
        "EngineSpec",               // Engine specifications

        // ===== AGE & LIFECYCLE ANALYSIS =====
        "VehicleAge",               // Age in years
        "AgeCategory",              // Lifecycle categorization

        // ===== STATUS & AVAILABILITY =====
        "Status",                   // Current vehicle status
        "IsActive",                 // Available for service flag

        // ===== BUSINESS CLASSIFICATION =====
        "VehicleTypeEnhanced",      // Fleet vs Stock type
        "VehicleCategory",          // Equipment categorization

        // ===== SERVICE INTELLIGENCE =====
        "ServiceComplexity",        // Service difficulty assessment
        "WarrantyLikelihood",       // Warranty coverage probability
        "PartsAvailability",        // Parts availability assessment
        "MaintenancePriority",      // Maintenance priority score (1-10)

        // ===== IDENTIFICATION FLAGS =====
        "HasVIN",                   // VIN availability flag

        // ===== DISPLAY OPTIONS =====
        "VehicleDisplayName",       // Comprehensive display name
        "VehicleShortName",         // Compact display name

        // ===== DATA QUALITY =====
        "DataQualityScore"          // Data completeness score (0-100)
    }),

    // ========================================================================
    // STEP 14: COLUMN RENAMING FOR CONSISTENCY
    // ========================================================================
    /*
    PURPOSE: Ensure consistent naming conventions across dimension tables
    STANDARD: Engine instead of EngineSpec, VehicleType instead of VehicleTypeEnhanced
    */

    RenameColumns = Table.RenameColumns(SelectFinalColumns, {
        {"EngineSpec", "Engine"},
        {"VehicleTypeEnhanced", "VehicleType"}
    }),

    // ========================================================================
    // STEP 15: DATA TYPE OPTIMIZATION
    // ========================================================================
    /*
    PURPOSE: Optimize storage and query performance with appropriate data types
    STRATEGY: Consistent types for reliable joins and calculations
    */

    SetDataTypes = Table.TransformColumnTypes(RenameColumns, {
        // Keys and identifiers
        {"VehicleKey", Int64.Type}, {"VehicleIdentifier", type text}, {"PrimaryLookup", type text},
        {"Registration", type text}, {"StockNumber", type text}, {"VIN", type text},

        // Vehicle specifications
        {"VehicleSource", type text}, {"Make", type text}, {"Model", type text},
        {"MakeModel", type text}, {"Year", Int64.Type}, {"Engine", type text},

        // Age and lifecycle
        {"VehicleAge", Int64.Type}, {"AgeCategory", type text},

        // Status and availability
        {"Status", type text}, {"IsActive", type logical},

        // Business classification
        {"VehicleType", type text}, {"VehicleCategory", type text},

        // Service intelligence
        {"ServiceComplexity", type text}, {"WarrantyLikelihood", type text},
        {"PartsAvailability", type text}, {"MaintenancePriority", type number},

        // Flags and display
        {"HasVIN", type logical}, {"VehicleDisplayName", type text}, {"VehicleShortName", type text},

        // Data quality
        {"DataQualityScore", type number}
    }),

    // ========================================================================
    // STEP 16: FINAL SORTING FOR CONSISTENCY
    // ========================================================================
    /*
    PURPOSE: Ensure consistent record ordering for reliable reporting
    STRATEGY: Sort by manufacturer, model, and year (newest first)
    */

    FinalSort = Table.Sort(SetDataTypes, {
        {"Make", Order.Ascending},
        {"Model", Order.Ascending},
        {"Year", Order.Descending}
    })

in
    FinalSort

/*
============================================================================
📋 VALIDATION & TESTING (When Deployed)
============================================================================

✅ POST-REFRESH VALIDATION:

1. **Row Count Verification:**
   - Should have ~71,640 rows (dual-source combination)
   - Verify: SELECT COUNT(*) FROM dim_Vehicle

2. **PrimaryLookup Uniqueness (CRITICAL):**
   - PrimaryLookup values should be unique for work order matching
   - Verify: SELECT PrimaryLookup, COUNT(*) FROM dim_Vehicle
             GROUP BY PrimaryLookup HAVING COUNT(*) > 1

3. **Source Distribution:**
   - Should have mix of "Fleet" and "Stock" vehicles
   - Verify: SELECT VehicleSource, COUNT(*) FROM dim_Vehicle
             GROUP BY VehicleSource

4. **Category Distribution:**
   - Should have reasonable distribution across categories
   - Verify: SELECT VehicleCategory, COUNT(*) FROM dim_Vehicle
             GROUP BY VehicleCategory ORDER BY COUNT(*) DESC

5. **Age Analysis:**
   - Age should be reasonable (not negative, not > 100 years)
   - Verify: SELECT MIN(VehicleAge), MAX(VehicleAge), AVG(VehicleAge)
             FROM dim_Vehicle WHERE VehicleAge IS NOT NULL

6. **Data Quality Scores:**
   - Scores should range 0-100
   - Verify: SELECT MIN(DataQualityScore), MAX(DataQualityScore), AVG(DataQualityScore)
             FROM dim_Vehicle

7. **Active Vehicle Count:**
   - Verify reasonable active percentage
   - Verify: SELECT IsActive, COUNT(*), COUNT(*)*100.0/SUM(COUNT(*)) OVER() as Pct
             FROM dim_Vehicle GROUP BY IsActive

✅ BUSINESS LOGIC VALIDATION:

Verify service intelligence calculations:
```sql
-- Check ServiceComplexity distribution
SELECT VehicleCategory, ServiceComplexity, COUNT(*)
FROM dim_Vehicle
GROUP BY VehicleCategory, ServiceComplexity
ORDER BY VehicleCategory, ServiceComplexity

-- Check MaintenancePriority by age and category
SELECT
    AgeCategory,
    VehicleCategory,
    AVG(MaintenancePriority) as AvgPriority,
    COUNT(*) as VehicleCount
FROM dim_Vehicle
WHERE IsActive = TRUE
GROUP BY AgeCategory, VehicleCategory
ORDER BY AvgPriority DESC

-- Check WarrantyLikelihood distribution
SELECT WarrantyLikelihood, COUNT(*), AVG(VehicleAge) as AvgAge
FROM dim_Vehicle
WHERE HasVIN = TRUE
GROUP BY WarrantyLikelihood
ORDER BY WarrantyLikelihood
```

============================================================================
🚀 DEPLOYMENT NOTES (Future)
============================================================================

**Prerequisites:**
1. ✅ Raw_VehicleFleet must exist and be refreshed
2. ✅ Raw_VehicleStock must exist and be refreshed
3. ✅ Determine refresh schedule based on business needs

**Deployment Steps (When Ready):**
1. Determine refresh schedule:
   - Daily if used for real-time service operations
   - Weekly if used for fleet analytics only
   - Monthly if used for strategic planning

2. Create df_Dim_Vehicle dataflow with this query
3. Schedule refresh according to determined schedule
4. Create relationships in Power BI model (when fact tables ready):
   - Fact_WorkOrderHeader[VehicleLookupKey] → dim_Vehicle[PrimaryLookup]
5. Verify row count (~71,640 vehicles)
6. Test PrimaryLookup matching with sample work orders
7. Validate all service intelligence calculations

**Scheduling Recommendation (When Deployed):**
- IF daily service reporting: Daily at 8:00 AM (after raw tables)
- IF fleet analytics only: Weekly Monday at 8:00 AM
- IF strategic planning: Monthly first Monday at 8:00 AM

**Refresh Dependencies:**
- Must refresh AFTER: Raw_VehicleFleet, Raw_VehicleStock
- Must refresh BEFORE: Any fact tables using VehicleKey/PrimaryLookup
- Can refresh IN PARALLEL with: Other dimension tables

**Performance Expectations:**
- ~2 minutes for 71,640 rows is EXCELLENT
- Dual-source combination optimized
- Ready for incremental refresh if needed (parameters in place)
- Pre-calculated intelligence eliminates complex DAX

**Critical Testing:**
- Test PrimaryLookup matching with work orders BEFORE production
- Validate vehicle identification accuracy with sample data
- Review equipment categorization for any missing manufacturers
- Verify age calculations against known vehicle years

============================================================================
*/
