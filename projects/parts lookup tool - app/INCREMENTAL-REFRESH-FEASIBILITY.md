# Parts Lookup — Incremental Refresh Feasibility & Design (Investigated 2026-07-28)

Internal reference doc — not the stakeholder version. Captures what was found, why, and what building this for real would involve. Investigation grew out of the 2026-07-28 capacity incident (see `INCIDENT-2026-07-28-capacity-and-refresh-fix.md`) — that fix addressed the sync's DELETE-based rewrite of the live table, but `InMaster_PartsLookup_Raw` / `df_PartsLookup_Sync` still do a full ~12-minute extract-and-reload from the ODBC source every run. This doc is about eliminating *that* remaining cost, to make hourly-or-better refresh realistic.

## Current state (baseline, post 2026-07-28 fixes)

- `InMaster_PartLookUp` (raw extract): ~3m24s-3m44s per run, full extract of ~1.1M rows every time, no filtering by recency.
- `PartLookUp_Sync`: ~8m37s per run, full transform + write of the same ~1.1M rows into `PartLocations_Staging`.
- Swap into live `PartLocations`: ~30-60s (today's fix — see incident doc).
- Total per-run cost: ~12-13 minutes, 4x/day. The expensive part (source extract + transform) is untouched by anything done on 2026-07-28.

## Investigation goal

Can `InMaster_PartsLookup_Raw` become a true incremental pull (only changed/new rows) instead of a full re-extract every run? If yes, per-run cost should drop by roughly the same order of magnitude `InTrans_Incremental` already achieved on a comparable table (see `projects/inspections - report/documentation/pipelines/phase-2-intrans-incremental.md`: 97% faster, 90% CU reduction, full refresh 8.3M rows/16-18min → incremental ~7K rows/1-2min).

## Findings

### Candidate watermark columns

`InMaster` has two datetime-tracking columns not currently used by the raw pull: `Last_Upd_Datetime` and `ModifiedDate`.

| Column | Nulls | Date range | Verdict |
|---|---|---|---|
| `Last_Upd_Datetime` | 0 / 1,101,554 | 2018-02-05 → present (real-time) | **Use this one** |
| `ModifiedDate` | 389,891 (35.4%) | 2026-03-24 → present | Reject — clearly a recently-added/never-backfilled column |

### Change volume

~10,668 of 1,101,554 rows (`~0.97%`) had `Last_Upd_Datetime` in the last 24 hours. An incremental pull would move roughly **1% of what a full refresh moves today** — directly comparable to (better than) `InTrans_Incremental`'s own 99.9% row reduction.

### Watermark reliability — initially looked shaky, resolved

First pass: joined recent `InTrans` transactions to `InMaster` on `BRANCH + PART_NO` and compared `Trans_Datetime` to `Last_Upd_Datetime`. Most of ~150 sampled rows correlated within single-digit minutes — but two showed the InMaster timestamp stuck 12 and 44 days in the past despite a same-day transaction.

**Root cause, confirmed by direct query: `BRANCH + PART_NO` is not unique in `InMaster`.**
```sql
-- Returns many rows (duplicates exist):
SELECT BRANCH, PART_NO, COUNT(*) FROM InMaster WHERE VENDOR_CODE IS NOT NULL
GROUP BY BRANCH, PART_NO HAVING COUNT(*) > 1

-- Returns zero rows (true key):
SELECT BRANCH, FRANCHISE, PART_NO, COUNT(*) FROM InMaster WHERE VENDOR_CODE IS NOT NULL
GROUP BY BRANCH, FRANCHISE, PART_NO HAVING COUNT(*) > 1
```
**True unique key of `InMaster` is `Branch + Franchise + PartNumber`.** The two "stale" outliers were the test query joining a real transaction to the wrong physical row (a stale, unrelated duplicate sharing the same Branch+PartNumber but different Franchise). Once matching on the correct composite key, `Last_Upd_Datetime` tracks real transactions reliably.

This is a load-bearing finding for the design below, independent of the incremental question: `InMaster_PartsLookup_Raw`'s existing header comment says grain is "Branch + PartNumber" — that's not actually true; it should read Branch + Franchise + PartNumber. Worth fixing that comment regardless of whether incremental gets built.

## Design for implementation

Follow the proven `InTrans_Incremental` / `watermark_control` pattern (documented in `phase-2-intrans-incremental.md`) as the template, adapted for the fact that `InMaster` is a mutable master table (rows get updated/removed) rather than an append-only transaction log.

### 1. Watermark tracking
Add a row to (or create, if scoped separately from InTrans) the `watermark_control` table for `InMaster_PartsLookup`:
```sql
INSERT INTO watermark_control (TableName, LastLoadedDatetime, LastUpdated)
VALUES ('InMaster_PartsLookup', <initial MAX(Last_Upd_Datetime)>, GETDATE())
```
Same read/update mechanics as `InTrans_Incremental`'s watermark: read before the pull, update after a successful load (via a small notebook step, same as `Update_Watermark` there).

### 2. Source query changes (`InMaster_PartsLookup_Raw.pq`)
- Filter `WHERE Last_Upd_Datetime > @watermark` instead of full extract.
- **Remove the `VENDOR_CODE IS NOT NULL` filter from the extraction query.** This is the key change that makes deletion handling work — see below. Vendor-code filtering moves downstream into the sync step's upsert/delete decision.
- Add a small overlap margin when computing the watermark cutoff (e.g., re-pull the last 15-30 minutes in addition to the true watermark) as a defensive buffer, same spirit as `InTrans_Incremental`'s `Table.Distinct` dedup safety net — cheap insurance against edge-of-window misses.
- Fix the grain comment to Branch + Franchise + PartNumber.

### 3. Sync logic changes (`PartsLookup_Sync.pq` + destination)
This is the biggest structural change. `InTrans_Incremental` gets to use simple **Append** because it's a log (nothing ever needs updating or deleting). Parts Lookup can't — the same real-world Branch+Franchise+PartNumber row needs to be *updated* when it changes, and *removed* when vendor code goes null. Two parts:

- **Stable `id` generation.** Current sync generates `id` from a per-run row index — fine for full-Replace (whole table gets fresh IDs every run), but breaks incremental upserts (the same logical row would get a new `id` every run instead of updating its existing one). Replace with a deterministic id derived from a hash of `Branch + Franchise + PartNumber`, so the same real-world row always maps to the same `id` across every incremental run.
- **Upsert + delete, not Replace.** For rows where `VendorCode` is populated: upsert into `PartLocations` keyed on the new stable `id`. For rows where `VendorCode` is now null (part lost its vendor code since last watermark): explicitly delete that `id` from `PartLocations`.
- **Open technical question to verify before building:** does Dataflow Gen2's native SQL database destination support a true "Update"/merge-by-key write mode, or only Replace/Append? If it only offers those two, the upsert+delete logic would need to move into a Script/Stored-procedure pipeline step (a `MERGE` statement keyed on `id`, plus a separate `DELETE WHERE id IN (...)` for vendor-code-nulled rows) similar to how the swap step from today's fix works. Check this first — it determines whether the sync stays a pure Dataflow Gen2 change or needs a pipeline-activity rework like today's.

### 4. Safety net
Keep a periodic **full reconciliation** run regardless of how well the watermark performs — weekly or nightly, off-hours. Same defensive posture `InTrans_Incremental` takes with its `Table.Distinct` dedup despite the design "shouldn't" need it. This catches anything a watermark edge case might silently miss (clock skew, a write path that doesn't bump `Last_Upd_Datetime`, etc.) without needing the whole system to be perfectly proven correct on day one.

## Expected impact

Based on `InTrans_Incremental`'s own real, measured precedent on a comparably-sized table:

| Metric | Current (full extract) | Projected (incremental) |
|---|---|---|
| Rows moved per run | ~1.1M | ~10K (change volume observed) or less for shorter intervals |
| Raw extract duration | ~3.5 min | likely <1 min |
| Sync/transform duration | ~8.5 min | likely 1-2 min |
| Refresh frequency ceiling | 4x/day (capacity-constrained) | hourly or more, plausible |

Not a promise — `InTrans_Incremental` is append-only and simpler than what Parts Lookup needs (true upsert+delete adds real complexity the InTrans case never had to solve) — but the row-volume reduction driving the savings is the same underlying mechanism, and the ~1% daily change rate here is comparable to or better than InTrans's own ~0.1% (7K/8.3M).

## Effort / scope estimate

This is a real project, not a config change:
1. **RESOLVED 2026-08-04:** Dataflow Gen2's SQL destination does not support native upsert/merge — Append/Replace only, confirmed against Microsoft Learn docs. Upsert+delete logic lives in a pipeline Script activity running T-SQL `MERGE`, as this item anticipated. Full concrete design in `docs/superpowers/plans/2026-08-04-parts-lookup-incremental-refresh.md` (in `data-projects`) — that plan is now the authoritative build reference; this doc remains the investigation record.
2. Add `watermark_control` entry + read/update mechanics (small, mirrors existing InTrans pattern closely).
3. Rewrite `InMaster_PartsLookup_Raw.pq` — watermark filter, remove vendor-code filter, fix grain comment.
4. Rewrite `PartsLookup_Sync.pq` — stable id generation, upsert/delete logic instead of Replace.
5. Build/adjust the pipeline to support the new components (possibly a new Script or Notebook activity depending on point 1).
6. Initial full historical load (same as InTrans's Step 2 in its initial-load process) to seed `PartLocations` before switching over to incremental going forward.
7. Testing: verify upserts update correctly, verify vendor-code-nulled rows actually get deleted, verify the reconciliation safety net catches injected discrepancies.

Not something to slot into a single session — worth scoping as its own follow-on piece of work once you're ready to pick it up.
