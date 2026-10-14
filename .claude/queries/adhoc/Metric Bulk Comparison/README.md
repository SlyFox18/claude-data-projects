# Metric Bulk Comparison (ad hoc, Ben — 2026-09-30)

Fills Ben's metric hardware list (`Metric Bulk Comparison.xlsx`: 159 rows, 158 distinct parts) with inventory, pricing, and demand metrics.

**Output:** `Metric Bulk Comparison - Filled YYYY-MM-DD.xlsx`
- **METRIC COMPARISON** — Ben's original sheet, one row per listed part, aggregated across branches
- **BY BRANCH** — one row per Branch × Part (only branches that have a jdis record for the part)

**Run:** `python build_report.py` (requires `az login`; DuckDB over OneLake, ~1 min)

| Column | Source / logic |
|---|---|
| BRANCH COUNT (summary tab only) | Number of branches with a jdis record for the part (added per Ben's review) |
| BIN QTY, ON ORDER QTY | jdis `BinQty`, `OnOrder` (summed across branches) |
| COST | jdis `Cost`; rollup = on-hand-weighted average |
| LIST, SELL PRICE 1, PACKAGE QUANTITY | jdis; rollup = most common value (flagged in DATA NOTE if branches differ) |
| ON HAND VALUE/IN STOCK COST | jdis `InventoryCost` (summed) |
| R12/R24 DEMANDS | InTrans lines, Type `I`, Qty > 0, rolling 12/24 months |
| R12/R24 SALES, SALES $ | `SUM(Qty)` / `SUM(SaleValue)` over the same lines (gross, returns not netted) |

Franchise `D` only. Full definitions and caveats are in the `build_report.py` header.

**First run (2026-09-30):** 2,152 branch rows. `19M8720` and `19M8194` are not in jdis or InTrans. List/Sell Price 1 vary by branch for `19M8002` and `19M8020`. R12/R24 may be slightly low because of the known Aug-2026 InTrans_Incremental gap.
