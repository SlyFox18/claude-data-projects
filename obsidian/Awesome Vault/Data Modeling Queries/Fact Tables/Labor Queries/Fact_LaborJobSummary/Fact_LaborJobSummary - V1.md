/*

============================================================================

FACT_LABORJOBSUMMARY - CRITICAL FINANCIAL BRIDGE FOR LABOR ANALYTICS

============================================================================

  

📋 TABLE OVERVIEW:

Purpose: Job-level financial summary bridging detailed labor to work order summary

Grain: One row per job (Branch + WorkOrder + JobCode + JobType)

Refresh Strategy: Full refresh with incremental ready (ModifiedDate filtering)

Target Performance: 2-3 minutes (job-level aggregation)

Source Dependencies: Raw_wkothsub + 4 dimension tables

  

🎯 BUSINESS USE CASES:

• Financial Reconciliation: Bridge between individual labor and work order totals

• Job Costing: Estimated vs Actual vs Invoiced labor analysis per job

• Performance Management: Job-level efficiency and accuracy tracking

• Invoice Integration: Direct job-to-invoice linkage for billing analysis

• Cross-Fact Validation: Ensure labor totals reconcile across fact tables

• Executive Reporting: Job-level summaries for operational dashboards

  

📊 KEY METRICS PROVIDED:

• Labor Financial Metrics: EstLabor, ActLabor, InvLabor for complete cycle analysis

• Labor Efficiency: Actual vs Estimated variance analysis

• Billing Accuracy: Invoiced vs Actual variance tracking  

• Job Context: Field repair flags, standard labor indicators

• Timeline Intelligence: Invoice dates for billing cycle analysis

  

🔗 CRITICAL DATA RECONCILIATION:

• Should reconcile Fact_LaborJobs (individual) → Fact_LaborJobSummary (job totals)

• Should reconcile to Fact_LaborInvoiced via InvoiceNumber linkage

• Should aggregate to Fact_LaborWorkOrder work order totals

• Provides missing financial bridge in labor architecture

  

🔗 DIMENSION RELATIONSHIPS:

• dim_WorkOrderMaster → WorkOrderKey (work order context)

• dim_BranchLocation → BranchKey (territory analysis)  

• dim_JobCode → JobCodeKey (service type analysis)

• dim_DateTable → InvoiceDateKey (billing timeline analysis)

  

📈 DASHBOARD IDEAS:

• Job Costing Dashboard: Est vs Act vs Inv analysis by job type

• Financial Reconciliation: Cross-fact labor total validation

• Billing Efficiency: Job-level billing accuracy and timing

• Performance Management: Job efficiency by technician and service type

  

⚡ PERFORMANCE NOTES:

• Leverages ModifiedDate filtering for incremental refresh readiness

• Job-level grain reduces data volume vs individual records

• Essential financial metrics focus for optimal refresh performance

• Direct invoice linkage enables efficient cross-fact analysis

  

============================================================================

*/

  

let

    // ========================================================================

    // INCREMENTAL REFRESH PARAMETERS - STANDARD PATTERN

    // ========================================================================

    /*

    PURPOSE: Consistent incremental refresh pattern across all fact tables

    STANDARD: Use same date range as other fact tables for consistency

    FLEXIBILITY: Independent control over fact table refresh scope

    */

    // Standard incremental refresh parameters (align with other fact tables)

    RangeStart = #datetime(2023, 1, 1, 0, 0, 0),   // Standard across all fact tables

    RangeEnd = DateTime.LocalNow(),                 // Always current data

    // ========================================================================

    // STEP 1: SOURCE DATA WITH OPTIONAL ADDITIONAL FILTERING

    // ========================================================================

    /*

    PURPOSE: Load job-level labor financial data with fact table level control

    APPROACH: Start with pre-filtered raw table, apply additional filtering if needed

    BENEFIT: Leverages raw table efficiency while maintaining fact table flexibility

    */

    // Source: Raw table already filtered at SQL level (efficient)

    Source = Raw_wkothsub,

    // Optional: Additional filtering at fact table level (for different refresh policies)

    // Uncomment if you want independent control over fact table date range:

    // FilteredSource = Table.SelectRows(Source, each

    //     [ModifiedDate] >= RangeStart and [ModifiedDate] < RangeEnd),

    // For now, use raw table filtering (most efficient approach)

    FilteredSource = Source,

    // ========================================================================

    // STEP 2: DIMENSION LOOKUP - WORK ORDER MASTER

    // ========================================================================

    /*

    PURPOSE: Link to work order dimension for comprehensive work order context

    BENEFIT: Enables cross-fact analysis and work order-level reporting

    */

    JoinWorkOrder = Table.NestedJoin(FilteredSource, {"Branch", "WorkOrder"},

        dim_WorkOrderMaster, {"Branch", "WorkOrder"}, "WorkOrderMatch", JoinKind.LeftOuter),

    ExpandWorkOrder = Table.ExpandTableColumn(JoinWorkOrder, "WorkOrderMatch",

        {"BranchWorkOrder"}, {"DimWorkOrderKey"}),

    // Handle missing work order keys  

    CleanWorkOrderKey = Table.ReplaceValue(ExpandWorkOrder, null, "UNKNOWN", Replacer.ReplaceValue, {"DimWorkOrderKey"}),

    // ========================================================================

    // STEP 3: DIMENSION LOOKUP - BRANCH LOCATION

    // ========================================================================

    /*

    PURPOSE: Add branch context for territory-based job costing analysis

    FIX: Join Branch to BranchID (correct field mapping)

    */

    JoinBranch = Table.NestedJoin(CleanWorkOrderKey, {"Branch"},

        dim_BranchLocation, {"BranchID"}, "BranchMatch", JoinKind.LeftOuter),

    ExpandBranch = Table.ExpandTableColumn(JoinBranch, "BranchMatch",

        {"BranchKey"}, {"BranchKey"}),

    CleanBranchKey = Table.ReplaceValue(ExpandBranch, null, -1, Replacer.ReplaceValue, {"BranchKey"}),

    // ========================================================================

    // STEP 4: DIMENSION LOOKUP - JOB CODE

    // ========================================================================

    /*

    PURPOSE: Add job code intelligence for service type costing analysis

    */

    JoinJobCode = Table.NestedJoin(CleanBranchKey, {"JobCode"},

        dim_JobCode, {"JobCode"}, "JobCodeMatch", JoinKind.LeftOuter),

    ExpandJobCode = Table.ExpandTableColumn(JoinJobCode, "JobCodeMatch",

        {"JobCodeKey"}, {"JobCodeKey"}),

    CleanJobCodeKey = Table.ReplaceValue(ExpandJobCode, null, -1, Replacer.ReplaceValue, {"JobCodeKey"}),

    // ========================================================================

    // STEP 5: DATE DIMENSION LOOKUP - INVOICE DATE

    // ========================================================================

    /*

    PURPOSE: Add invoice date intelligence for billing cycle analysis

    FIX: Extract date portion from datetime for proper join

    */

    // Extract date portion from datetime for join

    AddInvoiceDateOnly = Table.AddColumn(CleanJobCodeKey, "InvoiceDateOnly", each

        if [InvoiceDate] <> null then Date.From([InvoiceDate]) else null, type date),

    JoinInvoiceDate = Table.NestedJoin(AddInvoiceDateOnly, {"InvoiceDateOnly"},

        dim_DateTable, {"Date"}, "InvoiceDateMatch", JoinKind.LeftOuter),

    ExpandInvoiceDate = Table.ExpandTableColumn(JoinInvoiceDate, "InvoiceDateMatch",

        {"DateKey"}, {"InvoiceDateKey"}),

    CleanInvoiceDateKey = Table.ReplaceValue(ExpandInvoiceDate, null, -1, Replacer.ReplaceValue, {"InvoiceDateKey"}),

    // ========================================================================

    // STEP 6: BUSINESS CALCULATIONS - LABOR VARIANCE ANALYSIS

    // ========================================================================

    /*

    PURPOSE: Calculate key business metrics for job costing and efficiency analysis

    */

    // Labor variance calculations

    AddLaborVariance = Table.AddColumn(CleanInvoiceDateKey, "ActualVsEstimatedVariance", each

        ([ActLabor] ?? 0) - ([EstLabor] ?? 0), type number),

    AddInvoiceVariance = Table.AddColumn(AddLaborVariance, "InvoicedVsActualVariance", each  

        ([InvLabor] ?? 0) - ([ActLabor] ?? 0), type number),

    AddTotalVariance = Table.AddColumn(AddInvoiceVariance, "InvoicedVsEstimatedVariance", each

        ([InvLabor] ?? 0) - ([EstLabor] ?? 0), type number),

    // Efficiency percentages

    AddActualEfficiency = Table.AddColumn(AddTotalVariance, "ActualVsEstimatedPercent", each

        if ([EstLabor] ?? 0) > 0 then

            Number.Round(([ActLabor] ?? 0) / [EstLabor], 4)

        else null, type number),

    AddInvoiceEfficiency = Table.AddColumn(AddActualEfficiency, "InvoicedVsActualPercent", each

        if ([ActLabor] ?? 0) > 0 then

            Number.Round(([InvLabor] ?? 0) / [ActLabor], 4)

        else null, type number),

    // ========================================================================

    // STEP 7: BUSINESS CATEGORIZATION

    // ========================================================================

    /*

    PURPOSE: Categorize jobs for business intelligence and operational analysis

    */

    // Labor value categories

    AddLaborValueCategory = Table.AddColumn(AddInvoiceEfficiency, "LaborValueCategory", each

        let invLabor = [InvLabor] ?? 0 in

        if invLabor >= 5000 then "High Value"

        else if invLabor >= 1000 then "Medium Value"

        else if invLabor >= 200 then "Low Value"

        else if invLabor > 0 then "Minimal Value"

        else "No Labor", type text),

    // Efficiency categories with proper no-labor handling

    AddEfficiencyCategory = Table.AddColumn(AddLaborValueCategory, "EfficiencyCategory", each

        let

            efficiency = [ActualVsEstimatedPercent] ?? 0,

            estLabor = [EstLabor] ?? 0,

            actLabor = [ActLabor] ?? 0

        in

        if estLabor = 0 and actLabor = 0 then "No Labor"

        else if estLabor = 0 then "No Estimate"  

        else if actLabor = 0 then "No Work Done"

        else if efficiency <= 0.8 then "Excellent"    // Finished under estimate

        else if efficiency <= 1.0 then "Good"         // Finished at or near estimate  

        else if efficiency <= 1.2 then "Fair"         // 20% over estimate

        else "Poor", type text),                       // Significantly over estimate

    // Billing accuracy categories with proper no-labor handling

    AddBillingAccuracy = Table.AddColumn(AddEfficiencyCategory, "BillingAccuracyCategory", each

        let

            billingEff = [InvoicedVsActualPercent] ?? 0,

            actLabor = [ActLabor] ?? 0,

            invLabor = [InvLabor] ?? 0

        in

        if actLabor = 0 and invLabor = 0 then "No Labor"

        else if actLabor = 0 then "No Work Done"

        else if invLabor = 0 then "Not Billed"

        else if billingEff >= 0.95 and billingEff <= 1.05 then "Accurate"    // 95-105% = accurate billing

        else if billingEff >= 0.85 and billingEff <= 1.15 then "Good"        // 85-115% = acceptable variance

        else if billingEff >= 0.70 and billingEff <= 1.30 then "Fair"        // 70-130% = some over/under billing

        else "Poor", type text),                                              // Significant billing inaccuracy

    // ========================================================================

    // STEP 8: TEXT TO LOGICAL CONVERSION - ROBUST HANDLING (FIXED)

    // ========================================================================

    /*

    PURPOSE: Convert text flags to logical values with robust error handling

    APPROACH: Handle multiple possible formats (Y/N, Yes/No, 1/0, null, spaces)

    FIX: Changed [FieldRepair] to [IsFieldRepair] to match raw table output

    */

    ConvertFieldRepair = Table.AddColumn(AddBillingAccuracy, "FieldRepair_Logical", each

        let

            cleanValue = Text.Trim(Text.Upper([IsFieldRepair] ?? ""))  // FIXED: Changed from [FieldRepair] to [IsFieldRepair]

        in

            if cleanValue = "Y" or cleanValue = "YES" or cleanValue = "1" or cleanValue = "TRUE" then true

            else if cleanValue = "N" or cleanValue = "NO" or cleanValue = "0" or cleanValue = "FALSE" or cleanValue = "" then false

            else null, type logical),

    ConvertStandardLabor = Table.AddColumn(ConvertFieldRepair, "IsStandardLabor_Logical", each

        let

            cleanValue = Text.Trim(Text.Upper([IsStandardLabor] ?? ""))

        in

            if cleanValue = "Y" or cleanValue = "YES" or cleanValue = "1" or cleanValue = "TRUE" then true

            else if cleanValue = "N" or cleanValue = "NO" or cleanValue = "0" or cleanValue = "FALSE" or cleanValue = "" then false

            else null, type logical),

  

    // Remove original columns and rename converted ones (FIXED)

    RemoveOriginalLogical = Table.RemoveColumns(ConvertStandardLabor, {"IsFieldRepair", "IsStandardLabor"}),  // FIXED: Changed from "FieldRepair" to "IsFieldRepair"

    RenameLogicalColumns = Table.RenameColumns(RemoveOriginalLogical, {

        {"FieldRepair_Logical", "FieldRepair"},  // This stays the same - we want final output as "FieldRepair"

        {"IsStandardLabor_Logical", "IsStandardLabor"}

    }),

    // ========================================================================

    // STEP 9: SURROGATE KEY GENERATION

    // ========================================================================

    /*

    PURPOSE: Generate unique surrogate key for fact table relationships

    */

    AddSurrogateKey = Table.AddIndexColumn(RenameLogicalColumns, "LaborJobSummaryKey", 1, 1, Int64.Type),

    // ========================================================================

    // STEP 10: FINAL COLUMN SELECTION AND ORGANIZATION

    // ========================================================================

    /*

    PURPOSE: Organize columns for optimal fact table structure and performance

    */

    FinalColumns = Table.SelectColumns(AddSurrogateKey, {

        // ===== SURROGATE KEY =====

        "LaborJobSummaryKey",         // Unique fact table key

        // ===== DIMENSION KEYS =====

        "DimWorkOrderKey",            // Work order context

        "BranchKey",                  // Territory analysis

        "JobCodeKey",                 // Service type analysis  

        "InvoiceDateKey",             // Invoice timing analysis

        // ===== BUSINESS IDENTIFIERS =====

        "Branch",                     // Location identifier

        "WorkOrder",                  // Work order number

        "JobCode",                    // Job code identifier

        "JobType",                    // Job type classification

        "InvoiceNumber",              // Invoice linkage

        // ===== CORE FINANCIAL METRICS =====

        "EstLabor",                   // Estimated labor value

        "ActLabor",                   // Actual labor value

        "InvLabor",                   // Invoiced labor value

        "EstHours",                   // Estimated hours

        // ===== VARIANCE ANALYSIS =====

        "ActualVsEstimatedVariance",  // Performance variance

        "InvoicedVsActualVariance",   // Billing variance

        "InvoicedVsEstimatedVariance", // Total cycle variance

        "ActualVsEstimatedPercent",   // Efficiency percentage

        "InvoicedVsActualPercent",    // Billing efficiency percentage

        // ===== BUSINESS CATEGORIZATION =====

        "LaborValueCategory",         // Value-based grouping

        "EfficiencyCategory",         // Performance classification

        "BillingAccuracyCategory",    // Billing quality classification

        // ===== OPERATIONAL FLAGS =====

        "FieldRepair",                // Field service indicator

        "IsStandardLabor",            // Standard labor flag

        // ===== TIMELINE CONTEXT =====

        "InvoiceDate",                // Invoice timing

        "ModifiedDate"                // Last update timestamp

    }),

    // ========================================================================

    // STEP 11: DATA TYPE OPTIMIZATION

    // ========================================================================

    /*

    PURPOSE: Optimize storage and query performance with appropriate data types

    */

    FinalDataTypes = Table.TransformColumnTypes(FinalColumns, {

        // Keys and identifiers

        {"LaborJobSummaryKey", Int64.Type}, {"BranchKey", Int64.Type},

        {"JobCodeKey", Int64.Type}, {"InvoiceDateKey", Int64.Type},

        // Business identifiers  

        {"DimWorkOrderKey", type text}, {"Branch", type text}, {"WorkOrder", Int64.Type},

        {"JobCode", type text}, {"JobType", type text}, {"InvoiceNumber", type text},

        // Financial metrics

        {"EstLabor", type number}, {"ActLabor", type number}, {"InvLabor", type number},

        {"EstHours", type number},

        // Variance calculations

        {"ActualVsEstimatedVariance", type number}, {"InvoicedVsActualVariance", type number},

        {"InvoicedVsEstimatedVariance", type number}, {"ActualVsEstimatedPercent", type number},

        {"InvoicedVsActualPercent", type number},

        // Categories

        {"LaborValueCategory", type text}, {"EfficiencyCategory", type text},

        {"BillingAccuracyCategory", type text},

        // Flags (converted with robust handling - nulls allowed for problematic values)

        {"FieldRepair", type logical}, {"IsStandardLabor", type logical},

        // Dates

        {"InvoiceDate", type datetime}, {"ModifiedDate", type datetime}

    })

  

in

    FinalDataTypes

  

/*

============================================================================

✅ FACT_LABORJOBSUMMARY - CRITICAL FINANCIAL BRIDGE COMPLETE

============================================================================

  

🎯 ARCHITECTURAL EXCELLENCE:

• Bridges individual labor detail to work order summary for complete reconciliation

• Job-level grain enables efficient aggregation and cross-fact validation

• Direct invoice linkage supports billing cycle analysis and accuracy tracking

• Essential financial metrics focus optimizes refresh performance

  

🔄 INCREMENTAL REFRESH STANDARD:

• Follows standard Pattern 2 (Fact Table Power Query Filtering)

• Uses consistent 2023-01-01 start date across all fact tables

• RangeStart/RangeEnd parameters ready for production incremental refresh

• Currently leverages Raw_wkothsub SQL filtering for optimal efficiency

• Can be switched to independent filtering by uncommenting FilteredSource logic

  

⚡ BUSINESS VALUE DELIVERED:

• Financial Reconciliation: Complete Est → Act → Inv labor cycle tracking

• Job Costing: Individual job efficiency and profitability analysis

• Billing Intelligence: Accuracy and timing analysis for process optimization

• Cross-Fact Foundation: Enables seamless integration across labor architecture

  

🔗 INTEGRATION CAPABILITIES:

• Validates against Fact_LaborJobs: Individual → Job summary reconciliation

• Links to Fact_LaborInvoiced: Invoice number cross-reference validation

• Aggregates to Fact_LaborWorkOrder: Job → Work order financial rollup

• Enables complete labor analytics from punch to work order summary

  

📊 EXPECTED FINANCIAL RECONCILIATION:

• Should show ~$63-68M total InvLabor matching other labor tables

• Enables validation of individual punch → job → invoice → work order totals

• Provides missing bridge for orphaned records resolution

  

============================================================================

*/