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
            )
        in
            ConvertToText,
    
    // ========================================================================
    // STEP 3: LOAD PARTS TRANSACTIONS FROM INTRANS_INCREMENTAL
    // ========================================================================
    /*
    SOURCE: InTrans_Incremental (Lakehouse)
    COLUMNS: Branch, RONumber, TransDatetime, PartNumber, Description, 
             Franchise, Qty, SaleValue, CostValue, SellPrice1, ListPrice,
             CustomerNo, TradeType, ModifiedDate
    */
    
    PartsSource = InTrans_Incremental,
    
    // Ensure join columns are TEXT type
    PartsWithTextTypes = Table.TransformColumnTypes(
        PartsSource,
        {
            {"Branch", type text},
            {"RONumber", type text}  // RONumber in InTrans = Invoice Number
        }
    ),
    
    // ========================================================================
    // STEP 4: FILTER TO INSPECTION INVOICES
    // ========================================================================
    /*
    JOIN: InTrans_Incremental.Branch + RONumber = wkothsub.Branch + InvoiceNumber
    */
    
    FilterToInspectionInvoices = Table.NestedJoin(
        PartsWithTextTypes,
        {"Branch", "RONumber"},           // InTrans_Incremental columns
        InspectionInvoices,
        {"Branch", "InvoiceNumber"},      // wkothsub columns
        "InspectionMatch",
        JoinKind.Inner
    ),
    
    RemoveMatchTable = Table.RemoveColumns(FilterToInspectionInvoices, {"InspectionMatch"}),
    
    // ========================================================================
    // STEP 5: KEEP ALL FRANCHISE CODES (INCLUDING ZP FOR DISCOUNTS)
    // ========================================================================
    
    KeepAllFranchises = RemoveMatchTable,
    
    // ========================================================================
    // STEP 6: RENAME COLUMNS FOR CONSISTENCY WITH SEMANTIC MODEL
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
    // STEP 7: SET PROPER DATA TYPES
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
// STEP 8: REMOVE DUPLICATES FROM SOURCE DATA
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