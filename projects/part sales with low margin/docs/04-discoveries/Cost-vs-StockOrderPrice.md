# Discovery: Cost vs StockOrderPrice Field Usage

## Summary

The old report SQL includes both `Cost` and `StockOrderPrice` fields, but uses **Cost** for margin calculations on Page 2 (Inventory Cost Discrepancy). Understanding this distinction was critical to matching the old report's logic.

---

## The Two Cost Fields

### 1. Cost (from jdis_Part_Information)
```sql
pi_Cost AS "Cost"  -- From jdis_Part_Information table
```

**Used for:**
- Page 2 "Desired Margin" calculations
- MDP Value = Cost * Quantity
- Desired Margin $ = Sell Value - Cost Value

**Represents:** Purchase cost of the part from jdis system

### 2. StockOrderPrice (from InMaster)
```sql
COALESCE(InMaster_Filtered.STK_ORDER_PRICE, 0) AS STK_ORDER_PRICE  -- From InMaster table
```

**Used for:**
- Page 1 "Original Margin" calculations
- Stored in Fact_InTrans calculated columns
- Reference pricing from InMaster

**Represents:** Stock order price from InMaster system

---

## Field Mapping: Old to New

| Old Report Column | Old Source | New Report Column | New Source |
|-------------------|------------|-------------------|------------|
| Cost | jdis.pi_Cost | Cost | dim_Parts_LowMargin[Cost] |
| Cost Value | Cost * SOH Qty | Cost Value | [Cost] * [Total SOH Qty] |
| MDP Value | STK_ORDER_PRICE * SOH | MDP Value | StockOrderPrice * SOH |
| List Price | pi_List_Price_Master_File | ListPrice | dim_Parts_LowMargin[ListPrice] |
| Inventory Cost | pi_Inventory_Cost | InventoryCost | dim_Parts_LowMargin[InventoryCost] |
| Sell Price | pi_Sell_Price_1_Master_File | SellPrice1 | dim_Parts_LowMargin[SellPrice1] |

---

## Why This Matters

### Page 2 Calculations (Inventory Cost Discrepancy)

**Old Report Uses:**
```dax
Cost = SUM('Parts_Low_Margin_jdis_InMaster'[Cost])
Cost Value = [Cost] * [Total SOH Qty]
Desired Margin $ = [Sell Value] - [Cost Value]
```

**If New Report Used StockOrderPrice Instead:**
```dax
MDP Value = SUM(dim_Parts_LowMargin[StockOrderPrice]) * [Total SOH Qty]  // WRONG!
Desired Margin $ = [Sell Value] - [MDP Value]  // WRONG BASE!
```

Result: Different margin calculations, wrong parts flagged, incorrect totals.

---

## The Confusion

Initially, we thought:
1. MDP = "Manufacturer's Dealer Price" (Stock Order Price)
2. Old report probably uses MDP for calculations
3. We should use StockOrderPrice

**But the old report SQL revealed:**
- Old report has BOTH fields
- Old report uses **Cost** (not StockOrderPrice) for Desired Margin
- MDP Value is calculated but not used for margin gap analysis

---

## Example Showing the Difference

**Part: AH226238 in Branch 1**

| Field | Value | Source |
|-------|-------|--------|
| Cost | $619.52 | jdis pi_Cost |
| StockOrderPrice | $619.52 | InMaster STK_ORDER_PRICE |
| InventoryCost | $619.52 | jdis pi_Inventory_Cost |

For this part, they're all the same! But for other parts:

**Part: PFA12692 in Branch 3**

| Field | Value | Source |
|-------|-------|--------|
| Cost | $955.78 | jdis pi_Cost |
| StockOrderPrice | $955.78 | InMaster STK_ORDER_PRICE |
| InventoryCost | $1,190.84 | jdis pi_Inventory_Cost |

Cost and StockOrderPrice match, but InventoryCost differs.

**And for some parts, Cost and StockOrderPrice differ significantly!**

Using the wrong field changes:
- Which parts show positive vs. negative discrepancies
- The magnitude of the margin gaps
- The total KPI card values

---

## Implementation Impact

### In dim_Parts_LowMargin Query

Must include **both** fields:

```powerquery
jdis_Fields = Table.SelectColumns(dbo_jdis, {
    "PartNumber", "Franchise", "Branch",
    "ListPrice",
    "SellPrice1",
    "Cost",  // ← Must include for Page 2 calculations
    "QuantityOnHand",
    "BulkBinQty",
    "InventoryCost"
}),

// Later merge with InMaster to get:
InMaster_Fields = Table.SelectColumns(dbo_InMaster, {
    "PartNumber", "Franchise", "Branch",
    "LowMarginFlag",
    "StockOrderPrice"  // ← Keep for reference/Page 1
})
```

### In DAX Measures

**Page 2 (Inventory Analysis):**
```dax
Cost Value = [Cost] * [Total SOH Qty]  // Use Cost
Desired Margin $ = [Sell Value] - [Cost Value]
```

**Page 1 (Transaction Analysis) via Fact_InTrans:**
```dax
OriginalMarginDollars =  // Uses StockOrderPrice
    VAR UnitSellPrice = [SaleValue] / [Qty]
    VAR UnitCost = LOOKUPVALUE(
        dim_Parts_LowMargin[StockOrderPrice],  // StockOrderPrice here
        dim_Parts_LowMargin[PartNumber], [PartNumber],
        dim_Parts_LowMargin[Branch], [Branch],
        dim_Parts_LowMargin[Franchise], [Franchise],
        BLANK()
    )
    VAR OriginalMarginPerUnit = UnitSellPrice - UnitCost
    RETURN OriginalMarginPerUnit * [Qty]
```

---

## Discovery Timeline

1. **Initial migration** - Used StockOrderPrice for everything
2. **KPI cards didn't match** - Numbers way off
3. **Checked old report SQL** - Found both Cost and StockOrderPrice
4. **Re-read measure formulas** - Saw Cost used for Desired Margin
5. **Added Cost field** - Updated dimension query
6. **Updated measures** - Changed to use Cost for Page 2
7. **Validation** - Numbers now match!

---

## Technical Decision

**Final Rule:**
- **Page 2 (dim_Parts_LowMargin):** Use **Cost** for margin calculations
- **Page 1 (Fact_InTrans):** Use **StockOrderPrice** for original margin reference
- **Both fields available** in dim_Parts_LowMargin for flexibility

This matches the old report's logic exactly.

---

## Related Documentation

- [Page 2 Dimension Fix](../03-fixes-applied/Page-2-Dimension-Fix.md) - Adding Cost field
- [Measure Reference](../02-implementation/MEASURE-REFERENCE.md) - Which measures use which fields

---

**Status:** Clarified and documented ✅
**Impact:** Critical for accurate margin calculations
**Lesson:** Always check the source SQL, not just the report visuals
