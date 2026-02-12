let
    // =========================
    // Fabric Lakehouse navigation
    // =========================
    Source = Lakehouse.Contents([HierarchicalNavigation = null]),
    Workspace = Source{[workspaceId = "b48cdb35-7ce3-46de-96df-d70db77649cb"]}[Data],
    Lakehouse = Workspace{[lakehouseId = "3e74497b-8c51-4a1a-91a1-888c59118f48"]}[Data],
    InsalordRaw = Lakehouse{[Id = "Insalord", ItemKind = "Table"]}[Data],
    InsalparRaw = Lakehouse{[Id = "insalpar", ItemKind = "Table"]}[Data],

    // =========================
    // Type normalization (adjust if your schema differs)
    // =========================
    InsalordTyped =
        Table.TransformColumnTypes(
            InsalordRaw,
            {
                {"FileNumber", Int64.Type},
                {"Branch", type text},
                {"CustomerOrderNumber", type text},
                {"TaxNumber", type text},
                {"OrderType", type text},
                {"Freight", type number},
                {"Salesperson", type text},
                {"OrderDate", type datetime},
                {"CustomerNumber", type text},
                {"VehicleNumber", type text},
                {"RONumber", Int64.Type},   // change to type text if alphanumeric
                {"Note", type text},
                {"AuthID", type text},
                {"AuthValue", type number},
                {"RecControl", type text}
            }
        ),

    InsalparTyped =
        Table.TransformColumnTypes(
            InsalparRaw,
            {
                {"FileNumber", Int64.Type},
                {"LineNumber", Int64.Type},
                {"Branch", type text},
                {"Franchise", type text},
                {"PartNumber", type text},
                {"OrderQty", type number},
                {"SuppliedQty", type number},
                {"UnitPrice", type number},
                {"UnitCost", type number},
                {"JobCode", type text},
                {"Salesperson", type text},
                {"CreationDate", type datetime}
            }
        ),

    // =========================
    // Avoid name collisions from line vs header
    // =========================
    InsalparNoCollisions =
        let
            cols = Table.ColumnNames(InsalparTyped),
            step1 = if List.Contains(cols, "Branch")
                    then Table.RenameColumns(InsalparTyped, {{"Branch", "LineBranch"}})
                    else InsalparTyped,
            cols2 = Table.ColumnNames(step1),
            step2 = if List.Contains(cols2, "Salesperson")
                    then Table.RenameColumns(step1, {{"Salesperson", "LineSalesperson"}})
                    else step1
        in
            step2,

    // =========================
    // Rename existing BackorderQty if it exists
    // =========================
    RenameExistingBackorder =
        let
            cols = Table.ColumnNames(InsalparNoCollisions)
        in
            if List.Contains(cols, "BackorderQty")
            then Table.RenameColumns(InsalparNoCollisions, {{"BackorderQty", "OriginalBackorderQty"}})
            else InsalparNoCollisions,

    // =========================
    // Optional business filter (exclude transfers)
    // =========================
    InsalordFiltered =
        Table.SelectRows(InsalordTyped, each [OrderType] <> "T" or [OrderType] = null),

    // =========================
    // Per-line calculations (insalpar)
    // =========================
    // LineExtended = UnitPrice * OrderQty
    AddLineExtended =
        Table.AddColumn(
            RenameExistingBackorder, "LineExtended",
            each Number.From([UnitPrice]) * Number.From([OrderQty]),
            type number
        ),

    // Supplied amount = UnitPrice * SuppliedQty
    AddLineSuppliedAmount =
        Table.AddColumn(
            AddLineExtended, "LineSuppliedAmount",
            each Number.From([UnitPrice]) * Number.From([SuppliedQty]),
            type number
        ),

    // Backorder qty = OrderQty - SuppliedQty
    AddBackorderQty =
        Table.AddColumn(
            AddLineSuppliedAmount, "BackorderQty",
            each Number.From([OrderQty]) - Number.From([SuppliedQty]),
            type number
        ),

    // Backorder amount = UnitPrice * BackorderQty
    AddBackorderAmount =
        Table.AddColumn(
            AddBackorderQty, "BackorderAmount",
            each Number.From([UnitPrice]) * Number.From([BackorderQty]),
            type number
        ),

    // =========================
    // Join lines → header on FileNumber
    // =========================
    Joined =
        Table.NestedJoin(
            AddBackorderAmount, {"FileNumber"},
            InsalordFiltered, {"FileNumber"},
            "OrderHeader", JoinKind.Inner
        ),

    // Expand header with NEW names to avoid collisions (e.g., HeaderBranch, HeaderSalesperson)
    HeaderColsToExpand = {
        "Branch", "CustomerOrderNumber", "TaxNumber", "OrderType", "Freight",
        "Salesperson", "OrderDate", "CustomerNumber", "VehicleNumber",
        "RONumber", "Note"
    },
    HeaderColsAvailable = List.Intersect({HeaderColsToExpand, Table.ColumnNames(InsalordFiltered)}),
    HeaderColsRenamed =
        List.Transform(HeaderColsAvailable, each
            if _ = "Branch" then "HeaderBranch"
            else if _ = "Salesperson" then "HeaderSalesperson"
            else _
        ),
    ExpandedHeader =
        Table.ExpandTableColumn(
            Joined, "OrderHeader",
            HeaderColsAvailable,
            HeaderColsRenamed
        ),

    // =========================
    // Order identifiers & aging
    // =========================
    // Prefer RO number when present; otherwise use FileNumber.
    AddOrderNo =
        Table.AddColumn(
            ExpandedHeader, "Order_No",
            each
                let rn = try [RONumber] otherwise null
                in if rn = null or rn = 0
                   then Text.From([FileNumber])
                   else Text.From(rn),
            type text
        ),

    // Days open = (today's date) - (order date) → duration in days
    AddDaysOpen =
        Table.AddColumn(
            AddOrderNo, "Days_Open",
            each
                let
                    today = DateTime.Date(DateTime.LocalNow()),
                    ord = Date.From([OrderDate])
                in
                    Duration.Days(today - ord),
            Int64.Type
        ),

    // Aging bucket per your ranges
    AddAgingBucket =
        Table.AddColumn(
            AddDaysOpen, "Aging",
            each
                let d = [Days_Open]
                in
                    if d >= 0 and d <= 7 then " 0-7 days" else
                    if d >= 8 and d <= 30 then " 8-30 days" else
                    if d >= 31 and d <= 60 then "31-60 days" else
                    if d >= 61 and d <= 90 then "61-90 days" else "90+ days",
            type text
        ),

    // =========================
    // Aggregate to ORDER-level fact
    // =========================
    GroupKeys = {
        "HeaderBranch", "CustomerNumber", "HeaderSalesperson",
        "FileNumber", "Order_No", "OrderType", "OrderDate",
        "Days_Open", "Aging"
    },

    // Ensure HeaderSalesperson exists even if header lacked it
    AddHeaderSalespersonIfMissing =
        if List.Contains(Table.ColumnNames(AddAgingBucket), "HeaderSalesperson")
        then AddAgingBucket
        else Table.AddColumn(AddAgingBucket, "HeaderSalesperson", each null, type text),

    FactOrders =
        Table.Group(
            AddHeaderSalespersonIfMissing,
            GroupKeys,
            {
                // Quantities
                {"#_Parts_On_Order", each List.Sum([OrderQty]), type number},
                {"#_On_Back_Order", each List.Sum([BackorderQty]), type number},

                // Values
                {"Order_Total_$$", each List.Sum([LineExtended]), type number},
                {"$$_not_BO", each List.Sum([LineSuppliedAmount]), type number},
                {"Backorder_Amount", each List.Sum([BackorderAmount]), type number},

                // Header-level measure (Freight)
                {"Freight", each List.Max([Freight]), type number}
            }
        ),

    // =========================
    // Arrange columns
    // =========================
    DesiredOrder = {
        "HeaderBranch", "CustomerNumber", "HeaderSalesperson",
        "FileNumber", "Order_No", "OrderType", "OrderDate",
        "Days_Open", "Aging",
        "#_Parts_On_Order", "#_On_Back_Order",
        "Order_Total_$$", "$$_not_BO", "Backorder_Amount",
        "Freight"
    },
    Final =
        let
            cols = Table.ColumnNames(FactOrders),
            reorder = List.Intersect({DesiredOrder, cols})
        in
            Table.ReorderColumns(FactOrders, reorder)
in
    Final