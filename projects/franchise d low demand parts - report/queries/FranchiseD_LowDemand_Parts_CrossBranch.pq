/*
============================================================================
Query: Franchise D — Low Demand Parts with Cross-Branch Activity
Type: Ad-hoc Excel Analysis (Power Query Advanced Editor)
Connection: ODBC — dsn=EquipRDB64
Source Tables: InTrans (demand), jdis_Part_Information (part attributes)
============================================================================

PURPOSE:
Identifies Franchise D parts at a given branch with low local demand but
meaningful demand across all other branches combined. Surfaces stocking
opportunities — parts that are clearly moving in the system but are
under-stocked or inactive at specific locations.

HOW DEMAND IS CALCULATED:
  A "demand" = one InTrans row where:
    - TYPE = 'I'   (customer invoice — excludes transfers, adjustments, returns)
    - QTY  > 0     (outbound sale to customer)
    - Trans_Datetime within the last 18 months
  This counts actual transaction events, not pre-aggregated pi_sales_request_XX
  buckets (which are approximate).

CRITERIA (adjustable):
  - Franchise:              D         (change FRANCHISE = 'D' in WHERE)
  - Excluded branches:      2, 4      (change BRANCH NOT IN list in WHERE)
  - Local demand threshold: < 3       (change [Demands] < 3 in filter step)
  - Other branch threshold: >= 10     (change [OtherBranchDemands] >= 10)
  - Time window:            18 months (change DATEADD month value in WHERE)

PART FILTERS (from jdis_Part_Information):
  - On Order = 0            Only parts with no outstanding purchase orders
  - Package Qty = 1         Only individually-stocked parts (not bundled)
  - Return Indicator = 'R'  Only returnable parts

OUTPUT COLUMNS:
  Branch             — Branch where local demand is below threshold
  PartNumber         — Part number
  Description        — Manufacturer part description (from jdis)
  Cost               — Standard cost (pi_Cost)
  Source             — Source code (pi_Source)
  SLC                — Stock Level Classification (pi_SLC)
  CommodityCode      — Commodity code (pi_Commodity_Code)
  DealerGroupCode    — Dealer group code (pi_Dealer_Group_Code)
  Demands            — This branch's 18-month transaction count
  OtherBranchDemands — Combined 18-month transaction count at all other branches
                       (branches 2 & 4 excluded from this total)
  OtherLocationCount — Number of other branches that have demand for this part

NOTES:
  - Description comes from jdis_Part_Information (pi_Description).
    InTrans DESCRIPTION is a customer/notation field, not the part description.
  - INNER JOIN to jdis ensures all part filters are applied. Parts with no
    jdis record are excluded (cannot verify Package Qty, Return Indicator, etc.)
  - Branches 2 & 4 are excluded from both local demand AND OtherBranchDemands,
    so they do not influence either side of the comparison.
  - Run during off-peak hours (before 7 AM or after 5 PM) — InTrans is large.

LAST RUN: 2026-06-08
REQUESTED BY: Corp Parts Manager
============================================================================

Power Query M — paste into Excel Advanced Editor:
*/

let
    // SQL aggregates InTrans demand per branch/part and joins jdis for attributes.
    // INNER JOIN (not LEFT) because we filter on jdis columns — parts missing
    // from jdis cannot be validated and are correctly excluded.
    // Branches 2 & 4 excluded in WHERE so they affect neither side of the output.
    SQL = "
        SELECT
            i.BRANCH,
            i.PART_NO                       AS PartNumber,
            MAX(p.pi_Description)           AS Description,
            MAX(p.pi_Cost)                  AS Cost,
            MAX(p.pi_Source)                AS Source,
            MAX(p.pi_SLC)                   AS SLC,
            MAX(p.pi_Commodity_Code)        AS CommodityCode,
            MAX(p.pi_Dealer_Group_Code)     AS DealerGroupCode,
            COUNT(*)                        AS Demands
        FROM InTrans i
        INNER JOIN jdis_Part_Information p
            ON  p.pi_Branch  = i.BRANCH
            AND p.pi_Part_No = i.PART_NO
        WHERE
            i.FRANCHISE = 'D'
            AND i.TYPE = 'I'
            AND i.QTY > 0
            AND i.BRANCH NOT IN ('2', '4')
            AND i.Trans_Datetime >= DATEADD(month, -18, GETDATE())
            AND COALESCE(p.pi_On_Order, 0) = 0
            AND p.pi_Package_Qty = 1
            AND p.pi_Return_Indicator = 'R'
        GROUP BY
            i.BRANCH,
            i.PART_NO
    ",
    Source = Odbc.Query("dsn=EquipRDB64", SQL),

    // Enforce correct data types from SQL results
    Typed = Table.TransformColumnTypes(Source, {
        {"BRANCH",          type text},
        {"PartNumber",      type text},
        {"Description",     type text},
        {"Cost",            type number},
        {"Source",          type text},
        {"SLC",             type text},
        {"CommodityCode",   type text},
        {"DealerGroupCode", type text},
        {"Demands",         Int64.Type}
    }),

    // Total demand AND branch count per PartNumber across all non-excluded branches.
    // BranchCount = number of rows in the group = number of branches with any demand.
    TotalByPart = Table.Group(Typed, {"PartNumber"}, {
        {"TotalDemand", each List.Sum([Demands]),  Int64.Type},
        {"BranchCount", each Table.RowCount(_),    Int64.Type}
    }),

    // Join totals back onto each branch row
    Joined   = Table.NestedJoin(Typed, {"PartNumber"}, TotalByPart,
                   {"PartNumber"}, "T", JoinKind.LeftOuter),
    Expanded = Table.ExpandTableColumn(Joined, "T", {"TotalDemand", "BranchCount"}),

    // OtherBranchDemands = system total minus this branch's demand
    WithOther = Table.AddColumn(Expanded, "OtherBranchDemands",
        each [TotalDemand] - [Demands], Int64.Type),

    // OtherLocationCount = branches with demand for this part, minus this branch.
    // Since every row in the output has Demands >= 1 (COUNT(*) can't produce 0),
    // subtracting 1 always gives the correct count of OTHER branches.
    WithLocationCount = Table.AddColumn(WithOther, "OtherLocationCount",
        each [BranchCount] - 1, Int64.Type),

    // Filter: local demand < 3 AND combined other-branch demand >= 10
    Filtered = Table.SelectRows(WithLocationCount, each
        [Demands] < 3 and [OtherBranchDemands] >= 10),

    // Final output — drop intermediate columns
    Final = Table.SelectColumns(Filtered, {
        "BRANCH", "PartNumber", "Description", "Cost",
        "Source", "SLC", "CommodityCode", "DealerGroupCode",
        "Demands", "OtherBranchDemands", "OtherLocationCount"
    }),

    Renamed = Table.RenameColumns(Final, {{"BRANCH", "Branch"}}),

    Sorted = Table.Sort(Renamed, {
        {"PartNumber", Order.Ascending},
        {"Branch",     Order.Ascending}
    })

in
    Sorted
