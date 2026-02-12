# KPI Measures Using Cost Field (Not StockOrderPrice)

## Critical Issue

The current measures use **StockOrderPrice** but the old report uses **Cost** field from jdis_Part_Information.

This is causing the 3x difference:
- New Report (using StockOrderPrice): $2.09M / ($322K) / $1.77M
- Old Report (using Cost): $5.31M / ($138K) / $5.17M

## The Fix: Use Cost Instead of StockOrderPrice

### 1. Positive Margin $ Discrepancy (with Cost field)

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

**Format**: `$#,0.00;($#,0.00);$#,0.00`

**Key Change**: Replaced `[StockOrderPrice]` with `[Cost]` in two places:
- Line 6: `"_CostValue", [Cost] * [OnHandQty]`
- Line 7: `"_DesiredMarginDollars", ([SellPrice1] * [OnHandQty]) - ([Cost] * [OnHandQty])`
- Line 10: `(([SellPrice1] * [OnHandQty]) - ([Cost] * [OnHandQty]))`

### 2. Negative Margin $ Discrepancy (with Cost field)

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

**Format**: `$#,0.00;($#,0.00);$#,0.00`

**Key Change**: Same as Positive - replaced `[StockOrderPrice]` with `[Cost]`

### 3. Net Margin $ Discrepancy (no change)

```dax
Net Margin $ Discrepancy = [Positive Margin $ Discrepancy] + [Negative Margin $ Discrepancy]
```

**Format**: `$#,0.00;($#,0.00);$#,0.00`

---

## Additional Measures to Update

### Cost (base measure)

```dax
Cost = SUM(dim_Parts_LowMargin[Cost])
```

**Format**: `$#,0.00;($#,0.00);$#,0.00`

### Cost Value (replaces MDP Value)

```dax
Cost Value = [Cost] * [Total SOH Qty]
```

**Format**: `$#,0.00;($#,0.00);$#,0.00`

### Desired Margin $ (updated)

```dax
Desired Margin $ = [Sell Value] - [Cost Value]
```

**Format**: `$#,0.00;($#,0.00);$#,0.00`

### Desired Margin % (updated)

```dax
Desired Margin % = DIVIDE([Desired Margin $], [Sell Value], 0)
```

**Format**: `0.00%;-0.00%;0.00%`

---

## Before You Can Apply This

**CRITICAL**: The Cost field must exist in dim_Parts_LowMargin!

### Check if Cost field exists:
1. Go to Data view in Power BI
2. Select dim_Parts_LowMargin table
3. Look for "Cost" column

### If Cost field is MISSING:

You need to update your Lakehouse dimension with [dim_Parts_LowMargin_FILTERED_FINAL.pq](queries/dimensions/dim_Parts_LowMargin_FILTERED_FINAL.pq) which includes:
- Cost field from jdis_Part_Information
- Filtering logic to match row counts
- All other fixes we've implemented

Then refresh the dimension in Fabric and reload in Power BI.

### If Cost field EXISTS:

Apply the three measures above immediately and check if KPI cards now match the old report (~$5.31M).

---

## Expected Results After This Fix

**With Cost field instead of StockOrderPrice:**
- Positive: Should be ~$5.31M (not $2.09M)
- Negative: Should be ~($138K) (not $322K)
- Net: Should be ~$5.17M (not $1.77M)

This should get you within 2-3% of the old report values (accounting for the 4,125 missing rows).

---

## Why This Makes Such a Big Difference

**Example Calculation:**

**Using StockOrderPrice (Current - Wrong):**
- Sell Value: $1,000
- Inventory Cost: $600
- MDP Value (StockOrderPrice * Qty): $500
- Desired Margin $: $1,000 - $500 = $500
- Actual Margin $: $1,000 - $600 = $400
- Margin Discrepancy: $400 - $500 = **-$100** (negative)

**Using Cost (Correct):**
- Sell Value: $1,000
- Inventory Cost: $600
- Cost Value (Cost * Qty): $700
- Desired Margin $: $1,000 - $700 = $300
- Actual Margin $: $1,000 - $600 = $400
- Margin Discrepancy: $400 - $300 = **+$100** (positive!)

The **sign can flip** depending on whether Cost is higher or lower than StockOrderPrice! And the magnitude changes significantly.

If Cost is generally higher than StockOrderPrice (which is common - Cost represents purchase cost, StockOrderPrice might be a different pricing basis), you'd see:
- More positive discrepancies (actual margin exceeds desired)
- Higher total values

This explains why your old report shows $5.31M positive vs $2.09M in the new report.

---

## Implementation Checklist

- [ ] Verify Cost column exists in dim_Parts_LowMargin
  - If NO: Apply dim_Parts_LowMargin_FILTERED_FINAL.pq to Lakehouse first
  - If YES: Proceed to next step
- [ ] Update Positive Margin $ Discrepancy measure (use Cost)
- [ ] Update Negative Margin $ Discrepancy measure (use Cost)
- [ ] Create or update Cost base measure
- [ ] Create or update Cost Value measure
- [ ] Update Desired Margin $ measure (use Cost Value)
- [ ] Update Desired Margin % measure
- [ ] Test: KPI cards should show ~$5.31M positive
- [ ] Compare to old report - should be within 2-3%

After completing all steps, your new report should match the old report!
