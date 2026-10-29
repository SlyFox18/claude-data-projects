import duckdb, sys
sys.stdout.reconfigure(encoding="utf-8")
WS="4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9"; LH="7348c3a6-8694-4d11-bc70-1bd55be84ea2"
con=duckdb.connect()
con.sql("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.sql("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
for t in ["contact","ArMaster","ArMaster_Customer"]:
    cols=con.sql(f"DESCRIBE SELECT * FROM delta_scan('abfss://{WS}@onelake.dfs.fabric.microsoft.com/{LH}/Tables/{t}')").fetchall()
    n=con.sql(f"SELECT count(*) FROM delta_scan('abfss://{WS}@onelake.dfs.fabric.microsoft.com/{LH}/Tables/{t}')").fetchone()[0]
    print(f"\n=== {t} ({n:,} rows, {len(cols)} cols)")
    print(", ".join(c[0] for c in cols))
