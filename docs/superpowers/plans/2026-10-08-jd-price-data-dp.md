# JD Price Data on DP: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ingest JD's branch price-update files and national Change Report from the network share into DP (Dev, then Prod), with each file loaded exactly once, three report-ready Gold facts and a freshness warning. Then retire the LH_Master_Data price ingestion.

**Architecture:**
- A Staging Dataflow Gen2 reads both share folders through SPI-Data-Gateway, writing raw text lines to two landing tables.
- `Build_Silver_JDPriceFiles` parses them and loads each file once, using a per-file row-count check and an atomic `replaceWhere`.
- `Build_Gold_JDPriceChanges` builds the facts.
- The orchestrator gains a generic `freshnessChecks` config that adds warnings to the daily email.

**Spec:** `docs/superpowers/specs/2026-10-08-jd-price-data-dp-design.md`

> **Progress (2026-10-09):**
> - **Tasks 1–7 are DONE in Dev.**
>   - Freshness checks are live in the config.
>   - The dataflow commit has `LookbackDays = 35`.
>   - Silver was verified against LH; Gold was verified and is deterministic.
>   - The Dev pipeline run (`mode=items`) went OK.
> - **Changes from the plan as written:**
>   - The dataflow M is two self-contained queries.
>   - Silver stitches records split by a quoted line break, which was the real "row-shift defect" (807 records).
>   - Gold gained explicit Old/New + margin columns, because `Dealer*` list and cost are the OLD values (proven 99.6%). The first report had cost backwards.
>   - Branch 4B rolls into 4 (Brian).
> - **Task 8, done differently:** the report was copied to fabric-workspace-docs `workspaces/RP - Dev/JD Price Updates.*`, repointed there, committed and git-synced into RP - Dev. The data-projects copy is frozen as reference.
>   - Still open: the service connection mapping, plus report work in a separate chat.
> - **Task 9 DONE 2026-10-09** (released with the Part Master history, PR #28):
>   - one-off Silver copy into Prod Staging before the deploy;
>   - deploy, claim, shortcuts;
>   - Prod items run OK;
>   - compare_tiers: `Fact_PartPriceChange` and `_Branch` identical; the national fact differs in 3 `IsStockedPart` rows (newer Prod dim_Parts).
>   - **Prod runs these daily at 06:15 on weekdays.**
> - **Task 10 is OPEN.** After a few clean Prod days, switch off LH `pl_Raw_PriceUpdate_History` and the PC task `JD Price Update Harvest`, then update the reminder text and docs (Brian's OK).

**Tech stack:**
- Fabric Dataflow Gen2 (M), PySpark notebooks (Fabric runtime 1.3 / Spark 3.5);
- `deploy/` Python with pytest;
- DuckDB `delta_scan` for checks;
- Power BI PBIP (TMDL).

**Repos:**
- **F** = `C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs`, branch `dev`. All Fabric code.
- **D** = `data-projects`, branch `dev`. Docs, the local report, the PC scripts.

**Standing rules:**
- Stage only the files named in each step. F has unrelated uncommitted user changes; leave them alone.
- No Fabric or Git deletes without Brian's explicit OK.
- Dev workspaces get code only through `tools/dp-migration/git_sync.py` (in D). Never use `fab import`.

**Known IDs:**

| Item | Workspace | Lakehouse |
|---|---|---|
| DP - Staging - Dev | `ab15d64d-c7ba-415d-9bcf-7feb1ef9b201` | DP_Staging `876255e0-d462-4697-adc1-4a655f5bb101` |
| DP - Presentation - Dev | `73fd5443-240e-410a-990a-98827f32c087` | DP_Presentation `966efc8a-16f9-423b-aa43-e368fcd8fb91` |
| LH_Master_Data (old) | `b48cdb35-7ce3-46de-96df-d70db77649cb` | `3e74497b-8c51-4a1a-91a1-888c59118f48` |

| Other | Value |
|---|---|
| Gateway | SPI-Data-Gateway `d98a8d2c-d0df-4a42-a281-aab18e49dbd7` |
| Existing Folder connection | `Network_Folder` `289c15fd-8bb9-4140-b631-4bdd21fee695`, path `...\Daily_Reports\Price_Update` |

---

## File structure

| File | Repo | Responsibility |
|---|---|---|
| `deploy/orchestrator_core.py` | F | + `freshness_warnings()` (pure) |
| `deploy/test_orchestrator_core.py` | F | + freshness tests |
| `deploy/dag_config.py` | F | + validation of optional `orchestrator.freshnessChecks` |
| `deploy/test_dag_config.py` | F | + validation tests |
| `deploy/orchestrator_glue.py` | F | + run the freshness queries after Silver |
| `workspaces/DP - Staging - Dev/*/Run_DP_Refresh.Notebook`, `workspaces/DP - Presentation - Dev/Orchestration/Run_DP_Refresh.Notebook` | F | re-rendered |
| `workspaces/DP - Staging - Dev/Raw Data - Dataflows/df_JDPriceFiles_Raw.Dataflow/` | F | gateway file reader (created in the UI, committed from the workspace) |
| `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_JDPriceFiles.Notebook/` | F | parse + load each file once |
| `workspaces/DP - Presentation - Dev/Fact Tables/JD Price Updates/Build_Gold_JDPriceChanges.Notebook/` | F | 3 Gold facts |
| `workspaces/DP - Presentation - Dev/DP_Presentation.Lakehouse/shortcuts.metadata.json` | F | + 2 Silver shortcuts |
| `deploy/dp_refresh_dag.json` | F | + 3 items, + `freshnessChecks` |
| `deploy/oneoff/Utilities_CopyJDPriceSilverToProd_20261008.Notebook/` | F | one-off Prod backfill |
| `projects/jd-price-updates/reports/JD Price Updates.SemanticModel/...` | D | repoint to Gold |
| `projects/jd-price-updates/README.md`, `scripts/Send-JDChangeReportReminder.ps1` | D | new process |
| `.claude/queries/raw-tables/JDPriceFiles_Raw.pq` | D | query-library copy of the dataflow M |

---

### Task 1: Freshness warnings (orchestrator, TDD)

**Files:** F `deploy/orchestrator_core.py`, `deploy/test_orchestrator_core.py`, `deploy/dag_config.py`, `deploy/test_dag_config.py`, `deploy/orchestrator_glue.py`, plus the rendered notebooks.

- [ ] **Step 1: Write the failing core tests.** Append to `deploy/test_orchestrator_core.py` and add `freshness_warnings` to its `from orchestrator_core import (...)` list:

```python
from datetime import date


def test_freshness_fresh_source_gives_no_warning():
    checks = [{"table": "T", "column": "D", "maxAgeDays": 8, "label": "Feed"}]
    assert freshness_warnings(checks, {"T": date(2026, 10, 4)}, date(2026, 10, 12)) == []


def test_freshness_stale_source_warns_with_age():
    checks = [{"table": "T", "column": "D", "maxAgeDays": 8, "label": "Feed"}]
    w = freshness_warnings(checks, {"T": date(2026, 10, 4)}, date(2026, 10, 13))
    assert w == ["Feed: newest data is 2026-10-04 (9 days old, limit 8) - check the source folder"]


def test_freshness_missing_or_empty_table_warns():
    checks = [{"table": "T", "column": "D", "maxAgeDays": 8, "label": "Feed"}]
    assert freshness_warnings(checks, {}, date(2026, 10, 13)) == ["Feed: no data found in T"]
    assert freshness_warnings(checks, {"T": None}, date(2026, 10, 13)) == ["Feed: no data found in T"]


def test_freshness_accepts_datetimes():
    checks = [{"table": "T", "column": "D", "maxAgeDays": 1, "label": "Feed"}]
    assert freshness_warnings(checks, {"T": datetime(2026, 10, 12, 23, 0)}, date(2026, 10, 13)) == []
```

- [ ] **Step 2: Run them; they must fail.**
  - Run: `cd C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs && python -m pytest deploy/test_orchestrator_core.py -q -k freshness`
  - Expected: ImportError, because `freshness_warnings` doesn't exist yet.

- [ ] **Step 3: Implement.** Add to `deploy/orchestrator_core.py`, after `compose_summary`:

```python
def freshness_warnings(checks: list, newest: dict, today) -> list:
    """One warning per orchestrator.freshnessChecks entry whose table is empty or older than maxAgeDays.

    newest maps table name -> newest date (or datetime, or None) found in that table's column."""
    out = []
    for c in checks:
        d = newest.get(c["table"])
        if d is None:
            out.append(f"{c['label']}: no data found in {c['table']}")
            continue
        d = d.date() if hasattr(d, "date") else d
        age = (today - d).days
        if age > c["maxAgeDays"]:
            out.append(f"{c['label']}: newest data is {d.isoformat()} ({age} days old, "
                       f"limit {c['maxAgeDays']}) - check the source folder")
    return out
```

- [ ] **Step 4: Run them; they pass.** Same command as Step 2. Expected: 4 passed.

- [ ] **Step 5: Write the failing config-validation tests.** Append to `deploy/test_dag_config.py`:

```python
def test_freshness_checks_optional_and_validated():
    config, notebooks, reports = base()
    config["orchestrator"] = dict(GOOD_SETTINGS)
    assert check(config, notebooks, reports) == []
    good = [{"table": "Silver_A", "column": "SourceFileDate", "maxAgeDays": 8, "label": "Feed"}]
    config["orchestrator"] = dict(GOOD_SETTINGS, freshnessChecks=good)
    assert check(config, notebooks, reports) == []
    for bad in ({}, [{"table": "Silver_A", "column": "D", "maxAgeDays": 0, "label": "x"}],
                [{"table": "Silver_A", "column": "D", "label": "x"}],
                [{"table": "", "column": "D", "maxAgeDays": 3, "label": "x"}]):
        config["orchestrator"] = dict(GOOD_SETTINGS, freshnessChecks=bad)
        assert any("freshnessChecks" in e for e in check(config, notebooks, reports)), bad
```

- [ ] **Step 6: Run it; it must fail.**
  - Run: `python -m pytest deploy/test_dag_config.py -q -k freshness`
  - Expected: FAIL, because the bad values are accepted.

- [ ] **Step 7: Implement.** In `deploy/dag_config.py` `_check_orchestrator`, add before `errors += check_notify(...)`:

```python
    if "freshnessChecks" in settings:
        fc = settings["freshnessChecks"]
        if not isinstance(fc, list):
            errors.append("orchestrator: freshnessChecks must be a list")
        else:
            for i, c in enumerate(fc):
                ok = (isinstance(c, dict)
                      and all(isinstance(c.get(k), str) and c.get(k) for k in ("table", "column", "label"))
                      and isinstance(c.get("maxAgeDays"), int) and c["maxAgeDays"] >= 1)
                if not ok:
                    errors.append(f"orchestrator: freshnessChecks[{i}] needs table, column, label (text) "
                                  f"and maxAgeDays (integer >= 1)")
```

- [ ] **Step 8: Run it; it passes.** Same command as Step 6.

- [ ] **Step 9: Wire it into the glue.** In `deploy/orchestrator_glue.py`, Silver branch, immediately after the `for n, culprit in skipped.items(): ...` loop that follows `run_dag(dag)` (inside `if not summary["bronze_problems"]:`), add:

```python
                checks = SETTINGS.get("freshnessChecks") or []
                newest = {}
                for c in checks:
                    try:
                        newest[c["table"]] = spark.sql(
                            f"SELECT max(`{c['column']}`) FROM delta.`Tables/{c['table']}`").first()[0]
                    except Exception as ex:
                        summary["warnings"].append(f"freshness check on {c['table']} could not run "
                                                   f"({type(ex).__name__}: {str(ex)[:200]})")
                        newest[c["table"]] = "skip"
                summary["warnings"] += freshness_warnings(
                    [c for c in checks if newest.get(c["table"]) != "skip"], newest, datetime.now(CENTRAL).date())
```

  - These lines live in the non-dry-run path, so dry runs never query.
  - The tables are read from the Staging lakehouse, which is the Silver orchestrator's default lakehouse.
  - The Gold orchestrator already copies `upstream["warnings"]` into its email.

- [ ] **Step 10: Re-render and run the full suite.**
  - Run: `python deploy/render_orchestrator.py && python -m pytest deploy -q`
  - Expected: all pass (169 before this task, plus 5 new).

- [ ] **Step 11: Commit.**
  ```
  git add deploy/orchestrator_core.py deploy/test_orchestrator_core.py deploy/dag_config.py deploy/test_dag_config.py deploy/orchestrator_glue.py "workspaces/DP - Staging - Dev/Orchestration/Run_DP_Refresh.Notebook/notebook-content.py" "workspaces/DP - Presentation - Dev/Orchestration/Run_DP_Refresh.Notebook/notebook-content.py"
  git commit -m "Orchestrator: optional freshnessChecks add stale-source warnings to the DP email"
  ```

---

### Task 2: Gateway access (Brian, UI) + check (Claude)

- [ ] **Step 1 (Brian): grant access on the connection.** Fabric → Settings → **Manage connections and gateways** → `Network_Folder` → **Manage users**. Make sure these have **User**:
  - Brian (the pipeline runs as Brian);
  - **SPN-Fabric-CICD-Deploy** (deploys the Prod dataflow).
- [ ] **Step 2 (Brian): add a parent-folder connection.** On the same screen, **+ New** → On-premises → gateway **SPI-Data-Gateway** → type **Folder**:
  - Name `Network_Folder_DailyReports`, path `\\Eqsvc01-sp2010\equip\UWS\Poll\Daily_Reports`.
  - Use the same Windows credentials as `Network_Folder`.
  - Grant the same two users.
  - One connection on the parent covers both subfolders, so the dataflow needs only one.
- [ ] **Step 3 (Claude): check the new connection.** List connections with the read-only Fabric `connections` API. Confirm `Network_Folder_DailyReports` exists on gateway `d98a8d2c-…` and note its ID for Task 9.

---

### Task 3: Landing dataflow in Dev (Brian builds in UI; Claude checks)

- [ ] **Step 1 (Brian): create the dataflow.**
  - In **DP - Staging - Dev**, folder `Raw Data - Dataflows`: **New → Dataflow Gen2**, named `df_JDPriceFiles_Raw`.
  - **Do not tick "Enable Git integration…"**; the workspace commit handles Git.
  - Add **two Blank queries**, one at a time. The query box takes a single `let … in` expression, not a whole `section` document; the first version of this plan had that wrong (2026-10-08).
  - Each query is self-contained. Name the first `Landing_PriceUpdate_Lines` and paste:

```m
let
    // Raw lines only; Build_Silver_JDPriceFiles (DP_Staging) parses them.
    // Only files whose name date is within LookbackDays: 100000 for the one-time backfill, then 35.
    LookbackDays = 100000,
    FileLines = (files as table) as table =>
        let
            AddLines = Table.AddColumn(files, "L", each
                let l = Lines.FromBinary([Content], null, null, 1252)
                in Table.FromColumns({List.Transform(List.Positions(l), each _ + 1), l},
                                     type table [LineNumber = Int64.Type, LineText = text])),
            Keep = Table.SelectColumns(AddLines, {"Name", "Date modified", "L"}),
            Expanded = Table.ExpandTableColumn(Keep, "L", {"LineNumber", "LineText"}),
            Renamed = Table.RenameColumns(Expanded, {{"Name", "SourceFileName"}, {"Date modified", "SourceFileModified"}}),
            NonBlank = Table.SelectRows(Renamed, each Text.Trim([LineText] ?? "") <> ""),
            Typed = Table.TransformColumnTypes(NonBlank, {{"SourceFileName", type text},
                {"SourceFileModified", type datetime}, {"LineNumber", Int64.Type}, {"LineText", type text}})
        in
            Typed,
    Source = Folder.Files("\\Eqsvc01-sp2010\equip\UWS\Poll\Daily_Reports\Price_Update"),
    Named = Table.SelectRows(Source, each Text.StartsWith(Text.Upper([Name]), "PRICEUPDATE_")
                                     and Text.EndsWith(Text.Upper([Name]), ".TXT")),
    WithDate = Table.AddColumn(Named, "FileDate", each
        let p = Text.Split([Name], "_")
        in try #date(Number.FromText(p{3}), Number.FromText(p{1}), Number.FromText(p{2})) otherwise null),
    Recent = Table.SelectRows(WithDate, each [FileDate] <> null and
        [FileDate] >= Date.AddDays(DateTime.Date(DateTimeZone.RemoveZone(DateTimeZone.UtcNow())), -LookbackDays)),
    Result = FileLines(Recent)
in
    Result
```

  - Name the second `Landing_JDChangeReport_Lines` and paste:

```m
let
    // Raw lines only; Build_Silver_JDPriceFiles (DP_Staging) parses them.
    // All files every run - the folder is small (about 1 file/week).
    FileLines = (files as table) as table =>
        let
            AddLines = Table.AddColumn(files, "L", each
                let l = Lines.FromBinary([Content], null, null, 1252)
                in Table.FromColumns({List.Transform(List.Positions(l), each _ + 1), l},
                                     type table [LineNumber = Int64.Type, LineText = text])),
            Keep = Table.SelectColumns(AddLines, {"Name", "Date modified", "L"}),
            Expanded = Table.ExpandTableColumn(Keep, "L", {"LineNumber", "LineText"}),
            Renamed = Table.RenameColumns(Expanded, {{"Name", "SourceFileName"}, {"Date modified", "SourceFileModified"}}),
            NonBlank = Table.SelectRows(Renamed, each Text.Trim([LineText] ?? "") <> ""),
            Typed = Table.TransformColumnTypes(NonBlank, {{"SourceFileName", type text},
                {"SourceFileModified", type datetime}, {"LineNumber", Int64.Type}, {"LineText", type text}})
        in
            Typed,
    Source = Folder.Files("\\Eqsvc01-sp2010\equip\UWS\Poll\Daily_Reports\JD_Change_Report"),
    Named = Table.SelectRows(Source, each Text.StartsWith(Text.Upper([Name]), "US.UPDCOMP.UPDATE.V2-")
                                     and Text.EndsWith(Text.Upper([Name]), ".CSV")),
    Result = FileLines(Named)
in
    Result
```

- [ ] **Step 2 (Brian): bind the credentials.** When prompted for credentials, pick the connection `Network_Folder_DailyReports` from Task 2. Both queries use it.
- [ ] **Step 3 (Brian): set the output.**
  - Set a **data destination** on each query: Lakehouse `DP_Staging` (DP - Staging - Dev), new table with the same name, **Update method: Replace**, schema mapping as shown (4 columns).
- [ ] **Step 4 (Brian): Save & run** (the backfill, because `LookbackDays = 100000`). Expected runtime is 5–15 minutes.
- [ ] **Step 5 (Claude): check the backfill.** Run read-only DuckDB on the Dev Staging tables:

```sql
SELECT count(DISTINCT SourceFileName) files, count(*) lines FROM delta_scan('<staging>/Tables/Landing_PriceUpdate_Lines');
-- expect 4,792 files (+ any new on the share); lines ≈ 5.10M data lines + 1 header per file
SELECT count(DISTINCT SourceFileName), count(*) FROM delta_scan('<staging>/Tables/Landing_JDChangeReport_Lines');
-- expect 13 files
```

  - `<staging>` = `abfss://ab15d64d-c7ba-415d-9bcf-7feb1ef9b201@onelake.dfs.fabric.microsoft.com/876255e0-d462-4697-adc1-4a655f5bb101`.
  - If the Change Report table is empty with a credential error, Task 2's parent connection isn't being used. Fix the binding, then re-run.
- [ ] **Step 6 (Brian, after Task 4 Step 6 passes): switch to daily mode.** In `Landing_PriceUpdate_Lines`'s Advanced editor, change `LookbackDays = 100000,` to `LookbackDays = 35,`, then Save. **Do not run it yet.**
- [ ] **Step 7 (Brian): commit from the workspace.** DP - Staging - Dev → **Source control** → commit only `df_JDPriceFiles_Raw`, message `Add df_JDPriceFiles_Raw (gateway file reader)`.
- [ ] **Step 8 (Claude): pull and copy to the query library.**
  - `git pull` in F.
  - Confirm `queryMetadata.json` shows `gatewayObjectId` `d98a8d2c-…` and that the mashup has `LookbackDays = 35`.
  - Copy the M into D `.claude/queries/raw-tables/JDPriceFiles_Raw.pq`, with the standard header comment (purpose, grain = one row per file line, source = share via SPI-Data-Gateway, business use).

---

### Task 4: Silver notebook

**Files:** F `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_JDPriceFiles.Notebook/notebook-content.py` and `.platform`; `deploy/dp_refresh_dag.json`.

- [ ] **Step 1: Create the `.platform` file.** Copy `Build_Silver_InMaster.Notebook/.platform` and change `displayName` to `Build_Silver_JDPriceFiles`. Give it a new `logicalId` from `python -c "import uuid; print(uuid.uuid4())"`.

- [ ] **Step 2: Write `notebook-content.py`.** Keep the METADATA header block exactly as in `Build_Silver_InMaster` (default lakehouse DP_Staging). The cells are below; each cell is separated by `# METADATA` / `# CELL` markers in the same style as that file.

```python
# Build_Silver_JDPriceFiles
# Purpose: Parse JD's two price feeds from the landing tables written by
# df_JDPriceFiles_Raw (one row per file line) into typed Silver history,
# loading EACH FILE EXACTLY ONCE.
#
# Load rule (spec 2026-10-08): for each file in landing, compare its data-row
# count with Silver's rows for that SourceFileName. New file -> insert; count
# differs -> replace that file's rows (atomic replaceWhere); same -> skip.
# Files older than the landing window are never touched, so history survives.
# This replaces LH_Master_Data's append-then-delete-New/ design, which loaded
# 93 price files twice and one Change Report 5 times.
#
# Source realities (projects/jd-price-updates/README.md):
# - Price files: tab-delimited, header = 20 columns, or 19 before ~2018-2020
#   (no sell_price_old; it is the LAST column, so positions are identical).
# - JD row-shift defect: some rows are missing 6 fields. Rows whose field
#   count differs from the header keep Branch/Franchise/PartNumber only and
#   get IsMalformedRow = true.
# - Manufacturer* = JD's incoming price, Dealer* = our current system price,
#   *Diff = Manufacturer - Dealer (checked on PRICEUPDATE_10_04_2026_96.TXT).
# - Change Report: comma-delimited, records padded to fixed width (trim).

spark.conf.set("spark.sql.parquet.datetimeRebaseModeInRead", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInWrite", "CORRECTED")

print("=" * 80)
print("BUILD_SILVER_JDPRICEFILES")
print("=" * 80)
```

```python
from pyspark.sql import functions as F
from pyspark.sql import Window
from delta.tables import DeltaTable

PU_TARGET = "Tables/Silver_PriceUpdate_History"
CR_TARGET = "Tables/Silver_JDChangeReport_History"

PU_HEADER = ["branch", "inmaster_franchise", "part_no", "inmanuf_list_price", "inmaster_list_price",
             "cc_price_decrease", "bin_location", "category", "inmaster_on_hand_qty",
             "inmanuf_replace_price", "inmaster_replace_price", "inmanuf_sell_price1",
             "inmaster_sell_price1", "cost_diff", "list_diff", "sel1_diff", "effective_date",
             "update_code", "part_desc", "sell_price_old"]
PU_TEXT = {"inmaster_franchise": "Franchise", "part_no": "PartNumber", "bin_location": "BinLocation",
           "category": "Category", "update_code": "UpdateCode", "part_desc": "PartDescription"}
PU_NUM = {"inmanuf_list_price": "ManufacturerListPrice", "inmaster_list_price": "DealerListPrice",
          "cc_price_decrease": "ListPriceChangePercent", "inmaster_on_hand_qty": "OnHandQty",
          "inmanuf_replace_price": "ManufacturerReplacePrice", "inmaster_replace_price": "DealerReplacePrice",
          "inmanuf_sell_price1": "ManufacturerSellPrice1", "inmaster_sell_price1": "DealerSellPrice1",
          "cost_diff": "CostDiff", "list_diff": "ListDiff", "sel1_diff": "SellPrice1Diff",
          "sell_price_old": "SellPriceOld"}
CR_HEADER = ["PART NUMBER", "CURRENT DNP", "CURRENT SLP", "NEW DNP", "NEW SLP", "EFFECTIVE DATE"]
CR_NUM = {"CURRENT DNP": "CurrentDNP", "CURRENT SLP": "CurrentSLP", "NEW DNP": "NewDNP", "NEW SLP": "NewSLP"}


def blank_to_null(c):
    return F.when(F.trim(c) == "", None).otherwise(F.trim(c))


def to_num(c):
    return F.expr(f"try_cast(nullif(trim({c}), '') AS DOUBLE)")


def to_date(c):
    return F.expr(f"CAST(try_to_timestamp(nullif(trim({c}), ''), 'M/d/yyyy') AS DATE)")


def bad_parse(raw_col, parsed_col):
    """Non-blank text that failed to parse."""
    return F.coalesce(F.trim(F.col(raw_col)) != "", F.lit(False)) & F.col(parsed_col).isNull()


def split_header(lines):
    """(header rows, data rows): the header is each file's first non-blank line."""
    first = lines.groupBy("SourceFileName").agg(F.min("LineNumber").alias("HeaderLine"))
    tagged = lines.join(first, "SourceFileName")
    return (tagged.filter("LineNumber = HeaderLine").drop("HeaderLine"),
            tagged.filter("LineNumber > HeaderLine").drop("HeaderLine"))


def files_to_load(data_rows, target):
    landing = data_rows.groupBy("SourceFileName").agg(F.count("*").alias("n"))
    if not DeltaTable.isDeltaTable(spark, target):
        return sorted(r.SourceFileName for r in landing.collect())
    have = spark.read.format("delta").load(target).groupBy("SourceFileName").agg(F.count("*").alias("have"))
    todo = landing.join(have, "SourceFileName", "left").filter("have IS NULL OR have <> n")
    return sorted(r.SourceFileName for r in todo.select("SourceFileName").collect())


def write_files(df, target, files):
    if not DeltaTable.isDeltaTable(spark, target):
        df.write.format("delta").save(target)
        return
    in_list = ", ".join("'" + f.replace("'", "''") + "'" for f in files)
    (df.write.format("delta").mode("overwrite")
       .option("replaceWhere", f"SourceFileName IN ({in_list})").save(target))
```

```python
# ---------- Branch price updates ----------
lines = spark.read.table("Landing_PriceUpdate_Lines")
headers, data = split_header(lines)

full, legacy = "\t".join(PU_HEADER), "\t".join(PU_HEADER[:19])
hdr = headers.select("SourceFileName", F.rtrim("LineText").alias("h"))
unknown = [r.SourceFileName for r in hdr.filter(~F.col("h").isin(full, legacy)).collect()]
if unknown:
    raise ValueError(f"{len(unknown)} price file(s) have an unknown header layout (JD changed the format?): "
                     f"{unknown[:20]}")
hdr = hdr.withColumn("HeaderFields", F.when(F.col("h") == full, 20).otherwise(19)).drop("h")

name_re = r"(?i)^PRICEUPDATE_(\d{2})_(\d{2})_(\d{4})_(\d{1,3}[A-Za-z]?)\.TXT$"
data = (data.join(hdr, "SourceFileName")
        .withColumn("SourceFileDate", F.expr(
            f"make_date(int(regexp_extract(SourceFileName, '{name_re}', 3)), "
            f"int(regexp_extract(SourceFileName, '{name_re}', 1)), "
            f"int(regexp_extract(SourceFileName, '{name_re}', 2)))"))
        .withColumn("SourceFileBranch", F.regexp_extract("SourceFileName", name_re, 4)))
bad_names = [r.SourceFileName for r in data.filter("SourceFileDate IS NULL").select("SourceFileName").distinct().collect()]
if bad_names:
    print(f"WARNING: skipping {len(bad_names)} file(s) whose name has no valid date: {bad_names[:20]}")
data = data.filter("SourceFileDate IS NOT NULL")

todo = files_to_load(data, PU_TARGET)
print(f"Price files in landing: {data.select('SourceFileName').distinct().count():,}; to (re)load: {len(todo):,}")

if todo:
    d = (data.filter(F.col("SourceFileName").isin(todo))
         .withColumn("f", F.split("LineText", "\t", -1))
         .withColumn("IsMalformedRow", F.size("f") != F.col("HeaderFields")))
    raw = {}
    for i, name in enumerate(PU_HEADER):
        v = F.get(F.col("f"), i)
        if i >= 3:  # beyond Branch/Franchise/PartNumber, a shifted row's fields are untrustworthy
            v = F.when(~F.col("IsMalformedRow"), v)
        if name == "sell_price_old":
            v = F.when(F.col("HeaderFields") == 20, v)
        raw[name] = v
    d = d.select("SourceFileName", "SourceFileDate", "SourceFileBranch", "IsMalformedRow",
                 F.col("LineNumber").alias("SourceLineNumber"),
                 *[raw[n].alias(f"raw_{n}") for n in PU_HEADER])
    d = d.withColumn("Branch", F.expr("try_cast(nullif(regexp_replace(trim(raw_branch), '[^0-9]', ''), '') AS INT)"))
    for src, dst in PU_TEXT.items():
        d = d.withColumn(dst, blank_to_null(F.col(f"raw_{src}")))
    for src, dst in PU_NUM.items():
        d = d.withColumn(dst, to_num(f"raw_{src}"))
    d = d.withColumn("EffectiveDate", to_date("raw_effective_date"))
    issue = (bad_parse("raw_effective_date", "EffectiveDate")
             | (F.coalesce(F.trim("raw_branch") != "", F.lit(False)) & F.col("Branch").isNull()))
    for src, dst in PU_NUM.items():
        issue = issue | bad_parse(f"raw_{src}", dst)
    d = (d.withColumn("HasTypeConversionIssue", issue)
          .withColumn("BranchMismatchFlag",
                      F.coalesce(F.regexp_replace("SourceFileBranch", "[^0-9]", "").cast("int") != F.col("Branch"),
                                 F.lit(False)))
          .withColumn("LoadedAtUtc", F.current_timestamp()))
    pu = d.select("Branch", "PartNumber", "EffectiveDate", "Franchise", "PartDescription", "Category",
                  *PU_NUM.values(), "BinLocation", "UpdateCode", "SourceFileName", "SourceFileBranch",
                  "SourceFileDate", "SourceLineNumber", "BranchMismatchFlag", "IsMalformedRow",
                  "HasTypeConversionIssue", "LoadedAtUtc")
    write_files(pu, PU_TARGET, todo)
    print(f"Silver_PriceUpdate_History: wrote {len(todo):,} file(s)")
```

```python
# ---------- JD National Change Report ----------
lines = spark.read.table("Landing_JDChangeReport_Lines")
headers, data = split_header(lines)

hdr = headers.select("SourceFileName",
                     F.expr("transform(split(LineText, ','), x -> upper(trim(x)))").alias("h"))
unknown = [r.SourceFileName for r in hdr.filter(F.col("h") != F.array(*[F.lit(c) for c in CR_HEADER])).collect()]
if unknown:
    raise ValueError(f"Change Report file(s) with an unknown header: {unknown}")

cr_re = r"(?i)^US\.UPDCOMP\.UPDATE\.V2-(\d{4})-(\d{2})-(\d{2})\.CSV$"
data = data.withColumn("SourceFileDate", F.expr(
    f"make_date(int(regexp_extract(SourceFileName, '{cr_re}', 1)), "
    f"int(regexp_extract(SourceFileName, '{cr_re}', 2)), int(regexp_extract(SourceFileName, '{cr_re}', 3)))"))
bad_names = [r.SourceFileName for r in data.filter("SourceFileDate IS NULL").select("SourceFileName").distinct().collect()]
if bad_names:
    print(f"WARNING: skipping {len(bad_names)} Change Report file(s) with an unexpected name: {bad_names}")
data = data.filter("SourceFileDate IS NOT NULL")

todo = files_to_load(data, CR_TARGET)
print(f"Change Report files in landing: {data.select('SourceFileName').distinct().count():,}; to (re)load: {len(todo):,}")

if todo:
    d = (data.filter(F.col("SourceFileName").isin(todo))
         .withColumn("f", F.split("LineText", ",", -1))
         .withColumn("IsMalformedRow", F.size("f") != len(CR_HEADER)))
    d = d.select("SourceFileName", "SourceFileDate", "IsMalformedRow",
                 F.col("LineNumber").alias("SourceLineNumber"),
                 *[F.when(~F.col("IsMalformedRow") | F.lit(i == 0), F.get(F.col("f"), i)).alias(f"raw{i}")
                   for i in range(len(CR_HEADER))])
    d = d.withColumn("PartNumber", blank_to_null(F.col("raw0")))
    for i, name in enumerate(CR_HEADER[1:5], start=1):
        d = d.withColumn(CR_NUM[name], to_num(f"raw{i}"))
    d = d.withColumn("EffectiveDate", to_date("raw5"))
    issue = bad_parse("raw5", "EffectiveDate")
    for i, name in enumerate(CR_HEADER[1:5], start=1):
        issue = issue | bad_parse(f"raw{i}", CR_NUM[name])
    cr = (d.withColumn("HasTypeConversionIssue", issue)
           .withColumn("FileNameDateMismatchFlag",
                       F.coalesce(F.col("EffectiveDate") != F.col("SourceFileDate"), F.lit(False)))
           .withColumn("LoadedAtUtc", F.current_timestamp())
           .select("PartNumber", "EffectiveDate", "CurrentDNP", "CurrentSLP", "NewDNP", "NewSLP",
                   "SourceFileName", "SourceFileDate", "SourceLineNumber", "FileNameDateMismatchFlag",
                   "IsMalformedRow", "HasTypeConversionIssue", "LoadedAtUtc"))
    write_files(cr, CR_TARGET, todo)
    print(f"Silver_JDChangeReport_History: wrote {len(todo):,} file(s)")
```

```python
for t in (PU_TARGET, CR_TARGET):
    s = spark.read.format("delta").load(t)
    dup = s.groupBy("SourceFileName", "SourceLineNumber").count().filter("count > 1").count()
    assert dup == 0, f"{t}: {dup} file lines appear more than once"
    print(t, s.agg(F.count("*").alias("rows"), F.countDistinct("SourceFileName").alias("files"),
                   F.max("SourceFileDate").alias("newest"), F.sum(F.col("IsMalformedRow").cast("int")).alias("malformed"),
                   F.sum(F.col("HasTypeConversionIssue").cast("int")).alias("conv_issues")).collect()[0])
```

- [ ] **Step 3: Add the DAG items.** In `deploy/dp_refresh_dag.json` `items`, add:

```json
    {
      "name": "df_JDPriceFiles_Raw",
      "type": "dataflow",
      "workspace": "staging",
      "tier": "staging",
      "cadence": "daily",
      "dependsOn": [],
      "produces": ["Landing_PriceUpdate_Lines", "Landing_JDChangeReport_Lines"]
    },
    {
      "name": "Build_Silver_JDPriceFiles",
      "type": "notebook",
      "workspace": "staging",
      "tier": "silver",
      "cadence": "daily",
      "dependsOn": ["df_JDPriceFiles_Raw"],
      "produces": ["Silver_PriceUpdate_History", "Silver_JDChangeReport_History"]
    },
```

- [ ] **Step 4: Check the DAG and run the tests.**
  - Run: `python deploy/dag_check.py && python -m pytest deploy -q`
  - Expected: no errors. If `dag_check` reports the landing tables as unknown reads, follow its message; it lists what it accepts as sources.

- [ ] **Step 5: Commit, push, git sync Dev, run the notebook.**
  ```
  git add "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_JDPriceFiles.Notebook" deploy/dp_refresh_dag.json
  git commit -m "Build_Silver_JDPriceFiles: parse JD price feeds, load each file once"
  git push origin dev
  python C:\Users\bfox\Documents\Git-Projects\data-projects\tools\dp-migration\git_sync.py ab15d64d-c7ba-415d-9bcf-7feb1ef9b201
  ```
  - Then run the notebook on its own: `python deploy/run_and_verify_notebooks.py` with the workspace and notebook name (see its `--help`).
  - Expected: the backfill writes 4,792+ price files and 13 Change Report files, and the final cell prints no assertion error.

- [ ] **Step 6: Check Silver against LH_Master_Data (Claude, DuckDB, read-only).**
  - [ ] **Price rows:** Silver `count(*)` for files present in both = LH `count(*)` − 6,003 duplicates. Match on `SourceFileName`; LH has 4,774 files, Silver may have more.
  - [ ] **Change Report rows:** Silver = LH distinct rows (LH 56,728 − 4,652 duplicates) + the 8/31 file's rows.
  - [ ] **Values:** for 1,000 random (file, part, branch) rows, the prices and EffectiveDate match LH to 6 decimals. Report any differences by column. The expected differences are rows LH mis-mapped, which are now `IsMalformedRow`.
  - [ ] **Malformed rows:** ≥ 95% of `IsMalformedRow` rows have a PartNumber that exists in DP `dim_Parts`. If not, the shift starts earlier than field 3: stop and report.
  - [ ] **Idempotency:** run the notebook a second time. It must print "to (re)load: 0" for both feeds, and the row counts must not change.

- [ ] **Step 7:** Brian does Task 3 Step 6 onward (LookbackDays → 35, commit). Then git sync Dev again so the repo and workspace agree: `git pull` in F first, then `git_sync.py`.

---

### Task 5: Silver shortcuts into DP_Presentation (Dev)

- [ ] **Step 1: Add the shortcuts.** In F `workspaces/DP - Presentation - Dev/DP_Presentation.Lakehouse/shortcuts.metadata.json`, append two entries shaped like `Silver_WkVehFl`'s, for `Silver_PriceUpdate_History` and `Silver_JDChangeReport_History`:
  - `path` `/Tables`;
  - `oneLake.path` `Tables/<name>`;
  - `itemId` `876255e0-d462-4697-adc1-4a655f5bb101`;
  - `workspaceId` `ab15d64d-c7ba-415d-9bcf-7feb1ef9b201`.
- [ ] **Step 2: Commit, push, git sync.**
  - Commit (`Presentation Dev: shortcuts to JD price Silver tables`), push, then `git_sync.py 73fd5443-240e-410a-990a-98827f32c087`.
- [ ] **Step 3: Verify.** `fab ls "DP - Presentation - Dev.Workspace/DP_Presentation.Lakehouse/Tables"` lists both shortcuts.

---

### Task 6: Gold notebook

**Files:** F `workspaces/DP - Presentation - Dev/Fact Tables/JD Price Updates/Build_Gold_JDPriceChanges.Notebook/` (`.platform` copied from `Build_Gold_PartsPromo` with a new name and logicalId; METADATA header with default lakehouse DP_Presentation `966efc8a-…` in workspace `73fd5443-…`); `deploy/dp_refresh_dag.json`.

- [ ] **Step 1: Check the branch join first (Claude, DuckDB).**
  - Run `SELECT BranchID, Branch, BranchType FROM dim_BranchLocation ORDER BY BranchKey` on DP_Presentation Dev.
  - Confirm that main branches have `BranchID` equal to the bare number as text (e.g. `'96'`). If they don't, adjust `branch_lookup` below to the real rule and note it in the notebook comment.

- [ ] **Step 2: Write `notebook-content.py`.**

```python
# Build_Gold_JDPriceChanges
# Purpose: Report-ready JD price history (spec 2026-10-08).
#   Fact_PartPriceChange        PartNumber + EffectiveDate (company-wide)
#   Fact_PartPriceChange_Branch Branch + PartNumber + EffectiveDate
#   Fact_JDNationalPriceChange  PartNumber + EffectiveDate (JD national Change Report)
# Survivor rules (decided 2026-10-08, see spec):
# - Same branch/part/effective date in several files: latest SourceFileDate,
#   then highest SourceFileName, then lowest SourceLineNumber.
# - Company-wide: each price = most common value across branches, ties ->
#   lowest (same rule as dim_Parts). HasBranchPriceDisagreement marks the
#   ~0.15% of changes where JD's prices differ by branch.
# - Null EffectiveDate -> SourceFileDate, EffectiveDateFromFile = true.
# - Change Report: same part/effective date in several files -> latest file.
# Keys: PartNumberKey = xxhash64(PartNumber) (matches dim_Parts);
# BranchKey looked up from dim_BranchLocation.BranchID. All dates are DATE.

spark.conf.set("spark.sql.parquet.datetimeRebaseModeInRead", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInWrite", "CORRECTED")
from pyspark.sql import functions as F
from pyspark.sql import Window

PRICE_COLS = ["ManufacturerListPrice", "ManufacturerReplacePrice", "ManufacturerSellPrice1",
              "DealerListPrice", "DealerReplacePrice", "DealerSellPrice1", "SellPriceOld"]
```

```python
pu = (spark.read.table("Silver_PriceUpdate_History")
      .filter(~F.col("IsMalformedRow") & F.col("PartNumber").isNotNull() & F.col("Branch").isNotNull())
      .withColumn("EffectiveDateFromFile", F.col("EffectiveDate").isNull())
      .withColumn("EffectiveDate", F.coalesce("EffectiveDate", "SourceFileDate")))

w = Window.partitionBy("Branch", "PartNumber", "EffectiveDate").orderBy(
    F.col("SourceFileDate").desc(), F.col("SourceFileName").desc(), F.col("SourceLineNumber").asc())
branch_rows = pu.withColumn("rn", F.row_number().over(w)).filter("rn = 1").drop("rn")

branch_lookup = (spark.read.table("dim_BranchLocation")
                 .select(F.col("BranchID"), F.col("BranchKey"))
                 .filter(F.col("BranchID").rlike("^[0-9]+$"))
                 .select(F.col("BranchID").cast("int").alias("Branch"), "BranchKey"))
assert branch_lookup.groupBy("Branch").count().filter("count > 1").count() == 0, "BranchID not unique per branch"

fact_branch = (branch_rows.join(branch_lookup, "Branch", "left")
               .withColumn("PartNumberKey", F.xxhash64("PartNumber"))
               .withColumn("InventoryCostImpact", F.round(F.col("OnHandQty") * F.col("CostDiff"), 2))
               .select("BranchKey", "Branch", "PartNumberKey", "PartNumber", "EffectiveDate",
                       "EffectiveDateFromFile", *PRICE_COLS, "CostDiff", "ListDiff", "SellPrice1Diff",
                       "OnHandQty", "InventoryCostImpact", "BinLocation", "UpdateCode",
                       "HasTypeConversionIssue", "SourceFileName", "SourceFileDate"))
```

```python
def most_common(col):
    """Most common non-null value of col per PartNumber + EffectiveDate; ties -> lowest value."""
    counts = (branch_rows.filter(F.col(col).isNotNull())
              .groupBy("PartNumber", "EffectiveDate", col).count())
    wc = Window.partitionBy("PartNumber", "EffectiveDate").orderBy(F.col("count").desc(), F.col(col).asc())
    return counts.withColumn("rn", F.row_number().over(wc)).filter("rn = 1").select("PartNumber", "EffectiveDate", col)


base = (branch_rows.groupBy("PartNumber", "EffectiveDate").agg(
    F.countDistinct("Branch").alias("BranchCount"),
    F.max("EffectiveDateFromFile").alias("EffectiveDateFromFile"),
    F.max("HasTypeConversionIssue").alias("HasTypeConversionIssue"),
    (F.countDistinct("ManufacturerListPrice", "ManufacturerReplacePrice", "ManufacturerSellPrice1") > 1)
        .alias("HasBranchPriceDisagreement"),
    F.min("Franchise").alias("Franchise"),
    F.max("SourceFileDate").alias("LatestSourceFileDate")))
for c in PRICE_COLS:
    base = base.join(most_common(c), ["PartNumber", "EffectiveDate"], "left")

wp = Window.partitionBy("PartNumber").orderBy("EffectiveDate")
fact_part = (base
    .withColumn("PartNumberKey", F.xxhash64("PartNumber"))
    .withColumn("JDListChange", F.round(F.col("ManufacturerListPrice") - F.col("DealerListPrice"), 2))
    .withColumn("JDListChangePct", F.when(F.col("DealerListPrice") != 0,
                F.round((F.col("ManufacturerListPrice") - F.col("DealerListPrice")) / F.col("DealerListPrice"), 6)))
    .withColumn("JDCostChange", F.round(F.col("ManufacturerReplacePrice") - F.col("DealerReplacePrice"), 2))
    .withColumn("JDCostChangePct", F.when(F.col("DealerReplacePrice") != 0,
                F.round((F.col("ManufacturerReplacePrice") - F.col("DealerReplacePrice")) / F.col("DealerReplacePrice"), 6)))
    .withColumn("ChangeDirection", F.when(F.col("JDListChange") > 0, "Increase")
                .when(F.col("JDListChange") < 0, "Decrease").otherwise("NoChange"))
    .withColumn("PriorEffectiveDate", F.lag("EffectiveDate").over(wp))
    .withColumn("DaysSincePriorChange", F.datediff("EffectiveDate", "PriorEffectiveDate"))
    .withColumn("PriorJDListPrice", F.lag("ManufacturerListPrice").over(wp))
    .withColumn("PriorJDCostPrice", F.lag("ManufacturerReplacePrice").over(wp)))
```

```python
cr = (spark.read.table("Silver_JDChangeReport_History")
      .filter(~F.col("IsMalformedRow") & F.col("PartNumber").isNotNull())
      .withColumn("EffectiveDate", F.coalesce("EffectiveDate", "SourceFileDate")))
wc = Window.partitionBy("PartNumber", "EffectiveDate").orderBy(
    F.col("SourceFileDate").desc(), F.col("SourceFileName").desc(), F.col("SourceLineNumber").asc())
stocked = spark.read.table("dim_Parts").select("PartNumber").distinct().withColumn("IsStockedPart", F.lit(True))
fact_national = (cr.withColumn("rn", F.row_number().over(wc)).filter("rn = 1").drop("rn")
    .join(stocked, "PartNumber", "left")
    .withColumn("IsStockedPart", F.coalesce("IsStockedPart", F.lit(False)))
    .withColumn("PartNumberKey", F.xxhash64("PartNumber"))
    .withColumn("DNPChange", F.round(F.col("NewDNP") - F.col("CurrentDNP"), 2))
    .withColumn("DNPChangePct", F.when(F.col("CurrentDNP") != 0, F.round((F.col("NewDNP") - F.col("CurrentDNP")) / F.col("CurrentDNP"), 6)))
    .withColumn("SLPChange", F.round(F.col("NewSLP") - F.col("CurrentSLP"), 2))
    .withColumn("SLPChangePct", F.when(F.col("CurrentSLP") != 0, F.round((F.col("NewSLP") - F.col("CurrentSLP")) / F.col("CurrentSLP"), 6)))
    .select("PartNumberKey", "PartNumber", "EffectiveDate", "CurrentDNP", "NewDNP", "DNPChange", "DNPChangePct",
            "CurrentSLP", "NewSLP", "SLPChange", "SLPChangePct", "IsStockedPart", "FileNameDateMismatchFlag",
            "HasTypeConversionIssue", "SourceFileName", "SourceFileDate"))
```

```python
for name, df, key in [("Fact_PartPriceChange", fact_part, ["PartNumber", "EffectiveDate"]),
                      ("Fact_PartPriceChange_Branch", fact_branch, ["Branch", "PartNumber", "EffectiveDate"]),
                      ("Fact_JDNationalPriceChange", fact_national, ["PartNumber", "EffectiveDate"])]:
    df.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save(f"Tables/{name}")
    spark.sql(f"VACUUM delta.`Tables/{name}` RETAIN 0 HOURS")
    t = spark.read.format("delta").load(f"Tables/{name}")
    dup = t.groupBy(*key).count().filter("count > 1").count()
    assert dup == 0, f"{name}: {dup} duplicate {key}"
    print(f"{name}: {t.count():,} rows")
print("Branch rows with no BranchKey:", fact_branch.filter("BranchKey IS NULL").count())
```

  - `VACUUM` plus a path-based `save` follows the existing Gold pattern; see the memory on orphaned files.
  - `spark.databricks.delta.retentionDurationCheck.enabled` is already handled the way the other Gold notebooks handle it. Copy that line from `Build_Gold_PartsPromo` if it sets one.

- [ ] **Step 3: Add the DAG item.**

```json
    {
      "name": "Build_Gold_JDPriceChanges",
      "type": "notebook",
      "workspace": "presentation",
      "tier": "gold",
      "cadence": "daily",
      "dependsOn": ["Build_Silver_JDPriceFiles", "Build_Gold_Parts", "Build_Gold_BranchLocation"],
      "produces": ["Fact_PartPriceChange", "Fact_PartPriceChange_Branch", "Fact_JDNationalPriceChange"]
    },
```

- [ ] **Step 4: Check the DAG and run the tests.** `python deploy/dag_check.py && python -m pytest deploy -q`

- [ ] **Step 5: Commit, push, git sync, run.**
  - Commit (`Build_Gold_JDPriceChanges: three JD price facts`), push, then `git_sync.py 73fd5443-240e-410a-990a-98827f32c087`.
  - Run the notebook on its own.

- [ ] **Step 6: Verify (Claude, DuckDB).**
  - [ ] **Row counts:** `Fact_PartPriceChange` ≈ 1.29M; `Fact_PartPriceChange_Branch` ≈ 5.09M; `Fact_JDNationalPriceChange` ≈ distinct part/date in the Change Report Silver table.
  - [ ] **Disagreements:** `HasBranchPriceDisagreement` count ≈ 1,961.
  - [ ] **Spot check:** for 5 parts, hand-check one change against a share file. JD list, our list, `JDListChange` and the prior effective date all agree.
  - [ ] **Determinism:** run the notebook twice; `python deploy/compare_tiers.py` isn't usable for Dev against Dev, so instead compare a `hash_agg` of each table across the two runs. They must be equal.
  - [ ] **Branch keys:** branch rows with no `BranchKey` are only branches missing from `dim_BranchLocation`. List them for Brian.

---

### Task 7: Freshness config + full Dev pipeline run

- [ ] **Step 1: Add the checks.** In `deploy/dp_refresh_dag.json` `orchestrator`, add:

```json
    "freshnessChecks": [
      {"table": "Silver_PriceUpdate_History", "column": "SourceFileDate", "maxAgeDays": 8,
       "label": "JD branch price update files (share: Daily_Reports\\Price_Update)"},
      {"table": "Silver_JDChangeReport_History", "column": "SourceFileDate", "maxAgeDays": 10,
       "label": "JD National Change Report (share: Daily_Reports\\JD_Change_Report)"}
    ],
```

- [ ] **Step 2: Commit and push.** Run `python deploy/dag_check.py && python -m pytest deploy -q`, then commit (`DP config: freshness checks for JD price feeds`) and push.
  - The CI run on `dev` writes the config to `Files/config/dp_refresh_dag.json`.
  - Git sync both Dev workspaces (the orchestrator notebooks changed in Task 1).
- [ ] **Step 3: Prove the warning fires.**
  - Temporarily set the price check's `maxAgeDays` to `1` in a **local copy only**, and upload that config to Dev with the same mechanism CI uses (`deploy/deploy_backend.py write_dag_config`, see its `--help`).
  - Run Pipeline_DP_Refresh in Dev with `mode = items` and items `Build_Silver_JDPriceFiles`. The summary email must list the warning under **Warnings** and still say OK.
  - Then re-upload the committed config.
- [ ] **Step 4 (Brian): run the full Dev pipeline.**
  - Run it (`mode = all`), or wait for the scheduled run.
  - Expected: green, with the 3 new items Succeeded and no freshness warning.

---

### Task 8: Repoint the local report (Desktop CLOSED)

**Files:** D `projects/jd-price-updates/reports/JD Price Updates.SemanticModel/definition/` (tables, relationships, `_Measures.tmdl`).

- [ ] **Step 1 (Brian): close the report.** Confirm Power BI Desktop is closed for this report (memory: an open Desktop overwrites file edits).
- [ ] **Step 2: Inventory what the report uses.**
  - Run `pbir fields list "projects/jd-price-updates/reports/JD Price Updates.Report"`.
  - Grep `_Measures.tmdl` for every column of `Raw_PriceUpdate_History` / `Raw_JDNationalChangeReport_History` it uses, and check bookmarks (memory: the bookmark blind spot).
  - Write a column map, old → new table and column, as a comment block at the top of a scratch note.
  - Show Brian any measure that recomputes something Gold now provides (prior price, disagreement flag).
- [ ] **Step 3: Replace the tables.**
  - Swap the two raw tables for `Fact_PartPriceChange`, `Fact_PartPriceChange_Branch` and `Fact_JDNationalPriceChange`.
  - Point `dim_Parts`, `dim_DateTable` and `dim_BranchLocation` at the DP_Presentation Dev SQL endpoint, copying the `Sql.Database(...)` host and database from an RP-Dev report already on DP. Every TMDL file is UTF-8 without BOM, with no `//` comment lines.
  - **Relationships:**
    - `Fact_*[PartNumberKey]` → `dim_Parts[PartNumberKey]`;
    - `Fact_*[EffectiveDate]` → `dim_DateTable[Date]`;
    - `Fact_PartPriceChange_Branch[BranchKey]` → `dim_BranchLocation[BranchKey]`. This fixes today's auto-detected `Branch → BranchKey` relationship, which joins a branch number to a surrogate key and is wrong.
- [ ] **Step 4: Update the measures** using the column map from Step 2.
- [ ] **Step 5 (Brian): check in Desktop.**
  - Open it, refresh, and close and reopen if tables are missing (memory: new tables need a reopen).
  - Look over each page.
- [ ] **Step 6: Commit in D** (`JD Price Updates: report on DP Gold price facts`).

---

### Task 9: Prod rollout

- [ ] **Step 1: Parameterise the Prod dataflow.**
  - Check `parameter.yml` handles `df_JDPriceFiles_Raw`'s destination lakehouse/workspace IDs the same way it handles `df_ServiceTimeSheets_Raw`'s (Dev Staging IDs → Prod Staging IDs). Add rules if not, with `deploy/params.py append_rules` and a test in `test_params.py`.
  - The gateway connection ID is the same in both tiers.
- [ ] **Step 2: Release.** `python deploy/merge_preview.py`, then open a PR `dev → main` (template `.github/PULL_REQUEST_TEMPLATE/dev_to_main.md`). **Brian merges with "Create a merge commit".**
- [ ] **Step 3 (Brian): deploy.** Actions → **Deploy DP backend** → Run workflow from `main`.
- [ ] **Step 4: Post-deploy steps.**
  - `python deploy/claim_prod_pipeline.py`.
  - Fast-forward `dev`: `git fetch origin && git merge --ff-only origin/main && git push origin dev`.
- [ ] **Step 5 (Brian): open the Prod dataflow.**
  - Open `df_JDPriceFiles_Raw` in DP - Staging - Prod, confirm the connection is `Network_Folder_DailyReports` and both destinations point at **Prod** DP_Staging, then Save.
  - Don't run it yet.
- [ ] **Step 6: Copy history to Prod.**
  - Create `deploy/oneoff/Utilities_CopyJDPriceSilverToProd_20261008.Notebook`, modelled on `Utilities_CopySnapshotHistoryToProd_20261002`. It reads both Silver tables from Dev Staging by abfss path and writes them to Prod Staging `Tables/<same name>` (overwrite), then asserts the row counts are equal.
  - Run it: `python deploy/run_oneoff_notebook.py <Prod Staging workspaceId> deploy/oneoff/Utilities_CopyJDPriceSilverToProd_20261008.Notebook`.
- [ ] **Step 7: Shortcuts.** `python deploy/sync_shortcuts.py`, then `--apply`. The targets now exist.
- [ ] **Step 8: Run in Prod.**
  - Run Prod Pipeline_DP_Refresh with `mode = items`, items `df_JDPriceFiles_Raw, Build_Silver_JDPriceFiles, Build_Gold_JDPriceChanges`.
  - Expected: Silver prints "to (re)load: 0" or a handful of new files.
- [ ] **Step 9: Compare.** `python deploy/compare_tiers.py Fact_PartPriceChange Fact_PartPriceChange_Branch Fact_JDNationalPriceChange`. Expected: identical, or only files that arrived between the two runs.
- [ ] **Step 10: Commit** the one-off notebook in F `dev` (`One-off: copy JD price Silver history to Prod`).

---

### Task 10: Retire the old path and update the docs

- [ ] **Step 1 (Brian, Fabric UI): turn off the old schedule.** In LH_Master_Data, `pl_Raw_PriceUpdate_History` → Schedule → **Off**. The items themselves stay.
- [ ] **Step 2: Disable the PC harvest task.** `Disable-ScheduledTask -TaskPath "\Fabric\" -TaskName "JD Price Update Harvest"`. Disable it, don't unregister it.
- [ ] **Step 3: Update the reminder text.**
  - In D `projects/jd-price-updates/scripts/Send-JDChangeReportReminder.ps1`, change the instructions to: save the downloaded file **unchanged** into `\\Eqsvc01-sp2010\equip\UWS\Poll\Daily_Reports\JD_Change_Report`, and that the daily DP refresh loads it.
  - Test it with the exact Task Scheduler invocation: `powershell.exe -File "<full path>"`.
- [ ] **Step 4: Update the docs.**
  - Rewrite D `projects/jd-price-updates/README.md` with the new architecture: share → gateway dataflow → Silver → Gold. Keep "Known data realities", and move the old-pipeline gotchas under a "History (LH_Master_Data, retired 2026-10)" heading.
  - Add the new tables to `FACT-TABLES-SUMMARY.md`.
  - Add a "JD price files" line to F `OPERATIONS-GUIDE.md` → "DP Backend": share folders, where to save the Change Report, and the freshness warning.
- [ ] **Step 5: Update memory.**
  - Update `project_jd_price_updates_dax_report_build.md`: now on DP, the report is local, the gateway design, and the stale relationship bug fixed.
  - Add a pointer in MEMORY.md.
- [ ] **Step 6: Commit both repos** (named files only). Remind Brian:
  - the LH price items and tables are deleted only with his explicit OK, as part of retiring LH_Master_Data;
  - the next step is asking Ben which margin-impact questions he wants answered.
