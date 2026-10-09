"""Read-only: compare Fact_PartMaster_History (as of a date) with LH_Master_Data's PartMaster snapshots.

Usage: python partmaster_history_check.py <dev|prod> <YYYY-MM-DD> [weekly]
  daily  (default): 15 shared columns vs Fact_PartMaster_Snapshot_Daily for that date. The daily
                    snapshot has no Franchise, so Branch+PartNumber keys that exist under two
                    franchises are left out of the value comparison.
  weekly          : all 33 columns vs Fact_PartMaster_Snapshot_Weekly for that date (a Sunday).
Expected differences: timing (LH snapshots 02:00 from the 01:15 ODBC refresh; DP reads JD Bronze
in the morning refresh). Anything else is a bug.
"""
import sys
import duckdb

TIERS = {"dev": "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables/",
         "prod": "abfss://7836042d-adb1-4846-b70d-bd42980054c5@onelake.dfs.fabric.microsoft.com/29d9df80-a383-4d40-9807-1e2e6cbff88f/Tables/"}
LH = "abfss://b48cdb35-7ce3-46de-96df-d70db77649cb@onelake.dfs.fabric.microsoft.com/3e74497b-8c51-4a1a-91a1-888c59118f48/Tables/"
DAILY = ["QuantityOnHand", "BinQty", "BulkBinQty", "PendingQty", "BackOrderQty", "OnOrder", "Cost", "SellPrice1",
         "ListPrice", "InventoryCost", "Current12MoSales", "Current12MoDollars", "DateLastRequested"]
TIMESTAMPS = {"DateLastRequested", "DateCreated", "StocktakeDate"}


def norm(c):
    # Timestamps are compared as-is in a UTC session: casting to DATE in the PC's local zone shifted values
    # across midnight and reported 23% of DateLastRequested as different when only 0.1% were (2026-10-09).
    return c if c in TIMESTAMPS else (f"ROUND(CAST({c} AS DOUBLE), 2)" if c not in
           {"Branch", "Franchise", "PartNumber", "Description", "Source", "SLC", "CommodityCode", "DealerGroupCode",
            "BulkBin", "Bin", "PackageQty", "Returnable", "SuperTo", "SuperFrom"} else f"TRIM(CAST({c} AS VARCHAR))")


def main(tier, d, mode="daily"):
    sys.stdout.reconfigure(encoding="utf-8")
    con = duckdb.connect()
    con.sql("INSTALL azure; LOAD azure; INSTALL delta; LOAD delta;")
    con.sql("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli', ACCOUNT_NAME 'onelake');")
    con.sql("SET TimeZone = 'UTC'")
    con.sql(f"""CREATE TABLE h AS SELECT * FROM delta_scan('{TIERS[tier]}Fact_PartMaster_History')
                WHERE ValidFrom <= DATE '{d}' AND DATE '{d}' < ValidTo""")
    src = "Fact_PartMaster_Snapshot_Daily" if mode == "daily" else "Fact_PartMaster_Snapshot_Weekly"
    con.sql(f"CREATE TABLE s AS SELECT * FROM delta_scan('{LH}{src}') WHERE SnapshotDate = DATE '{d}'")
    print(f"{tier} history as of {d}: {con.sql('SELECT count(*) FROM h').fetchone()[0]:,} rows; "
          f"LH {src} {d}: {con.sql('SELECT count(*) FROM s').fetchone()[0]:,} rows")
    if mode == "daily":
        key, cols = ["Branch", "PartNumber"], DAILY
        con.sql("CREATE TABLE amb AS SELECT Branch, PartNumber FROM h GROUP BY ALL HAVING count(*) > 1")
        print(f"  Branch+PartNumber under 2+ franchises (excluded): {con.sql('SELECT count(*) FROM amb').fetchone()[0]:,}")
        flt = "WHERE (Branch, PartNumber) NOT IN (SELECT (Branch, PartNumber) FROM amb)"
    else:
        key = ["Branch", "Franchise", "PartNumber"]
        cols = [c for c in con.sql("SELECT * FROM s LIMIT 0").columns
                if c not in key + ["SnapshotDate", "SnapshotWeek", "SnapshotDateTime"]]
        flt = ""
    sel = ", ".join(f"{norm(c)} AS {c}" for c in key + cols)
    con.sql(f"CREATE TABLE a AS SELECT {sel} FROM h {flt}")
    con.sql(f"CREATE TABLE b AS SELECT {sel} FROM s {flt}")
    on = " AND ".join(f"a.{k} = b.{k}" for k in key)
    print("  keys only in history:", con.sql(f"SELECT count(*) FROM a ANTI JOIN b ON {on}").fetchone()[0],
          "| keys only in LH:", con.sql(f"SELECT count(*) FROM b ANTI JOIN a ON {on}").fetchone()[0])
    total = con.sql(f"SELECT count(*) FROM a JOIN b ON {on}").fetchone()[0]
    print(f"  matched keys: {total:,}; rows differing per column:")
    for c in cols:
        n = con.sql(f"SELECT count(*) FROM a JOIN b ON {on} WHERE a.{c} IS DISTINCT FROM b.{c}").fetchone()[0]
        if n:
            print(f"    {c}: {n:,} ({n / total:.3%})")


if __name__ == "__main__":
    main(*sys.argv[1:])
