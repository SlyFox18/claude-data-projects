/*
============================================================================
DIAGNOSTIC: Count promo rows using different filter methods
============================================================================
*/

let
    // SOURCE
    Source = Lakehouse.Contents([HierarchicalNavigation = null]),
    Workspace = Source{[workspaceId = "b48cdb35-7ce3-46de-96df-d70db77649cb"]}[Data],
    Lakehouse = Workspace{[lakehouseId = "3e74497b-8c51-4a1a-91a1-888c59118f48"]}[Data],
    InTrans = Lakehouse{[Id = "InTrans_Incremental", ItemKind = "Table"]}[Data],

    // METHOD 1: Just filter for PartNumber starting with * (no other conditions)
    Method1 = Table.SelectRows(InTrans, each Text.StartsWith([PartNumber], "*")),

    // Get row count
    Count1 = Table.RowCount(Method1),

    // Also get a sample of the filtered data
    Sample = Table.FirstN(Method1, 50)

in
    Sample

/*
This query removes ALL other filters (no date, no franchise filter)
to see how many promo rows exist total.

If this returns thousands of rows, the issue is with the additional filters.
If this returns only ~23 rows, the issue is with Text.StartsWith itself.
*/
