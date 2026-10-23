"""Copy the DP Prod Gold tables the trigger exploration reads into a local DuckDB file (read-only on OneLake).
Usage: python pull.py prices.duckdb"""
import duckdb, sys
sys.stdout.reconfigure(encoding="utf-8")
P = "abfss://7836042d-adb1-4846-b70d-bd42980054c5@onelake.dfs.fabric.microsoft.com/29d9df80-a383-4d40-9807-1e2e6cbff88f/Tables/"
con = duckdb.connect(sys.argv[1])
con.sql("INSTALL azure; LOAD azure; INSTALL delta; LOAD delta;")
con.sql("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli', ACCOUNT_NAME 'onelake');")
con.sql("SET TimeZone = 'UTC'")
for t in ["Fact_PartPriceChange", "Fact_JDNationalPriceChange", "dim_Parts"]:
    con.sql(f"CREATE OR REPLACE TABLE {t} AS SELECT * FROM delta_scan('{P}{t}')")
    print(t, con.sql(f"SELECT count(*) FROM {t}").fetchone()[0])
# Per-date on-hand exposure from the branch fact (too big to copy whole)
con.sql(f"""CREATE OR REPLACE TABLE branch_wave AS SELECT EffectiveDate, count(*) n_rows, count(*) FILTER (WHERE OnHandQty>0) n_onhand,
     sum(InventoryCostImpact) cost_impact, sum(OnHandQty*OldCost) FILTER (WHERE OnHandQty>0) onhand_old_cost
     FROM delta_scan('{P}Fact_PartPriceChange_Branch') GROUP BY 1""")
print("branch_wave", con.sql("SELECT count(*) FROM branch_wave").fetchone()[0])
