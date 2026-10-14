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
   - RESTRUCTURED 2026-08-10 (PERFORMANCE): the majority-vote fix above
     was first implemented with a `ModeOfList` helper invoked BY
     Table.Group's per-PartNumber aggregation function - i.e. a Table.Group
     nested inside another Table.Group, re-run ~1M times. That version was
     logically correct (code-reviewed and merged) but hung/would not load
     in the live Fabric Dataflow Gen2 preview against the real ~1M-row
     source table - a confirmed production performance failure. Replaced
     with a two-level Table.Group pattern run ONCE per business-filter
     column instead of once per PartNumber group - see STEP 1.
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

    ⚡ PERFORMANCE RESTRUCTURING (2026-08-10): the majority-vote logic above
    was first implemented as a `ModeOfList` helper function invoked BY
    Table.Group's per-PartNumber-group aggregation callback - i.e. a SECOND,
    independent Table.Group (plus its own Table.Sort) nested inside and
    freshly re-run by the FIRST Table.Group's aggregation function, once per
    distinct PartNumber (~1M times) x 6 business filter columns = ~6 million
    nested Table.Group/Table.Sort invocations. That version was logically
    correct - proven via DuckDB SQL prototyping and confirmed in code review
    - but when the user pasted it into the live Fabric Dataflow Gen2
    Advanced Editor, the query preview hung/would not load against the real
    ~1M-row jdis_Part_Information table. This is a real, user-reported
    production performance failure, not a hypothetical concern, and the
    root cause is well-established: nesting Table.Group inside another
    Table.Group's per-group aggregation function is a severe anti-pattern
    for the M engine at this scale, regardless of correctness.

    THE RESTRUCTURING: replaced the per-group nested-Table.Group pattern
    with a two-level Table.Group pattern run ONCE per business filter
    column (not once per PartNumber group), for each of the 6 columns
    independently:
      1) Normalize (trim + upper-case) and drop blanks, then run ONE
         Table.Group over the FULL source table by {PartNumber, Value},
         counting rows in each combination -> a much smaller table: one
         row per distinct (PartNumber, value) pair actually observed, with
         a VoteCount. (`<Column>Votes_Filtered` -> `_Normalized` -> `_Counts`)
      2) Table.Sort that small table by PartNumber ascending, then VoteCount
         descending. (`_Sorted`)
      3) Run a SECOND Table.Group, by PartNumber alone, over that already-
         sorted small table, taking `List.First` of the value column
         (`_Mode`). Because of the sort in step 2, the first row within
         each PartNumber group is guaranteed to be the highest-vote-count
         row, so `List.First` is a cheap O(1) lookup per group with NO
         further sorting or grouping inside the aggregation function -
         unlike the old ModeOfList, which called Table.Group AGAIN inside
         this step.
    The 6 resulting `<Column>_Mode` tables (one row per PartNumber that had
    at least one non-blank value for that column) are then left-joined back
    onto `EverythingElseByPart` (the FirstNonNullOfList-based "everything
    else" columns, computed with a single ordinary Table.Group over the
    full table - unchanged, since that was never the performance problem)
    to reassemble the new `DeduplicateEarly`.
    Total Table.Group calls in the new version: 13 (2 per business filter
    column x 6, plus 1 for "everything else"), each executed ONCE against
    the full or a reduced table - versus the old version's single outer
    Table.Group call that itself triggered ~6 million further nested
    Table.Group/Table.Sort calls from inside ModeOfList.

    MEASURED RESULT: this fixed the hang - live Fabric preview loaded in
    5:30 and a full refresh completed successfully in 7:43. Working and
    deployable, but ~2x the pre-fix baseline (2.5-4 min).

    A SECOND ATTEMPT WAS TRIED AND REJECTED (2026-08-10): on the theory
    that Table.* operations carry object-construction overhead List.*
    doesn't, a variant was tried that reverted to a SINGLE outer
    Table.Group by PartNumber (the original pre-fix shape) with a
    per-group majority-vote function built from ONLY List.* primitives
    (List.Distinct/List.Count/List.Max/List.PositionOf - no Table.Group,
    no Table.Sort anywhere in it). Logically re-verified correct against
    the same 5 known examples via DuckDB, but when pasted into the live
    Fabric Dataflow Gen2, the preview did not load at all and had to be
    cancelled - WORSE than this (13-Table.Group, no-per-group-function)
    version, not better. CONCLUSION: the deciding factor isn't Table.* vs
    List.* primitive cost - it's whether ANY custom multi-step function
    gets invoked once per group at ~1M-group scale at all. This version
    avoids that entirely (every Table.Group here uses only built-in
    aggregations - Table.RowCount, List.First on an already-sorted table -
    never a custom function re-evaluated per group), which is almost
    certainly why it's the one that actually works. Do not reintroduce a
    per-group custom function (Table- or List-based) without a real reason
    to believe this conclusion no longer holds - two independent attempts
    at that pattern have now both failed or underperformed relative to
    this one.

    ⚡ SCOPE REDUCTION (2026-08-10/11): the working attempt-1 architecture
    (7:43-8:00 measured refresh, twice) is still ~2x the pre-fix baseline
    (2.5-4 min) and a real, ongoing CU-consumption concern on F4 capacity -
    this dimension alone was eating nearly the entire documented 6-8 minute
    Dimensions-phase pipeline budget every single day. Given the real cost
    of continued architecture experimentation (see the two attempts above)
    versus more pressing priorities, majority-vote was deliberately scoped
    DOWN from 6 business filter columns to 4, dropping CommodityCode and
    VendorCode back to the cheap FirstNonNullOfList path:
      - CommodityCode: PROVEN zero real-world benefit. The full-data
        comparison (buggy Table.Distinct vs. correct majority-vote) found
        EXACTLY 0 PartNumbers where CommodityCode's value would differ.
        Majority-voting it was pure wasted computation for zero
        correctness gain - an unambiguous, risk-free thing to stop doing.
      - VendorCode: NOT proven harmless (~95,699 of ~100,362 total changed
        PartNumbers across all 6 columns came from VendorCode alone - by
        far the single largest share) - but this is deliberately deferred,
        not ignored. Two independent reasons: (1) it's almost certainly
        the single most expensive column to majority-vote, given its far
        higher per-part distinct-value cardinality than the other 5
        columns (e.g. PartNumber PF91010 has 20 distinct VendorCode values
        across 31 source rows - see the VENDORCODE warning further below);
        (2) majority-vote was already known to be an incomplete stopgap
        for VendorCode even when it WAS being computed - see that same
        warning for why "which vendor(s) does this part use" cannot be
        correctly represented by any single value on a one-row-per-part
        dimension at all, regardless of which value wins a vote. Paying
        peak computation cost for a result already known to need a real
        redesign was judged not worth it tonight.
    Franchise (2,939 changed parts), Source (1,070), SLC (128), and
    DealerGroupCode (6,526) all keep majority-vote - each has a real,
    provable disagreement count AND a clean semantic fit (each is a
    should-be-single-valued classification fact about the part, same
    reasoning that made the original fix correct for these columns in the
    first place).

    MEASURED RESULT OF SCOPE REDUCTION: 8:12 - NOT faster than the 6-column
    version's 7:43/8:00, actually slightly slower. This is a genuinely
    counter-intuitive, disappointing result (dropping 2 of 6 columns'
    worth of Table.Group calls and 2 of 6 joins should have helped) and is
    recorded honestly rather than glossed over. Two honest possibilities,
    neither confirmed: (1) run-to-run variance in live Fabric F4 capacity
    load (other concurrent activity on the same capacity at refresh time)
    dominates over the actual size of this specific optimization, i.e. the
    real signal-to-noise ratio at this scale may be too small for a
    2-of-6-column reduction to show up as a measurable difference; (2) the
    true bottleneck may not be primarily the majority-vote computation
    itself at all - it could be elsewhere in this dataflow (the 4 remaining
    Table.NestedJoin/Table.ExpandTableColumn pairs, or something in STEP
    2-10 downstream, or the base cost of scanning ~1M rows from
    jdis_Part_Information multiple times regardless of what's computed per
    row). NOT investigated further - this was the deliberate stopping
    point for tonight per real time/priority constraints (see the
    "FOR A FUTURE SESSION" note below) - but this result is exactly why
    the recommended next real step is a fundamentally different
    architecture (Fabric Notebook/Spark), not another M-engine tweak. Two
    different M restructurings and a scope reduction have now all failed
    to get meaningfully below ~7:43, which is reasonably strong evidence
    the M engine itself, not any one specific implementation detail within
    it, is the actual limiting factor here.

    📋 FOR A FUTURE SESSION - WHAT TO ACTUALLY LOOK AT:
    The M-engine-only approach has hit its practical limit for tonight
    (2 real architecture attempts, best measured result ~7:43-8:00 vs. a
    2.5-4 min baseline, even after scoping down to 4 of 6 columns). If this
    still isn't fast/cheap enough in practice once you're back in this
    file, the more promising direction is almost certainly NOT another M
    rewrite - it's moving the majority-vote computation OUT of Power Query
    entirely, into a Fabric Notebook (PySpark or Spark SQL) reading
    jdis_Part_Information as a DataFrame. This exact computation (group by
    PartNumber+column, count, window-function-rank, take the top row) is
    precisely what Spark's distributed engine is built for, and is the
    SAME logical operation already proven correct and FAST in DuckDB
    throughout this investigation (see
    projects/jd-price-updates/scripts/investigate_dim_parts_dedup.py and
    investigate_dim_parts_dedup_perf.py for working SQL to translate).
    Concretely: (1) a Notebook computes the per-column majority-vote for
    all 6 columns (including VendorCode, once its architecture question
    with Ben is resolved - see below) and writes the deduplicated result
    to a new intermediate Lakehouse table (e.g. jdis_Part_Information_Deduped);
    (2) this Dataflow Gen2 gets much simpler again - STEP 1 goes back to
    something close to the ORIGINAL Table.Distinct-shaped query, just
    reading from the new pre-deduplicated intermediate table instead of
    jdis_Part_Information directly, since the hard work already happened
    in the Notebook; (3) this needs the Notebook to run BEFORE this
    dataflow in the pipeline (a new dependency to add to the Fabric
    Pipeline, same "Raw -> Dims" ordering constraint that already governs
    everything else in this pipeline). This is real, new work - a new
    pipeline artifact, real testing before trusting it in production - not
    a quick fix, but the architecturally right direction if the M-only
    approach continues to be too expensive.
    SEPARATELY: the VendorCode architecture question (does it even belong
    as a single column on a part-level dimension, or does it need a proper
    part x branch or part x vendor bridge/fact table instead) still needs
    Brian's conversation with Ben - see the VENDORCODE warning below and
    project memory project_dim_parts_vendorcode_limitation.md. Resolve
    that BEFORE deciding whether/how to bring VendorCode back into
    whatever the final majority-vote (or Notebook-based) solution becomes.

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
    // MAJORITY-VOTE via a TWO-LEVEL Table.Group pattern (replaces the old
    // per-group nested-Table.Group `ModeOfList` helper - see the "PERFORMANCE
    // RESTRUCTURING" note in this step's header comment above for why).
    // For each of the 6 business filter columns, independently:
    //   1) normalize (trim + upper, so case variants count as one vote) and
    //      drop blanks, then Table.Group the FULL table ONCE by
    //      {PartNumber, Value} -> a small (PartNumber, value, VoteCount)
    //      table - one row per distinct pair actually observed
    //   2) Table.Sort that small table by PartNumber asc, VoteCount desc
    //   3) Table.Group that already-sorted small table by PartNumber alone,
    //      taking List.First of the value column - guaranteed to be the
    //      highest-vote-count row for that part because of the sort in
    //      step 2, so this is an O(1) List.First per group, NOT another
    //      nested Table.Group call
    // Every Table.Group call below runs exactly ONCE against the full (or a
    // much-reduced) table - there is no custom aggregation function here
    // that itself calls Table.Group per PartNumber group.
    // ------------------------------------------------------------------

    FranchiseVotes_Filtered = Table.SelectColumns(
        Table.SelectRows(RemoveBlankPartsEarly, each [Franchise] <> null and Text.Trim(Text.From([Franchise])) <> ""),
        {"PartNumber", "Franchise"}),
    FranchiseVotes_Normalized = Table.TransformColumns(FranchiseVotes_Filtered, {"Franchise", each Text.Upper(Text.Trim(Text.From(_))), type text}),
    FranchiseVotes_Counts = Table.Group(FranchiseVotes_Normalized, {"PartNumber", "Franchise"}, {{"VoteCount", each Table.RowCount(_), Int64.Type}}),
    FranchiseVotes_Sorted = Table.Sort(FranchiseVotes_Counts, {{"PartNumber", Order.Ascending}, {"VoteCount", Order.Descending}}),
    Franchise_Mode = Table.Group(FranchiseVotes_Sorted, {"PartNumber"}, {{"Franchise", each List.First([Franchise]), type text}}),

    SourceVotes_Filtered = Table.SelectColumns(
        Table.SelectRows(RemoveBlankPartsEarly, each [Source] <> null and Text.Trim(Text.From([Source])) <> ""),
        {"PartNumber", "Source"}),
    SourceVotes_Normalized = Table.TransformColumns(SourceVotes_Filtered, {"Source", each Text.Upper(Text.Trim(Text.From(_))), type text}),
    SourceVotes_Counts = Table.Group(SourceVotes_Normalized, {"PartNumber", "Source"}, {{"VoteCount", each Table.RowCount(_), Int64.Type}}),
    SourceVotes_Sorted = Table.Sort(SourceVotes_Counts, {{"PartNumber", Order.Ascending}, {"VoteCount", Order.Descending}}),
    Source_Mode = Table.Group(SourceVotes_Sorted, {"PartNumber"}, {{"Source", each List.First([Source]), type text}}),

    SLCVotes_Filtered = Table.SelectColumns(
        Table.SelectRows(RemoveBlankPartsEarly, each [SLC] <> null and Text.Trim(Text.From([SLC])) <> ""),
        {"PartNumber", "SLC"}),
    SLCVotes_Normalized = Table.TransformColumns(SLCVotes_Filtered, {"SLC", each Text.Upper(Text.Trim(Text.From(_))), type text}),
    SLCVotes_Counts = Table.Group(SLCVotes_Normalized, {"PartNumber", "SLC"}, {{"VoteCount", each Table.RowCount(_), Int64.Type}}),
    SLCVotes_Sorted = Table.Sort(SLCVotes_Counts, {{"PartNumber", Order.Ascending}, {"VoteCount", Order.Descending}}),
    SLC_Mode = Table.Group(SLCVotes_Sorted, {"PartNumber"}, {{"SLC", each List.First([SLC]), type text}}),

    DealerGroupCodeVotes_Filtered = Table.SelectColumns(
        Table.SelectRows(RemoveBlankPartsEarly, each [DealerGroupCode] <> null and Text.Trim(Text.From([DealerGroupCode])) <> ""),
        {"PartNumber", "DealerGroupCode"}),
    DealerGroupCodeVotes_Normalized = Table.TransformColumns(DealerGroupCodeVotes_Filtered, {"DealerGroupCode", each Text.Upper(Text.Trim(Text.From(_))), type text}),
    DealerGroupCodeVotes_Counts = Table.Group(DealerGroupCodeVotes_Normalized, {"PartNumber", "DealerGroupCode"}, {{"VoteCount", each Table.RowCount(_), Int64.Type}}),
    DealerGroupCodeVotes_Sorted = Table.Sort(DealerGroupCodeVotes_Counts, {{"PartNumber", Order.Ascending}, {"VoteCount", Order.Descending}}),
    DealerGroupCode_Mode = Table.Group(DealerGroupCodeVotes_Sorted, {"PartNumber"}, {{"DealerGroupCode", each List.First([DealerGroupCode]), type text}}),

    // CommodityCode and VendorCode are DELIBERATELY excluded from
    // majority-vote here - see the "SCOPE REDUCTION" note in this step's
    // header comment above. CommodityCode goes back to FirstNonNullOfList
    // (proven zero real-world benefit from majority-voting it - 0 parts
    // changed in the full-data comparison). VendorCode goes back to
    // FirstNonNullOfList too, NOT because it's provably harmless like
    // CommodityCode (it isn't - ~95,699 parts differ), but because it's
    // both the single most expensive column to majority-vote (far higher
    // per-part distinct-value cardinality than the others) AND a column
    // whose "fix" was already known to be an incomplete stopgap pending a
    // real conversation with Ben about part x branch modeling - see the
    // VENDORCODE warning further below in this comment block. No reason to
    // pay peak cost for a result already known to need revisiting.

    // "Everything else" columns (now including CommodityCode and VendorCode)
    // keep the FirstNonNullOfList behavior, computed with a single ordinary
    // Table.Group over the full table by PartNumber - this was never the
    // performance problem (FirstNonNullOfList is a plain O(n) list scan,
    // not a nested Table.Group call). Explicit types added so Table.Group's
    // output matches the source's actual types instead of defaulting to
    // `type any` (Table.Group aggregation functions do NOT inherit types
    // the way Table.Distinct passthrough did). This matters because
    // UnknownPartsRecord below declares these same columns as typed, and
    // Table.Combine merges the two.
    EverythingElseByPart = Table.Group(RemoveBlankPartsEarly, {"PartNumber"}, {
        {"Description", each FirstNonNullOfList([Description]), type text},
        {"CommodityCode", each FirstNonNullOfList([CommodityCode]), type text},
        {"VendorCode", each FirstNonNullOfList([VendorCode]), type text},
        {"QuantityOnHand", each FirstNonNullOfList([QuantityOnHand]), type number},
        {"BackOrderQty", each FirstNonNullOfList([BackOrderQty]), type number},
        {"Returnable", each FirstNonNullOfList([Returnable]), type text},
        {"InventoryCost", each FirstNonNullOfList([InventoryCost]), type number},
        {"SellPrice1", each FirstNonNullOfList([SellPrice1]), type number},
        {"ListPrice", each FirstNonNullOfList([ListPrice]), type number},
        {"Current12MoSales", each FirstNonNullOfList([Current12MoSales]), type number}
    }),

    // Recombine: EverythingElseByPart already has exactly one row per
    // distinct PartNumber (unconditional group, no blank-filtering upstream
    // of it), so it's the base table every business-filter `_Mode` table
    // left-joins onto. A part whose business-filter column is blank on
    // EVERY source row (excluded from that column's Votes_Filtered pipeline
    // above, so it never reaches that column's `_Mode` table) still gets a
    // row here, with that column coming back null via the left outer join -
    // matching the old ModeOfList behavior of returning null for an
    // all-blank list. Only 4 join/expand pairs now (down from 6) - no
    // CommodityCode/VendorCode join, they're already present via
    // EverythingElseByPart above.
    JoinFranchise = Table.NestedJoin(EverythingElseByPart, {"PartNumber"}, Franchise_Mode, {"PartNumber"}, "FranchiseJoin", JoinKind.LeftOuter),
    ExpandFranchise = Table.ExpandTableColumn(JoinFranchise, "FranchiseJoin", {"Franchise"}, {"Franchise"}),

    JoinSource = Table.NestedJoin(ExpandFranchise, {"PartNumber"}, Source_Mode, {"PartNumber"}, "SourceJoin", JoinKind.LeftOuter),
    ExpandSource = Table.ExpandTableColumn(JoinSource, "SourceJoin", {"Source"}, {"Source"}),

    JoinSLC = Table.NestedJoin(ExpandSource, {"PartNumber"}, SLC_Mode, {"PartNumber"}, "SLCJoin", JoinKind.LeftOuter),
    ExpandSLC = Table.ExpandTableColumn(JoinSLC, "SLCJoin", {"SLC"}, {"SLC"}),

    JoinDealerGroupCode = Table.NestedJoin(ExpandSLC, {"PartNumber"}, DealerGroupCode_Mode, {"PartNumber"}, "DealerGroupCodeJoin", JoinKind.LeftOuter),
    ExpandDealerGroupCode = Table.ExpandTableColumn(JoinDealerGroupCode, "DealerGroupCodeJoin", {"DealerGroupCode"}, {"DealerGroupCode"}),

    // Explicit final typing (belt-and-suspenders): Table.NestedJoin /
    // Table.ExpandTableColumn should already carry through the types set on
    // the Franchise_Mode/Source_Mode/etc. Table.Group columns, but this
    // guarantees DeduplicateEarly's output types exactly match what STEP 2
    // (EnhancedColumns) and UnknownPartsRecord below expect - the same
    // reason explicit types were added to the old Table.Group call.
    DeduplicateEarly = Table.TransformColumnTypes(ExpandDealerGroupCode, {
        {"PartNumber", type text},
        {"Franchise", type text},
        {"Source", type text},
        {"SLC", type text},
        {"DealerGroupCode", type text},
        {"CommodityCode", type text},
        {"VendorCode", type text},
        {"Description", type text},
        {"QuantityOnHand", type number},
        {"BackOrderQty", type number},
        {"Returnable", type text},
        {"InventoryCost", type number},
        {"SellPrice1", type number},
        {"ListPrice", type number},
        {"Current12MoSales", type number}
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
