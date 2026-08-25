/*
============================================================================
Query: Fact_PriceUpdate_Enriched
Dataflow: df_Fact_PriceUpdate_Enriched
Location: LH_Master_Data → Dataflows (fact-tables folder, or alongside
other JD price update dataflows -- see Fabric workspace organization)
============================================================================

PURPOSE: Enriched fact table built from Raw_PriceUpdate_History + dim_Parts.
Part of sub-project 3 phase 1 (foundational fact layer) -- see
docs/superpowers/specs/2026-08-10-jd-pricing-fact-tables-design.md. What
specific analysis/KPIs get built on top of this fact is explicitly out of
scope for this query.

REDESIGNED 2026-08-11 (SIMPLICITY + PERFORMANCE): this query originally
collapsed Raw_PriceUpdate_History's branch-level grain down to
PartNumber+EffectiveDate via a Table.Group, computing AffectedBranchCount
and a per-column "first non-null across branches" value for 13 other
fields, plus a HasBranchPriceDisagreement safety-net flag. Live in Fabric,
this took 45+ minutes and had to be cancelled (HasBranchPriceDisagreement
was dropped first as the dominant cost, per PR #31 -- but even after that,
the remaining Table.Group over 5.1M rows / ~1.29M groups still ran 20+
minutes without finishing). The real lesson, once named plainly: this
query was never actually "a lookup" -- it had a genuine large-scale
GROUP BY buried inside it, and Power Query's M engine is a poor fit for
that operation at multi-million-row scale, the same conclusion already
reached independently for dim_Parts.pq the same night (see project memory
project_dim_parts_perf_followup.md). Concrete proof this isn't "Fabric is
just slow": the sibling fact table Fact_JDNationalChangeReport_Enriched
has NO grouping at all (pure join/lookup) and built/refreshed cleanly on
the first try, no drama. REDESIGN: stopped doing the collapse in M
entirely. This query now keeps Raw_PriceUpdate_History's own grain
unchanged (one row per Branch + PartNumber + EffectiveDate +
SourceFileName, same as the raw table) and does nothing but normalize
PartNumber and left-join dim_Parts -- genuinely just "get a part number,
look up additional columns," matching the raw table's own row count and
performance characteristics (fast). AffectedBranchCount is NOT computed
here anymore -- see that section below for where it goes instead
(a DAX measure, not a pre-computed ETL column, which is also more
correct, not just faster -- see that section for why).

GRAIN: Unchanged from Raw_PriceUpdate_History -- one row per
Branch + PartNumber + EffectiveDate + SourceFileName. This fact does NOT
collapse across branches (see REDESIGNED note above for why that was
tried and reverted).

SOURCE: Two Lakehouse table connectors within this same dataflow (via
"Get Data > Lakehouse > Tables", which names the resulting query after the
table itself, unlike the Files connector sub-projects 1/2 use -- no
placeholder renaming needed here): `Raw_PriceUpdate_History` and
`dim_Parts`.

REFRESH: Daily, full Replace (not Append) -- this is a derived/enriched
rebuild of the ENTIRE source table on every refresh, not new-rows-only.
Scheduled after both Raw_PriceUpdate_History (harvested daily 02:00) and
dim_Parts have refreshed. See Fabric Pipeline setup in the implementation
plan's Task 10. Expected to be FAST now (a plain left-outer join over
5.1M rows, no grouping) -- should behave similarly to the sibling
Fact_JDNationalChangeReport_Enriched, not to dim_Parts' grouping-heavy
refresh time.

PARTNUMBER NORMALIZATION: dim_Parts normalizes PartNumber with
Text.Upper(Text.Trim(...)); Raw_PriceUpdate_History does neither. A naive
join on PartNumber as-is would silently under-match real, carried parts
purely from casing/whitespace differences. This query normalizes
PartNumber to dim_Parts' convention before joining -- the underlying raw
table is not touched.

DROPPED COLUMNS (present in Raw_PriceUpdate_History, not carried into this
fact -- unrelated to the grain redesign above, same rationale as before):
SourceFileBranch, BinLocation, OnHandQty, SourceFileName, SourceFileDate,
BranchMismatchFlag, PartDescription (raw), Franchise (raw). Branch/file-
level traceability detail remains available in Raw_PriceUpdate_History
itself if ever needed. Branch ITSELF is now KEPT (unlike the prior
collapsed-grain version) since it's part of this fact's actual grain
again, and is the raw material for the AffectedBranchCount DAX measure
described below.

PARTDESCRIPTION: the raw table's own PartDescription varies inconsistently
by branch/file (confirmed a leftover artifact, not meaningful data, by Ben
2026-08-10) -- replaced here with dim_Parts' Description (standardized).

FRANCHISE: not persisted as a column here (all JD parts are expected to
have Franchise = 'D', so a column would carry no distinguishing
information). Investigated via
verify_fact_priceupdate_enriched.py's Franchise consistency check
(comparing Raw_PriceUpdate_History's own Franchise against dim_Parts'
Franchise for the same PartNumber): found ~61,000 rows (1.2%) showing a
mismatch as of 2026-08-10. Traced this to its root cause -- it was NOT a
defect in Raw_PriceUpdate_History. It was a real, separate bug in
dim_Parts.pq's own deduplication logic (Table.Distinct picking an
arbitrary row per PartNumber instead of the majority-agreed value across
jdis_Part_Information's multiple rows per part) -- confirmed via direct
investigation (e.g. part DZ111141 has 21 source rows in
jdis_Part_Information, 19 of which say Franchise='D', with only 1 rare
'TD' and 1 rare 'td' exception; dim_Parts had picked one of the 2 rare
exceptions). This was significant enough (affects a table used by 9+
downstream reports) that it was fixed immediately as its own priority
item -- see the dedup fix in dim_Parts.pq (merged via PR #28, 2026-08-10)
and project memory notes project_dim_parts_dedup_fix.md and
project_dim_parts_vendorcode_limitation.md. IMPORTANT: as of this fact
table being written, that dim_Parts fix is deployed to live Fabric but its
own performance-scoped version does NOT majority-vote CommodityCode or
VendorCode (see project_dim_parts_perf_followup.md) -- re-verify this
Franchise consistency check periodically, since dim_Parts' own correctness
can keep evolving independently of this fact.

AFFECTEDBRANCHCOUNT (moved OUT of this query -- now a DAX measure, not an
ETL column): originally computed here via Table.Group -- see REDESIGNED
note above for why that was reverted. Ben's original ask ("how many
branches were affected by this price change") is still fully answerable,
just at the semantic-model layer instead of the ETL layer, which is
actually the MORE correct place for it, not just the faster one: a DAX
measure like
    AffectedBranchCount := DISTINCTCOUNT(Fact_PriceUpdate_Enriched[Branch])
evaluated in a visual/table grouped by PartNumber+EffectiveDate will
compute the exact same number the old M column did, but will also
correctly RECALCULATE if a report ever filters to a subset of branches
(e.g. one region) -- something a frozen, pre-computed ETL column could
never do; it would just keep showing the all-branches total even when a
report is filtered down to fewer branches, which is a real, subtle
correctness trap, not just a missed nice-to-have. Not yet built as of
this note -- a semantic-model task, not a dataflow task. See
projects/jd-price-updates/scripts/verify_fact_priceupdate_enriched.py for
the SQL-equivalent logic (still useful as a reference for validating the
eventual DAX measure's output) and project memory
project_dim_parts_perf_followup.md for the fuller context on why ETL-time
GROUP BY was avoided here.

HASBRANCHPRICEDISAGREEMENT: no longer applicable/needed. It existed to
flag when collapsing branches together would have hidden a real
disagreement -- since this fact no longer collapses branches at all, any
such disagreement is just directly visible in the data itself (different
rows, different values, for the same PartNumber+EffectiveDate) -- nothing
gets hidden that would need a tripwire. If ever needed at query time, the
same check can be expressed directly in DAX or SQL against this table's
now-uncollapsed rows.

NO CURRENT-SNAPSHOT VALUES: dim_Parts is a current snapshot, not
point-in-time history. Adding today's SellPrice1/InventoryCost/etc. onto a
historical price-change row (some back to 2008) would misleadingly invite
"today's price" being used to compute a "margin at the time." Deliberately
excluded -- see design spec.

INGESTEDAT: carried through from Raw_PriceUpdate_History as-is, not
recomputed -- since this fact's grain is unchanged from raw, each row
still corresponds to exactly one raw row, so its original IngestedAt
value remains meaningful. Same reasoning already used in the sibling
Fact_JDNationalChangeReport_Enriched.
============================================================================
*/

let
    // Placeholder names -- these come from this dataflow's own "Get Data >
    // Lakehouse > Tables" wizard steps, which name the resulting query
    // after the table itself (Raw_PriceUpdate_History, dim_Parts).
    Source = Raw_PriceUpdate_History,

    NormalizePartNumber = Table.TransformColumns(Source, {
        {"PartNumber", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text}
    }),

    // ------------------------------------------------------------------
    // Enrich with dim_Parts classification columns. Left outer join --
    // dim_Parts guarantees PartNumber uniqueness (its own final
    // deduplication step), so this cannot fan out rows. No grouping
    // anywhere in this query -- see REDESIGNED note above.
    // ------------------------------------------------------------------
    JoinWithDimParts = Table.NestedJoin(NormalizePartNumber, {"PartNumber"}, dim_Parts, {"PartNumber"}, "DimPartsMatch", JoinKind.LeftOuter),

    // IsCarriedLocally computed directly from the pre-expand nested join
    // table -- Table.RowCount([DimPartsMatch]) > 0 tests "did the join
    // find a match" directly, rather than using any one expanded column
    // (e.g. SLC) as an indirect proxy, which would false-negative on a
    // genuinely matched dim_Parts row that happens to have a legitimately
    // null SLC.
    AddIsCarriedLocally = Table.AddColumn(JoinWithDimParts, "IsCarriedLocally", each Table.RowCount([DimPartsMatch]) > 0, type logical),

    ExpandDimParts = Table.ExpandTableColumn(AddIsCarriedLocally, "DimPartsMatch",
        {"Description", "Source", "SLC", "DealerGroupCode", "CommodityCode", "VendorCode"},
        {"Description", "Source", "SLC", "DealerGroupCode", "CommodityCode", "VendorCode"}),

    FinalColumnOrder = Table.ReorderColumns(ExpandDimParts, {
        "Branch", "PartNumber", "EffectiveDate", "Description", "Category",
        "ManufacturerListPrice", "DealerListPrice", "ListPriceChangePercent",
        "ManufacturerReplacePrice", "DealerReplacePrice", "ManufacturerSellPrice1",
        "DealerSellPrice1", "SellPriceOld", "CostDiff", "ListDiff", "SellPrice1Diff",
        "UpdateCode", "Source", "SLC", "DealerGroupCode", "CommodityCode",
        "VendorCode", "IsCarriedLocally", "IngestedAt"
    })
in
    FinalColumnOrder
