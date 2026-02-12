/*
============================================================================
SIMPLE DIAGNOSTIC: Check if asterisk promo parts exist in Lakehouse
============================================================================
*/

let
    // SOURCE
    Source = Lakehouse.Contents([HierarchicalNavigation = null]),
    Workspace = Source{[workspaceId = "b48cdb35-7ce3-46de-96df-d70db77649cb"]}[Data],
    Lakehouse = Workspace{[lakehouseId = "3e74497b-8c51-4a1a-91a1-888c59118f48"]}[Data],
    InTrans = Lakehouse{[Id = "InTrans_Incremental", ItemKind = "Table"]}[Data],

    // Get distinct PartNumbers and sort them
    // Asterisk (*) should sort BEFORE letters, so promo parts should be at top
    UniquePartNos = Table.Distinct(Table.SelectColumns(InTrans, {"PartNumber"})),
    Sorted = Table.Sort(UniquePartNos, {{"PartNumber", Order.Ascending}}),

    // Take first 100 to see what's at the top
    First100 = Table.FirstN(Sorted, 100)

in
    First100

/*
WHAT TO LOOK FOR:
- If promo parts (*ACE, *FOS, *DISCOUNT, etc.) appear at the top, they exist
- If the list starts with numbers or letters (no asterisks), promos may not be in Lakehouse

The old report shows these promo parts:
*10PROMO, *FOS, *PLANTER, *TILLAGE, *HARVEST, *10OFF10, *DISCOUNT, *HAY, *TOY, *BLADES, *DRILL, *HYP
*/
