/*
============================================================================
Query: InMaster_PartsLookup_Incremental
Dataflow: df_InMaster_PartsLookup_Incremental
Location: LH_Master_Data → Dataflows → 01 - Raw Sources
============================================================================

PURPOSE: Incremental (watermark-filtered) companion to InMaster_PartsLookup_Raw
for the Parts Lookup Tool (Fabric App). Pulls only rows changed since the last
successful run instead of a full ~1.1M-row extract every time. Feeds
PartsLookup_Sync_Incremental → Merge_Staging_Incremental_To_Live, NOT the old
full-replace path.

GRAIN: One row per Branch + Franchise + PartNumber (all VendorCode values,
including null — filtering by VendorCode happens downstream in the merge step,
not here, because a newly-null VendorCode is exactly the signal that tells the
merge step to delete that row from PartLocations).

SOURCE: SQL Anywhere (ODBC: EquipRDB64) — InMaster table.

WATERMARK: Read from LH_Master_Data's `watermark_control` table, row
TableName = 'InMaster_PartsLookup'. Filters on Last_Upd_Datetime (NOT
ModifiedDate — see INCREMENTAL-REFRESH-FEASIBILITY.md for why: ModifiedDate
is 35.4% null / recently-added, Last_Upd_Datetime has 0 nulls and reflects
real transaction activity once correctly joined on the true composite key).
A 30-minute overlap margin is applied defensively, same spirit as
InTrans_Incremental's Table.Distinct dedup safety net.

ON ORDER: OS_ORDER_QTY ("Outstanding Order Quantity") is the on-order
quantity — confirmed against the full InMaster column list 2026-08-04, added
per stakeholder testing feedback. Distinct from BACK_ORD_QTY / BO_Qty
(customer backorders) and IN_TRANSIT_QTY (already shipped by vendor, not yet
received — a different signal). If this reading turns out wrong once live,
it's a one-column swap here (and in PartsLookup_Sync_Incremental.pq,
InMaster_PartsLookup_Raw.pq, PartsLookup_Sync.pq, and the merge script) —
not a redesign.

DO NOT MODIFY the existing InMaster.pq / InMaster_Raw.pq /
InMaster_PartsLookup_Raw.pq — those remain the full-refresh queries, now
used only for the weekly reconciliation pipeline (see ARCHITECTURE.md).

LAKEHOUSE ACCESS: uses explicit workspaceId/lakehouseId navigation, not a
bare Lakehouse.Contents(){[Name=...]} lookup — confirmed 2026-08-04 that the
bare form fails to resolve a table by name in a freshly created Dataflow
Gen2 query (threw "Failed to connect to InMaster..." — actually a watermark
read failure masked by this query's own try/otherwise around the ODBC call,
since SQL's evaluation depends on WatermarkText). Same explicit-GUID pattern
as the confirmed-working Fact_OpenOrderParts.pq.
============================================================================
*/

let
    // Step 1: Read the current watermark from the Lakehouse
    LH_Source    = Lakehouse.Contents([HierarchicalNavigation = null, EnableVorder = true, OutputMetadataRefresh = true]),
    LH_Workspace = LH_Source{[workspaceId = "b48cdb35-7ce3-46de-96df-d70db77649cb"]}[Data],
    LH_Lakehouse = LH_Workspace{[lakehouseId = "3e74497b-8c51-4a1a-91a1-888c59118f48"]}[Data],
    WatermarkTable = LH_Lakehouse{[Id = "watermark_control", ItemKind = "Table"]}[Data],
    FilterToThisTable = Table.SelectRows(WatermarkTable, each [TableName] = "InMaster_PartsLookup"),
    WatermarkRaw = FilterToThisTable{0}[LastLoadedDatetime],

    // Step 2: Defensive 30-minute overlap margin
    WatermarkWithOverlap = WatermarkRaw - #duration(0, 0, 30, 0),
    WatermarkText = DateTime.ToText(WatermarkWithOverlap, "yyyy-MM-dd HH:mm:ss"),

    // Step 3: Pull changed/new rows only. No VENDOR_CODE filter here — see header.
    SQL = "
        SELECT
            BRANCH            AS Branch,
            FRANCHISE         AS Franchise,
            PART_NO           AS PartNumber,
            PART_DESC         AS Description,
            BIN_LOCATION      AS Bin,
            SUPER_FROM        AS SuperFrom,
            SUPER_TO          AS SuperTo,
            VENDOR_CODE       AS VendorCode,
            SELL_PRICE1       AS SellPrice1,
            NOTE              AS Comments,
            ON_HAND_QTY       AS OnHandQty,
            Pending_Qty       AS PendingQty,
            OS_ORDER_QTY      AS OnOrder,
            Last_Upd_Datetime AS LastUpdDatetime
        FROM InMaster
        WHERE BRANCH NOT IN ('5', '97')
          AND Last_Upd_Datetime > '" & WatermarkText & "'
    ",

    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise
        error "Failed to connect to InMaster for Parts Lookup incremental pull. Verify ODBC connection, Last_Upd_Datetime column, and watermark_control row for 'InMaster_PartsLookup'.",

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
        {"BinQty", Int64.Type},
        {"LastUpdDatetime", type datetime}
    })
in
    TypedTable
