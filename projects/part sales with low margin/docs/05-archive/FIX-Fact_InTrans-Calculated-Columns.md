# Fix Fact_InTrans Calculated Columns for Multi-Row dim_Parts_LowMargin

## The Problem

Error: **"A table of multiple values was supplied where a single value was expected."**

**Root Cause:** dim_Parts_LowMargin now has multiple rows per PartNumber (one per Branch + Franchise combination), but the calculated columns in Fact_InTrans are only looking up by PartNumber.

**Example:**
```dax
LOOKUPVALUE(dim_Parts_LowMargin[LowMarginFlag], dim_Parts_LowMargin[PartNumber], [PartNumber])
```

This returns multiple values because the same PartNumber exists in multiple branches.

## The Solution

Add **Branch** (and optionally Franchise) to all LOOKUPVALUE calls to get a unique match.

---

## Fixed Calculated Columns

### 1. LowMarginFlag

**Old (Broken):**
```dax
LowMarginFlag =
LOOKUPVALUE(
    dim_Parts_LowMargin[LowMarginFlag],
    dim_Parts_LowMargin[PartNumber], [PartNumber]
)
```

**New (Fixed):**
```dax
LowMarginFlag =
LOOKUPVALUE(
    dim_Parts_LowMargin[LowMarginFlag],
    dim_Parts_LowMargin[PartNumber], [PartNumber],
    dim_Parts_LowMargin[Branch], [Branch]
)
```

---

### 2. StockOrderPrice

**Old (Broken):**
```dax
StockOrderPrice =
LOOKUPVALUE(
    dim_Parts_LowMargin[StockOrderPrice],
    dim_Parts_LowMargin[PartNumber], [PartNumber]
)
```

**New (Fixed):**
```dax
StockOrderPrice =
LOOKUPVALUE(
    dim_Parts_LowMargin[StockOrderPrice],
    dim_Parts_LowMargin[PartNumber], [PartNumber],
    dim_Parts_LowMargin[Branch], [Branch]
)
```

---

### 3. ListPriceManuf

**Old (Broken):**
```dax
ListPriceManuf =
LOOKUPVALUE(
    dim_Parts_LowMargin[ListPrice],
    dim_Parts_LowMargin[PartNumber], [PartNumber]
)
```

**New (Fixed):**
```dax
ListPriceManuf =
LOOKUPVALUE(
    dim_Parts_LowMargin[ListPrice],
    dim_Parts_LowMargin[PartNumber], [PartNumber],
    dim_Parts_LowMargin[Branch], [Branch]
)
```

---

### 4. OriginalMarginDollars

**Old (Broken):**
```dax
OriginalMarginDollars =
VAR UnitSellPrice = [SaleValue] / [Qty]
VAR UnitCost = LOOKUPVALUE(
    dim_Parts_LowMargin[StockOrderPrice],
    dim_Parts_LowMargin[PartNumber], [PartNumber]
)
VAR OriginalMarginPerUnit = UnitSellPrice - UnitCost
RETURN OriginalMarginPerUnit * [Qty]
```

**New (Fixed):**
```dax
OriginalMarginDollars =
VAR UnitSellPrice = [SaleValue] / [Qty]
VAR UnitCost = LOOKUPVALUE(
    dim_Parts_LowMargin[StockOrderPrice],
    dim_Parts_LowMargin[PartNumber], [PartNumber],
    dim_Parts_LowMargin[Branch], [Branch]
)
VAR OriginalMarginPerUnit = UnitSellPrice - UnitCost
RETURN OriginalMarginPerUnit * [Qty]
```

---

### 5. IsLowMarginFlagged

**Old (Broken):**
```dax
IsLowMarginFlagged =
LOOKUPVALUE(
    dim_Parts_LowMargin[IsLowMarginFlagged],
    dim_Parts_LowMargin[PartNumber], [PartNumber]
)
```

**New (Fixed):**
```dax
IsLowMarginFlagged =
LOOKUPVALUE(
    dim_Parts_LowMargin[IsLowMarginFlagged],
    dim_Parts_LowMargin[PartNumber], [PartNumber],
    dim_Parts_LowMargin[Branch], [Branch]
)
```

---

### 6. MarginDiscrepancyDollars

**No change needed** - this column references other calculated columns:
```dax
MarginDiscrepancyDollars = [ActualMarginDollars] - [OriginalMarginDollars]
```

Once OriginalMarginDollars is fixed, this will work correctly.

---

## Why Branch (Not Franchise) is Sufficient

Fact_InTrans has:
- `[PartNumber]` - The part being sold
- `[Branch]` - The branch where the sale occurred
- `[Franchise]` - The franchise (D, C, etc.)

dim_Parts_LowMargin has unique rows for:
- PartNumber + Branch + Franchise

**However**, for a given transaction in Fact_InTrans:
- The Branch is known
- The Franchise is known
- But looking up by PartNumber + Branch should be sufficient if each branch only has one franchise per part

**If a branch can have the same part in multiple franchises**, you'll need to add Franchise to the lookup as well:

```dax
LowMarginFlag =
LOOKUPVALUE(
    dim_Parts_LowMargin[LowMarginFlag],
    dim_Parts_LowMargin[PartNumber], [PartNumber],
    dim_Parts_LowMargin[Branch], [Branch],
    dim_Parts_LowMargin[Franchise], [Franchise]
)
```

---

## How to Apply These Fixes

### Option A: Edit in Power BI Desktop

1. Open the report in Power BI Desktop
2. Go to **Data view**
3. Select **Fact_InTrans** table
4. For each calculated column:
   - Click the column name in the Fields pane
   - Look at the formula bar at the top
   - Click in the formula bar to edit
   - Add the Branch (and Franchise if needed) parameters
   - Press Enter to save

### Option B: Edit TMDL File

1. **Close Power BI Desktop** (critical!)
2. Open `Fact_InTrans.tmdl` in text editor
3. Find each calculated column (lines 133, 139, 147, 155-160, 168)
4. Update with the fixed formulas above
5. Save the file
6. Open Power BI Desktop

---

## Testing After Fix

After applying the fixes:

1. **Check for errors**: All calculated columns should show values (no error icons)

2. **Verify data accuracy**: Compare a few transactions to the old report
   - Pick a transaction from old report
   - Find same transaction in new report (by TransId)
   - Verify LowMarginFlag, StockOrderPrice, OriginalMarginDollars match

3. **Check cross-branch transactions**:
   - Filter Fact_InTrans to a specific Branch
   - Verify all values look reasonable
   - Try different branches to ensure lookups work across all branches

---

## Expected Results

After fixing, all five calculated columns should:
- ✅ Show values (no errors)
- ✅ Match the branch-specific values from dim_Parts_LowMargin
- ✅ Work correctly even though dim_Parts_LowMargin has multiple rows per PartNumber

The key insight: Each transaction in Fact_InTrans has a specific Branch, so we can uniquely identify which row from dim_Parts_LowMargin to use by including Branch in the lookup.

---

## If You Still Get Errors After Adding Branch

If you still get "multiple values" error after adding Branch, it means a single PartNumber + Branch combination has multiple rows in dim_Parts_LowMargin (probably due to multiple Franchises).

In that case, add Franchise to the lookup:

```dax
LOOKUPVALUE(
    dim_Parts_LowMargin[LowMarginFlag],
    dim_Parts_LowMargin[PartNumber], [PartNumber],
    dim_Parts_LowMargin[Branch], [Branch],
    dim_Parts_LowMargin[Franchise], [Franchise]
)
```

This will give you a truly unique match based on all three keys.

---

## Alternative: Use RELATED Instead

If you want to create a relationship between Fact_InTrans and dim_Parts_LowMargin, you could:

1. Create a composite key column in Fact_InTrans:
```dax
PartBranchKey = [PartNumber] & "|" & [Branch] & "|" & [Franchise]
```

2. Create relationship: `Fact_InTrans[PartBranchKey]` → `dim_Parts_LowMargin[PartBranchKey]`

3. Use RELATED instead of LOOKUPVALUE:
```dax
LowMarginFlag = RELATED(dim_Parts_LowMargin[LowMarginFlag])
```

**However**, LOOKUPVALUE is simpler and doesn't require creating relationships, so I recommend sticking with the LOOKUPVALUE approach with multiple search keys.
