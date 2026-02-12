/*
============================================================================
FACT_INTRANS_ALLPROMO - FOR USE IN POWER BI REPORT (NOT DATAFLOW)
============================================================================

📋 PURPOSE:
This query is designed to be used directly in the Power BI semantic model,
NOT in a Fabric Dataflow. It queries InTrans_Incremental directly.

🔧 HOW TO USE:
1. In Power BI Desktop, go to Transform Data (Power Query Editor)
2. Create a new Blank Query
3. Open Advanced Editor
4. Paste the let...in block below
5. Rename the query to "Fact_InTrans_AllPromo"

============================================================================
*/

let
    StartDate = #datetime(2023, 1, 1, 0, 0, 0),

    Source = Lakehouse.Contents([HierarchicalNavigation = null]),
    Workspace = Source{[workspaceId = "b48cdb35-7ce3-46de-96df-d70db77649cb"]}[Data],
    Lakehouse = Workspace{[lakehouseId = "3e74497b-8c51-4a1a-91a1-888c59118f48"]}[Data],
    InTrans = Lakehouse{[Id = "InTrans_Incremental", ItemKind = "Table"]}[Data],

    // Filter to 2023 onwards
    FilterByDate = Table.SelectRows(InTrans, each
        [TransDatetime] >= StartDate
    ),

    // Select columns (Branch stays as text, Qty included)
    SelectColumns = Table.SelectColumns(FilterByDate, {
        "Branch",
        "Franchise",
        "CustomerNo",
        "PartNumber",
        "TransDatetime",
        "Type",
        "Qty",
        "RONumber",
        "SaleValue",
        "CostValue",
        "Description"
    }),

    // Rename for consistency with model
    RenameColumns = Table.RenameColumns(SelectColumns, {
        {"PartNumber", "PART_NO"},
        {"RONumber", "REF_NO"}
    }),

    // Add DateKey for dim_DateTable relationship
    AddDateKey = Table.AddColumn(RenameColumns, "DateKey", each
        Date.From([TransDatetime]),
        type date
    ),

    // Handle Qty - convert to number, null if not convertible
    CleanQty = Table.TransformColumns(AddDateKey, {
        {"Qty", each try Number.From(_) otherwise null, type number}
    }),

    // ========================================================================
    // DEDUPLICATE: Remove duplicates from InTrans_Incremental watermark issues
    // ========================================================================
    // The InTrans_Incremental table may contain duplicate rows due to watermark
    // strategy issues (introduced ~December 2024). Since duplicates are exact
    // copies, Table.Distinct is more efficient than Table.Group.
    Deduplicate = Table.Distinct(CleanQty),

    // Set data types (Branch is TEXT, not Int64)
    SetTypes = Table.TransformColumnTypes(Deduplicate, {
        {"Branch", type text},
        {"Franchise", type text},
        {"CustomerNo", type text},
        {"PART_NO", type text},
        {"TransDatetime", type datetime},
        {"Type", type text},
        {"Qty", type number},
        {"REF_NO", type text},
        {"SaleValue", type number},
        {"CostValue", type number},
        {"Description", type text},
        {"DateKey", type date}
    }),

    // Reorder columns
    ReorderColumns = Table.ReorderColumns(SetTypes, {
        "Branch",
        "DateKey",
        "REF_NO",
        "PART_NO",
        "TransDatetime",
        "CustomerNo",
        "Franchise",
        "Type",
        "Description",
        "Qty",
        "SaleValue",
        "CostValue"
    })

in
    ReorderColumns
