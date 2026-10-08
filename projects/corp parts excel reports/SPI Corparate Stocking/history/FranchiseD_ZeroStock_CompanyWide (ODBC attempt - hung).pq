/*
============================================================================
Query: Franchise D — Zero Stock, Company-Wide Demand
Type: Ad-hoc Excel Analysis (Power Query Advanced Editor)
Connection: ODBC — dsn=EquipRDB64
Source Tables: jdis_Part_Information (part attributes/eligibility), InTrans (demand)
============================================================================

RELATIONSHIP TO OTHER QUERY:
This is a SEPARATE query/grain from FranchiseD_LowDemand_Parts_CrossBranch.pq
(the branch-level "5 candidate branches vs. everyone else" report). Do NOT
merge these — they answer different questions and are both wanted side by
side in the same Excel workbook. This one drops Branch entirely and looks
company-wide.

PURPOSE:
Identifies Franchise D parts with ZERO stock and ZERO outstanding orders
company-wide (every branch, not just some), that are still generating
demand at multiple locations. Company-wide reorder-candidate view, as
opposed to the branch-level stocking-imbalance view in the other query.

============================================================================
CONFIRMED WITH BEN (2026-08-27, via Brian) — SQL BELOW NOT UPDATED TO MATCH
============================================================================
This query was abandoned for performance reasons (see PERFORMANCE notes
below and the working replacement in
.claude/queries/adhoc/franchise-d-zerostock/build_report.py) BEFORE Ben's
answers came back, so the SQL below still reflects the pre-confirmation
guesses, not the confirmed criteria. Do not use this file — see the
replacement script, which HAS been updated to match Ben's answers.
  1. On Hand = 0: CONFIRMED as EVERY branch showing exactly 0 (not summed).
  2. On Order = 0: CONFIRMED same "every branch = 0" logic as #1.
  3. Branch scope: CORRECTED — branches 2 & 4 ARE excluded, same as the
     branch-level report. Brian's original guess here ("include all
     branches") was wrong; this file's SQL still uses that wrong guess.
  4. Source <> 'AN' / SLC exclusions / 7-day-18-month window: CONFIRMED,
     carried over identically from the branch-level report.
  5. Judgment call (not explicitly discussed): a branch excluded by
     Source/SLC (or now, 2/4) is treated as irrelevant to the "on hand = 0
     everywhere" check.
============================================================================

HOW DEMAND IS CALCULATED:
  A "demand" = one InTrans row where:
    - FRANCHISE = 'D'
    - TYPE = 'I'   (customer invoice — excludes transfers, adjustments, returns)
    - QTY  > 0     (outbound sale to customer)
    - Trans_Datetime between 7 days ago and 18 months ago (same window as
      the other query — excludes the most recent week so very recent
      activity doesn't mask a true low-demand part)
  Demand is summed across ALL branches (no branch exclusions) since Branch
  isn't part of this query's grain.

CRITERIA (adjustable):
  - Franchise:              D            (change FRANCHISE = 'D' in WHERE)
  - Package Qty:            = 1          (individually-stocked parts only)
  - Return Indicator:       = 'R'        (returnable parts only)
  - Excluded source:        AN           (change p.pi_Source <> 'AN' in WHERE)
  - Excluded SLC prefixes:  21, 90, 91, 99 (any sub-code — change NOT LIKE list)
  - On Hand:                0 at every branch (change the HAVING clause)
  - On Order:                0 at every branch (change the HAVING clause)
  - Location count:         >= 3         (change [LocationCount] >= 3 in Filtered)
  - Time window:            7 days – 18 months (change DATEADD values)
  - NO floor on total demand magnitude (the old OtherBranchDemands >= 10
    equivalent was removed per Ben's request — this returns every part that
    clears the LocationCount threshold, regardless of how much it's sold)

OUTPUT COLUMNS:
  PartNumber      — Part number (no Branch column — this is company-wide)
  Description     — Manufacturer part description (from jdis)
  Cost            — Standard cost (pi_Cost)
  Source          — Source code (pi_Source)
  SLC             — Stock Level Classification (pi_SLC)
  CommodityCode   — Commodity code (pi_Commodity_Code)
  DealerGroupCode — Dealer group code (pi_Dealer_Group_Code)
  OnOrder         — Always 0 (it's a filter criterion) — shown for visibility
  OnHandQty       — Always 0 (it's a filter criterion) — shown for visibility
  TotalDemand     — Combined 18-month transaction count across ALL branches
  LocationCount   — Number of distinct branches with demand (Demands > 0)
                    for this part

NOTES:
  - Description/Cost/Source/SLC/CommodityCode/DealerGroupCode come from
    jdis_Part_Information, MAX()'d across branches. If these ever differ by
    branch for the same part (VendorCode is known to do this — see
    project_dim_parts_vendorcode_limitation memory — other attributes could
    too), MAX() picks one arbitrarily. Worth spot-checking if results look
    inconsistent.
  - Eligibility (jdis) and demand (InTrans) are two separate subqueries,
    LEFT JOINed on PartNumber, at PartNumber+BRANCH grain — same pattern
    proven fast in the other query. LocationCount is NOT computed in SQL
    (see PERFORMANCE note below) — it's computed in Power Query M after
    the fine-grained result comes back, via Table.Group + row-counting on
    the already-small dataset.
  - The zero-stock check is a HAVING clause on the eligibility subquery:
    SUM of "this branch is nonzero" flags must be 0 for both On Hand and
    On Order, meaning literally no eligible branch has any stock or any
    order outstanding.
  - PERFORMANCE (2026-08-27, pass 1): the first version of this query used
    COUNT(DISTINCT i.BRANCH) in SQL, grouped only by PART_NO, to get
    LocationCount directly from the source. That hung for 30+ minutes —
    COUNT(DISTINCT ...) forces per-group de-duplication across the whole
    Franchise D transaction history. Fixed by moving to a fine-grained
    PART_NO+BRANCH GROUP BY in SQL with LocationCount computed client-side
    in Power Query — same pattern already proven fast in
    FranchiseD_LowDemand_Parts_CrossBranch.pq.
  - PERFORMANCE (2026-08-27, pass 2): still hung ~10 minutes after pass 1,
    even with ODBC/capacity confirmed NOT the bottleneck. Root cause:
    the eligibility subquery filtered jdis_Part_Information (1M+ rows) by
    Franchise alone, with NO branch restriction — every other query in this
    repo that touches jdis restricts it by Branch first (jdis's practical
    key is Branch+PartNumber; every prior design drove jdis lookups off a
    branch-restricted or InTrans-joined set). Scanning the full table on an
    unproven predicate (Franchise) was a genuinely new, untested access
    pattern here. Fixed by pre-restricting jdis to
    "p.pi_Part_No IN (parts with any demand, per InTrans)" — this can't use
    a branch restriction (we need to check every branch's stock for the
    zero-everywhere condition), but restricting by part number achieves the
    same narrowing effect using InTrans, which every other query here
    already proves is fast to filter. Costs one more (cheap, unfiltered-by-
    branch, DISTINCT-PART_NO-only) InTrans scan in exchange for avoiding an
    unrestricted scan of jdis.
    UNVERIFIED: Claude cannot execute SQL against this ODBC source directly,
    so this diagnosis is inference from query patterns elsewhere in the
    repo, not a confirmed execution plan. If this still hangs, the next
    diagnostic step is running the eligibility (jdis-only) subquery alone,
    isolated from the InTrans join, to confirm which half is actually slow.
  - Run during off-peak hours (before 7 AM or after 5 PM) — InTrans is large.

CREATED: 2026-08-27
REQUESTED BY: Corp Parts Manager (Ben), via Brian
UPDATED: 2026-08-27 (perf pass 1) — replaced SQL-side COUNT(DISTINCT BRANCH)
  (hung 30+ min) with a fine-grained PartNumber+BRANCH SQL aggregate and
  moved LocationCount computation to Power Query M, matching the pattern
  already proven fast in FranchiseD_LowDemand_Parts_CrossBranch.pq
UPDATED: 2026-08-27 (perf pass 2) — still hung ~10 min with ODBC/capacity
  ruled out. Added an InTrans-derived "qualifying parts" pre-filter to the
  jdis eligibility subquery, since that subquery was scanning all of jdis
  on an unrestricted Franchise filter — a pattern untested elsewhere in
  this repo. See PERFORMANCE notes above.
============================================================================

Power Query M — paste into Excel Advanced Editor:
*/

let
    // Eligibility subquery: jdis rows passing part-level filters, PRE-
    // RESTRICTED to parts with any Franchise D demand at all (via InTrans),
    // grouped to PartNumber, keeping only parts where EVERY eligible branch
    // shows exactly 0 on-hand AND 0 on-order (see OPEN QUESTIONS #1, #2, #5
    // and PERFORMANCE pass 2 above — this pre-filter is what makes the jdis
    // scan tractable without a branch restriction).
    // Demand subquery: company-wide (all branches, no exclusions per Ben's
    // "include all branches for now" — OPEN QUESTION #3) InTrans aggregate,
    // grouped by PART_NO + BRANCH (fine-grained, cheap — see PERFORMANCE
    // note above). LocationCount is deliberately NOT computed here in SQL.
    SQL = "
        SELECT
            e.PartNumber,
            e.Description,
            e.Cost,
            e.Source,
            e.SLC,
            e.CommodityCode,
            e.DealerGroupCode,
            0                        AS OnOrder,
            0                        AS OnHandQty,
            d.BRANCH,
            COALESCE(d.Demands, 0)   AS Demands
        FROM (
            SELECT
                p.pi_Part_No                    AS PartNumber,
                MAX(p.pi_Description)           AS Description,
                MAX(p.pi_Cost)                  AS Cost,
                MAX(p.pi_Source)                AS Source,
                MAX(p.pi_SLC)                    AS SLC,
                MAX(p.pi_Commodity_Code)        AS CommodityCode,
                MAX(p.pi_Dealer_Group_Code)     AS DealerGroupCode
            FROM jdis_Part_Information p
            WHERE
                p.pi_Franchise = 'D'
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
                        AND i2.Trans_Datetime >= DATEADD(month, -18, GETDATE())
                        AND i2.Trans_Datetime <= DATEADD(day, -7, GETDATE())
                )
            GROUP BY
                p.pi_Part_No
            HAVING
                SUM(CASE WHEN COALESCE(p.pi_On_Hand_Qty, 0) <> 0 THEN 1 ELSE 0 END) = 0
                AND SUM(CASE WHEN COALESCE(p.pi_On_Order, 0)   <> 0 THEN 1 ELSE 0 END) = 0
        ) e
        LEFT JOIN (
            SELECT
                i.PART_NO   AS PartNumber,
                i.BRANCH,
                COUNT(*)    AS Demands
            FROM InTrans i
            WHERE
                i.FRANCHISE = 'D'
                AND i.TYPE = 'I'
                AND i.QTY > 0
                AND i.Trans_Datetime >= DATEADD(month, -18, GETDATE())
                AND i.Trans_Datetime <= DATEADD(day, -7, GETDATE())
            GROUP BY
                i.PART_NO,
                i.BRANCH
        ) d
            ON d.PartNumber = e.PartNumber
    ",
    Source = Odbc.Query("dsn=EquipRDB64", SQL),

    // Enforce correct data types from SQL results
    Typed = Table.TransformColumnTypes(Source, {
        {"PartNumber",      type text},
        {"Description",     type text},
        {"Cost",            type number},
        {"Source",          type text},
        {"SLC",             type text},
        {"CommodityCode",   type text},
        {"DealerGroupCode", type text},
        {"OnOrder",         type number},
        {"OnHandQty",       type number},
        {"BRANCH",          type text},
        {"Demands",         Int64.Type}
    }),

    // Collapse the fine-grained branch rows down to PartNumber. An eligible
    // part with NO demand anywhere comes back as a single row with
    // BRANCH = null and Demands = 0 (from the LEFT JOIN) — it naturally
    // fails LocationCount >= 3 below, so no special-case handling needed
    // beyond excluding null-BRANCH rows from the count.
    ByPart = Table.Group(Typed,
        {"PartNumber", "Description", "Cost", "Source", "SLC", "CommodityCode", "DealerGroupCode", "OnOrder", "OnHandQty"},
        {
            {"TotalDemand",   each List.Sum([Demands]), Int64.Type},
            {"LocationCount", each Table.RowCount(Table.SelectRows(_, each [BRANCH] <> null and [Demands] > 0)), Int64.Type}
        }),

    Filtered = Table.SelectRows(ByPart, each [LocationCount] >= 3),

    Sorted = Table.Sort(Filtered, {
        {"LocationCount", Order.Descending},
        {"TotalDemand",   Order.Descending},
        {"PartNumber",    Order.Ascending}
    })

in
    Sorted
