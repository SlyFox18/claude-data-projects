/*
============================================================================
FACT_OUTSTANDINGTRANSFERS - OPEN INTER-BRANCH TRANSFER ORDERS
============================================================================

📋 TABLE OVERVIEW:
Purpose:    Tracks inter-branch parts transfer orders that are currently
            outstanding. Each row represents one part line on one
            outstanding transfer ticket.
            Supports Page 3 (Outstanding Transfers) of the Transfers report.
Grain:      One row per outstanding part line (FILE_NO + Line_No from InSalPar)
Source:     TWO ODBC sources joined:
              1. Parts_InterbranchTransfers  — outstanding ticket validation,
                                               RequestingBranch, SupplyingBranch,
                                               OrderAge
              2. InSalPar                   — part-line detail (PartNumber,
                                               Franchise, quantities, dates)
Dataflow:   df_Fact_OutstandingTransfers

🎯 KEY DESIGN DECISION — SOURCE ARCHITECTURE:

  Parts_InterbranchTransfers is a VIEW (not a base table) built from InSalOrd
  WHERE type = 'T'. It has no PartNumber column — it is a ticket-level summary.

  InSalPar is the Parts Sales Order Details table. For transfer orders,
  FILE_NO = PartTicket (the transfer ticket number). Each FILE_NO has one
  row per part line, with PART_NO, FRANCHISE, ORDER_QTY, SHIPPED_QTY,
  SUPPLIED_QTY, and SO_RO_Ref.

  The correct OpenQty per line is:
    SHIPPED_QTY - SUPPLIED_QTY
    (shipped from supplying branch minus confirmed received at requesting branch)

  Parts_InterbranchTransfers is used ONLY for:
    • Authoritative outstanding filter (InTransitQuantity > 0 per ticket)
    • RequestingBranch (not available in InSalPar)
    • SupplyingBranch (validation cross-check)
    • OrderAge (pre-calculated by source system — days since transfer placed)

🔍 JOIN KEY VALIDATION (2026-03-03):
  InSalPar.FILE_NO = Parts_InterbranchTransfers.PartTicket — confirmed:
    PartTicket 1459307 → InSalPar FILE_NO 1459307:
      Line 1: PART_NO=961870,  ORDER_QTY=1, SHIPPED=1, SUPPLIED=0 → OpenQty=1
      Line 2: PART_NO=403279,  ORDER_QTY=2, SHIPPED=2, SUPPLIED=0 → OpenQty=2
  These exactly match the two Parts_InterbranchTransfers rows for PartTicket
  1459307 (InTransitQuantity 1 and 2).

  PREVIOUS APPROACH (WRONG — superseded 2026-03-03):
    Attempted join on InTrans.Trans_Id = PartTicket. This produced coincidental
    matches — InTrans.Trans_Id values are in the 13M+ range; PartTickets are in
    the 1M–2M range. Trans_Id values numerically overlapping PartTickets are
    completely unrelated transactions from 2014.
    InTrans.REF_NO = PartTicket is valid only for Type='T' rows, but InTrans is
    only populated AFTER parts ship — most outstanding transfers are pre-shipment
    and have no InTrans record. InSalPar is the correct and complete source.

📊 OUTSTANDING FILTER:
  InTransitQuantity > 0 from Parts_InterbranchTransfers identifies outstanding
  tickets. InSalPar.SHIPPED_QTY > InSalPar.SUPPLIED_QTY identifies the specific
  outstanding part lines within those tickets.

📊 COMPUTED COLUMNS:
  • OpenQty           = SHIPPED_QTY - SUPPLIED_QTY (per-line from InSalPar)
  • DateKey           = YYYYMMDD integer from InSalPar.Creation_Datetime
  • TransferSubType   = classified from InSalPar.SO_RO_Ref (same logic as
                        Fact_Transfers — Stock / Work Order / Counter / Unknown)
  • FulfillmentStatus = ORDER_QTY vs SHIPPED_QTY:
                        "Pending" — ShippedQty = 0 (nothing dispatched yet)
                        "Partial" — 0 < ShippedQty < OrderQty (partially dispatched)
                        "Shipped" — ShippedQty = OrderQty (fully dispatched, in transit)

🚫 BRANCH 12 EXCLUSION:
  Same as Fact_Transfers — records where either branch starts with "12"
  are excluded (O'Donnell supply location, covered by Combine Vault Sales).

🔗 DIMENSIONAL RELATIONSHIPS:
  • Fact_OutstandingTransfers[DateKey]           → dim_DateTable[DateKey]
  • Fact_OutstandingTransfers[RequestingBranch]  → dim_BranchLocation[BranchID]
  • Fact_OutstandingTransfers[SupplyingBranch]   → dim_BranchLocation[BranchID] (inactive)
  • Fact_OutstandingTransfers[PartNumber]        → dim_Parts[PartNumber]

📊 REPORT PAGES SUPPORTED:
  • Page 3 — Outstanding Transfers

============================================================================
*/

let
    // ========================================================================
    // STEP 1: LOAD OUTSTANDING TRANSFER TICKETS — CURRENT STATE
    // ========================================================================
    /*
    Parts_InterbranchTransfers is a VIEW on InSalOrd (Type='T' records only).
    InTransitQuantity > 0 is the authoritative outstanding filter.
    OrderAge (days since placed) is pre-calculated by the source system.
    This table has NO PartNumber — it is a ticket-level summary only.
    Multiple rows per PartTicket exist (one per part line); we GROUP to
    get one row per ticket for the header attributes used in the join.
    */

    OutstandingSource = Odbc.Query(
        "dsn=EquipRDB64",
        "SELECT
            PartTicket,
            RequestingBranch,
            SupplyingBranch,
            MAX(OrderAge) AS OrderAge
        FROM Parts_InterbranchTransfers
        WHERE InTransitQuantity > 0
        GROUP BY PartTicket, RequestingBranch, SupplyingBranch"
    ),

    // ========================================================================
    // STEP 2: LOAD PART-LINE DETAIL FROM InSalPar — ODBC DIRECT
    // ========================================================================
    /*
    InSalPar is the Parts Sales Order Details table.
    FILE_NO = the transfer ticket number (= PartTicket in Parts_InterbranchTransfers).
    One row per part line per transfer order.
    SHIPPED_QTY > SUPPLIED_QTY filters to lines still outstanding:
      SHIPPED_QTY  = quantity dispatched from supplying branch
      SUPPLIED_QTY = quantity confirmed received at requesting branch
    */

    TransferLines = Odbc.Query(
        "dsn=EquipRDB64",
        "SELECT
            FILE_NO           AS PartTicket,
            Line_No,
            PART_NO           AS PartNumber,
            ORDER_QTY,
            SHIPPED_QTY,
            SUPPLIED_QTY,
            SO_RO_Ref         AS SoRoRef,
            Creation_Datetime AS TransDatetime
        FROM InSalPar
        WHERE SHIPPED_QTY > SUPPLIED_QTY"
    ),

    // ========================================================================
    // STEP 3: EXCLUDE BRANCH 12
    // ========================================================================
    /*
    O'Donnell supply location — covered by Combine Vault Sales report.
    Text.StartsWith("12") catches all sub-branches (12I, 12S, etc.).
    Applied before the join to minimize rows processed.
    */

    FilterBranch12 = Table.SelectRows(OutstandingSource, each
        not Text.StartsWith(Text.From([RequestingBranch] ?? ""), "12") and
        not Text.StartsWith(Text.From([SupplyingBranch]  ?? ""), "12")
    ),

    // ========================================================================
    // STEP 4: JOIN TICKET HEADER TO PART LINES
    // ========================================================================
    /*
    LEFT JOIN from outstanding tickets to InSalPar lines.
    A ticket in Parts_InterbranchTransfers should always have corresponding
    InSalPar rows — the view is built from InSalOrd which InSalPar joins to.
    Left outer is defensive for data integrity only.
    */

    JoinDetail = Table.NestedJoin(
        FilterBranch12, "PartTicket",
        TransferLines,  "PartTicket",
        "LineDetail",
        JoinKind.LeftOuter
    ),

    ExpandDetail = Table.ExpandTableColumn(
        JoinDetail,
        "LineDetail",
        {"Line_No", "PartNumber", "ORDER_QTY", "SHIPPED_QTY",
         "SUPPLIED_QTY", "SoRoRef", "TransDatetime"}
    ),

    // ========================================================================
    // STEP 5: COMPUTE OpenQty PER LINE
    // ========================================================================
    /*
    OpenQty at the line level = SHIPPED_QTY - SUPPLIED_QTY.
    This is the per-part outstanding quantity for this specific part line.
    Parts_InterbranchTransfers.InTransitQuantity is a ticket-level total
    and is NOT used here — use per-line calculation instead.
    */

    AddOpenQty = Table.AddColumn(ExpandDetail, "OpenQty", each
        if [SHIPPED_QTY] = null or [SUPPLIED_QTY] = null then null
        else [SHIPPED_QTY] - [SUPPLIED_QTY],
        type number
    ),

    // ========================================================================
    // STEP 5.5: ADD FULFILLMENT STATUS
    // ========================================================================
    /*
    Classifies each part line by how much of the ordered quantity has shipped
    from the supplying branch (ORDER_QTY vs SHIPPED_QTY):

      • "Pending"  — nothing has shipped yet (ShippedQty = 0 or null)
      • "Partial"  — some qty has shipped but not all (0 < ShippedQty < OrderQty)
      • "Shipped"  — full order qty has shipped (ShippedQty = OrderQty)

    Note: all rows in this table already have SHIPPED_QTY > SUPPLIED_QTY
    (the InSalPar filter), meaning they are still outstanding at the
    requesting branch. "Shipped" here means fully dispatched but not yet
    confirmed received — it is still an outstanding transfer.

    Uses pre-rename column names (ORDER_QTY / SHIPPED_QTY) — rename
    to OrderQty / ShippedQty happens later in Step 9.
    */

    AddFulfillmentStatus = Table.AddColumn(AddOpenQty, "FulfillmentStatus", each
        if   [ORDER_QTY] = null or [SHIPPED_QTY] = null then "Pending"
        else if [ORDER_QTY] = [SHIPPED_QTY]              then "Shipped"
        else if [SHIPPED_QTY] > 0                        then "Partial"
        else                                                  "Pending",
        type text
    ),

    // ========================================================================
    // STEP 6: CLEAN TEXT FIELDS
    // ========================================================================
    /*
    Branch codes (e.g., "8I", "95I") are valid — do NOT strip letters.
    Null-safe trim only.
    */

    CleanText = Table.TransformColumns(AddFulfillmentStatus, {
        {"RequestingBranch", each if _ = null then null else Text.Trim(Text.From(_)), type text},
        {"SupplyingBranch",  each if _ = null then null else Text.Trim(Text.From(_)), type text},
        {"PartNumber",       each Text.Upper(Text.Trim(Text.From(_ ?? ""))),          type text}
    }),

    // ========================================================================
    // STEP 7: ADD TRANSFER SUB-TYPE CLASSIFICATION
    // ========================================================================
    /*
    Identical logic to Fact_Transfers.
    CLASSIFICATION (numeric range on SoRoRef):
      • null or < 100,000       → "Stock"      (replenishment)
      • 100,000 – 999,999       → "Work Order" (Repair Order demand)
      • 1,000,000 – 9,999,999   → "Counter"    (Sales Order demand)
      • ≥ 10,000,000            → "Unknown"
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

    DropSoRoRef = Table.RemoveColumns(AddTransferSubType, {"SoRoRef"}),

    // ========================================================================
    // STEP 8: ADD DATE KEY AND DATE
    // ========================================================================
    /*
    DateKey (YYYYMMDD integer) for relationship to dim_DateTable.
    Date (date) as a convenience field.
    TransDatetime = InSalPar.Creation_Datetime (when the transfer line was placed).
    */

    AddDateKey = Table.AddColumn(DropSoRoRef, "DateKey", each
        if [TransDatetime] = null then null
        else
            let txDate = DateTime.Date([TransDatetime])
            in Date.Year(txDate) * 10000 + Date.Month(txDate) * 100 + Date.Day(txDate),
        Int64.Type
    ),

    AddDate = Table.AddColumn(AddDateKey, "Date", each
        if [TransDatetime] = null then null
        else DateTime.Date([TransDatetime]),
        type date
    ),

    // ========================================================================
    // STEP 9: RENAME WORKING COLUMNS
    // ========================================================================

    RenameColumns = Table.RenameColumns(AddDate, {
        {"ORDER_QTY",    "OrderQty"},
        {"SHIPPED_QTY",  "ShippedQty"},
        {"SUPPLIED_QTY", "SuppliedQty"}
    }),

    // ========================================================================
    // STEP 10: REORDER COLUMNS
    // ========================================================================

    ReorderColumns = Table.ReorderColumns(RenameColumns, {
        "DateKey",
        "Date",
        "PartTicket",
        "Line_No",
        "TransDatetime",
        "RequestingBranch",
        "SupplyingBranch",
        "PartNumber",
        "TransferSubType",
        "FulfillmentStatus",
        "OrderQty",
        "ShippedQty",
        "SuppliedQty",
        "OpenQty",
        "OrderAge"
    }),

    // ========================================================================
    // STEP 11: FINAL DATA TYPES
    // ========================================================================

    FinalTypes = Table.TransformColumnTypes(ReorderColumns, {
        {"DateKey",            Int64.Type},
        {"Date",               type date},
        {"PartTicket",         Int64.Type},
        {"Line_No",            Int64.Type},
        {"TransDatetime",      type datetime},
        {"RequestingBranch",   type text},
        {"SupplyingBranch",    type text},
        {"PartNumber",         type text},
        {"TransferSubType",    type text},
        {"FulfillmentStatus",  type text},
        {"OrderQty",           type number},
        {"ShippedQty",         type number},
        {"SuppliedQty",        type number},
        {"OpenQty",            type number},
        {"OrderAge",           Int64.Type}
    })

in
    FinalTypes

/*
============================================================================
✅ FACT_OUTSTANDINGTRANSFERS — VALIDATION CHECKLIST
============================================================================

1. ROW COUNT:
   Expected: more rows than PartTickets (one per part line per ticket).
   Total depends on multi-line tickets. Cross-check:
   SELECT COUNT(*) FROM InSalPar ip
   INNER JOIN (SELECT DISTINCT PartTicket FROM Parts_InterbranchTransfers
               WHERE InTransitQuantity > 0) pit ON pit.PartTicket = ip.FILE_NO
   WHERE ip.SHIPPED_QTY > ip.SUPPLIED_QTY
   should match (minus Branch 12 exclusions).

2. PART NUMBER COVERAGE:
   Nearly 100% of rows should have PartNumber populated (InSalPar join).
   Any null PartNumber indicates a ticket with no matching InSalPar FILE_NO
   — investigate if found.

3. BRANCH 12 EXCLUSION:
   Filter rows where LEFT(RequestingBranch, 2) = "12" → must return 0 rows.
   Same check on SupplyingBranch.

4. OPENQTY ALL POSITIVE:
   MIN(OpenQty) > 0 by construction (SHIPPED_QTY > SUPPLIED_QTY filter).

5. ORDERAGE REASONABLENESS:
   MIN(OrderAge) >= 0.
   MAX(OrderAge) may be large (hundreds of days) — expected and correct.

6. TRANSFERSUBTYPE DISTRIBUTION:
   All three types (Work Order, Counter, Stock) should be present.
   "Unknown" should be 0 or near-zero.

7. DATE COVERAGE:
   MIN(Date) should reflect when the oldest outstanding transfer was placed.
   MAX(Date) should be recent (within the last few days).

============================================================================
*/
