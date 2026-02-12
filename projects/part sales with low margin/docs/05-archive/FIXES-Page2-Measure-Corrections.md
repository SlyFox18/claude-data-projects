# Page 2 Measure Corrections - Match Old Report Exactly

## Root Cause Analysis

The old report uses **`Cost`** field from `jdis_Part_Information` (pi_Cost), NOT `StockOrderPrice` from InMaster!

Looking at the old SQL:
```sql
pi_Cost AS "Cost",                    -- From jdis_Part_Information
pi_List_Price_Master_File AS "List Price",
pi_Inventory_Cost AS "Inventory Cost",
...
COALESCE(InMaster_Filtered.STK_ORDER_PRICE, 0) AS STK_ORDER_PRICE  -- From InMaster
```

The old report has BOTH fields but uses **`Cost`** for MDP calculations.

---

## Fix 1: Add Cost Field to dim_Parts_LowMargin

Update the Power Query to include the `Cost` field from jdis_Part_Information:

### In dim_Parts_LowMargin query - Step 2:

```powerquery
jdis_Fields = Table.SelectColumns(dbo_jdis, {
    "PartNumber", "Franchise", "Branch",
    "ListPrice",            // Manufacturer list price
    "SellPrice1",           // Current selling price
    "Cost",                 // ← ADD THIS - pi_Cost from jdis
    "QuantityOnHand",
    "BulkBinQty",
    "InventoryCost"
}),
```

### In dim_Parts_LowMargin query - Step 3 (Aggregation):

```powerquery
AggregateJdis = Table.Group(
    jdis_Fields,
    {"PartNumber", "Branch", "Franchise"},
    {
        {"ListPrice", each List.Max([ListPrice]), type number},
        {"SellPrice1", each List.Max([SellPrice1]), type number},
        {"Cost", each List.Max([Cost]), type number},  // ← ADD THIS
        {"QuantityOnHand", each List.Sum([QuantityOnHand]), type number},
        {"BulkBinQty", each List.Sum([BulkBinQty]), type number},
        {"InventoryCost", each List.Sum([InventoryCost]), type number}
    }
),
```

### In dim_Parts_LowMargin query - Step 9 (Data Types):

```powerquery
FinalDataTypes = Table.TransformColumnTypes(AddCompositeKey, {
    {"PartNumber", type text},
    {"Franchise", type text},
    {"Branch", type text},
    {"LowMarginFlag", type text},
    {"IsLowMarginFlagged", type logical},
    {"ListPrice", type number},
    {"SellPrice1", type number},
    {"Cost", type number},  // ← ADD THIS
    {"QuantityOnHand", type number},
    {"InventoryCost", type number},
    {"StockOrderPrice", type number},
    {"BulkBinQty", type number},
    {"OnHandQty", type number},
    {"PartBranchKey", type text}
})
```

---

## Fix 2: Update MDP Value Measure

**Old (Wrong):**
```dax
MDP Value = SUM(dim_Parts_LowMargin[StockOrderPrice]) * [Total SOH Qty]
```

**New (Correct):**
```dax
MDP Value = SUM(dim_Parts_LowMargin[Cost]) * [Total SOH Qty]
```

**Or rename to match old report exactly:**
```dax
Cost = SUM(dim_Parts_LowMargin[Cost])

Cost Value = [Cost] * [Total SOH Qty]
```

Then use `[Cost Value]` instead of `[MDP Value]` everywhere.

---

## Fix 3: Update Desired Margin $ Measure

**Old (Wrong):**
```dax
Desired Margin $ = [Sell Value] - [MDP Value]
```

**New (Correct):**
```dax
Desired Margin $ = [Sell Value] - [Cost Value]
```

Where:
```dax
Cost Value = [Cost] * [Total SOH Qty]
Cost = SUM(dim_Parts_LowMargin[Cost])
```

---

## Fix 4: Add New Sell Price Measure

**Old Report Formula:**
```dax
New Sell Price = DIVIDE(ABS([Margin $ Discrepancy]), [Total SOH Qty], 0) + [List Price]
```

**New Report - Add This Measure:**
```dax
New Sell Price =
    DIVIDE(
        ABS([Margin $ Discrepancy]),
        [Total SOH Qty],
        0
    ) + [List Price]
```

Where:
```dax
List Price = SUM(dim_Parts_LowMargin[ListPrice])
```

---

## Fix 5: Part Description Measure (Without Relationship)

Since there's no relationship, use LOOKUPVALUE instead:

**Old (Broken):**
```dax
Part Description =
    VAR FromDimParts = CALCULATE(
        SELECTEDVALUE(dim_Parts[Description]),
        USERELATIONSHIP(dim_Parts[PartNumber], dim_Parts_LowMargin[PartNumber])
    )
    VAR FromFactInTrans = SELECTEDVALUE(Fact_InTrans[Description])
    RETURN
    IF(FromDimParts <> BLANK(), FromDimParts, FromFactInTrans)
```

**New (Fixed):**
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

---

## Summary of All Measures to Add/Update

### New Measures to Add:

```dax
Cost = SUM(dim_Parts_LowMargin[Cost])
```

```dax
Cost Value = [Cost] * [Total SOH Qty]
```

```dax
New Sell Price =
    DIVIDE(ABS([Margin $ Discrepancy]), [Total SOH Qty], 0) + [List Price]
```

```dax
List Price = SUM(dim_Parts_LowMargin[ListPrice])
```

### Measures to Update:

**1. MDP Value** (if keeping this name):
```dax
MDP Value = [Cost Value]
```

Or just replace all references to `[MDP Value]` with `[Cost Value]`

**2. Desired Margin $:**
```dax
Desired Margin $ = [Sell Value] - [Cost Value]
```

**3. Desired Margin %:**
```dax
Desired Margin % = DIVIDE([Desired Margin $], [Sell Value], 0)
```

**4. Part Description:**
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

---

## Field Mapping Summary (Old vs New)

| Old Report Field | Old Source | New Report Field | New Source |
|------------------|------------|------------------|------------|
| Cost | jdis pi_Cost | Cost | dim_Parts_LowMargin[Cost] |
| Cost Value | Cost * SOH Qty | Cost Value | [Cost] * [Total SOH Qty] |
| MDP Value | STK_ORDER_PRICE * SOH | MDP Value | StockOrderPrice * SOH |
| List Price | pi_List_Price_Master_File | List Price | dim_Parts_LowMargin[ListPrice] |
| Inventory Cost | pi_Inventory_Cost | Inventory Cost | dim_Parts_LowMargin[InventoryCost] |
| Sell Price | pi_Sell_Price_1_Master_File | Sell Price | dim_Parts_LowMargin[SellPrice1] |

**Key Insight**: The old report uses **Cost** (not StockOrderPrice/MDP) for the "Desired Margin" calculations on Page 2!

---

## Validation After Fixes

Compare these specific values for part AH226238 in Branch 1:

**Old Report:**
- Cost Value: Should match "Cost Value" calculation
- Desired Margin $: $388.97
- Actual Margin $ (INV): $275.13
- Margin $ Discrepancy: -$113.84

**New Report (After Fix):**
- Cost Value: Should match old report
- Desired Margin $: Should be $388.97
- Actual Margin $ (INV): Should be $275.13
- Margin $ Discrepancy: Should be -$113.84

**KPI Cards (Branch 1):**
- Positive: ~$141.93K (from new screenshot)
- Negative: ~($13.89K) (from new screenshot)
- Net: ~$128.04K (from new screenshot)

These should stabilize once Cost field is added and measures are corrected.

---

## Order of Operations

1. **Update dim_Parts_LowMargin query** - Add Cost field
2. **Refresh** Power Query
3. **Add new measures** - Cost, Cost Value, List Price, New Sell Price
4. **Update existing measures** - MDP Value, Desired Margin $, Part Description
5. **Update table visual** - Replace MDP Value column with Cost Value (if desired)
6. **Validate** - Compare specific parts and KPI totals

After these changes, the new report should match the old report exactly!
