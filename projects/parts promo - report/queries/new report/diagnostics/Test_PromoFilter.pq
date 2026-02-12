/*
============================================================================
DIAGNOSTIC: TEST PROMO PART FILTERING
============================================================================
Purpose: Figure out why Text.StartsWith([PartNumber], "*") only returns 23 rows
when we expect ~12,000+ promo transactions
============================================================================
*/

let
    // SOURCE
    Source = Lakehouse.Contents([HierarchicalNavigation = null]),
    Workspace = Source{[workspaceId = "b48cdb35-7ce3-46de-96df-d70db77649cb"]}[Data],
    Lakehouse = Workspace{[lakehouseId = "3e74497b-8c51-4a1a-91a1-888c59118f48"]}[Data],
    InTrans = Lakehouse{[Id = "InTrans_Incremental", ItemKind = "Table"]}[Data],

    // ========================================================================
    // TEST 1: Get sample of PartNumber values that SHOULD be promos
    // ========================================================================
    // Let's see what part numbers actually look like in the data

    // Get distinct part numbers (sample)
    SamplePartNumbers = Table.FirstN(
        Table.Distinct(
            Table.SelectColumns(InTrans, {"PartNumber"})
        ),
        1000
    ),

    // ========================================================================
    // TEST 2: Try different filtering approaches
    // ========================================================================

    // Approach A: Text.StartsWith with asterisk
    ApproachA = Table.SelectRows(InTrans, each Text.StartsWith([PartNumber], "*")),
    CountA = Table.RowCount(ApproachA),

    // Approach B: Text.Start (first character equals *)
    ApproachB = Table.SelectRows(InTrans, each Text.Start([PartNumber], 1) = "*"),
    CountB = Table.RowCount(ApproachB),

    // Approach C: Text.Contains at position 0
    ApproachC = Table.SelectRows(InTrans, each Text.At([PartNumber], 0) = "*"),
    CountC = Table.RowCount(ApproachC),

    // Approach D: Character code check (asterisk = 42)
    ApproachD = Table.SelectRows(InTrans, each Character.ToNumber(Text.At([PartNumber], 0)) = 42),
    CountD = Table.RowCount(ApproachD),

    // ========================================================================
    // RESULTS TABLE
    // ========================================================================
    Results = #table(
        {"Test", "RowCount"},
        {
            {"A: Text.StartsWith(*, ""*"")", CountA},
            {"B: Text.Start(*, 1) = ""*""", CountB},
            {"C: Text.At(*, 0) = ""*""", CountC},
            {"D: Character code = 42", CountD}
        }
    )

in
    Results

/*
RUN THIS QUERY and tell me:
1. What row counts do you see for each approach?
2. If all are low, the asterisk might be encoded differently

ALTERNATIVE: Run this simpler query to see sample part numbers:

let
    Source = Lakehouse.Contents([HierarchicalNavigation = null]),
    Workspace = Source{[workspaceId = "b48cdb35-7ce3-46de-96df-d70db77649cb"]}[Data],
    Lakehouse = Workspace{[lakehouseId = "3e74497b-8c51-4a1a-91a1-888c59118f48"]}[Data],
    InTrans = Lakehouse{[Id = "InTrans_Incremental", ItemKind = "Table"]}[Data],

    // Get unique part numbers that might be promos
    UniquePartNos = Table.Distinct(Table.SelectColumns(InTrans, {"PartNumber"})),

    // Sort to see if asterisk parts show up
    Sorted = Table.Sort(UniquePartNos, {{"PartNumber", Order.Ascending}})
in
    Sorted

If asterisk parts exist, they should sort to the TOP (before letters/numbers).
*/
