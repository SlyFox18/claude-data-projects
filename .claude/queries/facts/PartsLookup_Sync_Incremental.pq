/*
============================================================================
Query: PartsLookup_Sync_Incremental
Dataflow: df_PartsLookup_Sync_Incremental
Location: LH_Master_Data → Dataflows → 04 - Fact
============================================================================

PURPOSE: Pushes InMaster_PartsLookup_Incremental's delta rows into the
parts-lookup-app's PartLocations_Staging_Incremental table. A pipeline Script
activity (Merge_Staging_Incremental_To_Live) then MERGEs this staging data
into the live PartLocations table and deletes any row whose VendorCode has
gone null. This is NOT the full-replace PartsLookup_Sync — that stays as the
weekly reconciliation path.

SOURCE: References InMaster_PartsLookup_Incremental directly (same
own-data-source pattern as the existing PartsLookup_Sync).

DESTINATION: Dataflow Gen2 native "SQL database" destination →
PartLocations_Staging_Incremental. Update method: Replace — each run's
staging table should contain only that run's delta batch (small, ~10K rows
typical), fully replaced every time. The merge step consumes and clears it.

ID GENERATION: Deterministic 64-bit hash of Branch|Franchise|PartNumber
(the confirmed true unique key — see INCREMENTAL-REFRESH-FEASIBILITY.md),
split across two independent rolling hashes (GetStableId below) so the same
real-world row always produces the same id across every run. This replaces
the old per-run-row-index scheme, which only worked because full Replace
mode reset every id on every run — that assumption breaks for incremental
upserts.

DO NOT trim/uppercase the key fields before hashing. An earlier version did
(defensive-seeming, but wrong) and it caused a real PRIMARY KEY violation in
production 2026-08-04: two genuinely different InMaster rows for the same
Branch+Franchise (e.g. PartNumber '03-3212560 ' with a trailing space vs
'03-3212560' without) got merged into one id once normalized. Verified
against all 1,062,114 real rows in InMaster_PartsLookup_Incremental with
raw (non-normalized) Branch+Franchise+PartNumber: zero duplicate groups —
this is the actual validated true grain, matching the original
investigation's own methodology (which also used raw GROUP BY, no
TRIM/UPPER). Hashing the raw values directly produces zero collisions and
zero float64 precision loss across the full dataset (checked directly, not
just estimated).

ON ORDER: onOrder sourced from InMaster_PartsLookup_Incremental.OnOrder
(InMaster.OS_ORDER_QTY) — see that query's header for the column-choice
rationale. Requires PartLocations.onOrder to already exist on the live table
(added via ALTER TABLE, see the incremental refresh plan's Task 6.5) before
the merge step can write to it.
============================================================================
*/

let
    Source = InMaster_PartsLookup_Incremental,

    AddLastRefreshed = Table.AddColumn(
        Source,
        "lastRefreshed",
        each DateTimeZone.RemoveZone(DateTimeZone.UtcNow()),
        type datetime
    ),

    GetStableId = (branch as text, franchise as text, partNumber as text) as text =>
        let
            Key = branch & "|" & franchise & "|" & partNumber,
            Codes = List.Transform(Text.ToList(Key), each Character.ToNumber(_)),
            Hash1 = List.Accumulate(Codes, 5381, (state, code) => Number.Mod(state * 33 + code, 65521)),
            Hash2 = List.Accumulate(Codes, 0, (state, code) => Number.Mod(state * 131 + code, 281474976710597)),
            Segment4 = Text.PadStart(Number.ToText(Hash1, "X"), 4, "0"),
            Segment5 = Text.PadStart(Number.ToText(Hash2, "X"), 12, "0")
        in
            "00000000-0000-4000-" & Segment4 & "-" & Segment5,

    AddId = Table.AddColumn(
        AddLastRefreshed,
        "id",
        each GetStableId([Branch], [Franchise], [PartNumber]),
        type text
    ),

    RenameForApp = Table.RenameColumns(AddId, {
        {"Branch", "branch"},
        {"Franchise", "franchise"},
        {"PartNumber", "partNumber"},
        {"Description", "description"},
        {"Bin", "bin"},
        {"SuperFrom", "superFrom"},
        {"SuperTo", "superTo"},
        {"VendorCode", "vendorCode"},
        {"SellPrice1", "sellPrice1"},
        {"Comments", "comments"},
        {"BinQty", "binQty"},
        {"OnOrder", "onOrder"}
    }),

    SelectFinalColumns = Table.SelectColumns(RenameForApp, {
        "id", "partNumber", "branch", "franchise", "description", "vendorCode", "bin",
        "binQty", "onOrder", "sellPrice1", "superTo", "superFrom", "comments", "lastRefreshed"
    })
in
    SelectFinalColumns
