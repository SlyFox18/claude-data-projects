/*
============================================================================
Query: Franchise D — SPI Pieces In Set REVIEW (InMaster PIS cleanup list)
Type: Ad-hoc Excel Analysis (Power Query Advanced Editor) — separate tab
      in the same workbook as "SPI -Pieces In Set.pq"
Connection: ODBC — dsn=EquipRDB
Source Tables: InTrans (sales), InMaster (Pieces_In_Set),
               jdis_Part_Information (description, source, SLC, commodity
               code, dealer group code)
============================================================================

PURPOSE:
The reverse of the main SPI Pieces In Set query. That query finds parts
that DO sell in a consistent multi-unit quantity (Match % >= 75%). This one
finds parts that are SET UP in InMaster as a multi-piece set
(InMaster.Pieces_In_Set > 1) but whose actual sales history does NOT show a
consistent set quantity (Match % < 75%). These are candidates for Ben to
review and correct in the part master — a Pieces In Set value that the
sales history doesn't back up.

HOW MATCH % IS CALCULATED (identical to the main query):
  1. Pull qualifying InTrans rows (see CRITERIA) for the last 18 months.
  2. Collapse to one row per Branch + Part + Invoice (REF_NO), summing QTY.
  3. Most Common Qty = the modal invoice quantity for that Branch + Part.
  4. Match % = (invoices at the Most Common Qty) / (total qualifying
     invoices) — how consistently the part sells in one exact quantity.
  5. Keep Branch + Part where InMaster Pieces_In_Set > 1 AND Match % < 75%.

CRITERIA (adjustable):
  - Franchise:              D            (InTrans AND InMaster)
  - Branches:               all EXCEPT 2 & 4 (same as the main tab —
                             change BRANCH NOT IN ('2', '4'), appears in
                             InvoiceQty, DemandCounts, and InMasterPis;
                             keep all three in sync)
  - Transaction type:       'I'          (customer invoice)
  - Qty:                    > 0          (outbound sale)
  - Time window:            last 18 months through today (InvoiceQty and
                             DemandCounts — keep in sync)
  - Pieces In Set:          > 1          (change HAVING MAX(Pieces_In_Set)
                             > 1 in InMasterPis) — see NOTES for why this
                             is > 1 and not > 0
  - Min sample size:        >= 3 qualifying invoices (change TotalInvoices
                             >= 3 in FinalJoined's WHERE)
  - Match % threshold:      < 75%        (change the FinalJoined WHERE) —
                             the exact complement of the main tab's >= 75%

OUTPUT COLUMNS:
  Branch            — Branch (grain is Branch + Part)
  Part #            — Part number
  Description       — jdis pi_Description (same source as the main tab)
  Source            — jdis pi_Source
  SLC               — jdis pi_SLC
  Commodity Code    — jdis pi_Commodity_Code
  Dealer Group Code — jdis pi_Dealer_Group_Code
  InMaster PIS      — InMaster.Pieces_In_Set, the value under review
  Most Common Qty   — Modal invoice quantity from actual sales
  Match %           — % of invoices sold at exactly Most Common Qty (< 75%
                      by definition on this tab)
  PIS Multiple %    — % of invoices whose quantity is an exact multiple of
                      InMaster PIS (e.g. PIS = 4 → invoices of 4, 8, 12
                      count). Helper for the review: a high value means
                      the part really does move in that set size even
                      though no single quantity dominates (customers buy
                      1 set, 2 sets, ...), so the PIS may be correct after
                      all. A low value means sales don't line up with the
                      set size — the strongest "fix this" signal.
  Invoices          — Count of qualifying invoices (Match % denominator)
  Demands           — Count of qualifying InTrans lines (same definition
                      as the main tab)
  Sales Qty         — Total units sold in the window

NOTES:
  - Pieces In Set > 1, NOT > 0: in InMaster, Pieces_In_Set = 1 is effectively
    the default — 53,036 franchise D branch/part rows (excl. 2 & 4) carry a
    1, versus ~256 with anything larger (checked live 2026-10-07). A PIS of
    1 means "sold individually", not a set, so "> 0" would bury the ~127
    real review candidates under ~2,900 single-piece parts. Change to > 0
    in InMasterPis if Ben does want those included.
  - InMaster is NOT unique on BRANCH + PART_NO (1,115,532 rows vs 1,109,907
    distinct keys) — the duplicates are the same part number filed under a
    different FRANCHISE (e.g. 'D' vs 'MR'/'M'/'BS'). InMasterPis filters to
    FRANCHISE = 'D' and takes MAX(Pieces_In_Set) per Branch + Part, so a
    part can't fan out into two rows and is flagged if any D row says set.
  - Parts with Pieces_In_Set > 1 but fewer than 3 qualifying invoices (or no
    sales at all) are NOT listed — there isn't enough sales history to say
    whether the PIS is right or wrong.
  - NOT in this tab (by design — Ben's ask was "less than 75%"): parts with
    PIS > 1 that DO sell consistently (Match % >= 75%) but at a different
    quantity than the PIS — e.g. PIS = 4 but 90% of invoices are qty 1.
    Those are also likely wrong PIS values. ~7 such Branch + Parts existed
    live 2026-10-07 (5 consistently sold as singles, 2 at another set size).
    To include them, change the Match % condition in FinalJoined to:
      AND (CAST(r.QtyCount AS FLOAT) / r.TotalInvoices < 0.75
           OR r.Qty <> m.PiecesInSet)
  - jdis_Part_Information is joined via the same JdisDedup pattern as the
    main tab (one winning row per Branch + Part, longest description) as a
    LEFT JOIN — a part missing from jdis still shows up (blank attributes)
    rather than silently disappearing from a cleanup list.
  - Run off-peak if possible (before 7 AM / after 5 PM) — scans 18 months
    of InTrans twice, same as the main tab. ~45s / 125 rows when tested
    live 2026-10-07 (mid-day).

REQUESTED BY: Ben (Corp Parts Manager), via Brian — 2026-10-07. Companion
  tab to SPI -Pieces In Set.pq.
CREATED: 2026-10-07
============================================================================

Power Query M — paste into Excel Advanced Editor:
*/

let
    SQL = "
        WITH InvoiceQty AS (
            -- One row per Branch + Part + Invoice, summing QTY across any
            -- split lines of the same part on the same invoice (same as
            -- the main tab).
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
                AND BRANCH NOT IN ('2', '4')
            GROUP BY BRANCH, PART_NO, REF_NO
        ),
        InMasterPis AS (
            -- Parts set up as a multi-piece set in InMaster. FRANCHISE = 'D'
            -- + MAX() guards against InMaster's cross-franchise duplicate
            -- rows for the same Branch + Part (see NOTES).
            SELECT
                BRANCH,
                PART_NO,
                MAX(Pieces_In_Set) AS PiecesInSet
            FROM InMaster
            WHERE
                FRANCHISE = 'D'
                AND BRANCH NOT IN ('2', '4')
            GROUP BY BRANCH, PART_NO
            HAVING MAX(Pieces_In_Set) > 1
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
            -- Per Branch+Part totals, restricted to InMaster set parts.
            -- PisMultipleInvoices = invoices whose qty is an exact multiple
            -- of the InMaster PIS (feeds PIS Multiple %).
            SELECT
                iq.BRANCH,
                iq.PART_NO,
                COUNT(*)         AS TotalInvoices,
                SUM(iq.InvoiceQty) AS TotalSalesQty,
                SUM(CASE WHEN MOD(iq.InvoiceQty, m.PiecesInSet) = 0 THEN 1 ELSE 0 END)
                                 AS PisMultipleInvoices
            FROM InvoiceQty iq
            INNER JOIN InMasterPis m
                ON  m.BRANCH  = iq.BRANCH
                AND m.PART_NO = iq.PART_NO
            GROUP BY iq.BRANCH, iq.PART_NO
        ),
        DemandCounts AS (
            -- Raw qualifying InTrans ROW count per Branch+Part (same
            -- definition as the main tab's Demands).
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
                AND BRANCH NOT IN ('2', '4')
            GROUP BY BRANCH, PART_NO
        ),
        Ranked AS (
            -- rn = 1 is the modal (most common) quantity per Branch+Part.
            -- Below 75% a tie for the mode CAN happen (unlike the main
            -- tab); the tie-break (smaller Qty first) just keeps it
            -- deterministic — Match % is the same either way.
            SELECT
                q.BRANCH,
                q.PART_NO,
                q.Qty,
                q.QtyCount,
                t.TotalInvoices,
                t.TotalSalesQty,
                t.PisMultipleInvoices,
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
            -- One jdis row per Branch + Part (longest description wins),
            -- same pattern and reason as the main tab's JdisDedup.
            SELECT
                pi_Branch,
                pi_Part_No,
                pi_Description,
                pi_Source,
                pi_SLC,
                pi_Commodity_Code,
                pi_Dealer_Group_Code,
                ROW_NUMBER() OVER (
                    PARTITION BY pi_Branch, pi_Part_No
                    ORDER BY LEN(pi_Description) DESC, pi_Description ASC
                ) AS jrn
            FROM jdis_Part_Information
        ),
        FinalJoined AS (
            SELECT
                r.BRANCH                                                            AS BRANCH,
                r.PART_NO                                                           AS PartNumber,
                p.pi_Description                                                    AS Description,
                p.pi_Source                                                         AS Source,
                p.pi_SLC                                                            AS SLC,
                p.pi_Commodity_Code                                                 AS CommodityCode,
                p.pi_Dealer_Group_Code                                              AS DealerGroupCode,
                m.PiecesInSet                                                       AS PiecesInSet,
                r.Qty                                                               AS MostCommonQty,
                ROUND(CAST(r.QtyCount AS FLOAT) / r.TotalInvoices * 100, 1)         AS MatchPercent,
                ROUND(CAST(r.PisMultipleInvoices AS FLOAT) / r.TotalInvoices * 100, 1) AS PisMultiplePercent,
                r.TotalInvoices                                                     AS Invoices,
                d.Demands                                                           AS Demands,
                r.TotalSalesQty                                                     AS SalesQty
            FROM Ranked r
            INNER JOIN InMasterPis m
                ON  m.BRANCH  = r.BRANCH
                AND m.PART_NO = r.PART_NO
            INNER JOIN DemandCounts d
                ON  d.BRANCH  = r.BRANCH
                AND d.PART_NO = r.PART_NO
            LEFT JOIN JdisDedup p
                ON  p.pi_Branch  = r.BRANCH
                AND p.pi_Part_No = r.PART_NO
                AND p.jrn = 1
            WHERE
                r.rn = 1
                AND r.TotalInvoices >= 3
                AND CAST(r.QtyCount AS FLOAT) / r.TotalInvoices < 0.75
        )
        SELECT *
        FROM FinalJoined
        ORDER BY
            BRANCH,
            PartNumber
    ",
    Source = Odbc.Query("dsn=EquipRDB", SQL),

    // Enforce correct data types from SQL results
    Typed = Table.TransformColumnTypes(Source, {
        {"BRANCH",             type text},
        {"PartNumber",         type text},
        {"Description",        type text},
        {"Source",             type text},
        {"SLC",                type text},
        {"CommodityCode",      type text},
        {"DealerGroupCode",    type text},
        {"PiecesInSet",        Int64.Type},
        {"MostCommonQty",      Int64.Type},
        {"MatchPercent",       type number},
        {"PisMultiplePercent", type number},
        {"Invoices",           Int64.Type},
        {"Demands",            Int64.Type},
        {"SalesQty",           Int64.Type}
    }),

    // Final display names
    Renamed = Table.RenameColumns(Typed, {
        {"BRANCH",             "Branch"},
        {"PartNumber",         "Part #"},
        {"CommodityCode",      "Commodity Code"},
        {"DealerGroupCode",    "Dealer Group Code"},
        {"PiecesInSet",        "InMaster PIS"},
        {"MostCommonQty",      "Most Common Qty"},
        {"MatchPercent",       "Match %"},
        {"PisMultiplePercent", "PIS Multiple %"},
        {"SalesQty",           "Sales Qty"}
    }),

    Sorted = Table.Sort(Renamed, {
        {"Branch", Order.Ascending},
        {"Part #", Order.Ascending}
    })

in
    Sorted
