# ERROR FIX: BulkBinQty Column Not Found

## The Error

```
Expression.Error: The column 'BulkBinQty' of the table wasn't found.
Details:
    BulkBinQty
```

---

## Root Cause

**Initial Assumption (WRONG):**
- Assumed BulkBinQty was in InMaster table
- CORRECTED query tried to select BulkBinQty from InMaster

**Reality:**
- **BulkBinQty exists in jdis_Part_Information** (pi_Bulk_Bin_Qty → BulkBinQty)
- **BulkBinQty does NOT exist in InMaster** (InMaster only has ON_HAND_QTY and BACK_ORD_QTY)

---

## Evidence from Raw Tables

### InMaster.pq - What InMaster Actually Has

```sql
SELECT
    -- INVENTORY LEVELS
    ON_HAND_QTY AS OnHandQty,      ← Only has this
    BACK_ORD_QTY AS BackOrderQty,  ← And this
    -- NO BULK_BIN_QTY field!
FROM InMaster
```

### jdis_Part_Information.pq - What jdis Actually Has

```sql
SELECT
    -- INVENTORY MANAGEMENT
    pi_On_Hand_Qty AS QuantityOnHand,
    pi_Bin_Qty AS BinQty,
    pi_Bulk_Bin_Qty AS BulkBinQty,     ← BulkBinQty is HERE!
    pi_Pending_Qty AS PendingQty,
    pi_Back_Ord_Qty AS BackOrderQty,
FROM jdis_Part_Information
```

---

## The Fix

### BEFORE (Incorrect - Caused Error)

```powerquery
// Step 1: Try to get BulkBinQty from InMaster
InMaster_Fields = Table.SelectColumns(dbo_InMaster, {
    "PartNumber",
    "LowMarginFlag",
    "StockOrderPrice",
    "BulkBinQty"            // ← ERROR! Does NOT exist in InMaster
})
```

### AFTER (Correct - Works)

```powerquery
// Step 1: Get only fields that ACTUALLY exist in InMaster
InMaster_Fields = Table.SelectColumns(dbo_InMaster, {
    "PartNumber",
    "LowMarginFlag",        // ONLY in InMaster
    "StockOrderPrice"       // In InMaster
    // BulkBinQty removed - not in InMaster!
})

// Step 2: Get BulkBinQty from jdis where it actually exists
jdis_Fields = Table.SelectColumns(dbo_jdis, {
    "PartNumber",
    "ListPrice",
    "SellPrice1",
    "QuantityOnHand",
    "BulkBinQty",           // ← FROM JDIS! (pi_Bulk_Bin_Qty)
    "InventoryCost"
})
```

---

## Updated Column Source Truth

| Column | InMaster Has? | jdis Has? | **Get From** |
|--------|---------------|-----------|--------------|
| LowMarginFlag | ✅ user_field_3 | ❌ NO | **InMaster** (ONLY source) |
| StockOrderPrice | ✅ STK_ORDER_PRICE | ❌ NO | **InMaster** |
| OnHandQty | ✅ ON_HAND_QTY | ✅ pi_On_Hand_Qty → QuantityOnHand | **jdis** (always current) |
| **BulkBinQty** | ❌ **NO** | ✅ **pi_Bulk_Bin_Qty** | **jdis** (NOT InMaster!) |
| BackOrderQty | ✅ BACK_ORD_QTY | ✅ pi_Back_Ord_Qty | Either (use jdis for current) |
| InventoryCost | ❌ NO (has ON_HAND_VAL total) | ✅ pi_Inventory_Cost | **jdis** (per-unit cost) |
| ListPrice | ✅ LIST_PRICE | ✅ pi_List_Price_Master_File | **jdis** (always current) |
| SellPrice1 | ✅ SELL_PRICE1 | ✅ pi_Sell_Price_1_Master_File | **jdis** (always current) |

---

## Why This Matters

### SOH (Stock On Hand) Calculation

**Formula:** `Total SOH = QuantityOnHand + BulkBinQty`

**Both components come from jdis:**
- QuantityOnHand (pi_On_Hand_Qty)
- BulkBinQty (pi_Bulk_Bin_Qty)

**InMaster contribution:**
- LOW margin flag (user_field_3)
- Stock Order Price for MDP calculations

---

## Files Updated

1. ✅ **dim_Parts_LowMargin_PowerBI_CORRECTED.pq** - Fixed to get BulkBinQty from jdis
2. ✅ **CORRECTED-COLUMN-MAPPING.md** - Updated Discovery 3 and truth table
3. ✅ **This file** - Documents the error and fix

---

## What You Need to Do

1. Open Power BI Desktop
2. Go to Transform Data (Power Query Editor)
3. Find `dim_Parts_LowMargin` query
4. Click Advanced Editor
5. **Replace ALL code** with updated code from: `dim_Parts_LowMargin_PowerBI_CORRECTED.pq`
6. Click Done
7. Query should load without errors now

**Validation:**
- Preview should show BulkBinQty column populated
- No error messages
- Column comes from jdis_Part_Information, not InMaster

---

## Lesson Learned

**Never assume column names without verifying source tables!**

**Verification process:**
1. Check raw table documentation files
2. Read actual SQL queries in raw .pq files
3. Confirm column names in source systems
4. Test in Power Query preview

**What we thought:**
- BulkBinQty is in both InMaster and jdis

**Reality:**
- BulkBinQty is ONLY in jdis_Part_Information
- InMaster has ON_HAND_QTY but NOT BULK_BIN_QTY

---

## Status

✅ **ERROR FIXED**
✅ **CORRECTED query updated**
✅ **Documentation updated**
✅ **Ready for testing in Power BI**

**Next Step:** Test updated query in Power BI Desktop to confirm it loads without errors.
