"""
DP_PRESENTATION - BATCH B DIMENSIONS VERIFICATION
============================================================================
Confirms the 4 Batch B dimension builds landed correctly: dim_AdjustmentType,
dim_PromoType, dim_UniqueCustomers, dim_Salesperson.
(dim_Branch12_Parts deferred - blocked on Fact_Branch12_Transactions.)

Run manually after Brian adds the Silver_VhSalman and Silver_Contact
shortcuts to DP_Presentation, syncs the workspace, and runs all 4 notebooks.
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
    "dim_AdjustmentType",
    {"AdjustmentTypeKey", "AdjustmentTypeName", "AdjustmentTypeDescription", "SortOrder", "IsActive"},
    expect_row_range="7 (matches production exactly, static table)",
)
check_table(
    "dim_PromoType",
    {"PromoPartNo", "PromoDescription", "PromoCategory", "FirstSeen", "LastSeen", "UsageCount"},
    expect_row_range="~50 per production's own documentation",
)
check_table(
    "dim_UniqueCustomers",
    {"CustomerKey", "CustomerName", "DataSource", "IdentificationMethod", "IdentificationRule", "IsActive", "CreatedDate"},
    expect_row_range="11 (matches production exactly, static table)",
)
check_table(
    "dim_Salesperson",
    {"SalespersonCode", "FirstName", "LastName", "FullName", "DisplayName", "Branch", "IsActive"},
    expect_row_range="up to 645 (one per distinct VhSalman.CODE)",
)

print("=" * 80)
print("dim_AdjustmentType - all rows")
print("=" * 80)
at = con.execute(f"SELECT * FROM delta_scan('{base}/dim_AdjustmentType') ORDER BY SortOrder").df()
print(at.to_string())

print("\n" + "=" * 80)
print("dim_UniqueCustomers - all rows")
print("=" * 80)
uc = con.execute(f"SELECT * FROM delta_scan('{base}/dim_UniqueCustomers') ORDER BY CustomerKey").df()
print(uc.to_string())

print("\n" + "=" * 80)
print("dim_Salesperson - IsActive breakdown + sample")
print("=" * 80)
sp_active = con.execute(f"""
    SELECT IsActive, COUNT(*) AS RowCount
    FROM delta_scan('{base}/dim_Salesperson')
    GROUP BY IsActive
""").df()
print(sp_active.to_string())
sp_sample = con.execute(f"SELECT * FROM delta_scan('{base}/dim_Salesperson') LIMIT 10").df()
print(sp_sample.to_string())

print("\n" + "=" * 80)
print("dim_PromoType - PromoCategory breakdown")
print("=" * 80)
pt = con.execute(f"""
    SELECT PromoCategory, COUNT(*) AS RowCount
    FROM delta_scan('{base}/dim_PromoType')
    GROUP BY PromoCategory
    ORDER BY RowCount DESC
""").df()
print(pt.to_string())

print("\n" + "=" * 80)
print("DONE")
print("=" * 80)
