# Parts Availability — Capacity Issue & Fix (2026-07-28)

## What you experienced

- Searches were noticeably slow (up to ~20 seconds).
- At least one search returned an error: *"Unable to complete the action because your organization's Fabric compute capacity has exceeded its limits. Try again later."*

## What caused it

Two separate issues, both addressed today:

1. **Missing search index.** The database behind Parts Availability had no index on part number, so every search scanned all ~1.05 million rows in the table to find matches. This got slower as more people searched at the same time.
2. **Inefficient refresh process.** The scheduled data refresh (4x/day) rebuilt the entire parts table from scratch every run — deleting all ~1.05 million rows and reinserting them one at a time. That's an expensive operation on our shared Fabric capacity, and combined with normal background activity already running today, it pushed the capacity over its limit and triggered the hard error above.

## What we did about it (today)

1. **Added a proper index on part number.** Searches now go straight to matching rows instead of scanning the whole table. Confirmed working via the database's own query statistics.
2. **Replaced the delete-and-rebuild refresh with a lighter swap method.** New data is now staged separately, then swapped into the live table almost instantly, instead of deleting the live table first and rebuilding it row by row.
3. **Automated the new process into the existing refresh pipeline**, so it runs unattended going forward — no manual steps needed for future refreshes.

## Where things stand

- App performance is back to fast and normal.
- The refresh schedule was intentionally paused for part of today while we implemented and tested these changes; it's being validated and returned to its normal automated schedule as part of this fix.
- Doing this now, during testing with a small group, was much better than hitting it later after a wider rollout.

## Confirmed impact (query-level evidence)

Before (from the SQL Database's own Performance Dashboard, prior to today's fix):
- `delete [dbo].[PartLocations]` — ran directly against the **live** table — 19 executions/30 days, 49,286.83 ms total CPU, ~2,594 ms average per execution, contending with every concurrent search for the duration of the whole refresh.

After (same dashboard, post-fix):
- The `delete [dbo].[PartLocations]` line against the live table **no longer appears at all**.
- The dataflow's delete step now runs against the disposable staging table only (`delete [dbo].[PartLocations_Staging]`, 2,895.43 ms) — same underlying step, but it can no longer contend with real searches.
- `TRUNCATE TABLE dbo.PartLocations` (the new live-table reset) doesn't even register in the high-CPU query list — negligible cost, as expected.
- The live table is now only touched for one clean bulk copy (`INSERT INTO dbo.PartLocations SELECT * FROM dbo.PartLocations_Staging`, ~25.5s CPU, ~30-60s wall time), instead of being live-rewritten for the entire multi-minute refresh.

Net effect: moving ~1.05M rows still costs real compute somewhere, so this isn't "free" — but the expensive part no longer happens against the table people are actively searching, and the live table's exposure window per refresh dropped from several minutes to under a minute.

## One more thing worth flagging

Even before today, this app's database was already one of the top consumers of our shared Fabric capacity (F4) over the past two weeks. As usage grows to more locations, it's worth a conversation about increasing that capacity headroom — happy to put together the specifics whenever that's useful.
