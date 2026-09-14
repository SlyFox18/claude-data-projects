"""
DP_PRESENTATION - BATCH D VERIFICATION: dim_CustomerList
============================================================================
Confirms the dim_CustomerList build landed correctly - the most complex dim
in the whole catalog: joined from 3 Silver sources, deduplicated, a stable
AccountNumber-derived surrogate key, and 9 hardcoded special customer rows.

Run manually after Brian:
  1. Adds the Silver_ArMaster shortcut to DP_Presentation (new this batch -
     Silver_Contact and Silver_ArMasterCustomer shortcuts already exist).
  2. Re-runs Build_Silver_Contact.Notebook (picks up the new ContactClass
     column from bronze contact.class).
  3. Syncs the workspace and runs Build_Gold_CustomerList.Notebook.
============================================================================
"""

import duckdb

DP_PRESENTATION_WS_ID = "73fd5443-240e-410a-990a-98827f32c087"
DP_PRESENTATION_LH_ID = "966efc8a-16f9-423b-aa43-e368fcd8fb91"
DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
pres_base = f"abfss://{DP_PRESENTATION_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_PRESENTATION_LH_ID}/Tables"
staging_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

EXPECTED_COLS = {
    "CustomerKey", "AccountNumber", "AccountNumberText", "CustomerNumber", "ContactID",
    "DisplayName", "CustomerName", "PrimaryName", "CompanyName", "FirstName", "LastName", "FullName",
    "TradeType", "CustomerTypeDescription", "StatusCode", "AccountStatus", "AccountType", "Territory",
    "CreditLimit", "AccountBalance", "Aging30", "Aging60", "Aging90", "YTDDebits", "CreditTerm",
    "PaymentMethod", "PriceLevel", "City", "State", "Email", "PrimaryPhone", "BusinessPhone", "MobilePhone",
    "IsKeyCustomer", "CreditUtilization", "FinancialRiskLevel", "HasOverdueBalance",
    "CustomerTier", "IsHighValue", "DiscountType", "TaxExemptNumber", "CustomerNotes", "DataQualityScore",
}

print("=" * 80)
print("VERIFY: dim_CustomerList - column contract")
print("=" * 80)
cols = con.execute(f"DESCRIBE SELECT * FROM delta_scan('{pres_base}/dim_CustomerList') LIMIT 0").df()
col_set = set(cols["column_name"].tolist())
if col_set == EXPECTED_COLS:
    print(f"PASS: {len(EXPECTED_COLS)}-column contract matches exactly.")
else:
    print(f"Missing: {EXPECTED_COLS - col_set}")
    print(f"Extra: {col_set - EXPECTED_COLS}")
print()

print("=" * 80)
print("VERIFY: row count + no duplicate CustomerKeys")
print("=" * 80)
count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{pres_base}/dim_CustomerList')").fetchone()[0]
print(f"Total rows: {count:,} (9 special + real customers, real count varies with live source)")
dup = con.execute(f"""
    SELECT CustomerKey, COUNT(*) AS n
    FROM delta_scan('{pres_base}/dim_CustomerList')
    GROUP BY CustomerKey HAVING COUNT(*) > 1
""").df()
print(f"Duplicate CustomerKey rows (expect 0): {len(dup)}")
if len(dup):
    print(dup.to_string())
print()

print("=" * 80)
print("VERIFY: all 9 special customer rows present, correct")
print("=" * 80)
special = con.execute(f"""
    SELECT CustomerKey, AccountNumber, DisplayName, TradeType, CustomerTypeDescription, CustomerTier
    FROM delta_scan('{pres_base}/dim_CustomerList')
    WHERE CustomerKey < 0
    ORDER BY CustomerKey
""").df()
print(special.to_string())
expected_specials = {-1: "UNKNOWN", -2: "INTERNAL", -3: "WARRANTY", -4: "FLEET", -5: "EXCESS",
                     -6: "POLICY", -7: "BILLING", -8: "MISC", -9: "STOCK"}
actual = dict(zip(special["CustomerKey"], special["AccountNumber"]))
if actual == expected_specials:
    print("PASS: all 9 special keys/AccountNumbers match production exactly.")
else:
    print(f"MISMATCH - expected {expected_specials}, got {actual}")
print()

print("=" * 80)
print("VERIFY: IsKeyCustomer count against real bronze contact.class = 'KEY'")
print("=" * 80)
gold_key_count = con.execute(f"""
    SELECT COUNT(*) FROM delta_scan('{pres_base}/dim_CustomerList') WHERE IsKeyCustomer = true
""").fetchone()[0]
print(f"dim_CustomerList IsKeyCustomer=true count: {gold_key_count:,}")
bronze_key_count = con.execute(f"""
    SELECT COUNT(*) FROM delta_scan('{staging_base}/Silver_Contact') WHERE ContactClass = 'KEY'
""").fetchone()[0]
print(f"Silver_Contact ContactClass='KEY' count: {bronze_key_count:,} (expect 312 per the original DuckDB check against bronze contact.class)")
print()

print("=" * 80)
print("VERIFY: CustomerTier breakdown")
print("=" * 80)
tier = con.execute(f"""
    SELECT CustomerTier, COUNT(*) AS RowCount
    FROM delta_scan('{pres_base}/dim_CustomerList')
    GROUP BY CustomerTier ORDER BY RowCount DESC
""").df()
print(tier.to_string())
print()

print("=" * 80)
print("Sample rows")
print("=" * 80)
sample = con.execute(f"""
    SELECT CustomerKey, AccountNumber, DisplayName, CustomerName, CustomerTypeDescription,
           AccountStatus, CreditLimit, AccountBalance, IsKeyCustomer, CustomerTier, DataQualityScore
    FROM delta_scan('{pres_base}/dim_CustomerList')
    WHERE CustomerKey > 0
    ORDER BY CustomerKey LIMIT 15
""").df()
print(sample.to_string())

print("\n" + "=" * 80)
print("DONE")
print("=" * 80)
