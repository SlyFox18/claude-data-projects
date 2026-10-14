"""
DIM_REPAIRORDER FULL REBUILD VERIFICATION - GROUND TRUTH PROOF
============================================================================
Independently recomputes all 15 dim_RepairOrder columns directly against
EquipRDB (the real source system) - not against another copy of our own
data - for the 11 repair orders confirmed wrong in the original
investigation plus 5 arbitrary real promo orders, and compares against
Build_Gold_PartsPromo.Notebook's real output in DP_Presentation.

Extends the pre-trim verify_gold_parts_promo.py pattern (2026-09-08) to
the full restored 15-column design
(docs/superpowers/specs/2026-09-21-dim-repairorder-rebuild-design.md).

Run manually after Brian confirms the notebook ran successfully in Fabric
(Task 4 of docs/superpowers/plans/2026-09-21-dim-repairorder-rebuild.md).
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

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

# ------------------------------------------------------------------
# Pull 5 arbitrary real promo orders too, not just the known-bad 11 -
# guards against a fix that only happens to work for the already-known
# tricky cases.
# ------------------------------------------------------------------
known_bad_placeholders = ",".join(f"'{r}'" for r in KNOWN_BAD_ROS)
sample_ros = con.execute(f"""
    SELECT DISTINCT REF_NO
    FROM delta_scan('{dp_base}/dim_RepairOrder')
    WHERE REF_NO NOT IN ({known_bad_placeholders})
    ORDER BY REF_NO
    LIMIT 5
""").df()["REF_NO"].tolist()

ALL_ROS = KNOWN_BAD_ROS + sample_ros
placeholders = ",".join(f"'{r}'" for r in ALL_ROS)

# ------------------------------------------------------------------
# Pull the new gold table's values
# ------------------------------------------------------------------
gold = con.execute(f"""
    SELECT REF_NO, BranchKey, CustomerNo, OrderDate, LastActivityDate,
           TotalPartsSales, TotalPartsCost, PartsCount,
           TotalPromoDiscount, PromoCount,
           NetOrderValue, OriginalMargin, NetMargin,
           DiscountAmount, DiscountPercent
    FROM delta_scan('{dp_base}/dim_RepairOrder')
    WHERE REF_NO IN ({placeholders})
""").df()

# ------------------------------------------------------------------
# Pull ground truth directly from EquipRDB, same business rules as the
# spec: non-promo excludes Franchise='ZP', promo does not. Real source
# column names confirmed against .claude/queries/raw-tables/
# Raw_InTrans_Incremental.pq: BRANCH, customer_no, REF_NO, PART_NO,
# FRANCHISE, Trans_Datetime, SALE_VAL, COST_VAL.
#
# "(FRANCHISE IS NULL OR FRANCHISE != 'ZP')" rather than a plain
# "FRANCHISE != 'ZP'" - SQL's != also evaluates to unknown/false against
# NULL, same three-valued-logic trap found and fixed in the notebook's
# own PySpark filter (Franchise handling uses eqNullSafe there). Must
# match the notebook's null-safe behavior or this ground-truth check
# would silently validate against the wrong rule.
#
# pyodbc returns Decimal for SQL Anywhere DECIMAL/NUMERIC columns - cast
# to float here so later comparisons against the gold table's float64
# columns don't raise TypeError.
# ------------------------------------------------------------------
cn = pyodbc.connect('DSN=EquipRDB64', timeout=30)
cur = cn.cursor()

cur.execute(f"""
    SELECT REF_NO,
           MIN(BRANCH) AS SRC_BranchKey,
           MIN(customer_no) AS SRC_CustomerNo,
           MIN(Trans_Datetime) AS SRC_OrderDate,
           MAX(Trans_Datetime) AS SRC_LastActivityDate
    FROM InTrans
    WHERE Trans_Datetime >= '2022-01-01'
      AND REF_NO IN ({placeholders})
    GROUP BY REF_NO
""")
order_rows = cur.fetchall()
order_attrs = pd.DataFrame.from_records(
    [tuple(r) for r in order_rows],
    columns=["REF_NO", "SRC_BranchKey", "SRC_CustomerNo", "SRC_OrderDate", "SRC_LastActivityDate"],
)
order_attrs["SRC_BranchKey"] = order_attrs["SRC_BranchKey"].astype(float)

cur.execute(f"""
    SELECT REF_NO, SUM(SALE_VAL) AS SRC_TotalPartsSales, SUM(COST_VAL) AS SRC_TotalPartsCost, COUNT(*) AS SRC_PartsCount
    FROM InTrans
    WHERE PART_NO NOT LIKE '*%'
      AND (FRANCHISE IS NULL OR FRANCHISE != 'ZP')
      AND Trans_Datetime >= '2022-01-01'
      AND REF_NO IN ({placeholders})
    GROUP BY REF_NO
""")
non_promo_rows = cur.fetchall()
non_promo = pd.DataFrame.from_records(
    [tuple(r) for r in non_promo_rows],
    columns=["REF_NO", "SRC_TotalPartsSales", "SRC_TotalPartsCost", "SRC_PartsCount"],
)
non_promo["SRC_TotalPartsSales"] = non_promo["SRC_TotalPartsSales"].astype(float)
non_promo["SRC_TotalPartsCost"] = non_promo["SRC_TotalPartsCost"].astype(float)
non_promo["SRC_PartsCount"] = non_promo["SRC_PartsCount"].astype(float)

cur.execute(f"""
    SELECT REF_NO, SUM(SALE_VAL) AS SRC_TotalPromoDiscount, COUNT(*) AS SRC_PromoCount
    FROM InTrans
    WHERE PART_NO LIKE '*%'
      AND Trans_Datetime >= '2022-01-01'
      AND REF_NO IN ({placeholders})
    GROUP BY REF_NO
""")
promo_rows = cur.fetchall()
promo = pd.DataFrame.from_records(
    [tuple(r) for r in promo_rows],
    columns=["REF_NO", "SRC_TotalPromoDiscount", "SRC_PromoCount"],
)
promo["SRC_TotalPromoDiscount"] = promo["SRC_TotalPromoDiscount"].astype(float)
promo["SRC_PromoCount"] = promo["SRC_PromoCount"].astype(float)

# ------------------------------------------------------------------
# Assemble source-side dim_RepairOrder from scratch, independently of
# the notebook's own PySpark logic - same derivation rules, computed
# fresh in pandas.
# ------------------------------------------------------------------
source = order_attrs.merge(non_promo, on="REF_NO", how="left").merge(promo, on="REF_NO", how="left")
for col in ["SRC_TotalPartsSales", "SRC_TotalPartsCost", "SRC_PartsCount", "SRC_TotalPromoDiscount", "SRC_PromoCount"]:
    source[col] = source[col].fillna(0)

source["SRC_NetOrderValue"] = source["SRC_TotalPartsSales"] + source["SRC_TotalPromoDiscount"]
source["SRC_OriginalMargin"] = source["SRC_TotalPartsSales"] - source["SRC_TotalPartsCost"]
source["SRC_NetMargin"] = source["SRC_NetOrderValue"] - source["SRC_TotalPartsCost"]
source["SRC_DiscountAmount"] = source["SRC_TotalPromoDiscount"].abs()
source["SRC_DiscountPercent"] = source.apply(
    lambda r: 0.0 if r["SRC_TotalPartsSales"] == 0 else r["SRC_DiscountAmount"] / r["SRC_TotalPartsSales"],
    axis=1,
)

# ------------------------------------------------------------------
# Compare
# ------------------------------------------------------------------
source["REF_NO"] = source["REF_NO"].astype(str)
gold["REF_NO"] = gold["REF_NO"].astype(str)
merged = source.merge(gold, on="REF_NO", how="outer", indicator=True)

pd.set_option("display.max_columns", None)
pd.set_option("display.width", 250)
print(f"Orders checked: {len(merged)} (expect {len(ALL_ROS)})")
print(merged.to_string(index=False))

NUMERIC_PAIRS = [
    ("SRC_TotalPartsSales", "TotalPartsSales"),
    ("SRC_TotalPartsCost", "TotalPartsCost"),
    ("SRC_PartsCount", "PartsCount"),
    ("SRC_TotalPromoDiscount", "TotalPromoDiscount"),
    ("SRC_PromoCount", "PromoCount"),
    ("SRC_NetOrderValue", "NetOrderValue"),
    ("SRC_OriginalMargin", "OriginalMargin"),
    ("SRC_NetMargin", "NetMargin"),
    ("SRC_DiscountAmount", "DiscountAmount"),
    ("SRC_DiscountPercent", "DiscountPercent"),
]

mismatch_mask = merged["_merge"] != "both"
for src_col, gold_col in NUMERIC_PAIRS:
    diff = (merged[src_col] - merged[gold_col]).abs()
    mismatch_mask = mismatch_mask | (diff > 0.01)

mismatches = merged[mismatch_mask]
print(f"\nOrders with a real mismatch on any of the 10 aggregate/calculated columns")
print(f"(off by >$0.01, or missing from one side): {len(mismatches)} (expect 0)")
if len(mismatches):
    print(mismatches.to_string(index=False))
else:
    print("All checked orders match EquipRDB ground truth exactly across all 10 aggregate/calculated columns.")
    print("BranchKey/CustomerNo/OrderDate/LastActivityDate are in the printed table above for manual eyeball")
    print("confirmation (identifiers/dates, not tolerance-compared numerics).")
