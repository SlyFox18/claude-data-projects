# FIX: Page 2 - Inventory Cost Discrepancy - Use Correct Base Table

## Issue Identified

The new report shows drastically different values compared to the old report:
- Old: $1.43M positive, ($10.48K) negative, 70+ LOW parts
- New: $62.72K positive, ($29.96K) negative, 11 LOW parts

**Root Cause**: Table is using `Fact_InTrans` as the base, which only includes parts with sales transactions in the last 2 years.

**Correct Approach**: Table should use `dim_Parts_LowMargin` as the base to show ALL parts in inventory.

---

## Why This Matters

### Page 1: Parts Sales with Low Margins
- **Purpose**: Analyze SALES performance
- **Base table**: `Fact_InTrans` ✅ CORRECT
- **Filter**: Last 2 years of transactions
- **Scope**: Parts that sold

### Page 2: Inventory Cost Discrepancy
- **Purpose**: Analyze INVENTORY valuation
- **Base table**: `dim_Parts_LowMargin` ✅ CORRECT
- **Filter**: Parts with SOH > 0
- **Scope**: ALL parts currently in stock

---

## Current Table Configuration (WRONG)

```
Table Visual:
  Rows from: Fact_InTrans (via dim_Parts_LowMargin relationship)
  Filters: Branch = 1, Franchise <> 'S', Measure Filter 2 = 1

Problem: Only shows parts that:
  1. Had sales in last 2 years (Fact_InTrans filter)
  2. Are currently in stock (Total SOH Qty > 0)
  3. Match the margin % filter

Result: Missing most inventory parts!
```

---

## Correct Table Configuration (FIX)

```
Table Visual:
  Rows from: dim_Parts_LowMargin (directly)
  Columns:
    - dim_Parts_LowMargin[Branch]
    - dim_Parts_LowMargin[Franchise]
    - dim_Parts_LowMargin[PartNumber]
    - [Part Description] (measure)
    - [Total SOH Qty]
    - [Inventory Cost]
    - [MDP Value]
    - [Sell Value]
    - [Desired Margin %]
    - [Actual Margin % (INV)]
    - [Desired Margin $]
    - [Actual Margin $ (INV)]
    - [Margin $ Discrepancy (Row)]
    - dim_Parts_LowMargin[LowMarginFlag]
    - [Sell Price]

  Filters:
    1. dim_Parts_LowMargin[Branch] = "1"
    2. dim_Parts_LowMargin[Franchise] <> "S"
    3. [Total SOH Qty] > 0  (only parts in stock)
    4. [Measure Filter 2] = 1  (margin % range filter)
```

---

## How to Fix in Power BI

### Step 1: Verify Current Visual Configuration

1. Select the table visual
2. Check the **Visualizations** pane → **Columns** section
3. Look at what fields are in **Rows**
4. If you see `Fact_InTrans[PartNumber]` or relationship paths → WRONG

### Step 2: Rebuild Table with Correct Base

1. **Delete the current table visual** (or create a new one)
2. **Add Rows** (in this exact order):
   - `dim_Parts_LowMargin[Branch]`
   - `dim_Parts_LowMargin[Franchise]`
   - `dim_Parts_LowMargin[PartNumber]`
3. **Add Values** (measures):
   - `[Part Description]`
   - `[Total SOH Qty]`
   - `[Inventory Cost]`
   - `[MDP Value]`
   - `[Sell Value]`
   - `[Desired Margin %]`
   - `[Actual Margin % (INV)]`
   - `[Desired Margin $]`
   - `[Actual Margin $ (INV)]`
   - `[Margin $ Discrepancy (Row)]`
   - `dim_Parts_LowMargin[LowMarginFlag]`
   - `[Sell Price]`

### Step 3: Apply Filters

**Visual Level Filters** (on the table visual itself):

1. **dim_Parts_LowMargin[Branch]** = "1"
2. **dim_Parts_LowMargin[Franchise]** is not "S"
3. **Total SOH Qty** > 0
4. **Measure Filter 2** = 1

**Page Level Filters** (apply to entire page):
- Percentage Filter slicer: -50% to 100%

### Step 4: Verify Row Count

After fixing, you should see **70+ rows** with `LowMarginFlag = "LOW"` for Branch 1, matching the old report.

---

## Why Measures Still Work

Even though you're changing the base table from `Fact_InTrans` to `dim_Parts_LowMargin`, all your measures still work because:

1. **Inventory measures** reference `dim_Parts_LowMargin` directly:
   ```dax
   [Total SOH Qty] = SUM(dim_Parts_LowMargin[OnHandQty])
   [Inventory Cost] = SUM(dim_Parts_LowMargin[InventoryCost])
   [MDP Value] = SUM(dim_Parts_LowMargin[StockOrderPrice]) * [Total SOH Qty]
   ```

2. **These don't require Fact_InTrans** - they're pure inventory calculations

3. **Context comes from dim_Parts_LowMargin rows** in the table

---

## Expected Results After Fix

**Totals should match old report:**
- Positive Margin $ Discrepancy ≈ $1.43M
- Negative Margin $ Discrepancy ≈ ($10.48K)
- Net Margin $ Discrepancy ≈ $1.42M
- LOW flagged parts ≈ 70+ rows

**Row count:**
- Branch 1, Franchise <> 'S', SOH > 0, Margin % -50% to 100%
- Should be similar to old report (looks like ~70-80 parts)

---

## Additional Validation

### Check 1: Compare Specific Part Numbers

From new report screenshot, I can see these parts:
- AH226238: Inventory Cost $619.52, MDP $505.68
- KK61931: Inventory Cost $0.00, MDP $0.00
- LP93647: Inventory Cost $76.76, MDP $76.76

Verify these same parts appear in old report with same values.

### Check 2: Total SOH Qty Sum

Sum up `[Total SOH Qty]` for all rows in both reports. Should match if using same data source and filters.

### Check 3: LOW Flag Count

```dax
Count of LOW Parts =
CALCULATE(
    COUNTROWS(dim_Parts_LowMargin),
    dim_Parts_LowMargin[LowMarginFlag] = "LOW",
    dim_Parts_LowMargin[Branch] = "1",
    dim_Parts_LowMargin[Franchise] <> "S",
    [Total SOH Qty] > 0
)
```

Should be 70+ if correct.

---

## Why Page 1 and Page 2 Differ

| Aspect | Page 1: Sales Analysis | Page 2: Inventory Analysis |
|--------|----------------------|---------------------------|
| **Base Table** | Fact_InTrans | dim_Parts_LowMargin |
| **Time Scope** | Last 2 years transactions | Current inventory snapshot |
| **Part Scope** | Parts that sold | Parts in stock |
| **Metrics** | Sale $, Cost $, Actual Margin $ | Inventory Cost, MDP Value, Discrepancy |
| **Purpose** | Historical performance | Current valuation issues |

Both pages use `dim_Parts_LowMargin` for **lookup data** (StockOrderPrice, LowMarginFlag, etc.), but they have different **base contexts**.

---

## Summary

**Problem**: Using transaction-based context (Fact_InTrans) for inventory analysis page.

**Solution**: Use inventory-based context (dim_Parts_LowMargin) for this page.

**Action**: Rebuild table visual with `dim_Parts_LowMargin` fields in Rows section, not relationships through `Fact_InTrans`.

This should fix the massive difference in totals and row counts.
