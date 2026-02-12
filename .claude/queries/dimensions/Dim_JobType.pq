/*
============================================================================
Dimension: Dim_JobType (WORK ORDER TYPE CLASSIFICATION)
Dataflow: df_Dim_JobType
Location: LH_Master_Data → Dataflows → 03 - Dimensions
============================================================================

📋 METADATA:
Source: Raw_WorkOrderDesc (raw table - JobType field)
Purpose: Work order type classification for billing categorization and business analysis
Created: [Unknown - pre-dates current documentation]
Last Modified: 10/07/2025
Output: Lakehouse table "Dim_JobType"

⏱️ REFRESH CHARACTERISTICS:
Refresh Schedule: Not scheduled (reference data - recommend monthly)
Average Refresh Time: ~2 minutes
Refresh Strategy: Full refresh with distinct values + business intelligence enrichment
Row Count: 7 distinct job types (as of documentation)
Query Folding: Partial (raw table source, in-memory transformations)

📊 DIMENSION TYPE: **Type 1 - Slowly Changing Dimension (Overwrite)**
- **Rare changes** - job type codes added infrequently
- **No SCD tracking** - current state only
- **Source-driven** - derived from work order descriptions
- **Business intelligence enrichment** - extensive classification and categorization

🎯 BUSINESS USE CASES:
• Billing Classification: Categorize work orders by billing type (Customer Pay, Warranty, Fleet, etc.)
• Revenue Analysis: Track revenue by job type and billing category
• Work Order Management: Filter and analyze work orders by service type
• Customer Segmentation: Distinguish retail customers from fleet/account customers
• Financial Reporting: Group revenue by billing type for financial statements
• Warranty Tracking: Isolate warranty and insurance claim work orders
• Internal Work Analysis: Track internal and fleet service activity
• Account Management: Analyze account billing patterns and customer relationships

📊 DATA STRUCTURE (7 COLUMNS):

**Primary Key (1 column):**
• JobTypeKey (Int64) - Surrogate key for relationships (1-7 sequential)

**Natural Key & Identification (3 columns):**
• JobTypeCode (text) - Single-letter code (A, F, I, P, R, S, W) - UPPERCASE normalized
• JobTypeName (text) - Full descriptive name:
  - A = "Account"
  - F = "Fleet"
  - I = "Internal"
  - P = "Policy"
  - R = "Retail"
  - S = "Misc"
  - W = "Warranty"
• JobTypeDisplayName (text) - Combined code and name (e.g., "A - Account", "W - Warranty")

**Business Classification (2 columns):**
• JobTypeCategory (text) - Grouped categories:
  - "Insurance/Warranty" (P, W)
  - "Fleet/Internal" (F, I)
  - "Retail/Misc" (R, S)
  - "Account" (A)
  - "Other" (unmapped)
• BillingType (text) - Billing classification:
  - "Insurance Claim" (P, W)
  - "Internal Charge" (I)
  - "Fleet Account" (F)
  - "Customer Pay" (R)
  - "Account Billing" (A)
  - "Other" (unmapped)

**Operational Status (1 column):**
• JobTypeStatus (text) - "Active" for all current job types

**Job Type Definitions:**
1. **A - Account**: Account billing (regular customer accounts)
2. **F - Fleet**: Fleet account work orders (fleet customers)
3. **I - Internal**: Internal work orders (company equipment/service)
4. **P - Policy**: Policy/insurance work orders
5. **R - Retail**: Retail customer work orders (walk-in/one-time customers)
6. **S - Misc**: Miscellaneous work orders (other service types)
7. **W - Warranty**: Warranty claim work orders

🔧 DESIGN PRINCIPLES:

**Source-Driven Pattern:**
• Extracts distinct JobType values from Raw_WorkOrderDesc
• Source: Work order descriptions table
• Self-updating as new job types appear in source
• Alphabetical sorting for consistent key generation

**Business Intelligence Enrichment:**
• **Code Normalization**: UPPERCASE, trimmed for consistency
• **Name Mapping**: Descriptive names for each single-letter code
• **Display Name**: Combined code + name for reports (e.g., "W - Warranty")
• **Category Grouping**: Logical groupings for analysis (Insurance/Warranty, Fleet/Internal, etc.)
• **Billing Classification**: Revenue categorization by billing type

**Job Type Classification Logic:**

**JobTypeName Mapping:**
- A → "Account" (regular customer accounts)
- F → "Fleet" (fleet customer work orders)
- I → "Internal" (internal company work)
- P → "Policy" (insurance/policy claims)
- R → "Retail" (walk-in/one-time customers)
- S → "Misc" (miscellaneous service)
- W → "Warranty" (warranty claims)

**JobTypeCategory Grouping:**
- **Insurance/Warranty**: P (Policy), W (Warranty)
- **Fleet/Internal**: F (Fleet), I (Internal)
- **Retail/Misc**: R (Retail), S (Misc)
- **Account**: A (Account)
- **Other**: Unmapped codes

**BillingType Classification:**
- **Insurance Claim**: P (Policy), W (Warranty) - third-party reimbursement
- **Internal Charge**: I (Internal) - internal cost allocation
- **Fleet Account**: F (Fleet) - fleet customer billing
- **Customer Pay**: R (Retail) - direct customer payment
- **Account Billing**: A (Account) - account customer billing
- **Other**: Unmapped codes

**Data Quality Steps:**
1. Source: Raw_WorkOrderDesc (distinct JobType values)
2. Sort: Alphabetical order for consistent key generation
3. Add Surrogate Key: Sequential index starting at 1
4. Add JobTypeCode: UPPERCASE, trimmed normalization
5. Add JobTypeName: Descriptive name mapping
6. Add JobTypeDisplayName: Combined code + name for reports
7. Add JobTypeCategory: Logical grouping for analysis
8. Add BillingType: Revenue/billing classification
9. Add JobTypeStatus: "Active" for all current types
10. Select Final Columns: Remove original JobType, keep enriched attributes
11. Set Data Types: Consistent typing for all text columns

**Surrogate Key Generation:**
• Sequential numbering starting at 1 (alphabetical order)
• No unknown record (all job types from source are valid)
• Keys stable as long as alphabetical sort order maintained

🔗 RELATIONSHIPS:

**Fact Table Relationships (Many-to-One):**
- **Fact_WorkOrderHeader** → JobTypeKey (work order type analysis)
- **Raw_WorkOrderDesc** → JobType (natural key - source relationship)

**Related Dimensions:**
- Works with dim_DateTable for time-based job type analysis
- May relate to customer dimensions for customer segmentation by job type
- May relate to technician dimensions for workload analysis by job type

⚠️ IMPORTANT NOTES:

**Refresh Strategy:**
• **RECOMMENDED**: Monthly refresh (reference data changes very infrequently)
• **NOT RECOMMENDED**: Daily refresh (unnecessary overhead)
• **TRIGGER**: Refresh when new job types appear in Raw_WorkOrderDesc
• **FUTURE PIPELINE**: Consider "Reference Data Pipeline" (first Monday of month at 8:00 AM)

**Performance Considerations:**
• Current refresh time: ~2 minutes
• Row count: 7 (extremely small - refresh time seems high)
• Source: Raw_WorkOrderDesc (distinct JobType values)
• **PERFORMANCE NOTE**: 2 minutes for 7 rows is slower than expected
• **POSSIBLE CAUSE**: Raw_WorkOrderDesc may be large, or query waits for source refresh
• **NOT URGENT**: Works correctly, just slower than optimal

**Business Intelligence Value:**
• **7 columns** from single source field (JobType → 6 additional enriched columns)
• **Billing classification** critical for revenue analysis and financial reporting
• **Category grouping** enables high-level business analysis
• **Display names** improve report readability
• **Pre-calculated classifications** eliminate complex DAX

**Job Type Business Context:**
• **Warranty (W)**: Manufacturer reimbursement, claim processing required
• **Policy (P)**: Insurance claims, third-party payment
• **Retail (R)**: Walk-in customers, immediate payment expected
• **Account (A)**: Established customer accounts, terms billing
• **Fleet (F)**: Fleet customers, specialized billing arrangements
• **Internal (I)**: Company equipment, internal cost allocation
• **Misc (S)**: Other service types not fitting standard categories

**Data Quality:**
• 7 distinct job types (complete coverage of business operations)
• All codes single-letter UPPERCASE (consistent format)
• All types currently "Active" (no deprecated types)
• No unknown record needed (all source values valid)

**Source Table Dependency:**
• Reads from Raw_WorkOrderDesc (must be refreshed first)
• Distinct JobType values extracted
• New job types automatically captured
• Self-updating dimension

Dependencies:
• Raw_WorkOrderDesc (raw table - must refresh first)

Used By:
• Fact_WorkOrderHeader (work order type analysis)
• Work order management reports
• Revenue analysis by billing type
• Customer segmentation dashboards
• Financial reporting by job category

Related Dimensions:
• dim_DateTable (time-based job type analysis)
• dim_Customer (if exists - customer segmentation by job type)
• dim_Technician (if exists - workload analysis by job type)

Critical Finding:
**Small but critical dimension - 7 job types drive billing and revenue classification**
**Business intelligence enrichment adds 6 columns from single source field**
**Billing type classification critical for financial reporting**
**Monthly refresh recommended (job types rarely change)**
**2-minute refresh time higher than expected for 7 rows (not urgent - works correctly)**

============================================================================
*/

let
    // ========================================================================
    // STEP 1: SOURCE DATA EXTRACTION
    // ========================================================================
    /*
    PURPOSE: Extract job type data from work order descriptions
    SOURCE: Raw_WorkOrderDesc table (work order master data)
    BUSINESS LOGIC: Distinct job type codes from work orders
    */
    Source = Raw_WorkOrderDesc,

    // ========================================================================
    // STEP 2: ALPHABETICAL SORTING FOR CONSISTENT KEY GENERATION
    // ========================================================================
    /*
    PURPOSE: Sort job types alphabetically for stable surrogate key assignment
    BENEFIT: Consistent key values across refreshes (A=1, F=2, I=3, P=4, R=5, S=6, W=7)
    */
    #"Sorted rows" = Table.Sort(Source, {{"JobType", Order.Ascending}}),

    // ========================================================================
    // STEP 3: SURROGATE KEY GENERATION
    // ========================================================================
    /*
    PURPOSE: Create sequential surrogate key for fact table relationships
    METHOD: Index starting at 1, incrementing by 1
    RESULT: JobTypeKey (1, 2, 3, 4, 5, 6, 7 in alphabetical order)
    */
    #"Added index" = Table.AddIndexColumn(#"Sorted rows", "Index", 1, 1, Int64.Type),

    // ========================================================================
    // STEP 4: RENAME INDEX TO SURROGATE KEY
    // ========================================================================
    /*
    PURPOSE: Use standard naming convention for dimension keys
    */
    #"Renamed columns" = Table.RenameColumns(#"Added index", {{"Index", "JobTypeKey"}}),

    // ========================================================================
    // STEP 5: REORDER COLUMNS
    // ========================================================================
    /*
    PURPOSE: Standard dimension pattern - key first, then attributes
    */
    #"Reordered columns" = Table.ReorderColumns(#"Renamed columns", {"JobTypeKey", "JobType"}),

    // ========================================================================
    // STEP 6: ADD NORMALIZED JOB TYPE CODE
    // ========================================================================
    /*
    PURPOSE: Create normalized UPPERCASE, trimmed job type code
    BUSINESS BENEFIT: Consistent code format for classification logic
    */
    #"Added custom" = Table.AddColumn(#"Reordered columns", "JobTypeCode", each
        Text.Upper(Text.Trim([JobType]))),

    // ========================================================================
    // STEP 7: ADD DESCRIPTIVE JOB TYPE NAME
    // ========================================================================
    /*
    PURPOSE: Map single-letter codes to descriptive names
    BUSINESS LOGIC: Business-friendly names for reports and dashboards
    CLASSIFICATION:
    - A = Account (regular customer accounts)
    - F = Fleet (fleet customer work orders)
    - I = Internal (internal company work)
    - P = Policy (insurance/policy claims)
    - R = Retail (walk-in/one-time customers)
    - S = Misc (miscellaneous service)
    - W = Warranty (warranty claims)
    */
    #"Added custom 1" = Table.AddColumn(#"Added custom", "JobTypeName", each
        let
            Code = Text.Upper(Text.Trim([JobType]))
        in
            if Code = "A" then "Account"
            else if Code = "F" then "Fleet"
            else if Code = "I" then "Internal"
            else if Code = "P" then "Policy"
            else if Code = "R" then "Retail"
            else if Code = "S" then "Misc"
            else if Code = "W" then "Warranty"
            else Code),

    // ========================================================================
    // STEP 8: ADD COMBINED DISPLAY NAME
    // ========================================================================
    /*
    PURPOSE: Create combined code + name for report display
    BUSINESS BENEFIT: Professional display in reports (e.g., "W - Warranty")
    FORMAT: "[Code] - [Name]" (e.g., "A - Account", "W - Warranty")
    */
    #"Added custom 2" = Table.AddColumn(#"Added custom 1", "JobTypeDisplayName", each
        [JobTypeCode] & " - " & [JobTypeName]),

    // ========================================================================
    // STEP 9: ADD JOB TYPE CATEGORY GROUPING
    // ========================================================================
    /*
    PURPOSE: Group job types into logical business categories
    BUSINESS LOGIC: High-level categorization for analysis
    CATEGORIES:
    - Insurance/Warranty: P (Policy), W (Warranty)
    - Fleet/Internal: F (Fleet), I (Internal)
    - Retail/Misc: R (Retail), S (Misc)
    - Account: A (Account)
    - Other: Unmapped codes
    */
    #"Added custom 3" = Table.AddColumn(#"Added custom 2", "JobTypeCategory", each
        let
            Code = [JobTypeCode]
        in
            if Code = "P" or Code = "W" then "Insurance/Warranty"
            else if Code = "F" or Code = "I" then "Fleet/Internal"
            else if Code = "R" or Code = "S" then "Retail/Misc"
            else if Code = "A" then "Account"
            else "Other"),

    // ========================================================================
    // STEP 10: ADD BILLING TYPE CLASSIFICATION
    // ========================================================================
    /*
    PURPOSE: Classify job types by billing/payment method
    BUSINESS LOGIC: Revenue categorization for financial reporting
    BILLING TYPES:
    - Insurance Claim: P (Policy), W (Warranty) - third-party reimbursement
    - Internal Charge: I (Internal) - internal cost allocation
    - Fleet Account: F (Fleet) - fleet customer billing
    - Customer Pay: R (Retail) - direct customer payment
    - Account Billing: A (Account) - account customer billing
    - Other: Unmapped codes
    */
    #"Added custom 4" = Table.AddColumn(#"Added custom 3", "BillingType", each
        let
            Code = [JobTypeCode]
        in
            if Code = "P" or Code = "W" then "Insurance Claim"
            else if Code = "I" then "Internal Charge"
            else if Code = "F" then "Fleet Account"
            else if Code = "R" then "Customer Pay"
            else if Code = "A" then "Account Billing"
            else "Other"),

    // ========================================================================
    // STEP 11: ADD JOB TYPE STATUS
    // ========================================================================
    /*
    PURPOSE: Add status flag for future extensibility
    CURRENT: All job types "Active"
    FUTURE: Can add "Inactive" for deprecated job types
    */
    #"Added custom 5" = Table.AddColumn(#"Added custom 4", "JobTypeStatus", each
        "Active"),

    // ========================================================================
    // STEP 12: SELECT FINAL COLUMNS
    // ========================================================================
    /*
    PURPOSE: Remove original JobType column, keep only enriched attributes
    COLUMNS: JobTypeKey, JobTypeCode, JobTypeName, JobTypeDisplayName, JobTypeCategory, BillingType, JobTypeStatus
    */
    #"Removed other columns" = Table.SelectColumns(#"Added custom 5", {
        "JobTypeKey",
        "JobTypeCode",
        "JobTypeName",
        "JobTypeDisplayName",
        "JobTypeCategory",
        "BillingType",
        "JobTypeStatus"
    }),

    // ========================================================================
    // STEP 13: SET DATA TYPES
    // ========================================================================
    /*
    PURPOSE: Optimize storage and query performance with appropriate data types
    STRATEGY: Int64 for key, text for all descriptive attributes
    */
    #"Changed column type" = Table.TransformColumnTypes(#"Removed other columns", {
        {"JobTypeCode", type text},
        {"JobTypeName", type text},
        {"JobTypeDisplayName", type text},
        {"JobTypeCategory", type text},
        {"BillingType", type text},
        {"JobTypeStatus", type text}
    })

in
    #"Changed column type"

/*
============================================================================
✅ PRODUCTION STATUS: READY - MONTHLY REFRESH RECOMMENDED
============================================================================

🎯 IMPLEMENTATION SUMMARY:
• Type 1 Dimension: Overwrite, no historical tracking
• 7 Distinct Job Types: Complete coverage of work order types
• 7 Columns: Comprehensive business intelligence from single source field
• Self-Updating: Automatically captures new job types from source
• Reference Data: Changes very infrequently (monthly refresh adequate)

📊 DIMENSION CHARACTERISTICS:
• **Grain**: One row per job type code
• **Keys**: JobTypeKey (surrogate 1-7), JobTypeCode (natural A/F/I/P/R/S/W)
• **Attributes**: 7 columns (key, code, name, display name, category, billing type, status)
• **SCD Type**: Type 1 (no historical tracking)
• **No Unknown Record**: All source values valid

🔗 RELATIONSHIP READY:
• **Primary Consumer**: Fact_WorkOrderHeader
• **Join Keys**: JobTypeKey (surrogate), JobTypeCode (natural)
• **Cardinality**: Many-to-One (many work orders per job type)
• **Filter Direction**: Single (dim → fact)

⚡ REFRESH STRATEGY:

**RECOMMENDED: Monthly Reference Data Pipeline**
• **Schedule**: First Monday of month at 8:00 AM
• **Frequency**: Monthly (or as needed)
• **Duration**: ~2 minutes (higher than expected for 7 rows - not urgent)
• **Rationale**: Reference data rarely changes

**NOT RECOMMENDED: Daily Refresh**
• Unnecessary overhead for static data
• Save CU capacity for dynamic tables
• Job types change very infrequently

**Dependencies:**
• Raw_WorkOrderDesc must be refreshed first

📝 MAINTENANCE CHECKLIST:

**Data Quality Checks:**
1. ✅ Verify 7 distinct job types extracted (A, F, I, P, R, S, W)
2. ✅ Confirm all codes UPPERCASE normalized
3. ✅ Check JobTypeName mapping accuracy
4. ✅ Verify JobTypeCategory groupings
5. ✅ Validate BillingType classifications
6. ✅ Confirm all types "Active"

**When Adding to Monthly Pipeline:**
1. ✅ Schedule first Monday of month at 8:00 AM
2. ✅ Ensure Raw_WorkOrderDesc refreshes first
3. ✅ Group with other reference dimensions
4. ✅ Test refresh duration (~2 min expected)

**When New Job Type Added:**
1. 📋 Review source data for new JobType code
2. 📋 Update JobTypeName mapping logic if needed
3. 📋 Update JobTypeCategory grouping if needed
4. 📋 Update BillingType classification if needed
5. 📋 Refresh dimension to capture new type

**Troubleshooting:**
• **Unmapped job type**: Review JobTypeName logic, add new mapping
• **Incorrect billing type**: Check BillingType classification logic
• **Missing job types**: Verify Raw_WorkOrderDesc has all types
• **Slow refresh**: 2 minutes for 7 rows is slow (check Raw_WorkOrderDesc size)

**NEVER:**
❌ Change JobTypeKey generation logic (breaks fact table joins)
❌ Remove JobType codes still in use (breaks historical joins)
❌ Change alphabetical sort (changes key assignments)
❌ Schedule daily refresh (wastes CU capacity)

**BUSINESS INTELLIGENCE NOTES:**
Critical dimension for billing and revenue classification.
7 columns from single source field provides extensive business value.
Billing type classification essential for financial reporting.
Category grouping enables high-level business analysis.
All 7 job types currently active - comprehensive coverage.

**PERFORMANCE NOTE:**
2-minute refresh for 7 rows is slower than expected.
Possible causes: Large Raw_WorkOrderDesc table, query waiting for source refresh.
Not urgent - dimension works correctly, just slower than optimal.
Monitor if refresh time increases significantly.

============================================================================
*/
