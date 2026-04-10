/*
============================================================================
FACT_ADJPAIRS_SUMMARY - AGGREGATED ADJUSTMENT PAIR SUMMARY
============================================================================

Purpose:    One row per negative adjustment transaction (last 24 months),
            with all matching positive adjustments aggregated into 12Mo
            and 24Mo windows. Transactions with zero matches appear with
            zeros and MatchType = "No Match".
Grain:      One row per TransId where Qty < 0
Source:     Fact_PartsAdjustments (base), Fact_AdjustmentPairs (matches)
Key logic:  Base is ALL negatives from Fact_PartsAdjustments — not derived
            from Fact_AdjustmentPairs — so unmatched transactions are
            included. IsExact = total aggregated positive qty exactly
            equals NegAbsQty (stakeholder confirmed).
            Direction is bidirectional — PosDate can be before NegDate.

============================================================================
*/

let
    // ========================================================================
    // STEP 1: LOAD ALL NEGATIVE TRANSACTIONS FROM FACT TABLE (last 24 months)
    // ========================================================================

    AllAdjustments = Fact_PartsAdjustments,

    CutoffDate = DateTime.From(Date.AddMonths(Date.From(DateTime.LocalNow()), -24)),

    AllNegatives = Table.SelectRows(
        AllAdjustments,
        each [Qty] < 0 and [TransDatetime] >= CutoffDate
    ),

    // ========================================================================
    // STEP 2: TRIM TO NEEDED COLUMNS — this is the base (one row per negative)
    // ========================================================================

    NegDetails = Table.SelectColumns(AllNegatives, {
        "TransId", "RONumber", "TransDatetime", "Branch",
        "PartNumber", "PartDescription", "Qty", "AbsQty",
        "CostValue", "AbsCost", "PAType"
    }),

    NegRenamed = Table.RenameColumns(NegDetails, {
        {"TransId",       "NegTransId"},
        {"RONumber",      "NegRONumber"},
        {"TransDatetime", "NegDate"},
        {"Qty",           "NegQty"},
        {"AbsQty",        "NegAbsQty"},
        {"CostValue",     "NegCost"},
        {"AbsCost",       "NegAbsCost"},
        {"PAType",        "NegPAType"}
    }),

    // ========================================================================
    // STEP 3: LOAD PAIR MATCHES AND AGGREGATE BY 12-MONTH WINDOW
    // ========================================================================

    PairSource = Fact_AdjustmentPairs,

    Pairs12Mo = Table.SelectRows(PairSource, each [IsWithin12Mo] = true),

    Grouped12Mo = Table.Group(
        Pairs12Mo,
        {"NegTransId"},
        {
            {"PosMatchCount_12Mo",   each Table.RowCount(_), type number},
            {"PosTotalAbsQty_12Mo",  each List.Sum([PosAbsQty]), type number},
            {"PosTotalAbsCost_12Mo", each List.Sum([PosAbsCost]), type number}
        }
    ),

    // ========================================================================
    // STEP 4: AGGREGATE 24-MONTH MATCHES
    // ========================================================================

    Grouped24Mo = Table.Group(
        PairSource,
        {"NegTransId"},
        {
            {"PosMatchCount_24Mo",   each Table.RowCount(_), type number},
            {"PosTotalAbsQty_24Mo",  each List.Sum([PosAbsQty]), type number},
            {"PosTotalAbsCost_24Mo", each List.Sum([PosAbsCost]), type number}
        }
    ),

    // ========================================================================
    // STEP 5: LEFT JOIN AGGREGATES ONTO ALL NEGATIVES
    //         Unmatched negatives get nulls → filled with 0 in Step 6
    // ========================================================================

    Joined12Mo = Table.NestedJoin(
        NegRenamed, {"NegTransId"},
        Grouped12Mo, {"NegTransId"},
        "12Mo", JoinKind.LeftOuter
    ),

    Expanded12Mo = Table.ExpandTableColumn(
        Joined12Mo, "12Mo",
        {"PosMatchCount_12Mo", "PosTotalAbsQty_12Mo", "PosTotalAbsCost_12Mo"},
        {"PosMatchCount_12Mo", "PosTotalAbsQty_12Mo", "PosTotalAbsCost_12Mo"}
    ),

    Joined24Mo = Table.NestedJoin(
        Expanded12Mo, {"NegTransId"},
        Grouped24Mo, {"NegTransId"},
        "24Mo", JoinKind.LeftOuter
    ),

    Expanded24Mo = Table.ExpandTableColumn(
        Joined24Mo, "24Mo",
        {"PosMatchCount_24Mo", "PosTotalAbsQty_24Mo", "PosTotalAbsCost_24Mo"},
        {"PosMatchCount_24Mo", "PosTotalAbsQty_24Mo", "PosTotalAbsCost_24Mo"}
    ),

    // ========================================================================
    // STEP 6: REPLACE NULLS — unmatched negatives become 0, not blank
    // ========================================================================

    FillNulls = Table.TransformColumns(
        Expanded24Mo,
        {
            {"PosMatchCount_12Mo",   each if _ = null then 0 else _, type number},
            {"PosTotalAbsQty_12Mo",  each if _ = null then 0 else _, type number},
            {"PosTotalAbsCost_12Mo", each if _ = null then 0 else _, type number},
            {"PosMatchCount_24Mo",   each if _ = null then 0 else _, type number},
            {"PosTotalAbsQty_24Mo",  each if _ = null then 0 else _, type number},
            {"PosTotalAbsCost_24Mo", each if _ = null then 0 else _, type number}
        }
    ),

    // ========================================================================
    // STEP 7: ADD CLASSIFICATION COLUMNS
    // ========================================================================

    AddIsExact12Mo = Table.AddColumn(
        FillNulls, "IsExact_12Mo",
        each [PosMatchCount_12Mo] > 0 and [PosTotalAbsQty_12Mo] = [NegAbsQty],
        type logical
    ),

    AddIsExact24Mo = Table.AddColumn(
        AddIsExact12Mo, "IsExact_24Mo",
        each [PosMatchCount_24Mo] > 0 and [PosTotalAbsQty_24Mo] = [NegAbsQty],
        type logical
    ),

    AddMatchType12Mo = Table.AddColumn(
        AddIsExact24Mo, "MatchType_12Mo",
        each if [PosMatchCount_12Mo] = 0 then "No Match"
             else if [IsExact_12Mo] then "Exact"
             else "Similar",
        type text
    ),

    AddMatchType24Mo = Table.AddColumn(
        AddMatchType12Mo, "MatchType_24Mo",
        each if [PosMatchCount_24Mo] = 0 then "No Match"
             else if [IsExact_24Mo] then "Exact"
             else "Similar",
        type text
    ),

    AddQtyRecovery12Mo = Table.AddColumn(
        AddMatchType24Mo, "QtyRecoveryPct_12Mo",
        each if [NegAbsQty] = 0 then null
             else [PosTotalAbsQty_12Mo] / [NegAbsQty],
        type number
    ),

    AddQtyRecovery24Mo = Table.AddColumn(
        AddQtyRecovery12Mo, "QtyRecoveryPct_24Mo",
        each if [NegAbsQty] = 0 then null
             else [PosTotalAbsQty_24Mo] / [NegAbsQty],
        type number
    ),

    AddLoaded = Table.AddColumn(
        AddQtyRecovery24Mo, "LoadedDatetime",
        each DateTime.LocalNow(),
        type datetime
    ),

    // ========================================================================
    // STEP 8: FINAL TYPES
    // ========================================================================

    TypedResult = Table.TransformColumnTypes(AddLoaded, {
        {"NegTransId",           Int64.Type},
        {"NegRONumber",          type text},
        {"NegDate",              type datetime},
        {"Branch",               type text},
        {"PartNumber",           type text},
        {"PartDescription",      type text},
        {"NegQty",               type number},
        {"NegAbsQty",            type number},
        {"NegCost",              type number},
        {"NegAbsCost",           type number},
        {"NegPAType",            type text},
        {"PosMatchCount_12Mo",   type number},
        {"PosTotalAbsQty_12Mo",  type number},
        {"PosTotalAbsCost_12Mo", type number},
        {"PosMatchCount_24Mo",   type number},
        {"PosTotalAbsQty_24Mo",  type number},
        {"PosTotalAbsCost_24Mo", type number},
        {"IsExact_12Mo",         type logical},
        {"IsExact_24Mo",         type logical},
        {"MatchType_12Mo",       type text},
        {"MatchType_24Mo",       type text},
        {"QtyRecoveryPct_12Mo",  type number},
        {"QtyRecoveryPct_24Mo",  type number},
        {"LoadedDatetime",       type datetime}
    })

in
    TypedResult
