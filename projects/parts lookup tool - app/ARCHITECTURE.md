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

**Confirmed 2026-07-15:** `id` has a database-level default (an `INSERT` omitting the column entirely succeeded). Task 5's dataflow does not map or generate `id` at all — the database populates it automatically on every insert.

## Refresh Cadence

Not yet fixed — see Task 6. Not capped by `jdis_Part_Information`'s 3x/day schedule since this table no longer depends on it; bounded only by how often you want to re-sync.
