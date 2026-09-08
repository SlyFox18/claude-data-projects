"""
DP GOLD PARTS PROMO VERIFICATION - THE ACTUAL PROOF
============================================================================
Compares the new dim_RepairOrder (built by Build_Gold_PartsPromo.Notebook,
Plan 4) against EquipRDB - the real source system - for all 11 repair
orders confirmed wrong in the original investigation
(docs/superpowers/specs/2026-09-04-jd-bronze-data-platform-redesign-design.md).

This is deliberately NOT comparing against another copy of our own data -
it's comparing against ground truth, the same way the original bug was
first proven.

Business rule under test: TotalPartsSales/TotalPartsCost = SUM(SaleValue/
CostValue) for non-promo (PART_NO NOT LIKE '*%') lines EXCLUDING
Franchise = 'ZP', per RONumber, since 2022-01-01. Matches dim_RepairOrder.pq
and this plan's notebook exactly.

Run manually after Task 3 confirms the notebook ran successfully.
============================================================================
"""

import duckdb
import pyodbc
import pandas as pd

DP_PRESENTATION_WS_ID = "73fd5443-240e-410a-990a-98827f32c087"   # DP - Presentation - Dev workspace
DP_PRESENTATION_LH_ID = "966efc8a-16f9-423b-aa43-e368fcd8fb91"   # DP_Presentation lakehouse
dp_base = f"abfss://{DP_PRESENTATION_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_PRESENTATION_LH_ID}/Tables"

KNOWN_BAD_ROS = [
    "1986984", "1981941", "1984493", "1987016", "1986996",
    "1985073", "1979395", "1985078", "1985139", "1987116", "1987002",
]

# ------------------------------------------------------------------
# Pull the new gold table's values
# ------------------------------------------------------------------
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

placeholders = ",".join(f"'{r}'" for r in KNOWN_BAD_ROS)
gold = con.execute(f"""
    SELECT REF_NO, TotalPartsSales, TotalPartsCost, PartsCount
    FROM delta_scan('{dp_base}/dim_RepairOrder')
    WHERE REF_NO IN ({placeholders})
""").df()

# ------------------------------------------------------------------
# Pull ground truth directly from EquipRDB - same business rule
# ------------------------------------------------------------------
cn = pyodbc.connect('DSN=EquipRDB64', timeout=30)
cur = cn.cursor()
cur.execute(f"""
    SELECT REF_NO, SUM(SALE_VAL) AS SRC_TotalPartsSales, SUM(COST_VAL) AS SRC_TotalPartsCost, COUNT(*) AS SRC_PartsCount
    FROM InTrans
    WHERE PART_NO NOT LIKE '*%'
      AND FRANCHISE != 'ZP'
      AND Trans_Datetime >= '2022-01-01'
      AND REF_NO IN ({placeholders})
    GROUP BY REF_NO
""")
src_rows = cur.fetchall()
source = pd.DataFrame.from_records(
    [tuple(r) for r in src_rows],
    columns=["REF_NO", "SRC_TotalPartsSales", "SRC_TotalPartsCost", "SRC_PartsCount"],
)
source["REF_NO"] = source["REF_NO"].astype(str)
source["SRC_TotalPartsSales"] = source["SRC_TotalPartsSales"].astype(float)
source["SRC_TotalPartsCost"] = source["SRC_TotalPartsCost"].astype(float)

# ------------------------------------------------------------------
# Compare
# ------------------------------------------------------------------
gold["REF_NO"] = gold["REF_NO"].astype(str)
merged = source.merge(gold, on="REF_NO", how="outer", indicator=True)
merged["SalesDiff"] = (merged["SRC_TotalPartsSales"] - merged["TotalPartsSales"]).abs()
merged["CostDiff"] = (merged["SRC_TotalPartsCost"] - merged["TotalPartsCost"]).abs()

pd.set_option("display.max_columns", None)
pd.set_option("display.width", 200)
print(f"Orders checked: {len(merged)} (expect 11)")
print(merged.to_string(index=False))

mismatches = merged[(merged["SalesDiff"] > 0.01) | (merged["CostDiff"] > 0.01) | (merged["_merge"] != "both")]
print(f"\nOrders with a real mismatch (sales/cost off by >$0.01, or missing from one side): {len(mismatches)} (expect 0)")
if len(mismatches):
    print(mismatches.to_string(index=False))
else:
    print("All 11 previously-wrong orders now match the real source exactly.")
