# Column Source Decision - InMaster vs jdis_Part_Information

## Executive Summary

**Decision**: Use HYBRID approach - merge InMaster + jdis_Part_Information

**Why**:
- `LowMarginFlag` (user_field_3) ONLY exists in InMaster
- Current pricing & `InventoryCost` exist in jdis_Part_Information
- Old report used both tables merged as `Parts_Low_Margin_jdis_InMaster`

---

## Column Source Mapping

### From InMaster ONLY:
| Column | InMaster Column | Why InMaster |
|--------|----------------|--------------|
| LowMarginFlag | user_field_3 | ⭐ **CRITICAL** - Only exists in InMaster, not in jdis |

### From jdis_Part_Information (Current/Active Data):
| Column | jdis Column | Why jdis |
|--------|-------------|----------|
| InventoryCost | InventoryCost | Current calculated inventory value (not in InMaster) |
| StockOrderPrice | StockOrderPrice | Current MDP from manufacturer |
| ListPrice | ListPrice | Current manufacturer list price |
| SellPrice1 | SellPrice1 | Current selling price |
| OnHandQty | OnHandQty | Current quantity on hand |
| BulkBinQty | BulkBinQty | Current bulk bin quantity |

### Why NOT from InMaster for pricing/inventory:

**InMaster has:**
- `ON_HAND_VAL` - Total value (Qty × Cost), not a per-unit cost
- `STK_ORDER_PRICE` - Stock order price (same as jdis)
- `LIST_PRICE` - List price (same as jdis)
- `SELL_PRICE1` - Sell price (same as jdis)

**But jdis has:**
- `InventoryCost` - **Per-unit inventory cost** (calculated, current)
- All the same pricing fields PLUS more detail
- Always current (InMaster may lag)

---

## Old Report Structure

The old report table `Parts_Low_Margin_jdis_InMaster` was clearly a **merge** of both tables:

**Evidence from Old Report Columns:**
```
Parts_Low_Margin_jdis_InMaster[user_field_3]       ← InMaster ONLY
Parts_Low_Margin_jdis_InMaster[Inventory Cost]     ← jdis ONLY
Parts_Low_Margin_jdis_InMaster[STK_ORDER_PRICE]    ← Both (use jdis for current)
Parts_Low_Margin_jdis_InMaster[List Price]         ← Both (use jdis for current)
```

---

## Why Hybrid Approach is Best

### Your Requirements:
1. ✅ Need `user_field_3` (LOW flag) from InMaster - **ONLY** source
2. ✅ Need current pricing from jdis - **BEST** source (always current)
3. ✅ Need InventoryCost from jdis - **ONLY** detailed source
4. ✅ Can't modify dim_Parts (used by other reports) - Keep separate
5. ✅ Must match old report exactly - Old report used BOTH tables

### Solution:
```
dim_Parts_LowMargin = jdis_Part_Information
                      LEFT JOIN InMaster (on PartNumber)
                      TO GET: user_field_3 (LowMarginFlag)
```

**Benefits:**
- All current pricing/inventory from jdis (single source of truth)
- LOW flag from InMaster (only place it exists)
- Simple LEFT JOIN (jdis is main, add flag where exists)
- Fast refresh (<30 seconds for both small tables + join)
- Matches old report architecture

---

## Implementation Files

### Option 1: Simple (InMaster Only) - ❌ NOT RECOMMENDED
**File:** `dim_Parts_LowMargin_PowerBI.pq`
**Issue:** InMaster doesn't have `InventoryCost` as a per-unit cost field
**Result:** Pages 2 & 3 (Inventory analysis) won't work correctly

### Option 2: Hybrid (InMaster + jdis) - ✅ RECOMMENDED
**File:** `dim_Parts_LowMargin_PowerBI_HYBRID.pq`
**Advantage:**
- Gets LOW flag from InMaster (only source)
- Gets current pricing/inventory from jdis (best source)
- Matches old report structure
**Result:** All three report pages work correctly

---

## Column-by-Column Decision

| Column Needed | InMaster Has? | jdis Has? | **Decision** | Reason |
|---------------|---------------|-----------|--------------|---------|
| PartNumber | ✅ PART_NO | ✅ PartNumber | jdis | Primary key |
| Franchise | ✅ FRANCHISE | ✅ Franchise | jdis | Available both, use main source |
| Branch | ✅ BRANCH | ✅ Branch | jdis | Available both, use main source |
| **LowMarginFlag** | ✅ user_field_3 | ❌ NO | **InMaster** | ⭐ ONLY source |
| StockOrderPrice | ✅ STK_ORDER_PRICE | ✅ StockOrderPrice | jdis | Always current |
| ListPrice | ✅ LIST_PRICE | ✅ ListPrice | jdis | Always current |
| SellPrice1 | ✅ SELL_PRICE1 | ✅ SellPrice1 | jdis | Always current |
| OnHandQty | ✅ ON_HAND_QTY | ✅ OnHandQty | jdis | Current inventory |
| BulkBinQty | ✅ BULK_BIN_QTY | ✅ BulkBinQty | jdis | Current inventory |
| **InventoryCost** | ⚠️ ON_HAND_VAL (total, not per-unit) | ✅ InventoryCost | **jdis** | ⭐ Per-unit cost needed |

---

## What You Need to Do

### Step 1: Use the Hybrid Query
1. Open Power BI Desktop
2. Go to Transform Data (Power Query Editor)
3. Find `dim_Parts_LowMargin` query
4. Click Advanced Editor
5. **Replace all code** with code from: `dim_Parts_LowMargin_PowerBI_HYBRID.pq`
6. Click Done

### Step 2: Verify the Merge
After replacing the code, verify in Power Query preview:

**Expected Columns:**
- PartNumber (from jdis)
- Franchise (from jdis)
- Branch (from jdis)
- **LowMarginFlag** (from InMaster via join) - may have blanks for parts not flagged
- StockOrderPrice (from jdis)
- ListPrice (from jdis)
- SellPrice1 (from jdis)
- OnHandQty (from jdis)
- BulkBinQty (from jdis)
- InventoryCost (from jdis)
- IsLowMarginFlagged (calculated boolean)

**Row Count:**
- Should be similar to jdis_Part_Information count (all active parts)
- LowMarginFlag will be blank/null for most parts (only ~1,320 flagged)

### Step 3: Close & Apply
- Click Close & Apply
- Wait for refresh (30-60 seconds)
- Model will reload with hybrid dimension

---

## Validation After Implementation

### Test 1: Verify LOW Flag Join
```dax
// Create a card visual
Low Margin Parts Count =
CALCULATE(
    COUNTROWS(dim_Parts_LowMargin),
    dim_Parts_LowMargin[IsLowMarginFlagged] = TRUE
)
```
**Expected:** ~1,320 parts (from InMaster validation)

### Test 2: Verify Inventory Cost
```dax
// Create a card visual
Total Inventory Cost = SUM(dim_Parts_LowMargin[InventoryCost])
```
**Expected:** Large dollar value (total inventory value across all parts)

### Test 3: Verify Both Sources
Create a table visual with:
- dim_Parts_LowMargin[PartNumber]
- dim_Parts_LowMargin[LowMarginFlag] (from InMaster)
- dim_Parts_LowMargin[InventoryCost] (from jdis)
- dim_Parts_LowMargin[IsLowMarginFlagged] (calculated)

**Expected:**
- Most rows have blank LowMarginFlag (not flagged)
- Most rows have InventoryCost values (from jdis)
- IsLowMarginFlagged = TRUE only where LowMarginFlag = "LOW"

---

## Impact on dim_Parts

**No changes needed to dim_Parts!**

- dim_Parts stays as-is (used by other reports)
- dim_Parts_LowMargin is a NEW dimension specifically for this report
- Both can coexist in the model
- Different purposes:
  - dim_Parts: General parts dimension (description, categories, etc.)
  - dim_Parts_LowMargin: Specialized for low margin analysis

---

## Summary

✅ **Use `dim_Parts_LowMargin_PowerBI_HYBRID.pq`**
- Merges InMaster (for LOW flag) + jdis (for current pricing/inventory)
- Matches old report architecture
- All three report pages will work correctly
- Fast refresh time
- Accurate current data

❌ **Don't use `dim_Parts_LowMargin_PowerBI.pq`** (InMaster only)
- Missing InventoryCost as per-unit field
- Pages 2 & 3 won't calculate correctly

---

**Ready to implement? Use the HYBRID query and proceed with the TMDL measures!**
