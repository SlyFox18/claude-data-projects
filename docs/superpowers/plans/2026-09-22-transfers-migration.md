# Transfers Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate Transfers from `LH_Master_Data` to `DP_Presentation`, adding 3 small additive columns to existing Silver notebooks and building a new Gold notebook for `Fact_OutstandingTransfers` that faithfully replicates the real production view+join logic — entirely from already-migrated Silver tables, no ODBC dependency.

**Architecture:** 3 one-line additions to 2 existing, already-proven Silver notebooks; one new Gold notebook joining `Silver_InSalPar`/`Silver_InMaster`/`Silver_InSalOrd` to replicate the real `Parts_InterbranchTransfers` view + the production dataflow's two-step outstanding/line-detail join; a proactive freshness fix for `Fact_Transfers`' own build notebook (found stale via the same never-registered-in-the-pipeline gap class as Open Parts Tickets); then the standard report-layer audit-and-repoint already proven on every other report this project.

**Tech Stack:** Fabric Notebooks (PySpark), Power BI Desktop (`.pbip`/TMDL text format), `fab` CLI, `pbir` CLI, DuckDB + `delta_scan()` for verification, Fabric Git integration, Fabric Data Pipelines (config-driven via `deploy/dp_backend_scope.json`).

**Full design reference:** `docs/superpowers/specs/2026-09-22-transfers-migration-design.md` (approved).

---

## Context You Need

**Real connection strings** (used throughout this whole project):
- Old: `Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data")`
- New: `Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation")`

**Real workspace/lakehouse IDs:**
- `DP - Staging - Dev` workspace: `ab15d64d-c7ba-415d-9bcf-7feb1ef9b201`, lakehouse `DP_Staging`: `876255e0-d462-4697-adc1-4a655f5bb101`
- `DP - Presentation - Dev` workspace: `73fd5443-240e-410a-990a-98827f32c087`, lakehouse `DP_Presentation`: `966efc8a-16f9-423b-aa43-e368fcd8fb91`
- SQL analytics endpoint ID (for the metadata-refresh step, Task 5): `18effb0e-7bc2-47a1-854c-f4f2e8129145`

**6 real data tables in the report** (`fabric-workspace-docs/workspaces/RP - Dev/Transfers.SemanticModel/definition/tables/`): `Fact_OutstandingTransfers`, `Fact_Transfers`, `Inv_Snapshot`, `dim_BranchLocation`, `dim_DateTable`, `dim_Parts`. `Fact_Transfers`/`dim_BranchLocation`/`dim_DateTable`/`dim_Parts` already exist in `DP_Presentation` (repoint-only, no new backend work needed for their own data). `Fact_OutstandingTransfers` needs the new Gold notebook (Task 5). `Inv_Snapshot` needs repointing to `Silver_PartInformation` (Task 8). The other table files in that folder (`ComparisonSelector`, `Data Refresh`, `MetricSelector`, `_Measures`) have no `Sql.Database` call — not part of this migration.

**Real `fab` CLI syntax, already discovered and proven working this session** — the plain path form does NOT work; every folder segment needs an explicit `.Folder` suffix, and `.py` notebook source needs `--format .py` on import:
```bash
export PATH="$HOME/.local/bin:$PATH"
fab import "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Transfers.Folder/Build_Gold_OutstandingTransfers.Notebook" \
  -i "<local path>" --format .py -f
fab get "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Transfers.Folder/Build_Gold_OutstandingTransfers.Notebook" -q "id"
fab job run "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Transfers.Folder/Build_Gold_OutstandingTransfers.Notebook" --timeout 300
```

**`dp_backend_scope.json` real entry shape** — always a precise text insertion matching the file's existing compact single-line-per-entry style, NEVER a full `json.dump()` rewrite (confirmed this session: `json.dump(..., indent=2)` reformats every existing entry and produces a huge, unwanted diff):
```json
{"name": "Build_Gold_X", "tier": "gold", "cadence": "daily",
 "notebookId": "<real-guid>", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
 "path": "workspaces/DP - Presentation - Dev/Fact Tables/Transfers/Build_Gold_X.Notebook"}
```

**Real, already-confirmed pre-existing staleness gap** (found during this plan's own investigation, same bug class as Open Parts Tickets' `Fact_Parts_Open_Tickets`): `Build_Gold_Transfers.Notebook` (real notebookId `1305ecbd-79c5-4355-b443-0bd0087f3c98`, already exists at `DP - Presentation - Dev/Fact Tables/Transfers/Build_Gold_Transfers.Notebook`) builds `Fact_Transfers` but is **not registered anywhere in `deploy/dp_backend_scope.json`**. Confirmed via direct DuckDB comparison: `DP_Presentation.Fact_Transfers` has 4,608,775 rows (max `Date` 2026-09-09) vs. the real live `LH_Master_Data.Fact_Transfers`'s 4,638,256 rows (max `Date` 2026-09-21) — 12 days stale, same gap size as the Open Parts Tickets incident. Task 4 fixes this proactively.

**Real `Parts_InterbranchTransfers` view SQL** (provided directly by Brian via SQL Central):
```sql
ALTER VIEW "Administrator"."Parts_InterbranchTransfers"
      (SupplyingBranch,RequestingBranch,PartTicket,OrderQuantity,ShippedQuantity,InTransitQuantity,OrderAge) AS
 select distinct Isnull(par.branch,'') as SupplyingBranch,
        Isnull(ord.trf_to_branch,'') as RequestingBranch,
        Isnull(par.file_no,0) as PartTicket,
        Isnull(par.order_qty,0) as OrderQuantity,
        Isnull(par.shipped_qty,0) as ShippedQuantity,
        Isnull(inm.in_transit_qty,0) as InTransitQuantity,
        Datediff(dd,Isnull(ord.ord_date,'1900-01-01'),Getdate()) as OrderAge
   from Administrator.insalpar as par
   left outer join Administrator.inmaster as inm on inm.branch = par.branch and inm.franchise = par.franchise and inm.part_no = par.part_no
   left outer join Administrator.insalord as ord on ord.file_no = par.file_no
  where ord.type = 'T'
```

**Real production `Fact_OutstandingTransfers` dataflow logic** (already fully read this session, `LH_Master_Data/Dataflows/04 - Facts/Tranfers/df_Fact_Transfers.Dataflow/mashup.pq` lines 402-741) — the exact 11-step logic Task 5's notebook ports into PySpark:
1. `Parts_InterbranchTransfers`-equivalent query grouped by `PartTicket`/`RequestingBranch`/`SupplyingBranch` with `MAX(OrderAge)`, filtered `InTransitQuantity > 0`.
2. `InSalPar`-equivalent line detail, filtered `ShippedQty > SuppliedQty`.
3. Exclude Branch 12 (`RequestingBranch`/`SupplyingBranch` starting with `"12"`) — applied to step 1's output before the join.
4. Left join step 1 to step 2 on `PartTicket`.
5. `OpenQty = ShippedQty - SuppliedQty` (null-safe: null if either side is null).
5.5. `FulfillmentStatus`: `"Pending"` if `OrderQty`/`ShippedQty` null or `ShippedQty = 0`; `"Shipped"` if `OrderQty = ShippedQty`; `"Partial"` if `0 < ShippedQty < OrderQty`.
6. Clean text: null-safe trim on `RequestingBranch`/`SupplyingBranch`; `PartNumber` upper+trim.
7. `TransferSubType` from `SoRoRef`: `null` or `< 100000` → `"Stock"`; `100000`–`999999` → `"Work Order"`; `1000000`–`9999999` → `"Counter"`; `>= 10000000` → `"Unknown"`.
8. `DateKey` (YYYYMMDD int) and `Date` from `TransDatetime`.
9-11. Rename/reorder/final types — not needed verbatim in PySpark (column naming is handled directly in the `select`/`withColumn` calls).

**Real Silver schemas confirmed this session** (via direct DuckDB `DESCRIBE` against `DP_Presentation`):
- `Silver_InSalPar` (21,444 rows): `FileNumber, LineNumber, Branch, Franchise, PartNumber, OrderQty, SuppliedQty, BackorderQty, UnitPrice, UnitCost, JobCode, Salesperson, PurOrderType, CreationDate` — plus the 2 new columns added in Task 2.
- `Silver_InSalOrd` (10,346 rows): `FileNumber, Branch, CustomerOrderNumber, TaxNumber, OrderType, Freight, Salesperson, OrderDate, CreatedDate, Deposit, CustomerNumber, VehicleNumber, SpecialInstructions, ROBranch, RONumber, Note, AuthID, AuthValue, RecControl` — plus `TrfToBranch` added in Task 3. `OrderType` is the real column to filter `= 'T'`.
- `Silver_InMaster` (1,111,807 rows): has `InTransitQty` under that exact name — no changes needed.

**DST-safe "now" pattern for `OrderAge`** (same pattern already used in Open Parts Tickets' `Build_Gold_PartsInvoicedByBranch.Notebook`): compute true US/Central local "now" via `pytz`, not a naive `datetime.now()` — the source's `GETDATE()` is a real on-prem SQL Anywhere server call (true Central time), and `OrderAge` is computed live on every query, not a static stored value.

**Real-tool boundary:** the report already exists in `RP - Dev` (confirmed via directory listing) but has no `.pbip` yet and hasn't been touched by this migration project before. Brian confirms the report isn't open in Desktop before Claude edits its TMDL directly (Task 9), same boundary as every other report this project.

---

### Task 1: Confirm Silver notebooks' real current content

**Files:** none — investigation only, confirms Task 2/3's exact insertion points before editing.

- [x] **Step 1: Re-read both notebooks**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
cat "workspaces/DP - Staging - Dev/Build_Silver_InSalPar.Notebook/notebook-content.py"
cat "workspaces/DP - Staging - Dev/Build_Silver_InSalOrd.Notebook/notebook-content.py"
```
Expected: `Build_Silver_InSalPar.Notebook`'s `silver = bronze.select(...)` call ends with `F.col("Creation_Datetime").alias("CreationDate"),` (13 columns). `Build_Silver_InSalOrd.Notebook`'s `silver = bronze.select(...)` call ends with `F.col("REC_CONTROL").alias("RecControl"),` (18 columns). If either differs from this, stop and re-investigate before Task 2/3 — something changed since this plan was written.

**Execution note (2026-09-22):** Confirmed exactly as expected — `Build_Silver_InSalPar.Notebook` has the 13-column `select()` ending in `CreationDate`, `Build_Silver_InSalOrd.Notebook` has the 18-column `select()` ending in `RecControl`. No drift since this plan was written; proceeded to Task 2.

---

### Task 2: Add `ShippedQty`/`SoRoRef` to `Build_Silver_InSalPar.Notebook`

**Files:**
- Modify: `fabric-workspace-docs/workspaces/DP - Staging - Dev/Build_Silver_InSalPar.Notebook/notebook-content.py`

- [x] **Step 1: Add the 2 new columns to the `select()` call**

Find:
```python
    F.col("UNIT_COST").alias("UnitCost"),
    F.col("JOB_CODE").alias("JobCode"),
```
Replace with:
```python
    F.col("UNIT_COST").alias("UnitCost"),
    F.col("JOB_CODE").alias("JobCode"),
    F.col("SHIPPED_QTY").alias("ShippedQty"),
    F.col("SO_RO_Ref").alias("SoRoRef"),
```
(Inserting after `JobCode` keeps the new columns grouped near the other quantity/reference columns — exact position within the `select()` call doesn't matter functionally, this just keeps the list readable.)

- [x] **Step 2: Run the notebook and verify**

```bash
export PATH="$HOME/.local/bin:$PATH"
fab job run "DP - Staging - Dev.Workspace/Build_Silver_InSalPar.Notebook" --timeout 300
```
Expected: `Completed`, no `failureReason`. The notebook's own `silver_count == bronze_count` assertion guarantees this addition didn't add/drop rows — if the assertion fails, the job itself fails, which is the expected safety net.

**Execution note (2026-09-22):** First `fab job run` completed successfully, but the DuckDB check in Step 3 then showed `ShippedQty` wasn't present — editing the local git-mirrored `.py` file does not by itself push to the live Fabric notebook. Ran `fab import "DP - Staging - Dev.Workspace/Build_Silver_InSalPar.Notebook" -i "workspaces/DP - Staging - Dev/Build_Silver_InSalPar.Notebook" --format .py -f` to publish the edited content to the live item first (reported "An item with the same name exists... imported"), then re-ran `fab job run` — that second run completed successfully against the actually-updated notebook. **New pattern worth carrying into Task 3 and any other existing-notebook edit in this plan: `fab import` (update) before `fab job run` whenever a notebook's local file was edited but not freshly created via `fab import` already.**

- [x] **Step 3: Confirm the new columns landed correctly**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables"
r = con.execute(f"SELECT COUNT(*), COUNT(ShippedQty), COUNT(SoRoRef) FROM delta_scan('{base}/Silver_InSalPar')").fetchone()
print(f"total rows={r[0]:,}  non-null ShippedQty={r[1]:,}  non-null SoRoRef={r[2]:,}")
```
Expected: total rows still 21,444 (or close — real data may have grown slightly since this plan was written, but should not have shrunk). `ShippedQty`/`SoRoRef` both present with plausible non-null counts (not 0, not necessarily 21,444 either since some rows may legitimately have nulls).

**Execution note (2026-09-22): real observed numbers — `total rows=21,444  non-null ShippedQty=711  non-null SoRoRef=305`.** Row count matches exactly (no growth/shrinkage since plan was written); both new columns present with plausible non-null counts.

- [x] **Step 4: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/DP - Staging - Dev/Build_Silver_InSalPar.Notebook/notebook-content.py"
git commit -m "Add ShippedQty/SoRoRef to Silver_InSalPar

Both already exist in Bronze InSalPar, just weren't selected into
Silver yet. Needed for the new Fact_OutstandingTransfers Gold table
(Transfers migration) - ShippedQty for OpenQty/FulfillmentStatus,
SoRoRef for TransferSubType classification. Pure additive select()
change - the notebook's own silver_count == bronze_count assertion
confirms no rows were added or dropped.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 3: Add `TrfToBranch` to `Build_Silver_InSalOrd.Notebook`

**Files:**
- Modify: `fabric-workspace-docs/workspaces/DP - Staging - Dev/Build_Silver_InSalOrd.Notebook/notebook-content.py`

- [ ] **Step 1: Add the new column to the `select()` call**

Find:
```python
    F.col("SPECIAL_INST").alias("SpecialInstructions"),
    F.col("RO_BRANCH").alias("ROBranch"),
```
Replace with:
```python
    F.col("SPECIAL_INST").alias("SpecialInstructions"),
    F.col("TRF_TO_BRANCH").alias("TrfToBranch"),
    F.col("RO_BRANCH").alias("ROBranch"),
```

- [ ] **Step 2: Run the notebook and verify**

```bash
export PATH="$HOME/.local/bin:$PATH"
fab job run "DP - Staging - Dev.Workspace/Build_Silver_InSalOrd.Notebook" --timeout 300
```
Expected: `Completed`, no `failureReason`.

- [ ] **Step 3: Confirm the new column landed correctly**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables"
r = con.execute(f"SELECT COUNT(*), COUNT(TrfToBranch) FROM delta_scan('{base}/Silver_InSalOrd')").fetchone()
print(f"total rows={r[0]:,}  non-null TrfToBranch={r[1]:,}")
```
Expected: total rows still ~10,346. `TrfToBranch` present with a plausible non-null count — most rows are NOT transfer orders (`OrderType != 'T'`), so a low non-null count here is expected and fine (only transfer-type orders would have a meaningful `trf_to_branch`).

- [ ] **Step 4: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/DP - Staging - Dev/Build_Silver_InSalOrd.Notebook/notebook-content.py"
git commit -m "Add TrfToBranch to Silver_InSalOrd

Already exists in Bronze InSalOrd, just wasn't selected into Silver
yet. Needed for the new Fact_OutstandingTransfers Gold table
(Transfers migration) - this is RequestingBranch in the real
Parts_InterbranchTransfers view. Pure additive select() change -
the notebook's own silver_count == bronze_count assertion confirms
no rows were added or dropped.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 4: Fix `Fact_Transfers`' staleness (register `Build_Gold_Transfers.Notebook`)

**Files:**
- Modify: `fabric-workspace-docs/deploy/dp_backend_scope.json`

- [ ] **Step 1: Re-confirm the notebook exists and is unregistered**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
export PATH="$HOME/.local/bin:$PATH"
ls "workspaces/DP - Presentation - Dev/Fact Tables/Transfers/"
grep -n "Build_Gold_Transfers" deploy/dp_backend_scope.json
fab get "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Transfers.Folder/Build_Gold_Transfers.Notebook" -q "id"
```
Expected: `Build_Gold_Transfers.Notebook` exists on disk; `grep` returns no output (not yet registered); `fab get` returns `1305ecbd-79c5-4355-b443-0bd0087f3c98`.

- [ ] **Step 2: Register it in `dp_backend_scope.json`**

Add this entry to the `notebooks` array (matching the file's existing compact style — do NOT use a script that reformats the whole file):
```json
{"name": "Build_Gold_Transfers", "tier": "gold", "cadence": "daily",
 "notebookId": "1305ecbd-79c5-4355-b443-0bd0087f3c98", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
 "path": "workspaces/DP - Presentation - Dev/Fact Tables/Transfers/Build_Gold_Transfers.Notebook"}
```

- [ ] **Step 3: Run it once to catch up to real current data**

```bash
fab job run "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Transfers.Folder/Build_Gold_Transfers.Notebook" --timeout 300
```
Expected: `Completed`, no `failureReason`. This is a full-overwrite rebuild (confirmed via the notebook's own `mode("overwrite")` write) so it will fully replace the stale data with current data in one run.

- [ ] **Step 4: Verify it now matches real production**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
lh_base = "abfss://b48cdb35-7ce3-46de-96df-d70db77649cb@onelake.dfs.fabric.microsoft.com/3e74497b-8c51-4a1a-91a1-888c59118f48/Tables"
dp_base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables"
for label, base in [("LH_Master_Data", lh_base), ("DP_Presentation", dp_base)]:
    r = con.execute(f"SELECT COUNT(*), MAX(Date) FROM delta_scan('{base}/Fact_Transfers')").fetchone()
    print(f"{label}: rows={r[0]:,}  max_date={r[1]}")
```
Expected: both sides' row counts and `max_date` match closely (may differ by 1 day if the two pulls happen to straddle a pipeline refresh, but should NOT still show the ~12-day/30K-row gap seen before this fix).

- [ ] **Step 5: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "deploy/dp_backend_scope.json"
git commit -m "Register Build_Gold_Transfers in the daily DP refresh pipeline

Real gap found during Transfers migration prep, same class as Open
Parts Tickets' Fact_Parts_Open_Tickets: this notebook existed in
DP_Presentation but was never registered in the daily refresh
pipeline, leaving Fact_Transfers 12 days stale. Registered as
tier=gold, cadence=daily and run once to catch up - now matches
LH_Master_Data's live production copy.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 5: Build and register `Build_Gold_OutstandingTransfers.Notebook`

**Files:**
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/Transfers/Build_Gold_OutstandingTransfers.Notebook/notebook-content.py`
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/Transfers/Build_Gold_OutstandingTransfers.Notebook/.platform`
- Modify: `fabric-workspace-docs/deploy/dp_backend_scope.json`

- [ ] **Step 1: Write the notebook content**

```python
# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "966efc8a-16f9-423b-aa43-e368fcd8fb91",
# META       "default_lakehouse_name": "DP_Presentation",
# META       "default_lakehouse_workspace_id": "73fd5443-240e-410a-990a-98827f32c087",
# META       "known_lakehouses": [
# META         {
# META           "id": "966efc8a-16f9-423b-aa43-e368fcd8fb91"
# META         }
# META       ]
# META     }
# META   }
# META }

# CELL ********************

# ============================================================================
# NOTEBOOK: Build_Gold_OutstandingTransfers
# ============================================================================
#
# PURPOSE:
#   Tracks inter-branch parts transfer orders that are currently
#   outstanding. Each row represents one part line on one outstanding
#   transfer ticket. Faithfully replicates the real production
#   LH_Master_Data/df_Fact_Transfers.Dataflow's Fact_OutstandingTransfers
#   logic - which itself is a Power Query port of the real SQL Anywhere
#   view Parts_InterbranchTransfers (view SQL below, provided directly by
#   Brian via SQL Central) - but sourced from the already-migrated Silver
#   tables instead of raw ODBC.
#
# GRAIN: One row per outstanding part line (FileNumber + LineNumber)
# SOURCE: Silver_InSalPar, Silver_InMaster, Silver_InSalOrd (DP_Presentation)
# TARGET: Fact_OutstandingTransfers (Delta table, full overwrite each run)
#
# REAL SOURCE VIEW SQL (Parts_InterbranchTransfers, SQL Anywhere):
#   ALTER VIEW "Administrator"."Parts_InterbranchTransfers"
#         (SupplyingBranch,RequestingBranch,PartTicket,OrderQuantity,
#          ShippedQuantity,InTransitQuantity,OrderAge) AS
#    select distinct Isnull(par.branch,'') as SupplyingBranch,
#           Isnull(ord.trf_to_branch,'') as RequestingBranch,
#           Isnull(par.file_no,0) as PartTicket,
#           Isnull(par.order_qty,0) as OrderQuantity,
#           Isnull(par.shipped_qty,0) as ShippedQuantity,
#           Isnull(inm.in_transit_qty,0) as InTransitQuantity,
#           Datediff(dd,Isnull(ord.ord_date,'1900-01-01'),Getdate()) as OrderAge
#      from Administrator.insalpar as par
#      left outer join Administrator.inmaster as inm on inm.branch = par.branch
#        and inm.franchise = par.franchise and inm.part_no = par.part_no
#      left outer join Administrator.insalord as ord on ord.file_no = par.file_no
#     where ord.type = 'T'
#
# OrderAge is computed LIVE by the source (DATEDIFF against GETDATE()),
# not a static stored value - this notebook replicates that using a
# DST-safe US/Central "now" (the real source is an on-prem server
# returning true local time, not UTC).
#
# ============================================================================

from pyspark.sql import functions as F
from datetime import datetime
import pytz

central = pytz.timezone("America/Chicago")
now_central = datetime.now(pytz.utc).astimezone(central)
today_central = now_central.date()
print(f"Computing OrderAge relative to (Central): {today_central}")

insalpar = spark.sql("SELECT FileNumber, LineNumber, Branch, Franchise, PartNumber, "
                      "OrderQty, SuppliedQty, ShippedQty, SoRoRef, CreationDate "
                      "FROM Silver_InSalPar")
inmaster = spark.sql("SELECT Branch, Franchise, PartNumber, InTransitQty FROM Silver_InMaster")
insalord = spark.sql("SELECT FileNumber, TrfToBranch, OrderDate, OrderType FROM Silver_InSalOrd") \
    .filter(F.col("OrderType") == "T")

print(f"Silver_InSalPar rows: {insalpar.count():,}")
print(f"Silver_InMaster rows (unfiltered): {inmaster.count():,}")
print(f"Silver_InSalOrd rows (OrderType='T'): {insalord.count():,}")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ============================================================================
# CELL 2 - STEP 1: OUTSTANDING TICKET DETERMINATION
# Replicates the real view (join InSalPar -> InMaster -> InSalOrd), then
# the production dataflow's own grouping query on top of it.
# ============================================================================

view_replica = (
    insalpar.alias("par")
    .join(inmaster.alias("inm"),
          (F.col("par.Branch") == F.col("inm.Branch"))
          & (F.col("par.Franchise") == F.col("inm.Franchise"))
          & (F.col("par.PartNumber") == F.col("inm.PartNumber")),
          "left_outer")
    .join(insalord.alias("ord"), F.col("par.FileNumber") == F.col("ord.FileNumber"), "left_outer")
    .select(
        F.coalesce(F.col("par.Branch"), F.lit("")).alias("SupplyingBranch"),
        F.coalesce(F.col("ord.TrfToBranch"), F.lit("")).alias("RequestingBranch"),
        F.coalesce(F.col("par.FileNumber"), F.lit(0)).alias("PartTicket"),
        F.datediff(F.lit(today_central), F.coalesce(F.to_date("ord.OrderDate"), F.lit("1900-01-01"))).alias("OrderAge"),
        F.coalesce(F.col("inm.InTransitQty"), F.lit(0.0)).alias("InTransitQuantity"),
    )
    .distinct()
)

outstanding_source = view_replica.filter(F.col("InTransitQuantity") > 0)

outstanding_tickets = (
    outstanding_source
    .groupBy("PartTicket", "RequestingBranch", "SupplyingBranch")
    .agg(F.max("OrderAge").alias("OrderAge"))
)

print(f"Outstanding tickets (post-group): {outstanding_tickets.count():,}")

# STEP 3 (Branch 12 exclusion) - applied here, matching the production
# dataflow's own step ordering (before the line-detail join).
filter_branch12 = outstanding_tickets.filter(
    (~F.coalesce(F.col("RequestingBranch"), F.lit("")).startswith("12"))
    & (~F.coalesce(F.col("SupplyingBranch"), F.lit("")).startswith("12"))
)

print(f"Outstanding tickets (post Branch-12 exclusion): {filter_branch12.count():,}")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ============================================================================
# CELL 3 - STEP 2: LINE-LEVEL DETAIL
# Silver_InSalPar directly (not through the view), filtered to lines
# still outstanding at the line level.
# ============================================================================

transfer_lines = insalpar.filter(F.col("ShippedQty") > F.col("SuppliedQty")).select(
    F.col("FileNumber").alias("PartTicket"),
    F.col("LineNumber"),
    F.upper(F.trim(F.coalesce(F.col("PartNumber"), F.lit("")))).alias("PartNumber"),
    F.col("OrderQty"),
    F.col("ShippedQty"),
    F.col("SuppliedQty"),
    F.col("SoRoRef"),
    F.col("CreationDate").alias("TransDatetime"),
)

print(f"Transfer lines (ShippedQty > SuppliedQty): {transfer_lines.count():,}")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ============================================================================
# CELL 4 - STEP 4: JOIN + COMPUTED COLUMNS
# ============================================================================

joined = filter_branch12.join(transfer_lines, on="PartTicket", how="left_outer")

with_open_qty = joined.withColumn(
    "OpenQty",
    F.when(F.col("ShippedQty").isNull() | F.col("SuppliedQty").isNull(), F.lit(None).cast("double"))
     .otherwise(F.col("ShippedQty") - F.col("SuppliedQty"))
)

with_fulfillment = with_open_qty.withColumn(
    "FulfillmentStatus",
    F.when(F.col("OrderQty").isNull() | F.col("ShippedQty").isNull(), F.lit("Pending"))
     .when(F.col("OrderQty") == F.col("ShippedQty"), F.lit("Shipped"))
     .when(F.col("ShippedQty") > 0, F.lit("Partial"))
     .otherwise(F.lit("Pending"))
)

with_transfer_subtype = with_fulfillment.withColumn(
    "TransferSubType",
    F.when(F.col("SoRoRef").isNull() | (F.col("SoRoRef") < 100000), F.lit("Stock"))
     .when(F.col("SoRoRef") <= 999999, F.lit("Work Order"))
     .when(F.col("SoRoRef") <= 9999999, F.lit("Counter"))
     .otherwise(F.lit("Unknown"))
).drop("SoRoRef")

with_date = with_transfer_subtype.withColumn(
    "Date", F.to_date("TransDatetime")
).withColumn(
    "DateKey",
    (F.year("Date") * 10000 + F.month("Date") * 100 + F.dayofmonth("Date")).cast("long")
)

final = with_date.select(
    "DateKey", "Date", "PartTicket", "LineNumber", "TransDatetime",
    "RequestingBranch", "SupplyingBranch", "PartNumber",
    "TransferSubType", "FulfillmentStatus",
    "OrderQty", "ShippedQty", "SuppliedQty", "OpenQty", "OrderAge",
)

row_count = final.count()
print(f"Final Fact_OutstandingTransfers rows: {row_count:,}")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ============================================================================
# CELL 5 - WRITE
# Full overwrite each run (matches the original's behavior - a live
# native query recomputed fresh on every refresh).
# ============================================================================

final.write \
    .mode("overwrite") \
    .option("overwriteSchema", "true") \
    .save("Tables/Fact_OutstandingTransfers")

print(f"SUCCESS: {row_count:,} rows written to Fact_OutstandingTransfers")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 2: Write the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Gold_OutstandingTransfers"
  },
  "config": {
    "version": "2.0",
    "logicalId": "REPLACE_WITH_NEW_GUID"
  }
}
```
Generate a real, unique GUID for `logicalId` via `python -c "import uuid; print(uuid.uuid4())"` before writing — don't leave the placeholder text.

- [ ] **Step 3: Import the notebook into Fabric**

```bash
export PATH="$HOME/.local/bin:$PATH"
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
fab import "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Transfers.Folder/Build_Gold_OutstandingTransfers.Notebook" \
  -i "workspaces/DP - Presentation - Dev/Fact Tables/Transfers/Build_Gold_OutstandingTransfers.Notebook" --format .py -f
```

- [ ] **Step 4: Run it once and capture the real notebookId**

```bash
fab job run "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Transfers.Folder/Build_Gold_OutstandingTransfers.Notebook" --timeout 300
fab get "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Transfers.Folder/Build_Gold_OutstandingTransfers.Notebook" -q "id"
```
Expected: `Completed`, no `failureReason`. Record the returned notebookId for Step 6.

- [ ] **Step 5: Force a SQL analytics endpoint metadata sync**

This is a brand-new table created via a path-based Spark write — confirmed this session that such tables aren't immediately visible through `Sql.Database()`'s SQL analytics endpoint without a forced sync (this exact issue blocked Brian's first Open Parts Tickets refresh attempt with "The key didn't match any rows in the table"). Do this proactively now, not reactively after Brian hits the same error:
```bash
fab api -X post "workspaces/73fd5443-240e-410a-990a-98827f32c087/sqlEndpoints/18effb0e-7bc2-47a1-854c-f4f2e8129145/refreshMetadata"
```

- [ ] **Step 6: Register in `dp_backend_scope.json`**

```json
{"name": "Build_Gold_OutstandingTransfers", "tier": "gold", "cadence": "daily",
 "notebookId": "<real-guid-from-step-4>", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
 "path": "workspaces/DP - Presentation - Dev/Fact Tables/Transfers/Build_Gold_OutstandingTransfers.Notebook"}
```

- [ ] **Step 7: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/DP - Presentation - Dev/Fact Tables/Transfers/Build_Gold_OutstandingTransfers.Notebook/" "deploy/dp_backend_scope.json"
git commit -m "Add Build_Gold_OutstandingTransfers notebook

New daily Gold notebook replicating the real Parts_InterbranchTransfers
view + the production df_Fact_Transfers.Dataflow's two-step
outstanding-ticket/line-detail join, sourced from Silver_InSalPar/
Silver_InMaster/Silver_InSalOrd instead of raw ODBC. OrderAge computed
with a DST-safe Central-time 'now', matching the source's live
GETDATE()-based calculation. Registered in dp_backend_scope.json
(tier=gold, cadence=daily).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 6: Verify `Fact_OutstandingTransfers` against the real source

**Files:** none — verification only.

- [ ] **Step 1: Row-count and aggregate sanity check**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
lh_base = "abfss://b48cdb35-7ce3-46de-96df-d70db77649cb@onelake.dfs.fabric.microsoft.com/3e74497b-8c51-4a1a-91a1-888c59118f48/Tables"
dp_base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables"

print("=== LH_Master_Data.Fact_OutstandingTransfers (real production, built from raw ODBC) ===")
r = con.execute(f"SELECT COUNT(*), SUM(OrderQty), AVG(OrderAge) FROM delta_scan('{lh_base}/Fact_OutstandingTransfers')").fetchone()
print(f"  rows={r[0]:,}  sum_order_qty={r[1]:,.2f}  avg_order_age={r[2]:.1f}")

print("=== DP_Presentation.Fact_OutstandingTransfers (new, from Silver) ===")
r = con.execute(f"SELECT COUNT(*), SUM(OrderQty), AVG(OrderAge) FROM delta_scan('{dp_base}/Fact_OutstandingTransfers')").fetchone()
print(f"  rows={r[0]:,}  sum_order_qty={r[1]:,.2f}  avg_order_age={r[2]:.1f}")
```
Expected: row counts and aggregates in the same ballpark (not necessarily exact — the old table's `OrderAge` was computed at whatever moment its last refresh ran, and the new table's `OrderAge` is computed at whenever this notebook ran; a few hours' to a day's difference in `avg_order_age` is expected and fine, not a bug). A large discrepancy (more than ~10% on row count, or `avg_order_age` off by many days) means the join logic has a real bug — investigate before proceeding, don't assume it's just timing.

- [ ] **Step 2: Spot-check one real ticket's line detail**

```python
r = con.execute(f"""
    SELECT PartTicket, LineNumber, RequestingBranch, SupplyingBranch, OrderQty, ShippedQty, SuppliedQty, OpenQty, TransferSubType, FulfillmentStatus
    FROM delta_scan('{dp_base}/Fact_OutstandingTransfers')
    ORDER BY OrderQty DESC LIMIT 5
""").fetchall()
for row in r:
    print(row)
```
Expected: sensible-looking rows — real branch codes, positive quantities, `OpenQty = ShippedQty - SuppliedQty` holding true, `TransferSubType`/`FulfillmentStatus` populated with one of the expected enum values each.

- [ ] **Step 3: Document the real comparison result in this plan**

Add a note here with the actual row counts/aggregates observed, since this is a live comparison whose exact numbers will differ by the time this plan is executed.

---

### Task 7: Exhaustive real-usage audit (report layer)

**Files:** none — investigation only. Findings get documented directly in this plan before Task 8 proceeds (same discipline as every prior report migration this project).

- [ ] **Step 1: `pbir fields list`**

```bash
export PATH="$HOME/.local/bin:$PATH"
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs/workspaces/RP - Dev"
pbir fields list "Transfers.Report"
```

- [ ] **Step 2: DAX-text grep across every measure/calculated table + relationships**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs/workspaces/RP - Dev/Transfers.SemanticModel/definition"
for tbl in Fact_OutstandingTransfers Fact_Transfers Inv_Snapshot dim_BranchLocation dim_DateTable dim_Parts; do
  echo "=== $tbl ==="
  grep -rohE "'?${tbl}'?\[[A-Za-z0-9_ ]+\]" tables/*.tmdl relationships.tmdl 2>/dev/null \
    | sed -E "s/'?${tbl}'?\[([A-Za-z0-9_ ]+)\]/\1/" | sort -u
done
```

- [ ] **Step 3: Bookmark check**

```bash
ls "Transfers.Report/definition/bookmarks/" 2>/dev/null
grep -rn "<ColumnName>" "Transfers.Report/definition/bookmarks/" 2>/dev/null
```

- [ ] **Step 4: `relationships.tmdl` cross-reference**

Relationship key columns use TMDL `fromColumn:`/`toColumn:` syntax, not `Table[Column]` DAX syntax — invisible to Step 2's grep. Read `relationships.tmdl` directly and note every column used as a relationship endpoint for these 6 tables (the design spec documents the expected relationships: `Fact_OutstandingTransfers[DateKey]`→`dim_DateTable[DateKey]`, `Fact_OutstandingTransfers[RequestingBranch]`/`[SupplyingBranch]`→`dim_BranchLocation[BranchID]`, `Fact_OutstandingTransfers[PartNumber]`→`dim_Parts[PartNumber]` — confirm these are real, don't just assume the design spec's note is exhaustive).

- [ ] **Step 5: Document findings**

For each of the 6 tables, record confirmed-used columns (keep) vs. confident-unused columns (trim) vs. ambiguous (leave as-is, note why). Also check each table for any `sortByColumn` property before trimming anything. Add a "### Task 7 Findings" section to this plan file (same structure as the Inventory Analysis/Open Parts Tickets plans' own findings sections) before starting Task 8.

---

### Task 8: Repoint and trim the report's 6 data tables

**Files:**
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Transfers.SemanticModel/definition/tables/Fact_OutstandingTransfers.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Transfers.SemanticModel/definition/tables/Fact_Transfers.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Transfers.SemanticModel/definition/tables/Inv_Snapshot.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Transfers.SemanticModel/definition/tables/dim_BranchLocation.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Transfers.SemanticModel/definition/tables/dim_DateTable.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Transfers.SemanticModel/definition/tables/dim_Parts.tmdl`

- [ ] **Step 1: Repoint all 6 tables' SQL connections**

In each file, find:
```
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
```
Replace with:
```
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation"),
```

- [ ] **Step 2: Fix `Inv_Snapshot.tmdl`'s `Item=` to the new Silver shortcut name**

Find:
```
				    jdis_Part_Information = Source{[Schema="dbo",Item="jdis_Part_Information"]}[Data],
```
Replace with:
```
				    jdis_Part_Information = Source{[Schema="dbo",Item="Silver_PartInformation"]}[Data],
```
(Keep the local variable name `jdis_Part_Information` as-is if that minimizes the diff, or rename it to `Silver_PartInformation` for clarity and update the `in` clause reference accordingly — either is fine, just keep the file internally consistent.)

- [ ] **Step 3: Trim per Task 7's findings**

For each of the 6 tables, apply Task 7's documented keep/trim decisions: remove confidently-unused `column` blocks, add/update a matching `Table.SelectColumns(...)` M-query step, check for any dangling `sortByColumn` on a trim candidate before removing it. Leave ambiguous columns untouched.

- [ ] **Step 4: Confirm no `LH_Master_Data` references remain**

```bash
grep -rn "LH_Master_Data" "workspaces/RP - Dev/Transfers.SemanticModel/"
```
Expected: no output.

- [ ] **Step 5: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/RP - Dev/Transfers.SemanticModel/definition/tables/"*.tmdl
git commit -m "Repoint Transfers to DP_Presentation

All 6 data tables repointed; Inv_Snapshot's Item= fixed to the new
Silver_PartInformation shortcut. Trimmed per the Task 7 exhaustive
audit where confident, left as-is where ambiguous.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 9: Create the `.pbip`

**Files:**
- Create: `fabric-workspace-docs/workspaces/RP - Dev/Transfers.pbip`

- [ ] **Step 1: Confirm it doesn't already exist**

```bash
ls "workspaces/RP - Dev/" | grep "Transfers"
```
Expected: only `Transfers.Report` and `Transfers.SemanticModel` — no `.pbip` (already confirmed this session; re-check in case something changed).

- [ ] **Step 2: Create the `.pbip` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/pbip/pbipProperties/1.0.0/schema.json",
  "version": "1.0",
  "artifacts": [
    {
      "report": {
        "path": "Transfers.Report"
      }
    }
  ],
  "settings": {
    "enableAutoRecovery": true
  }
}
```

- [ ] **Step 3: Commit and push**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/RP - Dev/Transfers.pbip"
git commit -m "Add Transfers.pbip for RP - Dev

Fabric's own Git integration doesn't create this - same pattern
already used for every other report migrated in this project.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 10: Brian — pull, refresh, publish, and visually confirm

**Files:** none — Brian's action.

- [ ] **Step 1: Pull into `RP - Dev`**

Sync/update to pick up Tasks 8-9's commits.

- [ ] **Step 2: Open Transfers from `RP - Dev` in Desktop and refresh**

Watch for "column does not exist" errors (would mean Task 7's audit missed a real usage) or "the key didn't match any rows in the table" errors (already proactively addressed via Task 5 Step 5's metadata-sync, but flag it if it recurs anyway) — report back for investigation rather than assuming.

- [ ] **Step 3: Visually confirm real output**

Against the real, currently-live `RP - Parts Reports` production version — specifically the Outstanding Transfers page (Page 3 — aging buckets, fulfillment status) and the main Transfers trend/summary pages, to confirm the new `Fact_OutstandingTransfers` produces equivalent output to the old ODBC-sourced table.

- [ ] **Step 4: Publish to `RP - Dev`, then Source control → Commit**

- [ ] **Step 5: Report back**

Once confirmed, Claude runs the final post-publish verification (Task 11).

---

### Task 11: Post-publish verification and catalog update

**Files:**
- Modify: `data-projects/docs/architecture/report-migration-catalog.md`

- [ ] **Step 1: DuckDB row-count check**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables"

tables = [
    "Fact_OutstandingTransfers", "Fact_Transfers", "Silver_PartInformation",
    "dim_BranchLocation", "dim_DateTable", "dim_Parts",
]
for t in sorted(set(tables)):
    try:
        n = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/{t}')").fetchone()[0]
        print(f"  OK  {t}: {n:,} rows")
    except Exception as e:
        print(f"  MISSING/ERROR  {t}: {e}")
```

- [ ] **Step 2: Update the catalog doc**

Mark Transfers complete in `docs/architecture/report-migration-catalog.md`'s Batch 2 section, matching the completion-note pattern already used for Batch 2a, Inventory Analysis, and Open Parts Tickets. Note this closes out Batch 2 entirely (all 6 reports now done: Open Work Orders, Pin Capture, Part Sales with Low Margin, Inventory Analysis, Open Parts Tickets, Transfers).

---

## Self-Review Notes

**Spec coverage:** The design spec's 3 architecture sections (3.1 Silver additions, 3.2 the new Gold notebook, 3.3 report-layer repoint) map to Tasks 1-3, Tasks 4-6, and Tasks 7-8 respectively (Task 4 added beyond the spec's own scope, per this plan's own proactive investigation finding the same staleness-gap class as Open Parts Tickets — the spec didn't anticipate this specific finding since it wasn't yet known at spec-writing time, but it's clearly in the spirit of "verify against real data, don't assume" this whole project follows). The spec's verification plan (section 4) maps to Task 2/3's row-count checks, Task 6 (Fact_OutstandingTransfers correctness), and Task 11 (post-migration row counts). The spec's explicit non-goals (section 5: no change to the real production view/dataflow, no DAX redesign, no raw-ODBC alternative) are respected throughout.

**Placeholder scan:** Task 7's findings feed Task 8 Step 3's trim decisions — a real sequential dependency (the audit must run first), matching the pattern already proven on every prior report this project. Task 6 Step 3 and Task 4's commit step both explicitly call for documenting live/real numbers observed at execution time rather than guessing them now — not a placeholder, a genuine "this number depends on when you run it" note.

**Type consistency:** `Fact_OutstandingTransfers`'s 15-column final schema (`DateKey, Date, PartTicket, LineNumber, TransDatetime, RequestingBranch, SupplyingBranch, PartNumber, TransferSubType, FulfillmentStatus, OrderQty, ShippedQty, SuppliedQty, OpenQty, OrderAge`) is consistent between the Context section's ported-logic summary and Task 5's actual PySpark code. The 3 new Silver columns (`ShippedQty`, `SoRoRef` on `Silver_InSalPar`; `TrfToBranch` on `Silver_InSalOrd`) are referenced identically across Tasks 2, 3, and 5's notebook code.
