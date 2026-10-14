"""
DP RAW SOURCES BATCH 1 - SILVER VERIFICATION
============================================================================
Independent check of the 9 Silver tables built in this batch - confirms
each Silver table's row count matches its bronze shortcut exactly (no loss
or duplication from the rename/select step), for every table.

Run manually after Brian runs all 9 notebooks (plan Task 12).
============================================================================
"""

import duckdb

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

# (bronze shortcut name, silver table name)
TABLE_PAIRS = [
    ("ArMaster", "Silver_ArMaster"),
    ("ArMaster_Customer", "Silver_ArMasterCustomer"),
    ("contact", "Silver_Contact"),
    ("GLMASTER", "Silver_GlMaster"),
    ("InSalOrd", "Silver_InSalOrd"),
    ("InSalPar", "Silver_InSalPar"),
    ("VhStockAccess", "Silver_VhStockAccess"),
    ("WarSubCl_Labour", "Silver_WarSubClLabour"),
    ("Branch_Name", "Silver_BranchName"),
]

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=" * 90)
print(f"{'Bronze':<20} {'Silver':<22} {'Bronze rows':>15} {'Silver rows':>15} {'Match':>8}")
print("=" * 90)

all_match = True
for bronze_name, silver_name in TABLE_PAIRS:
    bronze_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/{bronze_name}')").fetchone()[0]
    silver_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/{silver_name}')").fetchone()[0]
    match = bronze_count == silver_count
    all_match = all_match and match
    print(f"{bronze_name:<20} {silver_name:<22} {bronze_count:>15,} {silver_count:>15,} {'OK' if match else 'MISMATCH':>8}")

print("=" * 90)
print(f"All 9 Silver tables match their bronze shortcut exactly: {all_match}")
