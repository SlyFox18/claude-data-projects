// ============================================================================
// Fact_ServiceTimeSheet_Audit
// Purpose : Cross-reference submitted service time sheets against what was
//           actually invoiced in the source system. For every RO a tech
//           submits on a time sheet, show the hours and dollars the source
//           system recorded — and surface any discrepancy.
// Grain   : One row per technician per RO per pay period
// Sources : LH_Master_Data.service_time_sheets    (Phase 1 raw)
//           LH_Master_Data.TechnicianInvoiceDetail (Phase 1 raw)
//           LH_Master_Data.TechnicianPunchedDetail  (Phase 1 raw)
//           LH_Master_Data.WKROFILE                (Phase 1 raw)
// Output  : LH_Master_Data.Fact_ServiceTimeSheet_Audit
// Pipeline: Phase 4 – Facts (depends on all raw sources above)
//
// Key columns in the output:
//   TotalClaimedHrs   – hours the tech is claiming THIS pay period: CurrentDrawHrs
//                       for standard layout (draw history columns are cross-period and
//                       must NOT be summed); ShopHrs + FieldHrs for shop/field layout
//   InvoicedHrs       – full RO invoiced hours credited to this commission tech:
//                       their own TechCode hours PLUS any hourly/trainee TechCode
//                       hours on the same WorkOrder that have no commission submission.
//                       A commission tech who trains an hourly employee is credited
//                       with all RO hours since the hourly tech never submits a sheet.
//                       Null until any job codes on the RO are invoiced/closed.
//   HourlyInvoicedHrs – the trainee-only portion of InvoicedHrs.  Zero/null when no
//                       hourly employee punched time on this RO.
//   HasHourlyTrainee  – TRUE when one or more non-commission TechCodes contributed
//                       invoiced hours to this WorkOrder.
//   PunchedHrs        – SUM(HoursWorked) from TechnicianPunchedDetail for the
//                       commission tech's TechCode only.  Used to detect partial
//                       invoicing (more punch data exists than billed hours).
//   CrossPeriodClaimedHrs – SUM(TotalClaimedHrs) across ALL pay period rows for
//                       this WO+TechCode. Used in AuditStatus and HoursDifference
//                       so a multi-draw RO compares the cumulative claim rather than
//                       just the current period's draw against the invoice total.
//   HoursDifference   – CrossPeriodClaimedHrs − InvoicedHrs  (null when InvoicedHrs = null)
//                       positive = tech's total cross-period claim exceeds invoiced hours
//                       negative = invoiced more than claimed (tech may be owed more)
//   DrawNumber        – which draw this row is for this WO+TechCode (1 = first, etc.)
//   TotalDraws        – total pay period submissions for this WO+TechCode
//   TechPay           – TotalClaimedHrs × PayRate  (what payroll owes the tech this period)
//   LaborBilled       – SUM(LaborSale) for ALL TechCodes on the WorkOrder,
//                       matching the InvoicedHrs treatment above
//   PaidDifference    – LaborBilled − (CrossPeriodClaimedHrs × PayRate)
//                       Uses cross-period claimed so multi-draw rows show the net
//                       billing gap across ALL draws, not just the current period's pay.
//   AuditStatus       – Seven-bucket classification:
//                       "Draw - Open RO"               – InvoicedHrs = null AND formal draw history
//                       "Pending Invoice"               – InvoicedHrs = null AND no draw history
//                       "Draw - In Progress"            – PctComplete < 1 (< 100%, stored as decimal fraction)
//                       "Match"                         – abs(CrossPeriod − Invoiced) < 0.001 hrs
//                       "Invoiced More Than Claimed"    – CrossPeriod < Invoiced
//                       "Partial Invoice - In Progress" – CrossPeriod > Invoiced AND RO open
//                                                        AND PunchedHrs shows more work exists
//                       "Claimed More Than Invoiced"    – CrossPeriod > Invoiced otherwise
//
//   Hourly trainee detection — a TechCode in TechnicianInvoiceDetail is treated as
//   hourly/trainee for a given WorkOrder when it does NOT appear in service_time_sheets
//   as a TechNum claiming that same WorkOrder.  This is self-calibrating: when a trainee
//   is promoted and begins submitting their own sheets, their hours automatically stay
//   separate with no configuration change required.
//
// Pay Rate by Tech Level (validate with HR before each production run):
//   Level 3 = $40/hr
//   Level 4 = $43/hr
//   Level 5 = $46/hr
//   SM      = null  (service managers do not receive draw pay)
// ============================================================================

let
    // ── 1. Pay rate lookup ────────────────────────────────────────────────────
    PayRates = #table(
        type table [Level = text, PayRate = number],
        {{"3", 40}, {"4", 43}, {"5", 46}}
    ),

    // ── 2. Load service time sheets from Lakehouse ───────────────────────────
    //   In Fabric Dataflow Gen2 this table reference is created via the
    //   "Get data → Lakehouse" connector in the UI.  The query name you give
    //   that source step will appear here as a named query reference.
    Sheets = service_time_sheets,

    // Pre-compute cross-period aggregations directly from raw Sheets.
    // Both fold to SQL (GROUP BY SUM/COUNT) because they start from the raw
    // source before any AddColumn step breaks query folding. Keeping them here
    // as independent branches ensures the TID/TPD/WKR joins below stay in SQL.
    _CrossPeriodAgg = Table.Group(
        Table.AddColumn(Sheets, "_c", each
            ((if [CurrentDrawHrs] <> null then [CurrentDrawHrs] else ([ShopHrs] ?? 0) + ([FieldHrs] ?? 0)) ?? 0)
            + ([AfterHours] ?? 0)
        ),
        {"RONumber", "TechNum"},
        {{"CrossPeriodClaimedHrs", each List.Sum([_c]), type number}}
    ),
    _TotalDrawsCounts = Table.Group(
        Sheets,
        {"RONumber", "TechNum"},
        {{"TotalDraws", each Table.RowCount(_), Int64.Type}}
    ),

    // ── 3. Compute total claimed hours for this pay period ───────────────────
    //   CurrentDrawHrs (column 13) is the ONLY amount being claimed this period.
    //   Draw1–FinalDraw are a historical log across all pay periods — some draws
    //   may already have been paid in previous periods, so they must NOT be summed.
    //   Shop/field layout stores ShopHrs+FieldHrs in columns 13-14 instead.
    WithClaimedHrs = Table.AddColumn(Sheets, "TotalClaimedHrs", each
        let
            cur   = [CurrentDrawHrs],
            shop  = [ShopHrs]  ?? 0,
            field = [FieldHrs] ?? 0,
            after = [AfterHours] ?? 0,
            drawHrs =
                if cur <> null then cur
                else shop + field
        in
            (drawHrs ?? 0) + after,
        type number
    ),

    // ── 4. Look up pay rate from tech level ──────────────────────────────────
    WithPayRate = Table.AddColumn(WithClaimedHrs, "PayRate", each
        let
            level = Text.Trim([TechLevel] ?? ""),
            match = Table.SelectRows(PayRates, each [Level] = level)
        in
            if Table.RowCount(match) > 0 then match{0}[PayRate] else null,
        type number
    ),

    // ── 5. Compute tech pay (claimed hours × rate) ───────────────────────────
    WithTechPay = Table.AddColumn(WithPayRate, "TechPay", each
        if [PayRate] <> null and [TotalClaimedHrs] <> null
        then [TotalClaimedHrs] * [PayRate]
        else null,
        type number
    ),

    // ── 6. Convert RONumber to text for the join key ─────────────────────────
    //   TechnicianInvoiceDetail.WorkOrder is int64 in the source — convert to
    //   text so both sides of every join use the same type.
    WithROText = Table.AddColumn(WithTechPay, "RONumberText",
        each Text.From([RONumber]), type text),

    // ── 7. TechnicianInvoiceDetail — split commission vs hourly/trainee ──────
    //
    //   Strategy: build the set of (WorkOrder, TechCode) pairs that have a
    //   commission sheet submission, then split TID into two groups:
    //     • Commission rows — TechCode submitted a sheet for this WorkOrder
    //     • Hourly/trainee rows — TechCode punched time but did NOT submit
    //
    //   Commission rows aggregate by (WorkOrder, TechCode) as before.
    //   Hourly/trainee rows aggregate by WorkOrder only so their hours roll up
    //   to the commission tech who IS claiming that RO.

    // Set of (WorkOrder→text, TechNum) pairs with a commission submission
    CommissionPairs = Table.Distinct(
        Table.SelectColumns(
            Table.TransformColumnTypes(Sheets, {{"RONumber", type text}}),
            {"RONumber", "TechNum"}
        )
    ),

    TID = TechnicianInvoiceDetail,

    // WorkOrder is int64 in the source — convert to text to match RONumberText
    TID_Text = Table.TransformColumnTypes(TID, {{"WorkOrder", type text}}),

    // Aggregate TID to (WorkOrder, TechCode) grain FIRST — GROUP BY folds to SQL and
    // reduces TechnicianInvoiceDetail from millions of rows to thousands of groups
    // before any join against CommissionPairs touches it.
    TID_All_Agg = Table.Group(
        TID_Text,
        {"WorkOrder", "TechCode"},
        {
            {"InvoicedHrs",    each List.Sum([InvoiceHours]),          type number},
            {"TotalLaborCost", each List.Sum([LaborCost]),             type number},
            {"LaborBilled",    each List.Sum([LaborSale]),             type number},
            {"LastInvoiceDate",each List.Max([InvoiceDate]),                           type date},
            {"InvoiceNumber",         each List.First(List.Distinct([InvoiceNumber])),              type text},
            {"Branch",                each List.First(List.Sort([Branch])),                          type text},
            {"JobTypeList",           each Text.Combine(List.Sort(List.Distinct([JobType])), ", "),  type text},
            {"HasMultipleJobTypes",   each List.Count(List.Distinct([JobType])) > 1,                 type logical}
        }
    ),

    // Commission split — LeftSemi keeps aggregated rows where (WorkOrder, TechCode)
    // has a matching submission. No nested table column created; folds to SQL EXISTS.
    TID_Commission_Agg = Table.Join(
        TID_All_Agg, {"WorkOrder", "TechCode"},
        CommissionPairs, {"RONumber", "TechNum"},
        JoinKind.LeftSemi
    ),

    // Hourly/trainee split — LeftAnti keeps aggregated rows with NO commission submission.
    // Folds to SQL NOT EXISTS / LEFT JOIN WHERE NULL.
    TID_Hourly_Pre = Table.Join(
        TID_All_Agg, {"WorkOrder", "TechCode"},
        CommissionPairs, {"RONumber", "TechNum"},
        JoinKind.LeftAnti
    ),

    // Re-aggregate hourly rows to WorkOrder grain.
    // Column names reference TID_All_Agg output names (already renamed above).
    TID_Hourly_Agg = Table.Group(
        TID_Hourly_Pre,
        {"WorkOrder"},
        {
            {"HourlyInvoicedHrs", each List.Sum([InvoicedHrs]),    type number},
            {"HourlyLaborCost",   each List.Sum([TotalLaborCost]), type number},
            {"HourlyLaborBilled", each List.Sum([LaborBilled]),    type number}
        }
    ),

    // WO-level branch — join by WorkOrder only so the WO's branch is known even
    // when the submitted WO# is wrong (human error) and the TechCode join misses.
    TID_WO_Branch_Agg = Table.Group(
        TID_Text,
        {"WorkOrder"},
        {{"WOBranch", each List.First(List.Sort([Branch])), type text}}
    ),

    // ── 7b. TechnicianPunchedDetail ──────────────────────────────────────────
    //   PunchedHrs is aggregated for the commission tech's TechCode only.
    //   Used to detect partial invoicing on open ROs.
    TPD = TechnicianPunchedDetail,

    TPD_Agg = Table.Group(
        TPD,
        {"WorkOrder", "TechCode"},
        {
            {"PunchedHrs",  each List.Sum([HoursWorked]),           type number},
            {"Branch_TPD",  each List.First(List.Sort([Branch])),   type text}
        }
    ),

    // ── 7c. WKROFILE for RO closure status ───────────────────────────────────
    //   IsClosed = "Y" is the definitive signal that billing is final.
    //   When Claimed > Invoiced on a closed RO, the gap is genuine.
    //   On open ROs the gap may close as more job codes are invoiced.
    WKR = WKROFILE,
    WKR_Status = Table.SelectColumns(WKR, {"WorkOrder", "IsClosed"}),

    // ── 8a. Commission TID join ───────────────────────────────────────────────
    //   Brings in the commission tech's own invoiced hours and dollars.
    JoinedTID = Table.NestedJoin(
        WithROText,         {"RONumberText", "TechNum"},
        TID_Commission_Agg, {"WorkOrder",    "TechCode"},
        "TIDMatch",         JoinKind.LeftOuter
    ),
    ExpandedTID = Table.ExpandTableColumn(JoinedTID, "TIDMatch", {
        "InvoicedHrs", "TotalLaborCost", "LaborBilled", "LastInvoiceDate", "InvoiceNumber", "Branch", "JobTypeList", "HasMultipleJobTypes"
    }),

    // ── 8b. Hourly/trainee TID join ──────────────────────────────────────────
    //   Joined by WorkOrder only — no TechCode filter.
    //   Brings in the hours and dollars that belong to non-commission TechCodes
    //   on the same RO so they can be credited to the commission tech.
    JoinedHourly = Table.NestedJoin(
        ExpandedTID,    {"RONumberText"},
        TID_Hourly_Agg, {"WorkOrder"},
        "HourlyMatch",  JoinKind.LeftOuter
    ),
    ExpandedHourly = Table.ExpandTableColumn(JoinedHourly, "HourlyMatch", {
        "HourlyInvoicedHrs", "HourlyLaborCost", "HourlyLaborBilled"
    }),

    // ── 8c. Combine commission and hourly financial columns ───────────────────
    //   HasHourlyTrainee = TRUE when hourly TechCodes contributed invoiced hours.
    //   Null semantics preserved: InvoicedHrs stays null only when NO invoicing
    //   exists at all for this RO (open RO, not yet billed).
    WithTraineeFlag = Table.AddColumn(ExpandedHourly, "HasHourlyTrainee",
        each ([HourlyInvoicedHrs] ?? 0) > 0, type logical),

    WithCombinedInvoiced = Table.AddColumn(WithTraineeFlag, "InvoicedHrs_Combined", each
        let
            comm   = [InvoicedHrs],
            hourly = [HourlyInvoicedHrs] ?? 0
        in
            if comm = null and hourly = 0 then null
            else (comm ?? 0) + hourly,
        type number
    ),

    WithCombinedLaborCost = Table.AddColumn(WithCombinedInvoiced, "TotalLaborCost_Combined",
        each ([TotalLaborCost] ?? 0) + ([HourlyLaborCost] ?? 0), type number),

    WithCombinedLaborBilled = Table.AddColumn(WithCombinedLaborCost, "LaborBilled_Combined",
        each ([LaborBilled] ?? 0) + ([HourlyLaborBilled] ?? 0), type number),

    // Swap originals for combined totals; keep HourlyInvoicedHrs for transparency
    WithSwapped = Table.RenameColumns(
        Table.RemoveColumns(WithCombinedLaborBilled, {
            "InvoicedHrs", "TotalLaborCost", "LaborBilled",
            "HourlyLaborCost", "HourlyLaborBilled"
        }),
        {
            {"InvoicedHrs_Combined",    "InvoicedHrs"},
            {"TotalLaborCost_Combined", "TotalLaborCost"},
            {"LaborBilled_Combined",    "LaborBilled"}
        }
    ),

    // ── 8d. TPD join (commission tech only) ──────────────────────────────────
    JoinedTPD = Table.NestedJoin(
        WithSwapped, {"RONumberText", "TechNum"},
        TPD_Agg,     {"WorkOrder",    "TechCode"},
        "TPDMatch",  JoinKind.LeftOuter
    ),
    Expanded = Table.ExpandTableColumn(JoinedTPD, "TPDMatch", {"PunchedHrs", "Branch_TPD"}),

    // Resolve Branch: commission TID value when available, TPD fallback for open ROs
    WithBranch = Table.RenameColumns(
        Table.RemoveColumns(
            Table.AddColumn(Expanded, "Branch_Final", each [Branch] ?? [Branch_TPD], type text),
            {"Branch", "Branch_TPD"}
        ),
        {{"Branch_Final", "Branch"}}
    ),

    // ── 8e. WO branch join ───────────────────────────────────────────────────
    //   Joins TID by WorkOrder only — gives the branch where the WO was actually
    //   serviced, independent of whether the submitted TechCode matches.
    //   Needed for WOBranchMismatch detection when a wrong WO# was entered.
    JoinedWOBranch = Table.NestedJoin(
        WithBranch,         {"RONumberText"},
        TID_WO_Branch_Agg,  {"WorkOrder"},
        "WOBranchMatch",    JoinKind.LeftOuter
    ),
    WithWOBranch = Table.ExpandTableColumn(JoinedWOBranch, "WOBranchMatch", {"WOBranch"}),

    // ── 8f. WKROFILE join ────────────────────────────────────────────────────
    JoinedWKR = Table.NestedJoin(
        WithWOBranch, {"RONumberText"},
        WKR_Status,   {"WorkOrder"},
        "WKRMatch",   JoinKind.LeftOuter
    ),
    WithROStatus = Table.ExpandTableColumn(JoinedWKR, "WKRMatch", {"IsClosed"}),

    // Join CrossPeriodClaimedHrs and TotalDraws back — pre-aggregated from raw
    // Sheets above so they folded to SQL. Joined here, after all TID/TPD/WKR
    // work is done, so the expensive branches never interact with in-memory data.
    WithCrossPeriod = Table.ExpandTableColumn(
        Table.NestedJoin(
            WithROStatus,    {"RONumber", "TechNum"},
            _CrossPeriodAgg, {"RONumber", "TechNum"},
            "_CP", JoinKind.LeftOuter
        ),
        "_CP", {"CrossPeriodClaimedHrs"}
    ),
    WithTotalDraws = Table.ExpandTableColumn(
        Table.NestedJoin(
            WithCrossPeriod,   {"RONumber", "TechNum"},
            _TotalDrawsCounts, {"RONumber", "TechNum"},
            "_DC", JoinKind.LeftOuter
        ),
        "_DC", {"TotalDraws"}
    ),

    // ── 9. Audit variance columns ─────────────────────────────────────────────
    //   HoursDifference = CrossPeriodClaimedHrs − InvoicedHrs (full RO total).
    //   Positive = tech's cumulative cross-period claim exceeds invoiced hours.
    //   Negative = RO was invoiced for more than the tech claimed.
    //   Null when InvoicedHrs is null (no billing exists yet).
    WithHoursDiff = Table.AddColumn(WithTotalDraws, "HoursDifference", each
        if [InvoicedHrs] <> null
        then ([CrossPeriodClaimedHrs] ?? 0) - [InvoicedHrs]
        else null,
        type number
    ),

    WithPaidDiff = Table.AddColumn(WithHoursDiff, "PaidDifference", each
        let
            crossTechPay = ([CrossPeriodClaimedHrs] ?? 0) * ([PayRate] ?? 0)
        in
            if [LaborBilled] <> null and crossTechPay <> null
            then [LaborBilled] - crossTechPay
            else null,
        type number
    ),

    // ── 10. Audit status classification ──────────────────────────────────────
    //   Seven-bucket logic (evaluated in order):
    //   1. InvoicedHrs = null AND formal draw history → Draw - Open RO
    //   2. InvoicedHrs = null AND no draw history     → Pending Invoice
    //   3. PctComplete < 1 (i.e. < 100%)               → Draw - In Progress
    //        (tech still taking partial draws — defer audit until final draw)
    //        Note: PctComplete is stored as a decimal fraction (1.0 = 100%)
    //   4. abs(CrossPeriod − Invoiced) < 0.001        → Match
    //   5. CrossPeriod < Invoiced                     → Invoiced More Than Claimed
    //   6. CrossPeriod > Invoiced AND RO open AND PunchedHrs > Invoiced × 1.1
    //                                                 → Partial Invoice - In Progress
    //   7. CrossPeriod > Invoiced otherwise           → Claimed More Than Invoiced
    //
    //   Buckets 4-7 use CrossPeriodClaimedHrs (sum across ALL pay periods for this
    //   WO+TechCode) so a multi-draw RO correctly resolves to Match on the final
    //   draw rather than showing "Invoiced More" on every partial draw row.
    WithStatus = Table.AddColumn(WithPaidDiff, "AuditStatus", each
        let
            hasDraw = ([Draw1Hrs] <> null and [Draw1Hrs] > 0)
                   or ([Draw2Hrs] <> null and [Draw2Hrs] > 0)
                   or ([Draw3Hrs] <> null and [Draw3Hrs] > 0)
                   or ([FinalDrawHrs] <> null and [FinalDrawHrs] > 0),
            crossHrs = [CrossPeriodClaimedHrs] ?? 0,
            invHrs   = [InvoicedHrs] ?? 0
        in
            if   [InvoicedHrs] = null and hasDraw
                then "Draw - Open RO"
            else if [InvoicedHrs] = null
                then "Pending Invoice"
            else if [PctComplete] <> null and [PctComplete] < 1
                then "Draw - In Progress"
            else if Number.Abs(crossHrs - invHrs) < 0.001
                then "Match"
            else if crossHrs < invHrs
                then "Invoiced More Than Claimed"
            else if [IsClosed] <> "Y"
                and [PunchedHrs] <> null
                and [PunchedHrs] > (invHrs * 1.1)
                then "Partial Invoice - In Progress"
            else
                "Claimed More Than Invoiced",
        type text
    ),

    // DrawNumber: rank each row within its WO+TechNum by PayStart/PayPeriod.
    // Done LAST — after all SQL joins are complete — so the fold-breaking
    // group-within-group only runs on the small in-memory result set.
    _DrawGroups = Table.Group(
        WithStatus,
        {"RONumber", "TechNum"},
        {{"_Rows", each
            Table.AddIndexColumn(
                Table.Sort(_, {{"PayStart", Order.Ascending}, {"PayPeriod", Order.Ascending}}),
                "DrawNumber", 1, 1, Int64.Type
            ),
         type table}}
    ),
    WithDrawNum = Table.Combine(_DrawGroups[_Rows]),

    // ── 11. Select and order final columns ────────────────────────────────────
    Selected = Table.SelectColumns(WithDrawNum, {
        // — Source system context —
        "Branch", "WOBranch",
        // — Location and pay period —
        "Location", "PayPeriod", "PayStart", "PayEnd",
        // — Technician identity —
        "TechName", "TechNum", "TechLevel", "PayRate", "TechNameFromTab",
        // — RO identity —
        "CustomerName", "Model", "RONumber", "RONumberText", "PctComplete",
        // — Service sheet hours (what the tech submitted) —
        "Draw1Hrs", "Draw2Hrs", "Draw3Hrs", "FinalDrawHrs",
        "CurrentDrawHrs", "ShopHrs", "FieldHrs",
        "TotalClaimedHrs", "CrossPeriodClaimedHrs",
        "DrawNumber", "TotalDraws",
        "AfterHours", "Mileage",
        // — Tech pay (based on claim) —
        "TechPay",
        // — Source system hours and dollars —
        "InvoicedHrs", "HourlyInvoicedHrs", "HasHourlyTrainee",
        "PunchedHrs", "TotalLaborCost", "LaborBilled",
        "LastInvoiceDate",
        // — Invoice reference —
        "InvoiceNumber",
        // — Job type context —
        "JobTypeList", "HasMultipleJobTypes",
        // — RO closure status —
        "IsClosed",
        // — Audit variance —
        "HoursDifference", "PaidDifference", "AuditStatus",
        // — Lineage —
        "SourceFile"
    }),

    // ── 12. Final column types ────────────────────────────────────────────────
    Typed = Table.TransformColumnTypes(Selected, {
        {"Branch",            type text},
        {"WOBranch",          type text},
        {"Location",          type text},
        {"PayPeriod",         type text},
        {"PayStart",          type date},
        {"PayEnd",            type date},
        {"TechName",          type text},
        {"TechNum",           type text},
        {"TechLevel",         type text},
        {"PayRate",           type number},
        {"TechNameFromTab",   type text},
        {"CustomerName",      type text},
        {"Model",             type text},
        {"RONumber",          type number},
        {"RONumberText",      type text},
        {"PctComplete",       type number},
        {"Draw1Hrs",          type number},
        {"Draw2Hrs",          type number},
        {"Draw3Hrs",          type number},
        {"FinalDrawHrs",      type number},
        {"CurrentDrawHrs",    type number},
        {"ShopHrs",           type number},
        {"FieldHrs",          type number},
        {"TotalClaimedHrs",         type number},
        {"CrossPeriodClaimedHrs",   type number},
        {"DrawNumber",              Int64.Type},
        {"TotalDraws",              Int64.Type},
        {"AfterHours",              type number},
        {"Mileage",           type number},
        {"TechPay",           type number},
        {"InvoicedHrs",       type number},
        {"HourlyInvoicedHrs", type number},
        {"HasHourlyTrainee",  type logical},
        {"PunchedHrs",        type number},
        {"TotalLaborCost",    type number},
        {"LaborBilled",       type number},
        {"LastInvoiceDate",   type date},
        {"InvoiceNumber",       type text},
        {"JobTypeList",         type text},
        {"HasMultipleJobTypes", type logical},
        {"IsClosed",            type text},
        {"HoursDifference",   type number},
        {"PaidDifference",    type number},
        {"AuditStatus",       type text},
        {"SourceFile",        type text}
    }),

    // ── 13. Load timestamp ────────────────────────────────────────────────────
    WithTimestamp = Table.AddColumn(Typed, "LoadTimestamp",
        each DateTimeZone.RemoveZone(DateTimeZone.UtcNow()), type datetime)

in
    WithTimestamp
