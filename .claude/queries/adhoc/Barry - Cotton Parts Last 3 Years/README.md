# Cotton Parts Last 3 Years (ad hoc, Barry — 2026-10-22)

Fills Barry's cotton part lists (`Cotton Parts Last 3 Years.xlsx`) with description, location counts and units sold in three **non-overlapping** 12-month buckets. The earlier version of this sheet used cumulative windows (Last 24 included months 1-12).

**Output:** one workbook, `Cotton Parts Last 3 Years - Filled YYYY-MM-DD.xlsx`:
- one tab per tab in Barry's workbook, same name and row order: **All Cotton Parts** (master list, 8,246 parts) and **0 Demands Removed** (his trimmed list, 3,441 parts). Any new tab with a `Part` column is picked up automatically;
- **Notes**: bucket dates and definitions.

**Run:** `timeout 600 python build_report.py` (requires `az login`; DuckDB over OneLake, DP_Presentation Prod)

| Column | Source / logic |
|---|---|
| Description | `dim_Parts.Description` (most common across branches) |
| # Locations | Branches with a Franchise D `Silver_PartInformation` record |
| # Locations On Hand | Of those, branches with `QuantityOnHand > 0` |
| Mo 1-12 / 13-24 / 25-36 Sales | `Silver_InTrans` Type `I`, Franchise D, `SUM(Qty)` net of returns, rolling 12-month buckets back from run time |
| 36 Mo Total | Sum of the three buckets |

**Run 2026-10-22:**
- All Cotton Parts: 64 not found (mostly `AKK…` / `A-…`); totals 373,052 / 314,760 / 327,862.
- 0 Demands Removed: 5 not found; totals 357,563 / 294,712 / 306,390. 55 parts still show 0 net sales over 36 months: the 5 not found, 15 sold and returned (nets to 0), 35 with no Type `I` lines in the window (only receipts, adjustments or transfers).
