"""
DP_PRESENTATION - BATCH C DIMENSIONS VERIFICATION
============================================================================
Confirms the 4 Batch C dimension builds landed correctly: dim_Franchise,
dim_JobCode, dim_ModuleType, dim_Technician_Code_Names.

Run manually after Brian adds the Silver_WkRoDesc, Silver_WkOthSub,
Silver_TechnicianPunchedDetail, and Silver_WkMechFl shortcuts to
DP_Presentation, syncs the workspace, and runs all 4 notebooks.
============================================================================
"""

import duckdb

DP_PRESENTATION_WS_ID = "73fd5443-240e-410a-990a-98827f32c087"
DP_PRESENTATION_LH_ID = "966efc8a-16f9-423b-aa43-e368fcd8fb91"
base = f"abfss://{DP_PRESENTATION_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_PRESENTATION_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")


def check_table(name, expected_cols, expect_row_range=None):
    print("=" * 80)
    print(f"VERIFY: {name}")
    print("=" * 80)
    count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/{name}')").fetchone()[0]
    print(f"Row count: {count:,}" + (f" (expect {expect_row_range})" if expect_row_range else ""))

    cols = con.execute(f"DESCRIBE SELECT * FROM delta_scan('{base}/{name}') LIMIT 0").df()
    col_set = set(cols["column_name"].tolist())
    if col_set == expected_cols:
        print(f"PASS: {len(expected_cols)}-column contract matches exactly.")
    else:
        print(f"Missing: {expected_cols - col_set}")
        print(f"Extra: {col_set - expected_cols}")
    print()


check_table(
    "dim_Franchise",
    {"FranchiseKey", "Franchise", "FranchiseCode", "FranchiseDisplayName"},
)
check_table(
    "dim_JobCode",
    {"JobCodeKey", "JobCode", "JobCodeDisplayName", "JobCodeShortDesc"},
)
check_table(
    "dim_ModuleType",
    {"ModuleTypeKey", "ModuleTypeDescription", "SortOrder"},
    expect_row_range="11 (production's own '11 explicit categories')",
)
check_table(
    "dim_Technician_Code_Names",
    {"TechnicianKey", "TechnicianCode", "TechnicianDisplayName", "IsActive"},
    expect_row_range="~1,417 per production's own documentation",
)

print("=" * 80)
print("dim_ModuleType - all rows")
print("=" * 80)
mt = con.execute(f"SELECT * FROM delta_scan('{base}/dim_ModuleType') ORDER BY SortOrder").df()
print(mt.to_string())

print("\n" + "=" * 80)
print("dim_Franchise - sample")
print("=" * 80)
fr = con.execute(f"SELECT * FROM delta_scan('{base}/dim_Franchise') ORDER BY FranchiseKey LIMIT 10").df()
print(fr.to_string())

print("\n" + "=" * 80)
print("dim_JobCode - sample + Inspection classification spot check")
print("=" * 80)
jc = con.execute(f"SELECT * FROM delta_scan('{base}/dim_JobCode') ORDER BY JobCodeKey LIMIT 5").df()
print(jc.to_string())
inspection = con.execute(f"""
    SELECT * FROM delta_scan('{base}/dim_JobCode')
    WHERE JobCodeDisplayName LIKE '%(Inspection)%'
    LIMIT 5
""").df()
print("\nInspection-classified rows (confirms the static list is applied):")
print(inspection.to_string())

print("\n" + "=" * 80)
print("dim_Technician_Code_Names - real IsActive breakdown (was fake/always-true in production)")
print("=" * 80)
tech_active = con.execute(f"""
    SELECT IsActive, COUNT(*) AS RowCount
    FROM delta_scan('{base}/dim_Technician_Code_Names')
    GROUP BY IsActive
""").df()
print(tech_active.to_string())
tech_sample = con.execute(f"SELECT * FROM delta_scan('{base}/dim_Technician_Code_Names') LIMIT 10").df()
print(tech_sample.to_string())

print("\n" + "=" * 80)
print("DONE")
print("=" * 80)
