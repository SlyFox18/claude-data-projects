/*
============================================================================
FACT_ADJUSTMENTPAIRS - PARTS ADJUSTMENT PAIR MATCHING
============================================================================

Purpose:    Identifies "exact" and "similar" adjustment pairs — cases where
            a negative adjustment on a Part+Branch is matched by a positive
            adjustment (or vice versa) within a 24-month window.
Grain:      One row per matched pair (NegTransId + PosTransId)
Source:     Fact_PartsAdjustments (Lakehouse)
Key logic:  Self-join on Branch + PartNumber, filter DaysBetween <= 730
            Exact = AbsQty matches exactly; Similar = same part+branch, different qty
Notes:      Multiple matches per transaction are intentional — if a part has
            two negatives and three positives in window, that produces 6 pair rows.
            Either transaction can be "first" — time direction is bidirectional.

============================================================================
*/

let
    Source = Fact_PartsAdjustments,

    CutoffDate = DateTime.From(Date.AddMonths(Date.From(DateTime.LocalNow()), -24)),

    Filtered = Table.SelectRows(Source, each [TransDatetime] >= CutoffDate),

    Trimmed = Table.SelectColumns(Filtered, {
        "TransId", "RONumber", "TransDatetime", "Branch",
        "PartNumber", "PartDescription", "Qty", "AbsQty",
        "CostValue", "AbsCost", "PAType"
    }),

    Negatives = Table.SelectRows(Trimmed, each [Qty] < 0),
    Positives = Table.SelectRows(Trimmed, each [Qty] > 0),

    NegRenamed = Table.RenameColumns(Negatives, {
        {"TransId", "NegTransId"},
        {"RONumber", "NegRONumber"},
        {"TransDatetime", "NegDate"},
        {"Qty", "NegQty"},
        {"AbsQty", "NegAbsQty"},
        {"CostValue", "NegCost"},
        {"AbsCost", "NegAbsCost"},
        {"PAType", "NegPAType"}
    }),

    PosRenamed = Table.RenameColumns(Positives, {
        {"TransId", "PosTransId"},
        {"RONumber", "PosRONumber"},
        {"TransDatetime", "PosDate"},
        {"Qty", "PosQty"},
        {"AbsQty", "PosAbsQty"},
        {"CostValue", "PosCost"},
        {"AbsCost", "PosAbsCost"},
        {"PAType", "PosPAType"},
        {"PartDescription", "PosPartDescription"}
    }),

    PosColumns = Table.SelectColumns(PosRenamed, {
        "PosTransId", "PosRONumber", "PosDate", "Branch",
        "PartNumber", "PosQty", "PosAbsQty", "PosCost",
        "PosAbsCost", "PosPAType"
    }),

    Joined = Table.NestedJoin(
        NegRenamed, {"Branch", "PartNumber"},
        PosColumns, {"Branch", "PartNumber"},
        "PosMatch", JoinKind.Inner
    ),

    Expanded = Table.ExpandTableColumn(
        Joined, "PosMatch",
        {"PosTransId", "PosRONumber", "PosDate", "PosQty",
         "PosAbsQty", "PosCost", "PosAbsCost", "PosPAType"},
        {"PosTransId", "PosRONumber", "PosDate", "PosQty",
         "PosAbsQty", "PosCost", "PosAbsCost", "PosPAType"}
    ),

    AddDays = Table.AddColumn(
        Expanded, "DaysBetween",
        each
            let
                d1 = Date.From([NegDate]),
                d2 = Date.From([PosDate]),
                diff = Duration.Days(d2 - d1)
            in
                if diff >= 0 then diff else diff * -1,
        type number
    ),

    FilterWindow = Table.SelectRows(AddDays, each [DaysBetween] <= 730),

    AddWithin12 = Table.AddColumn(
        FilterWindow, "IsWithin12Mo",
        each [DaysBetween] <= 365,
        type logical
    ),

    AddIsExact = Table.AddColumn(
        AddWithin12, "IsExact",
        each [NegAbsQty] = [PosAbsQty],
        type logical
    ),

    AddMatchType = Table.AddColumn(
        AddIsExact, "MatchType",
        each if [IsExact] then "Exact" else "Similar",
        type text
    ),

    AddPairKey = Table.AddColumn(
        AddMatchType, "PairKey",
        each Text.From([NegTransId]) & "-" & Text.From([PosTransId]),
        type text
    ),

    AddLoaded = Table.AddColumn(
        AddPairKey, "LoadedDatetime",
        each DateTime.LocalNow(),
        type datetime
    ),

    TypedResult = Table.TransformColumnTypes(AddLoaded, {
        {"NegTransId",      Int64.Type},
        {"PosTransId",      Int64.Type},
        {"NegRONumber",     type text},
        {"PosRONumber",     type text},
        {"NegDate",         type datetime},
        {"PosDate",         type datetime},
        {"Branch",          type text},
        {"PartNumber",      type text},
        {"PartDescription", type text},
        {"NegQty",          type number},
        {"PosQty",          type number},
        {"NegAbsQty",       type number},
        {"PosAbsQty",       type number},
        {"NegCost",         type number},
        {"PosCost",         type number},
        {"NegAbsCost",      type number},
        {"PosAbsCost",      type number},
        {"NegPAType",       type text},
        {"PosPAType",       type text},
        {"DaysBetween",     type number},
        {"IsWithin12Mo",    type logical},
        {"IsExact",         type logical},
        {"MatchType",       type text},
        {"PairKey",         type text},
        {"LoadedDatetime",  type datetime}
    })

in
    TypedResult