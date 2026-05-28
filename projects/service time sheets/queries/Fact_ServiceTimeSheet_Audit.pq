// ============================================================================
// Fact_ServiceTimeSheet_Audit
// Purpose : Cross-reference submitted service time sheets against what was
//           actually invoiced in the source system. For every RO a tech
//           submits on a time sheet, show the hours and dollars the source
//           system recorded — and surface any discrepancy.
// Grain   : One row per technician per RO per pay period
// Sources : LH_Master_Data.service_time_sheets   (Phase 1 raw)
//           LH_Master_Data.TechnicianInvoiceDetail (Phase 1 raw)
// Output  : LH_Master_Data.Fact_ServiceTimeSheet_Audit
// Pipeline: Phase 4 – Facts (depends on both raw sources above)
//
// Key columns in the output:
//   TotalClaimedHrs  – hours the tech is claiming THIS pay period: CurrentDrawHrs
//                      for standard layout (draw history columns are cross-period and
//                      must NOT be summed); ShopHrs + FieldHrs for shop/field layout
//   InvoicedHrs      – SUM(InvoiceHours) from TechnicianInvoiceDetail for that RO+Tech
//                      null until job codes are invoiced/closed; primary audit comparison
//   PunchedHrs       – SUM(HoursWorked) from TechnicianPunchedDetail for that RO+Tech
//                      ALL clocked hours regardless of invoice status — used to detect
//                      partial invoicing (more punch data exists than billed hours)
//   HoursDifference  – TotalClaimedHrs − InvoicedHrs  (null when InvoicedHrs = null)
//                      positive = tech claimed more than invoiced
//                      negative = invoiced more than claimed (tech may be owed more)
//   TechPay          – TotalClaimedHrs × PayRate  (what payroll owes the tech)
//   LaborBilled      – SUM(LaborSale) from TID    (what was billed to the customer)
//   PaidDifference   – LaborBilled − TechPay
//   AuditStatus      – Six-bucket classification:
//                      "Draw - Open RO"               – InvoicedHrs = null AND tech has formal
//                                                       draw history (Draw1–FinalDraw columns > 0);
//                                                       pay advance on in-progress work — CFO focus
//                      "Pending Invoice"               – InvoicedHrs = null AND no draw history;
//                                                       work submitted (likely complete or first-time
//                                                       claim) but not yet billed — not a draw
//                      "Match"                         – abs(Claimed − Invoiced) < 0.001 hrs (exact)
//                      "Invoiced More Than Claimed"    – system billed more than tech claimed;
//                                                       tech may be owed additional pay
//                      "Partial Invoice - In Progress" – Claimed > Invoiced AND WKROFILE.IsClosed ≠ "Y"
//                                                       AND PunchedHrs shows more work exists;
//                                                       RO still open — more billing expected
//                      "Claimed More Than Invoiced"    – Claimed > Invoiced on a fully-billed RO;
//                                                       genuine discrepancy requiring review
//
// Pay Rate by Tech Level (validate with HR before first production run):
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
    //   TechnicianInvoiceDetail.WorkOrder is already text ("12345" not 12345).
    WithROText = Table.AddColumn(WithTechPay, "RONumberText",
        each Text.From([RONumber]), type text),

    // ── 7. Load TechnicianInvoiceDetail and aggregate to RO + TechCode grain ─
    //   Provides financial columns (InvoicedHrs, LaborBilled, LaborCost).
    //   TID only contains invoiced job codes — open RO operations are absent
    //   until the RO is closed. Use for financial reference, not hours audit.
    TID = TechnicianInvoiceDetail,

    // WorkOrder is a whole number in the source — convert to text to match RONumberText
    TID_Text = Table.TransformColumnTypes(TID, {{"WorkOrder", type text}}),

    TID_Agg = Table.Group(
        TID_Text,
        {"WorkOrder", "TechCode"},
        {
            {"InvoicedHrs",    each List.Sum([InvoiceHours]),              type number},
            {"TotalLaborCost", each List.Sum([LaborCost]),                 type number},
            {"LaborBilled",    each List.Sum([LaborSale]),                 type number},
            {"LastInvoiceDate",each List.Max([InvoiceDate]),               type date},
            {"Branch",         each List.First(List.Sort([Branch])),       type text}
        }
    ),

    // ── 7b. Load TechnicianPunchedDetail and aggregate to RO + TechCode grain ─
    //   HoursWorked captures ALL punch records regardless of invoice status.
    //   Draws are requested against work done, not work invoiced, so this is
    //   the correct comparison point for the pay advance audit.
    TPD = TechnicianPunchedDetail,

    TPD_Agg = Table.Group(
        TPD,
        {"WorkOrder", "TechCode"},
        {
            {"PunchedHrs",  each List.Sum([HoursWorked]),   type number},
            {"Branch_TPD",  each List.First(List.Sort([Branch])), type text}
        }
    ),

    // ── 7c. Load WKROFILE for RO closure status ──────────────────────────────
    //   IsClosed = "Y" is the definitive signal that an RO's billing is final.
    //   When Claimed > Invoiced on a closed RO, the gap is real ("Claimed More").
    //   On open ROs the gap may close as more job codes are invoiced ("Partial").
    WKR = WKROFILE,
    WKR_Status = Table.SelectColumns(WKR, {"WorkOrder", "IsClosed"}),

    // ── 8. Left-join sheets to TID (financial data) then TPD (hours) ─────────
    //   TID join: InvoicedHrs, LaborBilled, LaborCost, LastInvoiceDate, Branch.
    //   TPD join: PunchedHrs — the primary audit comparison column.
    JoinedTID = Table.NestedJoin(
        WithROText,  {"RONumberText", "TechNum"},
        TID_Agg,     {"WorkOrder",    "TechCode"},
        "TIDMatch",  JoinKind.LeftOuter
    ),

    ExpandedTID = Table.ExpandTableColumn(JoinedTID, "TIDMatch", {
        "InvoicedHrs", "TotalLaborCost", "LaborBilled", "LastInvoiceDate", "Branch"
    }),

    JoinedTPD = Table.NestedJoin(
        ExpandedTID, {"RONumberText", "TechNum"},
        TPD_Agg,     {"WorkOrder",    "TechCode"},
        "TPDMatch",  JoinKind.LeftOuter
    ),

    Expanded = Table.ExpandTableColumn(JoinedTPD, "TPDMatch", {"PunchedHrs", "Branch_TPD"}),

    // Resolve Branch: TID value when available (invoiced RO), TPD fallback for open ROs
    WithBranch = Table.RenameColumns(
        Table.RemoveColumns(
            Table.AddColumn(Expanded, "Branch_Final", each [Branch] ?? [Branch_TPD], type text),
            {"Branch", "Branch_TPD"}
        ),
        {{"Branch_Final", "Branch"}}
    ),

    // ── 8b. Join WKROFILE to bring in IsClosed ────────────────────────────────
    JoinedWKR = Table.NestedJoin(
        WithBranch, {"RONumberText"},
        WKR_Status, {"WorkOrder"},
        "WKRMatch",  JoinKind.LeftOuter
    ),
    WithROStatus = Table.ExpandTableColumn(JoinedWKR, "WKRMatch", {"IsClosed"}),

    // ── 9. Audit variance columns ─────────────────────────────────────────────
    //   HoursDifference = Claimed − Invoiced.  Positive means tech claimed more
    //   than was invoiced; negative means more was invoiced than claimed.
    //   Null when InvoicedHrs is null (open RO — no billing exists yet).
    WithHoursDiff = Table.AddColumn(WithROStatus, "HoursDifference", each
        if [InvoicedHrs] <> null
        then [TotalClaimedHrs] - [InvoicedHrs]
        else null,
        type number
    ),

    WithPaidDiff = Table.AddColumn(WithHoursDiff, "PaidDifference", each
        if [LaborBilled] <> null and [TechPay] <> null
        then [LaborBilled] - [TechPay]
        else null,
        type number
    ),

    // ── 10. Audit status classification ──────────────────────────────────────
    //   Six-bucket logic (evaluated in order):
    //   1. InvoicedHrs = null AND formal draw history exists → Draw - Open RO
    //      "Draw history" = any of Draw1–FinalDraw columns has a value > 0.
    //      A tech taking a draw advance fills in the Draw date + hours columns;
    //      a tech submitting completed work only fills in CurrentDrawHrs.
    //   2. InvoicedHrs = null AND no draw history → Pending Invoice
    //      Work was submitted (likely complete or first-time claim) but not yet
    //      billed and not a formal multi-period draw advance.
    //   3. Within 0.001 hr tolerance → Match (exact)
    //   4. Invoiced > Claimed → Invoiced More Than Claimed (tech may be owed more)
    //   5. Claimed > Invoiced AND IsClosed ≠ "Y" AND PunchedHrs > InvoicedHrs × 1.1
    //      → Partial Invoice: RO still open, more billing expected
    //   6. Claimed > Invoiced otherwise → Claimed More Than Invoiced (genuine flag)
    WithStatus = Table.AddColumn(WithPaidDiff, "AuditStatus", each
        let
            hasDraw = ([Draw1Hrs] <> null and [Draw1Hrs] > 0)
                   or ([Draw2Hrs] <> null and [Draw2Hrs] > 0)
                   or ([Draw3Hrs] <> null and [Draw3Hrs] > 0)
                   or ([FinalDrawHrs] <> null and [FinalDrawHrs] > 0)
        in
            if   [InvoicedHrs] = null and hasDraw
                then "Draw - Open RO"
            else if [InvoicedHrs] = null
                then "Pending Invoice"
            else if Number.Abs([HoursDifference] ?? 0) < 0.001
                then "Match"
            else if ([HoursDifference] ?? 0) < 0
                then "Invoiced More Than Claimed"
            else if [IsClosed] <> "Y"
                and [PunchedHrs] <> null
                and [PunchedHrs] > ([InvoicedHrs] * 1.1)
                then "Partial Invoice - In Progress"
            else
                "Claimed More Than Invoiced",
        type text
    ),

    // ── 11. Select and order final columns ────────────────────────────────────
    Selected = Table.SelectColumns(WithStatus, {
        // — Source system context —
        "Branch",
        // — Location and pay period —
        "Location", "PayPeriod", "PayStart", "PayEnd",
        // — Technician identity —
        "TechName", "TechNum", "TechLevel", "PayRate", "TechNameFromTab",
        // — RO identity —
        "CustomerName", "Model", "RONumber", "RONumberText", "PctComplete",
        // — Service sheet hours (what the tech submitted) —
        "Draw1Hrs", "Draw2Hrs", "Draw3Hrs", "FinalDrawHrs",
        "CurrentDrawHrs", "ShopHrs", "FieldHrs",
        "TotalClaimedHrs",
        "AfterHours", "Mileage",
        // — Tech pay (based on claim) —
        "TechPay",
        // — Source system hours and dollars —
        "InvoicedHrs", "PunchedHrs", "TotalLaborCost", "LaborBilled",
        "LastInvoiceDate",
        // — RO closure status —
        "IsClosed",
        // — Audit variance —
        "HoursDifference", "PaidDifference", "AuditStatus",
        // — Lineage —
        "SourceFile"
    }),

    // ── 12. Final column types ────────────────────────────────────────────────
    Typed = Table.TransformColumnTypes(Selected, {
        {"Branch",          type text},
        {"Location",        type text},
        {"PayPeriod",       type text},
        {"PayStart",        type date},
        {"PayEnd",          type date},
        {"TechName",        type text},
        {"TechNum",         type text},
        {"TechLevel",       type text},
        {"PayRate",         type number},
        {"TechNameFromTab", type text},
        {"CustomerName",    type text},
        {"Model",           type text},
        {"RONumber",        type number},
        {"RONumberText",    type text},
        {"PctComplete",     type number},
        {"Draw1Hrs",        type number},
        {"Draw2Hrs",        type number},
        {"Draw3Hrs",        type number},
        {"FinalDrawHrs",    type number},
        {"CurrentDrawHrs",  type number},
        {"ShopHrs",         type number},
        {"FieldHrs",        type number},
        {"TotalClaimedHrs", type number},
        {"AfterHours",      type number},
        {"Mileage",         type number},
        {"TechPay",         type number},
        {"InvoicedHrs",     type number},
        {"PunchedHrs",      type number},
        {"TotalLaborCost",  type number},
        {"LaborBilled",     type number},
        {"LastInvoiceDate", type date},
        {"IsClosed",        type text},
        {"HoursDifference", type number},
        {"PaidDifference",  type number},
        {"AuditStatus",     type text},
        {"SourceFile",      type text}
    }),

    // ── 13. Load timestamp ────────────────────────────────────────────────────
    WithTimestamp = Table.AddColumn(Typed, "LoadTimestamp",
        each DateTimeZone.RemoveZone(DateTimeZone.UtcNow()), type datetime)

in
    WithTimestamp
