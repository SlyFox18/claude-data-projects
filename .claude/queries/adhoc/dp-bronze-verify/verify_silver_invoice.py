"""
DP INVOICE - SILVER VERIFICATION
============================================================================
Independent check of Silver_Invoice - confirms the row count matches the
bronze shortcut exactly (this table's IS NOT NULL/empty filter had zero
real-world impact when checked this session, so an exact match is the
expected outcome, not just a close one - if a real difference shows up
here, it means either a genuinely bad row now exists in the source or
something is wrong with the notebook, and it's worth checking which
before assuming it's fine).

Run manually after Brian runs the notebook.
============================================================================
"""

import duckdb

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

bronze_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/Invoice')").fetchone()[0]
silver_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/Silver_Invoice')").fetchone()[0]

print(f"Bronze Invoice rows:  {bronze_count:,}")
print(f"Silver Invoice rows:  {silver_count:,}")
print(f"Difference:           {bronze_count - silver_count:,} (expect close to 0 - the IS NOT NULL/empty filter had zero real-world impact when checked this session)")

print("\n=== Independent re-confirmation of the grain finding ===")
distinct_invoice_number = con.execute(f"SELECT COUNT(DISTINCT InvoiceNumber) FROM delta_scan('{dp_base}/Silver_Invoice')").fetchone()[0]
distinct_real_grain = con.execute(f"""
    SELECT COUNT(*) FROM (
        SELECT DISTINCT InvoiceNumber, Branch, ModuleType, InvoiceType
        FROM delta_scan('{dp_base}/Silver_Invoice')
    )
""").fetchone()[0]

print(f"Distinct InvoiceNumber alone:                      {distinct_invoice_number:,}")
print(f"Distinct (InvoiceNumber, Branch, ModuleType, InvoiceType): {distinct_real_grain:,}")
print(f"Silver row count:                                  {silver_count:,}")
print(f"Real grain matches row count exactly: {distinct_real_grain == silver_count}")
print(f"InvoiceNumber alone is NOT a safe key (expect distinct_invoice_number < silver_count): {distinct_invoice_number < silver_count}")
