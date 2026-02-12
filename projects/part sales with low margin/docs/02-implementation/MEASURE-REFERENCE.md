# DAX Measures Reference

Complete reference for all DAX measures in the Part Sales with Low Margin report.

## Table of Contents

- [Transaction Measures (Page 1)](#transaction-measures-page-1)
- [Inventory Measures (Page 2)](#inventory-measures-page-2)
- [KPI Measures (Page 2)](#kpi-measures-page-2)
- [Utility Measures](#utility-measures)

---

## Transaction Measures (Page 1)

These measures analyze sales transactions from Fact_InTrans.

### Actual Margin $
```dax
Actual Margin $ = SUM(Fact_InTrans[ActualMarginDollars])
```
**Format:** `$#,0.00;($#,0.00);$#,0.00`

**Description:** Total actual profit from sales transactions.

---

### Actual Margin %
```dax
Actual Margin % = DIVIDE([Actual Margin $], [Total Sales Value], 0)
```
**Format:** `0.00%;-0.00%;0.00%`

**Description:** Actual profit as a percentage of sales value.

---

### Original Margin $
```dax
Original Margin $ = SUM(Fact_InTrans[OriginalMarginDollars])
```
**Format:** `$#,0.00;($#,0.00);$#,0.00`

**Description:** Expected profit based on stock order price.

---

### Original Margin %
```dax
Original Margin % = DIVIDE([Original Margin $], [Total Sales Value], 0)
```
**Format:** `0.00%;-0.00%;0.00%`

**Description:** Expected profit percentage.

---

### Margin Discrepancy $
```dax
Margin Discrepancy $ = [Actual Margin $] - [Original Margin $]
```
**Format:** `$#,0.00;($#,0.00);$#,0.00`

**Description:** Difference between actual and expected profit.

---

### Total Sales Value
```dax
Total Sales Value = SUM(Fact_InTrans[SaleValue])
```
**Format:** `$#,0.00;($#,0.00);$#,0.00`

**Description:** Total revenue from sales transactions.

---

### Total Transactions
```dax
Total Transactions = COUNTROWS(Fact_InTrans)
```
**Format:** `#,##0`

**Description:** Number of sales transactions.

---

## Inventory Measures (Page 2)

These measures analyze current inventory from dim_Parts_LowMargin.

### Total SOH Qty
```dax
Total SOH Qty = SUM(dim_Parts_LowMargin[OnHandQty])
```
**Format:** `#,##0`

**Description:** Total stock on hand quantity (QuantityOnHand + BulkBinQty).

---

### Inventory Cost
```dax
Inventory Cost = SUM(dim_Parts_LowMargin[InventoryCost])
```
**Format:** `$#,0.00;($#,0.00);$#,0.00`

**Description:** Total inventory cost value.

---

### Sell Price
```dax
Sell Price = SUM(dim_Parts_LowMargin[SellPrice1])
```
**Format:** `$#,0.00;($#,0.00);$#,0.00`

**Description:** Current selling price per unit.

---

### Sell Value
```dax
Sell Value = [Sell Price] * [Total SOH Qty]
```
**Format:** `$#,0.00;($#,0.00);$#,0.00`

**Description:** Total value if all inventory sold at current price.

---

### Cost
```dax
Cost = SUM(dim_Parts_LowMargin[Cost])
```
**Format:** `$#,0.00;($#,0.00);$#,0.00`

**Description:** Cost per unit from jdis_Part_Information.

---

### Cost Value
```dax
Cost Value = [Cost] * [Total SOH Qty]
```
**Format:** `$#,0.00;($#,0.00);$#,0.00`

**Description:** Total cost value of inventory.

---

### Desired Margin $
```dax
Desired Margin $ = [Sell Value] - [Cost Value]
```
**Format:** `$#,0.00;($#,0.00);$#,0.00`

**Description:** Target profit based on Cost field.

---

### Desired Margin %
```dax
Desired Margin % = DIVIDE([Desired Margin $], [Sell Value], 0)
```
**Format:** `0.00%;-0.00%;0.00%`

**Description:** Target profit percentage.

---

### Actual Margin $ (INV)
```dax
Actual Margin $ (INV) = [Sell Value] - [Inventory Cost]
```
**Format:** `$#,0.00;($#,0.00);$#,0.00`

**Description:** Actual profit potential of current inventory.

---

### Actual Margin % (INV)
```dax
Actual Margin % (INV) = DIVIDE([Actual Margin $ (INV)], [Sell Value], 0)
```
**Format:** `0.00%;-0.00%;0.00%`

**Description:** Actual profit percentage.

---

### List Price
```dax
List Price = SUM(dim_Parts_LowMargin[ListPrice])
```
**Format:** `$#,0.00;($#,0.00);$#,0.00`

**Description:** Manufacturer's list price.

---

### New Sell Price
```dax
New Sell Price =
    DIVIDE(
        ABS([Margin $ Discrepancy]),
        [Total SOH Qty],
        0
    ) + [List Price]
```
**Format:** `$#,0.00;($#,0.00);$#,0.00`

**Description:** Recommended new selling price to achieve target margin.

---

## KPI Measures (Page 2)

**CRITICAL:** These measures use direct column calculations to avoid DAX row context bugs.

### Margin $ Discrepancy (Base Measure)
```dax
Margin $ Discrepancy = [Actual Margin $ (INV)] - [Desired Margin $]
```
**Format:** `$#,0.00;($#,0.00);$#,0.00`

**Description:** Gap between actual and desired margin for inventory.

---

### Positive Margin $ Discrepancy
```dax
Positive Margin $ Discrepancy =
VAR DetailTable =
    ADDCOLUMNS(
        dim_Parts_LowMargin,
        "_SellValue", [SellPrice1] * [OnHandQty],
        "_CostValue", [Cost] * [OnHandQty],
        "_DesiredMarginDollars", ([SellPrice1] * [OnHandQty]) - ([Cost] * [OnHandQty]),
        "_ActualMarginDollars", ([SellPrice1] * [OnHandQty]) - [InventoryCost],
        "_MarginDiscrepancy",
            (([SellPrice1] * [OnHandQty]) - [InventoryCost]) -
            (([SellPrice1] * [OnHandQty]) - ([Cost] * [OnHandQty]))
    )
RETURN
SUMX(
    FILTER(DetailTable, [_MarginDiscrepancy] > 0),
    [_MarginDiscrepancy]
)
```
**Format:** `$#,0.00;($#,0.00);$#,0.00`

**Description:** Total margin discrepancies where actual exceeds desired (good).

**Technical Note:** Uses direct column references to avoid SUM() aggregation issues in row context.

---

### Negative Margin $ Discrepancy
```dax
Negative Margin $ Discrepancy =
VAR DetailTable =
    ADDCOLUMNS(
        dim_Parts_LowMargin,
        "_SellValue", [SellPrice1] * [OnHandQty],
        "_CostValue", [Cost] * [OnHandQty],
        "_DesiredMarginDollars", ([SellPrice1] * [OnHandQty]) - ([Cost] * [OnHandQty]),
        "_ActualMarginDollars", ([SellPrice1] * [OnHandQty]) - [InventoryCost],
        "_MarginDiscrepancy",
            (([SellPrice1] * [OnHandQty]) - [InventoryCost]) -
            (([SellPrice1] * [OnHandQty]) - ([Cost] * [OnHandQty]))
    )
RETURN
SUMX(
    FILTER(DetailTable, [_MarginDiscrepancy] < 0),
    [_MarginDiscrepancy]
)
```
**Format:** `$#,0.00;($#,0.00);$#,0.00`

**Description:** Total margin discrepancies where actual falls short of desired (bad).

**Technical Note:** Uses direct column references to avoid SUM() aggregation issues in row context.

---

### Net Margin $ Discrepancy
```dax
Net Margin $ Discrepancy = [Positive Margin $ Discrepancy] + [Negative Margin $ Discrepancy]
```
**Format:** `$#,0.00;($#,0.00);$#,0.00`

**Description:** Overall margin gap (sum of positive and negative).

---

## Utility Measures

### Part Description
```dax
Part Description =
    VAR CurrentPartNumber = SELECTEDVALUE(dim_Parts_LowMargin[PartNumber])
    VAR FromDimParts =
        LOOKUPVALUE(
            dim_Parts[Description],
            dim_Parts[PartNumber], CurrentPartNumber
        )
    RETURN
    IF(FromDimParts <> BLANK(), FromDimParts, "")
```
**Format:** None (text)

**Description:** Looks up part description from dim_Parts. Uses LOOKUPVALUE because dim_Parts_LowMargin has no relationship to dim_Parts.

---

### % Difference
```dax
% Difference =
    DIVIDE(
        ([MDP Value] - [Inventory Cost]),
        ([MDP Value] + [Inventory Cost]) / 2,
        0
    )
```
**Format:** `0.0%;-0.0%;0.0%`

**Description:** Percentage difference between MDP Value and Inventory Cost.

---

## Important Technical Notes

### Row Context vs. Filter Context

**Problem:** When you reference a measure containing `SUM()` inside `ADDCOLUMNS`, it aggregates the entire column instead of evaluating row-by-row.

**Example of the Bug:**
```dax
// WRONG - SUM([SellPrice1]) sums entire column in row context
ADDCOLUMNS(
    dim_Parts_LowMargin,
    "Calc", [Sell Price] * [Total SOH Qty]  // [Sell Price] = SUM(dim_Parts_LowMargin[SellPrice1])
)
```

**Correct Approach:**
```dax
// CORRECT - Direct column reference evaluates row-by-row
ADDCOLUMNS(
    dim_Parts_LowMargin,
    "Calc", [SellPrice1] * [OnHandQty]  // Direct columns, no SUM()
)
```

This is why the KPI measures use direct column calculations instead of referencing other measures.

---

### Why Positive/Negative Measures Are Complex

The old report had a simpler version that referenced `[Margin $ Discrepancy]`:

```dax
// OLD (Broken):
Positive Margin $ Discrepancy =
SUMX(
    FILTER(
        ADDCOLUMNS(
            dim_Parts_LowMargin,
            "MarginDiscrepancy", [Margin $ Discrepancy]  // ← Bug here!
        ),
        [MarginDiscrepancy] > 0
    ),
    [MarginDiscrepancy]
)
```

This caused the measure to evaluate incorrectly, showing $5.31M when it should show $2.09M.

The fix is to calculate everything directly on columns:
- `[SellPrice1]` instead of `[Sell Price]`
- `[OnHandQty]` instead of `[Total SOH Qty]`
- `[InventoryCost]` instead of `[Inventory Cost]`
- `[Cost]` instead of `[Cost]` measure

---

## Formatting Reference

| Format String | Example Output | Use For |
|---------------|----------------|---------|
| `$#,0.00;($#,0.00);$#,0.00` | $1,234.56 or ($1,234.56) | Currency |
| `#,##0` | 1,234 | Whole numbers (quantities) |
| `0.00%;-0.00%;0.00%` | 12.34% or -12.34% | Percentages |
| `0.0%;-0.0%;0.0%` | 12.3% or -12.3% | Percentages (1 decimal) |

---

## Adding New Measures

When adding new measures to this report:

1. **Create in the `_Measures` table** - Keep all measures in one place
2. **Use clear naming** - Follow existing naming conventions
3. **Add format strings** - Apply appropriate formatting
4. **Document here** - Add to this reference guide
5. **Test with filters** - Ensure they respect Branch/Franchise filters
6. **Avoid row context bugs** - Use direct columns in ADDCOLUMNS if needed

---

**See Also:**
- [Setup Guide](SETUP-GUIDE.md) for implementation instructions
- [KPI Measures Fix](../03-fixes-applied/KPI-Measures-Fix.md) for row context issue details
- [Quick Start](../01-getting-started/QUICK-START.md) for measure explanations
