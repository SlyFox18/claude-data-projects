"""Phase 0 correctness check: row counts of the 9 output tables, and no Silver table in DP_Presentation.

Usage: python proto_counts.py
"""
import sys

import duckdb

sys.stdout.reconfigure(encoding="utf-8")
STAGING = "abfss://ab15d64d-c7ba-415d-9bcf-7feb1ef9b201@onelake.dfs.fabric.microsoft.com/876255e0-d462-4697-adc1-4a655f5bb101/Tables/"
PRESENTATION = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables/"
SILVER = ["Silver_WkMechFl", "Silver_Contact", "Silver_WkMechAdj", "Silver_WkMechWk", "Silver_WkOthSub"]
GOLD = ["dim_Technician_Code_Names", "TechnicianAttendance", "TechnicianPunchedTime", "TechnicianEfficiency"]

con = duckdb.connect()
con.sql("SET TimeZone='UTC'; INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.sql("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
for root, tables in ((STAGING, SILVER), (PRESENTATION, GOLD)):
    for t in tables:
        n = con.sql(f"SELECT count(*) FROM delta_scan('{root}{t}')").fetchone()[0]
        print(f"{t:28s} {n:>12,}")
stray = []
for t in SILVER:
    try:
        con.sql(f"SELECT 1 FROM delta_scan('{PRESENTATION}{t}') LIMIT 1").fetchall()
        stray.append(t)
    except duckdb.Error:
        pass
print("stray Silver tables in DP_Presentation:", stray or "none")
sys.exit(1 if stray else 0)
