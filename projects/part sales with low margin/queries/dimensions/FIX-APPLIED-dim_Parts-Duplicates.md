# FIX APPLIED: dim_Parts Duplicate PartNumber Error

## The Error

```
The column 'PartNumber' in the 'dim_Parts' table contains a duplicate value ('10MN').
This is not allowed for columns that are on the 'one' side of a many-to-one relationship
or are used as a primary key.
```

**Impact:** Multiple reports failed including:
- Inspections - V2 semantic model (pipeline failure)
- Other reports using dim_Parts

---

## Root Cause Analysis

### What Happened

The `dim_Parts.pq` query had deduplication at line 221:
```powerquery
RemoveDuplicates = Table.Distinct(AddIsHighValue, {"PartNumber"})
```

However, this wasn't sufficient because:
1. **Timing Issue:** Deduplication happened mid-process, not at the end
2. **Table.Combine Issue:** After combining UnknownPartsTyped with regular parts (line 311), no final deduplication occurred
3. **Source Data Issue:** `jdis_Part_Information` likely has true duplicate PartNumber values

### Why '10MN' Specifically?

PartNumber '10MN' appears multiple times in the source `jdis_Part_Information` table. Possible reasons:
- Same part exists in multiple branches
- Same part with different franchises
- Data quality issue in source system

---

## The Fix Applied

### Quick Fix (ALREADY APPLIED)

Added a **final deduplication step** after all transformations:

```powerquery
// Line 350 - NEW STEP ADDED
FinalDeduplication = Table.Distinct(FinalSort, {"PartNumber"})

in
    FinalDeduplication  // Changed from FinalSort
```

**What this does:**
- Ensures absolutely NO duplicate PartNumber values make it through
- Keeps first occurrence of each PartNumber (lowest PartNumberKey)
- Runs AFTER all transformations and sorting
- Guarantees uniqueness for relationship integrity

**Status:** ✅ **FIX ALREADY APPLIED TO dim_Parts.pq**

---

## What You Need to Do NOW

### Step 1: Refresh the dim_Parts Table

1. **Option A: In Lakehouse Dataflow**
   - Open the dataflow that creates dim_Parts
   - Refresh the dim_Parts query
   - Publish changes
   - Run dataflow

2. **Option B: In Power BI Report**
   - Open each affected report
   - Transform Data > Find dim_Parts query
   - Right-click dim_Parts > Refresh Preview
   - Close & Apply
   - Save report

### Step 2: Verify Fix Worked

After refreshing, the error should be gone. To verify:

**In Power BI Desktop:**
1. Go to Model view
2. Click on dim_Parts table
3. Look at PartNumber column properties
4. Should show no errors
5. Row count should be slightly less (duplicates removed)

**In Power BI Service:**
1. Trigger dataset refresh for Inspections - V2
2. Should complete without errors
3. Check pipeline - should run successfully

### Step 3: Investigate Root Cause (Optional but Recommended)

To understand WHY '10MN' was duplicated:

1. In Power Query Editor, create a new blank query
2. Paste contents from: `DIAGNOSTIC-dim_Parts-Duplicates.pq`
3. Run the diagnostic query
4. Review results to see:
   - How many duplicates exist in source
   - What's different between duplicate records (Branch? Franchise?)
   - Whether this is a data quality issue

---

## Longer-Term Considerations

### If Duplicates are Expected (PartNumber not truly unique)

**Scenario:** PartNumber '10MN' legitimately exists in multiple branches

**Current Approach:** Taking first occurrence only (arbitrary)

**Better Approach Options:**

**Option 1: Change Grain to PartNumber + Branch**
```powerquery
// Line 221 - Change to include Branch
RemoveDuplicates = Table.Distinct(AddIsHighValue, {"PartNumber", "Branch"})
```
**Impact:** Changes dimension grain - relationships need to match on PartNumber + Branch

**Option 2: Aggregate to PartNumber Level**
```powerquery
// Group by PartNumber and sum quantities
GroupedParts = Table.Group(
    CleanReturnable,
    {"PartNumber", "Description", "Franchise"},  // Group keys
    {
        {"QuantityOnHand", each List.Sum([QuantityOnHand]), type number},
        {"BackOrderQty", each List.Sum([BackOrderQty]), type number},
        // ... aggregate other numeric columns
    }
)
```
**Impact:** Single PartNumber row with totals across all branches

**Option 3: Filter to Specific Branch**
```powerquery
// Only include parts from main branch
FilterBranch = Table.SelectRows(Source, each [Branch] = "MAIN")
```
**Impact:** Only shows parts from one branch

### If Duplicates are NOT Expected (Data Quality Issue)

**Action Required:**
1. Run diagnostic query to identify all duplicates
2. Review with data team/database administrator
3. Fix in source system (jdis_Part_Information)
4. Re-refresh dim_Parts after source is fixed

**Temporary Mitigation:** Current fix (final deduplication) keeps working until source is fixed

---

## Testing Checklist

After applying fix and refreshing:

- [ ] dim_Parts refreshes without errors
- [ ] dim_Parts has unique PartNumber values (no duplicates)
- [ ] Inspections - V2 report refreshes successfully
- [ ] Other reports using dim_Parts refresh successfully
- [ ] Pipeline runs without errors
- [ ] Relationships in model view show no errors
- [ ] Report visuals display correctly

---

## Rollback Plan (If Needed)

If the fix causes other issues, rollback steps:

### Option 1: Git Rollback
```bash
cd "c:\Users\bfox\Documents\Git-Projects\data-projects"
git checkout HEAD~1 -- "projects/part sales with low margin/queries/dimensions/dim_Parts.pq"
```

### Option 2: Manual Rollback
Remove the FinalDeduplication step:

1. Open dim_Parts.pq
2. Find line 350: `FinalDeduplication = Table.Distinct(FinalSort, {"PartNumber"})`
3. Delete lines 341-350 (entire section)
4. Change line 353 from `FinalDeduplication` back to `FinalSort`
5. Save

**BUT:** Rolling back will bring the duplicate error back! Only rollback if fix causes NEW problems.

---

## Summary

**What was done:** Added final deduplication step to ensure no duplicate PartNumber values

**Status:** ✅ Fix applied to [dim_Parts.pq](dim_Parts.pq)

**Next action:** Refresh dim_Parts table in all affected reports/dataflows

**Expected result:** Error eliminated, reports refresh successfully

**Diagnostic tool:** Use [DIAGNOSTIC-dim_Parts-Duplicates.pq](DIAGNOSTIC-dim_Parts-Duplicates.pq) to investigate root cause

---

**Questions or Issues?**

If the error persists after applying fix and refreshing:
1. Run diagnostic query to see current state
2. Check if source jdis_Part_Information has changed
3. Verify fix was actually applied to the correct dim_Parts.pq file
4. Check if multiple versions of dim_Parts exist in different locations
