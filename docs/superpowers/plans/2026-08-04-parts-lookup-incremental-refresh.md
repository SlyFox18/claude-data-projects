# Parts Lookup — Incremental Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Task labels matter in this plan.** Tasks 2, 3, 4, and 7 are marked `[AUTOMATABLE]` — pure file edits in this repo that a subagent can do. Every other task is marked `[MANUAL]` — work in the Fabric portal (dataflow editor, SQL Database query editor, pipeline canvas, notebook) that has no file-based path in `data-projects` and must be done by Brian. Do not attempt to script or automate a `[MANUAL]` task. `data-projects` is a local query-library/docs workspace, not Fabric-integrated — editing a `.pq` file here does not change what's deployed; it's a reference copy that Brian pastes into the Fabric dataflow editor.

**Goal:** Cut the Parts Availability app's data-freshness ceiling from 4x/day full re-extracts (~12-13 min, ~1.1M rows moved every run) to a true watermark-based incremental pull (~10K rows/run), so refresh can run far more often without risking the F4 capacity limit again. Also add a new **On Order** quantity column end-to-end (source → live table → app UI), requested during testing.

**On Order column:** `InMaster.OS_ORDER_QTY` ("Outstanding Order Quantity" — quantity currently on purchase order with the vendor, not yet received) is the source. Confirmed via the full `InMaster` column list Brian pulled directly — distinct from `BACK_ORD_QTY`/`BO_Qty` (customer backorders) and `IN_TRANSIT_QTY` (already shipped by vendor, different signal). If this reading turns out wrong once the app is live, it's a one-line column swap in Task 2/4/6, not a redesign.

**Architecture:** New, parallel incremental path — a watermark-filtered raw pull (`df_InMaster_PartsLookup_Incremental`) feeds a sync dataflow that writes deterministic-id delta rows into a small staging table, which a pipeline Script activity then `MERGE`s (update/insert) and explicitly deletes (vendor-code-nulled rows) into the live `PartLocations` table. A notebook updates the watermark on success. The existing full-refresh objects (`df_InMaster_PartsLookup_Raw`, `df_PartsLookup_Sync`, the July 28 staging-swap mechanism) are left untouched and repurposed as a weekly reconciliation safety net — nothing new writes directly to the objects the incident-fix already stabilized.

**Tech Stack:** Fabric Dataflow Gen2 (Power Query M, ODBC source), Fabric Data Factory pipeline (Script activity, Notebook activity), Fabric SQL Database (T-SQL `MERGE`), Fabric Lakehouse (`watermark_control` table).

**Resolved design question:** See "Task 1" below — Dataflow Gen2's SQL database destination does **not** support upsert/merge natively (Append/Replace only), confirmed against Microsoft's own docs. This is why a Script-activity `MERGE` step is required; it's not a workaround, it's the only path Fabric offers for this.

**✅ RESUMED AND BUILT (2026-08-05/06)** — Tasks 1-8 (Step 1-2) all complete. The original `Value cannot be null. Parameter name: source` blocker turned out to be a real connection-wiring bug (not a capacity symptom as first suspected) — see Task 6's attempt log for the fix. A second real bug (duplicate rows from two incompatible `id` schemes meeting on the first live merge) was found and cleaned up after Task 6 first succeeded — see `ARCHITECTURE.md`'s "Status as of 2026-08-06" section for full detail on both. The pipeline has completed a fully clean, validated end-to-end run with real production data (genuine 17,443-row watermark delta, correct merge, watermark advanced, zero duplicates after). **Task 8 Step 3 (scheduling) is deliberately not done yet** — see that task below for why. Full session detail: `ARCHITECTURE.md` and memory `project_parts_lookup_tool.md`.

---

## Task 1 [RESOLVED — no action needed]: Dataflow Gen2 SQL destination upsert capability

This was the open question blocking the design in `INCREMENTAL-REFRESH-FEASIBILITY.md`. Confirmed 2026-08-04 against Microsoft Learn docs (`dataflow-gen2-data-destinations-and-managed-settings`, `slowly-changing-dimension-type-two`):

- Dataflow Gen2 destinations support exactly two update methods: **Replace** (drop + reinsert everything) and **Append** (add rows, no updates). This applies to the SQL database destination the same as every other destination type.
- Microsoft's own "Slowly changing dimension type 2" tutorial hits this identical problem and prescribes the identical workaround this plan uses: stage the changed rows via Dataflow Gen2, then run a stored procedure or notebook to actually update the destination table.
- Separately, Fabric's **Copy Job** item type *does* support native Upsert/CDC Merge — but Copy Job is a low-code copy tool without Dataflow Gen2's transform capability, and this sync needs real transform logic (the stable-id hash in Task 6). Not a fit here; noted for future reference if a future sync is closer to a pure 1:1 copy.

**Conclusion locked in for the rest of this plan:** the upsert+delete logic lives in a pipeline Script activity running T-SQL `MERGE`, staged by a plain Dataflow Gen2 Replace write into a small intermediate table — same shape as the July 28 `PartLocations_Staging` → swap fix, just with `MERGE` instead of bulk `INSERT`.

---

## Task 2 [AUTOMATABLE]: Rewrite the incremental raw-pull query

**Files:**
- Create: `.claude/queries/raw-tables/InMaster_PartsLookup_Incremental.pq`

This is a new query, not an edit to the existing `InMaster_PartsLookup_Raw.pq` (which stays untouched — it becomes the weekly-reconciliation query, see Task 11). It reads the watermark from the Lakehouse, pushes the filter into the ODBC SQL text (so filtering happens at the source, not after pulling 1.1M rows), and — critically — drops the `VENDOR_CODE IS NOT NULL` filter so vendor-code-nulled rows still flow through and can be detected/deleted downstream.

- [x] **Step 1: Write the file with this exact content** — done, and corrected 2026-08-04 after a live failure (see below).

```powerquery
/*
============================================================================
Query: InMaster_PartsLookup_Incremental
Dataflow: df_InMaster_PartsLookup_Incremental
Location: LH_Master_Data → Dataflows → 01 - Raw Sources
============================================================================

PURPOSE: Incremental (watermark-filtered) companion to InMaster_PartsLookup_Raw
for the Parts Lookup Tool (Fabric App). Pulls only rows changed since the last
successful run instead of a full ~1.1M-row extract every time. Feeds
PartsLookup_Sync_Incremental → Merge_Staging_Incremental_To_Live, NOT the old
full-replace path.

GRAIN: One row per Branch + Franchise + PartNumber (all VendorCode values,
including null — filtering by VendorCode happens downstream in the merge step,
not here, because a newly-null VendorCode is exactly the signal that tells the
merge step to delete that row from PartLocations).

SOURCE: SQL Anywhere (ODBC: EquipRDB64) — InMaster table.

WATERMARK: Read from LH_Master_Data's `watermark_control` table, row
TableName = 'InMaster_PartsLookup'. Filters on Last_Upd_Datetime (NOT
ModifiedDate — see INCREMENTAL-REFRESH-FEASIBILITY.md for why: ModifiedDate
is 35.4% null / recently-added, Last_Upd_Datetime has 0 nulls and reflects
real transaction activity once correctly joined on the true composite key).
A 30-minute overlap margin is applied defensively, same spirit as
InTrans_Incremental's Table.Distinct dedup safety net.

DO NOT MODIFY the existing InMaster.pq / InMaster_Raw.pq /
InMaster_PartsLookup_Raw.pq — those remain the full-refresh queries, now
used only for the weekly reconciliation pipeline (see ARCHITECTURE.md).

LAKEHOUSE ACCESS: uses explicit workspaceId/lakehouseId navigation, not a
bare Lakehouse.Contents(){[Name=...]} lookup — confirmed 2026-08-04 that the
bare form fails to resolve a table by name in a freshly created Dataflow
Gen2 query. Same explicit-GUID pattern as the confirmed-working
Fact_OpenOrderParts.pq.
============================================================================
*/

let
    // Step 1: Read the current watermark from the Lakehouse
    LH_Source    = Lakehouse.Contents([HierarchicalNavigation = null, EnableVorder = true, OutputMetadataRefresh = true]),
    LH_Workspace = LH_Source{[workspaceId = "b48cdb35-7ce3-46de-96df-d70db77649cb"]}[Data],
    LH_Lakehouse = LH_Workspace{[lakehouseId = "3e74497b-8c51-4a1a-91a1-888c59118f48"]}[Data],
    WatermarkTable = LH_Lakehouse{[Id = "watermark_control", ItemKind = "Table"]}[Data],
    FilterToThisTable = Table.SelectRows(WatermarkTable, each [TableName] = "InMaster_PartsLookup"),
    WatermarkRaw = FilterToThisTable{0}[LastLoadedDatetime],

    // Step 2: Defensive 30-minute overlap margin
    WatermarkWithOverlap = WatermarkRaw - #duration(0, 0, 30, 0),
    WatermarkText = DateTime.ToText(WatermarkWithOverlap, "yyyy-MM-dd HH:mm:ss"),

    // Step 3: Pull changed/new rows only. No VENDOR_CODE filter here — see header.
    SQL = "
        SELECT
            BRANCH            AS Branch,
            FRANCHISE         AS Franchise,
            PART_NO           AS PartNumber,
            PART_DESC         AS Description,
            BIN_LOCATION      AS Bin,
            SUPER_FROM        AS SuperFrom,
            SUPER_TO          AS SuperTo,
            VENDOR_CODE       AS VendorCode,
            SELL_PRICE1       AS SellPrice1,
            NOTE              AS Comments,
            ON_HAND_QTY       AS OnHandQty,
            Pending_Qty       AS PendingQty,
            OS_ORDER_QTY      AS OnOrder,
            Last_Upd_Datetime AS LastUpdDatetime
        FROM InMaster
        WHERE BRANCH NOT IN ('5', '97')
          AND Last_Upd_Datetime > '" & WatermarkText & "'
    ",

    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise
        error "Failed to connect to InMaster for Parts Lookup incremental pull. Verify ODBC connection, Last_Upd_Datetime column, and watermark_control row for 'InMaster_PartsLookup'.",

    AddBinQty = Table.AddColumn(Source, "BinQty", each [OnHandQty] - [PendingQty], Int64.Type),

    TypedTable = Table.TransformColumnTypes(AddBinQty, {
        {"Branch", type text},
        {"Franchise", type text},
        {"PartNumber", type text},
        {"Description", type text},
        {"Bin", type text},
        {"SuperFrom", type text},
        {"SuperTo", type text},
        {"VendorCode", type text},
        {"SellPrice1", type number},
        {"Comments", type text},
        {"OnHandQty", Int64.Type},
        {"PendingQty", Int64.Type},
        {"OnOrder", Int64.Type},
        {"BinQty", Int64.Type},
        {"LastUpdDatetime", type datetime}
    })
in
    TypedTable
```

- [ ] **Step 2: Note the seeding behavior (no separate step needed)**

`watermark_control` won't have an `InMaster_PartsLookup` row yet (Task 3 creates it, seeded to `2018-01-01`, safely before the earliest known `Last_Upd_Datetime`). That means the *first* run of this query naturally pulls all ~1.1M rows — functionally a one-time full reconciliation against the already-populated `PartLocations` table, done through the new incremental machinery as its own validation. No separate seed script is needed.

---

## Task 3 [MANUAL, done 2026-08-04]: Create the watermark_control row and the staging table

**Where:** Fabric — `LH_Master_Data` Lakehouse (SQL analytics endpoint or a notebook cell) for the watermark row; the Parts Lookup Fabric App's SQL Database (query editor) for the staging table.

- [x] **Step 1: Confirm `watermark_control` exists and check its current rows**

It should already exist from the `InTrans_Incremental` build (`projects/inspections - report/documentation/pipelines/phase-2-intrans-incremental.md`). Lakehouse tables aren't writable via the T-SQL endpoint, so do the insert from a notebook cell (any existing notebook with a Lakehouse attached, or a new scratch cell):

```python
spark.sql("""
    INSERT INTO watermark_control (TableName, LastLoadedDatetime, LastUpdated)
    VALUES ('InMaster_PartsLookup', TIMESTAMP('2018-01-01 00:00:00'), current_timestamp())
""")
```

- [x] **Step 2: Verify the row landed** — confirmed: `InMaster_PartsLookup | 2018-01-01 00:00:00 | 2026-08-04 14:5...`.

- [x] **Step 3: Get the real `PartLocations` schema before creating the staging table**

Pulled the actual schema instead of guessing (good thing — see Step 4's note):
```sql
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE, NUMERIC_PRECISION, NUMERIC_SCALE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'PartLocations'
ORDER BY ORDINAL_POSITION;
```

Real result: `id` uniqueidentifier NOT NULL; `branch`, `franchise`, `description`, `bin`, `superFrom`, `superTo`, `vendorCode`, `comments` all `NVARCHAR(MAX)` (branch/franchise/vendorCode NOT NULL, the rest nullable); `partNumber` `NVARCHAR(40)` NOT NULL; `sellPrice1` `DECIMAL(18,2)` NOT NULL; `binQty`/`onOrder` `INT` nullable (`onOrder` confirmed present — the Task 6.5 Rayfin migration already added it to the live table); `lastRefreshed` `DATETIME2` NOT NULL.

- [x] **Step 4: Create the staging table matching that schema exactly**

**Deliberate divergence from the live table:** `vendorCode` is `NOT NULL` on the live `PartLocations`, but the staging table must allow it to be `NULL` — that's the exact signal the `MERGE` script (Task 6) uses to detect a part that lost its vendor code and needs deleting. Copying the live constraint verbatim would break every incremental run that includes a vendor-code-nulled row.

```sql
CREATE TABLE dbo.PartLocations_Staging_Incremental (
    id            UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    branch        NVARCHAR(MAX)    NOT NULL,
    franchise     NVARCHAR(MAX)    NOT NULL,
    partNumber    NVARCHAR(40)     NOT NULL,
    description   NVARCHAR(MAX)    NULL,
    bin           NVARCHAR(MAX)    NULL,
    superFrom     NVARCHAR(MAX)    NULL,
    superTo       NVARCHAR(MAX)    NULL,
    vendorCode    NVARCHAR(MAX)    NULL,
    sellPrice1    DECIMAL(18,2)    NOT NULL,
    comments      NVARCHAR(MAX)    NULL,
    binQty        INT              NULL,
    onOrder       INT              NULL,
    lastRefreshed DATETIME2        NOT NULL
);
```

- [x] **Step 5: Verify it's empty and correctly shaped** — confirmed, all 14 columns present, 0 rows.

---

## Task 4 [AUTOMATABLE]: Rewrite the sync query with a stable id and staging destination

**Files:**
- Create: `.claude/queries/facts/PartsLookup_Sync_Incremental.pq`

The existing `PartsLookup_Sync.pq` generates `id` from a per-run row index — fine for full Replace, but wrong for incremental upserts (the same real-world row needs the *same* `id` every run, or the merge step can't recognize it as an update). This version derives `id` deterministically from `Branch + Franchise + PartNumber` (the confirmed true unique key) via two independent rolling hashes combined into a 64-bit value — collision probability across ~1.1M rows is on the order of 1 in 30 million, versus a single 48-bit hash (the old scheme's id space) which would run a meaningfully higher risk of two different parts landing on the same `id`.

- [ ] **Step 1: Write the file with this exact content**

```powerquery
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
```

- [x] **Step 2 [CORRECTED 2026-08-04 after a live production failure]: `Text.Upper(Text.Trim(...))` normalization removed from `GetStableId`.**

**What happened:** the first real run of `df_PartsLookup_Sync_Incremental` hit `Violation of PRIMARY KEY constraint... Cannot insert duplicate key`. Root cause, confirmed by direct inspection of the real 1,062,114-row `InMaster_PartsLookup_Incremental` table via DuckDB: the original `GetStableId` normalized keys with `Text.Upper(Text.Trim(...))` as a "defensive" measure — but this silently merged genuinely different InMaster rows. Example found: `PartNumber = '03-3212560 '` (trailing space, length 11) and `PartNumber = '03-3212560'` (no trailing space, length 10) are two distinct real rows for the same Branch+Franchise, with different `VendorCode`/`SellPrice1`/etc. — normalized to the identical key, they hashed to the identical `id`.

**The fix:** hash the raw `Branch|Franchise|PartNumber` values directly, no trim/uppercase. Verified two ways before shipping this correction: (1) the raw (non-normalized) grain has **zero** duplicate groups across all 1,062,114 real rows — this is the actually-validated true unique key, and matches the original feasibility investigation's own methodology, which also used raw `GROUP BY` with no `TRIM`/`UPPER`; (2) ran the exact hash arithmetic (float64, matching Power Query M's `number` type) against all 1,062,114 real keys directly — zero collisions, zero precision loss.

**Before retrying:** clear the staging table first (the failed run may have left partial rows) —
```sql
DELETE FROM dbo.PartLocations_Staging_Incremental;
```
Not `TRUNCATE` — same reasoning as the July 28 incident fix (Task 6's note below): `TRUNCATE` forces a full OneLake mirror reseed.

---

## Task 5 [MANUAL, done 2026-08-04]: Build the two new Dataflow Gen2 items in Fabric

**Where:** Fabric, `LH_Master_Data` workspace.

- [x] **Step 1: Create `df_InMaster_PartsLookup_Incremental`**

New Dataflow Gen2 in `01 - Raw Sources`. Paste the query from Task 2 (Advanced Editor) as a new query in the dataflow. Do not add a data destination for this query yet if you want to test the M logic in isolation first — but for production, add destination: Lakehouse, table `InMaster_PartsLookup_Incremental`, Update method **Replace** (this table only ever holds the current run's delta batch, consumed by the sync step immediately after).

- [x] **Step 2: Create `df_PartsLookup_Sync_Incremental`**

New Dataflow Gen2 in `04 - Fact`. Add `InMaster_PartsLookup_Incremental` (the Lakehouse table from Step 1, not the dataflow) as its data source, referenced by name — same pattern the existing `PartsLookup_Sync` uses. Paste the query from Task 4. Destination: SQL database → the Parts Lookup app's database → existing table `PartLocations_Staging_Incremental` (created in Task 3) → Update method **Replace**.

- [x] **Step 3: Publish both, run each manually once** — done. `df_InMaster_PartsLookup_Incremental` completed in 2:19 with 1,062,114 rows (confirmed via DuckDB against OneLake: `OnOrder` populated on ~90% of rows, date range 2018-02-05 → 2026-08-04, matching the original investigation exactly). Hit two real issues along the way, both fixed and the corrected code is already reflected in Task 2/4 above and the actual `.pq` files: (1) a bare `Lakehouse.Contents()` failed to resolve `watermark_control` in a freshly created dataflow — fixed by switching to explicit workspaceId/lakehouseId navigation, matching the confirmed-working pattern in `Fact_OpenOrderParts.pq`; (2) also hit an unrelated transient SQL connection failure (`10054`) while setting the destination, plausibly capacity pressure from the old pipeline's normal schedule stacking with this session's test runs — cleared after a short wait/retry.

- [x] **Step 4: Run `df_PartsLookup_Sync_Incremental` and verify staging landed** — done, after fixing a real bug (see Task 4 Step 2's correction above: hash-key normalization was merging genuinely distinct rows, causing a PRIMARY KEY violation on the first attempt). After the fix: run took 8:28, staging landed with exactly 1,062,114 rows (matches the raw incremental table exactly — no rows lost or duplicated), live `PartLocations` unchanged at 1,058,974 as expected (merge hasn't run yet).
```sql
SELECT COUNT(*) FROM dbo.PartLocations_Staging_Incremental;
-- Confirmed: 1,062,114
```

---

## Task 6 [MANUAL]: Build the merge Script activity

**Where:** Fabric pipeline canvas (new pipeline, see Task 8) — a **Script** activity pointed at the Parts Lookup app's SQL Database connection.

**Prerequisite:** Task 6.5 (below) must run first — this script references `PartLocations.onOrder`, which doesn't exist on the live table yet.

- [x] **Step 1: Create the Script activity, name it `Merge_Staging_Incremental_To_Live`**

Query type: Non-Query. Paste this T-SQL:

```sql
MERGE dbo.PartLocations AS target
USING dbo.PartLocations_Staging_Incremental AS source
ON target.id = source.id
WHEN MATCHED AND source.vendorCode IS NOT NULL THEN
    UPDATE SET
        branch        = source.branch,
        franchise     = source.franchise,
        partNumber    = source.partNumber,
        description   = source.description,
        bin           = source.bin,
        superFrom     = source.superFrom,
        superTo       = source.superTo,
        vendorCode    = source.vendorCode,
        sellPrice1    = source.sellPrice1,
        comments      = source.comments,
        binQty        = source.binQty,
        onOrder       = source.onOrder,
        lastRefreshed = source.lastRefreshed
WHEN MATCHED AND source.vendorCode IS NULL THEN
    DELETE
WHEN NOT MATCHED BY TARGET AND source.vendorCode IS NOT NULL THEN
    INSERT (id, branch, franchise, partNumber, description, bin, superFrom, superTo, vendorCode, sellPrice1, comments, binQty, onOrder, lastRefreshed)
    VALUES (source.id, source.branch, source.franchise, source.partNumber, source.description, source.bin, source.superFrom, source.superTo, source.vendorCode, source.sellPrice1, source.comments, source.binQty, source.onOrder, source.lastRefreshed);

DELETE FROM dbo.PartLocations_Staging_Incremental;
```

**Why `DELETE` and not `TRUNCATE` for the staging cleanup:** this is the exact lesson from the 2026-08-03/04 capacity incident (`INCIDENT-2026-07-28-capacity-and-refresh-fix.md` / memory `project_parts_lookup_tool.md`) — Fabric SQL Database mirroring treats `TRUNCATE` as a DDL-adjacent change and forces a full reseed of that table's OneLake mirror. `DELETE` doesn't trigger it. The staging table here is small (~10K rows steady-state) so the cost difference is minor per-run, but there's no reason to reintroduce the exact pattern that caused the original incident.

- [x] **Step 2: Test it manually once**, after Task 5's first sync run has populated staging with ~1.1M rows. Expect this first run to take noticeably longer than steady-state (it's reconciling the full table once) — that's fine, it's a one-time cost. Done 2026-08-06 — succeeded at 4 vCores (1m50s) after the connection-wiring fix.

- [x] **Step 3: Verify** — done, plus an unplanned real cleanup: found and fixed ~1.06M old-scheme duplicate rows and 32 whitespace-hash-collision pairs. See `ARCHITECTURE.md`.

```sql
SELECT COUNT(*) FROM dbo.PartLocations;                          -- should be ~1.05M, roughly unchanged from before
SELECT COUNT(*) FROM dbo.PartLocations_Staging_Incremental;      -- should be 0 (cleared by the DELETE)
```

### Attempt log (2026-08-04) — read before retrying

Step 1 (the plain `MERGE` above) failed 7 consecutive times with the identical error `Value cannot be null. Parameter name: source`, across every variation tried in order: (1) the plain `MERGE` as written above, (2) split into two script blocks (`MERGE` alone, then `DELETE FROM staging` in a separate block — Fabric's own docs recommend separate blocks for multi-statement scripts), (3) `MERGE` rewritten as three plain statements (`UPDATE`/`DELETE`/`INSERT`, shown below as a fallback), (4) same rewrite with the `source` alias renamed to `stg` throughout, (5) a brand-new Script activity built from scratch rather than editing the failing one, (6) a bare `SELECT 1 AS Test;` in Query mode — even this trivial script failed identically, proving the failure has nothing to do with script content. At that point, attempting a `dbo.Merge_PartsLookup_Staging` stored procedure (SQL below) as a Script-activity-bypass workaround, raw SQL Database connectivity itself started failing with `10054`/"connection forcibly closed by remote host" — in the plain SQL query editor, a surface that had worked reliably all session.

**Conclusion: this was very likely capacity throttling the whole time, not a Script activity bug or a `source`-alias issue.** Confirmed via Fabric Capacity Metrics: `fabric1cap1` hit 251.69% peak utilization with 27 rejected operations in the trailing 14 days, and `parts-lookup-app` (this app's own SQL Database) was the #1 CU consumer on the entire capacity. Work paused at this point rather than continuing to test against a struggling capacity — see the pause banner at the top of this doc and memory `project_parts_lookup_tool.md` ("Capacity incident #3") for full detail.

**Resolved 2026-08-05/06:** the plain `MERGE` script itself was never the problem — retrying it verbatim after a capacity-settle wait produced the *same* error, which ruled out the capacity theory. Root cause found by diffing this Script activity's exported pipeline JSON against the old, proven-working `Swap_Staging_To_Live` activity: this activity's connection was wired via a newer `connectionSettings`-wrapped binding (`type: "FabricSqlDatabase"`, missing the `database` field the working pattern has) instead of the older, working shape (top-level `externalReferences.connection` + `typeProperties.database` name string). The current Fabric portal UI defaults fresh Script activities into this broken shape — recreating from scratch (already tried, see log above) doesn't avoid it. **Fix:** rebuilt the activity reusing the same existing connection object `Swap_Staging_To_Live` uses, instead of letting it auto-create a new native connection binding. First run after the fix got past the instant failure and ran for real (1m41s) before hitting a *different*, expected error (`10054` connection reset) — confirmed as the one-time heavy reconciliation needing more than the newly-lowered 2-vCore cap; a temporary bump to 4 vCores let it complete (1m50s, succeeded). Neither the Fallback A (UPDATE/DELETE/INSERT rewrite) nor Fallback B (stored procedure) below were needed — kept in this doc for reference only, not used.

A second, separate bug surfaced only after this first successful merge: the live `PartLocations` table (populated by the *old* row-index `id` scheme) had never been re-keyed to the new hash `id` scheme, so `ON target.id = source.id` matched nothing for existing parts and the whole batch inserted as duplicates instead of updating in place. Full cleanup detail in `ARCHITECTURE.md`'s "Status as of 2026-08-06" section — not repeated here since it's a one-time historical event, not part of the ongoing script logic.

**Fallback A — plain UPDATE/DELETE/INSERT instead of MERGE** (three separate script blocks, in case MERGE itself is genuinely unsupported by the Script activity rather than this being purely a capacity symptom):
```sql
-- Block 1
UPDATE target
SET
    branch = stg.branch, franchise = stg.franchise, partNumber = stg.partNumber,
    description = stg.description, bin = stg.bin, superFrom = stg.superFrom,
    superTo = stg.superTo, vendorCode = stg.vendorCode, sellPrice1 = stg.sellPrice1,
    comments = stg.comments, binQty = stg.binQty, onOrder = stg.onOrder,
    lastRefreshed = stg.lastRefreshed
FROM dbo.PartLocations AS target
INNER JOIN dbo.PartLocations_Staging_Incremental AS stg ON target.id = stg.id
WHERE stg.vendorCode IS NOT NULL;

-- Block 2
DELETE target
FROM dbo.PartLocations AS target
INNER JOIN dbo.PartLocations_Staging_Incremental AS stg ON target.id = stg.id
WHERE stg.vendorCode IS NULL;

-- Block 3
INSERT INTO dbo.PartLocations (id, branch, franchise, partNumber, description, bin, superFrom, superTo, vendorCode, sellPrice1, comments, binQty, onOrder, lastRefreshed)
SELECT stg.id, stg.branch, stg.franchise, stg.partNumber, stg.description, stg.bin, stg.superFrom, stg.superTo, stg.vendorCode, stg.sellPrice1, stg.comments, stg.binQty, stg.onOrder, stg.lastRefreshed
FROM dbo.PartLocations_Staging_Incremental AS stg
WHERE stg.vendorCode IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.PartLocations AS target WHERE target.id = stg.id);

-- Block 4 (unchanged)
DELETE FROM dbo.PartLocations_Staging_Incremental;
```

**Fallback B — Stored Procedure activity instead of Script activity** (different activity type, different code path, in case the Script activity specifically has a platform issue):
```sql
CREATE PROCEDURE dbo.Merge_PartsLookup_Staging
AS
BEGIN
    SET NOCOUNT ON;
    -- same UPDATE / DELETE / INSERT / DELETE-staging logic as Fallback A, in one procedure body
END
```
**Not confirmed created** — connectivity failed mid-attempt on 2026-08-04. Before assuming it exists, check:
```sql
SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'Merge_PartsLookup_Staging';
```
If it partially exists, `DROP PROCEDURE dbo.Merge_PartsLookup_Staging;` first to avoid confusion, then recreate cleanly if this path is actually needed. Invoke via a pipeline **Stored procedure** activity (distinct from Script in the Activities pane), same SQL Database connection, no parameters.

---

## Task 6.5 [MANUAL]: Add `onOrder` to the live PartLocations table and app entity

**Where:** Fabric App's SQL Database query editor, then the `parts-lookup-app` repo (`c:\Users\bfox\Documents\Git-Projects\parts-lookup-app`).

This must happen **before** Task 6 Step 2 (the first real merge test) — the `MERGE` statement writes to `PartLocations.onOrder`, which doesn't exist until this runs.

- [x] **Step 1 [AUTOMATABLE, done]: Add `onOrder` to the Rayfin entity** — `rayfin/data/PartLocation.ts` already has `@int({ optional: true }) onOrder?: number;`.

- [x] **Step 2 [MANUAL, done 2026-08-04]: Apply the migration** — `npm run rayfin:db` ran successfully (config version 10, `onOrder` field detected and applied). `npx tsc --noEmit` now passes clean, confirming the typed client picked up the change.

- [ ] **Step 3 (optional spot-check): Verify the column exists in SQL directly**

```sql
SELECT TOP 5 id, partNumber, binQty, onOrder FROM dbo.PartLocations;
-- Expected: column exists, all onOrder values NULL until the next sync run populates them
```

**If `rayfin:db` did NOT add the column** (check Step 3 first before assuming this is needed), fall back to a manual `ALTER TABLE`:
```sql
ALTER TABLE dbo.PartLocations ADD onOrder INT NULL;
```
Nullable, no default — matches the `binQty` precedent (never default an untracked quantity to `0`; null means "unknown," not "definitely zero").

- [x] **Step 4 [AUTOMATABLE, done]: Add `onOrder` to the UI** — `src/pages/HomePage.tsx` already has all five spots updated (`PartLocationRow` interface, `SortableColumn` type, `COLUMNS` array, `select([...])` field list, table cell) and `npm run lint` passed clean.

- [ ] **Step 5 [MANUAL]: Deploy the app**

Correction (found 2026-08-04): `npm run rayfin:up` does not exist in this app's `package.json` — that was stale info from the README's generic starter-template scripts table, not this app's actual scripts (only `dev`, `build`, `build:fabric`, `lint`, `preview`, `test`, `rayfin:db` are defined). The real command, confirmed via `npx rayfin up --help` / `npx rayfin up staticapp --help`:

From `c:\Users\bfox\Documents\Git-Projects\parts-lookup-app`:
```bash
npx rayfin up staticapp deploy
```
This deploys just the static web app (the React UI) — the right scope since the DB change was already applied separately in Step 2. `rayfin/.env` already has the deployment target saved from the original 2026-07-20 deploy, so no workspace flags are needed. Then verify in the live app: search a part, confirm an "On Order" column appears (values will be `—` until the next incremental sync populates real numbers).

---

## Task 7 [AUTOMATABLE]: Document the watermark-update notebook logic

**Files:**
- Create: `.claude/queries/facts/Update_Watermark_PartsLookup.md`

This isn't a `.pq` file — it's the Spark SQL that goes in a Fabric notebook cell (notebooks aren't stored in this repo, per the two-repo architecture rule; this file is the reference copy for future edits, same purpose the `.pq` files serve for dataflows).

- [ ] **Step 1: Write the file with this exact content**

````markdown
# Update_Watermark_PartsLookup (Notebook)

Location: LH_Master_Data → Notebooks. Runs as the last step of
`Pipeline_PartsLookup_Incremental`, after `Merge_Staging_Incremental_To_Live`
succeeds. Mirrors the InTrans_Incremental Update_Watermark notebook pattern
(`projects/inspections - report/documentation/pipelines/phase-2-intrans-incremental.md`),
adapted for this table's TableName.

```python
max_datetime_df = spark.sql("""
    SELECT MAX(LastUpdDatetime) as MaxDatetime
    FROM InMaster_PartsLookup_Incremental
""")
max_datetime = max_datetime_df.collect()[0]['MaxDatetime']

print(f"Latest LastUpdDatetime in InMaster_PartsLookup_Incremental: {max_datetime}")

spark.sql(f"""
    UPDATE watermark_control
    SET LastLoadedDatetime = '{max_datetime}',
        LastUpdated = current_timestamp()
    WHERE TableName = 'InMaster_PartsLookup'
""")

print(f"Watermark updated to {max_datetime}")
```

**Edge case:** if a run pulls zero new rows (nothing changed since last watermark),
`InMaster_PartsLookup_Incremental` will be empty and `MAX(LastUpdDatetime)` will
be `null`. Guard against overwriting the watermark with null:

```python
if max_datetime is not None:
    spark.sql(f"""
        UPDATE watermark_control
        SET LastLoadedDatetime = '{max_datetime}',
            LastUpdated = current_timestamp()
        WHERE TableName = 'InMaster_PartsLookup'
    """)
    print(f"Watermark updated to {max_datetime}")
else:
    print("No new rows this run — watermark left unchanged")
```
````

- [x] **Step 2 [MANUAL]: Build the actual notebook in Fabric** using the guarded version from Step 1. Name it `Update_Watermark_PartsLookup`. Test it manually once against the current state (watermark should update to a recent timestamp, not stay at `2018-01-01`). Done 2026-08-06 — built as a `%%sql` cell (matching the actual `Update_InTrans_Watermark` convention already in the workspace, not the more verbose Python form originally sketched in this doc's Step 1; the `.md` reference file has been updated to match). Confirmed correctly attached to `LH_Master_Data`, and confirmed **not** the same object as `Parts_Availability_App_WaterMark` (that one is the Task 3 one-time seed script — reusing it would have reset the watermark every run). Tested successfully twice: once in isolation (advanced to `2026-08-04T10:18:54Z`), once as the last step of a full real pipeline run (advanced to `2026-08-06T12:40:57Z`).

---

## Task 8 [MANUAL]: Assemble and schedule the new pipeline

**Where:** Fabric pipeline canvas, `LH_Master_Data` workspace.

- [x] **Step 1: Create `Pipeline_PartsLookup_Incremental`**, sequence:
  1. `df_InMaster_PartsLookup_Incremental` (Dataflow Gen2 activity)
  2. Wait (30-60s — same pattern as the existing pipeline, lets the Lakehouse commit before the next dataflow reads it)
  3. `df_PartsLookup_Sync_Incremental` (Dataflow Gen2 activity)
  4. Wait (30-60s — same reasoning, before the Script activity touches the SQL Database)
  5. `Merge_Staging_Incremental_To_Live` (Script activity, from Task 6)
  6. `Update_Watermark_PartsLookup` (Notebook activity, from Task 7)
  - Chain each step on **Success**. Add the same success/failure email notification pattern the existing `InMaster_PartLookUp → Wait → PartLookUp_Sync` pipeline already uses.
  - **Built 2026-08-06, with one deliberate deviation from "same pattern as the existing pipeline":** instead of one shared failure email fed by multiple activities (which Microsoft's docs confirm combines with AND logic, not OR — meaning the old pipeline's shared failure email likely never actually fires in a normal single-point-of-failure case, since a failed upstream activity leaves downstream activities `Skipped` rather than `Failed`), this pipeline gives each of the four real activities its own independent single-dependency failure email. Five email activities total instead of two. See `ARCHITECTURE.md`.

- [x] **Step 2: Run it manually end-to-end once** and confirm all 6 steps succeed in order. Done 2026-08-06 — clean run, all 7 activities (6 + success email) green. Verified: real 17,443-row watermark-filtered delta (not a full re-pull), `PartLocations` count moved by a small sensible amount (+761), staging cleared to 0, watermark advanced correctly, zero duplicate parts.

- [ ] **Step 3: Schedule conservatively at first** — **deliberately not done yet, as of 2026-08-06.**

Per the 2026-08-04 incident finding, don't jump straight to an aggressive cadence. Start at the same 4x/day times the old pipeline used (7:45 AM, 10:00 AM, 2:00 PM, 4:00 PM) and confirm several clean runs with the SQL Database's Performance Dashboard showing low CPU cost before tightening further (e.g., hourly).

**Brian's explicit decision (2026-08-06):** even though the pipeline is proven correct, there's no clean baseline yet for what it actually costs in CU, because every manual run so far happened alongside other Fabric activity (validation queries, portal poking) that muddies the reading — and two real capacity incidents happened during this build. Plan: (1) one manual run done in isolation, nothing else touching Fabric at the same time, to get a real clean cost reading; (2) if that looks fine, schedule once daily at an off-peak time and observe; (3) if still fine, gradually increase toward the 4x/day target above. Do not schedule 4x/day directly from here, regardless of how the earlier urgency felt — that urgency is exactly why this needs a real baseline first.

---

## Task 9 [MANUAL]: Repurpose the old full-refresh pipeline as weekly reconciliation

**Where:** Fabric pipeline canvas — the existing `InMaster_PartLookUp → Wait → PartLookUp_Sync` (→ swap) pipeline.

**Status 2026-08-06: Steps 2 and 3 (the `.pq` updates) are done — confirmed still in place in both files. Step 1 (the actual trigger change) has not been done yet** — intentionally left alone while the new incremental pipeline is still in its cautious, not-yet-scheduled validation phase (see Task 8 Step 3). The old pipeline is still running its original 4x/day schedule for now, which is fine as a stopgap since it's a known-working mechanism, just not the end state.

- [ ] **Step 1: Change its trigger from 4x/day to weekly**, off-hours (matches this org's existing Tier 3 convention — Monday 5 AM, same slot as Price Matrix / Bin Location). This is the safety net described in `INCREMENTAL-REFRESH-FEASIBILITY.md` — catches anything the watermark might silently miss (clock skew, a write path that doesn't bump `Last_Upd_Datetime`). **Do this only after the new incremental pipeline has an actual schedule and has proven itself over a few real cycles** — don't pull the old safety net away before the new mechanism is trusted.

- [x] **Step 2: Update `InMaster_PartsLookup_Raw.pq`'s header comment and add `OnOrder`**

Open the existing file and fix the grain line, per the feasibility doc's load-bearing correction:

Change:
```
GRAIN: One row per Branch + PartNumber (all franchises, VendorCode not null only)
```
To:
```
GRAIN: One row per Branch + Franchise + PartNumber (VendorCode not null only).
Note: this is the weekly full-reconciliation path only as of 2026-08 — see
InMaster_PartsLookup_Incremental.pq for the 4x/day incremental path that
actually keeps PartLocations current.
```

Then add `OS_ORDER_QTY AS OnOrder` to the `SELECT` list (same column as the incremental path, Task 2) and `{"OnOrder", Int64.Type}` to the `Table.TransformColumnTypes` call. **This is required, not optional** — this pipeline still runs weekly (Task 9 above) and does a full `Replace` write straight to `PartLocations` via the existing swap mechanism. If `onOrder` isn't selected here too, every weekly reconciliation run will null out the column for all ~1.05M rows until the next incremental run repopulates it.

- [x] **Step 3: Update `PartsLookup_Sync.pq`'s rename/select lists**

Same reasoning — add `{"OnOrder", "onOrder"}` to `Table.RenameColumns` and `"onOrder"` to the final `Table.SelectColumns` list, mirroring Task 4's incremental version.

---

## Task 10 [MANUAL]: First-run validation

**Where:** Fabric SQL Database query editor + LH_Master_Data.

- [x] **Step 1: Confirm no data loss vs. the old mechanism.** Right after Task 8 Step 2's first end-to-end run:
```sql
SELECT COUNT(*) FROM dbo.PartLocations;
```
Compare against the row count the old full-replace pipeline was producing (~1.05M, per the incident doc). Should be in the same ballpark — this run is effectively a full reconciliation since the watermark started at 2018-01-01.

**Done, across two runs, 2026-08-06:** the first real merge (the full-batch reconciliation, watermark still at its 2018-01-01 seed) landed at 1,059,058 after cleanup — in the expected ballpark, and the id-scheme duplicate cleanup (see Task 6 / `ARCHITECTURE.md`) is exactly what got it there cleanly. The second run (a genuine small incremental delta, watermark already advanced) moved the count to 1,059,819 — a sensible +761, not another large jump, and zero duplicates both times. No data loss found at either point. **Remaining open item, not yet done:** the isolated, no-other-activity capacity baseline test Brian is doing separately before scheduling (see Task 8 Step 3) — that's the last piece of real validation left, and it's about capacity cost, not correctness.

- [ ] **Step 2: Spot-check that updates actually update, not just insert.** Pick a part you can find in `InMaster` via SQL Anywhere, note its `SELL_PRICE1`, wait for a source-side value to change naturally (or coordinate a controlled test change if you have write access), then run the pipeline again and confirm `PartLocations.sellPrice1` reflects the new value without a duplicate row appearing (same `id` before and after).

- [ ] **Step 3: Spot-check the delete path.** Find a part currently in `PartLocations` (has a `vendorCode`), confirm via SQL Anywhere whether its `VENDOR_CODE` is still populated. If you can identify or simulate a part losing its vendor code, confirm after the next incremental run that its row is gone from `PartLocations` (not just null-vendorCode — actually removed, matching the old full-replace behavior where vendor-code-null rows never appeared at all).

- [ ] **Step 4: Verify search still works in the live app** — open Parts Availability, search for a part you just confirmed is in `PartLocations`, confirm it returns results with the index from the July 28 fix still functioning (query should be fast, not a full scan).

- [ ] **Step 5: Verify On Order values look right.** Pick a part you know is currently on order from a vendor (ask a parts manager if you don't know one offhand), confirm its `OS_ORDER_QTY` in `InMaster` via SQL Anywhere, and confirm the same number shows in the app's "On Order" column after the next sync. If the numbers don't match what parts staff expect "on order" to mean, that's the signal `OS_ORDER_QTY` was the wrong column — swap it for `IN_TRANSIT_QTY` or another candidate in Tasks 2/4/6/9 rather than trying to reinterpret `OS_ORDER_QTY`'s meaning.

---

## Task 11 [AUTOMATABLE]: Update documentation

**Files:**
- Modify: `projects/parts lookup tool - app/ARCHITECTURE.md`
- Modify: `projects/parts lookup tool - app/INCREMENTAL-REFRESH-FEASIBILITY.md`

- [ ] **Step 1: Add a new section to `ARCHITECTURE.md`** documenting the two parallel paths (incremental 4x/day+ vs. weekly reconciliation), the new object names (`df_InMaster_PartsLookup_Incremental`, `df_PartsLookup_Sync_Incremental`, `PartLocations_Staging_Incremental`, `Merge_Staging_Incremental_To_Live`, `Update_Watermark_PartsLookup`, `Pipeline_PartsLookup_Incremental`), the stable-id hash scheme replacing the old row-index scheme for this path, and the new `onOrder` column (source: `InMaster.OS_ORDER_QTY`, added 2026-08-04 per stakeholder testing feedback).

- [ ] **Step 2: Update `INCREMENTAL-REFRESH-FEASIBILITY.md`'s "Effort / scope estimate" section** — mark item 1 (confirm Dataflow Gen2 upsert capability) resolved with the finding from Task 1, and note the plan doc (`docs/superpowers/plans/2026-08-04-parts-lookup-incremental-refresh.md`) as where the design became concrete.

- [ ] **Step 3: Commit**

```bash
git add ".claude/queries/raw-tables/InMaster_PartsLookup_Incremental.pq" \
        ".claude/queries/facts/PartsLookup_Sync_Incremental.pq" \
        ".claude/queries/facts/Update_Watermark_PartsLookup.md" \
        ".claude/queries/raw-tables/InMaster_PartsLookup_Raw.pq" \
        "projects/parts lookup tool - app/ARCHITECTURE.md" \
        "projects/parts lookup tool - app/INCREMENTAL-REFRESH-FEASIBILITY.md" \
        "docs/superpowers/plans/2026-08-04-parts-lookup-incremental-refresh.md"
git commit -m "docs: add Parts Lookup incremental refresh design (query library + plan)"
```

---

## Self-Review Notes

- **Spec coverage:** every open item from `INCREMENTAL-REFRESH-FEASIBILITY.md`'s 7-step effort estimate has a task here — (1) upsert capability → Task 1, (2) watermark_control entry → Task 3, (3) raw query rewrite → Task 2, (4) sync query rewrite (stable id + upsert/delete) → Task 4 + Task 6, (5) pipeline build → Task 8, (6) initial historical load → folded into Task 2/5 (watermark seeded old, first run reconciles naturally — no separate seed script needed), (7) testing → Task 10.
- **Deviation from the feasibility doc worth flagging to Brian explicitly:** the doc assumed the existing dataflows/pipeline would be *modified* in place. This plan instead builds parallel new objects (`_Incremental` suffix) and leaves the existing full-refresh objects untouched, repurposed for weekly reconciliation. Safer (no risk to the already-stabilized July 28 fix) but means more Fabric objects to maintain going forward — worth a quick nod of agreement before Task 5 starts creating things.
