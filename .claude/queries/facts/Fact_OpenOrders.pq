/*
============================================================================
Query: Fact_OpenOrders
Dataflow: df_OpenOrders
Location: LH_Master_Data → Dataflows → 04 - Fact
============================================================================

PURPOSE: All currently open (not-yet-invoiced) work orders with their job codes.
Combined with Fact_JobCodePartFrequency in the Recommendations DAX calculated
table to produce part recommendations.

GRAIN: One row per WorkOrder × JobCode
SOURCE: WKROFILE (Lakehouse) INNER JOIN wkothsub (Lakehouse)
FILTER: WKROFILE.IsClosed = "N" (open orders only)

NOTE: wkothsub has 2023+ scope via incremental refresh. Open orders older than
3 years without recent modifications may not have job codes visible here.
In practice this affects a negligible number of orders.

OUTPUT COLUMNS:
  WorkOrderNumber  TEXT  — work order / RO number
  BranchCode       TEXT  — branch identifier
  CustomerNumber   TEXT  — customer account (joins to dim_CustomerList)
  JobCode          TEXT  — job code on this open order
  OpenDate         DATE  — work order creation date

REFRESH: Full daily, Phase 4 — small dataset (hundreds to low thousands of rows)
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
    // STEP 1: OPEN WORK ORDERS FROM WKROFILE
    // Lakehouse columns: Branch, WorkOrder, AccountNumber, CreatedOn, IsClosed
    // IsClosed = "N" → order is still open (not yet invoiced)
    // =====================================================================
    WKROFILE_Raw      = LH_Lakehouse{[Id = "WKROFILE", ItemKind = "Table"]}[Data],
    WKROFILE_Cols     = Table.SelectColumns(WKROFILE_Raw,
                            {"Branch", "WorkOrder", "AccountNumber", "CreatedOn", "IsClosed"}),
    OpenOrders        = Table.SelectRows(WKROFILE_Cols, each [IsClosed] = "N"),
    // AccountNumber stored as "83.000000" text in Lakehouse — strip decimal portion
    OpenOrders_CleanAcct = Table.TransformColumns(OpenOrders,
                            {"AccountNumber", each if _ = null then null
                                              else Text.BeforeDelimiter(Text.From(_), ".")}),
    OpenOrders_Renamed = Table.RenameColumns(OpenOrders_CleanAcct, {
                            {"Branch",        "BranchCode"},
                            {"WorkOrder",     "WorkOrderNumber"},
                            {"AccountNumber", "CustomerNumber"},
                            {"CreatedOn",     "OpenDate"}
                        }),
    OpenOrders_Typed  = Table.TransformColumnTypes(
                            Table.SelectColumns(OpenOrders_Renamed,
                                {"BranchCode", "WorkOrderNumber", "CustomerNumber", "OpenDate"}),
                            {
                                {"BranchCode",      type text},
                                {"WorkOrderNumber", type text},
                                {"CustomerNumber",  type text},
                                {"OpenDate",        type date}
                            }),

    // =====================================================================
    // STEP 2: JOB CODES FROM wkothsub FOR OPEN ORDERS
    // Lakehouse columns: Branch, WorkOrder, JobCode, InvoiceNumber
    // Open orders have no invoice number yet (InvoiceNumber is null/empty).
    // =====================================================================
    wkothsub_Raw      = LH_Lakehouse{[Id = "wkothsub", ItemKind = "Table"]}[Data],
    wkothsub_Cols     = Table.SelectColumns(wkothsub_Raw,
                            {"Branch", "WorkOrder", "JobCode", "InvoiceNumber"}),
    Jobs              = Table.SelectRows(wkothsub_Cols, each
                            [InvoiceNumber] = null or [InvoiceNumber] = ""),
    Jobs_Renamed      = Table.RenameColumns(Jobs, {
                            {"Branch",    "BranchCode"},
                            {"WorkOrder", "WorkOrderNumber"}
                        }),
    Jobs_Typed        = Table.TransformColumnTypes(
                            Table.SelectColumns(Jobs_Renamed,
                                {"BranchCode", "WorkOrderNumber", "JobCode"}),
                            {
                                {"BranchCode",      type text},
                                {"WorkOrderNumber", type text},
                                {"JobCode",         type text}
                            }),

    // =====================================================================
    // STEP 3: JOIN OPEN ORDERS TO JOB CODES
    // INNER JOIN — only include open orders that have at least one job code.
    // =====================================================================
    Joined            = Table.NestedJoin(
                            OpenOrders_Typed, {"WorkOrderNumber", "BranchCode"},
                            Jobs_Typed,       {"WorkOrderNumber", "BranchCode"},
                            "Jobs",
                            JoinKind.Inner
                        ),
    Expanded          = Table.ExpandTableColumn(Joined, "Jobs", {"JobCode"}),
    WithJobCodes      = Table.SelectRows(Expanded,
                            each [JobCode] <> null and [JobCode] <> ""),

    // =====================================================================
    // FINAL TYPES
    // =====================================================================
    Final             = Table.TransformColumnTypes(WithJobCodes, {
                            {"WorkOrderNumber", type text},
                            {"BranchCode",      type text},
                            {"CustomerNumber",  type text},
                            {"JobCode",         type text},
                            {"OpenDate",        type date}
                        })
in
    Final
