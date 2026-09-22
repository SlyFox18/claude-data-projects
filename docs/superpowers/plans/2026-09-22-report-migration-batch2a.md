# Report Migration Batch 2a Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repoint 3 reports (Open Work Orders, Pin Capture, Part Sales with Low Margin) from `LH_Master_Data` to `DP_Presentation`, renaming a handful of raw-table `Item=` references to their real Silver shortcut names along the way, and fixing 2 real `DateTime.LocalNow()` bugs found during investigation.

**Architecture:** All 3 reports are already published as-is to `RP - Dev` and confirmed closed in Desktop, so this is pure TMDL editing — no waiting on a publish step. Per report: exhaustive real-usage audit (`pbir` + DAX-text grep), repoint the SQL connection, rename `Item=` values where the underlying table is now a Silver shortcut under a different name, fix any `DateTime.LocalNow()` instance, trim per the audit's findings, commit.

**Tech Stack:** Power BI Desktop (`.pbip`/TMDL text format), `pbir` CLI, DuckDB + `delta_scan()` for verification, Fabric Git integration.

**Full design reference:** `docs/superpowers/specs/2026-09-21-report-migration-batch2a-design.md` (approved).

---

## Context You Need

All 3 reports live in `fabric-workspace-docs/workspaces/RP - Dev/`. **Real connection strings** (used throughout this whole project):
- Old: `Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data")`
- New: `Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation")`

**Real `Item=` renames needed** (raw table name → its real Silver shortcut name in `DP_Presentation`, confirmed via `fab ls` this session):
- `WKROFILE` → `Silver_WkRoFile`
- `TechnicianPunchedDetail` → `Silver_TechnicianPunchedDetail`
- `RepairOrderDetail` → **no rename** (shortcut kept this exact name)
- `InTrans_Incremental` → `Silver_InTrans`
- `wkothsub` → `Silver_WkOthSub`
- `InMaster` → `Silver_InMaster` (shortcut added and verified live this session)
- `jdis_Part_Information` → `Silver_PartInformation` (same rename already used for Parts Adjustments in Batch 1)

**2 real `DateTime.LocalNow()` bugs found during investigation** (both already wrapped in `DateTime.From(...)`, so — unlike Price Matrix — there's no Date-vs-DateTime type-mismatch risk here, just the plain UTC-not-local bug):
- `Pin Capture/Fact_PinTransactions.tmdl:315`: `TwoYearsAgo = DateTime.From(Date.AddMonths(Date.StartOfMonth(DateTime.Date(DateTime.LocalNow())), -24))`, used inside `Table.SelectRows(dbo_InTrans_Incremental, each [TransDatetime] >= TwoYearsAgo)` — a live SQL-backed filter, same shape that caused Price Matrix's query-folding issue, so verify carefully after the fix.
- `Part Sales with Low Margin/Fact_InTrans.tmdl:289`: `[TransDatetime] >= DateTime.From(Date.AddYears(DateTime.Date(DateTime.LocalNow()), -2))`, same live-filter shape.

**Real-tool boundary:** all 3 reports are already published to `RP - Dev` and confirmed not open in Desktop — Claude edits the TMDL directly (Tasks 1-3). Running the Fabric notebook is not needed for this batch (no new Gold-layer builds). Brian's Desktop refresh/publish/visual-confirm is a separate task (Task 5) — Claude does not drive Desktop.

---

### Task 1: Repoint Open Work Orders

**Files:**
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Open Work Orders.SemanticModel/definition/tables/Fact_OpenWorkOrders.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Open Work Orders.SemanticModel/definition/tables/dim_BranchLocation.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Open Work Orders.SemanticModel/definition/tables/dim_CustomerList.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Open Work Orders.SemanticModel/definition/tables/dim_DateTable.tmdl`

- [ ] **Step 1: Exhaustive real-usage audit**

```bash
export PATH="$HOME/.local/bin:$PATH"
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs/workspaces/RP - Dev"
pbir fields list "Open Work Orders.Report"
```

Then, for the DAX-side half (this is the check that already caught 2 real gaps this session — do not skip it):

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs/workspaces/RP - Dev/Open Work Orders.SemanticModel/definition"
for tbl in Fact_OpenWorkOrders dim_BranchLocation dim_CustomerList dim_DateTable dim_Technician_Code_Names; do
  echo "=== $tbl ==="
  grep -rohE "'?${tbl}'?\[[A-Za-z0-9_%]+\]" tables/*.tmdl relationships.tmdl 2>/dev/null \
    | sed -E "s/'?${tbl}'?\[([A-Za-z0-9_%]+)\]/\1/" | sort -u
done
```

Record findings: which columns on `dim_BranchLocation`/`dim_CustomerList`/`dim_DateTable` are genuinely used (candidates to keep) vs. not (candidates to trim, matching the same trim discipline already used in Batch 1 — but only trim if you're confident, don't guess). `dim_Technician_Code_Names` is in scope too even though it wasn't in the original 4-table list — check whether it's a real data table needing its own repoint (it has a `Sql.Database`/`Item=` reference per the earlier investigation this session, same standard repoint pattern).

- [ ] **Step 2: Repoint `Fact_OpenWorkOrders.tmdl` and rename 2 of its 3 `Item=` references**

Find:
```
				    SqlEndpoint = "xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com",
				    DatabaseName = "LH_Master_Data",

				    // RepairOrderDetail - Core work order data (open orders only)
				    RepairOrderDetail =
				        let
				            Source = Sql.Database(SqlEndpoint, DatabaseName),
				            ROD = Source{[Schema = "dbo", Item = "RepairOrderDetail"]}[Data],
				            // Filter to open work orders only (not invoiced)
				            OpenOnly = Table.SelectRows(ROD, each [StatusDisplay] <> "Invoiced")
				        in
				            OpenOnly,

				    // WKROFILE - Work order master data (customer account, payment method)
				    WKROFILE =
				        let
				            Source = Sql.Database(SqlEndpoint, DatabaseName),
				            WKR = Source{[Schema = "dbo", Item = "WKROFILE"]}[Data]
				        in
				            WKR,

				    // TechnicianPunchedDetail - Technician and equipment info
				    TechnicianPunched =
				        let
				            Source = Sql.Database(SqlEndpoint, DatabaseName),
				            TPD = Source{[Schema = "dbo", Item = "TechnicianPunchedDetail"]}[Data],
```
Replace with:
```
				    SqlEndpoint = "xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com",
				    DatabaseName = "DP_Presentation",

				    // RepairOrderDetail - Core work order data (open orders only)
				    RepairOrderDetail =
				        let
				            Source = Sql.Database(SqlEndpoint, DatabaseName),
				            ROD = Source{[Schema = "dbo", Item = "RepairOrderDetail"]}[Data],
				            // Filter to open work orders only (not invoiced)
				            OpenOnly = Table.SelectRows(ROD, each [StatusDisplay] <> "Invoiced")
				        in
				            OpenOnly,

				    // WKROFILE - Work order master data (customer account, payment method)
				    // Repointed to the Silver_WkRoFile shortcut (2026-09-22)
				    WKROFILE =
				        let
				            Source = Sql.Database(SqlEndpoint, DatabaseName),
				            WKR = Source{[Schema = "dbo", Item = "Silver_WkRoFile"]}[Data]
				        in
				            WKR,

				    // TechnicianPunchedDetail - Technician and equipment info
				    // Repointed to the Silver_TechnicianPunchedDetail shortcut (2026-09-22)
				    TechnicianPunched =
				        let
				            Source = Sql.Database(SqlEndpoint, DatabaseName),
				            TPD = Source{[Schema = "dbo", Item = "Silver_TechnicianPunchedDetail"]}[Data],
```

Note `RepairOrderDetail`'s own `Item=` line is unchanged — its shortcut kept the same name.

- [ ] **Step 3: Repoint `dim_BranchLocation.tmdl`, `dim_CustomerList.tmdl`, `dim_DateTable.tmdl`**

In each file, find:
```
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
```
Replace with:
```
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation"),
```
No `Item=` changes in any of these 3 files.

- [ ] **Step 4: Repoint `dim_Technician_Code_Names.tmdl` if Step 1 confirmed it's a real data table**

Same connection-string swap as Step 3, applied to this file too (confirm its `Item=` value first — expected to be `dim_Technician_Code_Names`, already existing under that exact name in `DP_Presentation`, no rename needed, but verify against Step 1's findings before assuming).

- [ ] **Step 5: Trim any genuinely-unused columns Step 1 found, with matching `Table.SelectColumns` M-query pins**

Only if Step 1's audit found real, confident trim candidates — don't trim speculatively. If trimming, add a `Table.SelectColumns` step to that table's M query listing exactly the kept columns (the Batch 0 lesson: a TMDL-only trim doesn't survive a Desktop refresh), and check for any `sortByColumn` that might now dangle (the real bug already found and fixed once this session on Price Matrix's `dim_BranchLocation`).

- [ ] **Step 6: Confirm no `LH_Master_Data` references remain**

```bash
grep -rn "LH_Master_Data" "workspaces/RP - Dev/Open Work Orders.SemanticModel/"
```
Expected: no output.

- [ ] **Step 7: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/RP - Dev/Open Work Orders.SemanticModel/definition/tables/"*.tmdl
git commit -m "Repoint Open Work Orders to DP_Presentation

WKROFILE and TechnicianPunchedDetail renamed to their real Silver
shortcut names (Silver_WkRoFile, Silver_TechnicianPunchedDetail).
RepairOrderDetail's shortcut kept its original name.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

**Real finding (Task 1's audit):** `dim_DateTable` in Open Work Orders is genuinely orphaned — zero columns referenced by any DAX measure or visual, AND (unlike the `dim_DateTable`-is-just-join-key-unused pattern found on Price Matrix) zero relationship object anywhere in `relationships.tmdl` connects to it at all. Confirmed via `pbir` + full DAX-text grep, independently re-verified by the spec reviewer. Deliberately left fully untrimmed (repoint only) rather than trimmed or removed — whether the whole table should be dropped is a real scope decision for Brian, not a column-trim call. An in-file marker comment was added (commit `dfe7b3b8`) so this doesn't require re-discovery later. Also found and fixed: `dim_CustomerList` trims to a single column (`AccountNumberText`, its only real use — the relationship key), confirmed via code-quality review this is a normal, well-supported pattern, not a structural concern.

---

### Task 2: Repoint Pin Capture and fix its `DateTime.LocalNow()` bug

**Files:**
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Pin Capture.SemanticModel/definition/tables/Fact_PinTransactions.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Pin Capture.SemanticModel/definition/tables/dim_BranchLocation.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Pin Capture.SemanticModel/definition/tables/dim_CustomerList.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Pin Capture.SemanticModel/definition/tables/dim_DateTable.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Pin Capture.SemanticModel/definition/tables/dim_Parts.tmdl`

- [ ] **Step 1: Exhaustive real-usage audit**

```bash
export PATH="$HOME/.local/bin:$PATH"
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs/workspaces/RP - Dev"
pbir fields list "Pin Capture.Report"
```

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs/workspaces/RP - Dev/Pin Capture.SemanticModel/definition"
for tbl in Fact_PinTransactions dim_BranchLocation dim_CustomerList dim_DateTable dim_Parts; do
  echo "=== $tbl ==="
  grep -rohE "'?${tbl}'?\[[A-Za-z0-9_%]+\]" tables/*.tmdl relationships.tmdl 2>/dev/null \
    | sed -E "s/'?${tbl}'?\[([A-Za-z0-9_%]+)\]/\1/" | sort -u
done
echo "=== raw PartNumber text usage check (control-character exposure) ==="
grep -n "PartNumber" relationships.tmdl
```

Also determine whether `PinFilterOptions.tmdl` is a real data table (has its own `Sql.Database`) or a parameter/calculated table (no SQL source, like `dim_AgingBucket` in Open Work Orders):
```bash
grep -n "Sql.Database\|partition.*=" "tables/PinFilterOptions.tmdl"
```
If it has a real `Sql.Database` call pointed at `LH_Master_Data`, it needs the same repoint as the other tables — add it to this task's file list and repeat Step 2's pattern on it. If it's calculated/parameter-only, leave it alone.

Check `New Report Columns.tmdl`/`New Report Relationships.tmdl`/`New Report Tables.tmdl` too — expected to be empty leftover placeholders (matching every other report already migrated this session), confirm and leave them for Brian's own Desktop cleanup pass rather than deleting them yourself.

- [ ] **Step 2: Repoint `Fact_PinTransactions.tmdl` and rename its 2 `Item=` references**

Find:
```
				    // Connect to Lakehouse
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
				    dbo_InTrans_Incremental = Source{[Schema="dbo",Item="InTrans_Incremental"]}[Data],
				    
				    // Filter to last 24 months (rolling window) - DO THIS EARLY!
				    TwoYearsAgo = DateTime.From(Date.AddMonths(Date.StartOfMonth(DateTime.Date(DateTime.LocalNow())), -24)),
```
Replace with:
```
				    // Connect to Lakehouse - repointed to DP_Presentation (2026-09-22)
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation"),
				    dbo_InTrans_Incremental = Source{[Schema="dbo",Item="Silver_InTrans"]}[Data],
				    
				    // Filter to last 24 months (rolling window) - DO THIS EARLY!
				    // Fabric/Power BI Service runs in UTC - DateTime.LocalNow() returns UTC, not local time.
				    // DateTimeZone.SwitchZone converts UTC to Central Time with automatic DST handling.
				    UtcNow    = DateTimeZone.UtcNow(),
				    UtcDT     = DateTimeZone.RemoveZone(UtcNow),
				    CurYear   = Date.Year(DateTime.Date(UtcDT)),
				    Mar1      = #date(CurYear, 3, 1),
				    Sun1Mar   = Date.AddDays(Mar1, Number.Mod(7 - Date.DayOfWeek(Mar1, Day.Sunday), 7)),
				    DstStart  = #datetime(CurYear, 3, Date.Day(Date.AddDays(Sun1Mar, 7)), 8, 0, 0),
				    Nov1      = #date(CurYear, 11, 1),
				    Sun1Nov   = Date.AddDays(Nov1, Number.Mod(7 - Date.DayOfWeek(Nov1, Day.Sunday), 7)),
				    DstEnd    = #datetime(CurYear, 11, Date.Day(Sun1Nov), 7, 0, 0),
				    OffsetHrs = if UtcDT >= DstStart and UtcDT < DstEnd then -5 else -6,
				    LocalNow  = DateTimeZone.RemoveZone(DateTimeZone.SwitchZone(UtcNow, OffsetHrs, 0)),
				    TwoYearsAgo = DateTime.From(Date.AddMonths(Date.StartOfMonth(DateTime.Date(LocalNow)), -24)),
```

Then find:
```
				    dbo_wkothsub = Source{[Schema="dbo",Item="wkothsub"]}[Data],
```
Replace with:
```
				    dbo_wkothsub = Source{[Schema="dbo",Item="Silver_WkOthSub"]}[Data],
```

- [ ] **Step 3: Repoint `dim_BranchLocation.tmdl`, `dim_CustomerList.tmdl`, `dim_DateTable.tmdl`, `dim_Parts.tmdl`**

In each file, find:
```
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
```
Replace with:
```
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation"),
```
No `Item=` changes in any of these 4 files.

- [ ] **Step 4: Trim per Step 1's findings, with matching `Table.SelectColumns` pins**

Same discipline as Task 1 Step 5 — only trim confident findings, pin with `Table.SelectColumns`, check for dangling `sortByColumn`.

- [ ] **Step 5: Confirm no `LH_Master_Data` or `DateTime.LocalNow()` references remain**

```bash
grep -rn "LH_Master_Data\|DateTime.LocalNow" "workspaces/RP - Dev/Pin Capture.SemanticModel/"
```
Expected: no output.

- [ ] **Step 6: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/RP - Dev/Pin Capture.SemanticModel/definition/tables/"*.tmdl
git commit -m "Repoint Pin Capture to DP_Presentation, fix DateTime.LocalNow()

InTrans_Incremental -> Silver_InTrans, wkothsub -> Silver_WkOthSub.
The rolling 24-month window filter used DateTime.LocalNow() (returns
UTC, not local) inside a live Table.SelectRows filter - fixed with
the project's canonical DST-aware conversion.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: Repoint Part Sales with Low Margin and fix its `DateTime.LocalNow()` bug

**Files:**
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Part Sales with Low Margin.SemanticModel/definition/tables/Fact_InTrans.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Part Sales with Low Margin.SemanticModel/definition/tables/dim_Parts_LowMargin.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Part Sales with Low Margin.SemanticModel/definition/tables/dim_BranchLocation.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Part Sales with Low Margin.SemanticModel/definition/tables/dim_CustomerList.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Part Sales with Low Margin.SemanticModel/definition/tables/dim_DateTable.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Part Sales with Low Margin.SemanticModel/definition/tables/dim_Parts.tmdl`

- [ ] **Step 1: Exhaustive real-usage audit**

```bash
export PATH="$HOME/.local/bin:$PATH"
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs/workspaces/RP - Dev"
pbir fields list "Part Sales with Low Margin.Report"
```

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs/workspaces/RP - Dev/Part Sales with Low Margin.SemanticModel/definition"
for tbl in Fact_InTrans dim_Parts_LowMargin dim_BranchLocation dim_CustomerList dim_DateTable dim_Parts; do
  echo "=== $tbl ==="
  grep -rohE "'?${tbl}'?\[[A-Za-z0-9_%]+\]" tables/*.tmdl relationships.tmdl 2>/dev/null \
    | sed -E "s/'?${tbl}'?\[([A-Za-z0-9_%]+)\]/\1/" | sort -u
done
echo "=== raw PartNumber text usage check (control-character exposure) ==="
grep -n "PartNumber" relationships.tmdl
```

`dim_Parts_LowMargin` itself joins on raw `PartNumber` text (confirmed in its own M query — `Table.NestedJoin(AggregateJdis, {"PartNumber", "Branch", "Franchise"}, InMaster_Fields, {"PartNumber", "Branch", "Franchise"}, ...)`), but that join happens entirely within this table's own M query between its two own sources (not a model-level relationship to `dim_Parts`) — confirm this doesn't also relate to the report's `dim_Parts` table via raw `PartNumber` (the real control-character risk is a `dim_Parts` relationship specifically, not an internal M-query join between two sources that both come from the same normalized-text pipeline).

- [ ] **Step 2: Repoint `Fact_InTrans.tmdl`, rename its `Item=`, and fix its `DateTime.LocalNow()`**

Find:
```
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
				    dbo_InTrans_Incremental = Source{[Schema="dbo",Item="InTrans_Incremental"]}[Data],
```
Replace with:
```
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation"),
				    dbo_InTrans_Incremental = Source{[Schema="dbo",Item="Silver_InTrans"]}[Data],
```

Then find:
```
				    FilterDateRange = Table.SelectRows(FilterToInvoices, each
				        [TransDatetime] >= DateTime.From(Date.AddYears(DateTime.Date(DateTime.LocalNow()), -2))
				    ),
```
Replace with:
```
				    // Fabric/Power BI Service runs in UTC - DateTime.LocalNow() returns UTC, not local time.
				    // DateTimeZone.SwitchZone converts UTC to Central Time with automatic DST handling.
				    UtcNow    = DateTimeZone.UtcNow(),
				    UtcDT     = DateTimeZone.RemoveZone(UtcNow),
				    CurYear   = Date.Year(DateTime.Date(UtcDT)),
				    Mar1      = #date(CurYear, 3, 1),
				    Sun1Mar   = Date.AddDays(Mar1, Number.Mod(7 - Date.DayOfWeek(Mar1, Day.Sunday), 7)),
				    DstStart  = #datetime(CurYear, 3, Date.Day(Date.AddDays(Sun1Mar, 7)), 8, 0, 0),
				    Nov1      = #date(CurYear, 11, 1),
				    Sun1Nov   = Date.AddDays(Nov1, Number.Mod(7 - Date.DayOfWeek(Nov1, Day.Sunday), 7)),
				    DstEnd    = #datetime(CurYear, 11, Date.Day(Sun1Nov), 7, 0, 0),
				    OffsetHrs = if UtcDT >= DstStart and UtcDT < DstEnd then -5 else -6,
				    LocalNow  = DateTimeZone.RemoveZone(DateTimeZone.SwitchZone(UtcNow, OffsetHrs, 0)),
				    FilterDateRange = Table.SelectRows(FilterToInvoices, each
				        [TransDatetime] >= DateTime.From(Date.AddYears(DateTime.Date(LocalNow), -2))
				    ),
```

- [ ] **Step 3: Repoint `dim_Parts_LowMargin.tmdl` and rename its 2 `Item=` references**

Find:
```
				    Source_InMaster = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
				    dbo_InMaster = Source_InMaster{[Schema="dbo",Item="InMaster"]}[Data],
```
Replace with:
```
				    Source_InMaster = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation"),
				    dbo_InMaster = Source_InMaster{[Schema="dbo",Item="Silver_InMaster"]}[Data],
```

Then find:
```
				    dbo_jdis = Source_jdis{[Schema="dbo",Item="jdis_Part_Information"]}[Data],
```
Replace with:
```
				    dbo_jdis = Source_jdis{[Schema="dbo",Item="Silver_PartInformation"]}[Data],
```

(`Source_jdis = Source_InMaster` is unchanged — it already reuses the one connection variable this step just repointed.)

- [ ] **Step 4: Repoint `dim_BranchLocation.tmdl`, `dim_CustomerList.tmdl`, `dim_DateTable.tmdl`, `dim_Parts.tmdl`**

In each file, find:
```
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
```
Replace with:
```
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation"),
```
No `Item=` changes in any of these 4 files.

- [ ] **Step 5: Trim per Step 1's findings, with matching `Table.SelectColumns` pins**

Same discipline as Task 1 Step 5.

- [ ] **Step 6: Confirm no `LH_Master_Data` or `DateTime.LocalNow()` references remain**

```bash
grep -rn "LH_Master_Data\|DateTime.LocalNow" "workspaces/RP - Dev/Part Sales with Low Margin.SemanticModel/"
```
Expected: no output.

- [ ] **Step 7: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/RP - Dev/Part Sales with Low Margin.SemanticModel/definition/tables/"*.tmdl
git commit -m "Repoint Part Sales with Low Margin to DP_Presentation, fix DateTime.LocalNow()

InTrans_Incremental -> Silver_InTrans, InMaster -> Silver_InMaster,
jdis_Part_Information -> Silver_PartInformation (same rename already
used for Parts Adjustments in Batch 1). The rolling 2-year window
filter used DateTime.LocalNow() inside a live Table.SelectRows filter
- fixed with the project's canonical DST-aware conversion.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 4: Push

**Files:** none.

- [ ] **Step 1: Push to origin**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git push origin dev
```

---

### Task 5: Brian — refresh, publish, and visually confirm all 3 reports

**Files:** none — Brian's action.

- [ ] **Step 1: Pull into `RP - Dev`**

In each of the 3 reports' Git integration state (or the workspace-level Source control pane), sync/update to pick up Tasks 1-3's commits.

- [ ] **Step 2: Open each report from `RP - Dev` in Desktop and refresh**

Watch for "column does not exist" errors on each — if any appear, that means the audit (Task 1/2/3 Step 1) missed a real usage; report back for investigation rather than assuming the trim is wrong.

- [ ] **Step 3: Visually confirm each report's real output**

Against the real, currently-live production versions (`RP - Service Reports` for Open Work Orders, `RP - Parts Reports` for Pin Capture and Part Sales with Low Margin).

- [ ] **Step 4: Publish each to `RP - Dev`, then Source control → Commit**

- [ ] **Step 5: Report back**

Once all 3 are confirmed, Claude runs the final post-publish verification (Task 6).

---

### Task 6: Post-publish verification

**Files:** none.

- [ ] **Step 1: Run a DuckDB row-count check against the real tables each report now depends on**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables"

tables = [
    "RepairOrderDetail", "Silver_WkRoFile", "Silver_TechnicianPunchedDetail",
    "Silver_InTrans", "Silver_WkOthSub", "Silver_InMaster", "Silver_PartInformation",
    "dim_BranchLocation", "dim_CustomerList", "dim_DateTable", "dim_Parts",
]
for t in sorted(set(tables)):
    try:
        n = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/{t}')").fetchone()[0]
        print(f"  OK  {t}: {n:,} rows")
    except Exception as e:
        print(f"  MISSING/ERROR  {t}: {e}")
```

Expected: every table prints a real row count, none print `MISSING/ERROR`.

- [ ] **Step 2: Update the report migration catalog doc**

Mark Open Work Orders, Pin Capture, and Part Sales with Low Margin as complete in `docs/architecture/report-migration-catalog.md`, matching the same completion-note pattern already used for Batch 0, Batch 1, and Price Matrix.

---

## Self-Review Notes

**Spec coverage:** Section 2 (3 reports, real `Item=` renames, the real `InMaster`/`jdis_Part_Information` finding) → Tasks 1-3. Section 3 (audit → repoint/rename → bug-class checks → trim workflow) → each task's Steps 1-5. Section 4 (verification: DuckDB + Brian's visual confirm, no new ground-truth script needed) → Tasks 5-6. Section 5 (out of scope: the 3 backend-build reports, Customer Anatomy, Inspections) → no task touches any of these.

**Placeholder scan:** Task 1 Step 4/5, Task 2 Step 4, Task 3 Step 5 (trim steps) depend on each task's own Step 1 audit findings rather than a pre-specified diff — a real sequential dependency (the audit has to run first), not a placeholder; every other step has literal, complete code.

**Type consistency:** the DST-aware `LocalNow` block is identical in Task 2 and Task 3 (matching the same canonical pattern already used in `Data Refresh.tmdl` tables and fixed on Price Matrix this session) — same variable names, same logic, cross-checked against each other for consistency.
