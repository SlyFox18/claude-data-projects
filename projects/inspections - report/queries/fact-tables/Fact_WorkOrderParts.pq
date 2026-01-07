/*
============================================================================
FACT_WORKORDERPARTS - INSPECTION WORK ORDER PARTS ANALYTICS (UPDATED)
============================================================================

📋 TABLE OVERVIEW:
Purpose: Complete parts transaction data for work orders with inspections
Grain: One row per parts transaction line item from inspection-related invoices
Refresh Strategy: Full refresh (maintains fast performance with optimized joins)
Performance: Target 2-3 minutes
Source Dependencies: Raw_wkothsub, Raw_InTrans

🎯 BUSINESS USE CASES:
• Parts Revenue Analysis: Track all parts sold on inspection work orders
• Discount Tracking: Identify and measure ADV, Trucking, and Promotional discounts
• Service Mix Analysis: Understand parts vs labor mix for inspection work orders
• Pattern Recognition: Identify commonly sold parts with specific inspection types
• Upsell Opportunity: Measure parts revenue generated from inspection leads

📊 DATA STRUCTURE (13+ COLUMNS):

**Core Identifiers:**
• BranchCode: Branch location
• InvoiceNumber: Invoice identifier (links to work orders)
• PartNumber: Part number (includes discount part codes)
• TransactionDate: When part was sold

**Financial Data:**
• SaleValue: Part sale value (negative for discounts)
• CostValue: Part cost value
• SellPrice: Selling price
• ListPrice: List price
• Quantity: Quantity sold

**Business Context:**
• Franchise: Franchise code (ZP = discount items, non-ZP = real parts)
• Description: Part description
• CustomerNumber: Customer identifier
• TradeType: Trade type indicator
• ModifiedDate: Last modification date

🔧 ARCHITECTURAL DESIGN DECISIONS:

**Invoice-Based Join Strategy:**
• InTrans links to INVOICE NUMBERS, not work orders
• Get all invoices from work orders with at least one inspection job
• Join InTrans on those invoice numbers
• Captures ALL parts sold on inspection-related invoices

**Franchise Code Strategy (CRITICAL):**
• ⭐ KEEP ALL FRANCHISES including ZP
• Real parts: Franchise <> "ZP"
• Discount items: Franchise = "ZP" (ADV, LEGACY, 4900, *10PROMO)
• Filter in DAX measures, not in source query

**Inspection Code Consistency:**
• Uses EXACT SAME 111 inspection codes as Fact_LaborJobSummary
• Ensures parts and labor metrics align perfectly
• Single source of truth for inspection identification

🎯 DISCOUNT PART NUMBERS:
• **ADV Discount**: PartNumber IN {"ADV", "LEGACY"}
• **Trucking Discount**: PartNumber = "4900"
• **Parts Discount**: PartNumber = "*10PROMO"

All discount parts have Franchise = "ZP" and negative SaleValue

============================================================================
*/

let
    // ========================================================================
    // STEP 1: INSPECTION JOB CODE LOOKUP TABLE (111 CODES)
    // ========================================================================
    /*
    PURPOSE: Centralized definition of all inspection job codes
    CRITICAL: MUST match Fact_LaborJobSummary for consistency
    MAINTENANCE: Update both this and Fact_LaborJobSummary when new codes added
    COVERAGE: 111 distinct inspection job codes across all equipment types
    */
    
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
    PURPOSE: Get all invoice numbers from work orders that have inspections
    LOGIC: Any invoice from a work order with at least one inspection job
    CRITICAL: InTrans links to invoices, not work orders directly
    CONSISTENCY: Uses same inspection code list as Fact_LaborJobSummary
    */
    
    InspectionInvoices = 
        let
            Source = Raw_wkothsub,
            
            // ⭐ JOIN TO INSPECTION CODES TABLE (consistent with Fact_LaborJobSummary)
            JoinInspectionCodes = Table.NestedJoin(
                Source,
                {"JobCode"},
                InspectionCodes,
                {"job_code"},
                "InspectionMatch",
                JoinKind.Inner
            ),
            
            // Remove the match column (we only needed it for filtering)
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
            
            // ⭐ CRITICAL: Convert to TEXT type to prevent SQL overflow
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
    // STEP 3: LOAD PARTS TRANSACTIONS FROM RAW_INTRANS
    // ========================================================================
    /*
    SOURCE: Raw_InTrans (6 years of parts transaction history)
    KEY FIELD: RONumber = Invoice Number (not work order number!)
    NOTE: Raw_InTrans.RONumber is actually REF_NO in the source system
    */
    
    PartsSource = Raw_InTrans,
    
    // ⭐ CRITICAL: Ensure join columns are TEXT type
    PartsWithTextTypes = Table.TransformColumnTypes(
        PartsSource,
        {
            {"Branch", type text},
            {"RONumber", type text}  // RONumber = Invoice Number in InTrans
        }
    ),
    
    // ========================================================================
    // STEP 4: FILTER TO INSPECTION INVOICES
    // ========================================================================
    /*
    JOIN TYPE: INNER JOIN on Invoice Number
    JOIN KEYS: Branch + Invoice Number (both TEXT type)
    RESULT: Only parts from invoices linked to inspection work orders
    */
    
    FilterToInspectionInvoices = Table.NestedJoin(
        PartsWithTextTypes,
        {"Branch", "RONumber"},           // InTrans: Branch + Invoice
        InspectionInvoices,
        {"Branch", "InvoiceNumber"},      // Join on InvoiceNumber
        "InspectionMatch",
        JoinKind.Inner
    ),
    
    RemoveMatchTable = Table.RemoveColumns(FilterToInspectionInvoices, {"InspectionMatch"}),
    
    // ========================================================================
    // STEP 5: KEEP ALL FRANCHISE CODES (INCLUDING ZP FOR DISCOUNTS)
    // ========================================================================
    /*
    ⭐ CRITICAL CHANGE: Do NOT filter out ZP franchise
    REASON: Discount parts (ADV, LEGACY, 4900, *10PROMO) are in ZP franchise
    STRATEGY: Filter in DAX measures, not here
    
    Real Parts: Use Franchise <> "ZP" in DAX
    Discounts: Use Franchise = "ZP" (or just filter by part number) in DAX
    */
    
    // OLD CODE (REMOVED):
    // ApplyBusinessRules = Table.SelectRows(
    //     RemoveMatchTable,
    //     each [Franchise] <> "ZP"
    // ),
    
    // NEW CODE: Keep all records
    KeepAllFranchises = RemoveMatchTable,
    
    // ========================================================================
    // STEP 6: REMOVE UNUSED COLUMNS
    // ========================================================================
    
    RemoveUnusedColumns = Table.RemoveColumns(
        KeepAllFranchises,
        {"JobCode", "JobType"}
    ),
    
    // ========================================================================
    // STEP 7: RENAME COLUMNS FOR CONSISTENCY
    // ========================================================================
    /*
    NOTE: RONumber in InTrans is actually Invoice Number
    Renamed to InvoiceNumber for clarity and consistency
    */
    
    RenameColumns = Table.RenameColumns(
        RemoveUnusedColumns,
        {
            {"Branch", "BranchCode"},
            {"RONumber", "InvoiceNumber"},
            {"TransDatetime", "TransactionDate"},
            {"PartNumber", "PartNumber"},
            {"Description", "Description"},
            {"Franchise", "Franchise"},
            {"Qty", "Quantity"},
            {"SaleValue", "SaleValue"},
            {"CostValue", "CostValue"},
            {"SellPrice1", "SellPrice"},
            {"ListPrice", "ListPrice"},
            {"CustomerNo", "CustomerNumber"},
            {"TradeType", "TradeType"},
            {"ModifiedDate", "ModifiedDate"}
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
            {"TransactionDate", type datetime},
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
  #"Calculated date" = Table.TransformColumns(SetDataTypes, {{"TransactionDate", each DateTime.Date(_), type nullable date}})
in
    #"Calculated date"

/*
============================================================================
✅ FACT_WORKORDERPARTS - UPDATED FOR DISCOUNT TRACKING
============================================================================

🎯 KEY UPDATES APPLIED:

1. **Complete Inspection Code List (111 codes)**
   - Replaced simplified pattern matching with complete embedded list
   - Matches Fact_LaborJobSummary exactly
   - Ensures consistency between parts and labor metrics

2. **Franchise Filter Removed**
   - KEEPS all franchises including ZP
   - Discount parts (ADV, LEGACY, 4900, *10PROMO) are in ZP franchise
   - Filter in DAX measures for flexibility:
     * Real Parts: Franchise <> "ZP"
     * Discounts: No franchise filter (or Franchise = "ZP")

3. **Improved Join Logic**
   - Uses table join to InspectionCodes (more maintainable)
   - Consistent with Fact_LaborJobSummary architecture
   - Single source of truth for inspection identification

📊 EXPECTED RESULTS:

**Row Count:**
- Previous (with ZP filter): Lower row count, missing discounts
- Updated (no ZP filter): Higher row count, includes all parts AND discounts
- Typical: 100,000-500,000 rows depending on date range

**Parts $ Total (Franchise <> "ZP, excluding discount parts):**
- ~$5.7M for date range 12/1/2024 - 11/3/2025
- Matches ValidInvoiceNumbers filtering

**Discount Totals (Franchise = "ZP" or by PartNumber):**
- ADV Discount (ADV, LEGACY): Should return negative values
- Trucking Discount (4900): Should return negative values
- Parts Discount (*10PROMO): Should return negative values

🔍 VALIDATION CHECKLIST:

□ Row count increased after removing ZP filter (confirms discounts included)
□ Parts $ Total ~$5.7M (using ValidInvoiceNumbers + Franchise <> "ZP")
□ ADV Discount measure returns negative number (not blank)
□ Trucking Discount measure returns negative number (not blank)
□ Parts Discount measure returns negative number (not blank)
□ Test with WO 661073: Should show 27 parts transactions

🚀 DAX MEASURES TO USE WITH THIS TABLE:

// Real Parts Revenue (exclude ZP and discount parts)
Parts $ Total = 
CALCULATE(
    SUM(Fact_WorkOrderParts[SaleValue]),
    Fact_WorkOrderParts[InvoiceNumber] IN VALUES(ValidInvoiceNumbers[InvoiceNumber]),
    Fact_WorkOrderParts[Franchise] <> "ZP",
    NOT(Fact_WorkOrderParts[PartNumber] IN {"ADV", "LEGACY", "4900", "*10PROMO"})
)

// Discount Measures (include ZP, filter by part number)
ADV Discount = 
CALCULATE(
    SUM(Fact_WorkOrderParts[SaleValue]),
    Fact_WorkOrderParts[InvoiceNumber] IN VALUES(ValidInvoiceNumbers[InvoiceNumber]),
    Fact_WorkOrderParts[PartNumber] IN {"ADV", "LEGACY"}
)

Trucking Discount = 
CALCULATE(
    SUM(Fact_WorkOrderParts[SaleValue]),
    Fact_WorkOrderParts[InvoiceNumber] IN VALUES(ValidInvoiceNumbers[InvoiceNumber]),
    Fact_WorkOrderParts[PartNumber] = "4900"
)

Parts Discount = 
CALCULATE(
    SUM(Fact_WorkOrderParts[SaleValue]),
    Fact_WorkOrderParts[InvoiceNumber] IN VALUES(ValidInvoiceNumbers[InvoiceNumber]),
    Fact_WorkOrderParts[PartNumber] = "*10PROMO"
)

🔄 MAINTENANCE NOTES:

**When New Inspection Codes Are Added:**
1. Update InspectionCodes table in this query (Step 1)
2. Update InspectionCodes table in Fact_LaborJobSummary
3. Update JobCodes DAX table in Power BI (if used)
4. Refresh both tables
5. Validate counts match

**When New Discount Part Numbers Are Added:**
1. Add to NOT() filter in Parts $ Total measure
2. Create new discount measure if needed
3. Update Total Discount % calculation

============================================================================
*/