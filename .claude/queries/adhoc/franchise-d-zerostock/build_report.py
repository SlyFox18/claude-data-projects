"""
FRANCHISE D - ZERO STOCK, COMPANY-WIDE DEMAND (AD HOC)
============================================================================
Request: Ben (Corp Parts Manager), via Brian, 2026-08-27. Company-wide
reorder-candidate view of Franchise D parts: zero on-hand AND zero on-order
at EVERY branch, but still generating demand at 3+ distinct branches over
the last 18 months (excluding the most recent 7 days).

This is a SEPARATE analysis from the branch-level report in
.claude/queries/adhoc/FranchiseD_LowDemand_Parts_CrossBranch.pq (the
"5 candidate branches vs. everyone else" query). Different grain, different
question - do not merge them.

Source: LH_Master_Data lakehouse, queried directly via DuckDB over OneLake
(same pattern as ../kurt-sales/build_report.py) - NOT a live Power Query
against the ODBC source (dsn=EquipRDB64).

Why this is a script and not a Power Query in Excel: the equivalent SQL was
tried as an ad-hoc .pq query against the live ODBC source
(FranchiseD_ZeroStock_CompanyWide.pq, still in .claude/queries/adhoc/ for
reference/history) and hung for 30+ minutes, twice, even with source
capacity confirmed fine. Diagnosed 2026-08-27 by running the real numbers
against the Lakehouse: this isn't a badly-written query, the workload is
just large. Franchise D is ~80% of the ENTIRE parts catalog (886,523 of
1,110,498 jdis_Part_Information rows) - unlike the branch-level sibling
report, which narrows scope to 5 of 47 branches (~10%), this query can't
meaningfully restrict scope at all and has to touch 500K-900K+ rows on both
the jdis and InTrans sides. DuckDB (columnar, over OneLake) runs the full
pipeline in ~30 seconds; dsn=EquipRDB64 (row-store OLTP over an ODBC network
bridge) does not, and there's no rewrite of the SQL that fixes that - the
scale is the problem, not the query shape.

Tables used:
- jdis_Part_Information - part attributes + eligibility (PackageQty,
  Returnable, Source, SLC, QuantityOnHand, OnOrder)
- InTrans_Incremental    - demand (Franchise D customer invoices, Qty > 0)

Trade-off vs. a live Power Query: this is run-on-demand, not
auto-refreshing in the workbook. Data is as fresh as the last Lakehouse
dataflow run (jdis refreshes 3x/day; InTrans_Incremental refreshes on the
nightly pipeline) - not live-ODBC-fresh, but should be more than fresh
enough for a reorder-candidate scan. Re-run this script any time for an
updated pull.

============================================================================
CONFIRMED WITH BEN (2026-08-27, via Brian)
============================================================================
  1. On Hand = 0: CONFIRMED as EVERY branch showing exactly 0 (not summed
     across branches). A part with +5 at one branch and -5 at another is
     EXCLUDED (sum would be 0, but not every branch is 0).
  2. On Order = 0: CONFIRMED same "every branch = 0" logic as #1.
  3. Branch scope: CORRECTED per Ben - branches 2 & 4 ARE excluded here too,
     same as the branch-level report (Brian's original guess of "include
     all branches" was the one thing Ben corrected).
  4. Source <> 'AN' / SLC exclusions (21%, 90%, 91%, 99%) / the 7-day-to-
     18-month demand window: CONFIRMED, carried over identically from the
     branch-level report.
  5. A branch excluded by Source/SLC (or now, by the 2/4 exclusion) is
     treated as irrelevant to the "on hand = 0 everywhere" check - i.e.
     nonzero stock at an excluded branch does not disqualify the part.
     Not explicitly discussed with Ben, but consistent with #3/#4 being
     confirmed as real exclusions rather than just missing data.

Output: "Franchise D - Zero Stock Company-Wide Demand.xlsx"
- One row per qualifying part, sorted by LocationCount desc, then
  TotalDemand desc.

Run manually - not part of any scheduled pipeline.
============================================================================
"""

import duckdb
import pandas as pd

WS_ID = "b48cdb35-7ce3-46de-96df-d70db77649cb"   # LH_Master_Data workspace
LH_ID = "3e74497b-8c51-4a1a-91a1-888c59118f48"   # LH_Master_Data lakehouse
base = f"abfss://{WS_ID}@onelake.dfs.fabric.microsoft.com/{LH_ID}/Tables"

out_path = "Franchise D - Zero Stock Company-Wide Demand.xlsx"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

result = con.execute(f"""
    WITH eligible AS (
        -- Zero stock AND zero on-order at EVERY eligible branch that
        -- carries the part (after Source/SLC exclusions AND the 2/4
        -- branch exclusion are applied) - see CONFIRMED #1, #2, #3, #5
        -- above.
        SELECT
            PartNumber,
            MAX(Description)     AS Description,
            MAX(Cost)            AS Cost,
            MAX(Source)          AS Source,
            MAX(SLC)             AS SLC,
            MAX(CommodityCode)   AS CommodityCode,
            MAX(DealerGroupCode) AS DealerGroupCode
        FROM delta_scan('{base}/jdis_Part_Information')
        WHERE Franchise = 'D'
          AND Branch NOT IN ('2', '4')
          AND PackageQty = 1
          AND Returnable = 'R'
          AND Source <> 'AN'
          AND SLC NOT LIKE '21%'
          AND SLC NOT LIKE '90%'
          AND SLC NOT LIKE '91%'
          AND SLC NOT LIKE '99%'
        GROUP BY PartNumber
        HAVING SUM(CASE WHEN COALESCE(QuantityOnHand, 0) <> 0 THEN 1 ELSE 0 END) = 0
           AND SUM(CASE WHEN COALESCE(OnOrder, 0)        <> 0 THEN 1 ELSE 0 END) = 0
    ),
    demand AS (
        -- Branches 2 & 4 excluded (CONFIRMED #3), fine-grained
        -- PartNumber+Branch, same demand definition as the branch-level
        -- report (customer invoice, Qty > 0, 7d-18mo window).
        SELECT PartNumber, Branch, COUNT(*) AS Demands
        FROM delta_scan('{base}/InTrans_Incremental')
        WHERE Franchise = 'D'
          AND Branch NOT IN ('2', '4')
          AND Type = 'I'
          AND Qty > 0
          AND TransDatetime >= CURRENT_DATE - INTERVAL 18 MONTH
          AND TransDatetime <= CURRENT_DATE - INTERVAL 7 DAY
        GROUP BY PartNumber, Branch
    )
    SELECT
        e.PartNumber,
        e.Description,
        e.Cost,
        e.Source,
        e.SLC,
        e.CommodityCode,
        e.DealerGroupCode,
        0 AS OnOrder,
        0 AS OnHandQty,
        COALESCE(SUM(d.Demands), 0) AS TotalDemand,
        COUNT(DISTINCT d.Branch)    AS LocationCount
    FROM eligible e
    LEFT JOIN demand d ON d.PartNumber = e.PartNumber
    GROUP BY e.PartNumber, e.Description, e.Cost, e.Source, e.SLC, e.CommodityCode, e.DealerGroupCode
    HAVING COUNT(DISTINCT d.Branch) >= 3
    ORDER BY LocationCount DESC, TotalDemand DESC, e.PartNumber
""").df()

print(f"Result rows: {len(result)}")

with pd.ExcelWriter(out_path, engine="openpyxl") as writer:
    result.to_excel(writer, sheet_name="Zero Stock Company-Wide", index=False)

print(f"Saved: {out_path}")
