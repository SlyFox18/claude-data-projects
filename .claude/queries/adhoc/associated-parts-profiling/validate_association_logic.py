"""
Associated Parts — aggregation logic validation (2026-08-27)
Part 1: a synthetic 4-invoice basket set with hand-computed expected output,
to catch logic bugs before trusting the real-data run in Part 2.
Part 2: runs the same SQL against real InTrans_Incremental (capped/thresholded
per Task 2's BASKET_CAP), to finalize MIN_COOCCURRENCE and preview row count.
"""
import duckdb

ASSOCIATION_SQL = """
    WITH baskets AS (
        SELECT Franchise, Branch, RONumber, PartNumber
        FROM {source}
        GROUP BY Franchise, Branch, RONumber, PartNumber
    ),
    basket_sizes AS (
        SELECT Franchise, Branch, RONumber, COUNT(*) AS DistinctParts
        FROM baskets GROUP BY Franchise, Branch, RONumber
    ),
    capped_baskets AS (
        SELECT b.*
        FROM baskets b
        INNER JOIN basket_sizes s
          ON b.Franchise = s.Franchise AND b.Branch = s.Branch AND b.RONumber = s.RONumber
        WHERE s.DistinctParts <= {basket_cap}
    ),
    pairs AS (
        SELECT a.Franchise, a.PartNumber AS PartA, b.PartNumber AS PartB
        FROM capped_baskets a
        INNER JOIN capped_baskets b
          ON a.Franchise = b.Franchise AND a.Branch = b.Branch AND a.RONumber = b.RONumber
         AND a.PartNumber <> b.PartNumber
    ),
    co_occurrence AS (
        SELECT Franchise, PartA, PartB, COUNT(*) AS CoOccurrenceCount
        FROM pairs GROUP BY Franchise, PartA, PartB
    ),
    part_totals AS (
        SELECT Franchise, PartNumber, COUNT(*) AS InvoiceCount
        FROM capped_baskets GROUP BY Franchise, PartNumber
    ),
    total_invoices AS (
        SELECT Franchise, COUNT(*) AS TotalInvoiceCount
        FROM basket_sizes GROUP BY Franchise
    )
    SELECT
        c.Franchise, c.PartA, c.PartB, c.CoOccurrenceCount,
        ta.InvoiceCount AS AnchorInvoiceCount,
        tb.InvoiceCount AS AssociatedInvoiceCount,
        ti.TotalInvoiceCount
    FROM co_occurrence c
    INNER JOIN part_totals ta ON ta.Franchise = c.Franchise AND ta.PartNumber = c.PartA
    INNER JOIN part_totals tb ON tb.Franchise = c.Franchise AND tb.PartNumber = c.PartB
    INNER JOIN total_invoices ti ON ti.Franchise = c.Franchise
    WHERE c.CoOccurrenceCount >= {min_cooccurrence}
    ORDER BY c.Franchise, c.PartA, c.PartB
"""

con = duckdb.connect()

# Out-of-core safety net: the real-data run in Part 2 originally hit
# _duckdb.OutOfMemoryException (max_temp_directory_size exceeded) on this
# host (31.6 GB total RAM). Diagnosis showed the actual filtered data is
# small (~1.29M raw rows, 447,661 baskets, ~4.8M estimated pairs -- see
# Part 2 comments below for the real fix), but this cap gives DuckDB an
# explicit, generous temp-spill budget as a safety margin regardless.
con.execute("PRAGMA memory_limit='10GB';")
con.execute("SET max_temp_directory_size='150GiB';")

# ---- Part 1: synthetic worked example -----------------------------------
# 4 invoices, franchise D, branch 1:
#   INV1: A, B      INV2: A, B      INV3: A, C      INV4: A
# Expected (min_cooccurrence=1, basket_cap=10):
#   A->B: CoOccurrence=2, AnchorInvoiceCount(A)=4, AssociatedInvoiceCount(B)=2 => Confidence=50%
#   B->A: CoOccurrence=2, AnchorInvoiceCount(B)=2, AssociatedInvoiceCount(A)=4 => Confidence=100%
#   A->C: CoOccurrence=1, AnchorInvoiceCount(A)=4, AssociatedInvoiceCount(C)=1 => Confidence=25%
#   C->A: CoOccurrence=1, AnchorInvoiceCount(C)=1, AssociatedInvoiceCount(A)=4 => Confidence=100%
con.execute("""
    CREATE OR REPLACE TABLE test_baskets AS
    SELECT * FROM (VALUES
        ('D','1','INV1','A'), ('D','1','INV1','B'),
        ('D','1','INV2','A'), ('D','1','INV2','B'),
        ('D','1','INV3','A'), ('D','1','INV3','C'),
        ('D','1','INV4','A')
    ) AS t(Franchise, Branch, RONumber, PartNumber)
""")

test_result = con.execute(
    ASSOCIATION_SQL.format(source="test_baskets", basket_cap=10, min_cooccurrence=1)
).df()
print("=== Synthetic test result ===")
print(test_result.to_string(index=False))

expected_pairs = {
    ("D", "A", "B"): (2, 4, 2, 4),
    ("D", "B", "A"): (2, 2, 4, 4),
    ("D", "A", "C"): (1, 4, 1, 4),
    ("D", "C", "A"): (1, 1, 4, 4),
}
actual = {
    (r.Franchise, r.PartA, r.PartB): (r.CoOccurrenceCount, r.AnchorInvoiceCount, r.AssociatedInvoiceCount, r.TotalInvoiceCount)
    for r in test_result.itertuples()
}
assert actual == expected_pairs, f"MISMATCH!\nExpected: {expected_pairs}\nActual: {actual}"
print("Synthetic test PASSED — aggregation logic is correct.\n")

# ---- Part 2: real data, capped, preview row counts at a few thresholds --
WS_ID = "b48cdb35-7ce3-46de-96df-d70db77649cb"
LH_ID = "3e74497b-8c51-4a1a-91a1-888c59118f48"
base = f"abfss://{WS_ID}@onelake.dfs.fabric.microsoft.com/{LH_ID}/Tables"
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

BASKET_CAP = 25  # Task 2's determined value (P99=24, rounded up to nearest 5)

# Materialize the filtered InTrans extract into a local DuckDB table first,
# instead of feeding {source} the raw abfss/delta_scan subquery directly.
# The ASSOCIATION_SQL template's WITH-CTEs (baskets/basket_sizes/capped_baskets)
# reference {source} more than once, and capped_baskets itself is joined to
# itself in the "pairs" self-join -- against a live remote delta_scan
# subquery, DuckDB's planner re-inlines and re-evaluates that remote scan on
# every reference instead of computing it once, which blew the temp-spill
# disk budget (OutOfMemoryException / max_temp_directory_size exceeded) even
# though the real filtered data is small (diagnostic run: 1,290,947 raw rows,
# 447,661 baskets, ~4.8M estimated pairs -- all comfortably small). This is
# a query-planning/execution fix only; ASSOCIATION_SQL itself (already
# validated against the synthetic test above) is unchanged.
con.execute(f"""
    CREATE OR REPLACE TABLE filtered_intrans AS
    SELECT Franchise, Branch, RONumber, PartNumber
    FROM delta_scan('{base}/InTrans_Incremental')
    WHERE Type = 'I' AND Qty > 0
      AND TransDatetime >= CURRENT_DATE - INTERVAL 24 MONTH
      AND PartNumber IS NOT NULL AND PartNumber <> ''
""")
n_filtered = con.execute("SELECT COUNT(*) FROM filtered_intrans").fetchone()[0]
print(f"Materialized filtered_intrans locally: {n_filtered:,} rows")

for min_cooc in (3, 5, 10):
    real_result = con.execute(
        ASSOCIATION_SQL.format(source="filtered_intrans", basket_cap=BASKET_CAP, min_cooccurrence=min_cooc)
    ).df()
    print(f"MIN_COOCCURRENCE={min_cooc}: {len(real_result):,} rows in Fact_PartAssociation")

print("\nPick MIN_COOCCURRENCE for a row count that's usefully small (tens of\n"
      "thousands, not millions) while still covering real parts. Spot-check a\n"
      "few PartA values you recognize against the live report/business knowledge\n"
      "before finalizing.")
