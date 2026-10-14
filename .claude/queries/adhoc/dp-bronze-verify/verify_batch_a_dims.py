"""
DP_PRESENTATION - BATCH A DIMENSIONS VERIFICATION
============================================================================
Confirms the 7 Batch A dimension builds landed correctly:
dim_CommodityCode, dim_DealerGroupCode, dim_SLC, dim_Source, dim_VendorCode,
dim_PaymentMethod, lookup_UniqueCustomers_Invoice.

Run manually after Brian adds the 3 new shortcuts (Silver_PartInformation,
Silver_Invoice, Silver_ArMasterCustomer) to DP_Presentation, syncs the
workspace, and runs all 7 notebooks.
============================================================================
"""

import duckdb

DP_PRESENTATION_WS_ID = "73fd5443-240e-410a-990a-98827f32c087"
DP_PRESENTATION_LH_ID = "966efc8a-16f9-423b-aa43-e368fcd8fb91"
base = f"abfss://{DP_PRESENTATION_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_PRESENTATION_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")


def check_table(name, expected_cols, unknown_key_col=None, unknown_key_val=None, expect_row_range=None):
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

    if unknown_key_col:
        unk = con.execute(f"""
            SELECT * FROM delta_scan('{base}/{name}')
            WHERE {unknown_key_col} = {unknown_key_val!r}
        """).df()
        print(f"\nUnknown-row check ({unknown_key_col}={unknown_key_val}, expect exactly 1 row):")
        print(unk.to_string())
    print()


check_table(
    "dim_CommodityCode",
    {"CommodityCodeKey", "CommodityCode"},
    unknown_key_col="CommodityCodeKey", unknown_key_val=0,
    expect_row_range="~781 (780 real codes + Unknown)",
)
check_table(
    "dim_DealerGroupCode",
    {"DealerGroupKey", "DealerGroupCode"},
    unknown_key_col="DealerGroupKey", unknown_key_val=0,
    expect_row_range="1,867 (1,866 real codes + Unknown) - verified real via DuckDB directly against Silver_PartInformation, genuinely messy/high-cardinality data (mix of real dealer names and numeric-looking codes), not a bug",
)
check_table(
    "dim_SLC",
    {"SLCKey", "SLC"},
    unknown_key_col="SLCKey", unknown_key_val=0,
    expect_row_range="123 (matches the Feb 2026 dimension-analysis.md documentation exactly)",
)
check_table(
    "dim_Source",
    {"SourceKey", "Source"},
    unknown_key_col="SourceKey", unknown_key_val=0,
    expect_row_range="~273 (close to the Feb 2026 doc's 267 - small real growth expected, live source)",
)
check_table(
    "dim_VendorCode",
    {"VendorCodeKey", "VendorCode"},
    expect_row_range="1,332 - verified real via DuckDB directly against Silver_PartInformation. Real bug found+fixed 2026-09-11: VendorCode is an INTEGER column in Silver_PartInformation, not text - the original string-empty filter silently zeroed out every row",
)
check_table(
    "dim_PaymentMethod",
    {"PaymentMethodKey", "PaymentMethod", "PaymentMethodDescription", "PaymentCategory", "SortOrder"},
    expect_row_range="12, not the documented 5 - verified real via DuckDB directly against Silver_Invoice.PaymentMethod. 7 extra rows are genuine (if messy) production data - rare garbage-looking values (e.g. '1005', 'ASHBURNBC4529', 1-14 rows each) that the old dataflow's own filter (<> null and <> \"\") would also pick up; its '5, unlikely to grow' documentation was simply never checked against real data",
)
check_table(
    "lookup_UniqueCustomers_Invoice",
    {"CustomerNumber", "UniqueCustomerGroup"},
    expect_row_range="719, not the documented ~513 - verified real: each group's individual count is proportionally higher than the old documentation (e.g. Manuel/MR Tractor 300->472), consistent with organic invoice growth since that number was last checked, not an implementation bug. Raw per-group counts summed exactly match the final 719",
)

print("=" * 80)
print("EDGE CASE: CustomerNumber 25227 (expect 'Manuel/MR Tractor', not 'Oscar')")
print("=" * 80)
edge = con.execute(f"""
    SELECT * FROM delta_scan('{base}/lookup_UniqueCustomers_Invoice')
    WHERE CustomerNumber = '25227'
""").df()
print(edge.to_string())

print("\n" + "=" * 80)
print("PAYMENT METHOD CATEGORY BREAKDOWN (expect no 'Other' category)")
print("=" * 80)
pm = con.execute(f"SELECT * FROM delta_scan('{base}/dim_PaymentMethod') ORDER BY SortOrder").df()
print(pm.to_string())

print("\n" + "=" * 80)
print("DONE")
print("=" * 80)
