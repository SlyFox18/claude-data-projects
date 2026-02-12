# DAX Measures Migration Guide - Low Margin Report

## Overview

This guide maps DAX measures from the old report to the new report structure.

**Old Report Tables:**
- `InTrans_Low_Margin` → **NEW:** `Fact_InTrans`
- `Parts_Low_Margin_jdis_InMaster` → **NEW:** `dim_Parts_LowMargin`

**Key Architecture Change:**
- Old report: All calculations in DAX measures
- New report: Pre-calculated columns + simple DAX measures = FASTER performance

---

## PHASE 1: Create Calculated Columns in Fact_InTrans

Before creating measures, add these calculated columns to `Fact_InTrans` table.

Go to **Data View** → Click `Fact_InTrans` table → Click **New Column** for each:

### Column 1: LowMarginFlag
```dax
LowMarginFlag = RELATED(dim_Parts_LowMargin[LowMarginFlag])
```

### Column 2: StockOrderPrice
```dax
StockOrderPrice = RELATED(dim_Parts_LowMargin[StockOrderPrice])
```

### Column 3: ListPriceManuf
```dax
ListPriceManuf = RELATED(dim_Parts_LowMargin[ListPrice])
```

### Column 4: OriginalMarginDollars
```dax
OriginalMarginDollars = ([ListPriceManuf] - [StockOrderPrice]) * [Qty]
```
**Business Logic:** This is the margin we SHOULD have gotten based on manufacturer list price

### Column 5: MarginDiscrepancyDollars
```dax
MarginDiscrepancyDollars = [ActualMarginDollars] - [OriginalMarginDollars]
```
**Business Logic:** Difference between actual margin and expected margin
- Positive = We did BETTER than expected (sold above list price)
- Negative = We did WORSE than expected (sold below list price or cost increased)

### Column 6: IsLowMarginFlagged
```dax
IsLowMarginFlagged = [LowMarginFlag] = "LOW"
```
**Business Logic:** Boolean flag for easy filtering

---

## PHASE 2: Base Measures (Sales Transactions)

Create these measures in the `_Measures` table.

### Sales & Cost Measures

#### Sale $
```dax
Sale $ = SUM(Fact_InTrans[SaleValue])
```
**Format:** Currency `$#,##0.00`

**OLD vs NEW:**
- Old: `CALCULATE(SUM('InTrans_Low_Margin'[SALE_VAL]), 'InTrans_Low_Margin'[TYPE] = "I")`
- New: Simpler because we pre-filtered to TYPE = 'I' in Power Query

---

#### Cost $
```dax
Cost $ = SUM(Fact_InTrans[CostValue])
```
**Format:** Currency `$#,##0.00`

**OLD vs NEW:**
- Old: `SUM(InTrans_Low_Margin[COST_VAL])`
- New: Same logic, just renamed column

---

#### Qty
```dax
Qty = SUM(Fact_InTrans[Qty])
```
**Format:** Whole Number `#,##0`

---

### Margin Measures (Pre-calculated - FAST!)

#### Actual Margin $
```dax
Actual Margin $ = SUM(Fact_InTrans[ActualMarginDollars])
```
**Format:** Currency `$#,##0.00`

**OLD vs NEW:**
- Old: `SUM('InTrans_Low_Margin'[SALE_VAL]) - SUM('InTrans_Low_Margin'[COST_VAL])`
- New: Pre-calculated in Power Query, just SUM it = MUCH FASTER

---

#### Original Margin $
```dax
Original Margin $ = SUM(Fact_InTrans[OriginalMarginDollars])
```
**Format:** Currency `$#,##0.00`

**OLD vs NEW:**
- Old: `SUMX('InTrans_Low_Margin', ([List Price Manuf] - [Stock Order Price]) * [Qty])`
- New: Pre-calculated in calculated column, just SUM it = MUCH FASTER

**Business Logic:** Expected margin based on list price vs stock order price

---

#### Margin Discrepancy $
```dax
Margin Discrepancy $ = SUM(Fact_InTrans[MarginDiscrepancyDollars])
```
**Format:** Currency `$#,##0.00`

**OLD vs NEW:**
- Old: Called "Captured Margin" = `[Actual Margin] - [Original Margin Test]`
- New: Pre-calculated in calculated column

**Business Logic:**
- Positive = We captured MORE margin than expected (good!)
- Negative = We lost margin vs expected (investigate!)

---

### Margin Percentage Measures

#### Margin Value %
```dax
Margin Value % = DIVIDE([Actual Margin $], [Sale $], 0)
```
**Format:** Percentage `0.00%`

**OLD vs NEW:**
- Old: Same formula
- New: Same, but base measures are faster

**Business Logic:** Actual margin as % of sales

---

#### Original Margin %
```dax
Original Margin % = DIVIDE([Original Margin $], [Sale $], 0)
```
**Format:** Percentage `0.00%`

**Business Logic:** Expected margin % based on list price

---

## PHASE 3: Conditional Formatting Measures

### Margin Value % Color Code
```dax
Margin Color Code =
SWITCH(
    TRUE(),
    [Margin Value %] < 0, 1,                                    // Red (negative margin)
    [Margin Value %] >= 0 && [Margin Value %] < 0.05, 2,       // Pink (0-5%)
    [Margin Value %] >= 0.05 && [Margin Value %] < 0.10, 3,    // Orange (5-10%)
    [Margin Value %] >= 0.10 && [Margin Value %] <= 0.1499, 4, // Yellow (10-14.99%)
    BLANK()                                                     // No color for 15%+
)
```
**Format:** Whole Number `0`

**Usage:** Use in table visual conditional formatting (Background color by rules)

**Color Mapping:**
- 1 = Red (losing money)
- 2 = Pink (very low margin)
- 3 = Orange (low margin)
- 4 = Yellow (below target margin)

---

### Margin $ Discrepancy Color Code
```dax
Margin $ Discrepancy Color Code =
SWITCH(
    TRUE(),
    [Margin Discrepancy $] > 1, 1,                                              // Dark Green
    [Margin Discrepancy $] >= 0.75 && [Margin Discrepancy $] <= 1, 2,           // Green
    [Margin Discrepancy $] >= 0.50 && [Margin Discrepancy $] < 0.75, 3,         // Light Green
    [Margin Discrepancy $] >= 0.25 && [Margin Discrepancy $] < 0.50, 4,         // Lighter Green
    [Margin Discrepancy $] > 0 && [Margin Discrepancy $] < 0.25, 5,             // Even Lighter Green
    [Margin Discrepancy $] = 0, 6,                                               // White (neutral)
    [Margin Discrepancy $] < 0 && [Margin Discrepancy $] >= -0.25, 7,           // Real Light Red
    [Margin Discrepancy $] < -0.25 && [Margin Discrepancy $] >= -0.50, 8,       // Lighter Red
    [Margin Discrepancy $] < -0.50 && [Margin Discrepancy $] >= -0.75, 9,       // Light Red
    [Margin Discrepancy $] < -0.75 && [Margin Discrepancy $] >= -1, 10,         // Red
    [Margin Discrepancy $] < -1, 11,                                             // Dark Red
    BLANK()
)
```
**Format:** Whole Number `0`

**Business Logic:** Green = captured more margin than expected, Red = lost margin

---

## PHASE 4: Inventory Analysis Measures (Page 2 & 3)

These measures work with `dim_Parts_LowMargin` for stock on hand analysis.

**NOTE:** These are for the "Inventory Cost Discrepancy" and "Low Action Items" pages.

### Total SOH Qty
```dax
Total SOH Qty =
    SUM(dim_Parts_LowMargin[BulkBinQty]) + SUM(dim_Parts_LowMargin[OnHandQty])
```
**Format:** Whole Number `#,##0`

**Business Logic:** Total stock on hand (bulk bin + regular bin)

**ISSUE:** Your `dim_Parts_LowMargin` doesn't have BulkBinQty/OnHandQty columns yet!

**FIX OPTIONS:**
1. Add these columns to `dim_Parts_LowMargin_PowerBI.pq` from InMaster
2. OR create a separate query/dimension for inventory analysis
3. OR if not using inventory pages, skip this section

---

### Inventory Cost
```dax
Inventory Cost = SUM(dim_Parts_LowMargin[InventoryCost])
```
**Format:** Currency `$#,##0.00`

**ISSUE:** Column doesn't exist in current dim_Parts_LowMargin

---

### Original MDP Value
```dax
Original MDP Value =
    SUM(dim_Parts_LowMargin[StockOrderPrice]) * [Total SOH Qty]
```
**Format:** Currency `$#,##0.00`

**Business Logic:** Expected cost based on stock order price × quantity on hand

---

### % Difference (Cost Variance)
```dax
% Difference =
DIVIDE(
    (SUM(dim_Parts_LowMargin[StockOrderPrice]) * [Total SOH Qty]) - [Inventory Cost],
    ((SUM(dim_Parts_LowMargin[StockOrderPrice]) * [Total SOH Qty]) + [Inventory Cost]) / 2,
    0
)
```
**Format:** Percentage `0.0%`

**Business Logic:** Percentage difference between original MDP cost and actual inventory cost
- Positive % = Inventory cost is LOWER than expected (good!)
- Negative % = Inventory cost is HIGHER than expected (investigate!)

---

### % Difference Color Code (Low Action Items page)
```dax
% Diff Discr (Low) Color Code =
SWITCH(
    TRUE(),
    [% Difference] >= 0, 1,                                         // Green (cost lower than MDP)
    [% Difference] <= -0.000001 && [% Difference] > -0.05, 2,      // Light yellow (-0.1% to -5%)
    [% Difference] <= -0.051 && [% Difference] > -0.1, 3,          // Yellow (-5.1% to -10%)
    [% Difference] <= -0.10 && [% Difference] > -0.15, 8,          // Light orange (-10.1% to -15%)
    [% Difference] <= -0.15, 4,                                     // Red (-15% and worse)
    BLANK()
)
```
**Format:** Whole Number `0`

**Business Logic:** Highlights parts where actual cost is significantly higher than MDP

---

## PHASE 5: Validation Measures

Create these to validate your migration:

### Row Count Check
```dax
Total Transactions = COUNTROWS(Fact_InTrans)
```
**Expected:** 3-6M rows (2 years of invoices)

---

### Type Verification
```dax
Type Check =
VAR TypeCount = CALCULATE(COUNTROWS(Fact_InTrans), Fact_InTrans[Type] <> "I")
RETURN
IF(TypeCount = 0, "✅ All TYPE = I", "⚠️ Non-invoice records found!")
```
**Expected:** "✅ All TYPE = I"

---

### Margin Calculation Spot Check
```dax
Margin Calc Check =
VAR ActualSum = SUM(Fact_InTrans[ActualMarginDollars])
VAR CalcSum = [Sale $] - [Cost $]
VAR Diff = ActualSum - CalcSum
RETURN
IF(ABS(Diff) < 0.01, "✅ Margins match", "⚠️ Margin mismatch: " & FORMAT(Diff, "$#,##0.00"))
```
**Expected:** "✅ Margins match"

---

## PHASE 6: Missing Columns for Inventory Analysis

If you want to replicate pages 2 & 3 (Inventory Cost Discrepancy, Low Action Items), you need to add these columns to `dim_Parts_LowMargin_PowerBI.pq`:

**Add to SelectColumns step:**
```powerquery
SelectColumns = Table.SelectColumns(dbo_InMaster, {
    "PartNumber",
    "Franchise",
    "LowMarginFlag",
    "StockOrderPrice",
    "ListPrice",
    // ADD THESE for inventory analysis:
    "BulkBinQty",           // For Total SOH Qty
    "OnHandQty",            // For Total SOH Qty
    "InventoryCost",        // For cost discrepancy analysis
    "SellPrice1"            // Already in your query
}),
```

**Or create a separate dimension:**
- `dim_Parts_Inventory` with full InMaster fields for pages 2 & 3
- Keep `dim_Parts_LowMargin` lightweight for transaction analysis (page 1)

---

## Summary of Changes

### Performance Improvements ✅

| Calculation | Old Approach | New Approach | Performance Gain |
|-------------|--------------|--------------|------------------|
| Actual Margin $ | Calculated in DAX every query | Pre-calc in PQ, SUM in DAX | **10-50x faster** |
| Original Margin $ | SUMX row-by-row | Pre-calc column, SUM | **10-50x faster** |
| Margin Discrepancy $ | Calculated measure | Pre-calc column, SUM | **10-50x faster** |
| Low Margin Flag filter | Text comparison every row | Boolean column | **5-10x faster** |

### What You Need to Do Next

**✅ COMPLETED:**
1. ✅ Fact_InTrans query loaded with date filter
2. ✅ dim_Parts_LowMargin query loaded
3. ✅ Basic table structure in place
4. ✅ Home header measure created

**⏭️ NEXT STEPS:**

**Step 1: Fix Relationships**
- Make `Fact_InTrans → dim_Parts_LowMargin` relationship **INACTIVE**
- This allows RELATED() to work in calculated columns

**Step 2: Add Calculated Columns** (Phase 1 above)
- Add 6 calculated columns to Fact_InTrans
- Wait 1-2 minutes for calculation (3-6M rows)

**Step 3: Create Base Measures** (Phase 2 above)
- Create measures in _Measures table
- Test against old report totals

**Step 4: Add Conditional Formatting** (Phase 3 above)
- Color code measures for visual formatting

**Step 5: Decide on Inventory Pages**
- Do you need pages 2 & 3?
- If yes, add columns to dim_Parts_LowMargin or create separate dimension

**Step 6: Validate**
- Compare totals to old report
- Spot check calculations
- Test filters and slicers

---

## Questions to Answer

1. **Do you need the Inventory Analysis pages (2 & 3)?**
   - If yes, we need to add more columns from InMaster
   - If no, we can skip those measures

2. **What date range should we validate against?**
   - Old report likely had different date range
   - Need to align for apples-to-apples comparison

3. **Are there any custom visuals or interactions to replicate?**
   - Screenshots show table visuals with conditional formatting
   - Any slicers or filters we need to set up?

---

## Ready to Start?

Start with **PHASE 1** - add the 6 calculated columns to Fact_InTrans.

After those calculate, we'll create the base measures in **PHASE 2** and validate against old report totals.

Let me know when you're ready to proceed or if you have questions about any of these measures!
