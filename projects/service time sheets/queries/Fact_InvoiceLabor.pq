// ============================================================================
// Fact_InvoiceLabor
// Purpose : Invoice-driven labor reconciliation. Starting from closed work orders
//           in TechnicianInvoiceDetail, compares labor billed to customers against
//           draw pay submitted by technicians. Includes WOs where no time sheet
//           was submitted (HasTimeSheet = FALSE).
// Grain   : One row per TechCode per closed WorkOrder
// Sources : LH_Master_Data.TechnicianInvoiceDetail (Phase 1 raw)
//           LH_Master_Data.WKROFILE                (Phase 1 raw)
//           LH_Master_Data.service_time_sheets      (Phase 1 raw)
//           LH_Master_Data.dim_CustomerList         (Phase 3 dimension)
// Output  : LH_Master_Data.Fact_InvoiceLabor
// Pipeline: Phase 4 – Facts (depends on all raw sources and dim_CustomerList)
//
// This is the REVERSE of Fact_ServiceTimeSheet_Audit:
//   Fact_ServiceTimeSheet_Audit  — starts from submitted sheets, finds matching invoices
//   Fact_InvoiceLabor            — starts from closed invoices, finds matching sheets
//
// Key columns in the output:
//   InvoiceDate          – max InvoiceDate across TID rows for this WorkOrder+TechCode.
//   InvoiceNumber        – invoice number from TID (typically one per WorkOrder)
//   CustomerName         – display name from dim_CustomerList (via WKROFILE AccountNumber)
//   CustomerTypeDesc     – Retail / Fleet / Internal / Warranty / etc.
//   IsKeyCustomer        – key account flag from dim_CustomerList
//   IsFieldService       – field vs shop service from WKROFILE
//   ClosedDate           – WO closure date from WKROFILE
//   InvoicedHrs          – SUM(InvoiceHours) from TID for this TechCode on this WorkOrder
//   LaborBilled          – SUM(LaborSale) from TID — what the customer was billed
//   LaborCost            – SUM(LaborCost) from TID — system cost basis
//   TotalClaimedHrs      – SUM of claimed hours across ALL pay period submissions for this
//                          RO+TechCode (each draw is incremental, so summing is correct)
//   TechPay              – SUM of tech draw pay across all pay periods. Total draw dollars
//                          paid for this RO.
//   HasTimeSheet         – FALSE when no time sheet submission exists for this TechCode+WO.
//                          Includes hourly/SM employees (never submit sheets) and commission
//                          techs who forgot to submit.
//   LaborGap             – LaborBilled − TechPay. Positive = company retained the difference.
//   ReconciliationStatus – Five-bucket classification:
//                            "No Draw Expected"  — TechLevel null (SM/hourly, no commission)
//                            "Missing Sheet"     — Commission tech, no sheet submitted
//                            "Match"             — |ClaimedHrs − InvoicedHrs| ≤ 0.001
//                            "Overclaimed"       — ClaimedHrs > InvoicedHrs + 0.001
//                            "Underclaimed"      — ClaimedHrs < InvoicedHrs − 0.001
//
// Pay Rate by Tech Level (keep in sync with Fact_ServiceTimeSheet_Audit):
//   Level 3 = $40/hr
//   Level 4 = $43/hr
//   Level 5 = $46/hr
// ============================================================================

let
    // ── 1. TechnicianInvoiceDetail — aggregate to WorkOrder+TechCode grain ────
    //   Convert WorkOrder to text so it joins cleanly to the text-keyed sheet data.
    TID = TechnicianInvoiceDetail,
    TID_Text = Table.TransformColumnTypes(TID, {{"WorkOrder", type text}}),

    // Limit to invoices from 2026-01-01 forward — historical data pre-dates this report
    TID_Filtered = Table.SelectRows(TID_Text, each [InvoiceDate] >= #date(2026, 1, 1)),

    TID_Agg = Table.Group(
        TID_Filtered,
        {"WorkOrder", "TechCode"},
        {
            {"InvoicedHrs",         each List.Sum([InvoiceHours]),                          type number},
            {"LaborCost",           each List.Sum([LaborCost]),                             type number},
            {"LaborBilled",         each List.Sum([LaborSale]),                             type number},
            {"InvoiceDate",         each List.Max([InvoiceDate]),                           type date},
            {"InvoiceNumber",       each List.First(List.Distinct([InvoiceNumber])),        type text},
            {"Branch",              each List.First(List.Sort([Branch])),                   type text},
            {"JobTypeList",         each Text.Combine(List.Sort(List.Distinct([JobType])), ", "), type text},
            {"HasMultipleJobTypes", each List.Count(List.Distinct([JobType])) > 1,          type logical}
        }
    ),

    // ── 2. Filter to closed WOs only ─────────────────────────────────────────
    //   IsClosed = "Y" in WKROFILE is the definitive signal that billing is final.
    //   Only closed WOs are included so the comparison is against settled amounts.
    WKR = WKROFILE,
    WKR_Typed = Table.TransformColumnTypes(WKR, {{"WorkOrder", type text}}),
    WKR_Closed = Table.SelectRows(WKR_Typed, each [IsClosed] = "Y"),

    //   (a) LeftSemi join — filter TID_Agg to closed WOs only.
    //   Rename the key to avoid duplicate-column error on the join.
    WKR_WO_Keyed = Table.RenameColumns(
        Table.SelectColumns(WKR_Closed, {"WorkOrder"}),
        {{"WorkOrder", "_WKR_WO"}}
    ),
    TID_Closed = Table.Join(
        TID_Agg,      {"WorkOrder"},
        WKR_WO_Keyed, {"_WKR_WO"},
        JoinKind.LeftSemi
    ),

    //   (b) LeftOuter join — pull WKROFILE context columns onto each closed-WO row.
    //   AccountNumber (CHARGE_ACCT) is the customer account key used for dim lookup.
    WKR_Context = Table.SelectColumns(WKR_Closed, {
        "WorkOrder", "AccountNumber", "IsFieldService", "ClosedDate"
    }),
    TID_WithWKR = Table.NestedJoin(
        TID_Closed,  {"WorkOrder"},
        WKR_Context, {"WorkOrder"},
        "_WKRCtx", JoinKind.LeftOuter
    ),
    TID_ExpandWKR = Table.ExpandTableColumn(TID_WithWKR, "_WKRCtx", {
        "AccountNumber", "IsFieldService", "ClosedDate"
    }),

    //   Convert AccountNumber to text for the dim_CustomerList lookup.
    //   Route through Int64.From to strip any decimal suffix (e.g. "51200.0" → "51200")
    //   that Text.From produces when AccountNumber is stored as Decimal in the Lakehouse.
    WithAccountText = Table.AddColumn(TID_ExpandWKR, "AccountNumberText",
        each
            let n = try Int64.From([AccountNumber])
            in if n[HasError] or [AccountNumber] = null then null else Text.From(n[Value]),
        type text),

    // ── 3. service_time_sheets — aggregate to WorkOrder+TechCode grain ────────
    //   For each (RONumber, TechNum), sum TotalClaimedHrs and TechPay across ALL
    //   pay periods. Each pay period row is an incremental draw, so summing is correct.
    Sheets = service_time_sheets,
    Sheets_Text = Table.TransformColumnTypes(Sheets, {{"RONumber", type text}}),

    //   Compute this period's claimed hours using same logic as Fact_ServiceTimeSheet_Audit.
    Sheets_WithClaimed = Table.AddColumn(Sheets_Text, "_ClaimedHrs", each
        let
            cur   = [CurrentDrawHrs],
            shop  = [ShopHrs] ?? 0,
            field = [FieldHrs] ?? 0,
            after = [AfterHours] ?? 0
        in
            ((if cur <> null then cur else shop + field) ?? 0) + after,
        type number
    ),

    //   Compute this period's tech draw pay from claimed hours × pay rate.
    Sheets_WithPay = Table.AddColumn(Sheets_WithClaimed, "_TechPayPeriod", each
        let
            rate =
                if Text.Trim([TechLevel] ?? "") = "3" then 40
                else if Text.Trim([TechLevel] ?? "") = "4" then 43
                else if Text.Trim([TechLevel] ?? "") = "5" then 46
                else null
        in
            if rate <> null then [_ClaimedHrs] * rate else null,
        type number
    ),

    //   Aggregate: sum claimed hours and pay across all pay periods per RO+Tech.
    Sheets_Agg = Table.Group(
        Sheets_WithPay,
        {"RONumber", "TechNum"},
        {
            {"TechName",        each List.First([TechName]),        type text},
            {"TechLevel",       each List.First([TechLevel]),       type text},
            {"Location",        each List.First([Location]),        type text},
            {"TotalClaimedHrs", each List.Sum([_ClaimedHrs]),       type number},
            {"TechPay",         each List.Sum([_TechPayPeriod]),    type number},
            {"LatestPayEnd",    each List.Max([PayEnd]),            type date}
        }
    ),

    // ── 4. Left join sheets to closed invoices ────────────────────────────────
    //   LeftOuter keeps all TID rows — WOs with no time sheet appear with
    //   null in the sheet columns and HasTimeSheet = FALSE.
    Joined = Table.NestedJoin(
        WithAccountText, {"WorkOrder", "TechCode"},
        Sheets_Agg,      {"RONumber",  "TechNum"},
        "_SheetMatch", JoinKind.LeftOuter
    ),
    Expanded = Table.ExpandTableColumn(Joined, "_SheetMatch", {
        "TechName", "TechLevel", "Location", "TotalClaimedHrs", "TechPay", "LatestPayEnd"
    }),

    // ── 5. Customer lookup — dim_CustomerList via WKROFILE AccountNumber ─────
    //   dim_CustomerList.AccountNumberText matches WKROFILE.AccountNumber (as text).
    //   Brings in customer display name, type, and key account flag.
    CustDim = dim_CustomerList,
    CustDim_Slim = Table.SelectColumns(CustDim, {
        "AccountNumberText", "CustomerName", "CustomerTypeDescription", "IsKeyCustomer"
    }),
    WithCustomer = Table.NestedJoin(
        Expanded,     {"AccountNumberText"},
        CustDim_Slim, {"AccountNumberText"},
        "_CustInfo", JoinKind.LeftOuter
    ),
    ExpandCustomer = Table.ExpandTableColumn(WithCustomer, "_CustInfo", {
        "CustomerName", "CustomerTypeDescription", "IsKeyCustomer"
    }),

    // ── 6. Derived columns ────────────────────────────────────────────────────
    WithHasSheet = Table.AddColumn(ExpandCustomer, "HasTimeSheet",
        each [TotalClaimedHrs] <> null, type logical),

    //   LaborGap: what the customer paid vs. what the tech received in draws.
    //   Positive = billed more than paid (company retained the difference).
    //   Null TechPay rows treated as $0 — no draw was paid for this work.
    WithGap = Table.AddColumn(WithHasSheet, "LaborGap",
        each ([LaborBilled] ?? 0) - ([TechPay] ?? 0), type number),

    //   ReconciliationStatus — five-bucket classification for row-level audit.
    //   Evaluated in priority order:
    //     1. Non-commission techs (SM/hourly) → "No Draw Expected"
    //     2. Commission tech with no sheet   → "Missing Sheet"
    //     3. Claimed ≈ Invoiced (±0.001)     → "Match"
    //     4. Claimed > Invoiced              → "Overclaimed"
    //     5. Claimed < Invoiced              → "Underclaimed"
    WithStatus = Table.AddColumn(WithGap, "ReconciliationStatus", each
        let
            techLevel    = Text.Trim([TechLevel] ?? ""),
            isCommission = List.Contains({"3", "4", "5"}, techLevel),
            hasSheet     = [HasTimeSheet],
            diff         = ([TotalClaimedHrs] ?? 0) - ([InvoicedHrs] ?? 0)
        in
            if not isCommission              then "No Draw Expected"
            else if not hasSheet             then "Missing Sheet"
            else if Number.Abs(diff) <= 0.001 then "Match"
            else if diff > 0.001             then "Overclaimed"
            else                                  "Underclaimed",
        type text),

    // ── 7. Select and order final columns ─────────────────────────────────────
    Selected = Table.SelectColumns(WithStatus, {
        // — Invoice reference —
        "InvoiceDate", "InvoiceNumber", "WorkOrder",
        // — Branch context —
        "Branch",
        // — Customer identity (from dim_CustomerList via WKROFILE AccountNumber) —
        "CustomerName", "CustomerTypeDescription", "IsKeyCustomer",
        // — Technician identity (from sheets when available) —
        "TechCode", "TechName", "TechLevel", "Location",
        // — Work order context (from WKROFILE) —
        "IsFieldService", "ClosedDate",
        // — Invoice financials (from TID) —
        "InvoicedHrs", "LaborCost", "LaborBilled",
        // — Time sheet financials (from sheets, null if no submission) —
        "TotalClaimedHrs", "TechPay", "LatestPayEnd",
        // — Reconciliation —
        "HasTimeSheet", "LaborGap", "ReconciliationStatus",
        // — Job type context —
        "JobTypeList", "HasMultipleJobTypes"
    }),

    // ── 8. Final column types ─────────────────────────────────────────────────
    Typed = Table.TransformColumnTypes(Selected, {
        {"InvoiceDate",             type date},
        {"InvoiceNumber",           type text},
        {"WorkOrder",               type text},
        {"Branch",                  type text},
        {"CustomerName",            type text},
        {"CustomerTypeDescription", type text},
        {"IsKeyCustomer",           type logical},
        {"TechCode",                type text},
        {"TechName",                type text},
        {"TechLevel",               type text},
        {"Location",                type text},
        {"IsFieldService",          type text},
        {"ClosedDate",              type date},
        {"InvoicedHrs",             type number},
        {"LaborCost",               type number},
        {"LaborBilled",             type number},
        {"TotalClaimedHrs",         type number},
        {"TechPay",                 type number},
        {"LatestPayEnd",            type date},
        {"HasTimeSheet",            type logical},
        {"LaborGap",                type number},
        {"ReconciliationStatus",    type text},
        {"JobTypeList",             type text},
        {"HasMultipleJobTypes",     type logical}
    }),

    // ── 9. Load timestamp ─────────────────────────────────────────────────────
    WithTimestamp = Table.AddColumn(Typed, "LoadTimestamp",
        each DateTimeZone.RemoveZone(DateTimeZone.UtcNow()), type datetime)

in
    WithTimestamp
