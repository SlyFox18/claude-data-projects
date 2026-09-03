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

**The old full-refresh objects** (`df_InMaster_PartsLookup_Raw`, `df_PartsLookup_Sync`, the July 28 staging-swap mechanism) are unchanged in mechanism, just repurposed to run weekly instead of 4x/day, as a reconciliation safety net. **As of 2026-08-06 this repurposing is still just a design intent, not done** — the old pipeline's trigger hasn't actually been changed to weekly yet (Task 9 Step 1); its `.pq` files already have `onOrder` added so it's safe to leave running 4x/day a bit longer if needed, it's just not the plan.

### Status as of 2026-08-06 — built and validated, deliberately not yet scheduled

**Done:** `Pipeline_PartsLookup_Incremental` is fully assembled (raw pull → wait → sync → wait → merge → watermark notebook, plus one success email and four independent failure emails, one per real activity — see "Pipeline notification pattern" below for why four separate ones, not one shared) and has completed a clean, fully-validated end-to-end run with real production data: a genuine 17,443-row watermark-filtered delta (not a re-pull of the full table), correct merge into `PartLocations`, watermark correctly advanced, staging correctly cleared, zero duplicate parts afterward. The mechanism works as designed.

**Not done:** the pipeline has **no schedule yet, deliberately.** Two real production incidents happened during the build (see below) that made it clear there was no clean baseline for what this pipeline alone costs in CU — Brian's call was to hold off on any automated schedule until a manual run, done in isolation (no other Fabric activity/validation queries running at the same time to muddy the reading), confirms what it actually costs. Plan from there: one clean isolated manual run → if fine, schedule once daily at an off-peak time and observe → if still fine, gradually increase toward the target 4x/day cadence from the plan doc. Do not jump straight to 4x/day without that staged validation, regardless of how urgent the original capacity problem felt — that urgency is exactly why this needs a real baseline, not a guess.

**Two real bugs found and fixed during the first real end-to-end runs (not design flaws in the plan — implementation issues surfaced by actually running it):**

1. **Script activity connection-wiring bug.** The `Merge_Staging_Incremental_To_Live` Script activity, when built fresh via the current Fabric portal UI, defaulted to a `connectionSettings`-wrapped connection binding (`type: "FabricSqlDatabase"`, nested `externalReferences.connection`) that is missing the `database` field the working pattern has, and fails instantly with `Value cannot be null. Parameter name: source` — regardless of script content; even a bare `SELECT 1 AS Test;` failed identically. The proven-working `Swap_Staging_To_Live` activity (in the old pipeline) uses a simpler, older shape: a top-level `externalReferences.connection` plus a `typeProperties.database` name string. **Fix:** rebuild the Script activity reusing the same existing connection object as `Swap_Staging_To_Live`, rather than letting the activity auto-create a new native connection binding. Worth checking for on any future Script activity added to a Fabric pipeline in this tenant — this isn't specific to Parts Lookup.
2. **Duplicate rows from two incompatible `id` schemes meeting for the first time.** The live `PartLocations` table (populated by the old row-index `id` scheme) had never been re-keyed to the new hash-based scheme before the first real `MERGE` ran against it — so the `MERGE`'s `ON target.id = source.id` never matched anything for existing parts, and the entire incremental batch got inserted as duplicates instead of updating in place (table briefly doubled to ~2.1M rows). Cleaned up via two passes: first removing old-scheme duplicates with a new-scheme counterpart (~1.06M rows, keeping the new-scheme row), then a second, much smaller pass (32 pairs) for parts where the *same* real part produced two different new-scheme hashes — root cause: the hash function doesn't trim whitespace, and a handful of source part numbers have incidental trailing-space variance between extracts that's real noise, not a real distinction. **Open follow-up, not urgent:** a narrowly-scoped trim-only normalization (not case-folding — that's what caused the earlier [[feedback_hash_key_normalization_masks_real_dupes]] near-miss) on the hash inputs would prevent this recurring, but wasn't safe to rush into live during this session. Needs its own careful validation pass before touching the hash function again.

Both fixes are live and proven — the pipeline's second real run (the clean 17,443-row one) produced zero duplicates and completed correctly, confirming both hold up under real operation, not just the one-time reconciliation.

### Fabric SQL Database billing model — the real root cause of the "phantom" CU spikes

Two real capacity incidents happened on 2026-08-05/06 while investigating what looked like unexplained CU spikes with no active refresh schedule running. Root cause, confirmed against Microsoft's own docs (`fabric/database/sql/usage-reporting`), not guessed:

- Fabric SQL Database bills compute per **activation event**, not per query cost. A brief trigger — even a few seconds of real work, or just a client connecting — forces the database to bill for that activity **plus a "kept online" tail** (Microsoft's own example: 2 minutes of real activity → 15 extra minutes billed, 17 total) to protect responsiveness.
- Reporting for this item type is **5-minute smoothed** in Capacity Metrics — which is exactly why every spike investigated showed as a tidy 5-consecutive-minute burst of `Sql Usage` / `SQL System` entries, regardless of how brief the real trigger was.
- The SQL Database's own Performance Dashboard explicitly disclaims that its billing doesn't reconcile with Capacity Metrics — use it to find *which query* ran, not to judge *actual CU cost*.
- **Real fix applied:** `parts-lookup-app` SQL Database's **Max vCore limit** (Settings → Compute, preview feature) was found set to **32 vCores** — roughly 20x this F4 capacity's entire ~1.5-vCore equivalent throughput, meaning this one child item could try to consume far more than the whole shared capacity has. Dropped to **2 vCores** (the lowest available option; still slightly above F4's total capacity, but the best guardrail this setting offers) as the standing limit, with a temporary bump to 4 for the one genuinely heavy one-time operation (the first full-batch merge). This is the single most important capacity guardrail from this whole investigation and should be checked on any future Fabric SQL Database in a shared capacity, not just this one.

### Pipeline notification pattern — four failure emails, not one shared

Microsoft's own docs confirm multiple `dependsOn` entries on one activity are combined with **AND** logic, not OR. The old pipeline's single shared `Failure` email activity (depending on two sequential activities both being `Failed`) is very likely dead code — in a sequential chain, if the first activity fails, the second never runs and ends up `Skipped`, not `Failed`, so the AND condition can't be satisfied in the ordinary single-point-of-failure case. `Pipeline_PartsLookup_Incremental` avoids this by giving each real activity (both dataflows, the merge script, the watermark notebook) its **own independent** single-dependency failure email, rather than funneling multiple activities into one shared node — the pattern Microsoft's docs call best practice for exactly this reason. Worth applying to the old pipeline too at some point, since its failure notification may not actually be firing.

## On Order column (added 2026-08-04)

Requested during stakeholder testing. Source: `InMaster.OS_ORDER_QTY` ("Outstanding Order Quantity" — on order with the vendor, not yet received), confirmed against the full `InMaster` column list. Distinct from `BACK_ORD_QTY`/`BO_Qty` (customer backorders) and `IN_TRANSIT_QTY` (already shipped, different signal) — if the value doesn't match what parts staff expect once live, it's a one-column swap in the raw/sync queries and merge script, not a redesign.

Threaded through every layer: both raw-pull queries (incremental and weekly-reconciliation), both sync queries, `PartLocations_Staging_Incremental`'s DDL, the `MERGE` script, an `ALTER TABLE PartLocations ADD onOrder INT NULL` on the live table, the Rayfin entity (`rayfin/data/PartLocation.ts`, nullable — same "never default an untracked quantity to 0" principle as `binQty`), and the UI (`src/pages/HomePage.tsx`, new sortable "On Order" column). App-side code changes are already committed; the Fabric-side raw/sync/merge objects and `npm run rayfin:db` / `npm run rayfin:up` still need to run (see the plan doc's Task 6.5 and Task 11).
