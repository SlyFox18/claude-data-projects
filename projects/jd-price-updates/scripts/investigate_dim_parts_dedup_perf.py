"""
Re-verification script for the dim_Parts majority-vote PERFORMANCE restructuring
(2026-08-10).

Background: the original majority-vote fix (see investigate_dim_parts_dedup.py)
was logically correct but implemented as a `ModeOfList` helper function invoked
BY Table.Group's per-PartNumber-group aggregation function - i.e. a fresh
Table.Group nested inside another Table.Group's per-row aggregation callback,
re-run ~1M times (once per distinct PartNumber) x 6 business-filter columns.
That shipped fix hung/would not load in the live Fabric Dataflow Gen2 preview
against the real ~1M-row jdis_Part_Information table - a real production
performance failure, not a hypothetical one.

The restructured dim_Parts.pq now uses a two-level Table.Group pattern instead,
run ONCE per business-filter column (not once per PartNumber group):
  1) first-level Table.Group over the FULL table by {PartNumber, Value} -> a
     small table of (PartNumber, value, VoteCount) triples
  2) Table.Sort that small table by PartNumber asc, VoteCount desc
  3) second-level Table.Group by PartNumber alone, taking List.First of the
     now-sorted value column (cheap - no further sort/group inside the
     aggregation function)

This script translates that exact two-level-GROUP-BY shape into SQL (using
DuckDB's arg_max as the literal equivalent of "sort desc by VoteCount, take
first"), and re-confirms it still resolves the same 5 known examples to
Franchise='D' - proving the RESTRUCTURED logic is still correct, not just
that the old logic was correct.

Run manually - not part of any scheduled pipeline.
"""

import duckdb

WS_ID = "b48cdb35-7ce3-46de-96df-d70db77649cb"   # LH_Master_Data workspace
LH_ID = "3e74497b-8c51-4a1a-91a1-888c59118f48"   # LH_Master_Data lakehouse
base = f"abfss://{WS_ID}@onelake.dfs.fabric.microsoft.com/{LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

BUSINESS_COLS = ["Franchise", "Source", "SLC", "DealerGroupCode", "CommodityCode", "VendorCode"]
examples = ["DZ111141", "19M7966", "Z47990", "R78055", "R71387"]
examples_sql = ",".join(f"'{p}'" for p in examples)

print("=" * 70)
print("Two-level GROUP BY (literal SQL equivalent of the new M architecture)")
print("Level 1: GROUP BY {PartNumber, Value} -> VoteCount  (== 1st Table.Group)")
print("Level 2: GROUP BY PartNumber, arg_max(Value, VoteCount)  (== sort + List.First)")
print("=" * 70)

for col in ["Franchise"]:
    q = f"""
        WITH level1 AS (
            SELECT
                UPPER(TRIM(PartNumber)) AS PartNumber,
                UPPER(TRIM({col})) AS {col},
                COUNT(*) AS VoteCount
            FROM delta_scan('{base}/jdis_Part_Information')
            WHERE PartNumber IS NOT NULL AND TRIM(PartNumber) <> ''
              AND {col} IS NOT NULL AND TRIM(CAST({col} AS VARCHAR)) <> ''
              AND UPPER(TRIM(PartNumber)) IN ({examples_sql})
            GROUP BY UPPER(TRIM(PartNumber)), UPPER(TRIM({col}))
        ),
        level2 AS (
            SELECT
                PartNumber,
                arg_max({col}, VoteCount) AS Majority{col},
                max(VoteCount) AS WinningVoteCount
            FROM level1
            GROUP BY PartNumber
        )
        SELECT * FROM level2 ORDER BY PartNumber
    """
    result = con.execute(q).df()
    print(f"\n--- {col} (5 known examples) ---")
    print(result.to_string(index=False))
    assert (result[f"Majority{col}"] == "D").all(), f"UNEXPECTED: not all 5 examples resolved to D for {col}"
    print(f"PASS: all 5 examples resolve to {col}='D' under the two-level-GROUP-BY (new architecture) logic.")

# ------------------------------------------------------------------
# Cross-check against the window-function version (STEP 1 of the original
# investigate_dim_parts_dedup.py) for ALL 6 business-filter columns, to
# confirm the two independent SQL formulations agree everywhere, not just
# on the 5 headline examples.
# ------------------------------------------------------------------
print()
print("=" * 70)
print("Cross-check: two-level GROUP BY vs ROW_NUMBER window function")
print("(both are valid SQL translations of 'majority vote per PartNumber';")
print(" they should NEVER disagree - if they do, something is wrong)")
print("=" * 70)

for col in BUSINESS_COLS:
    q = f"""
        WITH level1 AS (
            SELECT
                UPPER(TRIM(PartNumber)) AS PartNumber,
                UPPER(TRIM(CAST({col} AS VARCHAR))) AS Val,
                COUNT(*) AS VoteCount
            FROM delta_scan('{base}/jdis_Part_Information')
            WHERE PartNumber IS NOT NULL AND TRIM(PartNumber) <> ''
              AND {col} IS NOT NULL AND TRIM(CAST({col} AS VARCHAR)) <> ''
            GROUP BY UPPER(TRIM(PartNumber)), UPPER(TRIM(CAST({col} AS VARCHAR)))
        ),
        two_level AS (
            SELECT PartNumber, arg_max(Val, VoteCount) AS TwoLevelValue
            FROM level1
            GROUP BY PartNumber
        ),
        windowed AS (
            SELECT PartNumber, Val AS WindowValue
            FROM (
                SELECT PartNumber, Val, VoteCount,
                       ROW_NUMBER() OVER (PARTITION BY PartNumber ORDER BY VoteCount DESC) AS rn
                FROM level1
            )
            WHERE rn = 1
        )
        SELECT COUNT(*) AS DisagreeCount
        FROM two_level t
        JOIN windowed w ON t.PartNumber = w.PartNumber
        WHERE t.TwoLevelValue <> w.WindowValue
    """
    disagree = con.execute(q).fetchone()[0]
    status = "PASS (0 disagreements)" if disagree == 0 else f"FAIL ({disagree:,} disagreements!)"
    print(f"  {col:20s}: {status}")

print()
print("Done.")
