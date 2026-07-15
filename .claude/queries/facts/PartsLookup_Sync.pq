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

DESTINATION: SQL Server connector, pointed at the SQL Database in Fabric
connection string (from parts-lookup-app's SQL Database child item).
Update method: Replace (full delete + reinsert every run) — matches
InMaster_PartsLookup_Raw being itself a full refresh, and avoids stale
rows lingering for parts that lose their vendor code.

DO NOT map or generate `id` — confirmed 2026-07-15 that the database
auto-generates it on insert; this dataflow's output has no id column
at all, by design.

COLUMN NAMES: renamed here to match PartLocations' camelCase columns
exactly (confirmed via the deployed schema), since Dataflow Gen2's SQL
Server destination maps by name.
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

    RenameForApp = Table.RenameColumns(AddLastRefreshed, {
        {"Branch", "branch"},
        {"Franchise", "franchise"},
        {"PartNumber", "partNumber"},
        {"Bin", "bin"},
        {"SuperFrom", "superFrom"},
        {"SuperTo", "superTo"},
        {"VendorCode", "vendorCode"},
        {"SellPrice1", "sellPrice1"},
        {"Comments", "comments"},
        {"BinQty", "binQty"}
    }),

    SelectFinalColumns = Table.SelectColumns(RenameForApp, {
        "partNumber", "branch", "franchise", "vendorCode", "bin",
        "binQty", "sellPrice1", "superTo", "superFrom", "comments", "lastRefreshed"
    })
in
    SelectFinalColumns
