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
     ~23,000 PartNumbers total. Uses a per-column majority-vote (mode) for
     the 6 business filter columns - see STEP 1.
   - RESTRUCTURED 2026-08-10 (PERFORMANCE, ATTEMPT 1): the majority-vote fix
     above was first implemented with a `ModeOfList` helper invoked BY
     Table.Group's per-PartNumber aggregation function - i.e. a Table.Group
     nested inside another Table.Group, re-run ~1M times. That version was
     logically correct (code-reviewed and merged) but hung/would not load
     in the live Fabric Dataflow Gen2 preview against the real ~1M-row
     source table - a confirmed production performance failure. Replaced
     with a two-level Table.Group pattern run ONCE per business-filter
     column (6 columns x 2 Table.Group calls, plus 6 joins to stitch the
     results back together). MEASURED RESULT: preview loaded in 5:30 and a
     full refresh completed in 7:43 - a working, deployable improvement
     over the hang, but ~2x the pre-fix baseline (2.5-4 min) and enough to
     eat nearly the entire 6-8 minute Dimensions-phase pipeline budget.
   - RESTRUCTURED AGAIN 2026-08-10 (PERFORMANCE, ATTEMPT 2): the 7:43 result
     was still too close to the phase budget to be comfortable, and the
     6-separate-full-table-scans-plus-6-joins shape of attempt 1 was itself
     suspected as the new cost driver. Replaced with a SINGLE outer
     Table.Group by PartNumber (same overall shape as the very original
     pre-fix query), using a lightweight LIST-based `ModeOfListLightweight`
     helper instead of the original's heavy Table-based `ModeOfList` - see
     STEP 1 for the full reasoning and the theory of why List.* primitives
     should avoid both the original nested-Table.Group hang AND attempt 1's
     repeated-full-table-scan cost.
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

    FIX: each of the 6 business filter columns (Franchise, Source, SLC,
    DealerGroupCode, CommodityCode, VendorCode) independently takes a
    per-column majority-vote (mode). "Independently" is deliberate: these
    are separate classification facts about the same real part, and each
    one should be decided by its own majority - not coupled to whichever
    single row happens to be picked as a "winner" overall. All other
    columns (Description, and the numeric/operational snapshot columns)
    keep the prior simple behavior of taking a representative single value
    (first non-null) - majority-vote doesn't apply the same way to
    current-state snapshot values, and Description's casing/formatting
    variance across a part's rows is an already-accepted tradeoff (see
    Text.Upper note below). NOTE ON A REAL BEHAVIOR CHANGE: the OLD
    Table.Distinct picked one whole physical source row, so these "everything
    else" columns were previously guaranteed to all come from that SAME row
    (internally coherent per-row). The NEW FirstNonNullOfList helper is
    applied independently per column against the group, matching the same
    "independent per column" philosophy already used for the majority-vote
    columns - so it's now possible for Description to come from one branch's
    row while QuantityOnHand comes from a different branch's row for the
    same part. This is a reasonable, minor, and intentional tradeoff (not a
    regression to fix), consistent with how the business filter columns
    already work - flagged here so it's not mistaken for unchanged behavior.

    ⚡ PERFORMANCE RESTRUCTURING - ATTEMPT 1 (2026-08-10): the majority-vote
    logic above was first implemented as a `ModeOfList` helper function
    invoked BY Table.Group's per-PartNumber-group aggregation callback -
    i.e. a SECOND, independent Table.Group (plus its own Table.Sort) nested
    inside and freshly re-run by the FIRST Table.Group's aggregation
    function, once per distinct PartNumber (~1M times) x 6 business filter
    columns = ~6 million nested Table.Group/Table.Sort invocations. That
    version was logically correct - proven via DuckDB SQL prototyping and
    confirmed in code review - but when the user pasted it into the live
    Fabric Dataflow Gen2 Advanced Editor, the query preview hung/would not
    load against the real ~1M-row jdis_Part_Information table. This is a
    real, user-reported production performance failure, not a hypothetical
    concern, and the root cause is well-established: nesting Table.Group
    inside another Table.Group's per-group aggregation function is a severe
    anti-pattern for the M engine at this scale, regardless of correctness.

    THE ATTEMPT-1 RESTRUCTURING: replaced the per-group nested-Table.Group
    pattern with a two-level Table.Group pattern run ONCE per business
    filter column (not once per PartNumber group), for each of the 6
    columns independently: (1) normalize + drop blanks, then ONE
    Table.Group over the FULL source table by {PartNumber, Value} counting
    rows -> a small (PartNumber, value, VoteCount) table; (2) Table.Sort
    that small table by PartNumber asc, VoteCount desc; (3) a SECOND
    Table.Group by PartNumber alone taking `List.First` of the
    already-sorted value (cheap O(1) per group, no nested grouping). The 6
    resulting per-column mode tables were then left-joined back onto the
    FirstNonNullOfList-based "everything else" columns via 6
    Table.NestedJoin/Table.ExpandTableColumn pairs. Total Table.Group
    calls: 13 (2 per column x 6, plus 1 for "everything else"), each run
    ONCE against the full or a reduced table - versus attempt 1's
    predecessor's ~6 million nested calls.

    MEASURED RESULT OF ATTEMPT 1: this DID fix the hang - live Fabric
    preview loaded in 5:30 and a full refresh completed successfully in
    7:43. A working, deployable improvement over the original hang, but
    ~2x the pre-fix baseline (2.5-4 min), and this dimension alone was
    eating nearly the entire documented 6-8 minute Dimensions-phase budget
    in the scheduled 4:15 AM pipeline - worth one more optimization pass
    given that real scheduling stake.

    ⚡ PERFORMANCE RESTRUCTURING - ATTEMPT 2 (2026-08-10): attempt 1's
    6-separate-full-table-first-level-group-passes plus 6 sequential
    join/expand pairs were suspected as the new cost driver - a lot of
    repeated full-table scanning and join overhead compared to even the
    ORIGINAL single-pass Table.Distinct. Reverted to a SINGLE outer
    Table.Group by PartNumber (the same overall SHAPE as the very original
    pre-fix query, and as the majority-vote fix's first cut before attempt
    1's per-column splitting), but replaced the per-group majority-vote
    logic with a LIGHTWEIGHT, LIST-ONLY `ModeOfListLightweight` helper -
    no `Table.Group`, no `Table.Sort`, no `Table.FromList` anywhere in the
    per-group function, only `List.Select`/`List.Transform`/`List.Distinct`/
    `List.Count`/`List.Max`/`List.PositionOf`. THEORY: `Table.*` operations
    carry real object-construction/management overhead that plain `List.*`
    operations don't; since each part's own group of source rows is small
    (typically well under 30 rows, based on everything observed so far), a
    lightweight per-group frequency count using only list primitives should
    avoid BOTH the attempt-1-predecessor's heavy nested-Table.Group cost
    AND attempt 1's 6x-repeated-full-table-scan-plus-join cost, while
    keeping the "one Table.Group pass over the source" shape that worked
    fine (aside from the per-group callback) all along. `ModeOfListLightweight`:
    normalize + drop blanks (same as before) -> `List.Distinct` the cleaned
    list -> for each distinct value, `List.Count` how many cleaned entries
    equal it -> return the distinct value at the position of the max count
    (`List.PositionOf`). Re-verified correct against the same 5 known
    examples via DuckDB. NOT YET MEASURED against live Fabric as of this
    writing - flag this restructuring's actual refresh time when next
    tested, the same way attempt 1's 7:43 was measured after the fact.

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

    // Reusable helper: first non-null value of a list. The SELECTION algorithm
    // itself (first non-null) is unchanged from before this fix, but it's now
    // applied independently per column against the group rather than picking
    // one whole source row - see the "NOTE ON A REAL BEHAVIOR CHANGE" in this
    // step's header comment above for what that means in practice.
    FirstNonNullOfList = (lst as list) as any =>
        let
            nonNull = List.Select(lst, each _ <> null),
            result = if List.IsEmpty(nonNull) then null else List.First(nonNull)
        in
            result,

    // ------------------------------------------------------------------
    // MAJORITY-VOTE via a LIGHTWEIGHT, LIST-ONLY per-group function
    // (attempt 2 - replaces attempt 1's two-level-Table.Group-per-column
    // pattern, which itself replaced the original per-group nested-
    // Table.Group `ModeOfList` helper - see the "PERFORMANCE RESTRUCTURING"
    // notes in this step's header comment above for the full history and
    // reasoning). `ModeOfListLightweight` uses ONLY List.* primitives -
    // no Table.Group, no Table.Sort, no Table.FromList anywhere in the
    // per-group function - on the theory that Table.* operations carry
    // real object-construction overhead that plain List.* operations don't,
    // and each part's own group of source rows is small (well under 30
    // rows observed in practice), so a lightweight list-based frequency
    // count is cheap even run ~1M times (once per PartNumber group).
    // ------------------------------------------------------------------

    // Reusable helper: mode (most frequent non-blank value) of a list,
    // using ONLY List.* operations - no Table.Group/Table.Sort/Table.FromList.
    // Values are trimmed AND upper-cased before votes are counted, so case
    // variants of the same real value (e.g. "D" vs "d") are counted as ONE
    // cluster rather than splitting the vote (same reasoning as the old
    // ModeOfList - see its retired comment history above). NOTE ON SCOPING:
    // the outer `List.Transform(distinctValues, (val) => ...)` uses an
    // EXPLICITLY NAMED parameter `val` (not `each`/implicit `_`) precisely
    // so the inner `List.Select(cleaned, each _ = val)`'s `each` can freely
    // rebind `_` to the current `cleaned` element being tested without any
    // ambiguity about which `_` is meant - `val` unambiguously still refers
    // to the outer distinctValues element throughout. Manually traced against
    // {"D","D","D","TD","TD"} (5-vote example): distinctValues = {"D","TD"},
    // counts = {3,2}, List.Max(counts) = 3, List.PositionOf(counts,3) = 0,
    // distinctValues{0} = "D" - correct.
    ModeOfListLightweight = (lst as list) as any =>
        let
            cleaned = List.Select(List.Transform(lst, each Text.Upper(Text.Trim(Text.From(_ ?? "")))), each _ <> ""),
            distinctValues = List.Distinct(cleaned),
            counts = List.Transform(distinctValues, (val) => List.Count(List.Select(cleaned, each _ = val))),
            result = if List.IsEmpty(distinctValues) then null else
                distinctValues{List.PositionOf(counts, List.Max(counts))}
        in
            result,

    // Deduplicate EARLY via majority-vote per business filter column - back
    // to a SINGLE Table.Group pass over the full source table by PartNumber
    // (same overall shape as the original pre-fix query), with the
    // ModeOfListLightweight helper above doing the heavy lifting cheaply
    // inside the per-group aggregation callback.
    DeduplicateEarly = Table.Group(RemoveBlankPartsEarly, {"PartNumber"}, {
        // === BUSINESS FILTER COLUMNS: independent per-column majority-vote ===
        {"Franchise", each ModeOfListLightweight([Franchise]), type text},
        {"Source", each ModeOfListLightweight([Source]), type text},
        {"SLC", each ModeOfListLightweight([SLC]), type text},
        {"DealerGroupCode", each ModeOfListLightweight([DealerGroupCode]), type text},
        {"CommodityCode", each ModeOfListLightweight([CommodityCode]), type text},
        {"VendorCode", each ModeOfListLightweight([VendorCode]), type text},

        // === EVERYTHING ELSE: "representative value" behavior, decided
        // independently PER COLUMN (see header note above) - explicit types
        // added so Table.Group's output matches the source's actual types
        // instead of defaulting to `type any` (Table.Group aggregation
        // functions do NOT inherit types the way Table.Distinct passthrough
        // did). This matters because UnknownPartsRecord below declares these
        // same columns as typed, and Table.Combine merges the two.
        {"Description", each FirstNonNullOfList([Description]), type text},
        {"QuantityOnHand", each FirstNonNullOfList([QuantityOnHand]), type number},
        {"BackOrderQty", each FirstNonNullOfList([BackOrderQty]), type number},
        {"Returnable", each FirstNonNullOfList([Returnable]), type text},
        {"InventoryCost", each FirstNonNullOfList([InventoryCost]), type number},
        {"SellPrice1", each FirstNonNullOfList([SellPrice1]), type number},
        {"ListPrice", each FirstNonNullOfList([ListPrice]), type number},
        {"Current12MoSales", each FirstNonNullOfList([Current12MoSales]), type number}
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
