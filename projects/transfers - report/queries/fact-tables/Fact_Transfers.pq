/*
============================================================================
FACT_TRANSFERS - INTER-BRANCH PARTS TRANSFER & TRANSACTION FACT TABLE
============================================================================

📋 TABLE OVERVIEW:
Purpose:    Tracks all inter-branch parts transfer activity and the broader
            transaction context (sales, purchases) used for proportion analysis.
            Supports Pages 1 and 2 of the Transfers report.
Grain:      One row per transaction (TransId is the natural key)
Date Range: 2023-01-01 to current (full calendar year 2023 forward)
Source:     InTrans_Incremental (Lakehouse table, LH_Master_Data)
Dataflow:   df_Fact_Transfers

🎯 KEY BUSINESS LOGIC:
• Type = "T"  → Transfer transaction (primary focus, Page 1)
• Type = "I"  → Invoice / counter sale
• Type = "C"  → Credit transaction
• Type = "P"  → Purchase from supplier
• ALL four types are included — Page 2 compares transfers against sales
  and purchases to contextualize transfer volume within overall activity.

🔀 TRANSFER SUB-TYPE CLASSIFICATION (Type = "T" rows only):
  Uses numeric range check (avoids text-conversion edge cases):
  • 100,000–999,999   (6 digits) → "Work Order"  (Repair Order # — service shop demand)
  • 1,000,000–9,999,999 (7 digits) → "Counter"   (Sales Order # — customer-facing demand)
  • Null/blank/zero              → "Stock"        (No reference — replenishment transfer)
  • Any other value              → "Unknown"      (Future-proofing; none expected in 2023+ data)

  VALIDATED: Pre-2023 data had 5-digit SoRoRef (legacy counter numbering).
  The system changed before our start date — latest 5-digit record: 7/11/2022.
  No 5-digit values exist in the 2023+ dataset.

🚫 BRANCH 12 EXCLUSION:
Branch 12 (O'Donnell) is a supply/warehouse location tracked separately in the
Combine Vault Sales report. It is excluded here so it does not skew branch-to-branch
transfer analysis. The exclusion applies to BOTH Branch and TransferBranch columns —
any record where either party is Branch 12 (including sub-branches 12I, 12S, etc.)
is removed. Text.StartsWith("12") catches all sub-branch variants cleanly.

⚠️ DATA QUALITY NOTES:
• OrderQty/ShippedQty NULLs: ~12% of Type T rows have NULL Order_Qty and
  Shipped_Qty. This is a source system behavior concentrated heavily in 2023
  (tracking improved significantly in 2024+). NULLs are retained as-is —
  do NOT default to 0 as that conflates "not tracked" with "zero ordered."
• Sub-branch identifiers: Branch values like "8I", "95I", "4I", "93C" are
  valid sub-branch codes (I = IS Shop, S = Set-Up Shop, C = CP Shop).
  These are defined in dim_BranchLocation[BranchID] and match correctly.

🔗 DIMENSIONAL RELATIONSHIPS:
• Fact_Transfers[DateKey]        → dim_DateTable[DateKey]          (Many-to-One)
• Fact_Transfers[Branch]         → dim_BranchLocation[BranchID]   (Many-to-One, "Source Branch")
• Fact_Transfers[TransferBranch] → dim_BranchLocation[BranchID]   (Many-to-One, "Destination Branch")
• Fact_Transfers[PartNumber]     → dim_Parts[PartNumber]           (Many-to-One)

📊 REPORT PAGES SUPPORTED:
• Page 1 — Transfer Activity by Branch:
    Filter to Type = "T", slice by TransferSubType, Branch, TransferBranch, Date
• Page 2 — Transfer vs. Context:
    All types; compare Type T measures against Type I+C (sales) and Type P (purchases)

📈 KEY DAX MEASURES (suggested):
• Transfer Qty     = SUM(Qty)       WHERE Type = "T"
• Transfer Lines   = COUNTROWS()    WHERE Type = "T"
• Transfer Cost $  = SUM(CostValue) WHERE Type = "T"
• Sales Qty        = SUM(Qty)       WHERE Type IN ("I","C")
• Purchase Qty     = SUM(Qty)       WHERE Type = "P"

============================================================================
*/

let
    // ========================================================================
    // STEP 1: LOAD SOURCE TABLE FROM LAKEHOUSE
    // ========================================================================
    /*
    PURPOSE: Reference InTrans_Incremental from the Lakehouse.
    Contains 10M+ rows across all types, branches, and dates.
    Refreshed daily by the Raw phase of the master pipeline.
    */

    Source = InTrans_Incremental,

    // ========================================================================
    // STEP 2: FILTER TO DATE RANGE
    // ========================================================================
    /*
    PURPOSE: Limit to 2023-01-01 forward per business requirements.
    NOTE: Pre-2023 data has different SoRoRef numbering patterns (5-digit
    counter orders) and less consistent OrderQty/ShippedQty population.
    Starting 2023 provides clean, consistent data for transfer classification.
    */

    FilterDates = Table.SelectRows(Source, each
        [TransDatetime] >= #datetime(2023, 1, 1, 0, 0, 0)
    ),

    // ========================================================================
    // STEP 3: FILTER TO RELEVANT TRANSACTION TYPES
    // ========================================================================
    /*
    PURPOSE: Keep only the four types needed for this report.
    • T = Transfers (Page 1 focus)
    • I = Invoices/Counter Sales (Page 2 context — sales comparison)
    • C = Credits (Page 2 context — paired with I for "sales" measures)
    • P = Purchases from supplier (Page 2 context — purchasing comparison)
    Other types (A = Adjustment, R = Return, etc.) are excluded as they are
    not relevant to the transfer analysis or the proportion comparisons.
    */

    FilterTypes = Table.SelectRows(FilterDates, each
        [Type] = "T" or [Type] = "I" or [Type] = "C" or [Type] = "P"
    ),

    // ========================================================================
    // STEP 4: EXCLUDE BRANCH 12 (SUPPLY LOCATION)
    // ========================================================================
    /*
    PURPOSE: Remove all records where Branch 12 (O'Donnell supply location) is
    either the source OR the destination of the transaction.

    BUSINESS REASON: Branch 12 is an internal supply/warehouse location covered
    by the separate Combine Vault Sales report. Including it here would skew
    branch-to-branch transfer metrics. Stakeholder-confirmed exclusion.

    FILTER LOGIC:
    • Text.StartsWith([Branch], "12")         catches: "12", "12I", "12S", etc.
    • Text.StartsWith([TransferBranch], "12") catches the same on the other side
    • No ambiguity risk — branch IDs only go to 97; no "120", "121" etc. exist.
    • Null-safe: Text.From([col] ?? "") converts null → "" before StartsWith check.
    */

    FilterBranch12 = Table.SelectRows(FilterTypes, each
        not Text.StartsWith(Text.From([Branch]         ?? ""), "12") and
        not Text.StartsWith(Text.From([TransferBranch] ?? ""), "12")
    ),

    // ========================================================================
    // STEP 5: SELECT ESSENTIAL COLUMNS
    // ========================================================================
    /*
    PURPOSE: Retain only columns needed for analysis.
    Columns excluded:
    • Description  — available via dim_Parts join
    • BillToAcc    — not used in current report design
    • CustomerNo   — not used in current report design
    • FileNo       — not used in current report design
    • RONumberNew  — not used in current report design
    • SpecialInst  — used for sub-type context only; raw value not needed
    • SoRoRef      — used to derive TransferSubType; raw value then removed
    */

    SelectColumns = Table.SelectColumns(FilterBranch12, {
        // === TRANSACTION IDENTIFICATION ===
        "TransId",              // Natural grain key — unique per transaction
        "TransDatetime",        // Transaction timestamp
        "RONumber",             // Reference number (RO/SO/PO)
        "Type",                 // Transaction type (T/I/C/P)

        // === BRANCH / LOCATION ===
        "Branch",               // Source branch (maps to dim_BranchLocation[BranchID])
        "TransferBranch",       // Destination branch (Type T rows only)

        // === PART ===
        "PartNumber",           // Part number — joins to dim_Parts
        "Franchise",            // Manufacturer/brand code

        // === MEASURES ===
        "Qty",                  // Transaction quantity
        "CostValue",            // Cost value of the transaction

        // === FULFILLMENT (for future outstanding transfer analysis) ===
        "OrderQty",             // Quantity ordered — NULLs expected (see notes above)
        "ShippedQty",           // Quantity shipped — NULLs expected (see notes above)

        // === CLASSIFICATION INPUT ===
        "SoRoRef",              // SO/RO reference — length drives TransferSubType

        // === CONTEXT ===
        "OrderSalesman"         // Who initiated the order/transfer
    }),

    // ========================================================================
    // STEP 6: CLEAN TEXT FIELDS
    // ========================================================================
    /*
    PURPOSE: Standardize text fields for consistent dimension matching.
    NOTE: Branch and TransferBranch are NOT stripped of letters — values like
    "8I", "95I", "93C" are valid sub-branch codes defined in dim_BranchLocation.
    Only null-safe trimming is applied.
    */

    CleanText = Table.TransformColumns(SelectColumns, {
        {"Branch",        each if _ = null then null else Text.Trim(Text.From(_)),    type text},
        {"TransferBranch",each if _ = null then null else Text.Trim(Text.From(_)),    type text},
        {"PartNumber",    each Text.Upper(Text.Trim(Text.From(_ ?? ""))),             type text},
        {"Franchise",     each Text.Upper(Text.Trim(Text.From(_ ?? ""))),             type text},
        {"Type",          each Text.Upper(Text.Trim(Text.From(_ ?? ""))),             type text},
        {"RONumber",      each Text.Upper(Text.Trim(Text.From(_ ?? ""))),             type text},
        {"OrderSalesman", each Text.Upper(Text.Trim(Text.From(_ ?? ""))),             type text}
    }),

    // ========================================================================
    // STEP 7: ADD TRANSFER SUB-TYPE CLASSIFICATION
    // ========================================================================
    /*
    PURPOSE: Classify Type = "T" transfers as Work Order, Counter, or Stock.

    CLASSIFICATION LOGIC (numeric range — avoids text conversion edge cases):
      • SoRoRef is null OR numeric value < 100,000 → "Stock"      (no valid RO/SO reference)
      • 100,000 ≤ SoRoRef ≤ 999,999  (6 digits)   → "Work Order" (Repair Order #)
      • 1,000,000 ≤ SoRoRef ≤ 9,999,999 (7 digits) → "Counter"   (Sales Order #)
      • Any other value (≥ 10,000,000)              → "Unknown"   (future-proof)
    Non-transfer types (I, C, P) receive null — classification not applicable.

    WHY < 100,000 CATCHES MORE THAN NULL:
    Source system uses 0 and 1 as placeholder values when no real RO/SO reference
    exists — functionally identical to null. Validated: SoRoRef = 0 (102 rows),
    SoRoRef = 1 (2 rows) in 2023+ data. Treating all values < 100,000 as Stock
    is more robust than checking null alone and handles any future placeholder values.

    WHY NUMERIC RANGE (not text length):
    SoRoRef may be stored as a numeric type in the Lakehouse. A numeric range
    check works correctly regardless of whether the value is text or numeric,
    avoiding text-conversion edge cases with whitespace or type rendering.

    VALIDATED: In the 2023+ dataset, only 6-digit (WO) and 7-digit (Counter)
    SoRoRef values exist. Latest 5-digit legacy record was 7/11/2022.
    "Unknown" should be zero rows after applying the < 100,000 Stock catch.
    */

    AddTransferSubType = Table.AddColumn(CleanText, "TransferSubType", each
        if [Type] <> "T" then null
        else
            let
                rawRef = [SoRoRef],
                // Safely convert to number — handles text, numeric, or null types
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
    // STEP 8: DROP CLASSIFICATION INPUT COLUMN
    // ========================================================================
    /*
    PURPOSE: SoRoRef was needed only to derive TransferSubType. Now that
    the column is calculated, remove it to keep the model lean.
    */

    DropSoRoRef = Table.RemoveColumns(AddTransferSubType, {"SoRoRef"}),

    // ========================================================================
    // STEP 9: ADD DATE KEY FOR DIM_DATETABLE RELATIONSHIP
    // ========================================================================
    /*
    PURPOSE: Generate integer DateKey (YYYYMMDD) for relationship to dim_DateTable.
    Pattern consistent with all other fact tables in this data model.
    */

    AddDateKey = Table.AddColumn(DropSoRoRef, "DateKey", each
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
    // STEP 10: REORDER COLUMNS
    // ========================================================================
    /*
    ORDER: Keys → Identifiers → Location → Part → Classification → Measures → Fulfillment → Context
    */

    ReorderColumns = Table.ReorderColumns(AddDate, {
        // ===== DIMENSION KEYS =====
        "DateKey",              // → dim_DateTable
        "Date",                 // Convenience date field

        // ===== TRANSACTION IDENTIFICATION =====
        "TransId",              // Natural key / grain
        "TransDatetime",        // Full timestamp
        "RONumber",             // Reference number

        // ===== LOCATION =====
        "Branch",               // Source branch → dim_BranchLocation[BranchID]
        "TransferBranch",       // Destination branch → dim_BranchLocation[BranchID]

        // ===== PART =====
        "PartNumber",           // → dim_Parts
        "Franchise",            // Manufacturer code

        // ===== CLASSIFICATION =====
        "Type",                 // T / I / C / P
        "TransferSubType",      // Work Order / Counter / Stock / null (non-T rows)

        // ===== MEASURES =====
        "Qty",                  // Transaction quantity
        "CostValue",            // Transaction cost value

        // ===== FULFILLMENT =====
        "OrderQty",             // Ordered qty (NULLs expected, esp. 2023 — see notes)
        "ShippedQty",           // Shipped qty (NULLs expected, esp. 2023 — see notes)

        // ===== CONTEXT =====
        "OrderSalesman"         // Salesperson / initiator
    }),

    // ========================================================================
    // STEP 11: FINAL DATA TYPES
    // ========================================================================

    FinalTypes = Table.TransformColumnTypes(ReorderColumns, {
        // Keys
        {"DateKey",         Int64.Type},
        {"Date",            type date},

        // Transaction identification
        {"TransId",         Int64.Type},
        {"TransDatetime",   type datetime},
        {"RONumber",        type text},

        // Location
        {"Branch",          type text},
        {"TransferBranch",  type text},

        // Part
        {"PartNumber",      type text},
        {"Franchise",       type text},

        // Classification
        {"Type",            type text},
        {"TransferSubType", type text},

        // Measures
        {"Qty",             type number},
        {"CostValue",       type number},

        // Fulfillment — intentionally nullable (NULLs = not tracked, not zero)
        {"OrderQty",        type number},
        {"ShippedQty",      type number},

        // Context
        {"OrderSalesman",   type text}
    })

in
    FinalTypes

/*
============================================================================
✅ FACT_TRANSFERS — VALIDATION CHECKLIST
============================================================================

After deploying df_Fact_Transfers, validate with these checks:

1. ROW COUNT (verify against source):
   SELECT TYPE, COUNT(*)
   FROM InTrans
   WHERE Trans_Datetime >= '2023-01-01'
     AND TYPE IN ('T','I','C','P')
   GROUP BY TYPE

2. TRANSFER SUB-TYPE DISTRIBUTION:
   Matrix: TransferSubType vs COUNT(rows)
   • Work Order and Counter should both be in the six-figure range
   • Stock should be present but smaller
   • "Unknown" should be ZERO rows (confirms no unexpected SoRoRef lengths)

3. BRANCH RELATIONSHIP:
   Sub-branch codes like "8I", "95I", "93C" will match dim_BranchLocation[BranchID].
   Check for unmatched (blank) branch rows — should be minimal.

4. NULL FULFILLMENT COLUMNS:
   OrderQty and ShippedQty are NULL for ~12% of Type T rows — EXPECTED.
   Heavily concentrated in 2023. Do NOT treat as a data error.

5. BRANCH 12 EXCLUSION:
   SELECT DISTINCT Branch FROM Fact_Transfers WHERE Branch LIKE '12%'
   → Must return zero rows. Same check on TransferBranch.

6. DATE RANGE:
   MIN(TransDatetime) = 2023-01-01 or later
   MAX(TransDatetime) = within last 24 hours (confirms incremental refresh)

============================================================================
*/
