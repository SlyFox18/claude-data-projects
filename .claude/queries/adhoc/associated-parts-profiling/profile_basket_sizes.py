"""
Associated Parts — basket size profiling (2026-08-27)
Determines the distinct-parts-per-invoice distribution in InTrans_Incremental
over the last 24 months, so a data-driven basket-size cap can be chosen
before building Fact_PartAssociation. See:
docs/superpowers/specs/2026-08-27-associated-parts-design.md
"""
import duckdb

WS_ID = "b48cdb35-7ce3-46de-96df-d70db77649cb"
LH_ID = "3e74497b-8c51-4a1a-91a1-888c59118f48"
base = f"abfss://{WS_ID}@onelake.dfs.fabric.microsoft.com/{LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

result = con.execute(f"""
    WITH baskets AS (
        SELECT Franchise, Branch, RONumber, COUNT(DISTINCT PartNumber) AS DistinctParts
        FROM delta_scan('{base}/InTrans_Incremental')
        WHERE Type = 'I' AND Qty > 0
          AND TransDatetime >= CURRENT_DATE - INTERVAL 24 MONTH
          AND PartNumber IS NOT NULL AND PartNumber <> ''
        GROUP BY Franchise, Branch, RONumber
    )
    SELECT
        COUNT(*)                                   AS TotalBaskets,
        MIN(DistinctParts)                         AS MinParts,
        approx_quantile(DistinctParts, 0.50)       AS P50,
        approx_quantile(DistinctParts, 0.90)       AS P90,
        approx_quantile(DistinctParts, 0.95)       AS P95,
        approx_quantile(DistinctParts, 0.99)       AS P99,
        MAX(DistinctParts)                         AS MaxParts
    FROM baskets
""").df()

print(result.to_string(index=False))
