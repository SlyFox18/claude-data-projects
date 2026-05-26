/*
============================================================================
Query: Fact_OpenOrderParts
Dataflow: df_OpenOrderParts
Location: LH_Master_Data → Dataflows → 04 - Fact
============================================================================

PURPOSE: Parts already committed to open (not-yet-invoiced) work orders.
Used in the Recommendations DAX calculated table to suppress parts that are
already on the order from appearing as recommendations.

GRAIN: One row per WorkOrder × PartNumber
SOURCE: insalpar (Lakehouse) → Insalord (Lakehouse)
        Join key: insalpar.FileNumber = Insalord.FileNumber

FILTERS:
  Insalord.OrderType = 'W'  (work orders only — excludes other order types)
  insalpar records are pre-invoice by definition; no WkRoFile join needed.

OUTPUT COLUMNS:
  WorkOrderNumber  TEXT  — work order / RO number  (Insalord.RONumber)
  BranchCode       TEXT  — branch identifier        (Insalord.ROBranch)
  PartNumber       TEXT  — part already on order    (insalpar.PartNumber)

REFRESH: Full daily, Phase 4 — small dataset
============================================================================
*/

let
    // =====================================================================
    // LAKEHOUSE CONNECTION
    // Workspace: LH_Master_Data  (b48cdb35-7ce3-46de-96df-d70db77649cb)
    // Lakehouse: LH_Master_Data  (3e74497b-8c51-4a1a-91a1-888c59118f48)
    // =====================================================================
    LH_Source    = Lakehouse.Contents([HierarchicalNavigation = null, EnableVorder = true, OutputMetadataRefresh = true]),
    LH_Workspace = LH_Source{[workspaceId = "b48cdb35-7ce3-46de-96df-d70db77649cb"]}[Data],
    LH_Lakehouse = LH_Workspace{[lakehouseId = "3e74497b-8c51-4a1a-91a1-888c59118f48"]}[Data],

    // =====================================================================
    // STEP 1: PART LINES FROM insalpar
    // Lakehouse columns: FileNumber, PartNumber (among others)
    // =====================================================================
    insalpar_Raw  = LH_Lakehouse{[Id = "insalpar", ItemKind = "Table"]}[Data],
    Parts         = Table.SelectColumns(insalpar_Raw, {"FileNumber", "PartNumber"}),
    Parts_Filtered = Table.SelectRows(Parts, each
                        [PartNumber] <> null and [PartNumber] <> ""),
    Parts_Typed   = Table.TransformColumnTypes(Parts_Filtered, {
                        {"FileNumber", type text},
                        {"PartNumber", type text}
                    }),

    // =====================================================================
    // STEP 2: ORDER HEADERS FROM Insalord — WORK ORDERS ONLY
    // Lakehouse columns: FileNumber, RONumber, ROBranch, OrderType
    // OrderType = 'W' targets work orders specifically.
    // =====================================================================
    Insalord_Raw  = LH_Lakehouse{[Id = "Insalord", ItemKind = "Table"]}[Data],
    Orders        = Table.SelectColumns(Insalord_Raw, {"FileNumber", "RONumber", "ROBranch", "OrderType"}),
    Orders_Filtered = Table.SelectRows(Orders, each [OrderType] = "W"),
    Orders_Typed  = Table.TransformColumnTypes(Orders_Filtered, {
                        {"FileNumber", type text},
                        {"RONumber",   type text},
                        {"ROBranch",   type text}
                    }),

    // =====================================================================
    // STEP 3: JOIN insalpar → Insalord (via FileNumber)
    // =====================================================================
    Joined        = Table.NestedJoin(
                        Parts_Typed,  {"FileNumber"},
                        Orders_Typed, {"FileNumber"},
                        "Orders",
                        JoinKind.Inner
                    ),
    Expanded      = Table.ExpandTableColumn(Joined, "Orders", {"RONumber", "ROBranch"}),

    // =====================================================================
    // FINAL COLUMNS — rename to standard output names, drop FileNumber
    // =====================================================================
    Renamed       = Table.RenameColumns(Expanded, {
                        {"RONumber", "WorkOrderNumber"},
                        {"ROBranch", "BranchCode"}
                    }),
    Selected      = Table.SelectColumns(Renamed, {"WorkOrderNumber", "BranchCode", "PartNumber"}),

    Final         = Table.TransformColumnTypes(Selected, {
                        {"WorkOrderNumber", type text},
                        {"BranchCode",      type text},
                        {"PartNumber",      type text}
                    })
in
    Final
