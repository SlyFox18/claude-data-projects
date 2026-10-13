/*
============================================================================
Query: SPI Corparate Stocking — SPI Corparate Stocking.xlsx
Type: Excel Power Query (Advanced Editor) — Corp Parts Excel Reports library
Connection: ODBC — dsn=EquipRDB (live, like the other Corp Parts workbooks)
Source Tables: jdis_Part_Information (eligibility + attributes),
               InTrans (demand)
============================================================================

PURPOSE:
Company-wide reorder-candidate view — Franchise D parts with ZERO on-hand
and ZERO on-order at EVERY branch that still generate demand at 3+ distinct
branches. One row per part (no Branch column). Different grain from Border
Stores, which flags a low-demand branch against a candidate list.
Requested by Ben (Corp Parts Manager) via Brian, 2026-08-27.

REFRESH = LIVE EQUIP DATA (since 2026-10-13). Until 2026-10-13 this query
only re-read a file ("Source Data/Franchise D - Zero Stock Company-Wide
Demand.xlsx") written by build_report.py from Fabric; Refresh now queries
Equip directly, so the script and that file are no longer used (both kept
for reference — see README.md).

LOGIC (confirmed with Ben — same rules as build_report.py):
  Eligibility (jdis, per part, across branches):
    - Franchise D, branches 2 & 4 excluded
    - Package Qty = 1, Return Indicator = 'R', Source <> 'AN',
      SLC NOT LIKE 21%/90%/91%/99%
    - On Hand = 0 AND On Order = 0 at EVERY remaining eligible branch
      (every branch = 0, not the sum across branches)
    - Not superseded at ANY eligible branch (Super To blank, trimmed)
    - A branch excluded by Source/SLC or the 2/4 exclusion doesn't count
      against "zero everywhere"
  Demand (InTrans, per part + branch) — shared Corp Parts definition:
    - One customer INVOICE (TYPE 'I', QTY > 0, 7 days – 18 months back);
      several lines on one invoice count once
    - Credits (TYPE 'C', QTY < 0) netted back to the invoice they return
      (ORIGINAL_INVOICE_NO); an invoice credited to net qty <= 0 doesn't count
    - Branches 2 & 4 excluded; transfers never count
  Keep parts with demand at 3+ branches (no floor on total demand).

OUTPUT COLUMNS:
  PartNumber, Description, Cost, Source, SLC, CommodityCode, DealerGroupCode,
  OnOrder (always 0), OnHandQty (always 0),
  R18 Demands                      — total demands, all branches
  Count of Locations with Demands  — branches with demand
  Locations with Demands           — those branches, e.g. "11, 13, 93, 95"
  Sorted by Count of Locations desc, R18 Demands desc, PartNumber.

PERFORMANCE / WHY TWO QUERIES:
  - Two plain single-table queries, combined here in Power Query:
    Eligibility (one GROUP BY scan of jdis, ~78K parts, ~11s live) and
    Demand (one GROUP BY scan of InTrans, ~162K part/branch rows, ~5s).
  - The 2026-08-27 live attempt (history/…ODBC attempt - hung.pq) hung
    because of its SHAPE, not the data volume: jdis filtered by
    "pi_Part_No IN (subquery)" and a LEFT JOIN between two derived tables —
    both known to crawl on SQL Anywhere (see the folder CLAUDE.md). Don't
    move the combine step back into SQL as a join.
  - Checked 2026-10-13 against the DP-built file from the same morning:
    1,785 vs 1,774 parts, 1,768 in common, 1,758 of those with identical
    demand — the rest is Equip changing since the 06:15 DP refresh.
    DE18732: 4 demands at 11, 13, 93, 95 in both.
  - Run off-peak if possible (before 7 AM / after 5 PM).

REQUESTED BY: Ben (Corp Parts Manager), via Brian — 2026-08-27
UPDATED: 2026-10-13 — new "Locations with Demands" column; TotalDemand →
  "R18 Demands", LocationCount → "Count of Locations with Demands"; demand
  = invoices net of credits (per Ben)
UPDATED: 2026-10-13 — switched from the build_report.py source file to live
  ODBC (dsn=EquipRDB), so users refresh on demand without the script
============================================================================

Power Query M — paste into Excel Advanced Editor:
*/

let
    // Parts eligible company-wide: zero on-hand, zero on-order and not
    // superseded at every eligible branch (HAVING counts offending branches).
    EligibilitySQL = "
        SELECT
            pi_Part_No                  AS PartNumber,
            MAX(pi_Description)         AS Description,
            MAX(pi_Cost)                AS Cost,
            MAX(pi_Source)              AS Source,
            MAX(pi_SLC)                 AS SLC,
            MAX(pi_Commodity_Code)      AS CommodityCode,
            MAX(pi_Dealer_Group_Code)   AS DealerGroupCode
        FROM jdis_Part_Information
        WHERE
            pi_Franchise = 'D'
            AND pi_Branch NOT IN ('2', '4')
            AND pi_Package_Qty = 1
            AND pi_Return_Indicator = 'R'
            AND pi_Source <> 'AN'
            AND pi_SLC NOT LIKE '21%'
            AND pi_SLC NOT LIKE '90%'
            AND pi_SLC NOT LIKE '91%'
            AND pi_SLC NOT LIKE '99%'
        GROUP BY pi_Part_No
        HAVING
            SUM(CASE WHEN COALESCE(pi_On_Hand_Qty, 0) <> 0 THEN 1 ELSE 0 END) = 0
            AND SUM(CASE WHEN COALESCE(pi_On_Order, 0) <> 0 THEN 1 ELSE 0 END) = 0
            AND SUM(CASE WHEN COALESCE(RTRIM(pi_Super_To), '') <> '' THEN 1 ELSE 0 END) = 0
    ",

    // Demands per part + branch. Inner query: one row per invoice — invoice
    // lines keyed on REF_NO, credits on ORIGINAL_INVOICE_NO — so NetQty is
    // the invoice qty net of credits. Outer: count invoices still positive.
    DemandSQL = "
        SELECT
            x.PART_NO   AS PartNumber,
            x.BRANCH    AS Branch,
            COUNT(*)    AS Demands
        FROM (
            SELECT
                BRANCH,
                PART_NO,
                SUM(QTY) AS NetQty,
                MAX(CASE WHEN TYPE = 'I' THEN 1 ELSE 0 END) AS HasInvoice
            FROM InTrans
            WHERE
                FRANCHISE = 'D'
                AND BRANCH NOT IN ('2', '4')
                AND Trans_Datetime >= DATEADD(month, -18, GETDATE())
                AND (
                    -- invoice lines: 7 days – 18 months back
                    (TYPE = 'I' AND QTY > 0 AND Trans_Datetime <= DATEADD(day, -7, GETDATE()))
                    -- credits: no 7-day cutoff, a recent credit still cancels an older sale
                 OR (TYPE = 'C' AND QTY < 0)
                )
            GROUP BY
                BRANCH,
                PART_NO,
                CASE WHEN TYPE = 'I' THEN REF_NO ELSE ORIGINAL_INVOICE_NO END
        ) x
        WHERE
            x.NetQty > 0          -- not fully credited back
            AND x.HasInvoice = 1  -- a credit whose invoice is outside the window counts for nothing
        GROUP BY
            x.PART_NO,
            x.BRANCH
    ",

    Eligibility = Table.TransformColumnTypes(
        Odbc.Query("dsn=EquipRDB", EligibilitySQL), {
            {"PartNumber",      type text},
            {"Description",     type text},
            {"Cost",            type number},
            {"Source",          type text},
            {"SLC",             type text},
            {"CommodityCode",   type text},
            {"DealerGroupCode", type text}
        }),

    Demand = Table.TransformColumnTypes(
        Odbc.Query("dsn=EquipRDB", DemandSQL), {
            {"PartNumber", type text},
            {"Branch",     type text},
            {"Demands",    Int64.Type}
        }),

    // Roll demand up to the part. Each part + branch is already one row,
    // so the row count = number of branches with demand. Branch list is
    // sorted numerically (non-numeric branch codes, if any, go last).
    ByPart = Table.Group(Demand, {"PartNumber"}, {
        {"TotalDemand",    each List.Sum([Demands]), Int64.Type},
        {"LocationCount",  each Table.RowCount(_), Int64.Type},
        {"DemandBranches", each Text.Combine(
            List.Sort(List.Transform([Branch], Text.Trim),
                      each try Number.From(_) otherwise 99999),
            ", "), type text}
    }),

    ThreePlus = Table.SelectRows(ByPart, each [LocationCount] >= 3),

    // Inner join: keep only parts that are also eligible (zero stock
    // everywhere, not superseded, etc.)
    Joined = Table.NestedJoin(ThreePlus, {"PartNumber"}, Eligibility, {"PartNumber"}, "Part", JoinKind.Inner),
    Expanded = Table.ExpandTableColumn(Joined, "Part",
        {"Description", "Cost", "Source", "SLC", "CommodityCode", "DealerGroupCode"}),

    // Always 0 by construction (they're filter criteria) — shown for visibility
    WithOnOrder  = Table.AddColumn(Expanded, "OnOrder", each 0, Int64.Type),
    WithOnHand   = Table.AddColumn(WithOnOrder, "OnHandQty", each 0, Int64.Type),

    Ordered = Table.SelectColumns(WithOnHand, {
        "PartNumber", "Description", "Cost", "Source", "SLC", "CommodityCode",
        "DealerGroupCode", "OnOrder", "OnHandQty",
        "TotalDemand", "LocationCount", "DemandBranches"
    }),

    Sorted = Table.Sort(Ordered, {
        {"LocationCount", Order.Descending},
        {"TotalDemand",   Order.Descending},
        {"PartNumber",    Order.Ascending}
    }),

    // Display names requested by Ben 2026-10-13
    Renamed = Table.RenameColumns(Sorted, {
        {"TotalDemand",    "R18 Demands"},
        {"LocationCount",  "Count of Locations with Demands"},
        {"DemandBranches", "Locations with Demands"}
    })
in
    Renamed
