/*
============================================================================
Query: param_ROP_Matrix
Dataflow: df_Param_ROP_Matrix
Location: LH_Master_Data → Dataflows → 03 - Dimensions
============================================================================

PURPOSE: 1,993-row ROP calculation parameter matrix. Maps MonthCount +
average monthly demand range + average monthly sales range to stocking
modifiers and warehouse minimums used in Fact_NonJD_Reorder.

GRAIN: One row per MonthCount + DemandL/H + SalesL/H combination

SOURCE: CSV file in LH_Master_Data → Files → Version 5 ROP-CSV.csv
        Repo copy: projects/part order tool - app/example excel sheet/Version 5 ROP-CSV.csv

REFRESH: Manual only — admin-managed, only when stocking rules change

KEY FINDING: All 1,993 rows use "Default" for StockingGroup, CommodityCode,
SRC, SLC, and Attachment. The effective lookup dimensions are ONLY:
  MonthCount (1-19) + DemandL/DemandH + SalesL/SalesH

LAKEHOUSE IDs:
  Workspace: b48cdb35-7ce3-46de-96df-d70db77649cb
  Lakehouse: 3e74497b-8c51-4a1a-91a1-888c59118f48
============================================================================
*/

let
    Source = Lakehouse.Contents([HierarchicalNavigation = null, EnableVorder = true, OutputMetadataRefresh = true]),
    #"Navigation 1" = Source{[workspaceId = "b48cdb35-7ce3-46de-96df-d70db77649cb"]}[Data],
    #"Navigation 2" = #"Navigation 1"{[lakehouseId = "3e74497b-8c51-4a1a-91a1-888c59118f48"]}[Data],
    #"Navigation 3" = #"Navigation 2"{[Id = "Files", ItemKind = "Folder"]}[Data],
    #"Navigation 4" = #"Navigation 3"{[Name = "Version 5 ROP-CSV.csv"]}[Content],
    ParsedCSV = Csv.Document(#"Navigation 4", [Delimiter = ",", Columns = 18, QuoteStyle = QuoteStyle.None]),
    PromoteHeaders = Table.PromoteHeaders(ParsedCSV, [PromoteAllScalars = true]),
    FixHeader = Table.RenameColumns(PromoteHeaders, {
        {"Spiking Warehouse<BR>Stocking Min", "SpikingWarehouseStockingMin"}
    }),
    TypedTable = Table.TransformColumnTypes(FixHeader, {
        {"Group",                    type text},
        {"Commodity Code",           type text},
        {"SRC",                      type text},
        {"SLC",                      type text},
        {"Attachment",               type text},
        {"Price L",                  type number},
        {"Price H",                  type number},
        {"Month Count",              Int64.Type},
        {"Demand L",                 type number},
        {"Demand H",                 type number},
        {"Sales L",                  type number},
        {"Sales H",                  type number},
        {"Modifier",                 type number},
        {"Trending Cap",             type number},
        {"Warehouse Min",            Int64.Type},
        {"Stocking weeks",           Int64.Type},
        {"Spiking Modifier",         type number},
        {"SpikingWarehouseStockingMin", Int64.Type}
    }),
    Renamed = Table.RenameColumns(TypedTable, {
        {"Group",           "StockingGroup"},
        {"Commodity Code",  "CommodityCode"},
        {"Price L",         "PriceL"},
        {"Price H",         "PriceH"},
        {"Month Count",     "MonthCount"},
        {"Demand L",        "DemandL"},
        {"Demand H",        "DemandH"},
        {"Sales L",         "SalesL"},
        {"Sales H",         "SalesH"},
        {"Trending Cap",    "TrendingCap"},
        {"Warehouse Min",   "WarehouseMin"},
        {"Stocking weeks",  "StockingWeeks"},
        {"Spiking Modifier","SpikingModifier"}
    })
in
    Renamed