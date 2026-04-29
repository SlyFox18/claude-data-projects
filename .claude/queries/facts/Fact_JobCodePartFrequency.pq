/*
============================================================================
Query: Fact_JobCodePartFrequency
Dataflow: df_JobCodePartFrequency
Location: LH_Master_Data → Dataflows → 04 - Fact
============================================================================

PURPOSE: Pre-computed historical frequency table for the Open Order Parts
Advisor. For each job code, what % of invoiced work orders also had each part?

GRAIN: One row per JobCode × PartNumber
SOURCE: wkothsub (job codes, invoiced WOs) joined to InTrans_Incremental
        (parts on those invoices) via InvoiceNumber = RONumber
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
NOTE: In Fabric Dataflow Gen2, replace the InTrans ODBC source below with
      a Lakehouse connector pointing to InTrans_Incremental in LH_Master_Data.
============================================================================
*/

let
    // =====================================================================
    // DATE RANGE — 3 YEARS ROLLING
    // =====================================================================
    ThreeYearsAgo = Date.AddYears(Date.From(DateTime.LocalNow()), -3),
    DateStr = "'" & Date.ToText(ThreeYearsAgo, "yyyy-MM-dd") & "'",

    // =====================================================================
    // STEP 1: INVOICED JOB CODES FROM wkothsub (3 YEARS)
    // Selects distinct Branch + WorkOrder + JobCode + InvoiceNumber rows
    // where the order has been invoiced in the last 3 years.
    // =====================================================================
    SQL_Jobs =
        "SELECT DISTINCT
             RO_BRANCH  AS Branch,
             RO_NUMBER  AS WorkOrder,
             JOB_CODE   AS JobCode,
             INVOICE_NO AS InvoiceNumber
         FROM wkothsub
         WHERE INVOICE_DATE >= " & DateStr & "
           AND INVOICE_NO IS NOT NULL
           AND INVOICE_NO <> ''",

    Jobs = Odbc.Query("dsn=EquipRDB64", SQL_Jobs),
    Jobs_Typed = Table.TransformColumnTypes(Jobs, {
        {"Branch",        type text},
        {"WorkOrder",     type text},
        {"JobCode",       type text},
        {"InvoiceNumber", type text}
    }),

    // =====================================================================
    // STEP 2: DENOMINATOR — TOTAL DISTINCT WORK ORDERS PER JOB CODE
    // Used as the divisor when calculating FrequencyPct.
    // =====================================================================
    TotalsByJobCode = Table.Group(
        Jobs_Typed,
        {"JobCode"},
        {{"TotalOrdersWithJobCode",
          each List.Count(List.Distinct([WorkOrder])),
          Int64.Type}}
    ),

    // =====================================================================
    // STEP 3: PARTS FROM InTrans_Incremental
    // In Fabric Dataflow Gen2: Get Data → Fabric Lakehouse → LH_Master_Data
    //   → Table: InTrans_Incremental → keep Branch, RONumber, PartNumber only.
    // Replace the ODBC query below with the Lakehouse connector in Fabric.
    // The Lakehouse column name is RONumber (source column REF_NO).
    // =====================================================================
    SQL_Parts =
        "SELECT DISTINCT
             BRANCH   AS Branch,
             REF_NO   AS InvoiceNumber,
             PART_NO  AS PartNumber
         FROM InTrans
         WHERE PART_NO IS NOT NULL
           AND PART_NO <> ''",

    Parts = Odbc.Query("dsn=EquipRDB64", SQL_Parts),
    Parts_Typed = Table.TransformColumnTypes(Parts, {
        {"Branch",        type text},
        {"InvoiceNumber", type text},
        {"PartNumber",    type text}
    }),

    // =====================================================================
    // STEP 4: JOIN JOBS TO PARTS VIA INVOICE NUMBER + BRANCH
    // ⚠️ JOIN KEY IS INVOICE NUMBER (InvoiceNumber = InvoiceNumber)
    //    Do NOT join on WorkOrder — that produces ~1% of correct rows.
    // =====================================================================
    Joined = Table.NestedJoin(
        Jobs_Typed,  {"InvoiceNumber", "Branch"},
        Parts_Typed, {"InvoiceNumber", "Branch"},
        "Parts",
        JoinKind.Inner
    ),
    Expanded = Table.ExpandTableColumn(Joined, "Parts", {"PartNumber"}),
    WithParts = Table.SelectRows(Expanded,
        each [PartNumber] <> null and [PartNumber] <> ""),

    // =====================================================================
    // STEP 5: NUMERATOR — TIMES EACH PART APPEARED WITH EACH JOB CODE
    // =====================================================================
    FrequencyBase = Table.Group(
        WithParts,
        {"JobCode", "PartNumber"},
        {{"TimesWithPart",
          each List.Count(List.Distinct([WorkOrder])),
          Int64.Type}}
    ),

    // =====================================================================
    // STEP 6: JOIN TOTALS AND CALCULATE FrequencyPct
    // =====================================================================
    WithTotals = Table.NestedJoin(
        FrequencyBase,   {"JobCode"},
        TotalsByJobCode, {"JobCode"},
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
        {"JobCode",                type text},
        {"PartNumber",             type text},
        {"TimesWithPart",          Int64.Type},
        {"TotalOrdersWithJobCode", Int64.Type},
        {"FrequencyPct",           type number}
    })
in
    Final
