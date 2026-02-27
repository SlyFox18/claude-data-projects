/*
============================================================================
RAW_PARTS_INTERBRANCHTRANSFERS - OUTSTANDING INTER-BRANCH TRANSFER ORDERS
============================================================================

📋 TABLE OVERVIEW:
Purpose:    Tracks the status of inter-branch parts transfer orders including
            quantities ordered, shipped, and still in transit.
            Primary source for Page 3 (Outstanding Transfers) of the Transfers report.
Grain:      One row per transfer order line (PartTicket + PartNumber assumed)
Source:     ODBC: dsn=EquipRDB64, table: Parts_InterbranchTransfers
Lakehouse:  LH_Master_Data → Parts_InterbranchTransfers
Dataflow:   df_Raw_Parts_InterbranchTransfers  (Phase 1 — Raw Sources)

⚠️ OUTSTANDING TRANSFER LOGIC:
  The table contains ALL transfer orders, including completed ones.
  OrderAge of 3,945 days was observed in the TOP 1 sample row, confirming
  the table retains full history (not just open records).

  To identify OUTSTANDING transfers:
  • Filter WHERE InTransitQuantity > 0
  • InTransitQuantity = OrderQuantity - ShippedQuantity (implied)
  • If InTransitQuantity = 0, the transfer is complete regardless of OrderAge

🔗 COLUMN REFERENCE:
  Source Column         Lakehouse Column
  ─────────────────     ─────────────────
  SupplyingBranch    →  SupplyingBranch   (branch sending the parts)
  RequestingBranch   →  RequestingBranch  (branch requesting the parts)
  PartTicket         →  PartTicket        (transfer order/ticket number)
  OrderQuantity      →  OrderQuantity     (quantity originally requested)
  ShippedQuantity    →  ShippedQuantity   (quantity fulfilled so far)
  InTransitQuantity  →  InTransitQuantity (quantity still outstanding)
  OrderAge           →  OrderAge          (days since order was placed)

❓ OPEN QUESTIONS FOR PHASE 2 INVESTIGATION:
  • Does this table contain PartNumber? The TOP 1 * query did not return one —
    if not, joining to dim_Parts for part detail on Page 3 is not possible
    without linking to InTrans via PartTicket → FileNo or RONumber.
  • What is the join key between Parts_InterbranchTransfers and InTrans_Incremental?
    Candidate: PartTicket ↔ FileNo or RONumber in InTrans.
  • Is PartTicket unique per row, or is grain PartTicket + PartNumber?

📊 REPORT PAGE SUPPORTED:
  • Page 3 — Outstanding Transfers: Filter to InTransitQuantity > 0

============================================================================
*/

let
    Source = Odbc.Query(
        "dsn=EquipRDB64",
        "SELECT
            SupplyingBranch,
            RequestingBranch,
            PartTicket,
            OrderQuantity,
            ShippedQuantity,
            InTransitQuantity,
            OrderAge
        FROM Parts_InterbranchTransfers"
    ),

    // ========================================================================
    // STEP 1: RENAME TO PASCALCASE
    // ========================================================================
    /*
    PURPOSE: Source column names are already PascalCase — no renaming needed.
    Confirming types and standardizing for Lakehouse Delta compatibility.
    Delta tables reject column names with spaces; none present here.
    */

    // ========================================================================
    // STEP 2: CLEAN BRANCH COLUMNS
    // ========================================================================
    /*
    PURPOSE: Null-safe trim of branch identifiers.
    Note: Sub-branch codes (e.g., "8I", "13I") are valid — do not strip letters.
    */

    CleanBranches = Table.TransformColumns(Source, {
        {"SupplyingBranch",   each if _ = null then null else Text.Trim(Text.From(_)), type text},
        {"RequestingBranch",  each if _ = null then null else Text.Trim(Text.From(_)), type text}
    }),

    // ========================================================================
    // STEP 3: SET FINAL DATA TYPES
    // ========================================================================

    FinalTypes = Table.TransformColumnTypes(CleanBranches, {
        {"SupplyingBranch",   type text},
        {"RequestingBranch",  type text},
        {"PartTicket",        Int64.Type},
        {"OrderQuantity",     type number},
        {"ShippedQuantity",   type number},
        {"InTransitQuantity", type number},
        {"OrderAge",          type number}
    })

in
    FinalTypes

/*
============================================================================
📋 DEPLOYMENT NOTES
============================================================================

This table does not yet exist in the Lakehouse. Steps to add:

1. Add this dataflow (df_Raw_Parts_InterbranchTransfers) to the
   "01 - Raw Sources" group in LH_Master_Data

2. Configure output to Lakehouse table: Parts_InterbranchTransfers

3. Add to Phase 1 of the master pipeline (parallel with other raw tables)

4. Before building Page 3, investigate the open questions above —
   specifically whether PartNumber is available and what the join key
   to InTrans_Incremental is.

============================================================================
*/
