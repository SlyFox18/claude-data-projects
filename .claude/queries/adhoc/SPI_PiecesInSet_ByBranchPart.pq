/*
============================================================================
Query: Franchise D — SPI Pieces In Set (SPI PIS)
Type: Ad-hoc Excel Analysis (Power Query Advanced Editor)
Connection: ODBC — dsn=EquipRDB64
Source Tables: InTrans (sales), jdis_Part_Information (description, bin qty,
               on-order qty, cost)
============================================================================

PURPOSE:
For each Branch + Part, detects parts that customers consistently buy in a
fixed multi-unit quantity rather than as onesies — a "set size" signal for
parts reordering. If a part's sales quantity is the same number on most of
its invoices, that number is almost certainly how it's actually consumed
(e.g. a 2-pack, a kit of 4), and reorder quantities should be multiples of
it instead of 1. Beyond just detecting the set size, this query also turns
it into an actual reorder recommendation: how many units to order right now
so that Bin Qty + On Order Qty lands on a full multiple of SPI PIS.

HOW SPI PIS IS CALCULATED:
  1. Pull qualifying InTrans rows (see CRITERIA) for the last 18 months.
  2. Collapse to one row per Branch + Part + Invoice (REF_NO), summing QTY —
     so a part split across two lines of the same invoice counts as one
     invoice with the combined quantity, not two separate data points.
  3. Per Branch + Part, count how many invoices had each distinct quantity.
  4. SPI PIS = the most common ("modal") quantity across those invoices.
  5. Match % = (invoices at the modal quantity) / (total qualifying
     invoices for that Branch + Part) — how consistently it sells in that
     exact quantity.
  6. Keep only Branch + Part combinations where Match % >= 75% AND
     SPI PIS > 1 (a modal quantity of 1 is just normal single-unit selling,
     not a "set").

  WORKED EXAMPLE (from the original request):
    Invoice   Part #    Sales Qty
    #1        12345     2
    #2        12345     2
    #3        12345     2
    #4        12345     1
  4 invoices total, 3 of them at Qty = 2 → Match % = 75%, SPI PIS = 2.
  This is the query's own qualifying threshold (Match % >= 75%, not
  strictly >), so this example is intentionally the boundary case that
  passes.

HOW THE REORDER RECOMMENDATION IS CALCULATED (added per Ben's request):
  7. Round Up = the smallest multiple of SPI PIS that is >= (Bin Qty +
     On Order Qty) — i.e. CEILING((Bin Qty + On Order Qty) / SPI PIS) *
     SPI PIS. SPECIAL CASE: if Bin Qty + On Order Qty = 0 (nothing in the
     bin, nothing incoming), Round Up = exactly one SPI PIS, not 0 — the
     plain CEILING formula would otherwise round 0 up to 0 and recommend
     ordering nothing for a part that's completely out of stock, which is
     the single most important case a reordering report needs to catch.
     Brian confirmed this override 2026-08-27.
  8. Recommended Qty = Round Up − (Bin Qty + On Order Qty) — how many MORE
     units to order to reach that rounded-up target. NOTE: Ben's original
     phrasing was "(On Order Qty + Bin Qty) − Round up", the reverse of
     this. Since Round Up is constructed to always be >= (Bin Qty + On
     Order Qty), that literal order always yields <= 0, which can't be a
     usable reorder quantity — Brian confirmed 2026-08-27 the direction
     should be flipped, as implemented here. By construction, Recommended
     Qty is always >= 0.
  9. Recommended Cost = Cost * Recommended Qty.

CRITERIA (adjustable):
  - Franchise:              D            (change FRANCHISE = 'D' in WHERE)
  - Transaction type:       'I'          (customer invoice — excludes
                             transfers, adjustments, returns)
  - Qty:                    > 0          (outbound sale to customer;
                             "Sales Qty" in the request)
  - Time window:             last 18 months through today (change the
                             DATEADD/GETDATE bounds in WHERE — appears in
                             both InvoiceQty and DemandCounts, keep in sync)
  - Min sample size:        >= 3 qualifying invoices per Branch + Part
                             (change TotalInvoices >= 3 in final WHERE) —
                             without this, a part sold only 1-2 times could
                             hit "100% match" by chance and be noise for a
                             reordering decision
  - Match % threshold:      >= 75%       (change the final WHERE clause)
  - SPI PIS floor:          > 1          (change r.Qty > 1 in final WHERE)

OUTPUT COLUMNS:
  Branch          — Branch where the pattern was observed (grain is Branch +
                    Part, not Part alone — the same part can have a
                    different SPI PIS at different branches)
  Part #          — Part number
  Description     — Part description (jdis_Part_Information.pi_Description)
  SPI PIS         — The modal (most common) sales quantity for this
                    Branch + Part
  Match %         — % of qualifying invoices that sold at exactly SPI PIS
  Invoices        — Count of qualifying INVOICES (distinct REF_NO, after
                    collapsing split lines) — the denominator behind Match %
  Demands         — Count of qualifying InTrans TRANSACTION ROWS (lines),
                    same definition as "Demands" in
                    FranchiseD_LowDemand_Parts_CrossBranch.pq. NOT the same
                    number as Invoices when a part is split across multiple
                    lines of the same invoice — Demands counts every line,
                    Invoices counts the invoice once. Added because Ben
                    specifically asked for this familiar metric alongside
                    the new ones.
  Sales Qty       — Total units sold across all qualifying invoices in the
                    18-month window (SUM of quantity, not a count)
  Bin Qty         — Current primary-bin quantity (jdis pi_Bin_Qty) — NOT
                    the same as On Hand Qty (pi_On_Hand_Qty, which also
                    includes bulk bin); Ben asked for Bin Qty specifically
  On Order Qty    — Outstanding purchase-order quantity (jdis pi_On_Order)
  Cost            — Standard cost (jdis pi_Cost)
  Round Up        — Bin Qty + On Order Qty, rounded up to the next multiple
                    of SPI PIS (floored at one SPI PIS if both are 0 — see
                    HOW THE REORDER RECOMMENDATION IS CALCULATED above)
  Recommended Qty — Round Up − (Bin Qty + On Order Qty); how many more units
                    to order now
  Recommended Cost— Cost * Recommended Qty

NOTES:
  - Description does NOT come from InTrans.DESCRIPTION — that column is a
    customer/notation field on the transaction, not the part description
    (same finding documented in FranchiseD_LowDemand_Parts_CrossBranch.pq).
    Description, Bin Qty, On Order Qty, and Cost all come from
    jdis_Part_Information via an INNER JOIN on Branch + Part.
  - FIXED 2026-08-27 (real duplicate-row bug, found via a Claude-in-Excel
    data quality pass on a live extract): the jdis join originally didn't
    guard against jdis_Part_Information having more than one row per
    (pi_Branch, pi_Part_No) — it does, differing mainly by Description case/
    text — so 22 Branch+Part keys came back as 2 rows apiece (48 rows total
    in that extract), identical SPI PIS/Match %/Invoices, different
    Description casing/wording only. Fixed via the JdisDedup CTE, which
    picks exactly one jdis row per Branch+Part (longest description wins,
    alphabetical tie-break) and now also supplies Bin Qty/On Order Qty/Cost
    from that same single winning row, for internal consistency. Same
    underlying jdis duplication problem already documented and fixed for
    dim_Parts (dim_Parts.pq STEP 1) — this is the same issue one level more
    granular (duplicates within a single branch+part, not just across
    branches for the same part).
  - OPEN / NOT FIXED — Description truncation: that same audit found ~777
    rows (of 4,275) with a Description exactly 10 characters long (e.g.
    "MOWER BLAD", "BALL BEARI") — looks like pi_Description is truncated at
    the source for at least some rows. The JdisDedup fix above prefers the
    longest available duplicate, which may reduce this somewhat, but if
    EVERY duplicate row for a part is equally truncated it can't help.
    InMaster has its own separate PART_DESC field (see InMaster.pq) that
    MIGHT be fuller/untruncated, but that isn't verified — don't swap
    Description to it without first checking real examples side-by-side.
  - OPEN / NOT FIXED — box/bulk quantities: the same audit flagged ~25 rows
    with an implausibly large SPI PIS (e.g. 1,000 for "Packaging Material",
    100 for "Bag") — items very likely tracked/sold in a fixed case-pack or
    box quantity rather than a genuine reorder "set." The math behind these
    is not wrong (they really do sell in that exact quantity >=75% of the
    time), so this query does not filter them out — whether to cap SPI PIS
    at some sanity threshold, or leave it to manual review against
    Description, is a business call for Brian/Ben, not something assumed
    here. Now that this query produces real order-quantity/cost
    recommendations, a box/bulk item slipping through could recommend
    ordering (and spending on) far more than intended — worth resolving
    before this is trusted for actual purchasing decisions.
  - Ties for "most common quantity" (rn = 1) can't actually occur among
    output rows: two different quantities can't both hold more than 50% of
    a Branch + Part's invoices, so once the >= 75% Match % filter is
    applied, whichever quantity is picked as rn = 1 is unambiguously the
    true mode. The ORDER BY tie-break (smaller Qty first) exists only so
    the query is deterministic before that filter is applied.
  - REF_NO is InTrans's invoice number (confirmed elsewhere in this repo —
    NOT a work order number), so grouping by REF_NO for "one row per
    invoice" is the correct join/grouping key.
  - No Source/SLC/On-Order/Package-Qty ELIGIBILITY filters are applied here
    (unlike FranchiseD_LowDemand_Parts_CrossBranch.pq) — this query answers
    a different question (set-size detection from sales history, not
    stocking-gap eligibility) and none of those were requested. On Order
    Qty IS pulled through as a plain output column now, but only as
    context/input to the reorder math, not as a filter.
  - Run during off-peak hours (before 7 AM or after 5 PM) — InTrans is
    large and this scans the full 18-month window twice (once for
    InvoiceQty, once for DemandCounts — see that CTE's comment for why it
    isn't just derived from InvoiceQty instead).

LAST RUN: 2026-08-27
REQUESTED BY: Brian (ad-hoc — parts reordering, SPI Pieces In Set concept);
  Sales Qty/Bin Qty/On Order Qty/Cost + 3 reorder calc columns + Demands
  requested by Ben after reviewing the first version
UPDATED: 2026-08-27 — added Invoices output column; fixed a real duplicate-
  row bug (jdis_Part_Information join fan-out) found via a Claude-in-Excel
  data quality audit of a live extract — see NOTES for full detail and the
  two related OPEN items (description truncation, box/bulk-quantity outliers)
UPDATED: 2026-08-27 (Ben's round 2) — added Demands, Sales Qty, Bin Qty, On
  Order Qty, Cost, and 3 calculated reorder columns (Round Up, Recommended
  Qty, Recommended Cost) — see HOW THE REORDER RECOMMENDATION IS CALCULATED
============================================================================

Power Query M — paste into Excel Advanced Editor:
*/

let
    SQL = "
        WITH InvoiceQty AS (
            -- One row per Branch + Part + Invoice, summing QTY across any
            -- split lines of the same part on the same invoice. Feeds both
            -- the SPI PIS/Match % calc AND Sales Qty (SUM of InvoiceQty is
            -- the same total as summing every raw qualifying QTY directly).
            SELECT
                BRANCH,
                PART_NO,
                REF_NO,
                SUM(QTY) AS InvoiceQty
            FROM InTrans
            WHERE
                FRANCHISE = 'D'
                AND TYPE = 'I'
                AND QTY > 0
                AND Trans_Datetime >= DATEADD(month, -18, GETDATE())
                AND Trans_Datetime <= GETDATE()
            GROUP BY BRANCH, PART_NO, REF_NO
        ),
        QtyCounts AS (
            -- How many invoices had each distinct quantity, per Branch+Part
            SELECT
                BRANCH,
                PART_NO,
                InvoiceQty AS Qty,
                COUNT(*) AS QtyCount
            FROM InvoiceQty
            GROUP BY BRANCH, PART_NO, InvoiceQty
        ),
        PartTotals AS (
            -- Total qualifying invoice count AND total units sold
            -- (Sales Qty), per Branch+Part.
            SELECT
                BRANCH,
                PART_NO,
                COUNT(*)        AS TotalInvoices,
                SUM(InvoiceQty) AS TotalSalesQty
            FROM InvoiceQty
            GROUP BY BRANCH, PART_NO
        ),
        DemandCounts AS (
            -- Raw qualifying InTrans ROW count per Branch+Part — same
            -- definition as 'Demands' in
            -- FranchiseD_LowDemand_Parts_CrossBranch.pq (COUNT(*) of
            -- qualifying transaction lines). Computed separately from
            -- InvoiceQty/PartTotals (rather than derived from them)
            -- because it's a genuinely different grain: InvoiceQty already
            -- collapsed split invoice lines together, so a raw line count
            -- can't be recovered from it after the fact.
            SELECT
                BRANCH,
                PART_NO,
                COUNT(*) AS Demands
            FROM InTrans
            WHERE
                FRANCHISE = 'D'
                AND TYPE = 'I'
                AND QTY > 0
                AND Trans_Datetime >= DATEADD(month, -18, GETDATE())
                AND Trans_Datetime <= GETDATE()
            GROUP BY BRANCH, PART_NO
        ),
        Ranked AS (
            -- rn = 1 is the modal (most common) quantity per Branch+Part.
            -- See NOTES above re: why the tie-break never decides an
            -- actual output row once the Match % filter is applied.
            SELECT
                q.BRANCH,
                q.PART_NO,
                q.Qty,
                q.QtyCount,
                t.TotalInvoices,
                t.TotalSalesQty,
                ROW_NUMBER() OVER (
                    PARTITION BY q.BRANCH, q.PART_NO
                    ORDER BY q.QtyCount DESC, q.Qty ASC
                ) AS rn
            FROM QtyCounts q
            INNER JOIN PartTotals t
                ON  t.BRANCH  = q.BRANCH
                AND t.PART_NO = q.PART_NO
        ),
        JdisDedup AS (
            -- jdis_Part_Information is NOT guaranteed unique on
            -- (pi_Branch, pi_Part_No) alone — it carries duplicate/near-
            -- duplicate rows for the exact same branch+part, differing
            -- mainly by Description text (case variants, and some rows
            -- truncated shorter than others). An unguarded join against it
            -- fans out one Ranked row into two+ output rows — confirmed
            -- live via a post-hoc data quality audit (22 distinct
            -- Branch+Part keys, 48 rows affected, in a 2026-08-27 extract).
            -- This mirrors the same jdis duplication problem already fixed
            -- for dim_Parts (see dim_Parts.pq STEP 1), just one level more
            -- granular (there it was collapsing across branches per part;
            -- here jdis already duplicates within a single branch+part).
            -- Pick exactly one row per (pi_Branch, pi_Part_No): prefer the
            -- LONGEST non-null description (best chance of avoiding a
            -- truncated variant when a fuller one exists among the
            -- duplicates), tie-broken alphabetically for determinism. Bin
            -- Qty/On Order Qty/Cost are then taken from that same winning
            -- row, for internal consistency.
            SELECT
                pi_Branch,
                pi_Part_No,
                pi_Description,
                pi_Bin_Qty,
                pi_On_Order,
                pi_Cost,
                ROW_NUMBER() OVER (
                    PARTITION BY pi_Branch, pi_Part_No
                    ORDER BY LEN(pi_Description) DESC, pi_Description ASC
                ) AS jrn
            FROM jdis_Part_Information
        ),
        FinalJoined AS (
            SELECT
                r.BRANCH                                                    AS BRANCH,
                r.PART_NO                                                   AS PartNumber,
                p.pi_Description                                            AS Description,
                r.Qty                                                       AS SpiPis,
                ROUND(CAST(r.QtyCount AS FLOAT) / r.TotalInvoices * 100, 1)  AS MatchPercent,
                r.TotalInvoices                                             AS Invoices,
                d.Demands                                                   AS Demands,
                r.TotalSalesQty                                             AS SalesQty,
                COALESCE(p.pi_Bin_Qty, 0)                                   AS BinQty,
                COALESCE(p.pi_On_Order, 0)                                  AS OnOrderQty,
                p.pi_Cost                                                   AS Cost
            FROM Ranked r
            INNER JOIN JdisDedup p
                ON  p.pi_Branch  = r.BRANCH
                AND p.pi_Part_No = r.PART_NO
                AND p.jrn = 1
            INNER JOIN DemandCounts d
                ON  d.BRANCH  = r.BRANCH
                AND d.PART_NO = r.PART_NO
            WHERE
                r.rn = 1
                AND r.TotalInvoices >= 3
                AND r.Qty > 1
                AND CAST(r.QtyCount AS FLOAT) / r.TotalInvoices >= 0.75
        ),
        WithRoundUp AS (
            -- Round Up = next multiple of SPI PIS at or above (Bin Qty +
            -- On Order Qty) — EXCEPT when that sum is 0, where Round Up is
            -- forced to exactly one SPI PIS instead of the plain CEILING
            -- result of 0. See HOW THE REORDER RECOMMENDATION IS
            -- CALCULATED in the header comment above.
            SELECT
                *,
                CASE
                    WHEN (BinQty + OnOrderQty) = 0 THEN SpiPis
                    ELSE CAST(CEILING(CAST((BinQty + OnOrderQty) AS FLOAT) / SpiPis) * SpiPis AS INT)
                END AS RoundUp
            FROM FinalJoined
        )
        SELECT
            BRANCH,
            PartNumber,
            Description,
            SpiPis,
            MatchPercent,
            Invoices,
            Demands,
            SalesQty,
            BinQty,
            OnOrderQty,
            Cost,
            RoundUp,
            (RoundUp - (BinQty + OnOrderQty))        AS RecommendedQty,
            Cost * (RoundUp - (BinQty + OnOrderQty)) AS RecommendedCost
        FROM WithRoundUp
        ORDER BY
            BRANCH,
            PartNumber
    ",
    Source = Odbc.Query("dsn=EquipRDB64", SQL),

    // Enforce correct data types from SQL results
    Typed = Table.TransformColumnTypes(Source, {
        {"BRANCH",          type text},
        {"PartNumber",      type text},
        {"Description",     type text},
        {"SpiPis",          Int64.Type},
        {"MatchPercent",    type number},
        {"Invoices",        Int64.Type},
        {"Demands",         Int64.Type},
        {"SalesQty",        Int64.Type},
        {"BinQty",          Int64.Type},
        {"OnOrderQty",      Int64.Type},
        {"Cost",            type number},
        {"RoundUp",         Int64.Type},
        {"RecommendedQty",  Int64.Type},
        {"RecommendedCost", type number}
    }),

    // Final display names, matching the requested output columns
    Renamed = Table.RenameColumns(Typed, {
        {"BRANCH",          "Branch"},
        {"PartNumber",      "Part #"},
        {"SpiPis",          "SPI PIS"},
        {"MatchPercent",    "Match %"},
        {"SalesQty",        "Sales Qty"},
        {"BinQty",          "Bin Qty"},
        {"OnOrderQty",      "On Order Qty"},
        {"RoundUp",         "Round Up"},
        {"RecommendedQty",  "Recommended Qty"},
        {"RecommendedCost", "Recommended Cost"}
    }),

    Sorted = Table.Sort(Renamed, {
        {"Branch", Order.Ascending},
        {"Part #", Order.Ascending}
    })

in
    Sorted
