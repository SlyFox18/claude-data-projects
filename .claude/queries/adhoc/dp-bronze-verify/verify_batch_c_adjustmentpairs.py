"""
DP_PRESENTATION - FACT_ADJUSTMENTPAIRS + FACT_ADJPAIRS_SUMMARY VERIFICATION
(Batch C, 4/5)
============================================================================
Confirms both tables landed correctly after Brian ran
Build_Gold_AdjustmentPairs.Notebook. See
docs/architecture/lh-master-data-facts-catalog.md (Batch C section).
============================================================================
"""

import duckdb

DP_PRESENTATION_WS_ID = "73fd5443-240e-410a-990a-98827f32c087"
DP_PRESENTATION_LH_ID = "966efc8a-16f9-423b-aa43-e368fcd8fb91"
base = f"abfss://{DP_PRESENTATION_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_PRESENTATION_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

PAIRS_COLS = {
    "NegTransId", "PosTransId", "NegRONumber", "PosRONumber", "NegDate", "PosDate",
    "Branch", "PartNumber", "PartDescription", "NegQty", "PosQty", "NegAbsQty", "PosAbsQty",
    "NegCost", "PosCost", "NegAbsCost", "PosAbsCost", "NegPAType", "PosPAType",
    "DaysBetween", "IsWithin12Mo", "IsExact", "MatchType", "PairKey", "LoadedDatetime",
}
SUMMARY_COLS = {
    "NegTransId", "NegRONumber", "NegDate", "Branch", "PartNumber", "PartDescription",
    "NegQty", "NegAbsQty", "NegCost", "NegAbsCost", "NegPAType",
    "PosMatchCount_12Mo", "PosTotalAbsQty_12Mo", "PosTotalAbsCost_12Mo",
    "PosMatchCount_24Mo", "PosTotalAbsQty_24Mo", "PosTotalAbsCost_24Mo",
    "IsExact_12Mo", "IsExact_24Mo", "MatchType_12Mo", "MatchType_24Mo",
    "QtyRecoveryPct_12Mo", "QtyRecoveryPct_24Mo", "LoadedDatetime",
}


def check_contract(name, expected_cols):
    print("=" * 80)
    print(f"VERIFY: {name}")
    print("=" * 80)
    count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/{name}')").fetchone()[0]
    print(f"Row count: {count:,}")
    cols = con.execute(f"DESCRIBE SELECT * FROM delta_scan('{base}/{name}') LIMIT 0").df()
    col_set = set(cols["column_name"].tolist())
    if col_set == expected_cols:
        print(f"PASS: {len(expected_cols)}-column contract matches exactly.")
    else:
        print(f"Missing: {expected_cols - col_set}")
        print(f"Extra: {col_set - expected_cols}")
    print()
    return count


pairs_count = check_contract("Fact_AdjustmentPairs", PAIRS_COLS)
summary_count = check_contract("Fact_AdjPairs_Summary", SUMMARY_COLS)

print("=" * 80)
print("SPOT CHECKS")
print("=" * 80)

print("\n-- DaysBetween sanity: all pairs should be <= 730 days --")
days_check = con.execute(f"""
    SELECT MAX(DaysBetween) AS MaxDays, MIN(DaysBetween) AS MinDays
    FROM delta_scan('{base}/Fact_AdjustmentPairs')
""").df()
print(days_check.to_string())

print("\n-- IsWithin12Mo consistency: should exactly match DaysBetween <= 365 --")
mismatch = con.execute(f"""
    SELECT COUNT(*) FROM delta_scan('{base}/Fact_AdjustmentPairs')
    WHERE IsWithin12Mo != (DaysBetween <= 365)
""").fetchone()[0]
print(f"Mismatches: {mismatch} (expect 0)")

print("\n-- IsExact consistency: should exactly match NegAbsQty = PosAbsQty --")
exact_mismatch = con.execute(f"""
    SELECT COUNT(*) FROM delta_scan('{base}/Fact_AdjustmentPairs')
    WHERE IsExact != (NegAbsQty = PosAbsQty)
""").fetchone()[0]
print(f"Mismatches: {exact_mismatch} (expect 0)")

print("\n-- MatchType_24Mo breakdown (summary table) --")
match_breakdown = con.execute(f"""
    SELECT MatchType_24Mo, COUNT(*) AS n FROM delta_scan('{base}/Fact_AdjPairs_Summary')
    GROUP BY MatchType_24Mo ORDER BY n DESC
""").df()
print(match_breakdown.to_string())

print("\n-- Summary table: unmatched negatives (MatchType_24Mo = 'No Match') have 0s, not nulls --")
null_check = con.execute(f"""
    SELECT COUNT(*) FROM delta_scan('{base}/Fact_AdjPairs_Summary')
    WHERE MatchType_24Mo = 'No Match'
      AND (PosMatchCount_24Mo IS NULL OR PosTotalAbsQty_24Mo IS NULL OR PosTotalAbsCost_24Mo IS NULL)
""").fetchone()[0]
print(f"No-Match rows with a NULL aggregate (expect 0 - should be 0, not null): {null_check}")

print("\n-- Multiple matches per transaction are intentional - sanity check the fan-out exists --")
fanout = con.execute(f"""
    SELECT COUNT(*) FROM (
        SELECT NegTransId, COUNT(*) AS n FROM delta_scan('{base}/Fact_AdjustmentPairs')
        GROUP BY NegTransId HAVING COUNT(*) > 1
    )
""").fetchone()[0]
print(f"NegTransIds with multiple pair matches: {fanout:,} (expect > 0 - this is intentional, not a bug)")

print("\n" + "=" * 80)
print("DONE")
print("=" * 80)
