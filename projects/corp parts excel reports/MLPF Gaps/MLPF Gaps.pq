/*
============================================================================
Query: MLPF Gaps
Type: Ad-hoc Excel Analysis (Power Query Advanced Editor)
Connection: ODBC — dsn=EquipRDB
Source Tables: InTrans (demand), jdis_Part_Information (part attributes)
============================================================================

PURPOSE:
Company-wide, branch-level variant of FranchiseD_LowDemand_Parts_CrossBranch.pq.
Same demand definition and part filters, but with no candidate-branch
restriction (every branch except 12 is in scope) and no cross-branch
comparison columns — just each branch/part row's own demand, kept if it
hits the demand filter below. Requested by Ben (Corp Parts Manager) via
Brian, 2026-09-11, for the "MLPF Gaps" tab in Supplemental Stocking.xlsx.

HOW DEMAND IS CALCULATED:
  A "demand" = one InTrans row where:
    - TYPE = 'I'   (customer invoice — excludes transfers, adjustments, returns)
    - QTY  > 0     (outbound sale to customer)
    - Trans_Datetime between 7 days ago and 18 months ago (excludes the most
      recent week so very recent activity doesn't mask a true low-demand branch)

CRITERIA (adjustable):
  - Franchise:              D            (change i.FRANCHISE = 'D' in WHERE)
  - Branch scope:           all branches except 12 (SPI's Combine Vault — not
                             a physical retail branch, per Ben 2026-09-11;
                             change i.BRANCH <> '12' in WHERE)
  - Demand filter:          exactly 2    (change HAVING COUNT(*) = 2)
  - On-hand threshold:      < 1          (change p.pi_On_Hand_Qty < 1 in WHERE)
  - Superseded parts:       excluded     (only rows whose Super To is null or
                             blank — see NOTES; remove the pi_Super_To line
                             in WHERE to include them again)
  - Excluded source:        AN           (change p.pi_Source <> 'AN' in WHERE)
  - Excluded SLC prefixes:  21, 90, 91, 99 (any sub-code — change the NOT LIKE list)
  - Time window:            7 days – 18 months (change DATEADD values in WHERE)

PART FILTERS (from jdis_Part_Information):
  - On Order = 0            Only parts with no outstanding purchase orders
  - Package Qty = 1         Only individually-stocked parts (not bundled)
  - Return Indicator = 'R'  Only returnable parts
  - Source <> 'AN'          Excludes Source code "AN"
  - SLC NOT LIKE 21%/90%/91%/99%  Excludes these SLC families (any sub-code)
  - On Hand Qty < 1         Only branches with no stock of the part
  - Super To null/blank     Only parts NOT superseded to another part number

OUTPUT COLUMNS:
  Branch, PartNumber, Description, Cost, Source, SLC, CommodityCode,
  CommodityGroup, DealerGroupCode, OnOrder, OnHandQty, Demands.

NOTES:
  - "Sub To" = jdis_Part_Information.pi_Super_To (char(22)) — the part number
    this part has been superseded/substituted to. It's the only sub/super-
    to column in the table (the other is pi_Super_From, the reverse
    direction). A populated value means the part has been replaced, so it
    shouldn't be stocked as-is — Ben wants those rows dropped (2026-10-07).
  - The Super To filter uses COALESCE(RTRIM(p.pi_Super_To), '') = '' rather
    than IS NULL or = '': checked live 2026-10-07, the column is never NULL
    in this result set — "blank" is stored as an empty string, and a few
    rows (7) hold spaces only. Comparisons on this source are trailing-
    blank sensitive, so the RTRIM is what catches the spaces-only rows. The
    COALESCE keeps it safe if NULLs ever do appear.
  - Impact at time of change (live, 2026-10-07): 11,330 rows → 11,228 rows
    (102 superseded branch/part rows removed).
  - Description comes from jdis_Part_Information (pi_Description), not the
    InTrans notation field.
  - Single INNER JOIN + GROUP BY + HAVING, folded entirely to the source —
    ~12s when tested 2026-10-07.
  - CommodityGroup is pulled from the same CommodityCodeGroups.csv on
    SharePoint used by FranchiseD_LowDemand_Parts_CrossBranch.pq and the
    shared dim_CommodityCode Fabric dataflow — one source file, kept in
    sync across all three.
  - Run during off-peak hours where possible (before 7 AM or after 5 PM) —
    InTrans is large and this queries the ODBC source directly.

REQUESTED BY: Corp Parts Manager (Ben), via Brian — 2026-09-11
UPDATED: 2026-10-07 — exclude superseded parts (pi_Super_To must be null or
  blank), per Ben; header notes rebuilt to match the current query
  (demand filter is HAVING COUNT(*) = 2)
============================================================================

Power Query M — paste into Excel Advanced Editor:
*/

let
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
            AND i.BRANCH <> '12'
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
            AND p.pi_On_Hand_Qty < 1
            AND COALESCE(RTRIM(p.pi_Super_To), '') = ''
        GROUP BY
            i.BRANCH,
            i.PART_NO
        HAVING COUNT(*) = 2
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

    // Attach the business-defined CommodityGroup name from the same
    // SharePoint lookup CSV used by the sibling query and the shared
    // dim_CommodityCode Fabric dataflow.
    GroupSource   = SharePoint.Files("https://spitractor.sharepoint.com/sites/SouthPlainsImplement-ReportSite", [ApiVersion = 15]),
    GroupFile     = GroupSource{[Name = "CommodityCodeGroups.csv"]}[Content],
    GroupCsv      = Csv.Document(GroupFile, [Delimiter = ",", Columns = 2, Encoding = 65001, QuoteStyle = QuoteStyle.None]),
    GroupPromoted = Table.PromoteHeaders(GroupCsv, [PromoteAllScalars = true]),
    GroupTyped    = Table.TransformColumnTypes(GroupPromoted, {{"CommodityCode", type text}, {"Group", type text}}),

    JoinedGroup   = Table.NestedJoin(Typed, {"CommodityCode"}, GroupTyped, {"CommodityCode"}, "GroupTable", JoinKind.LeftOuter),
    ExpandedGroup = Table.ExpandTableColumn(JoinedGroup, "GroupTable", {"Group"}, {"CommodityGroup"}),

    // Unmapped commodity codes get "Other" instead of a blank, same
    // convention as dim_CommodityCode Step 15 and the sibling query.
    WithCommodityGroup = Table.TransformColumns(
        ExpandedGroup,
        {{"CommodityGroup", each if _ = null then "Other" else _, type text}}
    ),

    // Final output — drop intermediate columns
    Final = Table.SelectColumns(WithCommodityGroup, {
        "BRANCH", "PartNumber", "Description", "Cost",
        "Source", "SLC", "CommodityCode", "CommodityGroup", "DealerGroupCode",
        "OnOrder", "OnHandQty", "Demands"
    }),

    Renamed = Table.RenameColumns(Final, {{"BRANCH", "Branch"}}),

    Sorted = Table.Sort(Renamed, {
        {"PartNumber", Order.Ascending},
        {"Branch",     Order.Ascending}
    })

in
    Sorted
