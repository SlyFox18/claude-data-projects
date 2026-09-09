"""
DP BRONZE PARTINFORMATION TIERS VERIFICATION
============================================================================
Confirms the Active/Dead split of jdis_Part_Information landed correctly:
both bronze tables are mutually exclusive, their combined row count matches
a fresh live count against EquipRDB directly (not assumed from an earlier
session), and the split is roughly in line with what was measured this
session (Active ~27%, Dead ~73%) - source data changes continuously, so an
exact match isn't expected, only a similar shape.

CORRECTED 2026-09-09, after the first real run: the true grain of
jdis_Part_Information is (Branch, PartNumber, Franchise), NOT (Branch,
PartNumber) alone - confirmed by pulling every column for a real
"duplicate" Branch+PartNumber pair and finding Franchise ('D' vs 'UD')
was the actual differentiator, along with fully independent inventory/
cost/sales data per franchise. The same part number can be carried under
multiple franchise codes at the same branch, each an independent record.
The original (Branch, PartNumber)-only check found 2,215 false-positive
"overlaps" that were really just distinct rows differing only by
Franchise - not a bug in the dataflow split logic (Check 3's exact 0-row
match against a live EquipRDB count already confirmed the split itself
wasn't dropping or duplicating rows).

Run manually after Task 1 and Task 2 confirm both dataflows ran successfully.
============================================================================
"""

import duckdb
import pyodbc

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=== Check 1: bronze tier row counts ===")
active_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/PartInformation_Active')").fetchone()[0]
dead_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/PartInformation_Dead')").fetchone()[0]
combined = active_count + dead_count
print(f"Active: {active_count:,} ({active_count/combined*100:.1f}%)")
print(f"Dead: {dead_count:,} ({dead_count/combined*100:.1f}%)")
print(f"Combined: {combined:,}")
print("Expect roughly Active ~27%, Dead ~73% (measured this session: 298,349 / 813,379 of 1,111,728 total)")

print("\n=== Check 2: mutual exclusivity - no (Branch, PartNumber, Franchise) appears in both tiers ===")
overlap = con.execute(f"""
    SELECT COUNT(*) FROM (
        SELECT Branch, PartNumber, Franchise FROM delta_scan('{dp_base}/PartInformation_Active')
        INTERSECT
        SELECT Branch, PartNumber, Franchise FROM delta_scan('{dp_base}/PartInformation_Dead')
    )
""").fetchone()[0]
print(f"Rows appearing in both tiers: {overlap}")
print("Expect a very small number (not necessarily exactly 0) - the two dataflows are separate")
print("point-in-time pulls against a live, continuously-changing source, run minutes apart, not")
print("an atomic snapshot. A handful of rows can legitimately flip Active<->Dead status in that")
print("window (real stock/sales activity between the two pulls). A large count would mean a real")
print("logic problem; a handful (same order of magnitude as Check 3's own live-count drift) does not.")

print("\n=== Check 2b: is (Branch, PartNumber, Franchise) actually unique within each tier? ===")
dupes_active = con.execute(f"""
    SELECT COUNT(*) FROM (
        SELECT Branch, PartNumber, Franchise, COUNT(*) AS cnt
        FROM delta_scan('{dp_base}/PartInformation_Active')
        GROUP BY Branch, PartNumber, Franchise
        HAVING COUNT(*) > 1
    )
""").fetchone()[0]
dupes_dead = con.execute(f"""
    SELECT COUNT(*) FROM (
        SELECT Branch, PartNumber, Franchise, COUNT(*) AS cnt
        FROM delta_scan('{dp_base}/PartInformation_Dead')
        GROUP BY Branch, PartNumber, Franchise
        HAVING COUNT(*) > 1
    )
""").fetchone()[0]
print(f"Duplicate (Branch, PartNumber, Franchise) groups within Active (expect 0): {dupes_active}")
print(f"Duplicate (Branch, PartNumber, Franchise) groups within Dead (expect 0): {dupes_dead}")

print("\n=== Check 3: combined bronze total vs. a fresh live EquipRDB count ===")
cn = pyodbc.connect('DSN=EquipRDB64', timeout=30)
cur = cn.cursor()
cur.execute("SELECT COUNT(*) FROM jdis_Part_Information")
live_total = cur.fetchone()[0]
print(f"Live EquipRDB total right now: {live_total:,}")
print(f"Bronze combined total: {combined:,}")
diff = abs(live_total - combined)
diff_pct = diff / live_total * 100
print(f"Difference: {diff:,} rows ({diff_pct:.2f}%) - expect small (source data changes continuously "
      f"between the dataflow runs and this check; a large gap would suggest a real problem, not drift)")
