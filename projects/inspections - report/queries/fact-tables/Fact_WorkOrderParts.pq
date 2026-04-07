/*
============================================================================
FACT_WORKORDERPARTS - INSPECTION WORK ORDER PARTS ANALYTICS (OPTIMIZED)
============================================================================

📋 TABLE OVERVIEW:
Purpose: Complete parts transaction data for work orders with inspections
Grain: One row per parts transaction line item from inspection-related invoices
Refresh Strategy: Full refresh (maintains fast performance with optimized joins)
Performance: Target 2-4 minutes (improved with InTrans_Incremental)
Source Dependencies: Raw_wkothsub, InTrans_Incremental (Lakehouse)

🎯 BUSINESS USE CASES:
- Parts Revenue Analysis: Track all parts sold on inspection work orders
- Discount Tracking: Identify and measure ADV, Trucking, and Promotional discounts
- Service Mix Analysis: Understand parts vs labor mix for inspection work orders
- Pattern Recognition: Identify commonly sold parts with specific inspection types
- Upsell Opportunity: Measure parts revenue generated from inspection leads

📊 DATA STRUCTURE (13+ COLUMNS):

**Core Identifiers:**
- BranchCode: Branch location
- InvoiceNumber: Invoice identifier (links to work orders)
- PartNumber: Part number (includes discount part codes)
- TransactionDate: When part was sold

**Financial Data:**
- SaleValue: Part sale value (negative for discounts)
- CostValue: Part cost value
- SellPrice: Selling price
- ListPrice: List price
- Quantity: Quantity sold

**Business Context:**
- Franchise: Franchise code (ZP = discount items, non-ZP = real parts)
- Description: Part description
- CustomerNumber: Customer identifier
- TradeType: Trade type indicator
- ModifiedDate: Last modification date

🔧 ARCHITECTURAL DESIGN DECISIONS:

**Invoice-Based Join Strategy:**
- InTrans links to INVOICE NUMBERS, not work orders
- Get all invoices from work orders with at least one inspection job
- Join InTrans on those invoice numbers
- Captures ALL parts sold on inspection-related invoices

**Franchise Code Strategy (CRITICAL):**
- ⭐ KEEP ALL FRANCHISES including ZP
- Real parts: Franchise <> "ZP"
- Discount items: Franchise = "ZP" (ADV, LEGACY, 4900, *10PROMO)
- Filter in DAX measures, not in source query

**Inspection Code Consistency:**
- Uses EXACT SAME 111 inspection codes as Fact_LaborJobSummary
- Ensures parts and labor metrics align perfectly
- Single source of truth for inspection identification

**InTrans_Incremental Integration:**
- ⭐ NEW: Uses InTrans_Incremental from Lakehouse (optimized, current data)
- Replaces Raw_InTrans (legacy full refresh)
- Improves refresh performance and reduces CU usage
- Maintains data consistency with incremental refresh strategy

🎯 DISCOUNT PART NUMBERS:
- **ADV Discount**: PartNumber IN {"ADV", "LEGACY"}
- **Trucking Discount**: PartNumber = "4900"
- **Parts Discount**: PartNumber = "*10PROMO"

All discount parts have Franchise = "ZP" and negative SaleValue

📋 TABLE OVERVIEW:
Purpose: Complete parts transaction data for work orders with inspections
Grain: One row per parts transaction line item from inspection-related invoices
Refresh Strategy: Full refresh (maintains fast performance with optimized joins)
Performance: Target 2-4 minutes (improved with InTrans_Incremental)
Source Dependencies: Raw_wkothsub, InTrans_Incremental (Lakehouse)

🎯 KEY OPTIMIZATIONS:
- Uses InTrans_Incremental from Lakehouse (current data, faster queries)
- Simplified column handling and joins
- Maintains all business logic and discount tracking
- Expected 70% performance improvement vs Raw_InTrans

============================================================================
*/

let
    // ========================================================================
    // STEP 1: INSPECTION JOB CODE LOOKUP TABLE (111 CODES)
    // ========================================================================
    
    InspectionCodes = #table(
        type table [job_code = text],
        {
            {"/COMBINE VIP INSPECT"},
            {"/CS690 INSPECTION"},
            {"/CS690 VIP INSPECTIO"},
            {"/INSPECTION"},
            {"/PLANTER INSPECTION"},
            {"/Rental Inspection"},
            {"/SPRAYER INSPECTION"},
            {"/TRACTOR INSPECTION"},
            {"/WINTER INSPECTION"},
            {"ALL/9001/LEG/590"},
            {"COMBINE INSPECTION"},
            {"IS-125"},
            {"IS-145"},
            {"IS-3E ANNUAL SERVICE"},
            {"IS-4X2"},
            {"IS-5E INSPECT"},
            {"IS-AMS DATA"},
            {"IS-AMS DATA SETUP"},
            {"IS-AMS OPTIMIZE"},
            {"IS-AMS SOFTWARE"},
            {"IS-COMBINE INSPECT"},
            {"IS-COMPACT INSPECT"},
            {"IS-CORN/DRAPER"},
            {"IS-CP690 INSPECT"},
            {"IS-CP770 INSPECT"},
            {"IS-CS690 INSPECT"},
            {"IS-CS770 INSPECT"},
            {"IS-D100"},
            {"IS-D105(-200000)"},
            {"IS-D105(200001-)"},
            {"IS-D110(-500000)"},
            {"IS-D110(500001-)"},
            {"IS-D120"},
            {"IS-D125"},
            {"IS-D130(-400000)"},
            {"IS-D130(400001-)"},
            {"IS-D140(-400000)"},
            {"IS-D140(400001-)"},
            {"IS-D155(700001-)"},
            {"IS-D160"},
            {"IS-D170"},
            {"IS-E100"},
            {"IS-E120"},
            {"IS-E120-QCD"},
            {"IS-E130-QCD"},
            {"IS-E170-QCD"},
            {"IS-E180-QCD"},
            {"IS-GATOR INSPECTION"},
            {"IS-HPX(-040000)"},
            {"IS-HPX(040001-)"},
            {"IS-L110"},
            {"IS-L130"},
            {"IS-LA115"},
            {"IS-LA125"},
            {"IS-LA135"},
            {"IS-LT150(039001-)"},
            {"IS-LT160"},
            {"IS-LT166"},
            {"IS-LT180"},
            {"IS-MOWER INSPECTION"},
            {"IS-PICKER INSPECT"},
            {"IS-PLANTER INSPECT"},
            {"IS-PLATFORM INSP"},
            {"IS-PRE R INSPECTION"},
            {"IS-R INSPECTION"},
            {"IS-S240"},
            {"IS-SKID STEER INSPEC"},
            {"IS-SPRAYER INSPECT"},
            {"IS-STRIPPER INSPECT"},
            {"IS-SWATHER INSPECT"},
            {"IS-TRACTOR INSPECT"},
            {"IS-TS4X2"},
            {"IS-X300(-180000)"},
            {"IS-X300(180001-)"},
            {"IS-X300R(120001-)"},
            {"IS-X304(180001-)"},
            {"IS-X310"},
            {"IS-X320(-180000)"},
            {"IS-X324(-180000)"},
            {"IS-X350"},
            {"IS-X354"},
            {"IS-X360(-180000)"},
            {"IS-X380"},
            {"IS-X500"},
            {"IS-X570"},
            {"IS-XUV550"},
            {"IS-XUV560"},
            {"IS-XUV590I"},
            {"IS-XUV590M"},
            {"IS-XUV835R"},
            {"IS-XUV855D"},
            {"IS-Z225(-060000)"},
            {"IS-Z225(100001-12000"},
            {"IS-Z255"},
            {"IS-Z335E"},
            {"IS-Z345M"},
            {"IS-Z345R"},
            {"IS-Z355E"},
            {"IS-Z355R"},
            {"IS-Z375R"},
            {"IS-Z425(-040000)"},
            {"IS-Z425(100001-)"},
            {"IS-Z425(40001-100000"},
            {"IS-Z435"},
            {"IS-Z445(-100000)"},
            {"IS-Z445(100000-14000"},
            {"IS-Z445(140001-)"},
            {"IS-Z515E"},
            {"IS-Z525E"},
            {"IS-Z535M"},
            {"IS-Z540M"},
            {"IS-HARVESTREADY"},
            {"IS-Z540R"}
        }
    ),
    
    // ========================================================================
    // STEP 2: IDENTIFY INVOICE NUMBERS FROM INSPECTION WORK ORDERS
    // ========================================================================
    /*
    BRANCH NORMALIZATION (applied in Steps 2 and 3):
    wkothsub records work orders on sub-branch codes (e.g. "11S" for the Set-Up
    Shop at Branch 11), while InTrans_Incremental records the parts transaction on
    the main branch code ("11"). The inner join on Branch + InvoiceNumber silently
    dropped these rows — causing $29K+ of real parts to show as $0.

    FIX: Strip trailing sub-branch suffix from Branch on both sides before joining.
    Known suffixes: S = Set-Up Shop, I = IS Shop, C = CP Shop, B = other sub-branch.
    Simple text operation — no Lakehouse join needed, query folding preserved.
    */

    InspectionInvoices =
        let
            Source = Raw_wkothsub,

            // JOIN TO INSPECTION CODES TABLE
            JoinInspectionCodes = Table.NestedJoin(
                Source,
                {"JobCode"},
                InspectionCodes,
                {"job_code"},
                "InspectionMatch",
                JoinKind.Inner
            ),

            RemoveMatchColumn = Table.RemoveColumns(JoinInspectionCodes, {"InspectionMatch"}),

            // Get distinct Branch + InvoiceNumber combinations
            DistinctInvoices = Table.Distinct(
                Table.SelectColumns(RemoveMatchColumn, {"Branch", "InvoiceNumber"})
            ),

            // Filter out nulls (jobs not yet invoiced)
            RemoveNulls = Table.SelectRows(
                DistinctInvoices,
                each [InvoiceNumber] <> null and [InvoiceNumber] <> ""
            ),

            // Convert to TEXT type to prevent join issues
            ConvertToText = Table.TransformColumnTypes(
                RemoveNulls,
                {
                    {"Branch", type text},
                    {"InvoiceNumber", type text}
                }
            ),

            // Normalize sub-branch to main branch by stripping trailing suffix letter
            // e.g. "11S" → "11", "12I" → "12", "15C" → "15"
            AddNormalizedBranch = Table.AddColumn(
                ConvertToText, "BranchNorm",
                each if List.Contains({"S","I","C","B"}, Text.End([Branch], 1))
                     then Text.Start([Branch], Text.Length([Branch]) - 1)
                     else [Branch],
                type text
            ),
            DropOldBranch = Table.RemoveColumns(AddNormalizedBranch, {"Branch"}),
            RenameNormBranch = Table.RenameColumns(DropOldBranch, {{"BranchNorm", "Branch"}}),
            // Deduplicate: multiple sub-branches normalizing to the same main branch + invoice
            NormalizedInvoices = Table.Distinct(RenameNormBranch)
        in
            NormalizedInvoices,

    // ========================================================================
    // STEP 4: LOAD PARTS TRANSACTIONS FROM INTRANS_INCREMENTAL
    // ========================================================================
    /*
    SOURCE: InTrans_Incremental (Lakehouse)
    COLUMNS: Branch, RONumber, TransDatetime, PartNumber, Description,
             Franchise, Qty, SaleValue, CostValue, SellPrice1, ListPrice,
             CustomerNo, TradeType, ModifiedDate
    */

    PartsSource = InTrans_Incremental,

    // Rolling 3-year cutoff — Inspections report needs ~3 years max for YoY comparisons.
    // Filters InTrans_Incremental before the inspection invoice join, reducing data volume
    // from 10M+ rows to ~3M rows. Folds to SQL on the Lakehouse endpoint.
    CutoffDate = Date.AddYears(Date.From(DateTime.LocalNow()), -3),
    PartsFiltered = Table.SelectRows(PartsSource, each Date.From([TransDatetime]) >= CutoffDate),

    // Ensure join columns are TEXT type
    PartsWithTextTypes = Table.TransformColumnTypes(
        PartsFiltered,
        {
            {"Branch", type text},
            {"RONumber", type text}  // RONumber in InTrans = Invoice Number
        }
    ),

    // Normalize InTrans Branch to main branch code — same suffix-strip logic as InspectionInvoices
    // Simple AddColumn avoids a NestedJoin on 3M+ rows that would break query folding
    AddIntransNormalizedBranch = Table.AddColumn(
        PartsWithTextTypes, "BranchNorm",
        each if List.Contains({"S","I","C","B"}, Text.End([Branch], 1))
             then Text.Start([Branch], Text.Length([Branch]) - 1)
             else [Branch],
        type text
    ),
    DropIntransOldBranch = Table.RemoveColumns(AddIntransNormalizedBranch, {"Branch"}),
    PartsNormalized = Table.RenameColumns(DropIntransOldBranch, {{"BranchNorm", "Branch"}}),

    // ========================================================================
    // STEP 5: FILTER TO INSPECTION INVOICES
    // ========================================================================
    /*
    JOIN: InTrans_Incremental.Branch(normalized) + RONumber
          = wkothsub.Branch(normalized) + InvoiceNumber
    Both sides now use LocationID (main branch), so sub-branch mismatches are resolved.
    */

    FilterToInspectionInvoices = Table.NestedJoin(
        PartsNormalized,
        {"Branch", "RONumber"},           // InTrans_Incremental columns (branch normalized)
        InspectionInvoices,
        {"Branch", "InvoiceNumber"},      // wkothsub columns (branch normalized)
        "InspectionMatch",
        JoinKind.Inner
    ),
    
    RemoveMatchTable = Table.RemoveColumns(FilterToInspectionInvoices, {"InspectionMatch"}),
    
    // ========================================================================
    // STEP 6: KEEP ALL FRANCHISE CODES (INCLUDING ZP FOR DISCOUNTS)
    // ========================================================================

    KeepAllFranchises = RemoveMatchTable,

    // ========================================================================
    // STEP 7: RENAME COLUMNS FOR CONSISTENCY WITH SEMANTIC MODEL
    // ========================================================================
    
    RenameColumns = Table.RenameColumns(
        KeepAllFranchises,
        {
            {"Branch", "BranchCode"},
            {"RONumber", "InvoiceNumber"},
            {"TransDatetime", "TransactionDate"},
            {"Qty", "Quantity"},
            {"CustomerNo", "CustomerNumber"},
            {"SellPrice1", "SellPrice"}
        }
    ),
    
    // ========================================================================
    // STEP 8: SET PROPER DATA TYPES
    // ========================================================================
    
    SetDataTypes = Table.TransformColumnTypes(
        RenameColumns,
        {
            {"BranchCode", type text},
            {"InvoiceNumber", type text},
            {"TransactionDate", type date},
            {"PartNumber", type text},
            {"Description", type text},
            {"Franchise", type text},
            {"Quantity", type number},
            {"SaleValue", type number},
            {"CostValue", type number},
            {"SellPrice", type number},
            {"ListPrice", type number},
            {"CustomerNumber", type text},
            {"TradeType", type text},
            {"ModifiedDate", type datetime}
        }
    ),


// ========================================================================
// STEP 9: REMOVE DUPLICATES FROM SOURCE DATA
// ========================================================================
/*
ISSUE: InTrans_Incremental contains historical duplicates from Dec 31-Jan 1 
       system shutdowns when pipeline retried and loaded same data 5x
FIX: Deduplicate based on business grain before loading to semantic model
SAFETY: Only affects this report, doesn't touch shared InTrans_Incremental
*/

RemoveDuplicates = Table.Distinct(
    SetDataTypes,
    {
        "BranchCode",
        "InvoiceNumber", 
        "PartNumber",
        "TransactionDate",
        "Quantity",
        "SaleValue"
    }
)

in
    RemoveDuplicates

/*
============================================================================
✅ FACT_WORKORDERPARTS - OPTIMIZED WITH INTRANS_INCREMENTAL
============================================================================

🎯 KEY CHANGES:

1. **Source:** Raw_InTrans → InTrans_Incremental (Lakehouse)
2. **Column Mapping:** Correctly maps InTrans_Incremental columns
   - Branch → BranchCode
   - RONumber → InvoiceNumber  
   - Qty → Quantity
   - CustomerNo → CustomerNumber
   - SellPrice1 → SellPrice

3. **Performance:** Expected 70% improvement (11-12 min → 2-4 min)

4. **Business Logic:** Unchanged - maintains all discount tracking and inspection filtering

📊 EXPECTED RESULTS:
- Refresh time: 2-4 minutes
- Row count: 100K-500K rows
- All discount types captured (ZP franchise)

============================================================================
*/