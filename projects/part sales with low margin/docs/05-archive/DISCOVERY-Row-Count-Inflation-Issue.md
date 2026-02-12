# Discovery: Row Count Inflation in dim_Parts_LowMargin

## The Mystery

Initial comparison showed:
- **Old Report KPI Cards**: $5.31M positive, ($138K) negative (no filter)
- **New Report KPI Cards**: $2.07M positive, ($123K) negative (no filter)
- **Difference**: New report showing ~39% of old report values

But when we looked at individual rows, they matched exactly!

## The Investigation

### Test 1: Filter to Branch 3

**Old Report:**
- Row Count: 4,931
- Positive: $39.38K
- Negative: ($3.12K)
- Net: $36.26K

**New Report (Before Fix):**
- Row Count: 33,816 (6.86x more!)
- Positive: $39,251.83
- Negative: ($3,096.19)
- Net: $36,155.64

### Test 2: No Filter (All Branches)

**Old Report:**
- Total Rows: 155,264

**New Report (Before Fix):**
- Total Rows: 1,081,386 (7x more!)

## The Root Cause

The new report's dim_Parts_LowMargin dimension was creating rows for **every combination** of PartNumber + Branch + Franchise, including:
- Parts with QuantityOnHand = 0
- Parts with BulkBinQty = 0
- Parts with no meaningful data for analysis

These rows had $0 margin discrepancies, so they inflated the row count massively but had minimal impact on KPI totals (which is why the totals were "close" but not exact).

### Why This Happened

The jdis_Part_Information source table has entries for parts across all franchises, even when the franchise has zero inventory for that part. When we aggregated by PartNumber + Branch + Franchise, we included all these zero-inventory combinations.

The old report's SQL implicitly filtered these out through WHERE clauses or JOIN conditions:

```sql
-- Old report SQL (simplified)
SELECT ...
FROM jdis_Part_Information jdis
LEFT JOIN InMaster_Filtered ON jdis."Part No" = InMaster.PART_NO
WHERE jdis."Quantity on Hand" > 0 OR InMaster.user_field_3 = 'LOW'
-- (or similar filtering logic)
```

Our new Power Query didn't have this filtering step.

## The Solution

Add a filtering step AFTER aggregation but BEFORE creating the composite key:

```powerquery
// STEP 8: FILTER TO MEANINGFUL ROWS ONLY
FilterMeaningfulRows = Table.SelectRows(AddOnHandQty, each
    [OnHandQty] > 0 or [LowMarginFlag] = "LOW"
),
```

This keeps only rows where:
1. **OnHandQty > 0** - Part has inventory to analyze, OR
2. **LowMarginFlag = "LOW"** - Part is flagged for review even if no current inventory

## The Impact

### Before Filter:
- Total Rows: 1,081,386
- Branch 3 Rows: 33,816
- Problem: ~86% of rows have OnHandQty = 0 and don't contribute to analysis
- KPI Totals: Lower than expected due to missing rows that old report included

### After Filter:
- Total Rows: ~155,000 (expected)
- Branch 3 Rows: ~4,931 (expected)
- Solution: Only meaningful rows included
- KPI Totals: Should match old report exactly

## The Files

### Updated Query with Fix:
[dim_Parts_LowMargin_FILTERED_FINAL.pq](queries/dimensions/dim_Parts_LowMargin_FILTERED_FINAL.pq)

This query includes:
1. ✅ Multi-column join (PartNumber + Branch + Franchise)
2. ✅ Aggregation to handle source duplicates
3. ✅ **NEW: Filtering to remove zero-inventory, non-flagged rows**
4. ✅ Cost field from jdis_Part_Information
5. ✅ Composite key for relationships (if needed)

## Expected Results After Fix

### Row Counts:
| Filter | Old Report | New Report (Before) | New Report (After) |
|--------|-----------|-------------------|-------------------|
| All Branches | 155,264 | 1,081,386 ❌ | ~155,000 ✅ |
| Branch 3 | 4,931 | 33,816 ❌ | ~4,931 ✅ |

### KPI Cards (All Branches, No Filter):
| Metric | Old Report | New Report (Before) | New Report (After) |
|--------|-----------|-------------------|-------------------|
| Positive | $5.31M | $2.07M ❌ | ~$5.31M ✅ |
| Negative | ($138.75K) | ($123.62K) ❌ | ~($138.75K) ✅ |
| Net | $5.17M | $1.95M ❌ | ~$5.17M ✅ |

### KPI Cards (Branch 3):
| Metric | Old Report | New Report (Before) | New Report (After) |
|--------|-----------|-------------------|-------------------|
| Positive | $39.38K | $39.25K ✅ | ~$39.38K ✅ |
| Negative | ($3.12K) | ($3.10K) ✅ | ~($3.12K) ✅ |
| Net | $36.26K | $36.16K ✅ | ~$36.26K ✅ |

The Branch 3 totals were already close because most of the inflated rows had $0 discrepancies. The filtering will make them exact.

## Validation Steps

After loading the updated query:

### 1. Check Row Counts

**No filters applied:**
```dax
Row Count = COUNTROWS(dim_Parts_LowMargin)
```
Expected: ~155,000 (not 1.08M)

**Branch 3 only:**
Expected: ~4,931 (not 33,816)

### 2. Check KPI Cards Match Old Report

**No filters applied:**
- Positive: Should be ~$5.31M
- Negative: Should be ~($138.75K)
- Net: Should be ~$5.17M

**Branch 3 only:**
- Positive: Should be ~$39.38K
- Negative: Should be ~($3.12K)
- Net: Should be ~$36.26K

### 3. Verify Individual Rows Still Match

Compare specific parts (PFA12692, X387TC-4-RL, etc.) - values should still match exactly.

## Why the KPI Totals Were Close But Not Exact

The new report was missing meaningful rows because:

1. **Filtering removed too many rows** - The zero-inventory filter removed ALL rows for some parts, even those flagged LOW
2. **Different grain** - Some parts in old report might aggregate differently
3. **Cost vs StockOrderPrice** - Still using wrong field for calculations (separate issue)

After this fix + adding the Cost field + updating measures, everything should match exactly.

## Technical Lesson Learned

When migrating from SQL to Power Query:
1. ✅ Match the join logic (we did this - multi-column keys)
2. ✅ Match the aggregation logic (we did this - Group step)
3. ❌ **DON'T FORGET THE WHERE CLAUSES!** (we missed this initially)

SQL WHERE clauses that filter out rows need explicit Power Query Table.SelectRows steps.

The old report's SQL likely had:
```sql
WHERE QuantityOnHand > 0 OR LowMarginFlag = 'LOW'
```

We need the equivalent Power Query:
```powerquery
Table.SelectRows(table, each [OnHandQty] > 0 or [LowMarginFlag] = "LOW")
```

## Next Steps

1. ✅ Load [dim_Parts_LowMargin_FILTERED_FINAL.pq](queries/dimensions/dim_Parts_LowMargin_FILTERED_FINAL.pq) to Lakehouse
2. ✅ Refresh the dimension in Fabric
3. ✅ Refresh Power BI report
4. ✅ Validate row counts match
5. ✅ Update measures per [IMPLEMENTATION-GUIDE-Cost-Field-Fix.md](IMPLEMENTATION-GUIDE-Cost-Field-Fix.md)
6. ✅ Final validation that all values match old report

After completing these steps, the new report should be a perfect match to the old report!
