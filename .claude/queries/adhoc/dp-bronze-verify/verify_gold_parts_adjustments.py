"""
DP GOLD PARTS ADJUSTMENTS VERIFICATION - THE ACTUAL PROOF
============================================================================
Compares the new Fact_PartsAdjustments (built by
Build_Gold_PartsAdjustments.Notebook) against EquipRDB - the real source
system - for total row count, total cost value, and total absolute cost
value of adjustment activity since 2023-01-01.

This is deliberately NOT comparing against another copy of our own data -
it's comparing against ground truth, the same way the original Parts
Promo bug was first proven.

CORRECTED 2026-09-09, after the first real run of this script found a
674-row "mismatch" that was NOT a data bug: EquipRDB is a live, constantly
-updating source, while the gold table reflects a point-in-time snapshot
(bronze mirror -> silver -> gold, each with its own build lag). Comparing
an open-ended ">= 2023-01-01" against "right now" on the source side will
always show some drift for the most recent transactions - confirmed via
direct investigation that 100% of the original gap was explained by rows
either not yet pulled into Dev's silver build, or not yet captured by JD's
own nightly bronze-mirror pipeline (neither is a defect in this migration's
logic). Fixed by bounding BOTH sides of the comparison to the bronze
mirror's own known-fresh-as-of cutoff, computed dynamically each run -
this makes the check deterministic regardless of when it's run, instead of
chasing an ever-moving "live now".

Business rule under test: Fact_PartsAdjustments should have exactly one
row per InTrans line where Type = 'A' (adjustment) and TransDatetime >=
2023-01-01 (and, for this bounded comparison, < the bronze mirror's own
freshness cutoff) - GlTrans classification doesn't change this count or
these totals (see the notebook's own row-count assertion for why).
============================================================================
"""

import duckdb
import pyodbc

DP_PRESENTATION_WS_ID = "73fd5443-240e-410a-990a-98827f32c087"   # DP - Presentation - Dev workspace
DP_PRESENTATION_LH_ID = "966efc8a-16f9-423b-aa43-e368fcd8fb91"   # DP_Presentation lakehouse
dp_base = f"abfss://{DP_PRESENTATION_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_PRESENTATION_LH_ID}/Tables"

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"   # DP - Staging - Dev workspace
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"   # DP_Staging Dev lakehouse
staging_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

START_DATE = "2023-01-01"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

# ------------------------------------------------------------------
# Determine the bounded comparison window: the bronze InTrans shortcut's
# own freshness cutoff, converted to naive UTC to match EquipRDB's own
# Trans_Datetime storage convention (confirmed via direct investigation:
# EquipRDB stores a naive value that IS the UTC instant - Bronze/Silver
# correctly tag and convert it to Central for display/storage).
# ------------------------------------------------------------------
cutoff_row = con.execute(f"""
    SELECT CAST((MAX(Trans_Datetime) AT TIME ZONE 'UTC') AS VARCHAR) AS CutoffNaiveUTC,
           CAST(MAX(Trans_Datetime) AS VARCHAR) AS CutoffDisplay
    FROM delta_scan('{staging_base}/InTrans')
""").fetchone()
cutoff_naive_utc, cutoff_display = cutoff_row
print(f"Bounding this comparison to the bronze mirror's own freshness cutoff: {cutoff_display}")
print(f"(naive UTC form used for the source query: {cutoff_naive_utc})\n")

# ------------------------------------------------------------------
# Pull the new gold table's totals, bounded to the same cutoff
# ------------------------------------------------------------------
gold = con.execute(f"""
    SELECT COUNT(*) AS RowCount, SUM(CostValue) AS TotalCostValue, SUM(AbsCost) AS TotalAbsCost
    FROM delta_scan('{dp_base}/Fact_PartsAdjustments')
    WHERE TransDatetime < TIMESTAMP '{cutoff_naive_utc}' AT TIME ZONE 'UTC'
""").df()
print("New gold table (Fact_PartsAdjustments), bounded to cutoff:")
print(gold.to_string())

# ------------------------------------------------------------------
# Pull ground truth directly from EquipRDB, bounded to the same cutoff
# ------------------------------------------------------------------
cn = pyodbc.connect('DSN=EquipRDB64', timeout=30)
cur = cn.cursor()
cur.execute(f"""
    SELECT COUNT(*) AS SRC_RowCount, SUM(COST_VAL) AS SRC_TotalCostValue, SUM(ABS(COST_VAL)) AS SRC_TotalAbsCost
    FROM InTrans
    WHERE TYPE = 'A'
      AND Trans_Datetime >= '{START_DATE}'
      AND Trans_Datetime < '{cutoff_naive_utc}'
""")
src_row = cur.fetchone()
src_count, src_total_cost, src_total_abs = src_row
print(f"\nEquipRDB direct (InTrans, Type='A', {START_DATE} <= Trans_Datetime < {cutoff_naive_utc}):")
print(f"  RowCount: {src_count:,}")
print(f"  TotalCostValue: {float(src_total_cost):,.2f}")
print(f"  TotalAbsCost: {float(src_total_abs):,.2f}")

# ------------------------------------------------------------------
# Compare
# ------------------------------------------------------------------
gold_count = int(gold["RowCount"][0])
gold_cost = float(gold["TotalCostValue"][0])
gold_abs = float(gold["TotalAbsCost"][0])

count_match = gold_count == src_count
cost_diff = abs(gold_cost - float(src_total_cost))
abs_diff = abs(gold_abs - float(src_total_abs))

print(f"\nRow count match: {count_match} (gold {gold_count:,} vs. source {src_count:,})")
print(f"TotalCostValue diff: {cost_diff:.4f} (expect < 0.01)")
print(f"TotalAbsCost diff: {abs_diff:.4f} (expect < 0.01)")

if count_match and cost_diff < 0.01 and abs_diff < 0.01:
    print("\nFact_PartsAdjustments matches EquipRDB exactly - migration confirmed correct.")
else:
    print("\nMISMATCH FOUND - do not trust this build until investigated.")
