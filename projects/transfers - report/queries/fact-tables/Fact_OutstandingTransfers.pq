/*
============================================================================
FACT_OUTSTANDINGTRANSFERS - OPEN INTER-BRANCH TRANSFER ORDERS
============================================================================

📋 TABLE OVERVIEW:
Purpose:    Tracks inter-branch parts transfer orders that have not yet been
            fully fulfilled (OpenQty > 0). Each row represents the receiving
            branch's perspective on a single outstanding transfer part line.
            Supports Page 3 (Outstanding Transfers) of the Transfers report.
Grain:      One row per outstanding transfer part line (positive-Qty side only)
Date Range: 2023-01-01 to current
Source:     InTrans_Incremental (Lakehouse table, LH_Master_Data)
Dataflow:   df_Fact_OutstandingTransfers

🎯 KEY BUSINESS LOGIC:

ROW SELECTION — TWO FILTERS APPLIED:
  1. Qty > 0 (receiving/requesting branch perspective)
     Each transfer creates TWO paired rows in InTrans per part:
       • +Qty at receiving branch ("Trf. from X/D/...")  ← KEEP this row
       • -Qty at sending branch   ("Trf. to X/D/...")    ← excluded by Qty > 0
     Keeping only the positive row:
       a) Avoids double-counting (one row per transfer line)
       b) Correctly identifies RequestingBranch (Branch col on positive row)
          and SupplyingBranch (TransferBranch col on positive row)

  2. OrderQty > ShippedQty (unfulfilled)
     Rows where all parts have shipped (OrderQty = ShippedQty) are complete
     and excluded. Only open/in-transit transfer lines are retained.

NULL FULFILLMENT EXCLUSION:
  Rows where OrderQty or ShippedQty is NULL have no quantity tracking and
  cannot be assessed for fulfillment status. These are excluded (~6,000 rows
  in 2023+ data, concentrated in 2023, all have PartLineStatus = null).
  They should NOT be treated as outstanding — they are untracked.

🔍 PARTLINESTATUS — WHY IT IS NOT USED HERE:
  PartLineStatus stores a numeric LINE-TYPE code (11, 12, 13, 14...),
  NOT a fulfillment status. Validated 2026-02-27: the same numeric codes
  appear in both outstanding and completed transfers:
    • Status 11: 492 outstanding rows vs 165,550 completed rows
    • Status 12: 114 outstanding rows vs  27,854 completed rows
  PartLineStatus cannot be used to identify open transfers.
  OrderQty > ShippedQty is the correct and only reliable filter.

🔀 TRANSFER SUB-TYPE CLASSIFICATION (same logic as Fact_Transfers):
  • SoRoRef null or < 100,000       → "Stock"      (replenishment)
  • 100,000 – 999,999  (6 digits)   → "Work Order" (Repair Order demand)
  • 1,000,000 – 9,999,999 (7 digits) → "Counter"   (Sales Order demand)
  • ≥ 10,000,000                    → "Unknown"    (future-proof)

🚫 BRANCH 12 EXCLUSION:
  Same as Fact_Transfers — any record where either RequestingBranch or
  SupplyingBranch starts with "12" is excluded. Text.StartsWith("12")
  catches all sub-variants (12I, 12S, etc.).

📊 COMPUTED COLUMNS:
  • OpenQty = OrderQty - ShippedQty (parts still in transit / not yet shipped)

🔗 DIMENSIONAL RELATIONSHIPS:
  • Fact_OutstandingTransfers[DateKey]           → dim_DateTable[DateKey]        (Many-to-One)
  • Fact_OutstandingTransfers[RequestingBranch]  → dim_BranchLocation[BranchID]  (Many-to-One)
  • Fact_OutstandingTransfers[SupplyingBranch]   → dim_BranchLocation[BranchID]  (Many-to-One)
  • Fact_OutstandingTransfers[PartNumber]        → dim_Parts[PartNumber]          (Many-to-One)

📊 REPORT PAGES SUPPORTED:
  • Page 3 — Outstanding Transfers:
      No date filter needed — all rows are outstanding by definition.
      Slice by RequestingBranch, SupplyingBranch, TransferSubType.
      Transfer age is a DAX measure: DATEDIFF([Date], TODAY(), DAY)

📈 KEY DAX MEASURES (suggested):
  • Outstanding Lines  = COUNTROWS(Fact_OutstandingTransfers)
  • Open Qty          = SUM(Fact_OutstandingTransfers[OpenQty])
  • Avg Age (Days)    = AVERAGEX(Fact_OutstandingTransfers,
                          DATEDIFF([Date], TODAY(), DAY))
  • Oldest Transfer   = DATEDIFF(MIN([Date]), TODAY(), DAY)

============================================================================
*/

let
    // ========================================================================
    // STEP 1: LOAD SOURCE TABLE FROM LAKEHOUSE
    // ========================================================================
    /*
    Same source as Fact_Transfers. 10M+ rows — all types and dates.
    Refreshed daily by Phase 2 (InTrans incremental) of the master pipeline.
    */

    Source = InTrans_Incremental,

    // ========================================================================
    // STEP 2: FILTER TO DATE RANGE
    // ========================================================================
    /*
    2023-01-01 forward — consistent with Fact_Transfers date range.
    Pre-2023 data has less consistent OrderQty/ShippedQty population and
    is unlikely to have genuinely outstanding transfers at this point.
    */

    FilterDates = Table.SelectRows(Source, each
        [TransDatetime] >= #datetime(2023, 1, 1, 0, 0, 0)
    ),

    // ========================================================================
    // STEP 3: FILTER TO TRANSFERS — RECEIVING SIDE ONLY
    // ========================================================================
    /*
    Type = "T": transfers only (no invoices, credits, purchases).
    Qty > 0:    keeps only the receiving branch row (positive quantity).
                Each transfer creates a paired +Qty / -Qty row in InTrans.
                The positive row identifies:
                  Branch         = RequestingBranch (receiving party)
                  TransferBranch = SupplyingBranch  (sending party)
    */

    FilterReceivingSide = Table.SelectRows(FilterDates, each
        [Type] = "T" and [Qty] > 0
    ),

    // ========================================================================
    // STEP 4: FILTER TO OUTSTANDING ONLY
    // ========================================================================
    /*
    OrderQty > ShippedQty → transfer is partially or fully unfulfilled.
    Rows with NULL OrderQty or ShippedQty are excluded — no tracking data,
    cannot be assessed for fulfillment. These are NOT treated as outstanding.
    */

    FilterOutstanding = Table.SelectRows(FilterReceivingSide, each
        [OrderQty] <> null and
        [ShippedQty] <> null and
        [OrderQty] > [ShippedQty]
    ),

    // ========================================================================
    // STEP 5: EXCLUDE BRANCH 12 (SUPPLY LOCATION)
    // ========================================================================
    /*
    Same exclusion logic as Fact_Transfers.
    Branch 12 (O'Donnell) is a supply/warehouse location covered by the
    Combine Vault Sales report. Text.StartsWith("12") catches all sub-branches.
    Null-safe: Text.From([col] ?? "") converts null → "" before check.
    */

    FilterBranch12 = Table.SelectRows(FilterOutstanding, each
        not Text.StartsWith(Text.From([Branch]         ?? ""), "12") and
        not Text.StartsWith(Text.From([TransferBranch] ?? ""), "12")
    ),

    // ========================================================================
    // STEP 6: SELECT ESSENTIAL COLUMNS
    // ========================================================================
    /*
    Note: Type is excluded — this table is Type = "T" only by definition.
    Note: Qty and CostValue are excluded — OpenQty (computed below) is the
          relevant measure. CostValue not available on outstanding transfers
          in a meaningful way (transfer cost flows through Fact_Transfers).
    Note: SoRoRef is included here only to derive TransferSubType (Step 9).
    */

    SelectColumns = Table.SelectColumns(FilterBranch12, {
        // === TRANSACTION IDENTIFICATION ===
        "TransId",              // Natural grain key — unique per transaction
        "TransDatetime",        // Transaction timestamp (used for DateKey + age)
        "RONumber",             // Reference number

        // === LOCATION (positive-Qty row: Branch = requester, TransferBranch = supplier) ===
        "Branch",               // RequestingBranch — renamed in Step 7
        "TransferBranch",       // SupplyingBranch  — renamed in Step 7

        // === PART ===
        "PartNumber",           // Part number — joins to dim_Parts
        "Franchise",            // Manufacturer/brand code

        // === FULFILLMENT MEASURES ===
        "OrderQty",             // Quantity originally requested
        "ShippedQty",           // Quantity fulfilled so far

        // === CLASSIFICATION INPUT ===
        "SoRoRef",              // SO/RO reference — used to derive TransferSubType; dropped after

        // === CONTEXT ===
        "OrderSalesman"         // Who initiated the transfer
    }),

    // ========================================================================
    // STEP 7: RENAME BRANCH COLUMNS FOR CLARITY
    // ========================================================================
    /*
    On the positive-Qty (receiving) rows:
      Branch         = the branch REQUESTING parts (destination of transfer)
      TransferBranch = the branch SUPPLYING parts  (origin of transfer)
    Renaming makes the direction explicit in the semantic model and report.
    */

    RenameBranches = Table.RenameColumns(SelectColumns, {
        {"Branch",         "RequestingBranch"},
        {"TransferBranch", "SupplyingBranch"}
    }),

    // ========================================================================
    // STEP 8: CLEAN TEXT FIELDS
    // ========================================================================
    /*
    Branch codes (e.g., "8I", "95I", "93C") are valid sub-branch identifiers
    — do NOT strip letters. Apply null-safe trim only.
    */

    CleanText = Table.TransformColumns(RenameBranches, {
        {"RequestingBranch", each if _ = null then null else Text.Trim(Text.From(_)), type text},
        {"SupplyingBranch",  each if _ = null then null else Text.Trim(Text.From(_)), type text},
        {"PartNumber",       each Text.Upper(Text.Trim(Text.From(_ ?? ""))),          type text},
        {"Franchise",        each Text.Upper(Text.Trim(Text.From(_ ?? ""))),          type text},
        {"RONumber",         each Text.Upper(Text.Trim(Text.From(_ ?? ""))),          type text},
        {"OrderSalesman",    each Text.Upper(Text.Trim(Text.From(_ ?? ""))),          type text}
    }),

    // ========================================================================
    // STEP 9: ADD TRANSFER SUB-TYPE CLASSIFICATION
    // ========================================================================
    /*
    Identical logic to Fact_Transfers Step 7.
    Classifies the transfer by what triggered it (work order demand,
    counter/sales order demand, or stock replenishment).

    CLASSIFICATION LOGIC (numeric range):
      • SoRoRef null or < 100,000       → "Stock"
      • 100,000 – 999,999  (6 digits)   → "Work Order"
      • 1,000,000 – 9,999,999 (7 digits) → "Counter"
      • ≥ 10,000,000                    → "Unknown"
    */

    AddTransferSubType = Table.AddColumn(CleanText, "TransferSubType", each
        let
            rawRef = [SoRoRef],
            numRef = if rawRef = null then null
                     else try Number.From(Text.Trim(Text.From(rawRef))) otherwise null
        in
            if numRef = null or numRef < 100000 then "Stock"
            else if numRef <= 999999   then "Work Order"
            else if numRef <= 9999999  then "Counter"
            else "Unknown",
        type text
    ),

    // ========================================================================
    // STEP 10: DROP CLASSIFICATION INPUT COLUMN
    // ========================================================================

    DropSoRoRef = Table.RemoveColumns(AddTransferSubType, {"SoRoRef"}),

    // ========================================================================
    // STEP 11: ADD OPEN QTY (PARTS STILL IN TRANSIT)
    // ========================================================================
    /*
    OpenQty = the quantity not yet shipped. This is the key fulfillment gap.
    By definition > 0 for all rows in this table (filtered in Step 4).
    */

    AddOpenQty = Table.AddColumn(DropSoRoRef, "OpenQty", each
        [OrderQty] - [ShippedQty],
        type number
    ),

    // ========================================================================
    // STEP 12: ADD DATE KEY AND DATE
    // ========================================================================
    /*
    DateKey (YYYYMMDD integer) for relationship to dim_DateTable.
    Date (date) as a convenience field for DAX age calculations.
    Pattern consistent with all other fact tables in this data model.
    */

    AddDateKey = Table.AddColumn(AddOpenQty, "DateKey", each
        let
            txDate = DateTime.Date([TransDatetime])
        in
            Date.Year(txDate) * 10000 + Date.Month(txDate) * 100 + Date.Day(txDate),
        Int64.Type
    ),

    AddDate = Table.AddColumn(AddDateKey, "Date", each
        DateTime.Date([TransDatetime]),
        type date
    ),

    // ========================================================================
    // STEP 13: REORDER COLUMNS
    // ========================================================================
    /*
    ORDER: Keys → Identifiers → Location → Part → Classification → Fulfillment → Context
    */

    ReorderColumns = Table.ReorderColumns(AddDate, {
        // ===== DIMENSION KEYS =====
        "DateKey",              // → dim_DateTable
        "Date",                 // Convenience date field (for DAX age: DATEDIFF([Date], TODAY(), DAY))

        // ===== TRANSACTION IDENTIFICATION =====
        "TransId",              // Natural key — links back to Fact_Transfers if needed
        "TransDatetime",        // Full timestamp
        "RONumber",             // Reference number

        // ===== LOCATION =====
        "RequestingBranch",     // Branch receiving parts → dim_BranchLocation[BranchID]
        "SupplyingBranch",      // Branch sending parts  → dim_BranchLocation[BranchID]

        // ===== PART =====
        "PartNumber",           // → dim_Parts (description, category available via join)
        "Franchise",            // Manufacturer code

        // ===== CLASSIFICATION =====
        "TransferSubType",      // Work Order / Counter / Stock

        // ===== FULFILLMENT =====
        "OrderQty",             // Originally requested
        "ShippedQty",           // Fulfilled so far
        "OpenQty",              // Still outstanding (OrderQty - ShippedQty)

        // ===== CONTEXT =====
        "OrderSalesman"         // Initiator / salesperson
    }),

    // ========================================================================
    // STEP 14: FINAL DATA TYPES
    // ========================================================================

    FinalTypes = Table.TransformColumnTypes(ReorderColumns, {
        // Keys
        {"DateKey",          Int64.Type},
        {"Date",             type date},

        // Transaction identification
        {"TransId",          Int64.Type},
        {"TransDatetime",    type datetime},
        {"RONumber",         type text},

        // Location
        {"RequestingBranch", type text},
        {"SupplyingBranch",  type text},

        // Part
        {"PartNumber",       type text},
        {"Franchise",        type text},

        // Classification
        {"TransferSubType",  type text},

        // Fulfillment
        {"OrderQty",         type number},
        {"ShippedQty",       type number},
        {"OpenQty",          type number},

        // Context
        {"OrderSalesman",    type text}
    })

in
    FinalTypes

/*
============================================================================
✅ FACT_OUTSTANDINGTRANSFERS — VALIDATION CHECKLIST
============================================================================

After deploying df_Fact_OutstandingTransfers, validate with these checks:

1. ROW COUNT (spot-check against stakeholder-known values):
   Total outstanding lines: COUNTROWS(Fact_OutstandingTransfers)
   Total open qty:          SUM(Fact_OutstandingTransfers[OpenQty])
   Compare against a known open transfer ticket from the source system.

2. NO COMPLETED TRANSFERS INCLUDED:
   MIN(OpenQty) should be 1 or greater — never 0 or negative.
   If any OpenQty = 0 exists, the Step 4 filter has a gap.

3. POSITIVE QTY ONLY (no negative rows):
   MIN(OrderQty) > 0 and MIN(ShippedQty) >= 0.
   No negative ShippedQty should exist.

4. BRANCH 12 EXCLUSION:
   FILTER(Fact_OutstandingTransfers, LEFT([RequestingBranch], 2) = "12")
   → Must return zero rows. Same check on SupplyingBranch.

5. TRANSFER SUB-TYPE DISTRIBUTION:
   Matrix: TransferSubType vs COUNTROWS
   Confirm Work Order, Counter, and Stock are all present.
   "Unknown" should be zero or near-zero rows.

6. DATE RANGE:
   MIN(Date) = 2023 or later.
   MAX(Date) = today or yesterday (confirms incremental data is flowing).

7. CROSS-CHECK WITH FACT_TRANSFERS:
   Outstanding transfers should exist in Fact_Transfers (same TransId).
   SELECT TransId FROM Fact_OutstandingTransfers
   should all appear in Fact_Transfers with Type = "T".

8. STAKEHOLDER SPOT-CHECK:
   Pull a specific PartNumber + RequestingBranch combination that a
   stakeholder knows is outstanding. Confirm it appears here with the
   correct OpenQty.

============================================================================
*/
