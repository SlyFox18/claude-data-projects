# Lessons Learned - Parts Promo Migration

**Project:** Parts Promo Report Migration
**Date:** 2026-01-19
**Purpose:** Document discoveries and patterns for future projects

---

## Critical Discoveries

### 1. ZP Franchise = Promo Parts

**Problem:** Query returned only 23 rows instead of 12K+

**Root Cause:** Filter `[Franchise] <> "ZP"` was excluding promo parts

**Discovery:** In the InTrans system, **promo parts (like *FOS, *10PROMO) are coded with Franchise = 'ZP'**

**Solution:**
```powerquery
// WRONG - excludes all promos
FilterToPromos = Table.SelectRows(InTrans, each
    Text.StartsWith([PartNumber], "*")
    and [Franchise] <> "ZP"  // This kills promos!
)

// CORRECT - include ZP for promos
FilterToPromos = Table.SelectRows(InTrans, each
    Text.StartsWith([PartNumber], "*")
    // No franchise filter for promo parts
)
```

**Pattern for Future:** When filtering promo/special parts, DON'T exclude ZP franchise.

---

### 2. Branch Column is TEXT, Not Integer

**Problem:** Dataflow failing with "We couldn't convert to Number. Detail = 4B"

**Root Cause:** Branch column contains sub-branch codes like:
- 4B (branch 4, type B)
- 4S (branch 4, setup shop)
- 4I (branch 4, type I)

**Discovery:** We assumed Branch was an integer key, but it's actually a text classification

**Solution:**
```powerquery
// WRONG
SetTypes = Table.TransformColumnTypes(Source, {
    {"Branch", Int64.Type}  // Fails on "4B"
})

// CORRECT
SetTypes = Table.TransformColumnTypes(Source, {
    {"Branch", type text}  // Handles "4B", "4S", etc.
})
```

**Relationship:** `Fact[Branch]` → `dim_BranchLocation[BranchID]` (text-to-text)

**Pattern for Future:** Always check sample data before assuming column types. Branch/location codes often have suffix letters.

---

### 3. InTrans.Description = Customer Name

**Problem:** dim_PromoType showing wrong descriptions (customer names instead of promo descriptions)

**Root Cause:** The `Description` column in InTrans is typically the **customer name**, not the part description

**Solution:** Join with jdis_Part_Information to get actual part descriptions

```powerquery
// Get part descriptions from jdis_Part_Information
PartInfo = Lakehouse{[Id = "jdis_Part_Information", ItemKind = "Table"]}[Data],
PartDescriptions = Table.SelectColumns(
    Table.Distinct(PartInfo, {"PartNumber"}),
    {"PartNumber", "Description"}
),

// Join to get actual descriptions
JoinPartInfo = Table.NestedJoin(
    UniquePromos, {"PartNumber"},
    PartDescriptions, {"PartNumber"},
    "PartInfo", JoinKind.LeftOuter
)
```

**Pattern for Future:** Always verify what "Description" columns actually contain. In transactional tables, they often hold context-specific data (customer, job, etc.) rather than master data descriptions.

---

### 4. Date vs DateTime Type Comparison

**Problem:** "We cannot apply operator < to types Date and DateTime"

**Root Cause:** Comparing `#date(2022, 1, 1)` with `[TransDatetime]` (datetime column)

**Solution:**
```powerquery
// WRONG
StartDate = #date(2022, 1, 1)

// CORRECT
StartDate = #datetime(2022, 1, 1, 0, 0, 0)
```

**Pattern for Future:** When filtering datetime columns, always use `#datetime()` not `#date()`. The types must match for comparison operators.

---

### 5. Simple Queries Better in Report Than Dataflow

**Problem:** Fact_InTrans_AllPromo kept failing in dataflow due to Qty conversion issues

**Insight:** The query is just:
- Date filter
- Column selection
- Type setting

**No complex transformations = no need for intermediate Lakehouse table**

**Solution:** Use Power Query directly in the semantic model

**Benefits:**
- Avoids double storage
- Avoids dataflow write issues
- DirectQuery can fold to Lakehouse
- Simpler architecture

**Pattern for Future:**

| Query Complexity | Recommended Location |
|------------------|---------------------|
| Simple filter + select | Report Power Query |
| Complex transformations | Dataflow → Lakehouse |
| Joins across sources | Dataflow → Lakehouse |
| Aggregations | Depends on volume |

---

## Design Patterns Validated

### 1. Star Schema Redesign

**Old Model:**
- Complex self-join in fact table query
- Many-to-Many relationships
- Runtime aggregations

**New Model:**
- Pre-aggregated dim_RepairOrder
- Clean one-to-many relationships
- Calculations at refresh time

**Benefits:**
- Simpler DAX
- Better performance
- Clearer business logic

### 2. Dimension from Transaction Data

**Pattern:** Create dimension by aggregating transaction table

```powerquery
// dim_PromoType - derived from InTrans_Incremental
UniquePromos = Table.Group(
    FilterToPromos,
    {"PartNumber"},
    {
        {"FirstSeen", each List.Min([TransDatetime]), type datetime},
        {"LastSeen", each List.Max([TransDatetime]), type datetime},
        {"UsageCount", each Table.RowCount(_), Int64.Type}
    }
)
```

**Use When:**
- Need to categorize transaction-level data
- No master data table exists
- Want usage statistics in dimension

### 3. Pre-Aggregated Context Dimension

**Pattern:** Replace self-join with pre-aggregated dimension

**Old Approach (Parts_Promo.pq):**
```sql
SELECT promo.*,
       (SELECT SUM(SALE_VAL) FROM InTrans WHERE REF_NO = promo.REF_NO AND NOT promo...) as PartSales
FROM InTrans promo
WHERE Part_No LIKE '*%'
```

**New Approach (dim_RepairOrder):**
```powerquery
// Pre-aggregate once per REF_NO
AggregatedOrders = Table.Group(
    FilteredOrders,
    {"RONumber"},
    {
        {"TotalPartsSales", each List.Sum([non-promo SaleValues])},
        {"TotalPromoDiscount", each List.Sum([promo SaleValues])},
        ...
    }
)
```

**Benefits:**
- Calculation done once at refresh
- Clean relationship to fact table
- No runtime self-join overhead

---

## Dataflow vs Report Power Query Decision Matrix

| Scenario | Use Dataflow | Use Report PQ |
|----------|--------------|---------------|
| Complex transformations | Yes | No |
| Joins across sources | Yes | No |
| Data used by multiple reports | Yes | No |
| Simple filter/select | No | Yes |
| Incremental refresh needed | Yes | Maybe |
| DirectQuery to Lakehouse | No | Yes |
| Avoiding data duplication | No | Yes |

---

## Testing Checklist for Migration

Based on this project, add these checks:

- [ ] **Sample data review** - Check actual values before setting types
- [ ] **Franchise filter logic** - Understand what Franchise = 'ZP' means
- [ ] **Description column source** - Is it master data or transaction context?
- [ ] **Branch/Location codes** - Check for letter suffixes (4B, 4S, etc.)
- [ ] **Date vs DateTime** - Match types in filters
- [ ] **Row count validation** - Compare new vs old query counts
- [ ] **Simple query assessment** - Does it need a dataflow or can it stay in report?

---

## Code Snippets to Reuse

### Safe Qty Conversion
```powerquery
CleanQty = Table.TransformColumns(Source, {
    {"Qty", each try Number.From(_) otherwise null, type number}
})
```

### Promo Part Filter (Correct)
```powerquery
FilterToPromos = Table.SelectRows(InTrans, each
    Text.StartsWith([PartNumber], "*")
    and [TransDatetime] >= StartDate
    // No franchise filter - ZP is valid for promos
)
```

### Join for Part Description
```powerquery
PartInfo = Lakehouse{[Id = "jdis_Part_Information", ItemKind = "Table"]}[Data],
PartDescriptions = Table.SelectColumns(
    Table.Distinct(PartInfo, {"PartNumber"}),
    {"PartNumber", "Description"}
),

JoinPartInfo = Table.NestedJoin(
    SourceTable, {"PartNumber"},
    PartDescriptions, {"PartNumber"},
    "PartInfo", JoinKind.LeftOuter
),

ExpandPartInfo = Table.ExpandTableColumn(
    JoinPartInfo, "PartInfo",
    {"Description"},
    {"PartDescription"}
)
```

---

## Summary

The Parts Promo migration revealed several important patterns:

1. **Domain Knowledge Critical** - ZP franchise, Branch sub-codes, Description content
2. **Type Safety** - Match date/datetime types in comparisons
3. **Architecture Decisions** - Not everything needs a dataflow
4. **Star Schema Benefits** - Pre-aggregation simplifies downstream work
5. **Testing Early** - Row count validation catches filter logic errors

These lessons should be applied to all future migration projects.
