"""
FRANCHISE D - ZERO STOCK, COMPANY-WIDE DEMAND (AD HOC)
============================================================================
Request: Ben (Corp Parts Manager), via Brian, 2026-08-27. Company-wide
reorder-candidate view of Franchise D parts: zero on-hand AND zero on-order
at EVERY branch, but still generating demand at 3+ distinct branches over
the last 18 months (excluding the most recent 7 days).

Feeds the "SPI Corparate Stocking.xlsx" workbook (Corp Parts Excel Reports
SharePoint library) - see README.md in this folder.

This is a SEPARATE analysis from Border Stores (../Border Stores/Border
Stores.pq, the "candidate branches vs. everyone else" query). Different
grain, different question - do not merge them.

Source: DP - Staging - Prod lakehouse (DP_Staging: Silver_PartInformation +
Silver_InTrans), queried directly via DuckDB over OneLake (same pattern as
.claude/queries/adhoc/kurt-sales/build_report.py) - NOT a live Power Query
against the ODBC source. Switched from LH_Master_Data 2026-10-07: LH's
InTrans_Incremental over-counts some demand, DP matched live EquipRDB exactly
on every sampled part - see README "Data source".

Why this is a script and not a Power Query in Excel: the equivalent SQL was
tried as an ad-hoc .pq query against the live ODBC source
(history/FranchiseD_ZeroStock_CompanyWide (ODBC attempt - hung).pq) and
hung for 30+ minutes, twice, even with source
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

Tables used (same column names as the old LH_Master_Data tables):
- Silver_PartInformation - part attributes + eligibility (PackageQty,
  Returnable, Source, SLC, QuantityOnHand, OnOrder)
- Silver_InTrans          - demand (Franchise D customer invoices, Qty > 0)

Trade-off vs. a live Power Query: this is run-on-demand, not
auto-refreshing in the workbook. Data is as fresh as the last DP Prod Silver
run. Until DP cutover those runs are MANUAL, so the script prints how fresh
each input is and warns if either is more than 2 days old - run the DP
Silver notebooks first if it warns.

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

import os

import duckdb
import pandas as pd

import datetime

WS_ID = "189e5c0a-548a-4feb-93d6-dda9ebbe96c1"   # DP - Staging - Prod workspace
LH_ID = "6713bd45-a4ad-47e6-8bff-1bb0415e9784"   # DP_Staging (Prod) lakehouse
base = f"abfss://{WS_ID}@onelake.dfs.fabric.microsoft.com/{LH_ID}/Tables"
STALE_AFTER = datetime.timedelta(days=2)

# Write into the SharePoint-synced "Corp Parts Excel Reports" library's
# "Source Data" subfolder, NOT next to this script - Supplemental
# Stocking.xlsx now lives in that same SharePoint library (moved 2026-09-15
# so Ben/Barry/Curt/Shannon can all reach it), and its Power Query pulls
# this file straight from SharePoint via SharePoint.Files(), not a local
# path. This file was moved into "Source Data" 2026-09-17 to keep it out of
# the way of the workbooks people actually open - it's a data source, not
# something anyone needs to open directly. Saving here lets OneDrive sync
# push the update to SharePoint automatically - no manual upload step after
# each run. Read by the "SPI Corparate Stocking" query in SPI Corparate
# Stocking.xlsx - see README.md in this folder.
SHAREPOINT_SYNC_DIR = r"C:\Users\bfox\spitractor\South Plains Implement - Report Site - Corp Parts Excel Reports\Source Data"
out_path = os.path.join(SHAREPOINT_SYNC_DIR, "Franchise D - Zero Stock Company-Wide Demand.xlsx")

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

# Freshness check - DP Prod Silver is refreshed manually until cutover, so make
# a stale input obvious instead of silently publishing old data.
now = datetime.datetime.now(datetime.timezone.utc)
last_trans = con.execute(f"SELECT MAX(TransDatetime) FROM delta_scan('{base}/Silver_InTrans')").fetchone()[0]
last_parts = con.execute(f"""
    SELECT to_timestamp(MAX(commitInfo.timestamp) / 1000)
    FROM read_json_auto('{base}/Silver_PartInformation/_delta_log/*.json', union_by_name=true, ignore_errors=true)
    WHERE commitInfo IS NOT NULL""").fetchone()[0]
for label, ts in (("Silver_InTrans latest transaction", last_trans), ("Silver_PartInformation last refresh", last_parts)):
    ts = ts if ts.tzinfo else ts.replace(tzinfo=datetime.timezone.utc)
    flag = "  <-- STALE: run the DP Prod Silver notebooks first" if now - ts > STALE_AFTER else ""
    print(f"{label}: {ts.astimezone():%Y-%m-%d %H:%M}{flag}")

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
        FROM delta_scan('{base}/Silver_PartInformation')
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
        FROM delta_scan('{base}/Silver_InTrans')
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
