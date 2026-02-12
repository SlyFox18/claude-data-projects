/*
============================================================================
FACT_SERVICE_DETAIL - SERVICE JOB-LEVEL FACT TABLE WITH WKINVREG FALLBACK
============================================================================

TABLE OVERVIEW:
Purpose: Service job-level detail for Customer Anatomy report - Level 3 drill-down
Grain: One row per job within a work order, PLUS fallback rows for invoices without jobs
Source: wkothsub (job-level data) + WkInvReg (for fallback when no job records exist)
Filter: Jobs with InvoiceDate >= 2022-01-01
Refresh Strategy: Direct Lakehouse reference with date filtering

CRITICAL: This table now includes FALLBACK rows from WkInvReg (Work Order Invoice Register)
for service invoices that don't have corresponding job records in wkothsub. WkInvReg provides
WorkOrder context and financial breakdown that Invoice table doesn't have.

WHY WKINVREG INSTEAD OF INVOICE:
- WkInvReg has WorkOrder (RO_NUMBER) - Invoice table does NOT
- WkInvReg has financial breakdown (Labour, Parts, Sublet, Other)
- WkInvReg links invoices directly to work orders
- This gives us actual work order context for drill-through

BUSINESS USE CASES:
* Customer Anatomy - Service Drill-Down (Level 3): "What jobs did Customer X have?"
* Job Mix Analysis: What types of service jobs by customer
* Labor vs Parts breakdown per job
* Warranty vs Customer Pay analysis (via ClaimNumber)
* Machine downtime impact analysis
* Drill-through from Fact_Service_Invoices to see job details

KEY METRICS ENABLED:
* Labor Revenue (InvLabor)
* Labor Cost (ActLabor)
* Labor Margin = InvLabor - ActLabor
* Parts Revenue (InvParts)
* Parts Cost (ActParts)
* Parts Margin = InvParts - ActParts
* Total Job Margin = Labor Margin + Parts Margin
* Estimated vs Actual analysis (Est/Act/Inv cycle)

DIMENSIONAL RELATIONSHIPS:
* CustomerKey -> dim_CustomerList (via CustomerVehicleFlag logic + CustomerLookup fallback)
* InvoiceDateKey -> dim_DateTable (YYYYMMDD integer format)
* Branch -> dim_BranchLocation
* JobCode -> dim_JobCode (if exists)
* InvoiceNumber -> Fact_Service_Invoices (for drill-through from Level 2)

CUSTOMER ANATOMY INTEGRATION (3-Level Drill-Through):
- Level 1: Fact_CustomerPerformance (Customer X spent $8000 on service)
- Level 2: Fact_Service_Invoices (Customer X had 8 service invoices)
- Level 3: Fact_Service_Detail (Work Order #12345 had these jobs: Oil Change, Tire Rotation...)

CUSTOMER ASSIGNMENT LOGIC (Updated 2026-02-09):
This table uses CustomerVehicleFlag from WKROFILE to properly categorize work:
- CustomerVehicleFlag = 'S' (Stock): Work on dealership-owned inventory (demos, PDI,
  damaged in transit, awaiting delivery). Assigned to CustomerKey = -9 (Stock Equipment).
- CustomerVehicleFlag = 'C' (Customer): Work on customer-owned equipment. Uses standard
  CustomerLookup matching via BillToAccount/AccountNumber.
- No match found: Assigned to CustomerKey = -1 (Unknown Customer).

Join path to get CustomerVehicleFlag:
- PART 1 (wkothsub): wkothsub.WorkOrder + wkothsub.Branch -> WKROFILE
- PART 2 (WkInvReg): WkInvReg.WorkOrder + WkInvReg.Branch -> WKROFILE

DATAFLOW REQUIREMENTS:
This query requires these Lakehouse table references in the dataflow:
1. wkothsub - Job-level service data (already in Lakehouse)
2. WkInvReg - Work Order Invoice Register (for fallback rows with WorkOrder context)
3. WKROFILE - Work order master (for CustomerVehicleFlag) - NEW!
4. Invoice - For BillToAccount lookup on wkothsub records
5. CustomerLookup - Bridge table for customer matching
6. dim_CustomerList - Must include CustomerKey = -9 (Stock Equipment)

============================================================================
*/

let
    // ========================================================================
    // PART 1: JOB-LEVEL DATA FROM WKOTHSUB
    // ========================================================================
    // wkothsub contains job-level data within work orders
    // Each row is a job (JobCode) on a work order (WorkOrder)

    Source_wkothsub = wkothsub,

    // Filter to jobs with invoice dates in scope (2022+)
    FilteredJobs = Table.SelectRows(Source_wkothsub, each
        [InvoiceDate] <> null and
        [InvoiceDate] >= #datetime(2022, 1, 1, 0, 0, 0)),

    // Join to Invoice for BillToAccount (customer lookup)
    JoinToInvoice = Table.NestedJoin(
        FilteredJobs, {"InvoiceNumber"},
        Invoice, {"InvoiceNumber"},
        "InvoiceMatch", JoinKind.LeftOuter),

    ExpandBillToAccount = Table.ExpandTableColumn(JoinToInvoice, "InvoiceMatch",
        {"BillToAccount"},
        {"BillToAccount"}),

    // Add date keys
    AddInvoiceDateKey = Table.AddColumn(ExpandBillToAccount, "InvoiceDateKey", each
        if [InvoiceDate] = null then null
        else try Date.Year([InvoiceDate]) * 10000 + Date.Month([InvoiceDate]) * 100 + Date.Day([InvoiceDate])
        otherwise null, Int64.Type),

    AddInvoiceYear = Table.AddColumn(AddInvoiceDateKey, "InvoiceYear", each
        if [InvoiceDate] = null then null else try Date.Year([InvoiceDate]) otherwise null, Int64.Type),

    AddInvoiceMonth = Table.AddColumn(AddInvoiceYear, "InvoiceMonth", each
        if [InvoiceDate] = null then null else try Date.Month([InvoiceDate]) otherwise null, Int64.Type),

    // ========================================================================
    // GET CUSTOMERVEHICLEFLAG FROM WKROFILE
    // ========================================================================
    // wkothsub already has WorkOrder and Branch, so we can join directly to WKROFILE
    // CustomerVehicleFlag: 'S' = Stock (dealership-owned), 'C' = Customer

    JoinWKROFILE = Table.NestedJoin(
        AddInvoiceMonth, {"Branch", "WorkOrder"},
        WKROFILE, {"Branch", "WorkOrder"},
        "WKROFILEMatch", JoinKind.LeftOuter),

    ExpandCustomerVehicleFlag = Table.ExpandTableColumn(JoinWKROFILE, "WKROFILEMatch",
        {"CustomerVehicleFlag"},
        {"CustomerVehicleFlag"}),

    // ========================================================================
    // CUSTOMER KEY LOOKUP WITH CUSTOMERVEHICLEFLAG PRIORITY
    // ========================================================================
    // Priority 1: CustomerVehicleFlag = 'S' -> CustomerKey = -9 (Stock Equipment)
    // Priority 2: CustomerVehicleFlag = 'C' or null -> Use CustomerLookup
    // Priority 3: No match -> CustomerKey = -1 (Unknown Customer)

    AddMatchKey = Table.AddColumn(ExpandCustomerVehicleFlag, "BillToAccount_Upper", each
        Text.Upper(Text.Trim(Text.From([BillToAccount] ?? ""))), type text),

    // Single join to CustomerLookup bridge table
    JoinCustomer = Table.NestedJoin(
        AddMatchKey, {"BillToAccount_Upper"},
        CustomerLookup, {"MatchKey"},
        "CustomerMatch", JoinKind.LeftOuter),

    // Expand customer attributes
    ExpandCustomer = Table.ExpandTableColumn(JoinCustomer, "CustomerMatch",
        {"CustomerKey", "ContactID", "Territory", "Account_Class", "DisplayName"},
        {"CustomerKey_Lookup", "ContactID", "Territory", "AccountClass", "CustomerDisplayName"}),

    // Apply CustomerVehicleFlag priority logic for CustomerKey assignment
    AddCustomerKey = Table.AddColumn(ExpandCustomer, "CustomerKey", each
        if [CustomerVehicleFlag] = "S" then -9  // Stock Equipment
        else if [CustomerKey_Lookup] <> null then [CustomerKey_Lookup]  // Matched customer
        else -1,  // Unknown Customer
        Int64.Type),

    // Add IsStockEquipment flag
    AddIsStockEquipment = Table.AddColumn(AddCustomerKey, "IsStockEquipment", each
        [CustomerVehicleFlag] = "S", type logical),

    // Remove temporary matching columns
    RemoveMatchingColumns = Table.RemoveColumns(AddIsStockEquipment, {
        "BillToAccount_Upper", "CustomerKey_Lookup"
    }),

    // Margin calculations
    AddLaborMargin = Table.AddColumn(RemoveMatchingColumns, "LaborMargin", each
        (if [InvLabor] = null then 0 else [InvLabor]) -
        (if [ActLabor] = null then 0 else [ActLabor]), type number),

    AddPartsMargin = Table.AddColumn(AddLaborMargin, "PartsMargin", each
        (if [InvParts] = null then 0 else [InvParts]) -
        (if [ActParts] = null then 0 else [ActParts]), type number),

    AddTotalMargin = Table.AddColumn(AddPartsMargin, "TotalJobMargin", each
        (if [LaborMargin] = null then 0 else [LaborMargin]) +
        (if [PartsMargin] = null then 0 else [PartsMargin]), type number),

    AddTotalInvoiced = Table.AddColumn(AddTotalMargin, "TotalInvoiced", each
        (if [InvLabor] = null then 0 else [InvLabor]) +
        (if [InvParts] = null then 0 else [InvParts]), type number),

    AddIsWarranty = Table.AddColumn(AddTotalInvoiced, "IsWarrantyJob", each
        if [ClaimNumber] <> null and [ClaimNumber] <> "" then true else false, type logical),

    // Add source indicator for job-level records
    AddDetailSource = Table.AddColumn(AddIsWarranty, "DetailSource", each "Job Detail", type text),

    // Select columns for job data
    JobDataColumns = Table.SelectColumns(AddDetailSource, {
        "CustomerKey", "InvoiceDateKey", "BillToAccount", "ContactID", "Territory", "AccountClass", "CustomerDisplayName",
        "CustomerVehicleFlag", "IsStockEquipment",
        "InvoiceDate", "InvoiceYear", "InvoiceMonth", "Branch", "WorkOrder", "JobCode", "JobType",
        "JobStatus", "WorkCategory", "IsNonRevenue", "IsFieldRepair", "IsMachineDown",
        "EstLabor", "ActLabor", "InvLabor", "LaborMargin", "EstHours",
        "EstParts", "ActParts", "InvParts", "PartsMargin",
        "TotalInvoiced", "TotalJobMargin", "InvoiceNumber", "ClaimNumber", "IsWarrantyJob", "DetailSource"
    }),

    // Get list of InvoiceNumbers that have job records
    InvoiceNumbersWithJobs = Table.Distinct(Table.SelectColumns(JobDataColumns, {"InvoiceNumber"})),

    // ========================================================================
    // PART 2: FALLBACK ROWS FROM WKINVREG (Work Order Invoice Register)
    // ========================================================================
    // For service invoices that DON'T have job records in wkothsub,
    // use WkInvReg which has WorkOrder context and financial breakdown
    //
    // WkInvReg columns:
    // - InvoiceNumber (DOCUMENT_NO)
    // - WorkOrder (RO_NUMBER) - KEY BENEFIT: actual work order number!
    // - AccountNumber (CHARGE_ACCT) - for customer lookup
    // - Branch
    // - LabourCharged (invoiced labor)
    // - LabourCost (actual labor cost)
    // - PartsValue (invoiced parts)
    // - SubletValue, OtherValue
    // - InvoiceTotal
    // - WorkDate

    Source_WkInvReg = WkInvReg,

    // Filter to service invoices in date scope (using WorkDate)
    FilterWkInvReg = Table.SelectRows(Source_WkInvReg, each
        [WorkDate] <> null and
        [WorkDate] >= #datetime(2022, 1, 1, 0, 0, 0)),

    // Find invoices WITHOUT job records in wkothsub (anti-join)
    InvoicesWithoutJobs = Table.NestedJoin(
        FilterWkInvReg, {"InvoiceNumber"},
        InvoiceNumbersWithJobs, {"InvoiceNumber"},
        "JobMatch", JoinKind.LeftAnti),

    // Add date keys using WorkDate
    FallbackAddDateKey = Table.AddColumn(InvoicesWithoutJobs, "InvoiceDateKey", each
        if [WorkDate] = null then null
        else try Date.Year([WorkDate]) * 10000 + Date.Month([WorkDate]) * 100 + Date.Day([WorkDate])
        otherwise null, Int64.Type),

    FallbackAddYear = Table.AddColumn(FallbackAddDateKey, "InvoiceYear", each
        if [WorkDate] = null then null else try Date.Year([WorkDate]) otherwise null, Int64.Type),

    FallbackAddMonth = Table.AddColumn(FallbackAddYear, "InvoiceMonth", each
        if [WorkDate] = null then null else try Date.Month([WorkDate]) otherwise null, Int64.Type),

    // Rename WorkDate to InvoiceDate for consistency
    FallbackRenameDate = Table.RenameColumns(FallbackAddMonth, {{"WorkDate", "InvoiceDate"}}),

    // ========================================================================
    // GET CUSTOMERVEHICLEFLAG FROM WKROFILE FOR FALLBACK ROWS
    // ========================================================================
    // WkInvReg has WorkOrder and Branch, so we can join directly to WKROFILE
    // CustomerVehicleFlag: 'S' = Stock (dealership-owned), 'C' = Customer

    FallbackJoinWKROFILE = Table.NestedJoin(
        FallbackRenameDate, {"Branch", "WorkOrder"},
        WKROFILE, {"Branch", "WorkOrder"},
        "WKROFILEMatch", JoinKind.LeftOuter),

    FallbackExpandCustVehFlag = Table.ExpandTableColumn(FallbackJoinWKROFILE, "WKROFILEMatch",
        {"CustomerVehicleFlag"},
        {"CustomerVehicleFlag"}),

    // ========================================================================
    // CUSTOMER KEY LOOKUP WITH CUSTOMERVEHICLEFLAG PRIORITY
    // ========================================================================
    // Priority 1: CustomerVehicleFlag = 'S' -> CustomerKey = -9 (Stock Equipment)
    // Priority 2: CustomerVehicleFlag = 'C' or null -> Use CustomerLookup
    // Priority 3: No match -> CustomerKey = -1 (Unknown Customer)

    FallbackAddMatchKey = Table.AddColumn(FallbackExpandCustVehFlag, "AccountNumber_Upper", each
        Text.Upper(Text.Trim(Text.From([AccountNumber] ?? ""))), type text),

    // Single join to CustomerLookup bridge table
    FallbackJoinCustomer = Table.NestedJoin(
        FallbackAddMatchKey, {"AccountNumber_Upper"},
        CustomerLookup, {"MatchKey"},
        "CustomerMatch", JoinKind.LeftOuter),

    // Expand customer attributes
    FallbackExpandCustomer = Table.ExpandTableColumn(FallbackJoinCustomer, "CustomerMatch",
        {"CustomerKey", "ContactID", "Territory", "Account_Class", "DisplayName"},
        {"CustomerKey_Lookup", "ContactID", "Territory", "AccountClass", "CustomerDisplayName"}),

    // Apply CustomerVehicleFlag priority logic for CustomerKey assignment
    FallbackAddCustomerKey = Table.AddColumn(FallbackExpandCustomer, "CustomerKey", each
        if [CustomerVehicleFlag] = "S" then -9  // Stock Equipment
        else if [CustomerKey_Lookup] <> null then [CustomerKey_Lookup]  // Matched customer
        else -1,  // Unknown Customer
        Int64.Type),

    // Add IsStockEquipment flag
    FallbackAddIsStockEquipment = Table.AddColumn(FallbackAddCustomerKey, "IsStockEquipment", each
        [CustomerVehicleFlag] = "S", type logical),

    // Remove temporary matching columns
    FallbackRemoveMatchCols = Table.RemoveColumns(FallbackAddIsStockEquipment, {
        "AccountNumber_Upper", "CustomerKey_Lookup"
    }),

    // Rename AccountNumber to BillToAccount for consistency with job data
    FallbackRenameBillTo = Table.RenameColumns(FallbackRemoveMatchCols, {{"AccountNumber", "BillToAccount"}}),

    // Calculate margins using WkInvReg financial columns
    // LabourCharged = Invoiced Labor, LabourCost = Actual Labor Cost
    FallbackAddLaborMargin = Table.AddColumn(FallbackRenameBillTo, "LaborMargin", each
        (if [LabourCharged] = null then 0 else [LabourCharged]) -
        (if [LabourCost] = null then 0 else [LabourCost]), type number),

    // PartsValue is invoiced parts - WkInvReg doesn't have parts cost, so margin = 0
    FallbackAddPartsMargin = Table.AddColumn(FallbackAddLaborMargin, "PartsMargin", each
        0, type number),

    FallbackAddTotalMargin = Table.AddColumn(FallbackAddPartsMargin, "TotalJobMargin", each
        [LaborMargin] + [PartsMargin], type number),

    // Total Invoiced from WkInvReg (Labour + Parts + Sublet + Other)
    FallbackAddTotalInvoiced = Table.AddColumn(FallbackAddTotalMargin, "TotalInvoiced", each
        (if [LabourCharged] = null then 0 else [LabourCharged]) +
        (if [PartsValue] = null then 0 else [PartsValue]) +
        (if [SubletValue] = null then 0 else [SubletValue]) +
        (if [OtherValue] = null then 0 else [OtherValue]), type number),

    // Map WkInvReg columns to match job data structure
    // WorkOrder comes directly from WkInvReg - this is the key benefit!
    FallbackAddJobCode = Table.AddColumn(FallbackAddTotalInvoiced, "JobCode", each "(WO Summary)", type text),
    FallbackAddJobType = Table.AddColumn(FallbackAddJobCode, "JobType", each null, type text),
    FallbackAddJobStatus = Table.AddColumn(FallbackAddJobType, "JobStatus", each null, type text),
    FallbackAddWorkCategory = Table.AddColumn(FallbackAddJobStatus, "WorkCategory", each null, type text),
    FallbackAddIsNonRevenue = Table.AddColumn(FallbackAddWorkCategory, "IsNonRevenue", each null, type text),
    FallbackAddIsFieldRepair = Table.AddColumn(FallbackAddIsNonRevenue, "IsFieldRepair", each null, type text),
    FallbackAddIsMachineDown = Table.AddColumn(FallbackAddIsFieldRepair, "IsMachineDown", each null, type text),
    FallbackAddEstLabor = Table.AddColumn(FallbackAddIsMachineDown, "EstLabor", each null, type number),
    FallbackAddActLabor = Table.AddColumn(FallbackAddEstLabor, "ActLabor", each [LabourCost], type number),
    FallbackAddInvLabor = Table.AddColumn(FallbackAddActLabor, "InvLabor", each [LabourCharged], type number),
    FallbackAddEstHours = Table.AddColumn(FallbackAddInvLabor, "EstHours", each null, type number),
    FallbackAddEstParts = Table.AddColumn(FallbackAddEstHours, "EstParts", each null, type number),
    FallbackAddActParts = Table.AddColumn(FallbackAddEstParts, "ActParts", each null, type number),
    FallbackAddInvParts = Table.AddColumn(FallbackAddActParts, "InvParts", each [PartsValue], type number),
    FallbackAddClaimNumber = Table.AddColumn(FallbackAddInvParts, "ClaimNumber", each null, type text),
    FallbackAddIsWarranty = Table.AddColumn(FallbackAddClaimNumber, "IsWarrantyJob", each false, type logical),
    FallbackAddDetailSource = Table.AddColumn(FallbackAddIsWarranty, "DetailSource", each "WO Summary", type text),

    // Select matching columns for fallback data
    FallbackColumns = Table.SelectColumns(FallbackAddDetailSource, {
        "CustomerKey", "InvoiceDateKey", "BillToAccount", "ContactID", "Territory", "AccountClass", "CustomerDisplayName",
        "CustomerVehicleFlag", "IsStockEquipment",
        "InvoiceDate", "InvoiceYear", "InvoiceMonth", "Branch", "WorkOrder", "JobCode", "JobType",
        "JobStatus", "WorkCategory", "IsNonRevenue", "IsFieldRepair", "IsMachineDown",
        "EstLabor", "ActLabor", "InvLabor", "LaborMargin", "EstHours",
        "EstParts", "ActParts", "InvParts", "PartsMargin",
        "TotalInvoiced", "TotalJobMargin", "InvoiceNumber", "ClaimNumber", "IsWarrantyJob", "DetailSource"
    }),

    // ========================================================================
    // PART 3: COMBINE JOB DATA + FALLBACK DATA
    // ========================================================================

    CombinedData = Table.Combine({JobDataColumns, FallbackColumns}),

    // Set final data types
    SetTypes = Table.TransformColumnTypes(CombinedData, {
        {"CustomerKey", Int64.Type},
        {"InvoiceDateKey", Int64.Type},
        {"BillToAccount", type text},
        {"ContactID", type text},
        {"Territory", type text},
        {"AccountClass", type text},
        {"CustomerDisplayName", type text},
        {"CustomerVehicleFlag", type text},
        {"IsStockEquipment", type logical},
        {"InvoiceDate", type datetime},
        {"InvoiceYear", Int64.Type},
        {"InvoiceMonth", Int64.Type},
        {"Branch", type text},
        {"WorkOrder", type text},
        {"JobCode", type text},
        {"JobType", type text},
        {"JobStatus", type text},
        {"WorkCategory", type text},
        {"IsNonRevenue", type text},
        {"IsFieldRepair", type text},
        {"IsMachineDown", type text},
        {"EstLabor", type number},
        {"ActLabor", type number},
        {"InvLabor", type number},
        {"LaborMargin", type number},
        {"EstHours", type number},
        {"EstParts", type number},
        {"ActParts", type number},
        {"InvParts", type number},
        {"PartsMargin", type number},
        {"TotalInvoiced", type number},
        {"TotalJobMargin", type number},
        {"InvoiceNumber", type text},
        {"ClaimNumber", type text},
        {"IsWarrantyJob", type logical},
        {"DetailSource", type text}
    })

in
    SetTypes

/*
============================================================================
FACT_SERVICE_DETAIL - IMPLEMENTATION NOTES
============================================================================

DATAFLOW SETUP REQUIREMENTS (Updated 2026-02-09):

This query requires these Lakehouse table references:

1. **wkothsub** (already exists)
   - Reference to: LH_Master_Data > wkothsub
   - Query name in dataflow: wkothsub
   - Job-level service data

2. **WkInvReg** (NEW - must add to dataflow)
   - Reference to: LH_Master_Data > WkInvReg
   - Query name in dataflow: WkInvReg
   - Work Order Invoice Register - provides fallback rows with WorkOrder context

3. **WKROFILE** (NEW - must add to dataflow)
   - Reference to: LH_Master_Data > WKROFILE
   - Query name in dataflow: WKROFILE
   - Work order master - provides CustomerVehicleFlag

4. **Invoice** (already exists)
   - Reference to: LH_Master_Data > Invoice
   - Query name in dataflow: Invoice
   - Provides BillToAccount for customer lookup on wkothsub records

5. **CustomerLookup** (already exists)
   - Reference to: LH_Master_Data > CustomerLookup
   - Query name in dataflow: CustomerLookup
   - Bridge table for customer matching

6. **dim_CustomerList** (already exists)
   - Reference to: LH_Master_Data > dim_CustomerList
   - Query name in dataflow: dim_CustomerList
   - Must include CustomerKey = -9 (Stock Equipment)

DATAFLOW STRUCTURE:
```
Dataflow: df_CustomerAnatomy_Facts (or similar)
├── wkothsub (Lakehouse reference)
├── WkInvReg (Lakehouse reference)
├── WKROFILE (Lakehouse reference) - NEW!
├── Invoice (Lakehouse reference)
├── CustomerLookup (Lakehouse reference)
├── dim_CustomerList (Lakehouse reference)
└── Fact_Service_Detail (this query)
```

============================================================================
CUSTOMER ASSIGNMENT LOGIC (Updated 2026-02-09)
============================================================================

PROBLEM SOLVED:
Service detail records were showing as "Unknown Customer" when the work was performed
on dealership-owned stock equipment (BillToAccount = '0'). This is now properly
categorized using CustomerVehicleFlag from WKROFILE.

SOLUTION - CUSTOMERVEHICLEFLAG:
WKROFILE.CustomerVehicleFlag identifies the type of equipment:
- 'S' = Stock (dealership-owned): demos, PDI, damaged in transit, awaiting delivery
- 'C' = Customer (customer-owned): regular customer work

CUSTOMER KEY ASSIGNMENT PRIORITY (both PART 1 and PART 2):
1. CustomerVehicleFlag = 'S' -> CustomerKey = -9 (Stock Equipment)
2. CustomerVehicleFlag = 'C' or null -> Use CustomerLookup via BillToAccount/AccountNumber
3. CustomerLookup doesn't match -> CustomerKey = -1 (Unknown Customer)

NEW COLUMNS ADDED:
- CustomerVehicleFlag: 'S' = Stock, 'C' = Customer (from WKROFILE)
- IsStockEquipment: Boolean flag for filtering (true when CustomerVehicleFlag = 'S')

============================================================================

============================================================================
WKINVREG FALLBACK MECHANISM (IMPROVED)
============================================================================

PROBLEM SOLVED:
Many service invoices in Fact_Service_Invoices don't have corresponding job records
in wkothsub. The previous fallback used Invoice table which lacks WorkOrder context.

SOLUTION - USE WKINVREG:
WkInvReg (Work Order Invoice Register) provides:
- InvoiceNumber (DOCUMENT_NO) - links to Fact_Service_Invoices
- WorkOrder (RO_NUMBER) - ACTUAL work order number! (Invoice table doesn't have this)
- AccountNumber (CHARGE_ACCT) - for customer lookup
- LabourCharged / LabourCost - for labor revenue and margin
- PartsValue, SubletValue, OtherValue - for service category breakdown
- WorkDate - for date key generation

This query now creates TWO types of rows:

1. **Job Detail rows** (DetailSource = "Job Detail")
   - Source: wkothsub table
   - One row per job (WorkOrder + JobCode)
   - Full job-level breakdown with Est/Act/Inv cycles

2. **WO Summary rows** (DetailSource = "WO Summary")
   - Source: WkInvReg table (for invoices NOT in wkothsub)
   - One row per invoice
   - JobCode = "(WO Summary)" to indicate fallback
   - HAS WorkOrder number (key improvement!)
   - Financial values from WkInvReg (LabourCharged, PartsValue, etc.)

This ensures EVERY InvoiceNumber in Fact_Service_Invoices has at least one
matching row in Fact_Service_Detail, making drill-through work for all invoices.

NEW COLUMN VALUES:
- DetailSource = "Job Detail" = Real job-level data from wkothsub
- DetailSource = "WO Summary" = Work order summary from WkInvReg

============================================================================

EXPECTED PERFORMANCE:
- Source rows (wkothsub): ~350K rows
- After date filter: ~200-250K rows (2022+)
- Fallback rows from WkInvReg: ~20-30K rows (invoices without job records)
- Refresh time: 5-8 min expected

============================================================================

REQUIRED RELATIONSHIPS IN SEMANTIC MODEL:
1. Fact_Service_Detail[InvoiceNumber] -> Fact_Service_Invoices[InvoiceNumber] (Many-to-One, ACTIVE)
2. Fact_Service_Detail[CustomerKey] -> dim_CustomerList[CustomerKey] (Many-to-One, INACTIVE)
3. Fact_Service_Detail[InvoiceDateKey] -> dim_DateTable[DateKey] (Many-to-One, INACTIVE)
4. Fact_Service_Detail[Branch] -> dim_BranchLocation[BranchID] (Many-to-One, INACTIVE)

NOTE: Detail-to-dimension relationships should be INACTIVE to avoid ambiguous paths.
Filtering flows through Invoice tables to Detail tables via the active InvoiceNumber relationship.

KEY DAX MEASURES TO CREATE:

-- Job Count (excludes fallback summary rows)
Service Jobs = CALCULATE(COUNTROWS(Fact_Service_Detail), Fact_Service_Detail[DetailSource] = "Job Detail")

-- Work Order Summary Count (fallback rows)
Service WO Summaries = CALCULATE(COUNTROWS(Fact_Service_Detail), Fact_Service_Detail[DetailSource] = "WO Summary")

-- All Detail Rows (includes both)
Service Detail Rows = COUNTROWS(Fact_Service_Detail)

-- Labor Revenue
Service Labor Revenue = SUM(Fact_Service_Detail[InvLabor])

-- Labor Margin
Service Labor Margin = SUM(Fact_Service_Detail[LaborMargin])

-- Total Service Revenue
Service Total Revenue = SUM(Fact_Service_Detail[TotalInvoiced])

-- Total Service Margin
Service Total Margin = SUM(Fact_Service_Detail[TotalJobMargin])

DRILL-DOWN INTEGRATION (3-Level Architecture):

Level 1: Fact_CustomerPerformance
  "Customer X spent $8000 on service last quarter"
       ↓ Click on customer
Level 2: Fact_Service_Invoices
  "Customer X had 8 service invoices: Invoice #1269113 ($797), Invoice #1686530 ($782)..."
       ↓ Click on invoice (drill-through on InvoiceNumber)
Level 3: Fact_Service_Detail (THIS TABLE)
  - If jobs exist: "Invoice #1269113 had 3 jobs: Oil Change ($150), Tire Rotation ($80)..."
  - If no jobs: "Invoice #1269113 - WO #12345 Summary ($797)" [shows actual WorkOrder!]

Link Field: InvoiceNumber (Fact_Service_Detail → Fact_Service_Invoices)

============================================================================
*/
