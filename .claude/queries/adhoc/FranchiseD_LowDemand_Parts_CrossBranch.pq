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
    - Trans_Datetime between 7 days ago and 18 months ago (excludes the most
      recent week so very recent activity doesn't mask a true low-demand branch)
  This counts actual transaction events, not pre-aggregated pi_sales_request_XX
  buckets (which are approximate).

  Candidate branches (7, 14, 95, 91, 96) with ZERO qualifying demand for a
  part still appear with Demands = 0, as long as jdis shows that branch
  carries the part (passes the PART FILTERS below). A candidate branch used
  to just be missing from the output instead of showing up with a 0 — which
  hid exactly the "never stocked here at all" case this report exists to
  surface. This zero-fill only applies to the 5 candidate branches; the
  broader other-branch universe is unaffected (see NOTES).

CRITERIA (adjustable):
  - Franchise:              D            (change FRANCHISE = 'D' in WHERE)
  - Candidate branches:     7,14,95,91,96 (the ONLY branches eligible to be
                             flagged as the low-demand "local" branch —
                             change the List.Contains(...) set in Filtered,
                             AND the two BRANCH IN (...) lists in SQL)
  - Other-branch universe:  excludes 2, 4 (change BRANCH NOT IN list in WHERE —
                             this defines the pool used for OtherBranchDemands,
                             separate from which branches can be flagged)
  - Local demand threshold: < 3          (change [Demands] < 3 in filter step)
  - Other branch threshold: >= 10        (change [OtherBranchDemands] >= 10)
  - Other location count:   >= 5         (change [OtherLocationCount] >= 5)
  - On-hand threshold:      < 1          (local branch only — change [OnHandQty] < 1)
  - Excluded source:        AN           (change p.pi_Source <> 'AN' in WHERE)
  - Excluded SLC prefixes:  21, 90, 91, 99 (any sub-code, e.g. 21A/21B/21C —
                             change the NOT LIKE list in WHERE)
  - Time window:            7 days – 18 months (change DATEADD values in WHERE)

PART FILTERS (from jdis_Part_Information):
  - On Order = 0            Only parts with no outstanding purchase orders
  - Package Qty = 1         Only individually-stocked parts (not bundled)
  - Return Indicator = 'R'  Only returnable parts
  - Source <> 'AN'          Excludes Source code "AN"
  - SLC NOT LIKE 21%/90%/91%/99%  Excludes these SLC families (any sub-code)

OUTPUT COLUMNS:
  Branch             — Branch where local demand is below threshold (always
                       one of the candidate branches: 7, 14, 95, 91, 96)
  PartNumber         — Part number
  Description        — Manufacturer part description (from jdis)
  Cost               — Standard cost (pi_Cost)
  Source             — Source code (pi_Source)
  SLC                — Stock Level Classification (pi_SLC)
  CommodityCode      — Commodity code (pi_Commodity_Code)
  CommodityGroup     — Business-defined group name for the commodity code
                       (e.g. Sprayer, Toys, Tillage) from the SharePoint lookup
                       CSV; "Other" if the code isn't in a group yet
  DealerGroupCode    — Dealer group code (pi_Dealer_Group_Code)
  OnOrder            — Outstanding purchase-order quantity (pi_On_Order) — always 0
                       here since it's also a filter criterion; shown for visibility
  OnHandQty          — Local branch's on-hand quantity (pi_On_Hand_Qty), always < 1
  Demands            — This branch's transaction count (7 days – 18 months back),
                       0 if no qualifying local sales
  OtherBranchDemands — Combined transaction count at all other branches
                       (branches 2 & 4 excluded from this total; NOT limited
                       to the 5 candidate branches)
  OtherLocationCount — Number of OTHER branches with actual demand (Demands > 0)
                       for this part — branches with zero demand don't count
                       toward this, whether it's this row or another row

NOTES:
  - Description comes from jdis_Part_Information (pi_Description).
    InTrans DESCRIPTION is a customer/notation field, not the part description.
  - The SQL is a UNION ALL of two parts:
      1. The original demand-driven pull — INNER JOIN InTrans to jdis, GROUP BY
         branch/part — covering every branch except 2 & 4 (not just the 5
         candidates). This is what feeds OtherBranchDemands/OtherLocationCount
         and also supplies candidate-branch rows that DO have demand.
      2. A zero-fill pull — jdis rows for the 5 candidate branches only, for
         parts that qualify (via the same part-filter + qualifying-parts
         criteria) but have NO matching InTrans row (NOT EXISTS), emitted
         with Demands = 0.
    Part 2 exists specifically so a candidate branch that has never sold a
    qualifying part still shows up instead of being silently dropped.
  - INNER JOIN to jdis in part 1 (and the WHERE filters in part 2) ensures
    all part filters are applied. Parts with no jdis record are excluded
    (cannot verify Package Qty, Return Indicator, etc.)
  - Branch scope is ASYMMETRIC by design:
      * The candidate (local) branch must be one of 7, 14, 95, 91, 96.
      * OtherBranchDemands/OtherLocationCount are computed against the broader
        pool of all branches except 2 & 4 (NOT restricted to the 5 candidates).
    This is why the branch restriction lives in the post-aggregation Filtered
    step (via List.Contains), not solely in the SQL WHERE — part 2's
    candidate-only WHERE clause is just how zero-fill rows are generated, it
    doesn't change what Filtered ultimately allows through.
  - OnHandQty is likewise local-branch-only. It is pulled back as a plain
    column (not filtered in SQL WHERE) so it never reduces the pool of rows
    used to compute OtherBranchDemands for other branches.
  - Source and SLC exclusions ARE applied broadly in the SQL WHERE (like the
    other part filters) — these remove the branch/part row from the analysis
    entirely, on both the local and other-branch sides. They're applied in
    both UNION ALL parts to stay consistent.
  - BranchCount (used for OtherLocationCount) counts only branches with
    Demands > 0 — not just any row in the group — since zero-fill rows now
    exist in the data and shouldn't count as "having demand."
  - CommodityGroup is pulled from CommodityCodeGroups.csv on SharePoint
    (SouthPlainsImplement-ReportSite) — the same source-of-truth file used by
    the shared dim_CommodityCode Fabric dataflow. Update that one file to
    relabel/add codes for both this query and the Fabric dimension at once.
  - Run during off-peak hours (before 7 AM or after 5 PM) — InTrans is large,
    and this version scans it three times (demand aggregate, qualifying-parts
    list, and the NOT EXISTS zero-fill check).

LAST RUN: 2026-06-08
REQUESTED BY: Corp Parts Manager (Ben)
UPDATED: 2026-07-07 — 7-day exclusion, candidate-branch restriction (5 branches,
  asymmetric from the other-branch total), on-hand < 1 filter, Source/SLC exclusions
UPDATED: 2026-07-08 — added CommodityGroup (from the SharePoint lookup CSV
  shared with dim_CommodityCode), blank groups shown as "Other"
UPDATED: 2026-08-27 — added visible OnOrder column; fixed candidate branches
  with zero qualifying demand being dropped instead of showing Demands = 0
  (via UNION ALL zero-fill pull); added OtherLocationCount >= 5 filter
  (now required alongside OtherBranchDemands >= 10)
============================================================================

Power Query M — paste into Excel Advanced Editor:
*/

let
    // Part 1: original demand-driven pull. INNER JOIN (not LEFT) because we
    // filter on jdis columns — parts missing from jdis cannot be validated
    // and are correctly excluded. BRANCH NOT IN ('2','4') defines the broad
    // "other branch" universe — the narrower 5-branch candidate restriction
    // is applied later, in Filtered.
    // Part 2: zero-fill pull for the 5 candidate branches — jdis rows for
    // qualifying parts with NO matching InTrans row, emitted as Demands = 0,
    // so a candidate branch that never sold a qualifying part still appears.
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
            MAX(COALESCE(p.pi_On_Order,0))  AS OnOrder,
            MAX(p.pi_On_Hand_Qty)           AS OnHandQty,
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
            AND i.Trans_Datetime <= DATEADD(day, -7, GETDATE())
            AND COALESCE(p.pi_On_Order, 0) = 0
            AND p.pi_Package_Qty = 1
            AND p.pi_Return_Indicator = 'R'
            AND p.pi_Source <> 'AN'
            AND p.pi_SLC NOT LIKE '21%'
            AND p.pi_SLC NOT LIKE '90%'
            AND p.pi_SLC NOT LIKE '91%'
            AND p.pi_SLC NOT LIKE '99%'
        GROUP BY
            i.BRANCH,
            i.PART_NO

        UNION ALL

        SELECT
            p.pi_Branch                     AS BRANCH,
            p.pi_Part_No                    AS PartNumber,
            p.pi_Description                AS Description,
            p.pi_Cost                       AS Cost,
            p.pi_Source                     AS Source,
            p.pi_SLC                        AS SLC,
            p.pi_Commodity_Code             AS CommodityCode,
            p.pi_Dealer_Group_Code          AS DealerGroupCode,
            COALESCE(p.pi_On_Order, 0)      AS OnOrder,
            p.pi_On_Hand_Qty                AS OnHandQty,
            0                                AS Demands
        FROM jdis_Part_Information p
        WHERE
            p.pi_Franchise = 'D'
            AND p.pi_Branch IN ('7', '14', '95', '91', '96')
            AND COALESCE(p.pi_On_Order, 0) = 0
            AND p.pi_Package_Qty = 1
            AND p.pi_Return_Indicator = 'R'
            AND p.pi_Source <> 'AN'
            AND p.pi_SLC NOT LIKE '21%'
            AND p.pi_SLC NOT LIKE '90%'
            AND p.pi_SLC NOT LIKE '91%'
            AND p.pi_SLC NOT LIKE '99%'
            AND p.pi_Part_No IN (
                SELECT DISTINCT i2.PART_NO
                FROM InTrans i2
                WHERE
                    i2.FRANCHISE = 'D'
                    AND i2.TYPE = 'I'
                    AND i2.QTY > 0
                    AND i2.BRANCH NOT IN ('2', '4')
                    AND i2.Trans_Datetime >= DATEADD(month, -18, GETDATE())
                    AND i2.Trans_Datetime <= DATEADD(day, -7, GETDATE())
            )
            AND NOT EXISTS (
                SELECT 1
                FROM InTrans i3
                WHERE
                    i3.BRANCH = p.pi_Branch
                    AND i3.PART_NO = p.pi_Part_No
                    AND i3.FRANCHISE = 'D'
                    AND i3.TYPE = 'I'
                    AND i3.QTY > 0
                    AND i3.Trans_Datetime >= DATEADD(month, -18, GETDATE())
                    AND i3.Trans_Datetime <= DATEADD(day, -7, GETDATE())
            )
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
        {"OnOrder",         type number},
        {"OnHandQty",       type number},
        {"Demands",         Int64.Type}
    }),

    // Total demand per PartNumber across the broad other-branch universe
    // (all branches except 2 & 4 — NOT limited to the 5 candidates).
    // BranchCount = number of branches with ACTUAL demand (Demands > 0) —
    // zero-fill rows contribute 0 to TotalDemand and are excluded from
    // BranchCount, since BranchCount feeds OtherLocationCount, which means
    // branches that HAVE demand, not just branches that carry the part.
    TotalByPart = Table.Group(Typed, {"PartNumber"}, {
        {"TotalDemand", each List.Sum([Demands]), Int64.Type},
        {"BranchCount", each Table.RowCount(Table.SelectRows(_, each [Demands] > 0)), Int64.Type}
    }),

    // Join totals back onto each branch row
    Joined   = Table.NestedJoin(Typed, {"PartNumber"}, TotalByPart,
                   {"PartNumber"}, "T", JoinKind.LeftOuter),
    Expanded = Table.ExpandTableColumn(Joined, "T", {"TotalDemand", "BranchCount"}),

    // OtherBranchDemands = broad-universe total minus this branch's demand
    WithOther = Table.AddColumn(Expanded, "OtherBranchDemands",
        each [TotalDemand] - [Demands], Int64.Type),

    // OtherLocationCount = other branches with demand for this part.
    // BranchCount already only counts demand>0 branches. If THIS branch has
    // demand>0 it was counted in BranchCount, so subtract 1 to exclude
    // itself. If THIS branch has demand=0 (a zero-fill row), it was never in
    // BranchCount, so no subtraction is needed — BranchCount is already
    // "other branches with demand."
    WithLocationCount = Table.AddColumn(WithOther, "OtherLocationCount",
        each [BranchCount] - (if [Demands] > 0 then 1 else 0), Int64.Type),

    // Filter: candidate branch must be one of the 5 target branches, local
    // demand < 3, combined other-branch demand >= 10, at least 5 other
    // branches actually have demand, and local on-hand qty < 1.
    // The 5-branch restriction and on-hand check live HERE (not solely in
    // SQL WHERE) so they only narrow which rows get flagged, without
    // shrinking the OtherBranchDemands totals computed above.
    Filtered = Table.SelectRows(WithLocationCount, each
        List.Contains({"7", "14", "95", "91", "96"}, [BRANCH])
        and [Demands] < 3
        and [OtherBranchDemands] >= 10
        and [OtherLocationCount] >= 5
        and [OnHandQty] < 1),

    // Attach the business-defined CommodityGroup name (Plow & Planter, Sprayer,
    // Toys, Cotton Strippers/Pickers, Tillage, etc.) from the same SharePoint
    // lookup CSV used by the shared dim_CommodityCode Fabric dataflow — see
    // .claude/queries/dimensions/dim_CommodityCode.pq (Steps 14-15) for the
    // canonical version of this pattern. Joined here, AFTER Filtered, since by
    // this point the row count is small (a handful of flagged branch/parts,
    // not the full InTrans pull) — no reason to join against the larger set.
    GroupSource   = SharePoint.Files("https://spitractor.sharepoint.com/sites/SouthPlainsImplement-ReportSite", [ApiVersion = 15]),
    GroupFile     = GroupSource{[Name = "CommodityCodeGroups.csv"]}[Content],
    GroupCsv      = Csv.Document(GroupFile, [Delimiter = ",", Columns = 2, Encoding = 65001, QuoteStyle = QuoteStyle.None]),
    GroupPromoted = Table.PromoteHeaders(GroupCsv, [PromoteAllScalars = true]),
    GroupTyped    = Table.TransformColumnTypes(GroupPromoted, {{"CommodityCode", type text}, {"Group", type text}}),

    JoinedGroup = Table.NestedJoin(Filtered, {"CommodityCode"}, GroupTyped, {"CommodityCode"}, "GroupTable", JoinKind.LeftOuter),
    ExpandedGroup = Table.ExpandTableColumn(JoinedGroup, "GroupTable", {"Group"}, {"CommodityGroup"}),

    // Unmapped commodity codes get "Other" instead of a blank, same convention
    // as dim_CommodityCode Step 15.
    WithCommodityGroup = Table.TransformColumns(
        ExpandedGroup,
        {{"CommodityGroup", each if _ = null then "Other" else _, type text}}
    ),

    // Final output — drop intermediate columns
    Final = Table.SelectColumns(WithCommodityGroup, {
        "BRANCH", "PartNumber", "Description", "Cost",
        "Source", "SLC", "CommodityCode", "CommodityGroup", "DealerGroupCode",
        "OnOrder", "OnHandQty",
        "Demands", "OtherBranchDemands", "OtherLocationCount"
    }),

    Renamed = Table.RenameColumns(Final, {{"BRANCH", "Branch"}}),

    Sorted = Table.Sort(Renamed, {
        {"PartNumber", Order.Ascending},
        {"Branch",     Order.Ascending}
    })

in
    Sorted
