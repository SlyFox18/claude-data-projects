/*
============================================================================
Query: Fact_JobCodePartFrequency
Dataflow: df_JobCodePartFrequency
Location: LH_Master_Data → Dataflows → 04 - Fact
============================================================================

PURPOSE: Pre-computed historical frequency table for the Open Order Parts
Advisor. For each job code, what % of invoiced work orders also had each part?

GRAIN: One row per JobCode × PartNumber
SOURCE: wkothsub (Lakehouse) joined to InTrans_Incremental (Lakehouse)
        via wkothsub.InvoiceNumber = InTrans_Incremental.RONumber
FILTER: Invoiced orders only, last 3 years rolling. All branches combined.

OUTPUT COLUMNS:
  JobCode                   TEXT  — job code (e.g. 8R)
  PartNumber                TEXT  — part number
  TimesWithPart             INT   — distinct WOs where this job + part appeared
  TotalOrdersWithJobCode    INT   — distinct WOs where this job code appeared
  FrequencyPct              FLOAT — TimesWithPart / TotalOrdersWithJobCode

⚠️ CRITICAL JOIN: wkothsub.InvoiceNumber = InTrans_Incremental.RONumber
   RONumber in InTrans is the INVOICE number, not the work order number.
   Joining on work order number produces ~1% of the correct row count.

REFRESH: Full daily, Phase 4
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
    // DATE RANGE — 3 YEARS ROLLING
    // =====================================================================
    ThreeYearsAgo = Date.AddYears(Date.From(DateTime.LocalNow()), -3),

    // =====================================================================
    // STEP 1: INVOICED JOB CODES FROM wkothsub (3 YEARS)
    // Lakehouse columns (PascalCase): Branch, WorkOrder, JobCode,
    //   InvoiceNumber, InvoiceDate
    // Filter: invoiced only (InvoiceNumber not null/empty), last 3 years
    // =====================================================================
    wkothsub_Raw      = LH_Lakehouse{[Id = "wkothsub", ItemKind = "Table"]}[Data],
    wkothsub_Cols     = Table.SelectColumns(wkothsub_Raw,
                            {"Branch", "WorkOrder", "JobCode", "InvoiceNumber", "InvoiceDate"}),
    Jobs_Filtered     = Table.SelectRows(wkothsub_Cols, each
                            [InvoiceNumber] <> null and [InvoiceNumber] <> "" and
                            Date.From([InvoiceDate]) >= ThreeYearsAgo),
    Jobs_Distinct     = Table.Distinct(
                            Table.SelectColumns(Jobs_Filtered,
                                {"Branch", "WorkOrder", "JobCode", "InvoiceNumber"})),
    Jobs_Typed        = Table.TransformColumnTypes(Jobs_Distinct, {
                            {"Branch",        type text},
                            {"WorkOrder",     type text},
                            {"JobCode",       type text},
                            {"InvoiceNumber", type text}
                        }),

    // =====================================================================
    // STEP 2: DENOMINATOR — TOTAL DISTINCT WORK ORDERS PER JOB CODE
    // Used as the divisor when calculating FrequencyPct.
    // =====================================================================
    TotalsByJobCode   = Table.Group(
                            Jobs_Typed,
                            {"JobCode"},
                            {{"TotalOrdersWithJobCode",
                              each List.Count(List.Distinct([WorkOrder])),
                              Int64.Type}}
                        ),

    // =====================================================================
    // STEP 3: PARTS FROM InTrans_Incremental
    // Lakehouse columns: Branch, RONumber (= invoice number), PartNumber
    // ⚠️ RONumber is the INVOICE number — renamed to InvoiceNumber for join
    // =====================================================================
    InTrans_Raw       = LH_Lakehouse{[Id = "InTrans_Incremental", ItemKind = "Table"]}[Data],
    InTrans_Cols      = Table.SelectColumns(InTrans_Raw, {"Branch", "RONumber", "PartNumber"}),
    Parts_Filtered    = Table.SelectRows(InTrans_Cols, each
                            [PartNumber] <> null and [PartNumber] <> ""),
    Parts_Distinct    = Table.Distinct(Parts_Filtered),
    Parts_Renamed     = Table.RenameColumns(Parts_Distinct, {{"RONumber", "InvoiceNumber"}}),
    Parts_Typed       = Table.TransformColumnTypes(Parts_Renamed, {
                            {"Branch",        type text},
                            {"InvoiceNumber", type text},
                            {"PartNumber",    type text}
                        }),

    // =====================================================================
    // STEP 4: JOIN JOBS TO PARTS VIA INVOICE NUMBER + BRANCH
    // ⚠️ JOIN KEY IS INVOICE NUMBER — do NOT join on WorkOrder
    // =====================================================================
    Joined            = Table.NestedJoin(
                            Jobs_Typed,  {"InvoiceNumber", "Branch"},
                            Parts_Typed, {"InvoiceNumber", "Branch"},
                            "Parts",
                            JoinKind.Inner
                        ),
    Expanded          = Table.ExpandTableColumn(Joined, "Parts", {"PartNumber"}),
    WithParts         = Table.SelectRows(Expanded,
                            each [PartNumber] <> null and [PartNumber] <> ""),

    // =====================================================================
    // STEP 5: NUMERATOR — TIMES EACH PART APPEARED WITH EACH JOB CODE
    // =====================================================================
    FrequencyBase     = Table.Group(
                            WithParts,
                            {"JobCode", "PartNumber"},
                            {{"TimesWithPart",
                              each List.Count(List.Distinct([WorkOrder])),
                              Int64.Type}}
                        ),

    // =====================================================================
    // STEP 6: JOIN TOTALS AND CALCULATE FrequencyPct
    // =====================================================================
    WithTotals        = Table.NestedJoin(
                            FrequencyBase,   {"JobCode"},
                            TotalsByJobCode, {"JobCode"},
                            "Totals",
                            JoinKind.Inner
                        ),
    WithTotalsExpanded = Table.ExpandTableColumn(
                            WithTotals, "Totals", {"TotalOrdersWithJobCode"}),

    WithFrequency     = Table.AddColumn(
                            WithTotalsExpanded,
                            "FrequencyPct",
                            each if [TotalOrdersWithJobCode] = 0 then 0
                                 else [TimesWithPart] / [TotalOrdersWithJobCode],
                            type number),

    // =====================================================================
    // FINAL TYPES
    // =====================================================================
    Final             = Table.TransformColumnTypes(WithFrequency, {
                            {"JobCode",                type text},
                            {"PartNumber",             type text},
                            {"TimesWithPart",          Int64.Type},
                            {"TotalOrdersWithJobCode", Int64.Type},
                            {"FrequencyPct",           type number}
                        })
in
    Final
