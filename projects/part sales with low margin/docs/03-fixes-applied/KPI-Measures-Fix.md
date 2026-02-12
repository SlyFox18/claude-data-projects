# Fix KPI Measures: Use Direct Column References in Row Context

## The Problem Discovered

Testing revealed that measure references inside ADDCOLUMNS don't evaluate correctly in row context:

**Test Results:**
- `Test Positive with ADDCOLUMNS (using measures)` = $2,050,377.03 ❌
- `Test Positive Direct Calc (using columns)` = $2,090,356.22 ✅
- **Difference**: $39,979.19

**Root Cause:**
When you use `[Measure]` inside ADDCOLUMNS on dim_Parts_LowMargin, measures containing `SUM()` aggregate the entire column instead of evaluating row-by-row.

For example:
```dax
[Sell Price] = SUM(dim_Parts_LowMargin[SellPrice1])
```

Inside ADDCOLUMNS row context, this sums ALL rows, not the current row!

## Old Report vs New Report Row Counts

- Old Report: 155,014 rows
- New Report: 150,889 rows
- Difference: 4,125 rows (2.7%)

The old report shows higher KPI values partially because:
1. It has more rows (4,125 more)
2. Its measures evaluate correctly in the table context it uses

## The Complete Fix

Replace all three KPI measures with direct column calculations:

### 1. Positive Margin $ Discrepancy

**Replace current measure with:**

```dax
Positive Margin $ Discrepancy =
VAR DetailTable =
    ADDCOLUMNS(
        dim_Parts_LowMargin,
        "_SellValue", [SellPrice1] * [OnHandQty],
        "_MDPValue", [StockOrderPrice] * [OnHandQty],
        "_DesiredMarginDollars", ([SellPrice1] * [OnHandQty]) - ([StockOrderPrice] * [OnHandQty]),
        "_ActualMarginDollars", ([SellPrice1] * [OnHandQty]) - [InventoryCost],
        "_MarginDiscrepancy",
            (([SellPrice1] * [OnHandQty]) - [InventoryCost]) -
            (([SellPrice1] * [OnHandQty]) - ([StockOrderPrice] * [OnHandQty]))
    )
RETURN
SUMX(
    FILTER(DetailTable, [_MarginDiscrepancy] > 0),
    [_MarginDiscrepancy]
)
```

**Format**: `$#,0.00;($#,0.00);$#,0.00`

### 2. Negative Margin $ Discrepancy

**Replace current measure with:**

```dax
Negative Margin $ Discrepancy =
VAR DetailTable =
    ADDCOLUMNS(
        dim_Parts_LowMargin,
        "_SellValue", [SellPrice1] * [OnHandQty],
        "_MDPValue", [StockOrderPrice] * [OnHandQty],
        "_DesiredMarginDollars", ([SellPrice1] * [OnHandQty]) - ([StockOrderPrice] * [OnHandQty]),
        "_ActualMarginDollars", ([SellPrice1] * [OnHandQty]) - [InventoryCost],
        "_MarginDiscrepancy",
            (([SellPrice1] * [OnHandQty]) - [InventoryCost]) -
            (([SellPrice1] * [OnHandQty]) - ([StockOrderPrice] * [OnHandQty]))
    )
RETURN
SUMX(
    FILTER(DetailTable, [_MarginDiscrepancy] < 0),
    [_MarginDiscrepancy]
)
```

**Format**: `$#,0.00;($#,0.00);$#,0.00`

### 3. Net Margin $ Discrepancy

**Keep this one - it's already correct:**

```dax
Net Margin $ Discrepancy = [Positive Margin $ Discrepancy] + [Negative Margin $ Discrepancy]
```

**Format**: `$#,0.00;($#,0.00);$#,0.00`

---

## Why This Fix Works

### Before (Broken):
```dax
ADDCOLUMNS(
    dim_Parts_LowMargin,
    "MarginDiscrepancy", [Margin $ Discrepancy]
)
```

Where `[Margin $ Discrepancy]` references:
- `[Actual Margin $ (INV)]` = `[Sell Value] - [Inventory Cost]`
- `[Sell Value]` = `[Sell Price] * [Total SOH Qty]`
- `[Sell Price]` = `SUM(dim_Parts_LowMargin[SellPrice1])` ❌ Sums entire column!

### After (Fixed):
```dax
ADDCOLUMNS(
    dim_Parts_LowMargin,
    "MarginDiscrepancy",
        (([SellPrice1] * [OnHandQty]) - [InventoryCost]) -
        (([SellPrice1] * [OnHandQty]) - ([StockOrderPrice] * [OnHandQty]))
)
```

Direct column references evaluate row-by-row correctly: `[SellPrice1]` gets the current row's value.

---

## Expected Results After Fix

**New Report KPI Cards (No Filter):**
- Positive: ~$2,090,356.22 (from Test Positive Direct Calc)
- Negative: Will need to calculate
- Net: Positive + Negative

**Old Report KPI Cards (No Filter):**
- Positive: $5.31M
- Negative: ($138.75K)
- Net: $5.17M

**Expected Relationship:**
The new report should show ~$2.09M, which is still less than the old report's $5.31M. This remaining difference (~60% lower) is likely due to:

1. **Missing 4,125 rows** (2.7% of data)
2. **Different filtering logic** in how rows are included
3. **Cost vs StockOrderPrice field** (we're still using StockOrderPrice, not Cost)

---

## After Applying This Fix

### Step 1: Apply the Fixed Measures

Update the three measures in Power BI Desktop or directly in the TMDL file.

### Step 2: Verify the KPI Cards Match Test

After updating, the KPI cards should show:
- Positive: $2,090,356.22 (matching Test Positive Direct Calc)
- Negative: Should match a similar direct calc test
- Net: Should be the sum of Positive + Negative

### Step 3: Compare to Old Report

The new report will likely still show lower values than the old report. This is expected due to:
- Missing ~4,125 rows (2.7%)
- Different source data quality/filtering

### Step 4: Investigate Row Count Difference

To match the old report exactly, we need to understand why the new report has 4,125 fewer rows:

**Create this diagnostic measure:**
```dax
Missing Rows Analysis =
VAR NewReportRows = COUNTROWS(dim_Parts_LowMargin)
VAR OldReportRows = 155014
VAR Difference = OldReportRows - NewReportRows
RETURN
"New: " & NewReportRows & " | Old: " & OldReportRows & " | Missing: " & Difference
```

This will help determine if:
1. The filtering step removed too many rows
2. The source data changed between report builds
3. The old report had duplicate rows we should replicate

---

## Still Need to Add Cost Field

Remember, we're still using `[StockOrderPrice]` in these calculations. The old report uses `[Cost]` field from jdis_Part_Information.

After fixing the row context issue, you'll still need to:
1. Add Cost field to dim_Parts_LowMargin (per previous fix)
2. Update these measures to use `[Cost]` instead of `[StockOrderPrice]`

Complete formula with Cost field:
```dax
"DesiredMarginDollars", ([SellPrice1] * [OnHandQty]) - ([Cost] * [OnHandQty]),
```

---

## Implementation Order

1. ✅ **First**: Apply this fix (use direct column references)
2. ✅ **Verify**: KPI cards now show ~$2.09M (matching direct calc test)
3. ✅ **Then**: Add Cost field to dimension
4. ✅ **Update**: Change StockOrderPrice to Cost in these measures
5. ✅ **Final**: Verify against old report

---

## Technical Lesson Learned

**DAX Context Transition Rules:**

When using measures inside ADDCOLUMNS:
- ❌ **Aggregation measures** like `SUM()`, `AVERAGE()`, etc. will aggregate the entire table
- ✅ **Column references** like `[ColumnName]` evaluate row-by-row
- ❌ **Measures that call other aggregation measures** compound the problem
- ✅ **Direct calculations on columns** work correctly in row context

**Best Practice:**
When iterating over a table with SUMX/ADDCOLUMNS, always use direct column references, not measures that contain SUM/AVERAGE/etc.

**Exception:**
If you need a measure in row context, use `CALCULATE([Measure])` to force context transition, but this is slower.

---

## Summary

The KPI measures were using measure references that contained `SUM()` aggregations, causing them to sum the entire column instead of evaluating row-by-row. The fix is to use direct column references in the ADDCOLUMNS calculation.

This should get your new report KPI cards to show ~$2.09M (instead of $2.05M), which is closer but still not matching the old report's $5.31M due to missing rows and the Cost vs StockOrderPrice difference.
