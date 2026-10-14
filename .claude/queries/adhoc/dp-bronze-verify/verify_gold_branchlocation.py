"""
DP GOLD BRANCHLOCATION VERIFICATION
============================================================================
Independent check of dim_BranchLocation (built by
Build_Gold_BranchLocation.Notebook) - confirms row count, that Seminole
(BranchID '1') survived filtering (the specific branch a prior production
bug - arbitrary Table.Skip(30) - used to drop, per that table's own header
comment), and spot-checks BranchType/RegionalClassification for a few known
branches against the documented business rules.

Run manually after the notebook confirmed it ran successfully.
============================================================================
"""

import duckdb

DP_PRESENTATION_WS_ID = "73fd5443-240e-410a-990a-98827f32c087"
DP_PRESENTATION_LH_ID = "966efc8a-16f9-423b-aa43-e368fcd8fb91"
dp_base = f"abfss://{DP_PRESENTATION_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_PRESENTATION_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=== Check 1: row count ===")
row_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/dim_BranchLocation')").fetchone()[0]
print(f"Row count: {row_count} (production has 69 operational branches - expect a similar count)")

print("\n=== Check 2: Seminole (BranchID '1') present and correctly classified ===")
seminole = con.execute(f"""
    SELECT BranchKey, Branch, BranchType, BranchID, State, City, RegionalClassification, DataQualityScore
    FROM delta_scan('{dp_base}/dim_BranchLocation')
    WHERE BranchID = '1'
""").df()
print(seminole.to_string())
print(f"Expect exactly 1 row, BranchType='Main Branch', RegionalClassification='West Texas': "
      f"{'PASS' if len(seminole) == 1 and seminole['BranchType'][0] == 'Main Branch' and seminole['RegionalClassification'][0] == 'West Texas' else 'FAIL'}")

print("\n=== Check 3: no Hourly/Salary branches leaked through ===")
leaked = con.execute(f"""
    SELECT COUNT(*) FROM delta_scan('{dp_base}/dim_BranchLocation')
    WHERE BranchID LIKE 'H%' OR BranchID LIKE 'S%'
""").fetchone()[0]
print(f"Hourly/Salary branches in output (expect 0): {leaked}")

print("\n=== Check 4: BranchType distribution sanity ===")
breakdown = con.execute(f"""
    SELECT BranchType, COUNT(*) AS cnt
    FROM delta_scan('{dp_base}/dim_BranchLocation')
    GROUP BY BranchType
    ORDER BY cnt DESC
""").df()
print(breakdown.to_string())
