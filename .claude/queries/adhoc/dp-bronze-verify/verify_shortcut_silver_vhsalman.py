"""
DP VHSALMAN - BRONZE SHORTCUT + SILVER VERIFICATION
============================================================================
New raw source, discovered 2026-09-11 while investigating dim_Salesperson.
VhSalman is the real base table behind the Salesperson/SalespersonInformation
views (both resolved via real SQL Anywhere view definitions pulled by
Brian). Confirms the VhSalman shortcut resolves to the same row count as
JD Bronze directly, and Silver_VhSalman matches the shortcut exactly
(pure passthrough, no filter).

Run manually after Brian creates the shortcut and runs Build_Silver_VhSalman.
============================================================================
"""

import duckdb

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

JD_BRONZE_WS_ID = "4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9"
JD_BRONZE_LH_ID = "7348c3a6-8694-4d11-bc70-1bd55be84ea2"
jd_base = f"abfss://{JD_BRONZE_WS_ID}@onelake.dfs.fabric.microsoft.com/{JD_BRONZE_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=" * 80)
print("VERIFY SHORTCUT: VhSalman")
print("=" * 80)
jd_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{jd_base}/VhSalman')").fetchone()[0]
dp_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/VhSalman')").fetchone()[0]
print(f"JD Bronze VhSalman: {jd_count:,}")
print(f"DP_Staging VhSalman (shortcut): {dp_count:,}")
print(f"Match: {jd_count == dp_count}")

print("\n" + "=" * 80)
print("VERIFY SILVER: Silver_VhSalman")
print("=" * 80)
silver_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/Silver_VhSalman')").fetchone()[0]
print(f"Silver_VhSalman rows: {silver_count:,}")
print(f"Match to bronze: {silver_count == dp_count}")

print("\n" + "=" * 80)
print("DONE")
print("=" * 80)
