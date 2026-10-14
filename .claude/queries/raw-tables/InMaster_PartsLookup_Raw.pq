/*
============================================================================
Query: InMaster_PartsLookup_Raw
Dataflow: df_InMaster_PartsLookup_Raw
Location: LH_Master_Data → Dataflows → 01 - Raw Sources
============================================================================

PURPOSE: Single-source cross-branch part lookup data for the Parts Lookup
Tool (Fabric App). Replaces the retired in-store Equip part-lookup utility.
Pulls only parts with a supplier/vendor code present — the exact business
rule for "which branches carry this part through a vendor."

GRAIN: One row per Branch + Franchise + PartNumber (VendorCode not null only).
Note: this is the weekly full-reconciliation path only as of 2026-08 — see
InMaster_PartsLookup_Incremental.pq for the 4x/day incremental path that
actually keeps PartLocations current.

SOURCE: SQL Anywhere (ODBC: EquipRDB64) — InMaster table

REFRESH: Full refresh. InMaster refreshes in ~3 minutes on average, much
faster than jdis_Part_Information (3x/day) — this table is not capped by
that schedule since it doesn't depend on jdis_Part_Information at all.

BIN QTY: InMaster has no direct bin-quantity column. Computed as
ON_HAND_QTY - Pending_Qty, validated 2026-07-15 at 99.94% exact match
(1,102,498 / 1,103,165 rows) against jdis_Part_Information's independently
tracked BinQty field. Brian has also used this formula for bin qty in
another existing report.

COMMENTS: Sourced from InMaster.NOTE (confirmed 2026-07-15 — not in
jdis_Part_Information, and not the undocumented user_field_1/user_field_2).

BRANCH EXCLUSION: Branches 5 and 97 excluded per Ben (stakeholder),
2026-07-15 — not relevant results for this tool's purpose. Filtered
at the source query, matching this repo's established convention for
branch/franchise exclusions (e.g. Transfers report's Branch 12
exclusion, Non-JD Order Tool's franchise exclusion) rather than
filtering client-side in the app, so any future consumer of this
table gets the same exclusion automatically.

DO NOT MODIFY the existing InMaster.pq / InMaster_Raw.pq raw pulls — this
is a separate, purpose-built table for this tool only.

ON ORDER: OS_ORDER_QTY AS OnOrder added 2026-08-04 (stakeholder testing
feedback). Must stay in sync with InMaster_PartsLookup_Incremental.pq's
column choice — this weekly full-Replace run would otherwise null out
onOrder for all ~1.05M live rows every time it runs.
============================================================================
*/

let
    SQL = "
        SELECT
            BRANCH          AS Branch,
            FRANCHISE       AS Franchise,
            PART_NO         AS PartNumber,
            PART_DESC       AS Description,
            BIN_LOCATION    AS Bin,
            SUPER_FROM      AS SuperFrom,
            SUPER_TO        AS SuperTo,
            VENDOR_CODE     AS VendorCode,
            SELL_PRICE1     AS SellPrice1,
            NOTE            AS Comments,
            ON_HAND_QTY     AS OnHandQty,
            Pending_Qty     AS PendingQty,
            OS_ORDER_QTY    AS OnOrder
        FROM InMaster
        WHERE VENDOR_CODE IS NOT NULL
          AND BRANCH NOT IN ('5', '97')
    ",

    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise
        error "Failed to connect to InMaster for Parts Lookup Tool. Verify ODBC connection and VENDOR_CODE column.",

    AddBinQty = Table.AddColumn(Source, "BinQty", each [OnHandQty] - [PendingQty], Int64.Type),

    TypedTable = Table.TransformColumnTypes(AddBinQty, {
        {"Branch", type text},
        {"Franchise", type text},
        {"PartNumber", type text},
        {"Description", type text},
        {"Bin", type text},
        {"SuperFrom", type text},
        {"SuperTo", type text},
        {"VendorCode", type text},
        {"SellPrice1", type number},
        {"Comments", type text},
        {"OnHandQty", Int64.Type},
        {"PendingQty", Int64.Type},
        {"OnOrder", Int64.Type},
        {"BinQty", Int64.Type}
    })
in
    TypedTable
