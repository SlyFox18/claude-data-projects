# Part Master History on DP: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the LH_Master_Data PartMaster snapshots with a change-only history table on DP, kept forever, with the old snapshot tables preserved as frozen archives in DP Prod.

**Architecture:**
- A new Gold notebook, `Build_Gold_PartMasterHistory`, runs daily after `Build_Silver_PartInformation`.
- It compares Silver with the open versions and records changes with Delta `MERGE` (close) plus append (open). The same-day undo step makes reruns idempotent.
- A built-in self-test (`self_test="true"`) proves the version logic on synthetic data inside Fabric, because Spark isn't available locally.
- A one-off notebook copies the two LH snapshot tables into DP Prod unchanged.

**Spec:** `docs/superpowers/specs/2026-10-09-partmaster-history-dp-design.md`

**Deviation from the spec (decided while planning, 2026-10-09):**
- The archives go to **Prod only, with no Dev shortcut.** Dev validation compares against the LH tables directly.
- A Dev shortcut pointing at Prod would also be copied into Prod by `deploy/sync_shortcuts.py`, where it would collide with the real tables.

**Tech stack:**
- PySpark notebooks (Fabric runtime 1.3, Spark 3.5) with the Delta Lake Python API;
- `deploy/` Python with pytest;
- DuckDB `delta_scan` for checks.

**Repos:**
- **F** = `C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs`, branch `dev`. All Fabric code.
- **D** = `data-projects`, branch `dev`. Docs and the check script.

**Rules:**
- Stage named files only; F has unrelated uncommitted changes.
- No Fabric or Git deletes without Brian's explicit OK.
- Dev workspaces get code only through `tools/dp-migration/git_sync.py` (in D).
- Follow `docs/architecture/dp-notebook-rules.md`.

**IDs:**

| Item | Workspace | Lakehouse |
|---|---|---|
| DP Presentation **Dev** | `73fd5443-240e-410a-990a-98827f32c087` | `966efc8a-16f9-423b-aa43-e368fcd8fb91` |
| DP Presentation **Prod** | `7836042d-adb1-4846-b70d-bd42980054c5` | `29d9df80-a383-4d40-9807-1e2e6cbff88f` |
| LH_Master_Data | `b48cdb35-7ce3-46de-96df-d70db77649cb` | `3e74497b-8c51-4a1a-91a1-888c59118f48` |

**Facts this plan relies on (checked 2026-10-09):**
- **Dev's `Pipeline_DP_Refresh` has no schedule.** Prod runs weekdays at 06:15.
- **`Silver_PartInformation`** has 33 columns. Branch + Franchise + PartNumber is unique and there are no null keys. It's shortcut into DP_Presentation.
- **LH sizes:** `Fact_PartMaster_Snapshot_Daily` has 337M rows (15 value columns, no Franchise); `_Weekly` has 48M rows (33 columns).

---

## File structure

| File | Repo | Purpose |
|---|---|---|
| `deploy/oneoff/Utilities_ArchivePartMasterSnapshotsToProd_20261009.Notebook/` | F | One-off: copy the two LH snapshot tables into DP Prod as `*_Archive` |
| `workspaces/DP - Presentation - Dev/Fact Tables/Part Master History/Build_Gold_PartMasterHistory.Notebook/` | F | Daily history step, plus the self-test |
| `deploy/dp_refresh_dag.json` | F | + one item |
| `tools/dp-migration/partmaster_history_check.py` | D | Read-only check: history as-of vs LH daily and weekly snapshots |
| `OPERATIONS-GUIDE.md` | F | + the "Part Master history" lookup queries |
| `docs/architecture/lh-master-data-retirement.md` | D | Status updates |

---

### Task 1: Archive the LH snapshots into DP Prod (do this first; independent of everything else)

**Files:** Create F `deploy/oneoff/Utilities_ArchivePartMasterSnapshotsToProd_20261009.Notebook/.platform` and `notebook-content.py`.

- [ ] **Step 1: Write the `.platform` file.** Generate the logicalId with `python -c "import uuid; print(uuid.uuid4())"`.

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {"type": "Notebook", "displayName": "Utilities_ArchivePartMasterSnapshotsToProd_20261009"},
  "config": {"version": "2.0", "logicalId": "<new uuid>"}
}
```

- [ ] **Step 2: Write `notebook-content.py`.**

```python
# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {"name": "synapse_pyspark"},
# META   "dependencies": {"lakehouse": {
# META     "default_lakehouse": "29d9df80-a383-4d40-9807-1e2e6cbff88f",
# META     "default_lakehouse_name": "DP_Presentation",
# META     "default_lakehouse_workspace_id": "7836042d-adb1-4846-b70d-bd42980054c5",
# META     "known_lakehouses": [{"id": "29d9df80-a383-4d40-9807-1e2e6cbff88f"}]}}
# META }

# CELL ********************

# One-off (2026-10-09): freeze the LH_Master_Data PartMaster snapshot history into DP_Presentation Prod
# as *_Archive tables - exact copies, same columns and types, no conversion (spec
# docs/superpowers/specs/2026-10-09-partmaster-history-dp-design.md in data-projects, section 3).
# Never rebuilt; not in the DAG. Re-running overwrites with LH's current copy (safe until LH is retired).
from pyspark.sql import functions as F

spark.conf.set("spark.sql.parquet.datetimeRebaseModeInRead", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInWrite", "CORRECTED")
LH = "abfss://b48cdb35-7ce3-46de-96df-d70db77649cb@onelake.dfs.fabric.microsoft.com/3e74497b-8c51-4a1a-91a1-888c59118f48/Tables"


def fingerprint(df):
    """(rows, order-independent content hash) - equal on both sides means an exact copy."""
    return df.select(F.count(F.lit(1)).alias("n"), F.bit_xor(F.xxhash64(*df.columns)).alias("h")).first()


for source, target in (("Fact_PartMaster_Snapshot_Daily", "Fact_PartMaster_Snapshot_Daily_Archive"),
                       ("Fact_PartMaster_Snapshot_Weekly", "Fact_PartMaster_Snapshot_Weekly_Archive")):
    src = spark.read.format("delta").load(f"{LH}/{source}")
    src.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save(f"Tables/{target}")
    dst = spark.read.format("delta").load(f"Tables/{target}")
    a, b = fingerprint(src), fingerprint(dst)
    assert (a.n, a.h) == (b.n, b.h), f"{target}: copy differs from {source}: {a} vs {b}"
    assert src.schema == dst.schema, f"{target}: schema changed"
    print(target, f"{b.n:,} rows, fingerprint {b.h}, snapshots "
          f"{dst.agg(F.min('SnapshotDate'), F.max('SnapshotDate'), F.countDistinct('SnapshotDate')).first()}")

# METADATA ********************

# META {"language": "python", "language_group": "synapse_pyspark"}
```

- [ ] **Step 3: Run it in Prod.**
  - Run: `cd C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs && python deploy/run_oneoff_notebook.py 7836042d-adb1-4846-b70d-bd42980054c5 "deploy/oneoff/Utilities_ArchivePartMasterSnapshotsToProd_20261009.Notebook"`
  - Expected: Completed, printing `Fact_PartMaster_Snapshot_Daily_Archive` with about 337M rows from 2025-10-27, and `_Weekly_Archive` with about 48M rows over 44 snapshots. Allow up to about 30 minutes.

- [ ] **Step 4: Check independently (DuckDB, read-only).** Compare `count(*)` and `count(DISTINCT SnapshotDate)` for each archive (Prod path `abfss://7836042d-adb1-4846-b70d-bd42980054c5@onelake.dfs.fabric.microsoft.com/29d9df80-a383-4d40-9807-1e2e6cbff88f/Tables/<name>`) against the LH source. They must be equal.

- [ ] **Step 5: Commit** (F, `dev`):
  ```
  git add "deploy/oneoff/Utilities_ArchivePartMasterSnapshotsToProd_20261009.Notebook"
  git commit -m "One-off: archive LH PartMaster snapshots into DP Prod"
  git push origin dev
  ```

---

### Task 2: History notebook with self-test

**Files:** Create F `workspaces/DP - Presentation - Dev/Fact Tables/Part Master History/Build_Gold_PartMasterHistory.Notebook/.platform` (new logicalId; displayName `Build_Gold_PartMasterHistory`) and `notebook-content.py`:

- [ ] **Step 1: Write `notebook-content.py`.**

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

# PARAMETERS CELL ********************

self_test = "false"
run_date_override = ""

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Build_Gold_PartMasterHistory
# Purpose: change-only history of the part master (Silver_PartInformation = DP's jdis_Part_Information),
# all 33 columns, kept forever. Replaces LH_Master_Data's daily/weekly full snapshots (spec
# docs/superpowers/specs/2026-10-09-partmaster-history-dp-design.md in data-projects).
#
# One row per version: ValidFrom <= D < ValidTo is the state on date D (ValidTo 9999-12-31 = current).
# ChangeType: Initial (seed) / New / Changed / Removed (zero-length marker on the day a part left
# Silver) / Returned. ChangedColumns lists the columns that differ from the previous version.
#
# Idempotent per run date: the run first undoes anything already written for that date (deletes rows
# with ValidFrom = run date, reopens rows closed on it), then applies the day. A run date earlier than
# the newest ValidFrom raises - history is never rewritten backwards.
# Safety: if Silver has > MAX_SHRINK fewer rows than the open versions, raise and write nothing.
# VACUUM keeps 7 days (not 0 like other Gold tables) so Delta time travel can undo a bad day.

spark.conf.set("spark.sql.parquet.datetimeRebaseModeInRead", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInWrite", "CORRECTED")

from datetime import datetime
from functools import reduce
from zoneinfo import ZoneInfo
from pyspark.sql import Window
from pyspark.sql import functions as F
from delta.tables import DeltaTable

KEY = ["Branch", "Franchise", "PartNumber"]
OPEN_END = "9999-12-31"
MAX_SHRINK = 0.02

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

def as_of(hist, d):
    """State on date d (string 'YYYY-MM-DD')."""
    day = F.lit(d).cast("date")
    return hist.filter((F.col("ValidFrom") <= day) & (day < F.col("ValidTo")))


def apply_day(silver, path, run_date):
    """Apply one day's snapshot `silver` (KEY + value columns) to the history table at `path`."""
    vals = [c for c in silver.columns if c not in KEY]
    run, end = F.lit(run_date).cast("date"), F.lit(OPEN_END).cast("date")
    now = F.current_timestamp()
    s = silver.withColumn("RowHash", F.xxhash64(*vals))

    def version(df, change_type, changed_columns):
        return df.select(*KEY, *vals, run.alias("ValidFrom"), end.alias("ValidTo"), F.lit(True).alias("IsCurrent"),
                         change_type.alias("ChangeType"), changed_columns.alias("ChangedColumns"),
                         "RowHash", now.alias("LoadedAtUtc"))

    table = DeltaTable.forPath(spark, path) if DeltaTable.isDeltaTable(spark, path) else None
    if table is not None:
        newest = spark.read.format("delta").load(path).agg(F.max("ValidFrom")).first()[0]
        if newest is not None and str(newest) > run_date:
            raise ValueError(f"run date {run_date} is before the newest version ({newest}); history is never rewritten backwards")
        table.delete(F.col("ValidFrom") == run)
        table.update(F.col("ValidTo") == run, {"ValidTo": end, "IsCurrent": F.lit(True)})
    hist = spark.read.format("delta").load(path) if table is not None else None

    if hist is None or hist.limit(1).count() == 0:
        first = version(s, F.lit("Initial"), F.lit(""))
        first.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save(path)
        return {"Initial": first.count()}

    open_ = hist.filter("IsCurrent")
    n_open, n_silver = open_.count(), s.count()
    if n_silver < n_open * (1 - MAX_SHRINK):
        raise ValueError(f"Silver has {n_silver:,} rows vs {n_open:,} open versions (> {MAX_SHRINK:.0%} fewer) - "
                         "refusing to mark parts Removed; check Silver_PartInformation / JD Bronze")

    ever = hist.select(*KEY).distinct().withColumn("_ever", F.lit(True))
    o = open_.select(*KEY, *[F.col(c).alias(f"_o_{c}") for c in vals],
                     F.col("RowHash").alias("_o_RowHash"), F.lit(True).alias("_in_open"))
    j = (s.withColumn("_in_silver", F.lit(True)).join(o, KEY, "full_outer").join(ever, KEY, "left")
         .fillna(False, subset=["_in_silver", "_in_open", "_ever"]))
    differs = {c: ~F.col(c).eqNullSafe(F.col(f"_o_{c}")) for c in vals}
    any_diff = reduce(lambda a, b: a | b, differs.values())

    arrived = j.filter(F.col("_in_silver") & ~F.col("_in_open"))
    changed = j.filter(F.col("_in_silver") & F.col("_in_open") & any_diff)
    removed = j.filter(~F.col("_in_silver") & F.col("_in_open"))

    new_rows = version(arrived, F.when(F.col("_ever"), "Returned").otherwise("New"), F.lit("")).unionByName(
        version(changed, F.lit("Changed"), F.concat_ws(",", *[F.when(d, F.lit(c)) for c, d in differs.items()])))
    markers = removed.select(*KEY, *[F.col(f"_o_{c}").alias(c) for c in vals], run.alias("ValidFrom"),
                             run.alias("ValidTo"), F.lit(False).alias("IsCurrent"), F.lit("Removed").alias("ChangeType"),
                             F.lit("").alias("ChangedColumns"), F.col("_o_RowHash").alias("RowHash"),
                             now.alias("LoadedAtUtc"))
    close_keys = changed.select(*KEY).unionByName(removed.select(*KEY))

    counts = {"New/Returned": arrived.count(), "Changed": changed.count(), "Removed": removed.count()}
    if counts["Changed"] or counts["Removed"]:
        (table.alias("h").merge(close_keys.alias("c"),
                                " AND ".join(f"h.{k} = c.{k}" for k in KEY) + " AND h.IsCurrent")
         .whenMatchedUpdate(set={"ValidTo": run, "IsCurrent": F.lit(False)}).execute())
    new_rows.unionByName(markers).write.format("delta").mode("append").save(path)

    after = spark.read.format("delta").load(path)
    cur = after.filter("IsCurrent")
    assert cur.groupBy(*KEY).count().filter("count > 1").count() == 0, "a key has more than one open version"
    assert cur.count() == n_silver, f"open versions {cur.count():,} != Silver rows {n_silver:,}"
    w = Window.partitionBy(*KEY).orderBy("ValidFrom", "ValidTo")
    spans = after.filter("ValidFrom < ValidTo").withColumn("_prev_to", F.lag("ValidTo").over(w))
    assert spans.filter("_prev_to > ValidFrom").count() == 0, "overlapping versions"
    return counts

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

def run_self_test():
    """Synthetic 4-day scenario covering every ChangeType, a same-day rerun, the shrink guard and the backdating guard."""
    path = "Tables/_SelfTest_PartMasterHistory"
    if notebookutils.fs.exists(path):
        notebookutils.fs.rm(path, True)
    cols = ["Branch", "Franchise", "PartNumber", "Qty", "Code"]

    def day(rows):
        return spark.createDataFrame(rows, cols)

    def state(d):
        return sorted((r.PartNumber, r.Qty, r.Code)
                      for r in as_of(spark.read.format("delta").load(path), d).collect())

    def table_rows():
        return sorted(tuple(r[c] for c in cols + ["ValidFrom", "ValidTo", "IsCurrent", "ChangeType", "ChangedColumns"])
                      for r in spark.read.format("delta").load(path).collect())

    d1 = day([("1", "D", "A", 1, "x"), ("1", "D", "B", 2, "y"), ("1", "D", "C", 3, "z")])
    assert apply_day(d1, path, "2026-01-01") == {"Initial": 3}
    d2 = day([("1", "D", "A", 5, "x"), ("1", "D", "C", 3, "z"), ("1", "D", "D", 4, "q")])
    c2 = apply_day(d2, path, "2026-01-02")
    assert c2 == {"New/Returned": 1, "Changed": 1, "Removed": 1}, c2
    snapshot = table_rows()
    assert apply_day(d2, path, "2026-01-02") == c2 and table_rows() == snapshot, "same-day rerun changed the table"
    d3 = day([("1", "D", "A", 5, "w"), ("1", "D", "B", 2, "y"), ("1", "D", "C", 3, "z"), ("1", "D", "D", 4, "q")])
    apply_day(d3, path, "2026-01-03")

    assert state("2026-01-01") == [("A", 1, "x"), ("B", 2, "y"), ("C", 3, "z")]
    assert state("2026-01-02") == [("A", 5, "x"), ("C", 3, "z"), ("D", 4, "q")]
    assert state("2026-01-03") == [("A", 5, "w"), ("B", 2, "y"), ("C", 3, "z"), ("D", 4, "q")]
    h = spark.read.format("delta").load(path)
    kinds = sorted((r.PartNumber, str(r.ValidFrom), r.ChangeType, r.ChangedColumns) for r in h.collect())
    assert ("A", "2026-01-02", "Changed", "Qty") in kinds and ("A", "2026-01-03", "Changed", "Code") in kinds, kinds
    assert ("B", "2026-01-02", "Removed", "") in kinds and ("B", "2026-01-03", "Returned", "") in kinds, kinds
    assert ("D", "2026-01-02", "New", "") in kinds, kinds

    try:
        apply_day(day([("1", "D", "A", 5, "w")]), path, "2026-01-04")
        raise AssertionError("shrink guard did not fire")
    except ValueError as ex:
        assert "refusing" in str(ex)
    try:
        apply_day(d2, path, "2026-01-02")
        raise AssertionError("backdating guard did not fire")
    except ValueError as ex:
        assert "never rewritten backwards" in str(ex)
    notebookutils.fs.rm(path, True)
    print("SELF-TEST PASSED")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

if self_test.lower() == "true":
    run_self_test()
else:
    run_date = run_date_override or datetime.now(ZoneInfo("America/Chicago")).date().isoformat()
    silver = spark.read.table("Silver_PartInformation")
    result = apply_day(silver, "Tables/Fact_PartMaster_History", run_date)
    print(f"Fact_PartMaster_History {run_date}: {result}")
    spark.sql("VACUUM delta.`Tables/Fact_PartMaster_History` RETAIN 168 HOURS")
    print(spark.read.format("delta").load("Tables/Fact_PartMaster_History")
          .groupBy("ChangeType").count().orderBy("ChangeType").collect())

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 2: Add the DAG item.** In F `deploy/dp_refresh_dag.json` `items`, add it next to the other `Build_Gold_P…` items:

```json
    {
      "name": "Build_Gold_PartMasterHistory",
      "type": "notebook",
      "workspace": "presentation",
      "tier": "gold",
      "cadence": "daily",
      "dependsOn": [
        "Build_Silver_PartInformation"
      ],
      "produces": [
        "Fact_PartMaster_History"
      ],
      "extraReads": [],
      "scanIgnore": [],
      "dynamicReviewed": true
    },
```

  - `dynamicReviewed: true` is needed because the notebook writes through `DeltaTable.forPath` and a `path` argument, which `deploy/dag_scan.py` treats as dynamic. Reviewed: it writes only `Fact_PartMaster_History`; the self-test writes and removes `_SelfTest_PartMasterHistory`.

- [ ] **Step 3: Check the DAG and run the tests.**
  - Run: `cd C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs && python deploy/dag_check.py && python -m pytest deploy -q`
  - Expected: `OK` and all tests passing. If `dag_check` complains that the item reads its own table (from the VACUUM line), add `"Fact_PartMaster_History"` to `scanIgnore` and re-run.

- [ ] **Step 4: Commit, push and git sync Presentation Dev.**
  ```
  git add "workspaces/DP - Presentation - Dev/Fact Tables/Part Master History/Build_Gold_PartMasterHistory.Notebook" deploy/dp_refresh_dag.json
  git commit -m "Build_Gold_PartMasterHistory: change-only part master history with self-test"
  git push origin dev
  python C:\Users\bfox\Documents\Git-Projects\data-projects\tools\dp-migration\git_sync.py 73fd5443-240e-410a-990a-98827f32c087
  ```
  - If git sync refuses because of a conflict on `DP_Presentation` (shortcut ordering, seen 2026-10-09), Brian resolves it with Source control → Resolve conflicts → **Accept incoming changes** for that item.

- [ ] **Step 5: Run the self-test in Dev.**
  - Find the notebook's item ID with `fab get "DP - Presentation - Dev.Workspace/Build_Gold_PartMasterHistory.Notebook" -q id`.
  - Run: `python C:\Users\bfox\Documents\Git-Projects\data-projects\tools\dp-migration\run_item.py 73fd5443-240e-410a-990a-98827f32c087 <notebookId> RunNotebook 1800 --param self_test=true`
  - Expected: exit 0, and the notebook output contains `SELF-TEST PASSED`. If it fails, read the assertion message, fix `apply_day`, re-commit, re-sync and re-run. **Do not seed until the self-test passes.**

---

### Task 3: Seed in Dev and check against LH

**Files:** Create D `tools/dp-migration/partmaster_history_check.py`.

- [ ] **Step 1: Write the check script.**

```python
"""Read-only: compare Fact_PartMaster_History (as of a date) with LH_Master_Data's PartMaster snapshots.

Usage: python partmaster_history_check.py <dev|prod> <YYYY-MM-DD> [weekly]
  daily  (default): 15 shared columns vs Fact_PartMaster_Snapshot_Daily for that date. The daily
                    snapshot has no Franchise, so Branch+PartNumber keys that exist under two
                    franchises are left out of the value comparison.
  weekly          : all 33 columns vs Fact_PartMaster_Snapshot_Weekly for that date (a Sunday).
Expected differences: timing (LH snapshots 02:00 from the 01:15 ODBC refresh; DP reads JD Bronze
in the morning refresh). Anything else is a bug.
"""
import sys
import duckdb

TIERS = {"dev": "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables/",
         "prod": "abfss://7836042d-adb1-4846-b70d-bd42980054c5@onelake.dfs.fabric.microsoft.com/29d9df80-a383-4d40-9807-1e2e6cbff88f/Tables/"}
LH = "abfss://b48cdb35-7ce3-46de-96df-d70db77649cb@onelake.dfs.fabric.microsoft.com/3e74497b-8c51-4a1a-91a1-888c59118f48/Tables/"
DAILY = ["QuantityOnHand", "BinQty", "BulkBinQty", "PendingQty", "BackOrderQty", "OnOrder", "Cost", "SellPrice1",
         "ListPrice", "InventoryCost", "Current12MoSales", "Current12MoDollars", "DateLastRequested"]
TIMESTAMPS = {"DateLastRequested", "DateCreated", "StocktakeDate"}


def norm(c):
    return f"CAST({c} AS DATE)" if c in TIMESTAMPS else (f"ROUND(CAST({c} AS DOUBLE), 2)" if c not in
           {"Branch", "Franchise", "PartNumber", "Description", "Source", "SLC", "CommodityCode", "DealerGroupCode",
            "BulkBin", "Bin", "PackageQty", "Returnable", "SuperTo", "SuperFrom"} else f"TRIM(CAST({c} AS VARCHAR))")


def main(tier, d, mode="daily"):
    sys.stdout.reconfigure(encoding="utf-8")
    con = duckdb.connect()
    con.sql("INSTALL azure; LOAD azure; INSTALL delta; LOAD delta;")
    con.sql("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli', ACCOUNT_NAME 'onelake');")
    con.sql(f"""CREATE TABLE h AS SELECT * FROM delta_scan('{TIERS[tier]}Fact_PartMaster_History')
                WHERE ValidFrom <= DATE '{d}' AND DATE '{d}' < ValidTo""")
    src = "Fact_PartMaster_Snapshot_Daily" if mode == "daily" else "Fact_PartMaster_Snapshot_Weekly"
    con.sql(f"CREATE TABLE s AS SELECT * FROM delta_scan('{LH}{src}') WHERE SnapshotDate = DATE '{d}'")
    print(f"{tier} history as of {d}: {con.sql('SELECT count(*) FROM h').fetchone()[0]:,} rows; "
          f"LH {src} {d}: {con.sql('SELECT count(*) FROM s').fetchone()[0]:,} rows")
    if mode == "daily":
        key, cols = ["Branch", "PartNumber"], DAILY
        con.sql("CREATE TABLE amb AS SELECT Branch, PartNumber FROM h GROUP BY ALL HAVING count(*) > 1")
        print(f"  Branch+PartNumber under 2+ franchises (excluded): {con.sql('SELECT count(*) FROM amb').fetchone()[0]:,}")
        flt = "WHERE (Branch, PartNumber) NOT IN (SELECT (Branch, PartNumber) FROM amb)"
    else:
        key = ["Branch", "Franchise", "PartNumber"]
        cols = [c for c in con.sql("SELECT * FROM s LIMIT 0").columns
                if c not in key + ["SnapshotDate", "SnapshotWeek", "SnapshotDateTime"]]
        flt = ""
    sel = ", ".join(f"{norm(c)} AS {c}" for c in key + cols)
    con.sql(f"CREATE TABLE a AS SELECT {sel} FROM h {flt}")
    con.sql(f"CREATE TABLE b AS SELECT {sel} FROM s {flt}")
    on = " AND ".join(f"a.{k} = b.{k}" for k in key)
    print("  keys only in history:", con.sql(f"SELECT count(*) FROM a ANTI JOIN b ON {on}").fetchone()[0],
          "| keys only in LH:", con.sql(f"SELECT count(*) FROM b ANTI JOIN a ON {on}").fetchone()[0])
    total = con.sql(f"SELECT count(*) FROM a JOIN b ON {on}").fetchone()[0]
    print(f"  matched keys: {total:,}; rows differing per column:")
    for c in cols:
        n = con.sql(f"SELECT count(*) FROM a JOIN b ON {on} WHERE a.{c} IS DISTINCT FROM b.{c}").fetchone()[0]
        if n:
            print(f"    {c}: {n:,} ({n / total:.3%})")


if __name__ == "__main__":
    main(*sys.argv[1:])
```

- [ ] **Step 2: Seed Dev.**
  - First refresh Silver in Dev so it's current: run `Build_Silver_PartInformation` in DP - Staging - Dev with `run_item.py` (workspace `ab15d64d-c7ba-415d-9bcf-7feb1ef9b201`; get the notebook ID with `fab get`).
  - Then run `Build_Gold_PartMasterHistory` in Presentation Dev with no parameters.
  - Expected: it prints `{'Initial': ~1,115,000}`.

- [ ] **Step 3: Compare with the LH daily snapshot for the same date.**
  - Run: `python tools/dp-migration/partmaster_history_check.py dev <today>`
  - Expected: row counts within about 0.1%, few keys on only one side, and per-column differences under about 1%.
  - Explain any column with more. Timing explains quantity and DateLastRequested drift; a whole column differing means a mapping bug, so stop and investigate. Record the numbers in the plan's progress note.

- [ ] **Step 4: Commit the script** (D):
  ```
  git add tools/dp-migration/partmaster_history_check.py
  git commit -m "partmaster_history_check: compare DP part master history with LH snapshots"
  git push origin dev
  ```

---

### Task 4: Second Dev day, then a same-day rerun

- [ ] **Step 1: Run Silver, then the history notebook, in Dev again** on the next weekday after Task 3, the same way as Task 3 Step 2.
  - Expected: `{'New/Returned': small, 'Changed': ~5–10K, 'Removed': small}`.
- [ ] **Step 2: Check the new day.** `python tools/dp-migration/partmaster_history_check.py dev <that date>` gives the same tolerances as Task 3 Step 3.
- [ ] **Step 3: Rerun the history notebook immediately.** It must print **the same counts**, and `Fact_PartMaster_History`'s row count must not change. This proves the undo-today step on real data.
- [ ] **Step 4: Run the "changes" query from Task 5** against Dev for that date. Confirm `ChangedColumns` matches what changed (spot-check 5 parts against LH's daily snapshot for the two dates).

---

### Task 5: Lookup queries (docs)

**Files:** Modify F `OPERATIONS-GUIDE.md`; add a section after "DP Backend: Dev and Prod".

- [ ] **Step 1: Add the section.**

````markdown
## Part Master history (Fact_PartMaster_History)

Change-only history of the part master (`Silver_PartInformation`, DP's version of `jdis_Part_Information`), all 33 columns, kept forever. Each row is one version, valid from `ValidFrom` up to (not including) `ValidTo`; `9999-12-31` = current. Query it in the DP_Presentation SQL endpoint.

**What did it look like on a date?** (Shannon-type requests)
```sql
DECLARE @d date = '2026-09-08';
SELECT * FROM dbo.Fact_PartMaster_History
WHERE ValidFrom <= @d AND @d < ValidTo
  AND Branch = '1' AND Franchise = 'W';
```

**What changed on a date, before and after?** (incidents like the 2026 "COTTON" commodity-code mass change)
```sql
DECLARE @d date = '2026-10-09';
SELECT n.Branch, n.Franchise, n.PartNumber, n.ChangedColumns,
       o.CommodityCode AS OldCommodityCode, n.CommodityCode AS NewCommodityCode
FROM dbo.Fact_PartMaster_History n
JOIN dbo.Fact_PartMaster_History o
  ON o.Branch = n.Branch AND o.Franchise = n.Franchise AND o.PartNumber = n.PartNumber
 AND o.ValidTo = n.ValidFrom AND o.ChangeType <> 'Removed'
WHERE n.ValidFrom = @d AND n.ChangeType = 'Changed'
  AND n.ChangedColumns LIKE '%CommodityCode%';
```
Swap the column names to see other fields' old and new values. `ChangeType` also marks parts that appeared (`New`), disappeared (`Removed`) or came back (`Returned`) that day.

**Before go-live:** dates before the history table's first `ValidFrom` are in the frozen archives `Fact_PartMaster_Snapshot_Daily_Archive` (15 columns, no Franchise, from 2025-10-27) and `Fact_PartMaster_Snapshot_Weekly_Archive` (all 33 columns, Sundays) in DP_Presentation **Prod**. Filter them on `SnapshotDate`.

**Undoing a bad day:** the table keeps 7 days of Delta versions (`VACUUM ... RETAIN 168 HOURS`), so a bad run can be rolled back with Delta time travel (`RESTORE TABLE ... TO VERSION AS OF n` in a notebook) within a week.
````

- [ ] **Step 2: Commit** (F): `git add OPERATIONS-GUIDE.md && git commit -m "OPERATIONS-GUIDE: Part Master history lookups" && git push origin dev`

---

### Task 6: Prod release (this also releases the JD price backend; do both together)

Merging `dev` into `main` deploys **everything** on `dev`, including the JD price items (`df_JDPriceFiles_Raw`, `Build_Silver_JDPriceFiles`, `Build_Gold_JDPriceChanges`, freshness checks). Their Prod prerequisites (JD plan `docs/superpowers/plans/2026-10-08-jd-price-data-dp.md`, Task 9) must be done in the same release, **before the first 06:15 Prod run after the deploy.**

- [ ] **Step 1: JD Silver history into Prod Staging, BEFORE the deploy.** Create and run the one-off from JD plan Task 9 Step 6 (`deploy/oneoff/Utilities_CopyJDPriceSilverToProd_20261008.Notebook`). It copies `Silver_PriceUpdate_History` and `Silver_JDChangeReport_History` from Staging Dev to Staging Prod.
  - Then the first Prod run loads only files newer than the copy.
- [ ] **Step 2: Preview, PR and merge.** `python deploy/merge_preview.py`, then open a PR `dev` → `main` (template `.github/PULL_REQUEST_TEMPLATE/dev_to_main.md`). **Brian merges with "Create a merge commit".**
- [ ] **Step 3 (Brian): Deploy.** Actions → **Deploy DP backend** → Run workflow from `main`.
- [ ] **Step 4: Post-deploy.**
  - `python deploy/claim_prod_pipeline.py`.
  - Fast-forward dev: `git fetch origin && git merge --ff-only origin/main && git push origin dev`.
  - `python deploy/sync_shortcuts.py`, then `--apply`. This creates the Prod shortcuts for the two JD Silver tables.
- [ ] **Step 5 (Brian): check the Prod dataflow.** Open `df_JDPriceFiles_Raw` in DP - Staging - Prod. Confirm the connection is `Network_Folder_DailyReports` and both destinations are **Prod** DP_Staging. Save.
- [ ] **Step 6: Run in Prod.** Run Prod `Pipeline_DP_Refresh` with `mode=items` and `items=df_JDPriceFiles_Raw,Build_Silver_JDPriceFiles,Build_Gold_JDPriceChanges,Build_Silver_PartInformation,Build_Gold_PartMasterHistory`.
  - Use `run_pipeline.py`'s pattern against workspace `7836042d-…`, or Brian runs it from the UI.
  - Expected: all Succeeded. History prints `{'Initial': ~1.1M}`. JD Silver prints only a few files to (re)load.
- [ ] **Step 7: Verify.**
  - `python tools/dp-migration/partmaster_history_check.py prod <date>`, same tolerances as Task 3.
  - `python deploy/compare_tiers.py Fact_PartPriceChange Fact_PartPriceChange_Branch Fact_JDNationalPriceChange`: identical, or only files that arrived between the runs.
- [ ] **Step 8: Self-test in Prod once** (`--param self_test=true` against the Prod notebook). Expected: `SELF-TEST PASSED`.

---

### Task 7: Side-by-side run (about 2 weeks), then retire LH

- [ ] **Step 1: Each weekday** for about 2 weeks, run `python tools/dp-migration/partmaster_history_check.py prod <date>`, and on Sundays/Mondays also the `weekly` mode for the Sunday date.
  - Log a one-line result per day in the plan's progress note.
  - Any unexplained difference stops the retirement.
- [ ] **Step 2 (Brian approves, then turn off schedules only, nothing deleted):**
  - `DF_PartMaster_Snapshot_Daily`, `DF_PartMaster_Snapshot_Weekly`, and the interim `df_JDIS_PART_INFORMATION_Raw` (Mon–Sat 01:15).
  - Once JD price Prod has run cleanly for a few days: `pl_Raw_PriceUpdate_History`, and on Brian's PC `Disable-ScheduledTask -TaskPath "\Fabric\" -TaskName "JD Price Update Harvest"`.
  - Then update `Send-JDChangeReportReminder.ps1`'s text (JD plan Task 10 Step 3).
- [ ] **Step 3: Update records.**
  - `docs/architecture/lh-master-data-retirement.md`: rows OFF with dates.
  - Memory: `project_jd_price_updates_dax_report_build.md` (Prod live) and a new `project_partmaster_history.md` (pointer in MEMORY.md).
  - Commit D and F.
