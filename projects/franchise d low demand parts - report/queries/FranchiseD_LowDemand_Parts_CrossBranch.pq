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

  IMPORTANT — zero-demand branches ARE included (fixed 2026-07-09):
  The candidate branch/part population comes from jdis_Part_Information
  (SQL_Candidates below), not from InTrans. A candidate branch with NO
  qualifying InTrans transactions for a part still produces a row, with
  Demands = 0 (via a LEFT JOIN + COALESCE to 0 against the InTrans demand
  counts). Previously the candidate population was derived directly from
  InTrans's GROUP BY, so COUNT(*) could never be 0 — a branch with zero
  demand simply had no row and was invisible to the < 3 filter entirely.

CRITERIA (adjustable):
  - Franchise:              D            (change pi_Franchise = 'D' in
                             SQL_Candidates, and i.FRANCHISE = 'D' in
                             SQL_Demand — both must match)
  - Candidate branches:     7,14,95,91,96 (change pi_Branch IN (...) in
                             SQL_Candidates — this now lives in SQL, not M,
                             since candidates are a separate query from the
                             broad other-branch demand totals)
  - Other-branch universe:  excludes 2, 4 (change BRANCH NOT IN list in
                             SQL_Demand — this defines the pool used for
                             OtherBranchDemands/OtherLocationCount, separate
                             from which branches can be flagged)
  - Local demand threshold: < 3          (change [Demands] < 3 in Filtered)
  - Other branch threshold: >= 10        (change [OtherBranchDemands] >= 10)
  - Other location threshold: >= 5       (change [OtherLocationCount] >= 5 —
                             added 2026-07-09 per Ben; stacks on top of the
                             OtherBranchDemands threshold, does not replace it)
  - On-hand threshold:      < 1          (local branch only — change
                             pi_On_Hand_Qty < 1 in SQL_Candidates)
  - Excluded source:        AN           (change pi_Source <> 'AN' in both
                             SQL_Candidates and SQL_Demand)
  - Excluded SLC prefixes:  21, 90, 91, 99 (any sub-code, e.g. 21A/21B/21C —
                             change the NOT LIKE list in both SQL queries)
  - Time window:            7 days – 18 months (change DATEADD values in
                             SQL_Demand)

PART FILTERS (from jdis_Part_Information, applied in BOTH SQL queries):
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
  OnHandQty          — Local branch's on-hand quantity (pi_On_Hand_Qty), always < 1
  Demands            — This branch's transaction count (7 days – 18 months
                       back). Can be 0 — a branch with no qualifying InTrans
                       activity for the part still shows a row.
  OtherBranchDemands — Combined transaction count at all other branches
                       (branches 2 & 4 excluded from this total; NOT limited
                       to the 5 candidate branches)
  OtherLocationCount — Number of other branches that have demand for this
                       part, always >= 5 in the output

NOTES:
  - Description comes from jdis_Part_Information (pi_Description).
    InTrans DESCRIPTION is a customer/notation field, not the part description.
  - Two separate SQL queries, joined in M (restructured 2026-07-09):
      1. SQL_Candidates — the base population. Pulls the 5 candidate branches
         directly from jdis_Part_Information (on-hand < 1, franchise D, all
         part filters). This is what makes zero-demand branches visible —
         they exist as jdis rows regardless of InTrans activity.
      2. SQL_Demand — the broad "other branch" universe (all branches except
         2 & 4), grouped from InTrans to get a demand count per branch/part.
         Used both to look up each candidate branch's own Demands (via a
         LEFT JOIN on Branch+PartNumber, COALESCE null to 0) and to build
         TotalByPart (SUM/COUNT per PartNumber) for OtherBranchDemands and
         OtherLocationCount.
    Splitting these into two queries removes the asymmetry problem the old
    single-query design had to work around: the 5-branch restriction and the
    on-hand filter now live directly in SQL_Candidates' WHERE clause without
    touching the other-branch totals, because that's a genuinely separate
    query now.
  - OtherBranchDemands math with zero-demand branches: TotalDemand (from
    TotalByPart) already excludes any branch with zero qualifying InTrans
    rows, since SQL_Demand's GROUP BY can't produce a zero-count row.
    So `OtherBranchDemands = TotalDemand - Demands` is correct whether
    Demands is 0 (branch was never in the total to begin with) or > 0
    (branch's own count is being subtracted back out).
  - OtherLocationCount math with zero-demand branches: BranchCount counts
    only branches with an actual SQL_Demand row. A zero-demand candidate
    branch was never one of those rows, so nothing needs to be subtracted
    for it — `OtherLocationCount = BranchCount - (1 if Demands > 0 else 0)`.
  - Franchise is now checked via jdis_Part_Information.pi_Franchise in
    SQL_Candidates (previously only InTrans.FRANCHISE was checked, which
    doesn't help for branches with no InTrans rows at all). Both fields are
    expected to agree — re-verify after the first live run.
  - Source and SLC exclusions are applied in both SQL queries' WHERE clauses,
    consistent with the other part filters, and affect both sides of the
    comparison.
  - CommodityGroup is pulled from CommodityCodeGroups.csv on SharePoint
    (SouthPlainsImplement-ReportSite) — the same source-of-truth file used by
    the shared dim_CommodityCode Fabric dataflow. Update that one file to
    relabel/add codes for both this query and the Fabric dimension at once.
  - Run during off-peak hours (before 7 AM or after 5 PM) — InTrans is large.

LAST RUN: 2026-06-08
REQUESTED BY: Corp Parts Manager (Ben)
UPDATED: 2026-07-07 — 7-day exclusion, candidate-branch restriction (5 branches,
  asymmetric from the other-branch total), on-hand < 1 filter, Source/SLC exclusions
UPDATED: 2026-07-08 — added CommodityGroup (from the SharePoint lookup CSV
  shared with dim_CommodityCode), blank groups shown as "Other"
UPDATED: 2026-07-09 — restructured into two SQL queries (SQL_Candidates +
  SQL_Demand) so branches with zero InTrans demand appear with Demands = 0
  instead of being invisible; added OtherLocationCount >= 5 filter (stacks on
  top of OtherBranchDemands >= 10, per Ben)
============================================================================

Power Query M — paste into Excel Advanced Editor:
*/

let
    // Broad "other branch" demand universe: all branches except 2 & 4, grouped
    // from InTrans. Drives TotalByPart (for OtherBranchDemands/OtherLocationCount)
    // and is looked up per-candidate-branch below for that branch's own Demands.
    // Only Branch/PartNumber/Demands are needed here — descriptive columns come
    // from SQL_Candidates instead.
    SQL_Demand = "
        SELECT
            i.BRANCH                        AS Branch,
            i.PART_NO                       AS PartNumber,
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
    ",
    DemandSource = Odbc.Query("dsn=EquipRDB64", SQL_Demand),
    DemandTyped = Table.TransformColumnTypes(DemandSource, {
        {"Branch",     type text},
        {"PartNumber", type text},
        {"Demands",    Int64.Type}
    }),

    // Total demand AND branch count per PartNumber across the broad other-branch
    // universe. BranchCount = number of rows in the group = number of branches
    // with any qualifying demand (zero-demand branches never appear here).
    TotalByPart = Table.Group(DemandTyped, {"PartNumber"}, {
        {"TotalDemand", each List.Sum([Demands]),  Int64.Type},
        {"BranchCount", each Table.RowCount(_),    Int64.Type}
    }),

    // Base population: the 5 candidate branches, pulled directly from jdis so
    // a branch with ZERO InTrans demand still produces a row. On-hand < 1,
    // franchise D, and all part filters live here since this is now a
    // standalone query — no longer shares a WHERE clause with the broad
    // other-branch demand totals.
    SQL_Candidates = "
        SELECT
            p.pi_Branch                     AS Branch,
            p.pi_Part_No                    AS PartNumber,
            p.pi_Description                AS Description,
            p.pi_Cost                       AS Cost,
            p.pi_Source                     AS Source,
            p.pi_SLC                        AS SLC,
            p.pi_Commodity_Code             AS CommodityCode,
            p.pi_Dealer_Group_Code          AS DealerGroupCode,
            p.pi_On_Hand_Qty                AS OnHandQty
        FROM jdis_Part_Information p
        WHERE
            p.pi_Franchise = 'D'
            AND p.pi_Branch IN ('7', '14', '95', '91', '96')
            AND p.pi_On_Hand_Qty < 1
            AND COALESCE(p.pi_On_Order, 0) = 0
            AND p.pi_Package_Qty = 1
            AND p.pi_Return_Indicator = 'R'
            AND p.pi_Source <> 'AN'
            AND p.pi_SLC NOT LIKE '21%'
            AND p.pi_SLC NOT LIKE '90%'
            AND p.pi_SLC NOT LIKE '91%'
            AND p.pi_SLC NOT LIKE '99%'
    ",
    CandidateSource = Odbc.Query("dsn=EquipRDB64", SQL_Candidates),
    CandidateTyped = Table.TransformColumnTypes(CandidateSource, {
        {"Branch",          type text},
        {"PartNumber",      type text},
        {"Description",     type text},
        {"Cost",            type number},
        {"Source",          type text},
        {"SLC",             type text},
        {"CommodityCode",   type text},
        {"DealerGroupCode", type text},
        {"OnHandQty",       type number}
    }),

    // Left join each candidate branch/part row to its own branch's demand
    // count. COALESCE null -> 0: a branch with no qualifying InTrans activity
    // has no row in DemandTyped at all — that absence IS the zero-demand case.
    JoinedDemand   = Table.NestedJoin(CandidateTyped, {"Branch", "PartNumber"}, DemandTyped,
                         {"Branch", "PartNumber"}, "D", JoinKind.LeftOuter),
    ExpandedDemand = Table.ExpandTableColumn(JoinedDemand, "D", {"Demands"}),
    WithDemands    = Table.TransformColumns(ExpandedDemand, {
        {"Demands", each if _ = null then 0 else _, Int64.Type}
    }),

    // Left join broad-universe totals by part.
    JoinedTotal   = Table.NestedJoin(WithDemands, {"PartNumber"}, TotalByPart,
                        {"PartNumber"}, "T", JoinKind.LeftOuter),
    ExpandedTotal = Table.ExpandTableColumn(JoinedTotal, "T", {"TotalDemand", "BranchCount"}),
    WithTotals    = Table.TransformColumns(ExpandedTotal, {
        {"TotalDemand", each if _ = null then 0 else _, Int64.Type},
        {"BranchCount", each if _ = null then 0 else _, Int64.Type}
    }),

    // OtherBranchDemands = broad-universe total minus this branch's own demand.
    // Correct even when Demands = 0: a zero-demand branch was never counted
    // inside TotalDemand to begin with, so subtracting 0 changes nothing.
    WithOther = Table.AddColumn(WithTotals, "OtherBranchDemands",
        each [TotalDemand] - [Demands], Int64.Type),

    // OtherLocationCount = branches with demand for this part, minus this
    // branch — but only if THIS branch itself contributed a demand row.
    // A zero-demand branch was never part of BranchCount, so there's nothing
    // to subtract for it.
    WithLocationCount = Table.AddColumn(WithOther, "OtherLocationCount",
        each [BranchCount] - (if [Demands] > 0 then 1 else 0), Int64.Type),

    // Filter: local demand < 3 (now genuinely includes 0), combined
    // other-branch demand >= 10, AND at least 5 other branches carrying
    // demand (added 2026-07-09, stacks on top of the >= 10 threshold).
    // Candidate-branch, franchise, and on-hand restrictions are already
    // enforced in SQL_Candidates.
    Filtered = Table.SelectRows(WithLocationCount, each
        [Demands] < 3
        and [OtherBranchDemands] >= 10
        and [OtherLocationCount] >= 5),

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

    JoinedGroup   = Table.NestedJoin(Filtered, {"CommodityCode"}, GroupTyped, {"CommodityCode"}, "GroupTable", JoinKind.LeftOuter),
    ExpandedGroup = Table.ExpandTableColumn(JoinedGroup, "GroupTable", {"Group"}, {"CommodityGroup"}),

    // Unmapped commodity codes get "Other" instead of a blank, same convention
    // as dim_CommodityCode Step 15.
    WithCommodityGroup = Table.TransformColumns(
        ExpandedGroup,
        {{"CommodityGroup", each if _ = null then "Other" else _, type text}}
    ),

    // Final output — drop intermediate columns
    Final = Table.SelectColumns(WithCommodityGroup, {
        "Branch", "PartNumber", "Description", "Cost",
        "Source", "SLC", "CommodityCode", "CommodityGroup", "DealerGroupCode", "OnHandQty",
        "Demands", "OtherBranchDemands", "OtherLocationCount"
    }),

    Sorted = Table.Sort(Final, {
        {"PartNumber", Order.Ascending},
        {"Branch",     Order.Ascending}
    })

in
    Sorted
