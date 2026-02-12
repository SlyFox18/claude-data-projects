# Implementation Guide: Add Cost Field to Match Old Report

## Problem Summary

The new report is using **StockOrderPrice** for MDP calculations, but the old report uses **Cost** (pi_Cost from jdis_Part_Information). This is causing a ~10x difference in results:

- **Old Report**: Positive $1.43M, Negative ($10.48K), Net $1.42M
- **New Report**: Positive $141.93K, Negative ($13.89K), Net $128.04K

## Root Cause

The old report SQL shows TWO cost fields:
```sql
pi_Cost AS "Cost",                    -- From jdis_Part_Information (used for calculations)
COALESCE(InMaster_Filtered.STK_ORDER_PRICE, 0) AS STK_ORDER_PRICE  -- From InMaster (reference only)
```

But the new dim_Parts_LowMargin query only has StockOrderPrice, missing the Cost field entirely.

---

## Implementation Steps

### Step 1: Update Lakehouse dim_Parts_LowMargin Query

Replace the current dim_Parts_LowMargin query in your Lakehouse with [dim_Parts_LowMargin_FINAL_WITH_COST.pq](queries/dimensions/dim_Parts_LowMargin_FINAL_WITH_COST.pq).

**Critical changes made:**

1. **Line 36** - Added "Cost" to jdis_Fields selection:
```powerquery
jdis_Fields = Table.SelectColumns(dbo_jdis, {
    "PartNumber", "Franchise", "Branch",
    "ListPrice", "SellPrice1",
    "Cost",  // ← ADDED
    "QuantityOnHand", "BulkBinQty", "InventoryCost"
})
```

2. **Line 52** - Added "Cost" to aggregation:
```powerquery
AggregateJdis = Table.Group(
    jdis_Fields,
    {"PartNumber", "Branch", "Franchise"},
    {
        {"ListPrice", each List.Max([ListPrice]), type number},
        {"SellPrice1", each List.Max([SellPrice1]), type number},
        {"Cost", each List.Max([Cost]), type number},  // ← ADDED
        {"QuantityOnHand", each List.Sum([QuantityOnHand]), type number},
        {"BulkBinQty", each List.Sum([BulkBinQty]), type number},
        {"InventoryCost", each List.Sum([InventoryCost]), type number}
    }
)
```

3. **Line 143** - Added "Cost" to data types:
```powerquery
FinalDataTypes = Table.TransformColumnTypes(AddCompositeKey, {
    {"PartNumber", type text},
    {"Franchise", type text},
    {"Branch", type text},
    {"LowMarginFlag", type text},
    {"IsLowMarginFlagged", type logical},
    {"ListPrice", type number},
    {"SellPrice1", type number},
    {"Cost", type number},  // ← ADDED
    {"QuantityOnHand", type number},
    {"InventoryCost", type number},
    {"StockOrderPrice", type number},
    {"BulkBinQty", type number},
    {"OnHandQty", type number},
    {"PartBranchKey", type text}
})
```

**After updating:**
1. Save the query in Fabric Lakehouse
2. Run the pipeline to refresh dim_Parts_LowMargin
3. Wait for completion before proceeding to Step 2

---

### Step 2: Update Power BI Report Measures

Open the Power BI report and update measures in the `_Measures` table.

#### A. Create New Base Measures

Add these four new measures:

```dax
Cost = SUM(dim_Parts_LowMargin[Cost])
```
**Format**: `$#,0.00;($#,0.00);$#,0.00`

```dax
Cost Value = [Cost] * [Total SOH Qty]
```
**Format**: `$#,0.00;($#,0.00);$#,0.00`

```dax
List Price = SUM(dim_Parts_LowMargin[ListPrice])
```
**Format**: `$#,0.00;($#,0.00);$#,0.00`

```dax
New Sell Price =
    DIVIDE(
        ABS([Margin $ Discrepancy]),
        [Total SOH Qty],
        0
    ) + [List Price]
```
**Format**: `$#,0.00;($#,0.00);$#,0.00`

#### B. Update Existing Measures

**1. Update MDP Value** (or replace references and delete):

**Option 1**: Make MDP Value reference Cost Value
```dax
MDP Value = [Cost Value]
```

**Option 2**: Delete MDP Value measure and replace all references to `[MDP Value]` with `[Cost Value]` throughout the report

**2. Update Desired Margin $**:
```dax
Desired Margin $ = [Sell Value] - [Cost Value]
```
**Format**: `$#,0.00;($#,0.00);$#,0.00`

**3. Update Desired Margin %**:
```dax
Desired Margin % = DIVIDE([Desired Margin $], [Sell Value], 0)
```
**Format**: `0.00%;-0.00%;0.00%`

**4. Fix Part Description** (to work without relationship):
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
**Format**: None (text)

---

### Step 3: Update Table Visual (if needed)

If your table visual currently shows `[MDP Value]`, replace it with `[Cost Value]`.

**Table Columns Should Be**:
- Branch
- Franchise
- PartNumber
- Part Description
- Total SOH Qty
- Inventory Cost
- **Cost Value** (not MDP Value)
- Sell Value
- Desired Margin %
- Actual Margin % (INV)
- Desired Margin $
- Actual Margin $ (INV)
- Margin $ Discrepancy
- LowMarginFlag
- **New Sell Price** (not Sell Price)

---

### Step 4: Validation

After completing all updates, validate against the old report:

#### A. Check Specific Part (AH226238, Branch 1)

| Measure | Old Report | New Report (After Fix) | Status |
|---------|-----------|----------------------|--------|
| Cost | Has value | Should have value | ✓ Check |
| Cost Value | Has value | Should match old | ✓ Check |
| Desired Margin $ | $388.97 | Should be $388.97 | ✓ Check |
| Actual Margin $ (INV) | $275.13 | Should be $275.13 | ✓ Check |
| Margin $ Discrepancy | -$113.84 | Should be -$113.84 | ✓ Check |

#### B. Check KPI Cards (Branch 1, Franchise <> 'S')

| KPI | Old Report | New Report (After Fix) | Status |
|-----|-----------|----------------------|--------|
| Positive Margin $ Discrepancy | $1.43M | Should be ~$1.43M | ✓ Check |
| Negative Margin $ Discrepancy | ($10.48K) | Should be ~($10.48K) | ✓ Check |
| Net Margin $ Discrepancy | $1.42M | Should be ~$1.42M | ✓ Check |

#### C. Check Row Count

- Filter: Branch = "1", Franchise <> "S", Margin % -50% to 100%
- Old Report: 70+ rows with LowMarginFlag = "LOW"
- New Report (After Fix): Should be 70+ rows

#### D. Check Part Description

- Part Description column should show descriptions (not blank)
- Should work without errors (no USERELATIONSHIP error)

---

## Quick Reference: Old vs New Field Names

| Old Report | Old Source | New Report | New Source |
|-----------|-----------|-----------|-----------|
| Cost | jdis.pi_Cost | Cost | dim_Parts_LowMargin[Cost] |
| Cost Value | Cost * SOH Qty | Cost Value | [Cost] * [Total SOH Qty] |
| List Price | pi_List_Price_Master_File | List Price | SUM(dim_Parts_LowMargin[ListPrice]) |
| Sell Price | pi_Sell_Price_1_Master_File | Sell Price (base) | SUM(dim_Parts_LowMargin[SellPrice1]) |
| New Sell Price | Formula | New Sell Price | Formula |
| Inventory Cost | pi_Inventory_Cost | Inventory Cost | SUM(dim_Parts_LowMargin[InventoryCost]) |
| MDP (STK_ORDER_PRICE) | InMaster.STK_ORDER_PRICE | StockOrderPrice | dim_Parts_LowMargin[StockOrderPrice] |

---

## Common Issues and Troubleshooting

### Issue 1: Cost column not appearing after query update

**Cause**: Lakehouse pipeline not refreshed or Power BI not refreshed

**Fix**:
1. In Fabric Lakehouse, verify dim_Parts_LowMargin pipeline ran successfully
2. In Power BI Desktop, right-click dim_Parts_LowMargin table → Refresh data
3. Check Data view to confirm Cost column exists

### Issue 2: "Column 'Cost' not found" error in measures

**Cause**: Power BI hasn't refreshed the table schema

**Fix**:
1. Close Power BI Desktop completely
2. Reopen the report
3. Refresh dim_Parts_LowMargin table
4. Try creating measures again

### Issue 3: Numbers still don't match after all fixes

**Cause**: Measures not updated or using wrong fields

**Fix**:
1. Verify all 4 new measures created
2. Verify all 4 existing measures updated
3. Check table visual is using Cost Value (not MDP Value)
4. Check filters match old report exactly

### Issue 4: Part Description still showing USERELATIONSHIP error

**Cause**: Measure not updated to use LOOKUPVALUE

**Fix**: Replace measure with LOOKUPVALUE version (see Step 2.B.4 above)

---

## Files Reference

All supporting files are in: `projects/part sales with low margin/`

- **Updated Query**: [queries/dimensions/dim_Parts_LowMargin_FINAL_WITH_COST.pq](queries/dimensions/dim_Parts_LowMargin_FINAL_WITH_COST.pq)
- **Detailed Fix Documentation**: [FIXES-Page2-Measure-Corrections.md](FIXES-Page2-Measure-Corrections.md)
- **Field Mapping**: [PAGE-2-Inventory-Cost-Discrepancy-Mapping.md](PAGE-2-Inventory-Cost-Discrepancy-Mapping.md)

---

## Summary Checklist

- [ ] Step 1: Updated Lakehouse dim_Parts_LowMargin query with Cost field
- [ ] Step 1: Ran Lakehouse pipeline to refresh dimension
- [ ] Step 2.A: Created 4 new measures (Cost, Cost Value, List Price, New Sell Price)
- [ ] Step 2.B: Updated 4 existing measures (MDP Value, Desired Margin $, Desired Margin %, Part Description)
- [ ] Step 3: Updated table visual columns (Cost Value, New Sell Price)
- [ ] Step 4.A: Validated specific part (AH226238)
- [ ] Step 4.B: Validated KPI cards match old report
- [ ] Step 4.C: Validated row count (~70+)
- [ ] Step 4.D: Validated Part Description works

After completing all items, the new report should match the old report exactly!
