/*
============================================================================
Query: Franchise D — Cotton Dealer Groups at Branches 2 & 4 (one-off)
Type: Ad-hoc Excel Analysis (Power Query Advanced Editor)
Connection: ODBC — dsn=EquipRDB
Source Tables: InTrans (demand), jdis_Part_Information (part attributes)
============================================================================

PURPOSE:
One-time pull for Ben (Corp Parts Manager), requested 2026-09-15. Same logic
as the production Border Stores query (FranchiseD_LowDemand_Parts_CrossBranch.pq)
with two changes: candidate/local branches are 2 & 4 instead of the usual
5-branch list, and results are restricted to cotton-related parts (see
DEALER GROUP FILTER below). Every threshold (OtherBranchDemands >= 10,
OtherLocationCount >= 5, OnHandQty < 1) stays exactly as in production. NOT
the production query — do not save over FranchiseD_LowDemand_Parts_CrossBranch.pq.

('7460' was in an earlier draft of this ask and confirmed NOT to exist
anywhere in pi_Dealer_Group_Code — checked table-wide against the live
source, not just at branches 2 & 4. Dropped per Ben, 2026-09-15.)

DEALER GROUP FILTER (revised 2026-09-29 — PICKER, 690, 770 added per Ben):
A part qualifies if EITHER:
  (a) its OWN row's dealer group code is COTTON, STRIPPER, or PICKER, OR
  (b) ANY branch codes that part number as a cotton-model code:
      '690', '770', 'CS690', or 'JDCS690'.
Why (b) is cross-branch instead of a plain IN list: pi_Dealer_Group_Code is
assigned PER BRANCH, and branches 2 & 4 never use the model codes — the same
part numbers there are coded COTTON/STRIPPER/PICKER, blank, or occasionally
COMBINE/DISK/TURF/BEARING etc. A branch-level filter on '690'/'770' returns
zero rows at 2 & 4 no matter what. Verified live 2026-09-29:
  - '770'     3,286 D rows, 18 branches (none at 2 or 4)
  - 'CS690'   22 D rows, 9 branches (none at 2 or 4)
  - 'JDCS690' 9 D rows, branches 91/92/95
  - '690'     1 row, branch 94, Source AN (excluded by the AN filter anyway)
  - 'CS770'   does NOT exist anywhere — the code is plain '770'
Also: pi_Dealer_Group_Code is char(10) and comparisons here are trailing-
blank SENSITIVE — 'COTTON ' (25 rows), 'STRIPPER '/'STRIPPER  ' (3),
'PICKER ' (1) were silently missed by the old IN list. RTRIM() fixes that.
Net effect vs. the previous version (live, 2026-09-29): 194 → 243 rows,
49 added, 0 lost.

NOTE: the DealerGroupCode OUTPUT column still shows the branch 2/4 row's own
code (COTTON, PICKER, blank, COMBINE...), not 770/CS690 — a row pulled in via
rule (b) will not visibly say "770".

PERFORMANCE NOTE (2026-09-15): the zero-fill (Part 2) originally used the
same LEFT JOIN anti-join pattern as production's Part 2 (a fix applied there
2026-08-27). That pattern assumes a small, low-volume candidate branch set —
true for production's candidates, NOT true for branches 2 & 4, which are
high-volume (37K+ branch/part rows over 18mo just for these two). Against
that volume, the LEFT JOIN against an unindexed GROUP-BY-derived table
didn't finish in 3+ minutes (killed, never completed). Rewritten as a
correlated NOT EXISTS instead — an indexed per-row lookup, not a join
against something with no index — which runs in ~1.4s standalone, ~5.6s for
the full query. This is the OPPOSITE fix from what production needed in
August, because the volume profile is opposite: NOT EXISTS was slow there
because it did a per-row lookup across ALL branches; here it's fast because
it's a per-row lookup already narrowed to just 2 branches by the outer WHERE.
Verified directly against the live source (dsn=EquipRDB64) before handing
this back — both the old (broken) and new (fixed) versions were timed for
real, not guessed at.

PERFORMANCE NOTE (2026-09-29): rule (b) is implemented as a TWO-STEP pull —
first a tiny query gets the distinct model part numbers (~795 parts, ~2s),
then those are inlined into the main SQL as a literal IN (...) list. Doing
the cross-branch lookup inside the main SQL instead was timed live and is
far too slow: IN (subquery) took 250s, and a LEFT JOIN to a DISTINCT
derived table didn't finish in 10+ min (killed). jdis has no index leading
on pi_Part_No alone, so any in-SQL "does this part exist at another branch"
lookup scans ~1M rows per candidate. Literal-list version: ~5s main query,
~7s total.

HOW DEMAND IS CALCULATED (same as the production query):
  A "demand" = one InTrans row where:
    - TYPE = 'I'   (customer invoice — excludes transfers, adjustments, returns)
    - QTY  > 0     (outbound sale to customer)
    - Trans_Datetime between 7 days ago and 18 months ago

CRITERIA (everything not listed here is unchanged from the production query):
  - Candidate branches:     2, 4 ONLY (was 7,14,95,91,96 in production)
  - Dealer group filter:    COTTON/STRIPPER/PICKER (own row, trimmed) OR
                             part coded 690/770/CS690/JDCS690 at ANY branch —
                             NEW for this one-off, applied in BOTH the demand
                             pull and the zero-fill (see DEALER GROUP FILTER)
  - Other-branch universe:  excludes 2, 4 (unchanged)
  - Other branch threshold: >= 10        (unchanged)
  - Other location count:   >= 5         (unchanged)
  - On-hand threshold:      < 1          (unchanged, local branch only)
  - Excluded source:        AN           (unchanged)
  - Excluded SLC prefixes:  21, 90, 91, 99 (unchanged)
  - Time window:            7 days – 18 months (unchanged)

PART FILTERS (from jdis_Part_Information) — same as production, plus dealer group:
  - On Order = 0, Package Qty = 1, Return Indicator = 'R', Source <> 'AN',
    SLC NOT LIKE 21%/90%/91%/99%, dealer group rule above

OUTPUT COLUMNS: same as production (Branch always 2 or 4; Demands,
OtherBranchDemands, OtherLocationCount all included).

REQUESTED BY: Corp Parts Manager (Ben), via Brian — 2026-09-15, one-off, not
saved to the queries/ folder.
UPDATED: 2026-09-29 — added PICKER + cotton-model codes (690/770/CS690/
  JDCS690) via cross-branch lookup; RTRIM fix for trailing-space codes; two-
  step model-part pull for performance. See DEALER GROUP FILTER.
============================================================================

Power Query M — paste into Excel Advanced Editor:
*/

let
    // Step A: every part number coded as a cotton model ('690','770',
    // 'CS690','JDCS690') at ANY branch — see DEALER GROUP FILTER above.
    // Small (~795 parts), so it's inlined as a literal list below instead
    // of a subquery (see PERFORMANCE NOTE 2026-09-29 for why).
    ModelPartsRaw = Odbc.Query("dsn=EquipRDB", "
        SELECT DISTINCT pi_Part_No AS PartNumber
        FROM jdis_Part_Information
        WHERE RTRIM(pi_Dealer_Group_Code) IN ('690', '770', 'CS690', 'JDCS690')
    "),
    ModelParts    = List.Buffer(List.Transform(ModelPartsRaw[PartNumber], each Text.From(_))),
    ModelPartList = Text.Combine(
                        List.Transform(ModelParts, each "'" & Text.Replace(_, "'", "''") & "'"),
                        ", "),

    // Dealer group rule applied in both Part 1 and Part 2. Guarded so an
    // empty model list can't produce an invalid "IN ()".
    DealerGroupFilter =
        if List.IsEmpty(ModelParts) then
            "RTRIM(p.pi_Dealer_Group_Code) IN ('COTTON', 'STRIPPER', 'PICKER')"
        else
            "(RTRIM(p.pi_Dealer_Group_Code) IN ('COTTON', 'STRIPPER', 'PICKER')
              OR p.pi_Part_No IN (" & ModelPartList & "))",

    // Part 1: demand-driven pull, all branches except 2 & 4 (broad "other
    // branch" universe, unchanged from production). Part 2: zero-fill for
    // branches 2 & 4, using NOT EXISTS instead of production's LEFT JOIN
    // anti-join — see PERFORMANCE NOTE (2026-09-15) above for why.
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
            AND " & DealerGroupFilter & "
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
            AND p.pi_Branch IN ('2', '4')
            AND COALESCE(p.pi_On_Order, 0) = 0
            AND p.pi_Package_Qty = 1
            AND p.pi_Return_Indicator = 'R'
            AND " & DealerGroupFilter & "
            AND p.pi_Source <> 'AN'
            AND p.pi_SLC NOT LIKE '21%'
            AND p.pi_SLC NOT LIKE '90%'
            AND p.pi_SLC NOT LIKE '91%'
            AND p.pi_SLC NOT LIKE '99%'
            AND NOT EXISTS (
                SELECT 1 FROM InTrans i2
                WHERE i2.BRANCH = p.pi_Branch
                  AND i2.PART_NO = p.pi_Part_No
                  AND i2.FRANCHISE = 'D'
                  AND i2.TYPE = 'I'
                  AND i2.QTY > 0
                  AND i2.Trans_Datetime >= DATEADD(month, -18, GETDATE())
                  AND i2.Trans_Datetime <= DATEADD(day, -7, GETDATE())
            )
    ",
    Source = Odbc.Query("dsn=EquipRDB", SQL),

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
    // (all branches except 2 & 4). BranchCount = number of branches with
    // ACTUAL demand (Demands > 0) — zero-fill rows contribute 0.
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
    WithLocationCount = Table.AddColumn(WithOther, "OtherLocationCount",
        each [BranchCount] - (if [Demands] > 0 then 1 else 0), Int64.Type),

    // Candidate branch must be 2 or 4, combined other-branch demand >= 10,
    // at least 5 other branches actually have demand, and local on-hand
    // qty < 1 — all unchanged from production, just the branch set differs.
    Filtered = Table.SelectRows(WithLocationCount, each
        List.Contains({ "2", "4" }, [BRANCH])
        and [OtherBranchDemands] >= 10
        and [OtherLocationCount] >= 5
        and [OnHandQty] < 1),

    // Attach the business-defined CommodityGroup name, same SharePoint
    // lookup CSV used by the production query and dim_CommodityCode.
    GroupSource   = SharePoint.Files("https://spitractor.sharepoint.com/sites/SouthPlainsImplement-ReportSite", [ApiVersion = 15]),
    GroupFile     = GroupSource{[Name = "CommodityCodeGroups.csv"]}[Content],
    GroupCsv      = Csv.Document(GroupFile, [Delimiter = ",", Columns = 2, Encoding = 65001, QuoteStyle = QuoteStyle.None]),
    GroupPromoted = Table.PromoteHeaders(GroupCsv, [PromoteAllScalars = true]),
    GroupTyped    = Table.TransformColumnTypes(GroupPromoted, {{"CommodityCode", type text}, {"Group", type text}}),

    JoinedGroup   = Table.NestedJoin(Filtered, {"CommodityCode"}, GroupTyped, {"CommodityCode"}, "GroupTable", JoinKind.LeftOuter),
    ExpandedGroup = Table.ExpandTableColumn(JoinedGroup, "GroupTable", {"Group"}, {"CommodityGroup"}),

    // Unmapped commodity codes get "Other" instead of a blank
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
