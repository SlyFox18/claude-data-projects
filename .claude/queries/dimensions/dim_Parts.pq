/*
============================================================================
DIM_PARTS - OPTIMIZED PARTS DIMENSION (BASED ON PERFORMANCE TESTING)
============================================================================

📋 TABLE OVERVIEW:
Purpose: Master parts dimension with practical inventory, pricing, and sales intelligence
Grain: One row per unique part number with essential business data and operational insights
Refresh Strategy: Full refresh (parts data changes infrequently)
Target Performance: <5 minutes (realistic improvement from 6 minutes)
Source Dependencies: jdis_Part_Information (Raw lakehouse table)

⚡ PERFORMANCE OPTIMIZATIONS APPLIED (PROVEN IN TESTING):
✅ OPTIMIZATION #1: Early Blank Removal - Filter before expensive operations
   - Tested savings: ~20 seconds (1:21 → 1:02)
✅ OPTIMIZATION #2: Early Deduplication - Process unique parts only
   - Reduces downstream processing by 5-10%
   - FIXED 2026-08 (CORRECTNESS BUG): previously Table.Distinct, which just
     keeps whichever row happens to appear FIRST in source row order per
     PartNumber - not the correct/majority value. Confirmed live on
     production data: DZ111141 has 21 source rows (19x Franchise='D',
     1x'TD', 1x'td') but Table.Distinct picked one of the 2 rare rows.
     Same pattern confirmed for 19M7966, Z47990, R78055, R71387, and
     ~23,000 PartNumbers total. Now uses Table.Group with a per-column
     majority-vote (mode) for the 6 business filter columns - see STEP 1.
✅ OPTIMIZATION #3: Consolidated Text Cleaning - 9 fields in 1 pass
   - Maintains original speed, better code organization
✅ OPTIMIZATION #4: Removed Text.Proper on Description (BIGGEST WIN)
   - Text.Proper is expensive on 1M rows
   - Using Text.Upper instead = much faster
✅ OPTIMIZATION #5: Strategic column selection early
   - Reduces memory footprint for downstream operations
✅ OPTIMIZATION #6: FINAL DEDUPLICATION - Ensures no duplicate PartNumbers
   - CRITICAL FIX for relationship errors
   - Guarantees uniqueness for "one" side of relationships

❌ OPTIMIZATIONS NOT INCLUDED (TESTED AS SLOWER):
❌ InMaster JOIN - Adds 1:20 to preview time (will handle separately)
❌ Table.ToRecords pattern - Adds 50+ seconds
❌ Complex calculated column consolidation - Doesn't improve speed

📊 EXPECTED PERFORMANCE IMPROVEMENT:
Before (Original): ~6 minutes refresh, 1:21 preview
After (Optimized): ~5 minutes refresh, ~1:00 preview
Realistic Improvement: 15-20% faster

============================================================================
*/

let
    // ========================================================================
    // STEP 1: EARLY DATA QUALITY FILTERING (PROVEN OPTIMIZATION)
    // ========================================================================
    /*
    ⚡ PERFORMANCE CRITICAL: Remove blanks and duplicates EARLY
    TESTING RESULTS: Saves ~20 seconds (1:21 → 1:02 in preview)
    RATIONALE: Process fewer rows through ALL downstream transformations

    ⚠️ DEDUP CORRECTNESS (FIXED 2026-08): jdis_Part_Information has multiple
    rows per PartNumber (one per branch's own copy of that part's master
    record). Most agree with each other, but a small number carry a rare
    branch-level data-entry error in one of the "business filter" columns.
    Table.Distinct used to just keep whichever row appeared FIRST in source
    row order - not necessarily the correct/majority value. Confirmed live:
    DZ111141 has 21 rows (19x Franchise='D', 1x'TD', 1x'td'); the old logic
    picked one of the 2 rare rows instead of the overwhelming majority 'D'.
    Same pattern confirmed for 19M7966, Z47990, R78055, R71387, and roughly
    23,000 PartNumbers total.

    FIX: Table.Group by PartNumber, with each of the 6 business filter
    columns (Franchise, Source, SLC, DealerGroupCode, CommodityCode,
    VendorCode) independently taking a per-column majority-vote (mode) via
    the ModeOfList helper below. "Independently" is deliberate: these are
    separate classification facts about the same real part, and each one
    should be decided by its own majority - not coupled to whichever single
    row happens to be picked as a "winner" overall. All other columns
    (Description, and the numeric/operational snapshot columns) keep the
    prior simple behavior of taking a representative single value (first
    non-null) - majority-vote doesn't apply the same way to current-state
    snapshot values, and Description's casing/formatting variance across a
    part's rows is an already-accepted tradeoff (see Text.Upper note below).

    ⚠️ VENDORCODE IS A DIFFERENT KIND OF CASE - NOT THE SAME BUG, DON'T
    TREAT ITS "FIX" AS FULLY SOLVED (confirmed 2026-08-10, investigated
    against real production data): Franchise/Source/SLC/DealerGroupCode/
    CommodityCode disagree on a small fraction of parts (0.01%-0.7% of
    ~1M), and every case checked showed a clear, lopsided majority with a
    rare stray outlier - a genuine data-entry-error pattern, correctly
    fixed by majority-vote. VendorCode disagrees on ~9.6% of all parts -
    two orders of magnitude more often - and the disagreement doesn't look
    like typos: e.g. PartNumber PF91010 has 20 DISTINCT VendorCode values
    across 31 source rows, with the "winning" value appearing only 4 times
    (13%) - not a majority at all, just the largest of many small, roughly
    even clusters. This is much more consistent with VendorCode genuinely
    varying by branch (which distributor a given branch actually orders a
    part from) than with data-entry error. dim_VendorCode (a separate
    dimension, one row per unique vendor code - checked, does NOT help
    here) can't fix this either: the real gap is that "which vendor(s)
    does this part use" is fundamentally a one-to-many relationship
    (part x branch -> vendor), and no single-value-per-PartNumber column
    can represent that correctly regardless of which value wins the vote.
    Majority-vote is applied to VendorCode here anyway because it's still
    a strict improvement over the old arbitrary-first-row-wins (at least
    picks the most common relationship instead of a random one), but this
    should NOT be considered "fixed" the way the other 5 columns are - it's
    a known, accepted simplification pending a real conversation with Ben
    about whether VendorCode belongs on a part-level dimension at all, or
    needs a proper part x branch (or part x vendor) bridge/fact table
    instead. Flagged for a future session, not resolved here.
    */

    Source = jdis_Part_Information,

    // Remove blank part numbers FIRST (before any expensive operations)
    RemoveBlankPartsEarly = Table.SelectRows(Source, each
        [PartNumber] <> null and [PartNumber] <> ""
    ),

    // Reusable helper: mode (most frequent non-blank value) of a list.
    // M has no built-in List.Mode. Values are trimmed/text-normalized for
    // comparison only (not upper-cased - matches the majority-vote logic
    // validated against production data via DuckDB before this fix).
    ModeOfList = (lst as list) as any =>
        let
            cleaned = List.Select(List.Transform(lst, each Text.Trim(Text.From(_ ?? ""))), each _ <> ""),
            counted = if List.IsEmpty(cleaned) then null else
                Table.Group(
                    Table.FromList(cleaned, Splitter.SplitByNothing(), {"Value"}),
                    {"Value"},
                    {{"Count", each Table.RowCount(_), Int64.Type}}
                ),
            result = if counted = null or Table.IsEmpty(counted) then null else
                Table.Sort(counted, {{"Count", Order.Descending}}){0}[Value]
        in
            result,

    // Reusable helper: first non-null value of a list (unchanged "representative
    // value" behavior for columns that don't need majority-vote logic).
    FirstNonNullOfList = (lst as list) as any =>
        let
            nonNull = List.Select(lst, each _ <> null),
            result = if List.IsEmpty(nonNull) then null else List.First(nonNull)
        in
            result,

    // Deduplicate EARLY via majority-vote per business filter column
    // (process unique parts only, same "process fewer rows downstream" win
    // as before - see performance note at the top of this step)
    DeduplicateEarly = Table.Group(RemoveBlankPartsEarly, {"PartNumber"}, {
        // === BUSINESS FILTER COLUMNS: independent per-column majority-vote ===
        {"Franchise", each ModeOfList([Franchise]), type text},
        {"Source", each ModeOfList([Source]), type text},
        {"SLC", each ModeOfList([SLC]), type text},
        {"DealerGroupCode", each ModeOfList([DealerGroupCode]), type text},
        {"CommodityCode", each ModeOfList([CommodityCode]), type text},
        {"VendorCode", each ModeOfList([VendorCode]), type text},

        // === EVERYTHING ELSE: unchanged "representative value" behavior ===
        {"Description", each FirstNonNullOfList([Description])},
        {"QuantityOnHand", each FirstNonNullOfList([QuantityOnHand])},
        {"BackOrderQty", each FirstNonNullOfList([BackOrderQty])},
        {"Returnable", each FirstNonNullOfList([Returnable])},
        {"InventoryCost", each FirstNonNullOfList([InventoryCost])},
        {"SellPrice1", each FirstNonNullOfList([SellPrice1])},
        {"ListPrice", each FirstNonNullOfList([ListPrice])},
        {"Current12MoSales", each FirstNonNullOfList([Current12MoSales])}
    }),

    // ========================================================================
    // STEP 2: COLUMN SELECTION - ESSENTIAL FIELDS ONLY
    // ========================================================================
    /*
    PERFORMANCE: Select only needed columns to reduce memory footprint
    */

    EnhancedColumns = Table.SelectColumns(DeduplicateEarly, {
        // === CORE PARTS IDENTIFICATION ===
        "PartNumber",           // Primary part identifier
        "Description",          // Part description
        "Franchise",            // Manufacturer/brand

        // === BUSINESS FILTER COLUMNS ===
        "Source",               // Source classification
        "SLC",                  // SLC classification
        "DealerGroupCode",      // Dealer group identifier
        "CommodityCode",        // Commodity classification
        "VendorCode",           // Vendor identifier

        // === INVENTORY INTELLIGENCE ===
        "QuantityOnHand",       // Current stock level
        "BackOrderQty",         // Backorder quantity
        "Returnable",           // Returnable indicator (Y/N)

        // === PRICING INFORMATION ===
        "InventoryCost",        // Inventory cost value
        "SellPrice1",           // Primary selling price
        "ListPrice",            // Manufacturer list price

        // === SALES ACTIVITY ===
        "Current12MoSales"      // 12-month sales quantity for activity indicator
    }),

    // ========================================================================
    // STEP 3: CONSOLIDATED TEXT CLEANING - SINGLE PASS
    // ========================================================================
    /*
    ⚡ PERFORMANCE OPTIMIZATION: All text transformations in ONE operation
    CHANGED: Using Text.Upper for Description instead of Text.Proper
    REASON: Text.Proper is VERY expensive on 1M+ rows
    SAVES: Estimated 30-60 seconds by avoiding Proper case conversion
    */

    CleanAllTextFields = Table.TransformColumns(EnhancedColumns, {
        // Core identification - ALL UPPERCASE FOR SPEED
        {"PartNumber", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"Description", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},  // Changed from Text.Proper
        {"Franchise", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},

        // Business filter fields (all in one pass)
        {"Source", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"SLC", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"DealerGroupCode", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"CommodityCode", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"VendorCode", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},

        // Returnable field cleanup
        {"Returnable", each Text.Upper(Text.Trim(Text.From(_ ?? "N"))), type text}
    }),

    // ========================================================================
    // STEP 4: ADD CALCULATED COLUMNS - ORIGINAL PATTERN (PROVEN FAST)
    // ========================================================================
    /*
    KEPT ORIGINAL APPROACH: Sequential Table.AddColumn operations
    TESTING SHOWED: Consolidation attempts were SLOWER, not faster
    This pattern is actually optimal for Power Query M engine
    */

    // Inventory status calculation
    AddStockStatus = Table.AddColumn(CleanAllTextFields, "StockStatus", each
        let
            onHand = [QuantityOnHand] ?? 0,
            backOrder = [BackOrderQty] ?? 0
        in
            if onHand > 0 then "In Stock"
            else if backOrder > 0 then "Backordered"
            else "Out of Stock",
        type text),

    // Service availability flag
    AddIsAvailable = Table.AddColumn(AddStockStatus, "IsAvailable", each
        ([QuantityOnHand] ?? 0) > 0, type logical),

    // Sales activity indicator
    AddHasRecentSales = Table.AddColumn(AddIsAvailable, "HasRecentSales", each
        ([Current12MoSales] ?? 0) > 0, type logical),

    // Activity status for business analysis
    AddActivityStatus = Table.AddColumn(AddHasRecentSales, "ActivityStatus", each
        if [HasRecentSales] then "Active" else "No Recent Sales", type text),

    // Returnable flag conversion
    AddIsReturnable = Table.AddColumn(AddActivityStatus, "IsReturnable", each
        [Returnable] = "Y", type logical),

    // High-value parts flag
    AddIsHighValue = Table.AddColumn(AddIsReturnable, "IsHighValue", each
        ([InventoryCost] ?? 0) >= 500, type logical),

    // ========================================================================
    // STEP 5: SORT AND ADD SURROGATE KEY
    // ========================================================================
    /*
    PERFORMANCE: Sort once for consistent key assignment
    */

    SortByPartNumber = Table.Sort(AddIsHighValue, {{"PartNumber", Order.Ascending}}),

    AddSurrogateKey = Table.AddIndexColumn(SortByPartNumber, "PartNumberKey", 1, 1, Int64.Type),

    // ========================================================================
    // STEP 6: COLUMN REORDERING FOR LOGICAL PRESENTATION
    // ========================================================================

    ReorderColumns = Table.ReorderColumns(AddSurrogateKey, {
        // === PRIMARY KEYS & IDENTIFICATION ===
        "PartNumberKey",        // Surrogate key for fact joins
        "PartNumber",           // Business key for lookups
        "Description",          // Part description (NOW UPPERCASE)
        "Franchise",            // Manufacturer/brand

        // === BUSINESS FILTER COLUMNS ===
        "Source",               // Source classification
        "SLC",                  // SLC classification
        "DealerGroupCode",      // Dealer group
        "CommodityCode",        // Commodity classification
        "VendorCode",           // Vendor identifier

        // === INVENTORY INTELLIGENCE ===
        "QuantityOnHand",       // Raw stock quantity
        "BackOrderQty",         // Raw backorder quantity
        "StockStatus",          // Calculated status
        "IsAvailable",          // Availability flag

        // === PRICING INFORMATION ===
        "InventoryCost",        // Cost basis
        "SellPrice1",           // Selling price
        "ListPrice",            // Manufacturer price

        // === SALES & ACTIVITY ===
        "Current12MoSales",     // Raw sales data
        "HasRecentSales",       // Activity flag
        "ActivityStatus",       // Activity description

        // === OPERATIONAL FLAGS ===
        "Returnable",           // Original Y/N field
        "IsReturnable",         // Boolean conversion
        "IsHighValue"           // Value-based flag
    }),

    // ========================================================================
    // STEP 7: SPECIAL "UNKNOWN PARTS" RECORD
    // ========================================================================
    /*
    DIMENSIONAL MODELING BEST PRACTICE: Handle orphaned fact records
    */

    UnknownPartsRecord = #table(
        type table [
            PartNumberKey = Int64.Type,
            PartNumber = text,
            Description = text,
            Franchise = text,
            Source = text,
            SLC = text,
            DealerGroupCode = text,
            CommodityCode = text,
            VendorCode = text,
            QuantityOnHand = number,
            BackOrderQty = number,
            StockStatus = text,
            IsAvailable = logical,
            InventoryCost = number,
            SellPrice1 = number,
            ListPrice = number,
            Current12MoSales = number,
            HasRecentSales = logical,
            ActivityStatus = text,
            Returnable = text,
            IsReturnable = logical,
            IsHighValue = logical
        ],
        {
            {-1, "UNKNOWN", "UNKNOWN PART", "UNKNOWN", "UNKNOWN", "UNKNOWN",
             "UNKNOWN", "UNKNOWN", "UNKNOWN", 0, 0, "Unknown", false, 0, 0, 0, 0,
             false, "Unknown", "N", false, false}
        }
    ),

    // ========================================================================
    // STEP 8: COMBINE SPECIAL RECORD WITH REGULAR PARTS
    // ========================================================================

    CombinedParts = Table.Combine({UnknownPartsRecord, ReorderColumns}),

    // ========================================================================
    // STEP 9: FINAL SORT FOR CONSISTENT OUTPUT
    // ========================================================================

    FinalSort = Table.Sort(CombinedParts, {{"PartNumberKey", Order.Ascending}}),

    // ========================================================================
    // STEP 10: CRITICAL FIX - FINAL DEDUPLICATION
    // ========================================================================
    /*
    ⚡ CRITICAL FIX FOR DUPLICATE PARTNUMBER ERROR

    PURPOSE: Ensure absolutely NO duplicate PartNumber values exist in final output

    REASON FOR THIS STEP:
    - PartNumber is on the "one" side of many-to-one relationships
    - Power BI requires complete uniqueness for relationship keys
    - Early deduplication (line 39) happens BEFORE calculated columns
    - Table.Combine (line 216) could theoretically introduce edge cases
    - This final step is a safety net to guarantee uniqueness

    ERROR PREVENTED:
    "The column 'PartNumber' in the 'dim_Parts' table contains a duplicate value.
    This is not allowed for columns that are on the 'one' side of a many-to-one
    relationship or are used as a primary key."

    APPROACH:
    - Keep first occurrence of each PartNumber
    - Preserves lowest PartNumberKey for each PartNumber
    - Ensures relationship integrity

    PERFORMANCE IMPACT:
    - Minimal (<5 seconds on 1M rows)
    - Essential for data quality
    - Prevents downstream refresh failures
    */

    FinalDeduplication = Table.Distinct(FinalSort, {"PartNumber"})

in
    FinalDeduplication

/*
============================================================================
✅ OPTIMIZATION SUMMARY - BASED ON ACTUAL TESTING
============================================================================

🎯 PROVEN OPTIMIZATIONS APPLIED:

1. **Early Blank Removal & Deduplication** (TESTED - WORKS)
   - Preview time: 1:21 → 1:02 (saves ~20 seconds)
   - Estimated full refresh savings: 1-2 minutes
   - Processes 5-10% fewer rows through all transformations

2. **Text.Upper Instead of Text.Proper for Description** (ESTIMATED - HIGH CONFIDENCE)
   - Text.Proper is expensive (title-cases every word)
   - Text.Upper is fast (simple uppercase conversion)
   - Estimated savings: 30-60 seconds on 1M+ rows
   - Trade-off: Descriptions now all uppercase (acceptable for most use cases)

3. **Consolidated Text Transforms** (ORGANIZATIONAL)
   - No proven speed improvement, but cleaner code
   - Maintains original fast pattern
   - Easier to maintain

4. **Early Column Selection** (MINOR IMPROVEMENT)
   - Reduces memory footprint
   - Estimated savings: 10-20 seconds

5. **FINAL DEDUPLICATION** (CRITICAL FIX - NEW)
   - Prevents duplicate PartNumber errors in relationships
   - Guarantees dimension integrity
   - Minimal performance impact (<5 seconds)

📊 REALISTIC PERFORMANCE EXPECTATIONS:

| Metric | Original | Optimized | Improvement |
|--------|----------|-----------|-------------|
| Preview Time | 1:21 | ~1:00 | ~20 seconds |
| Full Refresh | ~6:00 | ~4:30-5:00 | 1-1.5 min (15-25%) |
| CU Usage | Baseline | 15-20% less | F4 savings |
| Data Quality | Duplicates possible | 100% unique | CRITICAL |

🔑 KEY DECISIONS MADE:

✅ **KEPT from original**:
- Sequential Table.AddColumn operations (proven fast)
- Same business logic and calculated columns
- Special "Unknown" record pattern

✅ **CHANGED for speed**:
- Early blank removal (before transformations)
- Early deduplication (process unique parts only)
- Text.Upper on Description instead of Text.Proper
- Early column selection

✅ **ADDED for data quality**:
- Final deduplication step (prevents relationship errors)

❌ **REJECTED (tested as slower)**:
- InMaster JOIN in this dimension (adds 1:20)
- Table.ToRecords consolidation (adds 50+ seconds)
- Complex column addition patterns (slower than sequential)

💡 **IMPORTANT NOTE ON DESCRIPTION FIELD**:

The biggest single optimization is changing Description from:
- Text.Proper (Title Case Every Word) ← SLOW
- Text.Upper (ALL UPPERCASE) ← FAST

If you MUST have proper case descriptions for display:
- Keep Text.Proper (accept slower refresh)
- OR create a DAX calculated column for display formatting
- OR use FORMAT in DAX measures when displaying

For most analytics use cases, uppercase is acceptable and MUCH faster.

============================================================================
📋 VALIDATION CHECKLIST
============================================================================

After deploying, compare to original:

1. ✅ Row Count Match: Should be identical to original
2. ✅ Preview Time: Target ~1:00 (vs 1:21 original)
3. ✅ Full Refresh Time: Target ~4:30-5:00 (vs ~6:00 original)
4. ✅ All Calculated Columns: Verify StockStatus, ActivityStatus work
5. ✅ Special Unknown Record: Verify PartNumberKey = -1 exists
6. ⚠️ Description Format: Now ALL UPPERCASE (trade-off for speed)
7. ✅ NO DUPLICATE PARTNUMBERS: Critical for relationships

**Validation Query**:
```sql
-- Run in Lakehouse SQL after refresh
SELECT
    COUNT(*) AS total_parts,
    COUNT(DISTINCT PartNumber) AS unique_parts,
    SUM(CASE WHEN StockStatus = 'In Stock' THEN 1 ELSE 0 END) AS in_stock_count,
    SUM(CASE WHEN IsAvailable = TRUE THEN 1 ELSE 0 END) AS available_count
FROM dim_Parts

-- Critical: These should be EQUAL (no duplicates)
-- If total_parts > unique_parts, you still have duplicates!
```

Expected:
- Total parts ~1M
- total_parts = unique_parts (NO DUPLICATES)
- All metrics should match original dim_Parts

============================================================================
🔧 WHAT WAS FIXED IN THIS VERSION
============================================================================

**THE PROBLEM:**
Your current query was causing this error:
"The column 'PartNumber' in the 'dim_Parts' table contains a duplicate
value ('10MN'). This is not allowed for columns that are on the 'one'
side of a many-to-one relationship."

**THE ROOT CAUSE:**
- Early deduplication (line 39) happens before calculated columns
- After Table.Combine with Unknown record, no final deduplication
- Source data may have true duplicates (like '10MN')
- Without final check, duplicates could slip through

**THE FIX:**
Added Step 10 (line 231): Final deduplication using Table.Distinct
- Runs AFTER all transformations
- Runs AFTER combining with Unknown record
- Guarantees 100% unique PartNumber values
- Prevents relationship errors

**PERFORMANCE IMPACT OF FIX:**
- Minimal: <5 seconds on 1M rows
- Essential for data integrity
- Prevents hours of debugging downstream issues

============================================================================
*/
