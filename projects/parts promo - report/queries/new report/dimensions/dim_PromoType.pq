/*
============================================================================
DIM_PROMOTYPE - PROMOTIONAL PART TYPES DIMENSION
============================================================================

📋 TABLE OVERVIEW:
Purpose: Dimension table for promotional part types (parts starting with *)
Grain: One row per unique promo part number
Refresh Strategy: Full refresh (small table, ~50 rows)
Source Dependencies: InTrans_Incremental, jdis_Part_Information (via dim_Parts)

🎯 BUSINESS USE CASES:
• Promo Categorization: Group similar promos (*DISCOUNT, *10OFF10, etc.)
• Promo Analysis: Compare effectiveness by promo type
• Filtering: Easy slicer for promo types in reports
• Trending: Track which promo types are used over time

📊 DATA STRUCTURE:

**Primary Key:**
• PromoPartNo: The promo part number (e.g., *ACE, *DISCOUNT)

**Attributes:**
• PromoDescription: Actual part description from jdis_Part_Information
• PromoCategory: Derived category for grouping similar promos

🔗 RELATIONSHIPS:
• PromoPartNo → Fact_PartsPromo[PART_NO]

============================================================================
*/

let
    // ========================================================================
    // SOURCE: Lakehouse InTrans_Incremental + jdis_Part_Information
    // ========================================================================
    Source = Lakehouse.Contents([HierarchicalNavigation = null]),
    Workspace = Source{[workspaceId = "b48cdb35-7ce3-46de-96df-d70db77649cb"]}[Data],
    Lakehouse = Workspace{[lakehouseId = "3e74497b-8c51-4a1a-91a1-888c59118f48"]}[Data],
    InTrans = Lakehouse{[Id = "InTrans_Incremental", ItemKind = "Table"]}[Data],

    // Get part descriptions from jdis_Part_Information
    PartInfo = Lakehouse{[Id = "jdis_Part_Information", ItemKind = "Table"]}[Data],
    PartDescriptions = Table.SelectColumns(
        Table.Distinct(PartInfo, {"PartNumber"}),
        {"PartNumber", "Description"}
    ),

    // ========================================================================
    // STEP 1: FILTER TO PROMO PARTS ONLY
    // ========================================================================
    /*
    NOTE: Do NOT filter out ZP franchise!
    Promo parts typically HAVE Franchise = 'ZP' - that's how they're coded in the system.
    */
    FilterToPromos = Table.SelectRows(InTrans, each
        Text.StartsWith([PartNumber], "*")
    ),

    // ========================================================================
    // STEP 2: GET UNIQUE PROMO PART NUMBERS WITH USAGE STATS
    // ========================================================================
    UniquePromos = Table.Group(
        FilterToPromos,
        {"PartNumber"},
        {
            {"FirstSeen", each List.Min([TransDatetime]), type datetime},
            {"LastSeen", each List.Max([TransDatetime]), type datetime},
            {"UsageCount", each Table.RowCount(_), Int64.Type}
        }
    ),

    // ========================================================================
    // STEP 3: JOIN WITH PART INFORMATION FOR ACTUAL DESCRIPTIONS
    // ========================================================================
    /*
    NOTE: The Description in InTrans is usually the customer name, not the part description.
    The actual promo description is in jdis_Part_Information.
    */
    JoinPartInfo = Table.NestedJoin(
        UniquePromos, {"PartNumber"},
        PartDescriptions, {"PartNumber"},
        "PartInfo", JoinKind.LeftOuter
    ),

    ExpandPartInfo = Table.ExpandTableColumn(
        JoinPartInfo, "PartInfo",
        {"Description"},
        {"PromoDescription"}
    ),

    // ========================================================================
    // STEP 4: ADD PROMO CATEGORY (Derived grouping)
    // ========================================================================
    /*
    PURPOSE: Group similar promos for easier analysis
    LOGIC: Based on common patterns in promo part names
    */
    AddPromoCategory = Table.AddColumn(ExpandPartInfo, "PromoCategory", each
        if Text.Contains([PartNumber], "DISCOUNT") then "General Discount"
        else if Text.Contains([PartNumber], "OFF") then "Percentage Off"
        else if Text.Contains([PartNumber], "PROMO") then "Promotional"
        else if Text.Contains([PartNumber], "ACE") then "ACE Program"
        else if Text.Contains([PartNumber], "HARVEST") or Text.Contains([PartNumber], "HAY") or
                Text.Contains([PartNumber], "PLANTER") or Text.Contains([PartNumber], "TILLAGE") then "Seasonal/Equipment"
        else if Text.Contains([PartNumber], "GREASE") or Text.Contains([PartNumber], "LIGHT") or
                Text.Contains([PartNumber], "NOZZLE") or Text.Contains([PartNumber], "BLADES") then "Parts/Consumables"
        else if Text.Contains([PartNumber], "PICK") or Text.Contains([PartNumber], "COTTON") or
                Text.Contains([PartNumber], "COMBINE") then "Harvest Equipment"
        else "Other",
        type text
    ),

    // ========================================================================
    // STEP 5: RENAME AND SELECT FINAL COLUMNS
    // ========================================================================
    RenameColumns = Table.RenameColumns(AddPromoCategory, {
        {"PartNumber", "PromoPartNo"}
    }),

    FinalColumns = Table.SelectColumns(RenameColumns, {
        "PromoPartNo",
        "PromoDescription",
        "PromoCategory",
        "FirstSeen",
        "LastSeen",
        "UsageCount"
    }),

    // ========================================================================
    // STEP 6: SET DATA TYPES
    // ========================================================================
    SetTypes = Table.TransformColumnTypes(FinalColumns, {
        {"PromoPartNo", type text},
        {"PromoDescription", type text},
        {"PromoCategory", type text},
        {"FirstSeen", type datetime},
        {"LastSeen", type datetime},
        {"UsageCount", Int64.Type}
    }),

    // Sort by usage count (most used first)
    SortedTable = Table.Sort(SetTypes, {{"UsageCount", Order.Descending}})

in
    SortedTable
