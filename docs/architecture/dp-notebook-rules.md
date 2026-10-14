# DP Notebook Rules

These rules apply to every Silver and Gold notebook in the DP backend (`DP - Staging - Dev`, `DP - Presentation - Dev`). Each one comes from a real bug. Most were found on 2026-10-05, when the first Prod run was compared with Dev on the same JD data: each notebook should give identical output on identical input, but some didn't.

## 1. Take a source table's key from JD, not from the data

JD keeps Bronze unique on the primary key listed in `JD_EquipRDB_Production_Bronze.watermarktable_full.TablePrimaryKeyColumnNames`. Any dedup or MERGE in Silver must use exactly that key.

> **Example:** Silver_InTrans used `(TransId, TransDatetime)`, but JD's key is `Branch, Franchise, Part_No, Trans_Datetime, Trans_id`. About 150,000 genuinely different transactions (mostly 2010–2014) were merged into one arbitrary survivor. This was the fourth bug of this kind on InTrans.

Read the key with:
```sql
SELECT TableName, TablePrimaryKeyColumnNames
FROM delta_scan('abfss://JD_FabricOneLake@onelake.dfs.fabric.microsoft.com/JD_EquipRDB_Production_Bronze.Lakehouse/Tables/watermarktable_full')
```
In a MERGE, compare key columns with null-safe equality (`<=>`). Otherwise rows with a null key column never match, and they get inserted again on every run.

Document numbers in this source system are reused: TransId, DocRef, RONumber. Never treat one as unique without checking.

## 2. Never keep an arbitrary row

Spark has no fixed row order. Each of these can return a different row on every run:

| Don't use | Use instead |
|-----------|-------------|
| `dropDuplicates([keys])` | `row_number()` over the keys, ordered by a stated rule, keeping row 1. If no rule matters, use `_stable_dedupe`: lowest values of the other columns. |
| `F.first(col)` / `first_value` | `F.min_by(col, F.struct(...))` or `F.max_by(...)` with an explicit order. For example, the earliest transaction: `struct(col.isNull(), TransDatetime, TransId, ...)`. |
| `monotonically_increasing_id()` to mean "first row" | An explicit order, as above. |
| `Window.orderBy(x)` when `x` can tie | Add more columns until the order is unique: `orderBy("Branch", "BranchID")`. |

When the rule is a business choice (which branch's price, sum or keep one), ask Brian and write his decision in a comment next to the code. Examples:
- **dim_Parts:** quantities and values are company-wide sums; other attributes take the most common value.
- **Parts Not Re-Ordered:** quantities of lines that share a key are added.

## 3. Surrogate keys must sort on something unique

A key numbered `1..N` with `row_number()` is only stable if the sort columns are unique. Assert it in the notebook:
```python
assert df.groupBy("BranchID").count().filter("count > 1").count() == 0
```
> **Example:** dim_BranchLocation numbered rows by `Branch` alone, but "1 - Seminole" is four rows (Main Branch and the IS, Set-Up and CP shops). Keys reshuffled from run to run. Any fact table not rebuilt in the same run would then point at the wrong branch.

Prefer `xxhash64(<business key>)` for new keys (as dim_Parts and dim_CustomerList do): it can't shift.

## 4. Floating-point totals vary in the last digits

Spark adds DOUBLE values in whatever order the data arrives, so 6817.63 can come out as 6817.629999999999. That's expected. `compare_tiers.py` rounds DOUBLE values to 6 decimals. Use DECIMAL where exact cents matter.

## 5. Appending to history: match the existing schema

An append-only snapshot must cast new rows to the existing table's column types before writing. Otherwise a type change in the source fails the append with `DELTA_FAILED_TO_MERGE_FIELDS`.
> **Example:** Fact_Parts_Open_Orders_Snapshot: its source `Order_No` became BIGINT, but the history column is INT.

## How to check

After changing a notebook, run it twice on the same input, or run Prod and Dev back to back. Then run:
```
python deploy/compare_tiers.py <table> [...]
```
in fabric-workspace-docs. Identical input must give identical output. The only exceptions are the cases listed under "Checking Prod against Dev" in `fabric-workspace-docs/OPERATIONS-GUIDE.md`.
