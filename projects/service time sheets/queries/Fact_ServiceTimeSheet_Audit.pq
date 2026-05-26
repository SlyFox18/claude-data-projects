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
//   TotalClaimedHrs  – hours the tech reported on the time sheet (CurrentDrawHrs
//                      for standard layout; ShopHrs + FieldHrs for shop/field)
//   InvoicedHrs      – SUM(InvoiceHours) from TechnicianInvoiceDetail for that RO+Tech
//   HoursDifference  – InvoicedHrs − TotalClaimedHrs
//                      positive = invoiced more than claimed
//                      negative = tech claimed more than invoiced
//   TechPay          – TotalClaimedHrs × PayRate  (what payroll owes the tech)
//   LaborBilled      – SUM(LaborSale) from TID    (what was billed to the customer)
//   PaidDifference   – LaborBilled − TechPay
//   AuditStatus      – "Match" / "Claimed More Than Invoiced" /
//                      "Invoiced More Than Claimed" / "Pending — Not Yet Invoiced"
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
    //   CurrentDrawHrs and ShopHrs/FieldHrs are mutually exclusive — the raw
    //   query sets the missing layout's columns to null via MissingField.UseNull.
    //   We use whichever is present.
    WithClaimedHrs = Table.AddColumn(Sheets, "TotalClaimedHrs", each
        let
            cur   = [CurrentDrawHrs],
            shop  = [ShopHrs],
            field = [FieldHrs],
            after = [AfterHours] ?? 0,
            drawHrs =
                if cur <> null then cur
                else (shop ?? 0) + (field ?? 0)
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
    //   This collapses the per-punch detail rows into a single row per
    //   (work order, technician) to match the service sheet grain.
    TID = TechnicianInvoiceDetail,

    // WorkOrder is a whole number in the source — convert to text to match RONumberText
    TID_Text = Table.TransformColumnTypes(TID, {{"WorkOrder", type text}}),

    TID_Agg = Table.Group(
        TID_Text,
        {"WorkOrder", "TechCode", "Branch"},
        {
            {"InvoicedHrs",    each List.Sum([InvoiceHours]),  type number},
            {"PunchedHrs",     each List.Sum([HoursPunched]),  type number},
            {"TotalLaborCost", each List.Sum([LaborCost]),     type number},
            {"LaborBilled",    each List.Sum([LaborSale]),     type number},
            {"LastInvoiceDate",each List.Max([InvoiceDate]),   type date}
        }
    ),

    // ── 8. Left-join sheets to aggregated TID ────────────────────────────────
    //   Left join keeps all sheet rows.
    //   - If InvoicedHrs is null → work not yet invoiced in the source system.
    //   - Branch comes from TID (the source system's numeric branch code).
    Joined = Table.NestedJoin(
        WithROText,  {"RONumberText", "TechNum"},
        TID_Agg,     {"WorkOrder",    "TechCode"},
        "TIDMatch",  JoinKind.LeftOuter
    ),

    Expanded = Table.ExpandTableColumn(Joined, "TIDMatch", {
        "InvoicedHrs", "PunchedHrs", "TotalLaborCost",
        "LaborBilled", "LastInvoiceDate", "Branch"
    }),

    // ── 9. Audit variance columns ─────────────────────────────────────────────
    WithHoursDiff = Table.AddColumn(Expanded, "HoursDifference", each
        if [InvoicedHrs] <> null
        then [InvoicedHrs] - [TotalClaimedHrs]
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
    WithStatus = Table.AddColumn(WithPaidDiff, "AuditStatus", each
        if   [InvoicedHrs] = null                          then "Pending - Not Yet Invoiced"
        else if Number.Abs([HoursDifference] ?? 0) < 0.01 then "Match"
        else if ([HoursDifference] ?? 0) > 0               then "Invoiced More Than Claimed"
        else                                                     "Claimed More Than Invoiced",
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
