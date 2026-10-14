/*
============================================================================
Query: Fact_JDNationalChangeReport_Enriched
Dataflow: df_Fact_JDNationalChangeReport_Enriched
Location: LH_Master_Data → Dataflows (fact-tables folder, or alongside
other JD price update dataflows -- see Fabric workspace organization)
============================================================================

PURPOSE: Enriched fact table built from Raw_JDNationalChangeReport_History
+ dim_Parts. Part of sub-project 3 phase 1 (foundational fact layer) -- see
docs/superpowers/specs/2026-08-10-jd-pricing-fact-tables-design.md. What
specific analysis/KPIs get built on top of this fact is explicitly out of
scope for this query.

GRAIN: Unchanged from raw -- one row per PartNumber + EffectiveDate +
SourceFileName. Unlike Fact_PriceUpdate_Enriched, this source never had a
branch dimension to begin with, so there's nothing to collapse. Verified
against real production data via
projects/jd-price-updates/scripts/verify_fact_jdnationalchangereport_enriched.py
BEFORE this query was written -- confirmed raw and joined row counts are
exactly equal (48,453 = 48,453 as of 2026-08-10) and the dim_Parts join
finds genuine matches: IsCarriedLocally split 45,410 False / 3,043 True
(~94%/6%), not a join that's silently matching nothing.

SOURCE: Two Lakehouse table connectors within this same dataflow (via
"Get Data > Lakehouse > Tables"): `Raw_JDNationalChangeReport_History` and
`dim_Parts`.

REFRESH: Weekly, full Replace (not Append) -- the source only changes when
Brian manually places a new file (at most weekly, per the Saturday
reminder), so a daily refresh would just spend CU re-deriving identical
data. See Fabric Pipeline setup in the implementation plan's Task 10.

PARTNUMBER NORMALIZATION: same reasoning as Fact_PriceUpdate_Enriched --
dim_Parts normalizes PartNumber with Text.Upper(Text.Trim(...));
Raw_JDNationalChangeReport_History only trims, doesn't uppercase. This
query normalizes to dim_Parts' convention before joining.

ISCARRIEDLOCALLY: computed as a genuine join-match test (Table.RowCount on
the pre-expand nested join table > 0), not an indirect column-null proxy --
same pattern used in the sibling Fact_PriceUpdate_Enriched.pq after a code
review found the column-null-proxy approach could produce false negatives
if a legitimately matched dim_Parts row happened to have a null value in
whichever column was being tested. Expected False for the large majority
of rows -- most national Deere parts aren't carried at South Plains, and
this is confirmed real (not a join bug) by the roughly 94%/6% split found
during verification.

NOTE ON LIVE dim_Parts STATE (as of 2026-08-10): a real, separate bug was
found and fixed in dim_Parts.pq's own deduplication logic (majority-vote
fix, merged via PR #28) -- see that file's header comment and project
memory notes project_dim_parts_dedup_fix.md /
project_dim_parts_vendorcode_limitation.md. That fix exists in this repo's
reference copy but has NOT yet been deployed to the live Fabric Dataflow
Gen2. This doesn't affect IsCarriedLocally itself (a pure join-match test,
unrelated to which specific classification values dim_Parts currently
holds), but the Source/SLC/DealerGroupCode/CommodityCode/VendorCode
enrichment columns below will reflect whatever dim_Parts currently has
live until that fix is deployed and refreshed.

IngestedAt IS CARRIED THROUGH FROM RAW, NOT RECOMPUTED: unlike
Fact_PriceUpdate_Enriched (which regrains and therefore needs a fresh
IngestedAt), this fact's grain is unchanged from raw -- each row still
corresponds to exactly one raw row, so its original IngestedAt value
remains meaningful and is passed through as-is.

NO CURRENT-SNAPSHOT VALUES: same reasoning as Fact_PriceUpdate_Enriched --
see that query's header comment and the design spec.
============================================================================
*/

let
    // Placeholder names -- these come from this dataflow's own "Get Data >
    // Lakehouse > Tables" wizard steps, which name the resulting query
    // after the table itself (Raw_JDNationalChangeReport_History, dim_Parts).
    Source = Raw_JDNationalChangeReport_History,

    NormalizePartNumber = Table.TransformColumns(Source, {
        {"PartNumber", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text}
    }),

    // ------------------------------------------------------------------
    // Enrich with dim_Parts classification columns. Left outer join --
    // dim_Parts guarantees PartNumber uniqueness, so this cannot fan out
    // rows (grain stays exactly as in the raw table).
    // ------------------------------------------------------------------
    JoinWithDimParts = Table.NestedJoin(NormalizePartNumber, {"PartNumber"}, dim_Parts, {"PartNumber"}, "DimPartsMatch", JoinKind.LeftOuter),

    // IsCarriedLocally computed BEFORE expanding -- direct join-match test,
    // not an indirect column-null proxy. See ISCARRIEDLOCALLY note above.
    AddIsCarriedLocally = Table.AddColumn(JoinWithDimParts, "IsCarriedLocally", each
        Table.RowCount([DimPartsMatch]) > 0, type logical),

    ExpandDimParts = Table.ExpandTableColumn(AddIsCarriedLocally, "DimPartsMatch",
        {"Description", "Source", "SLC", "DealerGroupCode", "CommodityCode", "VendorCode"},
        {"Description", "Source", "SLC", "DealerGroupCode", "CommodityCode", "VendorCode"}),

    FinalColumnOrder = Table.ReorderColumns(ExpandDimParts, {
        "PartNumber", "EffectiveDate", "Description", "CurrentDNP", "CurrentSLP", "NewDNP", "NewSLP",
        "SourceFileName", "SourceFileDate", "FileNameDateMismatchFlag", "HasTypeConversionIssue",
        "Source", "SLC", "DealerGroupCode", "CommodityCode", "VendorCode", "IsCarriedLocally", "IngestedAt"
    })
in
    FinalColumnOrder
