/*
============================================================================
DIM_VEHICLE - COMPREHENSIVE VEHICLE & EQUIPMENT MASTER DIMENSION
============================================================================

📋 TABLE OVERVIEW:
Purpose: Central vehicle and equipment dimension for service operations and fleet management
Grain: One row per unique vehicle/equipment unit (fleet vehicles + stock inventory)
Refresh Strategy: Full refresh with dual-source integration (prepared for incremental)
Dependencies: Raw_VehicleFleet, Raw_VehicleStock
Key Integration: PrimaryLookup field enables Fact_WorkOrderHeader vehicle assignment

🎯 BUSINESS USE CASES:
• Service Operations: Vehicle identification for work order assignment and service history
• Fleet Management: Vehicle age analysis, replacement planning, utilization tracking
• Maintenance Planning: Equipment reliability analysis and preventive maintenance scheduling
• Parts Management: Equipment-specific parts inventory and ordering optimization
• Asset Management: Vehicle portfolio analysis, depreciation tracking, lifecycle management
• Performance Analytics: Service frequency patterns and equipment reliability scoring

📊 KEY FEATURES PROVIDED:
• Dual-Source Integration: Fleet vehicles (registered) + stock vehicles (inventory numbers)
• Equipment Classification: Heavy equipment vs vehicles vs commercial trucks categorization
• Age Analysis: Vehicle age calculation with lifecycle categorization
• Service Readiness: Active status and VIN availability for service scheduling
• Display Flexibility: Multiple naming strategies for different reporting requirements
• Maintenance Intelligence: Equipment type classification for service pattern analysis

🔗 CRITICAL INTEGRATION POINTS:
• Fact_WorkOrderHeader: PrimaryLookup matches VehicleLookupKey for work order assignment
• Fact_WorkOrderParts: Equipment-specific parts analysis and inventory planning
• Fact_WarrantyClaims: Equipment warranty tracking and manufacturer performance
• Service Scheduling: Vehicle availability and maintenance window planning
• Customer Communications: Vehicle identification for service notifications

📈 EQUIPMENT ANALYTICS STRATEGY:
• Vehicle Categories: Heavy Equipment > Commercial Truck > Domestic > Import > Other
• Age Segmentation: New (0-2yr) > Recent (3-5yr) > Mature (6-10yr) > Older (10+yr)
• Service Classification: Fleet (customer-owned) vs Stock (dealer inventory)
• Maintenance Readiness: Active status and complete identification requirements
• Manufacturer Intelligence: Brand-based service patterns and parts availability

⚡ PERFORMANCE OPTIMIZATION:
• Dual-source combination with efficient lookup key generation
• Incremental refresh ready (filtered by modification dates when available)
• Surrogate keys optimize fact table joins and improve query performance
• Text cleaning operations batched for optimal processing efficiency
• Multiple display name options reduce runtime calculations in reports

🔧 OPERATIONAL GUIDELINES:
• Monitor PrimaryLookup uniqueness - critical for work order assignment accuracy
• Review vehicle categories when adding new equipment manufacturers
• Update age category thresholds based on business equipment lifecycle policies
• Validate VIN completeness for warranty claim processing requirements
• Audit active status accuracy for service scheduling and capacity planning

============================================================================
📈 FLEET MANAGEMENT & ANALYTICS RECOMMENDATIONS
============================================================================

🚛 FLEET ANALYTICS DASHBOARDS:
• Fleet Portfolio: Age distribution and replacement planning analysis
• Equipment Utilization: Service frequency and downtime pattern analysis
• Manufacturer Performance: Reliability comparison by make and equipment type
• Maintenance Scheduling: Age-based preventive maintenance planning calendar

⚙️ SERVICE OPERATIONS APPLICATIONS:
• Work Order Assignment: PrimaryLookup enables accurate vehicle identification
• Parts Planning: Equipment-specific inventory management and ordering optimization
• Warranty Management: VIN-based warranty claim processing and manufacturer coordination
• Customer Communications: Professional vehicle identification in service notifications

🔍 BUSINESS INTELLIGENCE OPPORTUNITIES:
• Equipment ROI Analysis: Service costs vs age and utilization patterns
• Replacement Planning: Age category analysis for capital equipment decisions
• Service Pattern Recognition: Equipment type and age correlation with maintenance needs
• Manufacturer Evaluation: Brand performance comparison for future purchasing decisions

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