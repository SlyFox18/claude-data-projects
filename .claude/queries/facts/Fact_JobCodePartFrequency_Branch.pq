/*
============================================================================
Query: Fact_JobCodePartFrequency_Branch
Dataflow: df_JobCodePartFrequency_Branch
Location: LH_Master_Data → Dataflows → 04 - Fact
============================================================================

PURPOSE: Branch-level version of Fact_JobCodePartFrequency. For each
         combination of Branch × JobCode × PartNumber, what % of that
         branch's work orders for that job code also included each part?

         Enables branch-vs-branch comparison:
         "Seminole adds this part to /TRACTOR INSPECT 80% of the time.
         Tahoka never does — should they?"

GRAIN: One row per Branch × JobCode × PartNumber
SOURCE: wkothsub (Lakehouse) joined to InTrans_Incremental (Lakehouse)
        via wkothsub.InvoiceNumber = InTrans_Incremental.RONumber
FILTER: Invoiced orders only, last 3 years rolling.

OUTPUT COLUMNS:
  Branch                    TEXT  — branch identifier
  JobCode                   TEXT  — job code (e.g. /10-020030)
  PartNumber                TEXT  — part number
  TimesWithPart             INT   — distinct WOs at this branch where job+part appeared
  TotalOrdersWithJobCode    INT   — distinct WOs at this branch with this job code
  FrequencyPct              FLOAT — TimesWithPart / TotalOrdersWithJobCode (branch-specific)

NOTE: FrequencyPct is branch-specific. A part at 50% for Seminole means
      Seminole added it to half of their orders for that job code,
      regardless of what other branches do. Use CompanyFrequencyPct
      (added in Fact_BranchAnalysis calculated table) for comparison.

⚠️ CRITICAL JOIN: wkothsub.InvoiceNumber = InTrans_Incremental.RONumber
   RONumber in InTrans is the INVOICE number, not the work order number.
   Joining on work order number produces ~1% of the correct row count.

REFRESH: Full daily, Phase 4 (same wave as Fact_JobCodePartFrequency)
         Estimated: slightly longer than sibling query due to Branch dimension

USED BY:
  Job Code Parts Advisor — Branch Comparison page (Page 2)
  Fact_BranchAnalysis calculated table (DAX enrichment layer)

============================================================================
*/

let
    // =====================================================================
    // LAKEHOUSE CONNECTION
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
    // =====================================================================
    wkothsub_Raw  = LH_Lakehouse{[Id = "wkothsub", ItemKind = "Table"]}[Data],
    wkothsub_Cols = Table.SelectColumns(wkothsub_Raw,
                        {"Branch", "WorkOrder", "JobCode", "InvoiceNumber", "InvoiceDate"}),
    Jobs_Filtered = Table.SelectRows(wkothsub_Cols, each
                        [InvoiceNumber] <> null and [InvoiceNumber] <> "" and
                        Date.From([InvoiceDate]) >= ThreeYearsAgo),
    Jobs_Distinct = Table.Distinct(
                        Table.SelectColumns(Jobs_Filtered,
                            {"Branch", "WorkOrder", "JobCode", "InvoiceNumber"})),
    Jobs_Typed    = Table.TransformColumnTypes(Jobs_Distinct, {
                        {"Branch",        type text},
                        {"WorkOrder",     type text},
                        {"JobCode",       type text},
                        {"InvoiceNumber", type text}
                    }),

    // =====================================================================
    // STEP 2: DENOMINATOR — DISTINCT WORK ORDERS PER BRANCH × JOB CODE
    // Branch is now part of the grouping key (vs company-wide sibling query)
    // =====================================================================
    TotalsByBranchJobCode = Table.Group(
                                Jobs_Typed,
                                {"Branch", "JobCode"},
                                {{"TotalOrdersWithJobCode",
                                  each List.Count(List.Distinct([WorkOrder])),
                                  Int64.Type}}
                            ),

    // =====================================================================
    // STEP 3: PARTS FROM InTrans_Incremental
    // ⚠️ RONumber is the INVOICE number — renamed for join
    // =====================================================================
    InTrans_Raw   = LH_Lakehouse{[Id = "InTrans_Incremental", ItemKind = "Table"]}[Data],
    InTrans_Cols  = Table.SelectColumns(InTrans_Raw, {"Branch", "RONumber", "PartNumber"}),
    Parts_Filtered = Table.SelectRows(InTrans_Cols, each
                        [PartNumber] <> null and [PartNumber] <> ""),
    Parts_Distinct = Table.Distinct(Parts_Filtered),
    Parts_Renamed  = Table.RenameColumns(Parts_Distinct, {{"RONumber", "InvoiceNumber"}}),
    Parts_Typed    = Table.TransformColumnTypes(Parts_Renamed, {
                        {"Branch",        type text},
                        {"InvoiceNumber", type text},
                        {"PartNumber",    type text}
                    }),

    // =====================================================================
    // STEP 4: JOIN JOBS TO PARTS VIA INVOICE NUMBER + BRANCH
    // =====================================================================
    Joined   = Table.NestedJoin(
                   Jobs_Typed,  {"InvoiceNumber", "Branch"},
                   Parts_Typed, {"InvoiceNumber", "Branch"},
                   "Parts",
                   JoinKind.Inner
               ),
    Expanded = Table.ExpandTableColumn(Joined, "Parts", {"PartNumber"}),
    WithParts = Table.SelectRows(Expanded,
                    each [PartNumber] <> null and [PartNumber] <> ""),

    // =====================================================================
    // STEP 5: NUMERATOR — TIMES EACH PART APPEARED PER BRANCH × JOB CODE
    // Branch is now part of the grouping key
    // =====================================================================
    FrequencyBase = Table.Group(
                        WithParts,
                        {"Branch", "JobCode", "PartNumber"},
                        {{"TimesWithPart",
                          each List.Count(List.Distinct([WorkOrder])),
                          Int64.Type}}
                    ),

    // =====================================================================
    // STEP 6: JOIN BRANCH TOTALS AND CALCULATE FrequencyPct
    // =====================================================================
    WithTotals = Table.NestedJoin(
                     FrequencyBase,          {"Branch", "JobCode"},
                     TotalsByBranchJobCode,  {"Branch", "JobCode"},
                     "Totals",
                     JoinKind.Inner
                 ),
    WithTotalsExpanded = Table.ExpandTableColumn(
                             WithTotals, "Totals", {"TotalOrdersWithJobCode"}),

    WithFrequency = Table.AddColumn(
                        WithTotalsExpanded,
                        "FrequencyPct",
                        each if [TotalOrdersWithJobCode] = 0 then 0
                             else [TimesWithPart] / [TotalOrdersWithJobCode],
                        type number),

    // =====================================================================
    // FINAL TYPES
    // =====================================================================
    Final = Table.TransformColumnTypes(WithFrequency, {
                {"Branch",                 type text},
                {"JobCode",                type text},
                {"PartNumber",             type text},
                {"TimesWithPart",          Int64.Type},
                {"TotalOrdersWithJobCode", Int64.Type},
                {"FrequencyPct",           type number}
            })
in
    Final
