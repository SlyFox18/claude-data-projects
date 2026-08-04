/*
============================================================================
Query: PartsLookup_Sync
Dataflow: df_PartsLookup_Sync
Location: LH_Master_Data → Dataflows → 04 - Fact (or wherever this pipeline stage lives)
============================================================================

PURPOSE: Pushes InMaster_PartsLookup_Raw into the parts-lookup-app Fabric
App's own database (PartLocations table). This is the sync step bridging
the Lakehouse and the Fabric App — the app can't read the Lakehouse
directly, so this dataflow is the only thing that populates it.

SOURCE: References the `InMaster_PartsLookup_Raw` query directly — this
dataflow adds that Lakehouse table as its own individual data source
(not the whole LH_Master_Data lakehouse as a shared connection), so the
query is referenced by name, not via LH_Master_Data{...}[Data] bracket
navigation.

DESTINATION: Dataflow Gen2's native "SQL database" destination, pointed
directly at the parts-lookup-app database (Fabric surfaces it in the
destination picker's workspace tree — no manual connection string
needed). Existing table PartLocations, Update method: Replace (full
delete + reinsert every run) — matches InMaster_PartsLookup_Raw being
itself a full refresh, and avoids stale rows lingering for parts that
lose their vendor code.

ID GENERATION: confirmed 2026-07-15 that `id` has a database-level
default when writing via a hand-written SQL INSERT that omits the
column — but Dataflow Gen2's mapped destination write does NOT tolerate
leaving a required column unmapped ("(none)") even when a DB default
exists; it errored with "some column mappings have errors." So this
query generates its own id: a row index (guaranteed unique within this
run) converted to hex and embedded in valid GUID format. Doesn't need
to be globally unique or a "real" v4 UUID — SQL Server's uniqueidentifier
only requires syntactically valid GUID text, and Replace mode means
uniqueness only has to hold within a single run's ~1.1M rows (12 hex
digits supports up to ~2.8 x 10^14 distinct values, far more than
enough). Power Query M has no built-in GUID generator, and a random-
value-per-row approach was avoided deliberately — M's random functions
have a known caching bug where they can return the same value across
every row in a Table.AddColumn context; a deterministic row-index-based
value has no such risk.

COLUMN NAMES: renamed here to match PartLocations' camelCase columns
exactly (confirmed via the deployed schema), since Dataflow Gen2's
destination maps by name.

ON ORDER: onOrder added 2026-08-04 (stakeholder testing feedback), sourced
from InMaster_PartsLookup_Raw.OnOrder. Must stay in sync with
PartsLookup_Sync_Incremental.pq — this dataflow still runs weekly as the
full-reconciliation path and would null out onOrder for every row otherwise.
============================================================================
*/

let
    Source = InMaster_PartsLookup_Raw,

    AddLastRefreshed = Table.AddColumn(
        Source,
        "lastRefreshed",
        each DateTimeZone.RemoveZone(DateTimeZone.UtcNow()),
        type datetime
    ),

    AddRowIndex = Table.AddIndexColumn(AddLastRefreshed, "RowIndex", 1, 1, Int64.Type),

    AddId = Table.AddColumn(
        AddRowIndex,
        "id",
        each "00000000-0000-0000-0000-" & Text.PadStart(Number.ToText([RowIndex], "X"), 12, "0"),
        type text
    ),

    RemoveRowIndex = Table.RemoveColumns(AddId, {"RowIndex"}),

    RenameForApp = Table.RenameColumns(RemoveRowIndex, {
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
