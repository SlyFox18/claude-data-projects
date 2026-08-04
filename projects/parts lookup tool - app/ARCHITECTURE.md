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
- Columns: `id, bin, binQty, branch, comments, description, franchise, lastRefreshed, partNumber, sellPrice1, superFrom, superTo, vendorCode` (camelCase, matching the TypeScript entity fields exactly, no transformation). `description` added 2026-07-17 per Ben's feedback — sourced from `InMaster.PART_DESC`, already present in `InMaster_PartsLookup_Raw` but not originally carried through to this entity.

**`id` generation — two different findings, and the second one is the operative one:**
- A hand-written SQL `INSERT` omitting `id` entirely succeeds (there's a database-level default).
- But Dataflow Gen2's mapped destination write does **not** tolerate leaving a required column unmapped ("(none)") even with that default in place — it errors with "some column mappings have errors."
- **Resolution:** the sync query generates its own `id` — a per-row index (guaranteed unique within a run) converted to hex and embedded in valid GUID text format (`00000000-0000-0000-0000-<12 hex digits>`). This doesn't need to be a "real" random v4 UUID; SQL Server's `uniqueidentifier` only requires syntactically valid GUID text, and Replace mode means uniqueness only needs to hold within one run's ~1.1M rows. Power Query M has no built-in GUID generator, and a random-per-row value was deliberately avoided — M's random functions have a known bug where they can return the same value across every row in a `Table.AddColumn` context; the row-index approach has no such risk.

**`binQty` must be nullable:** ~8.8% of rows in `InMaster_PartsLookup_Raw` (96,534 / 1,099,563) have a null `binQty` because `OnHandQty` or `PendingQty` are themselves untracked for those parts in the source system. The entity originally had `binQty` as required, which caused a real `NOT NULL` constraint violation on first sync run. Fixed by making it `@int({ optional: true })` — never default an untracked quantity to `0`, since that would falsely claim "definitely empty bin" when the truth is "unknown" (same principle applied elsewhere in this org's data, e.g. `Fact_Transfers`' `OrderQty`/`ShippedQty` nulls). Required an `npx rayfin up db apply` to push the relaxed schema before re-running the sync.

## Refresh Cadence

**Confirmed 2026-07-16:** dedicated pipeline (`InMaster_PartsLookUp` → Wait → `PartLookUp_Sync`, with success/failure email notifications), running 4x/day at 7:45 AM, 10:00 AM, 2:00 PM, and 4:00 PM. Running cleanly with no failures since it went live. Matches the "start conservative" decision — can tighten the cadence later if actually needed.

## App Branding

**Ben's feedback, 2026-07-17:** the app's user-facing name is "Parts Availability" (title bar, in-app header, sign-in page) — the underlying Fabric item, repo, and internal project naming (`parts-lookup-app`, "Parts Lookup Tool") stay as-is for continuity with existing history; only user-visible text changed. Column labels abbreviated: BR (Branch), FR (Franchise), Sell Price (was "Sell Price 1"), Sup To / Sup From (was "Super To" / "Super From"). Description column added (see schema note above).

## Incremental Refresh (added 2026-08-04)

Full design and build plan: `docs/superpowers/plans/2026-08-04-parts-lookup-incremental-refresh.md` (in `data-projects`).

**Why:** the original 4x/day full-replace sync (~1.1M rows moved every run) was the root cause of a real Fabric capacity incident (see `INCIDENT-2026-07-28-capacity-and-refresh-fix.md`) — even after fixing the swap mechanism's `TRUNCATE`-triggered OneLake mirror reseed, the underlying full extract-and-reload cost remained and blocked safely increasing refresh frequency ahead of the app's rollout to 19 stores.

**Resolved design question:** Dataflow Gen2's SQL database destination supports only Append/Replace, no native upsert/merge (confirmed against Microsoft Learn docs, including MS's own "Slowly changing dimension type 2" tutorial hitting the identical problem). Upsert+delete logic therefore lives in a pipeline Script activity running T-SQL `MERGE`, not in the Dataflow Gen2 destination config.

**Parallel objects (new, alongside the existing full-refresh objects, not replacing them):**
- `df_InMaster_PartsLookup_Incremental` — watermark-filtered raw pull (query: `.claude/queries/raw-tables/InMaster_PartsLookup_Incremental.pq` in `data-projects`)
- `df_PartsLookup_Sync_Incremental` — writes delta rows with a deterministic hash `id` to `PartLocations_Staging_Incremental` (query: `.claude/queries/facts/PartsLookup_Sync_Incremental.pq`)
- `Merge_Staging_Incremental_To_Live` — pipeline Script activity, T-SQL `MERGE` (update/insert) + explicit `DELETE` for vendor-code-nulled rows, cleans up staging with `DELETE` not `TRUNCATE` (directly applying the July 28/Aug 3-4 incident lesson)
- `Update_Watermark_PartsLookup` — notebook, updates `watermark_control` (Lakehouse table, `TableName = 'InMaster_PartsLookup'`), guarded against null on empty-delta runs
- `Pipeline_PartsLookup_Incremental` — orchestrates the above, scheduled 4x/day to start (same times as the old pipeline), tightened later once proven

**Stable id scheme:** replaced the old per-run row-index `id` (only valid under full Replace) with a deterministic 64-bit hash of `Branch|Franchise|PartNumber` — the confirmed true unique key — so the same real-world row always maps to the same `id` across runs, which upserts require.

**The old full-refresh objects** (`df_InMaster_PartsLookup_Raw`, `df_PartsLookup_Sync`, the July 28 staging-swap mechanism) are unchanged in mechanism, just repurposed to run weekly instead of 4x/day, as a reconciliation safety net.

## On Order column (added 2026-08-04)

Requested during stakeholder testing. Source: `InMaster.OS_ORDER_QTY` ("Outstanding Order Quantity" — on order with the vendor, not yet received), confirmed against the full `InMaster` column list. Distinct from `BACK_ORD_QTY`/`BO_Qty` (customer backorders) and `IN_TRANSIT_QTY` (already shipped, different signal) — if the value doesn't match what parts staff expect once live, it's a one-column swap in the raw/sync queries and merge script, not a redesign.

Threaded through every layer: both raw-pull queries (incremental and weekly-reconciliation), both sync queries, `PartLocations_Staging_Incremental`'s DDL, the `MERGE` script, an `ALTER TABLE PartLocations ADD onOrder INT NULL` on the live table, the Rayfin entity (`rayfin/data/PartLocation.ts`, nullable — same "never default an untracked quantity to 0" principle as `binQty`), and the UI (`src/pages/HomePage.tsx`, new sortable "On Order" column). App-side code changes are already committed; the Fabric-side raw/sync/merge objects and `npm run rayfin:db` / `npm run rayfin:up` still need to run (see the plan doc's Task 6.5 and Task 11).
