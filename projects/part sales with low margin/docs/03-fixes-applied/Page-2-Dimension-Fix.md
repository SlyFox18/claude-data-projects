# Page 2 Dimension Fix (dim_Parts_LowMargin)

## Summary of Issues Fixed

During migration of Page 2 (Inventory Cost Discrepancy), we discovered and fixed multiple issues with the dim_Parts_LowMargin dimension:

1. **Wrong join key** - Joined only on PartNumber instead of PartNumber + Branch + Franchise
2. **Row count inflation** - 7x more rows due to missing filtering
3. **Missing Cost field** - Old report uses Cost, new was using StockOrderPrice
4. **No relationship needed** - Page 2 uses standalone dimension, not related to Fact_InTrans

---

## Issue 1: Wrong Join Key

### Problem

**Old Query (Broken):**
```powerquery
MergeInMaster = Table.NestedJoin(
    jdis_Fields,
    {"PartNumber"},  // ← Missing Branch and Franchise!
    InMaster_Fields,
    {"PartNumber"},
    "InMasterData",
    JoinKind.LeftOuter
),

RemoveDuplicates = Table.Distinct(RemoveBlankParts, {"PartNumber"})
```

This caused:
- Same part in different branches got arbitrary StockOrderPrice/LowMarginFlag values
- Only 11 parts flagged as LOW in Branch 1 (should be 70+)
- KPI totals way off

### Fix

**New Query (Fixed):**
```powerquery
MergeInMaster = Table.NestedJoin(
    AggregateJdis,
    {"PartNumber", "Branch", "Franchise"},  // ← Multi-column join key
    InMaster_Fields,
    {"PartNumber", "Branch", "Franchise"},
    "InMasterData",
    JoinKind.LeftOuter
)
```

No deduplication needed after aggregation - PartNumber + Branch + Franchise is unique.

**Impact:**
- Branch 1 now shows 70+ LOW parts (correct)
- Each branch gets its own StockOrderPrice and LowMarginFlag values
- Matches old report structure

---

## Issue 2: Row Count Inflation

### Problem

The dimension was creating rows for ALL combinations of PartNumber + Branch + Franchise, including parts with:
- QuantityOnHand = 0
- BulkBinQty = 0
- No meaningful data to analyze

**Results:**
- Old Report: 155,014 rows total, 4,931 for Branch 3
- New Report (Before Fix): 1,081,386 rows total, 33,816 for Branch 3 (7x more!)

Most extra rows had OnHandQty = 0 and contributed nothing to analysis but inflated counts.

### Fix

Added filtering step after aggregation:

```powerquery
// STEP 8: FILTER TO MEANINGFUL ROWS ONLY
FilterMeaningfulRows = Table.SelectRows(AddOnHandQty, each
    [OnHandQty] > 0 or [LowMarginFlag] = "LOW"
),
```

This keeps only rows where:
- OnHandQty > 0 (has inventory to analyze), OR
- LowMarginFlag = "LOW" (flagged even if no current inventory)

**Impact:**
- Row count reduced from 1.08M to ~151K
- Matches old report's row count
- Only meaningful data included

---

## Issue 3: Missing Cost Field

### Problem

The old report SQL shows TWO cost fields:
```sql
pi_Cost AS "Cost",                    -- From jdis_Part_Information (used for calculations)
COALESCE(InMaster_Filtered.STK_ORDER_PRICE, 0) AS STK_ORDER_PRICE  -- From InMaster
```

The old report uses **Cost** for MDP calculations, not StockOrderPrice!

**Old Report Measures:**
```dax
Cost Value = [Cost] * [Total SOH Qty]
Desired Margin $ = [Sell Value] - [Cost Value]
```

**New Report (Before Fix):**
```dax
MDP Value = [StockOrderPrice] * [Total SOH Qty]  // ← Wrong field!
Desired Margin $ = [Sell Value] - [MDP Value]    // ← Wrong base
```

This caused different margin calculations and affected which parts were flagged.

### Fix

Add Cost field to the dimension query:

**Step 2 - Add to column selection:**
```powerquery
jdis_Fields = Table.SelectColumns(dbo_jdis, {
    "PartNumber", "Franchise", "Branch",
    "ListPrice", "SellPrice1",
    "Cost",  // ← ADDED
    "QuantityOnHand", "BulkBinQty", "InventoryCost"
})
```

**Step 3 - Add to aggregation:**
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

**Step 9 - Add to data types:**
```powerquery
{"Cost", type number}
```

**Impact:**
- Measures now use Cost instead of StockOrderPrice
- Calculations match old report logic
- Margin values align with expectations

---

## Issue 4: No Relationship to Fact_InTrans

### Problem

User tried to create relationship: `Fact_InTrans[PartNumber]` → `dim_Parts_LowMargin[PartNumber]`

**Error:** "Column 'PartNumber' contains duplicate value 'AN260236'"

This is because PartNumber now correctly appears multiple times (once per branch/franchise).

### Why This Is NOT a Problem

Page 2 doesn't need a relationship!

- Page 2 shows **current inventory snapshot** from dim_Parts_LowMargin
- Page 1 shows **transaction history** from Fact_InTrans (uses dim_Parts instead)
- These are two different analyses with different purposes

**Correct Approach:**
- dim_Parts_LowMargin is a **standalone table** for Page 2
- Use visual-level filters (Branch, Franchise, Margin % range)
- Measures reference dim_Parts_LowMargin directly

**For Fact_InTrans calculated columns that need values from dim_Parts_LowMargin:**

Use LOOKUPVALUE with all three keys:
```dax
LowMarginFlag =
LOOKUPVALUE(
    dim_Parts_LowMargin[LowMarginFlag],
    dim_Parts_LowMargin[PartNumber], [PartNumber],
    dim_Parts_LowMargin[Branch], [Branch],
    dim_Parts_LowMargin[Franchise], [Franchise],
    BLANK()  // Return blank if no match
)
```

See [Calculated Columns Fix](Calculated-Columns-Fix.md) for details.

---

## Final Query

The complete fixed query is in:
`queries/dimensions/dim_Parts_LowMargin_FILTERED_FINAL.pq`

This includes:
1. ✅ Multi-column join (PartNumber + Branch + Franchise)
2. ✅ Aggregation to handle source duplicates
3. ✅ Filtering to remove zero-inventory rows
4. ✅ Cost field from jdis_Part_Information
5. ✅ Composite key (PartBranchKey) if needed

---

## Validation

After applying this fix, verify:

### Row Counts
- Total rows: ~150K (not 1.08M)
- Branch 3: ~4,931 rows (not 33,816)

### Data Accuracy
Filter to Branch 1:
- Should show 70+ parts with LowMarginFlag = "LOW"
- KPI cards should show reasonable values
- Table data should match old report row-by-row

### Field Presence
- Cost column exists in dim_Parts_LowMargin
- All measures can reference [Cost]
- Lookups work correctly

---

## Related Fixes

- [KPI Measures Fix](KPI-Measures-Fix.md) - Row context issue with measures
- [Calculated Columns Fix](Calculated-Columns-Fix.md) - LOOKUPVALUE with multiple keys

---

**Status:** Fixed and Validated ✅
**Files:** `queries/dimensions/dim_Parts_LowMargin_FILTERED_FINAL.pq`
