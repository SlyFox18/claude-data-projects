/*
============================================================================
Query: Fact_PriceUpdate_Enriched
Dataflow: df_Fact_PriceUpdate_Enriched
Location: LH_Master_Data → Dataflows (fact-tables folder, or alongside
other JD price update dataflows -- see Fabric workspace organization)
============================================================================

PURPOSE: Enriched, deduplicated fact table built from Raw_PriceUpdate_History
+ dim_Parts. Part of sub-project 3 phase 1 (foundational fact layer) -- see
docs/superpowers/specs/2026-08-10-jd-pricing-fact-tables-design.md. What
specific analysis/KPIs get built on top of this fact is explicitly out of
scope for this query.

GRAIN: One row per PartNumber + EffectiveDate -- NOT Branch + PartNumber +
EffectiveDate + SourceFileName like the raw table. Confirmed with Brian and
Ben (2026-08-10): branch doesn't affect price, only assortment, so
collapsing across branches removes an assortment artifact that was never
analytically meaningful for pricing questions, and AffectedBranchCount
below captures exactly the "how many branches" signal that's actually
useful. This logic was verified against real production data via
projects/jd-price-updates/scripts/verify_fact_priceupdate_enriched.py
BEFORE this query was written. Real verified example: PartNumber 57M11134,
EffectiveDate 2026-08-03, AffectedBranchCount = 16 (branches 1, 2, 4, 6, 7,
8, 11, 13, 15, 16, 91, 92, 93, 95, 96, 97). NOTE: an earlier manual count
from a Fabric table preview screenshot suggested 15 branches for this same
example -- that count was incomplete (the screenshot only showed however
many rows fit before the table's sort order moved to a different part;
branch 93 was sitting elsewhere, off-screen). 16 is the real, SQL-verified
number -- trust this one.

SOURCE: Two Lakehouse table connectors within this same dataflow (via
"Get Data > Lakehouse > Tables", which names the resulting query after the
table itself, unlike the Files connector sub-projects 1/2 use -- no
placeholder renaming needed here): `Raw_PriceUpdate_History` and
`dim_Parts`.

REFRESH: Daily, full Replace (not Append) -- this is a derived/enriched
rebuild of the ENTIRE source table on every refresh, not new-rows-only.
Scheduled after both Raw_PriceUpdate_History (harvested daily 02:00) and
dim_Parts have refreshed. See Fabric Pipeline setup in the implementation
plan's Task 10.

PARTNUMBER NORMALIZATION: dim_Parts normalizes PartNumber with
Text.Upper(Text.Trim(...)); Raw_PriceUpdate_History does neither. A naive
join on PartNumber as-is would silently under-match real, carried parts
purely from casing/whitespace differences. This query normalizes
PartNumber to dim_Parts' convention before joining -- the underlying raw
table is not touched.

DROPPED COLUMNS (present in Raw_PriceUpdate_History, not carried into this
fact): Branch, SourceFileBranch, BinLocation, OnHandQty, SourceFileName,
SourceFileDate, BranchMismatchFlag, PartDescription (raw), Franchise (raw).
Branch/file-level detail remains available in Raw_PriceUpdate_History
itself if ever needed -- this fact intentionally doesn't duplicate it.

HASTYPECONVERSIONISSUE (attempted, then dropped -- not a column in this
fact): Raw_PriceUpdate_History has NO HasTypeConversionIssue column --
re-confirmed 2026-08-10 directly against the LIVE Fabric table (fresh
DESCRIBE against the deployed table, not just this repo's reference .pq
copy, which does define the column but has not actually been deployed --
a separate, known reference-vs-live deployment gap, not this fact's
concern). An inline reconstruction was attempted here -- re-parsing each
price/date field with try Number.From(...)/Date.From(...) at this layer
-- but was dropped as fundamentally uncomputable: by the time a row
reaches this fact, Raw_PriceUpdate_History's own upstream query has
already run every risky field through
try Number.From(...)/Date.From(...) otherwise null, so a genuinely
garbled source value has already become null there -- indistinguishable
at this layer from "was always blank." The pre-conversion raw text isn't
available downstream of Raw_PriceUpdate_History, so this fact cannot
recover that signal; shipping the column anyway would mean it always
silently reads False, which is worse than not having it at all. If
Raw_PriceUpdate_History's live deployment is ever updated to add its own
HasTypeConversionIssue column (matching its reference .pq), this fact
could then properly carry it forward via a simple List.AnyTrue
aggregation over the grouped rows -- a future possibility, not something
built now.

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
table being written, that dim_Parts fix exists in this repo's reference
copy but has NOT yet been deployed to the live Fabric Dataflow Gen2 --
until someone manually pastes the corrected dim_Parts.pq into Fabric and
refreshes it, live dim_Parts still has the old, buggy classification, and
this fact's dim_Parts-joined enrichment columns will inherit whatever
dim_Parts currently has live. Re-verify this Franchise consistency check
after the dim_Parts fix is actually deployed -- the ~61,000-row mismatch
count should shrink substantially (though not necessarily to exactly
zero -- VendorCode-style genuine branch variation was ruled out
specifically for Franchise via the investigation above, but re-verifying
after deployment is still the right practice, not an assumption).

HASBRANCHPRICEDISAGREEMENT (attempted, then dropped -- PERFORMANCE,
2026-08-11): originally a safety-net flag -- true if the branch rows
being collapsed for a given PartNumber+EffectiveDate don't actually agree
on price/change fields. Confirmed correct and real via
verify_fact_priceupdate_enriched.py (7,422 of 1,292,823 groups, 0.57%,
actually show this) -- the logic itself was never wrong. It was dropped
because of a real, live production performance failure: this column's
per-group aggregation function ran a 3-step List.Count(List.Distinct(
List.RemoveNulls(...))) chain 12 SEPARATE times (once per price/change
field checked) for every one of the ~1.29 million PartNumber+EffectiveDate
groups, on top of the ~5.1M-row source scan already required to build
those groups. When built into the live Fabric Dataflow Gen2 and refreshed,
this ran for 45+ minutes without completing and had to be cancelled --
directly analogous to (and diagnosed using the same lesson learned from)
the dim_Parts.pq performance saga the same night: a single Table.Group
call bundling multiple complex custom per-group functions is a severe
M-engine anti-pattern at ~1M+-group scale, regardless of whether the
functions use Table.* or List.* primitives. AffectedBranchCount (kept)
uses this same 3-step chain, but only ONCE per group, not twelve times --
by far the smaller share of the total per-group cost, and the one Ben
explicitly asked for as this fact's core value-add, unlike
HasBranchPriceDisagreement which was a secondary safety net. See project
memory project_dim_parts_perf_followup.md for the shared root cause and
the recommended real fix (a Fabric Notebook/Spark redesign) for both this
fact and dim_Parts in a future session -- if/when that happens,
HasBranchPriceDisagreement (or an equivalent per-column disagreement
check) can be reintroduced there without the same per-group cost, since
Spark's engine is built for exactly this kind of group-by-and-compare
computation at this scale.

NO CURRENT-SNAPSHOT VALUES: dim_Parts is a current snapshot, not
point-in-time history. Adding today's SellPrice1/InventoryCost/etc. onto a
historical price-change row (some back to 2008) would misleadingly invite
"today's price" being used to compute a "margin at the time." Deliberately
excluded -- see design spec.
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
    // Collapse Branch + PartNumber + EffectiveDate + SourceFileName grain
    // down to PartNumber + EffectiveDate. See GRAIN note above.
    // ------------------------------------------------------------------
    GroupedByPartAndDate = Table.Group(NormalizePartNumber, {"PartNumber", "EffectiveDate"}, {
        {"AffectedBranchCount", each List.Count(List.Distinct(List.RemoveNulls([Branch]))), Int64.Type},
        {"Category", each List.First(List.RemoveNulls([Category]), null), type nullable text},
        {"ManufacturerListPrice", each List.First(List.RemoveNulls([ManufacturerListPrice]), null), type nullable number},
        {"DealerListPrice", each List.First(List.RemoveNulls([DealerListPrice]), null), type nullable number},
        {"ListPriceChangePercent", each List.First(List.RemoveNulls([ListPriceChangePercent]), null), type nullable number},
        {"ManufacturerReplacePrice", each List.First(List.RemoveNulls([ManufacturerReplacePrice]), null), type nullable number},
        {"DealerReplacePrice", each List.First(List.RemoveNulls([DealerReplacePrice]), null), type nullable number},
        {"ManufacturerSellPrice1", each List.First(List.RemoveNulls([ManufacturerSellPrice1]), null), type nullable number},
        {"DealerSellPrice1", each List.First(List.RemoveNulls([DealerSellPrice1]), null), type nullable number},
        {"SellPriceOld", each List.First(List.RemoveNulls([SellPriceOld]), null), type nullable number},
        {"CostDiff", each List.First(List.RemoveNulls([CostDiff]), null), type nullable number},
        {"ListDiff", each List.First(List.RemoveNulls([ListDiff]), null), type nullable number},
        {"SellPrice1Diff", each List.First(List.RemoveNulls([SellPrice1Diff]), null), type nullable number},
        {"UpdateCode", each List.First(List.RemoveNulls([UpdateCode]), null), type nullable text}
        // HasBranchPriceDisagreement dropped here -- see the header comment's
        // "HASBRANCHPRICEDISAGREEMENT (attempted, then dropped -- PERFORMANCE)"
        // note for the full reasoning. Do not re-add a per-group custom
        // function like this without re-reading that note first.
    }),

    // ------------------------------------------------------------------
    // IngestedAt -- freshly computed at THIS fact's build time (not
    // carried from raw rows' IngestedAt, which becomes ambiguous once
    // multiple branch rows collapse into one group). DST-aware UTC ->
    // Central, same pattern as .claude/queries/DATA-REFRESH-TEMPLATE.pq
    // ------------------------------------------------------------------
    UtcNow    = DateTimeZone.UtcNow(),
    UtcDT     = DateTimeZone.RemoveZone(UtcNow),
    CurYear   = Date.Year(DateTime.Date(UtcDT)),
    Mar1      = #date(CurYear, 3, 1),
    Sun1Mar   = Date.AddDays(Mar1, Number.Mod(7 - Date.DayOfWeek(Mar1, Day.Sunday), 7)),
    DstStart  = #datetime(CurYear, 3, Date.Day(Date.AddDays(Sun1Mar, 7)), 8, 0, 0),
    Nov1      = #date(CurYear, 11, 1),
    Sun1Nov   = Date.AddDays(Nov1, Number.Mod(7 - Date.DayOfWeek(Nov1, Day.Sunday), 7)),
    DstEnd    = #datetime(CurYear, 11, Date.Day(Sun1Nov), 7, 0, 0),
    OffsetHrs = if UtcDT >= DstStart and UtcDT < DstEnd then -5 else -6,
    LocalNow  = DateTimeZone.RemoveZone(DateTimeZone.SwitchZone(UtcNow, OffsetHrs, 0)),

    AddIngestedAt = Table.AddColumn(GroupedByPartAndDate, "IngestedAt", each LocalNow, type datetime),

    // ------------------------------------------------------------------
    // Enrich with dim_Parts classification columns. Left outer join --
    // dim_Parts guarantees PartNumber uniqueness (its own final
    // deduplication step), so this cannot fan out rows.
    // ------------------------------------------------------------------
    JoinWithDimParts = Table.NestedJoin(AddIngestedAt, {"PartNumber"}, dim_Parts, {"PartNumber"}, "DimPartsMatch", JoinKind.LeftOuter),

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
        "PartNumber", "EffectiveDate", "Description", "Category",
        "ManufacturerListPrice", "DealerListPrice", "ListPriceChangePercent",
        "ManufacturerReplacePrice", "DealerReplacePrice", "ManufacturerSellPrice1",
        "DealerSellPrice1", "SellPriceOld", "CostDiff", "ListDiff", "SellPrice1Diff",
        "UpdateCode", "AffectedBranchCount",
        "Source", "SLC", "DealerGroupCode", "CommodityCode",
        "VendorCode", "IsCarriedLocally", "IngestedAt"
    })
in
    FinalColumnOrder
