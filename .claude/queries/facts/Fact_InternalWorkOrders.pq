/*
============================================================================
Query: Fact_InternalWorkOrders
Dataflow: df_Fact_InternalWorkOrders
Location: LH_Master_Data → Dataflows → 04 - Fact
============================================================================

PURPOSE: Internal work orders (stock checks) with job code detail.
An "internal" WO is any work order where wkrodesc.JobType = "i" —
these represent service work performed on unsold stock equipment.

GRAIN: One row per WorkOrder × JobCode
DATE SCOPE: CreatedOn >= 2026-01-01 (adjust start date in STEP 2 as needed)

SOURCE TABLES (all Lakehouse, no ODBC):
  wkrodesc   — job codes, base table (LINE_NO = 1 pre-filtered in raw table)
  WKROFILE   — WO header: dates, status, equipment identifiers
  wkothsub   — estimated hours, standard labor flag, invoice reference
  wkmechwk   — technician labor (aggregated to WO × JobCode before join)
  vhstock    — Make/Model for stock (unsold) equipment
  WKVEHFL    — Make/Model for registered/fleet equipment (fallback)

OUTPUT: ~7,000–12,000 rows (Internal WOs, 2026 scope)
REFRESH: Full daily, Phase 4
============================================================================
*/

let
    // =========================================================================
    // LAKEHOUSE CONNECTION
    // Workspace: LH_Master_Data  (b48cdb35-7ce3-46de-96df-d70db77649cb)
    // Lakehouse: LH_Master_Data  (3e74497b-8c51-4a1a-91a1-888c59118f48)
    // =========================================================================
    LH_Source    = Lakehouse.Contents([HierarchicalNavigation = null, EnableVorder = true, OutputMetadataRefresh = true]),
    LH_Workspace = LH_Source{[workspaceId = "b48cdb35-7ce3-46de-96df-d70db77649cb"]}[Data],
    LH_Lakehouse = LH_Workspace{[lakehouseId = "3e74497b-8c51-4a1a-91a1-888c59118f48"]}[Data],

    // =========================================================================
    // STEP 1: wkrodesc — Internal job codes only
    // The raw Lakehouse table already has LINE_NO = 1 applied (one row per
    // job code per WO). Filter to JobType = "i" for Internal WOs only.
    // =========================================================================
    wkrodesc_Raw  = LH_Lakehouse{[Id = "wkrodesc", ItemKind = "Table"]}[Data],
    wkrodesc_Cols = Table.SelectColumns(wkrodesc_Raw,
                        {"Branch", "WorkOrder", "JobCode", "JobType", "JobValue"}),
    InternalJobs  = Table.SelectRows(wkrodesc_Cols, each [JobType] = "I"),
    InternalJobs_Typed = Table.TransformColumnTypes(InternalJobs, {
                        {"Branch",   type text},
                        {"WorkOrder", type text},
                        {"JobCode",  type text},
                        {"JobType",  type text},
                        {"JobValue", type number}
                    }),

    // =========================================================================
    // STEP 2: WKROFILE — WO header, filtered to 2026-01-01 forward
    // IsClosed is text "Y" / "N" (not boolean) — use "N" for open WOs in DAX.
    // =========================================================================
    WKROFILE_Raw  = LH_Lakehouse{[Id = "WKROFILE", ItemKind = "Table"]}[Data],
    WKROFILE_Cols = Table.SelectColumns(WKROFILE_Raw,
                        {"Branch", "WorkOrder", "StockNumber", "Registration",
                         "CreatedOn", "ClosedDate", "ProgressStatus", "IsClosed"}),
    WKROFILE_2026 = Table.SelectRows(WKROFILE_Cols,
                        each [CreatedOn] <> null and [CreatedOn] >= #datetime(2026, 1, 1, 0, 0, 0)),
    WKROFILE_Typed = Table.TransformColumnTypes(WKROFILE_2026, {
                        {"Branch",         type text},
                        {"WorkOrder",      type text},
                        {"StockNumber",    type text},
                        {"Registration",   type text},
                        {"CreatedOn",      type date},
                        {"ClosedDate",     type date},
                        {"ProgressStatus", type text},
                        {"IsClosed",       type text}
                    }),

    // =========================================================================
    // STEP 3: wkothsub — estimated hours and operational flags per job
    // =========================================================================
    wkothsub_Raw  = LH_Lakehouse{[Id = "wkothsub", ItemKind = "Table"]}[Data],
    wkothsub_Cols = Table.SelectColumns(wkothsub_Raw,
                        {"Branch", "WorkOrder", "JobCode", "JobType",
                         "EstHours", "IsStandardLabor", "IsNonRevenue", "InvoiceNumber"}),
    wkothsub_Typed = Table.TransformColumnTypes(wkothsub_Cols, {
                        {"Branch",          type text},
                        {"WorkOrder",       type text},
                        {"JobCode",         type text},
                        {"JobType",         type text},
                        {"EstHours",        type number},
                        {"IsStandardLabor", type text},
                        {"IsNonRevenue",    type text},
                        {"InvoiceNumber",   type text}
                    }),

    // =========================================================================
    // STEP 4: wkmechwk — aggregate actual and invoiced hours to WO × JobCode grain
    // wkmechwk has one row per technician per day per job — sum before joining.
    // =========================================================================
    wkmechwk_Raw  = LH_Lakehouse{[Id = "wkmechwk", ItemKind = "Table"]}[Data],
    wkmechwk_Cols = Table.SelectColumns(wkmechwk_Raw,
                        {"Branch", "WorkOrder", "JobCode", "JobType",
                         "HoursWorked", "InvoiceHours"}),
    wkmechwk_Typed = Table.TransformColumnTypes(wkmechwk_Cols, {
                        {"Branch",       type text},
                        {"WorkOrder",    type text},
                        {"JobCode",      type text},
                        {"JobType",      type text},
                        {"HoursWorked",  type number},
                        {"InvoiceHours", type number}
                    }),
    wkmechwk_Agg  = Table.Group(wkmechwk_Typed,
                        {"Branch", "WorkOrder", "JobCode", "JobType"},
                        {
                            {"HoursWorked",  each List.Sum(List.RemoveNulls([HoursWorked])),  type number},
                            {"InvoiceHours", each List.Sum(List.RemoveNulls([InvoiceHours])), type number}
                        }),

    // =========================================================================
    // STEP 5: vhstock — Make/Model for stock (unsold) equipment
    // Full-extract table — all stock units including unsold are present.
    // =========================================================================
    vhstock_Raw     = LH_Lakehouse{[Id = "vhstock", ItemKind = "Table"]}[Data],
    vhstock_Cols    = Table.SelectColumns(vhstock_Raw, {"StockNumber", "Make", "Model"}),
    vhstock_Renamed = Table.RenameColumns(vhstock_Cols,
                        {{"Make", "StockMake"}, {"Model", "StockModel"}}),

    // =========================================================================
    // STEP 6: WKVEHFL — Make/Model for registered/fleet vehicles (fallback)
    // Used when WKROFILE.Registration is populated and StockNumber is null.
    // =========================================================================
    WKVEHFL_Raw     = LH_Lakehouse{[Id = "WKVEHFL", ItemKind = "Table"]}[Data],
    WKVEHFL_Cols    = Table.SelectColumns(WKVEHFL_Raw, {"Registration", "Make", "Model"}),
    WKVEHFL_Renamed = Table.RenameColumns(WKVEHFL_Cols,
                        {{"Make", "RegMake"}, {"Model", "RegModel"}}),

    // =========================================================================
    // STEP 7: Join InternalJobs → WKROFILE (INNER — only WOs in scope)
    // =========================================================================
    Join_WO       = Table.NestedJoin(
                        InternalJobs_Typed, {"Branch", "WorkOrder"},
                        WKROFILE_Typed,     {"Branch", "WorkOrder"},
                        "WOHeader", JoinKind.Inner),
    Expand_WO     = Table.ExpandTableColumn(Join_WO, "WOHeader",
                        {"StockNumber", "Registration", "CreatedOn",
                         "ClosedDate", "ProgressStatus", "IsClosed"}),

    // =========================================================================
    // STEP 8: Join → wkothsub (LEFT — job may not yet have an invoice)
    // =========================================================================
    Join_Sub      = Table.NestedJoin(
                        Expand_WO,        {"Branch", "WorkOrder", "JobCode", "JobType"},
                        wkothsub_Typed,   {"Branch", "WorkOrder", "JobCode", "JobType"},
                        "SubInfo", JoinKind.LeftOuter),
    Expand_Sub    = Table.ExpandTableColumn(Join_Sub, "SubInfo",
                        {"EstHours", "IsStandardLabor", "IsNonRevenue", "InvoiceNumber"}),

    // =========================================================================
    // STEP 9: Join → wkmechwk aggregated hours (LEFT — WO may have no labor yet)
    // =========================================================================
    Join_Hours    = Table.NestedJoin(
                        Expand_Sub,       {"Branch", "WorkOrder", "JobCode", "JobType"},
                        wkmechwk_Agg,     {"Branch", "WorkOrder", "JobCode", "JobType"},
                        "HourInfo", JoinKind.LeftOuter),
    Expand_Hours  = Table.ExpandTableColumn(Join_Hours, "HourInfo",
                        {"HoursWorked", "InvoiceHours"}),

    // =========================================================================
    // STEP 10: Join → vhstock for stock equipment Make/Model (LEFT)
    // =========================================================================
    Join_Stock    = Table.NestedJoin(
                        Expand_Hours, {"StockNumber"},
                        vhstock_Renamed, {"StockNumber"},
                        "StockEq", JoinKind.LeftOuter),
    Expand_Stock  = Table.ExpandTableColumn(Join_Stock, "StockEq",
                        {"StockMake", "StockModel"}),

    // =========================================================================
    // STEP 11: Join → WKVEHFL for registered vehicle Make/Model (LEFT fallback)
    // =========================================================================
    Join_Veh      = Table.NestedJoin(
                        Expand_Stock, {"Registration"},
                        WKVEHFL_Renamed, {"Registration"},
                        "RegEq", JoinKind.LeftOuter),
    Expand_Veh    = Table.ExpandTableColumn(Join_Veh, "RegEq",
                        {"RegMake", "RegModel"}),

    // =========================================================================
    // STEP 12: Resolve Make/Model — prefer vhstock, fall back to WKVEHFL
    // =========================================================================
    With_Make     = Table.AddColumn(Expand_Veh, "Make",
                        each if [StockMake] <> null and [StockMake] <> ""
                             then [StockMake] else [RegMake],
                        type text),
    With_Model    = Table.AddColumn(With_Make, "Model",
                        each if [StockModel] <> null and [StockModel] <> ""
                             then [StockModel] else [RegModel],
                        type text),

    // =========================================================================
    // STEP 13: Select final columns and apply types
    // =========================================================================
    Selected      = Table.SelectColumns(With_Model, {
                        "Branch", "WorkOrder", "JobCode", "JobType", "JobValue",
                        "CreatedOn", "ClosedDate", "ProgressStatus", "IsClosed",
                        "StockNumber", "Registration", "Make", "Model",
                        "EstHours", "IsStandardLabor", "IsNonRevenue", "InvoiceNumber",
                        "HoursWorked", "InvoiceHours"
                    }),
    Final         = Table.TransformColumnTypes(Selected, {
                        {"Branch",          type text},
                        {"WorkOrder",       type text},
                        {"JobCode",         type text},
                        {"JobType",         type text},
                        {"JobValue",        type number},
                        {"CreatedOn",       type date},
                        {"ClosedDate",      type date},
                        {"ProgressStatus",  type text},
                        {"IsClosed",        type text},
                        {"StockNumber",     type text},
                        {"Registration",    type text},
                        {"Make",            type text},
                        {"Model",           type text},
                        {"EstHours",        type number},
                        {"IsStandardLabor", type text},
                        {"IsNonRevenue",    type text},
                        {"InvoiceNumber",   type text},
                        {"HoursWorked",     type number},
                        {"InvoiceHours",    type number}
                    })
in
    Final
