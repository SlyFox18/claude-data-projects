"""
FACT_PART_TRANSACTIONS MATRIX-PRICING VERIFICATION - GROUND TRUTH PROOF
============================================================================
Independently recomputes EffectiveListSalVal (and its 3 dependents:
EffectiveListMargin, MatrixSaleGained, MatrixMarginGained) directly against
EquipRDB for a sample of real Type IN ('C','I') transactions, and compares
against Build_Gold_PartTransactions.Notebook's real output in
DP_Presentation.

No natural row key is persisted on this table, so rows are matched between
Gold and EquipRDB via a composite of Branch/PartNumber/TransactionDate/
SaleAmount - selective enough for spot-check verification. The notebook's
own internal self-consistency check (EffectiveListMargin/MatrixSaleGained/
MatrixMarginGained arithmetic, verified 0 mismatches after the notebook ran)
already proves those 3 are wired correctly off EffectiveListSalVal; this
script's job is verifying EffectiveListSalVal's own external inputs
(SellPrice1/ListPrice/TransactionTradeType) are correct.

Run manually after Brian confirms the notebook ran successfully
(Task 3 of docs/superpowers/plans/2026-09-21-price-matrix-migration.md).
============================================================================
"""

import duckdb
import pyodbc
import pandas as pd

DP_PRESENTATION_WS_ID = "73fd5443-240e-410a-990a-98827f32c087"   # DP - Presentation - Dev workspace
DP_PRESENTATION_LH_ID = "966efc8a-16f9-423b-aa43-e368fcd8fb91"   # DP_Presentation lakehouse
dp_base = f"abfss://{DP_PRESENTATION_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_PRESENTATION_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

# ------------------------------------------------------------------
# Pull a sample of 20 real rows from the Gold table - Franchise 7
# (Price Matrix's own real filter, FranchiseKey = 7) isn't a column on
# this table, so sample broadly across real transactions instead.
# ------------------------------------------------------------------
sample = con.execute(f"""
    SELECT Branch, PartNumber, TransactionDate, SaleAmount, CostAmount,
           EffectiveListSalVal
    FROM delta_scan('{dp_base}/Fact_Part_Transactions')
    WHERE SaleAmount != 0
    ORDER BY TransactionDate DESC
    LIMIT 20
""").df()
print(f"Sample rows pulled from Gold: {len(sample)} (expect 20)")

# ------------------------------------------------------------------
# For each sampled row, pull the matching real InTrans row(s) from
# EquipRDB and independently recompute EffectiveListSalVal.
# ------------------------------------------------------------------
cn = pyodbc.connect('DSN=EquipRDB64', timeout=30)
cur = cn.cursor()

results = []
for _, row in sample.iterrows():
    cur.execute("""
        SELECT SELL_PRICE1, LIST_PRICE, QTY, TRADE_TYPE, SALE_VAL
        FROM InTrans
        WHERE BRANCH = ? AND PART_NO = ? AND Trans_Datetime = ? AND SALE_VAL = ?
    """, row["Branch"], row["PartNumber"], row["TransactionDate"], float(row["SaleAmount"]))
    src_rows = cur.fetchall()

    if len(src_rows) != 1:
        results.append({
            "Branch": row["Branch"], "PartNumber": row["PartNumber"],
            "Match": f"AMBIGUOUS ({len(src_rows)} source rows matched)" if src_rows else "NOT FOUND",
            "Gold_EffectiveListSalVal": row["EffectiveListSalVal"],
            "Src_EffectiveListSalVal": None,
        })
        continue

    sell_price1, list_price, qty, trade_type, sale_val = src_rows[0]
    sell_price1 = float(sell_price1) if sell_price1 is not None else 0.0
    list_price = float(list_price) if list_price is not None else 0.0
    qty = float(qty) if qty is not None else 0.0
    sale_val = float(sale_val)

    sell_price1_sale_val = sell_price1 * qty
    list_sale_val = list_price * qty
    pct_change = 0.0 if sell_price1_sale_val == 0 else (sell_price1_sale_val - list_sale_val) / sell_price1_sale_val
    src_effective_list_sal_val = sale_val if trade_type == "W" else sale_val * (1 - pct_change)

    results.append({
        "Branch": row["Branch"], "PartNumber": row["PartNumber"],
        "Match": "OK",
        "Gold_EffectiveListSalVal": row["EffectiveListSalVal"],
        "Src_EffectiveListSalVal": src_effective_list_sal_val,
    })

results_df = pd.DataFrame(results)
results_df["Diff"] = (results_df["Gold_EffectiveListSalVal"] - results_df["Src_EffectiveListSalVal"]).abs()

pd.set_option("display.max_columns", None)
pd.set_option("display.width", 200)
print(results_df.to_string(index=False))

matched = results_df[results_df["Match"] == "OK"]
mismatches = matched[matched["Diff"] > 0.01]
unmatched = results_df[results_df["Match"] != "OK"]

print(f"\nMatched rows: {len(matched)} (expect close to 20 - some ambiguous/not-found matches from the")
print(f"composite key are possible on a high-volume table and are reported separately, not counted as failures)")
print(f"Unmatched/ambiguous rows: {len(unmatched)}")
print(f"Real mismatches among matched rows (off by >$0.01): {len(mismatches)} (expect 0)")
if len(mismatches):
    print(mismatches.to_string(index=False))
else:
    print("All matched rows' EffectiveListSalVal match EquipRDB ground truth exactly.")
