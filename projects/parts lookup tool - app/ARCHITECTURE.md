# Architecture — Parts Lookup Tool

## Data Flow

```
[ODBC: InMaster] → df_InMaster_PartsLookup_Raw → InMaster_PartsLookup_Raw (Lakehouse)
                                                          │
                                                          ▼
                                          Sync step (mechanism: see Task 4/5 findings)
                                                          │
                                                          ▼
                                    PartLocation table (Fabric App's own SQL Database in Fabric)
                                                          │
                                                          ▼
                                          parts-lookup-app (Fabric App, GraphQL + React UI)
```

## Key Constraints

- Do NOT modify the existing `InMaster.pq` / `InMaster_Raw.pq` raw pulls — this is a separate, purpose-built table for this tool only.
- BinQty is computed at the raw-query level (`ON_HAND_QTY - Pending_Qty`), not in the Fabric App — validated 2026-07-15 at 99.94% exact match against `jdis_Part_Information`'s independently tracked BinQty (1,102,498 / 1,103,165 rows).
- The Fabric App (generic Rayfin template) cannot read the Lakehouse directly — it owns its own schema. Data must be pushed in via the sync step.

## Sync Mechanism

**Confirmed 2026-07-15 (Task 4):** direct SQL writes to the Fabric App's SQL Database in Fabric are fully consistent with the GraphQL layer — a row inserted via plain SQL (Fabric portal's query editor, using the connection string from the SQL Database child item) was immediately visible through the app's real GraphQL client (`client.data.PartLocation.select([...]).execute()`).

This means Task 5's sync step is a normal **Dataflow Gen2** writing straight to the SQL Database in Fabric as a SQL Server destination — no GraphQL mutations, no notebook, no headless-auth question to solve. Delete-then-insert (full replace) each run, matching `InMaster_PartsLookup_Raw` being itself a full refresh.

**Real schema (confirmed via the deployed database):**
- Table: `PartLocations` (PascalCase, pluralized — not the snake_case Fabric App docs/examples implied)
- Columns: `id, bin, binQty, branch, comments, franchise, lastRefreshed, partNumber, sellPrice1, superFrom, superTo, vendorCode` (camelCase, matching the TypeScript entity fields exactly, no transformation)

**`id` generation — two different findings, and the second one is the operative one:**
- A hand-written SQL `INSERT` omitting `id` entirely succeeds (there's a database-level default).
- But Dataflow Gen2's mapped destination write does **not** tolerate leaving a required column unmapped ("(none)") even with that default in place — it errors with "some column mappings have errors."
- **Resolution:** the sync query generates its own `id` — a per-row index (guaranteed unique within a run) converted to hex and embedded in valid GUID text format (`00000000-0000-0000-0000-<12 hex digits>`). This doesn't need to be a "real" random v4 UUID; SQL Server's `uniqueidentifier` only requires syntactically valid GUID text, and Replace mode means uniqueness only needs to hold within one run's ~1.1M rows. Power Query M has no built-in GUID generator, and a random-per-row value was deliberately avoided — M's random functions have a known bug where they can return the same value across every row in a `Table.AddColumn` context; the row-index approach has no such risk.

## Refresh Cadence

Not yet fixed — see Task 6. Not capped by `jdis_Part_Information`'s 3x/day schedule since this table no longer depends on it; bounded only by how often you want to re-sync.
