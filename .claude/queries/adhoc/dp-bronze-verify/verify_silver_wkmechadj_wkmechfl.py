"""
DP WKMECHADJ AND WKMECHFL - SILVER VERIFICATION
============================================================================
Independent check of the 2 Silver tables built in this plan - confirms
each Silver table's row count matches its bronze shortcut exactly (both
are pure select/rename, no filtering).

Run manually after Brian runs both notebooks.
============================================================================
"""

import duckdb

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

# (bronze shortcut name, silver table name)
TABLE_PAIRS = [
    ("WKMECHADJ", "Silver_WkMechAdj"),
    ("WKMECHFL", "Silver_WkMechFl"),
]

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=" * 90)
print(f"{'Bronze':<20} {'Silver':<20} {'Bronze rows':>15} {'Silver rows':>15} {'Match':>8}")
print("=" * 90)

all_match = True
for bronze_name, silver_name in TABLE_PAIRS:
    bronze_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/{bronze_name}')").fetchone()[0]
    silver_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/{silver_name}')").fetchone()[0]
    match = bronze_count == silver_count
    all_match = all_match and match
    print(f"{bronze_name:<20} {silver_name:<20} {bronze_count:>15,} {silver_count:>15,} {'OK' if match else 'MISMATCH':>8}")

print("=" * 90)
print(f"Both Silver tables match their bronze shortcut exactly: {all_match}")
