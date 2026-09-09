# Foundational Dimensions (dim_DateTable, dim_BranchLocation) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `dim_DateTable` and `dim_BranchLocation` in the new JD Bronze data platform (`DP - Presentation - Dev`) — the first foundational, shared dimensions in the new backend, built per Brian's explicit direction to pause report migration, build shared foundation first, and improve on the existing design where a real improvement presents itself rather than porting blindly.

**Architecture:** `dim_DateTable` is a pure-generation Spark notebook with no bronze/silver layer at all (same as production — zero source dependency) — rebuilt **slim**, dropping ~48 of production's 76 columns that are all computed off `DateTime.LocalNow()` baked into static refresh-time columns (the same UTC-not-local bug class already found and fixed twice this session). `dim_BranchLocation` sources from an EquipRDB **view** (`BranchOperational`) that isn't in JD's Bronze mirror (views aren't replicated the way base tables are) — needs its own small Dataflow Gen2 ingestion into `DP_Staging`'s bronze area, same mechanism already proven in production, then a Spark gold notebook ported faithfully from the existing enrichment logic (no bug found there, no redesign needed).

**Tech Stack:** Fabric Dataflow Gen2 (portal-created, for the one ODBC-sourced bronze table), PySpark (both gold notebooks), DuckDB for independent verification.

---

### Task 1: Build `Build_Gold_DateTable.Notebook`

**Files:**
- Create: `workspaces/DP - Presentation - Dev/Build_Gold_DateTable.Notebook/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Presentation - Dev/Build_Gold_DateTable.Notebook/notebook-content.py`

- [ ] **Step 1: Generate a logical ID**

```bash
python -c "import uuid; print(uuid.uuid4())"
```
Use the output as `<LOGICAL_ID>` below.

- [ ] **Step 2: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Gold_DateTable"
  },
  "config": {
    "version": "2.0",
    "logicalId": "<LOGICAL_ID>"
  }
}
```

- [ ] **Step 3: Create the notebook content**

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

# Build_Gold_DateTable
# Purpose: Pure-generation calendar dimension - no source dependency at all,
# same as production's dim_DateTable (df_Dim_Date.Dataflow in LH_Master_Data).
#
# DELIBERATELY SLIM, 2026-09-09 - a real redesign, not a like-for-like port.
# Production's dim_DateTable has 76 columns. About 48 of them (every
# IsCurrentYear/IsCurrentMonth/IsPrevious*/IsYearToDate/IsQuarterToDate/
# IsMonthToDate/every IsRolling*/IsLast*Days/IsNext30Days/IsSameMonthLastYear/
# IsSameQuarterLastYear/RollingPeriodCategory/DaysFromToday/YearOffset column)
# are computed off DateTime.LocalNow() and baked in as STATIC columns at
# REFRESH TIME - the exact same UTC-not-actual-local-time bug already found
# and fixed twice this session (Fact_PartsAdjustments.LoadedDatetime, and the
# documented 2026-02-27 Data Refresh Table fix). Since this table is used by
# "ALL fact tables requiring time intelligence... ALL reports requiring date
# filtering" per its own production header comment, this bug has been live
# and silently wrong for hours around midnight, in every one of those flags,
# the whole time.
#
# Beyond the bug: baking "is this the current month" into a column that only
# updates on refresh is a modeling anti-pattern regardless of the UTC issue -
# these belong in DAX measures or a calculation group, evaluated dynamically
# against TODAY() at QUERY time in each report, not frozen at whatever moment
# the pipeline last ran. Brian agreed: drop every "today"-relative column
# from this table entirely. That logic becomes report-layer DAX work when
# each report actually migrates onto this backend - explicitly NOT part of
# this table, and NOT part of this plan (no report is being touched here).
#
# What's KEPT: every column that is a genuine calendar attribute of the date
# itself and never depends on "today" - the date hierarchy, display names,
# business calendar (season/fiscal), sort helpers, weekday/business-day
# flags, and working-day counts (all computed from the date's own
# month/quarter/year boundaries, not from "today"). Same 2020-01-01 to
# 2030-12-31 range as production - no reason to change it here.

print("=" * 80)
print("BUILD_GOLD_DATETABLE")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

START_DATE = "2020-01-01"
END_DATE = "2030-12-31"

# Base date spine - one row per day in the fixed range.
dates_df = spark.sql(f"SELECT explode(sequence(to_date('{START_DATE}'), to_date('{END_DATE}'), interval 1 day)) AS Date")

row_count = dates_df.count()
print(f"Date spine generated ({START_DATE} to {END_DATE}): {row_count:,} days")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Date hierarchy, display names, and business calendar - all pure functions
# of the date itself, matching production's exact formats/rules.

MONTH_NAMES = ["January", "February", "March", "April", "May", "June", "July",
               "August", "September", "October", "November", "December"]
MONTH_NAMES_SHORT = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul",
                      "Aug", "Sep", "Oct", "Nov", "Dec"]
DOW_NAMES = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
DOW_NAMES_SHORT = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

enriched = (
    dates_df
    .withColumn("DateKey", F.date_format(F.col("Date"), "yyyyMMdd").cast("bigint"))
    .withColumn("Year", F.year("Date").cast("bigint"))
    .withColumn("Quarter", F.quarter("Date").cast("bigint"))
    .withColumn("Month", F.month("Date").cast("bigint"))
    .withColumn("Day", F.dayofmonth("Date").cast("bigint"))
    .withColumn("WeekOfYear", F.weekofyear("Date").cast("bigint"))
    # Spark dayofweek(): 1=Sunday..7=Saturday - matches production's convention exactly.
    .withColumn("DayOfWeek", F.dayofweek("Date").cast("bigint"))
    .withColumn("MonthName", F.element_at(F.array(*[F.lit(m) for m in MONTH_NAMES]), F.month("Date")))
    .withColumn("MonthNameShort", F.element_at(F.array(*[F.lit(m) for m in MONTH_NAMES_SHORT]), F.month("Date")))
    .withColumn("DayOfWeekName", F.element_at(F.array(*[F.lit(d) for d in DOW_NAMES]), F.dayofweek("Date")))
    .withColumn("DayOfWeekNameShort", F.element_at(F.array(*[F.lit(d) for d in DOW_NAMES_SHORT]), F.dayofweek("Date")))
    .withColumn("MonthYear", F.date_format(F.col("Date"), "MMM yyyy"))
    .withColumn("QuarterYear", F.concat(F.lit("Q"), F.quarter("Date"), F.lit(" "), F.year("Date")))
    .withColumn("DateDisplayName", F.date_format(F.col("Date"), "dd/MM/yyyy"))
    .withColumn(
        "Season",
        F.when(F.month("Date").between(3, 5), "Spring")
        .when(F.month("Date").between(6, 8), "Summer")
        .when(F.month("Date").between(9, 11), "Fall")
        .otherwise("Winter"),
    )
    .withColumn("IsPeakSeason", F.col("Season").isin("Spring", "Summer", "Fall"))
    # Fiscal year/quarter = calendar year/quarter (same assumption as production).
    .withColumn("FiscalYear", F.year("Date").cast("bigint"))
    .withColumn("FiscalQuarter", F.quarter("Date").cast("bigint"))
    .withColumn("MonthSort", (F.year("Date") * 100 + F.month("Date")).cast("double"))
    .withColumn("QuarterSort", (F.year("Date") * 10 + F.quarter("Date")).cast("double"))
    .withColumn("SortableMonthYear", F.concat(
        F.year("Date"), F.lit("-"), F.lpad(F.month("Date"), 2, "0"), F.lit(" "),
        F.element_at(F.array(*[F.lit(m) for m in MONTH_NAMES_SHORT]), F.month("Date")),
    ))
    # DayOfWeek 1=Sunday, 7=Saturday - weekend is Sunday or Saturday.
    .withColumn("IsWeekend", (F.col("DayOfWeek") == 1) | (F.col("DayOfWeek") == 7))
    .withColumn("IsWeekday", ~F.col("IsWeekend"))
    .withColumn("IsBusinessDay", F.col("IsWeekday"))
)

print(f"Date hierarchy, display names, and business calendar added.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Working-day counts - computed from each date's OWN month/quarter/year
# boundaries, not from "today", so these are legitimate calendar attributes
# (unlike the dropped rolling/current-period flags). Self-joins against the
# same date spine's IsWeekday flag to count working days in each period.

weekday_lookup = enriched.select("Date", "Year", "Month", "Quarter", "IsWeekday")

working_days_month = (
    weekday_lookup.filter(F.col("IsWeekday"))
    .groupBy("Year", "Month")
    .agg(F.count("*").alias("WorkingDaysInMonth"))
)
working_days_quarter = (
    weekday_lookup.filter(F.col("IsWeekday"))
    .groupBy("Year", "Quarter")
    .agg(F.count("*").alias("WorkingDaysInQuarter"))
)
working_days_year = (
    weekday_lookup.filter(F.col("IsWeekday"))
    .groupBy("Year")
    .agg(F.count("*").alias("WorkingDaysInYear"))
)

with_working_days = (
    enriched
    .join(working_days_month, on=["Year", "Month"], how="left")
    .join(working_days_quarter, on=["Year", "Quarter"], how="left")
    .join(working_days_year, on=["Year"], how="left")
    .withColumn("WorkingDaysInMonth", F.col("WorkingDaysInMonth").cast("bigint"))
    .withColumn("WorkingDaysInQuarter", F.col("WorkingDaysInQuarter").cast("bigint"))
    .withColumn("WorkingDaysInYear", F.col("WorkingDaysInYear").cast("bigint"))
)

print("Working-day counts (month/quarter/year) added.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Final column selection - deliberately excludes every "today"-relative
# column from production (see header comment). This is the entire list of
# columns this table has; anything not named here is intentionally dropped.

dim_date_table = with_working_days.select(
    "DateKey", "Date",
    "Year", "Quarter", "Month", "Day", "WeekOfYear", "DayOfWeek",
    "MonthName", "MonthNameShort", "DayOfWeekName", "DayOfWeekNameShort",
    "MonthYear", "SortableMonthYear", "QuarterYear", "DateDisplayName",
    "Season", "IsPeakSeason", "FiscalYear", "FiscalQuarter",
    "MonthSort", "QuarterSort",
    "IsWeekend", "IsWeekday", "IsBusinessDay",
    "WorkingDaysInMonth", "WorkingDaysInQuarter", "WorkingDaysInYear",
)

final_count = dim_date_table.count()
final_col_count = len(dim_date_table.columns)
print(f"dim_DateTable rows: {final_count:,} (expect 4,018)")
print(f"dim_DateTable columns: {final_col_count} (expect 28 - production had 76)")

dim_date_table.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/dim_DateTable")

print("Gold build complete: dim_DateTable written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Verification - quick in-notebook sanity check, not the final proof (that's
# the independent DuckDB script). Spot-checks a known date and confirms none
# of the dropped "today"-relative columns exist in the output.

sample = spark.sql("""
    SELECT DateKey, Date, Year, Quarter, Month, MonthName, Season, FiscalYear,
           IsWeekend, WorkingDaysInMonth
    FROM delta.`Tables/dim_DateTable`
    WHERE Date = '2025-12-25'
""").toPandas()
print("Spot check - 2025-12-25 (expect Year=2025, Quarter=4, Month=12, Season=Winter, IsWeekend=false - Thursday):")
print(sample.to_string())

dropped_columns = {
    "YearOffset", "IsCurrentYear", "IsCurrentMonth", "IsPreviousYear", "IsPreviousMonth",
    "IsPreviousQuarter", "IsYearToDate", "IsQuarterToDate", "IsMonthToDate",
    "IsRolling6Months", "IsRolling12Months", "IsRolling24Months", "IsRolling36Months",
    "IsRolling48Months", "IsRolling4Quarters", "IsRolling8Quarters", "IsRolling52Weeks",
    "IsRolling365Days", "IsRolling730Days", "IsRolling1095Days", "IsRolling1460Days",
    "IsRolling180Days", "IsRolling545Days", "IsRolling45Days", "IsRolling120Days",
    "IsRolling270Days", "IsRolling450Days", "IsRolling13Weeks", "IsRolling26Weeks",
    "IsRolling104Weeks", "IsRolling156Weeks", "IsLast30Days", "IsLast60Days", "IsLast90Days",
    "IsNext30Days", "IsSameMonthLastYear", "IsSameQuarterLastYear", "RollingPeriodCategory",
    "DaysFromToday",
}
actual_columns = set(dim_date_table.columns)
leaked = dropped_columns & actual_columns
print(f"\nDropped 'today'-relative columns found in output (expect none): {leaked if leaked else 'none - clean'}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 4: Commit and push**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git status --short
```
Expect exactly 2 new untracked files under `workspaces/DP - Presentation - Dev/Build_Gold_DateTable.Notebook/`. If anything else shows, STOP and report rather than committing.

```bash
git add "workspaces/DP - Presentation - Dev/Build_Gold_DateTable.Notebook"
git commit -m "Add Build_Gold_DateTable notebook - slim calendar dimension

Pure-generation, no source dependency, same as production. Deliberately
drops ~48 of production's 76 columns - all computed off
DateTime.LocalNow() baked into static refresh-time columns, the same
UTC-not-actual-local-time bug already fixed twice this session. That
class of logic (current/previous/rolling/relative-date flags) belongs
in report-layer DAX measures evaluated at query time, not frozen at
refresh time - deferred to when each report actually migrates, not
part of this table. Kept: genuine calendar attributes that never
depend on today (date hierarchy, display names, season/fiscal,
weekday/business-day flags, working-day counts).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git fetch origin dev
git log --oneline HEAD..origin/dev
```
If the last command shows commits, report NEEDS_CONTEXT rather than pushing. Otherwise:
```bash
git push origin dev
```

- [ ] **Step 5: Brian confirms Dev picked up the notebook and runs it**

`DP - Presentation - Dev` → Source control → **Update all**. Open `Build_Gold_DateTable.Notebook` and run all cells.

- [ ] **Step 6: Report back the notebook's own output**

Row count, column count, the 2025-12-25 spot check, and the dropped-columns check.

---

### Task 2: Independently verify `dim_DateTable`

**Files:**
- Create: `.claude/queries/adhoc/dp-bronze-verify/verify_gold_datetable.py`

- [ ] **Step 1: Write the verification script**

```python
"""
DP GOLD DATETABLE VERIFICATION
============================================================================
Independent check of dim_DateTable (built by Build_Gold_DateTable.Notebook)
- pure calendar math, so this verifies against hand-computed expected
values for known dates rather than a source system (there is no source -
this table has none, same as production).

Also confirms none of the deliberately-dropped "today"-relative columns
leaked back in - a negative check, not just a positive one.

Run manually after Task 1 confirms the notebook ran successfully.
============================================================================
"""

import duckdb

DP_PRESENTATION_WS_ID = "73fd5443-240e-410a-990a-98827f32c087"
DP_PRESENTATION_LH_ID = "966efc8a-16f9-423b-aa43-e368fcd8fb91"
dp_base = f"abfss://{DP_PRESENTATION_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_PRESENTATION_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=== Check 1: row count and column count ===")
row_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/dim_DateTable')").fetchone()[0]
col_count = len(con.execute(f"DESCRIBE SELECT * FROM delta_scan('{dp_base}/dim_DateTable') LIMIT 1").df())
print(f"Row count: {row_count:,} (expect 4,018)")
print(f"Column count: {col_count} (expect 28)")

print("\n=== Check 2: hand-computed spot checks ===")
# 2025-12-25 is a Thursday, Q4, Winter, not a weekend, not peak season boundary issue.
# 2025-07-04 is a Friday, Q3, Summer, peak season, weekday.
# 2025-01-01 is a Wednesday, Q1, Winter, DateKey 20250101.
checks = con.execute(f"""
    SELECT Date, DateKey, Year, Quarter, Month, DayOfWeek, DayOfWeekName, Season,
           IsPeakSeason, IsWeekend, IsBusinessDay, FiscalYear, FiscalQuarter
    FROM delta_scan('{dp_base}/dim_DateTable')
    WHERE Date IN ('2025-12-25', '2025-07-04', '2025-01-01')
    ORDER BY Date
""").df()
print(checks.to_string())
print("\nExpect:")
print("  2025-01-01: DateKey=20250101, Q1, Month=1, DayOfWeekName=Wednesday, Season=Winter, IsPeakSeason=False, IsWeekend=False")
print("  2025-07-04: Q3, Month=7, DayOfWeekName=Friday, Season=Summer, IsPeakSeason=True, IsWeekend=False")
print("  2025-12-25: Q4, Month=12, DayOfWeekName=Thursday, Season=Winter, IsPeakSeason=False, IsWeekend=False")

print("\n=== Check 3: confirm no dropped 'today'-relative columns leaked back in ===")
columns_df = con.execute(f"DESCRIBE SELECT * FROM delta_scan('{dp_base}/dim_DateTable') LIMIT 1").df()
actual_columns = set(columns_df["column_name"].tolist())
dropped_columns = {
    "YearOffset", "IsCurrentYear", "IsCurrentMonth", "IsPreviousYear", "IsPreviousMonth",
    "IsPreviousQuarter", "IsYearToDate", "IsQuarterToDate", "IsMonthToDate",
    "IsRolling6Months", "IsRolling12Months", "IsRolling24Months", "IsRolling36Months",
    "IsRolling48Months", "IsRolling4Quarters", "IsRolling8Quarters", "IsRolling52Weeks",
    "IsRolling365Days", "IsRolling730Days", "IsRolling1095Days", "IsRolling1460Days",
    "IsRolling180Days", "IsRolling545Days", "IsRolling45Days", "IsRolling120Days",
    "IsRolling270Days", "IsRolling450Days", "IsRolling13Weeks", "IsRolling26Weeks",
    "IsRolling104Weeks", "IsRolling156Weeks", "IsLast30Days", "IsLast60Days", "IsLast90Days",
    "IsNext30Days", "IsSameMonthLastYear", "IsSameQuarterLastYear", "RollingPeriodCategory",
    "DaysFromToday",
}
leaked = dropped_columns & actual_columns
print(f"Dropped columns found in table (expect none): {leaked if leaked else 'none - clean'}")

print(f"\nAll columns present: {sorted(actual_columns)}")
```

- [ ] **Step 2: Run it**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
export PATH="$HOME/.local/bin:$PATH"
python ".claude/queries/adhoc/dp-bronze-verify/verify_gold_datetable.py"
```
Expected: row count 4,018, column count 28, all three spot-check dates match the expected values in the script's comments, zero dropped columns found.

**If anything doesn't match: stop, investigate before proceeding to Task 3.**

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add .claude/queries/adhoc/dp-bronze-verify/verify_gold_datetable.py
git commit -m "Add dim_DateTable verification script

Hand-computed spot checks (no source system to compare against - this
table has none) plus a negative check confirming none of the
deliberately-dropped 'today'-relative columns leaked back in.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: Create the `BranchOperational` bronze ingestion

**Files:** none (Fabric portal action — Dataflow Gen2 creation)

- [ ] **Step 1: Brian creates the Dataflow Gen2**

In the Fabric portal:
1. Open workspace `DP - Staging - Dev`
2. **New item** → **Dataflow Gen2**
3. Name it `df_BranchOperational_Raw`
4. In the Power Query editor, use **Home → Advanced Editor** (or equivalent) to paste in the M code below, replacing whatever default query exists

```
let
  Source = Odbc.DataSource("dsn=EquipRDB64", [HierarchicalNavigation = true]),
  #"Navigation 1" = Source{[Name = "Administrator", Kind = "Schema"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Name = "BranchOperational", Kind = "View"]}[Data],
  #"Choose columns" = Table.SelectColumns(#"Navigation 2", {"BranchID", "BranchName", "LocationID", "State", "City"})
in
  #"Choose columns"
```

5. Set the query's **Data destination** to the `DP_Staging` lakehouse (in `DP - Staging - Dev`), table name `BranchOperational`, table action **Replace**
6. **Publish**

This is the same query the current production `df_BranchOperational_Raw.Dataflow` already runs (confirmed via reading its `mashup.pq` this session) — only the destination changes, to the new lakehouse instead of `LH_Master_Data`.

- [ ] **Step 2: Brian runs it once**

Refresh the new dataflow manually to populate `DP_Staging.BranchOperational` for the first time.

- [ ] **Step 3: Verify it landed (agent-executed)**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
export PATH="$HOME/.local/bin:$PATH"
python -c "
import duckdb
con = duckdb.connect()
con.execute('INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;')
con.execute(\"CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');\")
r = con.execute(\"SELECT COUNT(*) FROM delta_scan('abfss://ab15d64d-c7ba-415d-9bcf-7feb1ef9b201@onelake.dfs.fabric.microsoft.com/876255e0-d462-4697-adc1-4a655f5bb101/Tables/BranchOperational')\").fetchone()[0]
print(f'BranchOperational row count: {r}')
sample = con.execute(\"SELECT * FROM delta_scan('abfss://ab15d64d-c7ba-415d-9bcf-7feb1ef9b201@onelake.dfs.fabric.microsoft.com/876255e0-d462-4697-adc1-4a655f5bb101/Tables/BranchOperational') WHERE BranchID = '1'\").df()
print(sample.to_string())
"
```
Expected: some non-zero row count (production's copy of this view is small, well under 200 rows), and a row present for `BranchID = '1'` (Seminole — the specific branch production's own header comment says was previously broken by a bad filter, worth confirming present from day one here).

**If BranchID '1' is missing or the table is empty: stop, investigate before proceeding to Task 4.**

---

### Task 4: Build `Build_Gold_BranchLocation.Notebook`

**Files:**
- Create: `workspaces/DP - Presentation - Dev/Build_Gold_BranchLocation.Notebook/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Presentation - Dev/Build_Gold_BranchLocation.Notebook/notebook-content.py`

This needs a shortcut to reach `BranchOperational` in `DP_Staging` from `DP_Presentation` — same cross-workspace "shortcuts, not copies" pattern already used for `Silver_InTrans` and `GlTrans`.

- [ ] **Step 1: Brian adds the shortcut**

In the Fabric portal:
1. Open workspace `DP - Presentation - Dev` → lakehouse `DP_Presentation`
2. **Tables** → **...** → **New table shortcut** → **Microsoft OneLake**
3. Browse to: workspace `DP - Staging - Dev` → lakehouse `DP_Staging` → **Tables** → select `BranchOperational`
4. Keep the name `BranchOperational`
5. **Create**

- [ ] **Step 2: Generate a logical ID**

```bash
python -c "import uuid; print(uuid.uuid4())"
```

- [ ] **Step 3: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Gold_BranchLocation"
  },
  "config": {
    "version": "2.0",
    "logicalId": "<LOGICAL_ID from Step 2>"
  }
}
```

- [ ] **Step 4: Create the notebook content**

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

# Build_Gold_BranchLocation
# Purpose: Reproduce production's dim_BranchLocation exactly (df_Dim_Location.
# Dataflow in LH_Master_Data), sourced from the new BranchOperational bronze
# table instead - no bug found in this table's enrichment logic during
# review, so this is a faithful port, not a redesign (unlike dim_DateTable).
#
# BranchOperational is an EquipRDB VIEW, not a base table - confirmed this
# session it isn't in JD's Bronze mirror (likely because JD's replication
# only covers base tables, not views), so it can't get a OneLake shortcut
# into JD's mirror the way InTrans/GlTrans did. It gets its own small direct
# ingestion instead (a Dataflow Gen2, same mechanism production already
# uses), landing into DP_Staging, then reaches this notebook via a
# cross-workspace shortcut - same "shortcuts, not copies" pattern already
# used for Silver_InTrans and GlTrans.
#
# Business logic, unchanged from production:
# - Filter out Hourly (BranchID starts with 'H') and Salary (BranchID starts
#   with 'S') branches - keep all numbered operational branches and
#   specialized shops (1, 2, 3, 1I, 1S, 1C, etc.)
# - Classify BranchType: IS Shop / Set-Up Shop / CP Shop / Main Branch, from
#   BranchName text or BranchID suffix
# - Derive ServiceCapacity, MarketPresence, TerritoryCoverage,
#   OperationalPriority, RegionalClassification, ServiceHours,
#   DistanceFromHub, DataQualityScore - all pattern-matched heuristics on
#   BranchID/BranchName/State/City, none date-dependent
# - BranchKey: sequential surrogate key, 1..N, in alphabetical Branch order
#   (matching production's Table.AddIndexColumn after Table.Sort)

print("=" * 80)
print("BUILD_GOLD_BRANCHLOCATION")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F
from pyspark.sql.window import Window

source = spark.read.table("BranchOperational")

# Fix missing LocationID, standardize city names, apply known naming
# correction - matches production's Steps 1-2 exactly.
cleaned = (
    source
    .withColumn("LocationID", F.when(F.col("LocationID").isNull(), F.lit("11")).otherwise(F.col("LocationID")))
    .withColumn("City", F.initcap(F.trim(F.coalesce(F.col("City"), F.lit("")))))
    .withColumn("City", F.when(F.col("City") == "Odonnell", "O'Donnell").otherwise(F.col("City")))
)

# Professional branch display name: "LocationID - City".
with_branch_name = cleaned.withColumn(
    "Branch",
    F.concat(F.coalesce(F.col("LocationID"), F.lit("")), F.lit(" - "), F.coalesce(F.col("City"), F.lit(""))),
)

# Leading-zero removal for known branch numbers - exact same hardcoded
# replacements as production (Table.ReplaceValue chain in the .pq source).
BRANCH_NUMBER_FIXES = {
    "01 - Seminole": "1 - Seminole",
    "02 - Tornillo": "2 - Tornillo",
    "03 - Denver City": "3 - Denver City",
    "04 - Mesquite": "4 - Mesquite",
    "04 - Las Cruces": "4 - Las Cruces",
    "05 - Deming": "5 - Deming",
    "06 - San Angelo": "6 - San Angelo",
    "07 - Ballinger": "7 - Ballinger",
    "08 - Big Spring": "8 - Big Spring",
}
branch_col = F.col("Branch")
for old_value, new_value in BRANCH_NUMBER_FIXES.items():
    branch_col = F.when(F.col("Branch") == old_value, F.lit(new_value)).otherwise(branch_col)
standardized = with_branch_name.withColumn("Branch", branch_col)

row_count_before_filter = standardized.count()
print(f"BranchOperational rows loaded and cleaned: {row_count_before_filter:,}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Smart operational filtering - keep all operational branches, exclude
# Hourly (H*) and Salary (S*) BranchID patterns. Sort alphabetically first
# so the surrogate key (added later) matches production's ordering.

filtered = (
    standardized
    .filter(~(F.coalesce(F.col("BranchID"), F.lit("")).startswith("H")
              | F.coalesce(F.col("BranchID"), F.lit("")).startswith("S")))
    .orderBy("Branch")
)

filtered_count = filtered.count()
print(f"Operational branches after filtering Hourly/Salary: {filtered_count:,}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Branch type classification and business intelligence enrichment - exact
# same rules as production's dim_BranchLocation.pq.

classified = filtered.withColumn(
    "BranchType",
    F.when(F.upper(F.coalesce(F.col("BranchName"), F.lit(""))).contains("IS SHOP")
           | F.coalesce(F.col("BranchID"), F.lit("")).endswith("I"), "IS Shop")
    .when(F.upper(F.coalesce(F.col("BranchName"), F.lit(""))).contains("SET-UP SHOP")
          | F.coalesce(F.col("BranchID"), F.lit("")).endswith("S"), "Set-Up Shop")
    .when(F.upper(F.coalesce(F.col("BranchName"), F.lit(""))).contains("CP SHOP")
          | F.coalesce(F.col("BranchID"), F.lit("")).endswith("C"), "CP Shop")
    .otherwise("Main Branch"),
)

enriched = (
    classified
    .withColumn(
        "ServiceCapacity",
        F.when(F.col("BranchType") == "Main Branch", "Full Service")
        .when(F.col("BranchType") == "IS Shop", "Inspection Specialist")
        .when(F.col("BranchType") == "Set-Up Shop", "Setup Specialist")
        .when(F.col("BranchType") == "CP Shop", "Pickup Specialist")
        .otherwise("Standard Service"),
    )
    .withColumn(
        "MarketPresence",
        F.when((F.upper(F.col("State")) == "TX") & (F.col("BranchType") == "Main Branch"), "Texas Primary Market")
        .when((F.upper(F.col("State")) == "NM") & (F.col("BranchType") == "Main Branch"), "New Mexico Primary Market")
        .when(F.upper(F.col("State")) == "TX", "Texas Secondary Market")
        .when(F.upper(F.col("State")) == "NM", "New Mexico Secondary Market")
        .otherwise("Extended Market"),
    )
    .withColumn(
        "TerritoryCoverage",
        F.when(F.col("BranchType") == "Main Branch", "Regional Hub")
        .when(F.col("BranchType").isin("IS Shop", "Set-Up Shop"), "Service Extension")
        .otherwise("Local Service"),
    )
    .withColumn(
        "OperationalPriority",
        F.when((F.col("BranchType") == "Main Branch") & F.col("MarketPresence").contains("Primary"), F.lit(10.0))
        .when(F.col("BranchType") == "Main Branch", F.lit(8.0))
        .when(F.col("BranchType") == "IS Shop", F.lit(6.0))
        .when(F.col("BranchType") == "Set-Up Shop", F.lit(5.0))
        .otherwise(F.lit(3.0)),
    )
)

print("Branch type classification and business intelligence added.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Data quality scoring, surrogate key, regional/hours/distance analytics -
# exact same rules as production.

with_quality_score = enriched.withColumn(
    "DataQualityScore",
    (F.when((F.coalesce(F.col("LocationID"), F.lit("")) != "") & (F.col("LocationID") != "11"), 20).otherwise(0))
    + (F.when(F.coalesce(F.col("BranchID"), F.lit("")) != "", 20).otherwise(0))
    + (F.when(F.coalesce(F.col("City"), F.lit("")) != "", 15).otherwise(0))
    + (F.when(F.coalesce(F.col("State"), F.lit("")) != "", 15).otherwise(0))
    + (F.when(F.coalesce(F.col("BranchName"), F.lit("")) != "", 15).otherwise(0))
    + (F.when((F.col("BranchType") != "Main Branch") | (F.coalesce(F.col("BranchName"), F.lit("")) != ""), 15).otherwise(0)),
)

# Surrogate key - sequential 1..N in the already-established alphabetical
# Branch order (matches production's Table.AddIndexColumn after Table.Sort).
key_window = Window.orderBy("Branch")
with_key = with_quality_score.withColumn("BranchKey", F.row_number().over(key_window).cast("bigint"))

with_regional = with_key.withColumn(
    "RegionalClassification",
    F.when((F.upper(F.col("State")) == "TX") & F.upper(F.col("City")).isin("SEMINOLE", "DENVER CITY", "BIG SPRING"), "West Texas")
    .when((F.upper(F.col("State")) == "TX") & F.upper(F.col("City")).isin("SAN ANGELO", "BALLINGER"), "Central Texas")
    .when(F.upper(F.col("State")) == "TX", "Texas Other")
    .when((F.upper(F.col("State")) == "NM") & F.upper(F.col("City")).isin("LAS CRUCES", "DEMING"), "Southern New Mexico")
    .when((F.upper(F.col("State")) == "NM") & (F.upper(F.col("City")) == "TORNILLO"), "Border Region")
    .when(F.upper(F.col("State")) == "NM", "New Mexico Other")
    .otherwise("Other Region"),
)

with_hours = with_regional.withColumn(
    "ServiceHours",
    F.when(F.col("BranchType") == "Main Branch", "Extended Hours")
    .when(F.col("BranchType") == "IS Shop", "Business Hours")
    .otherwise("Limited Hours"),
)

with_distance = with_hours.withColumn(
    "DistanceFromHub",
    F.when(F.col("BranchType") == "Main Branch", "Hub Location")
    .when(F.upper(F.col("City")).isin("SEMINOLE", "SAN ANGELO"), "Near Hub")
    .otherwise("Remote Location"),
)

dim_branch_location = with_distance.select(
    "BranchKey", "Branch", "BranchType", "BranchID", "BranchName", "LocationID",
    "State", "City", "ServiceCapacity", "MarketPresence", "TerritoryCoverage",
    "OperationalPriority", "RegionalClassification", "ServiceHours",
    "DistanceFromHub", "DataQualityScore",
)

final_count = dim_branch_location.count()
print(f"dim_BranchLocation rows: {final_count:,}")

dim_branch_location.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/dim_BranchLocation")

print("Gold build complete: dim_BranchLocation written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Verification - quick in-notebook sanity check, not the final proof (that's
# the independent DuckDB script). Confirms Seminole (BranchID '1') is
# present - production's own header comment flags this as the specific
# branch a prior bug (arbitrary Table.Skip(30)) used to drop.

seminole_check = spark.sql("""
    SELECT BranchKey, Branch, BranchType, BranchID, RegionalClassification, DataQualityScore
    FROM delta.`Tables/dim_BranchLocation`
    WHERE BranchID = '1'
""").toPandas()
print("Seminole (BranchID '1') check - expect exactly 1 row, BranchType='Main Branch':")
print(seminole_check.to_string())
if len(seminole_check) == 1 and seminole_check["BranchType"][0] == "Main Branch":
    print("PASS")
else:
    print("FAIL - Seminole missing or misclassified, do not trust this build.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 5: Commit and push**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git status --short
```
Expect exactly 2 new untracked files under `workspaces/DP - Presentation - Dev/Build_Gold_BranchLocation.Notebook/`. If anything else shows, STOP and report rather than committing.

```bash
git add "workspaces/DP - Presentation - Dev/Build_Gold_BranchLocation.Notebook"
git commit -m "Add Build_Gold_BranchLocation notebook

Faithful PySpark port of production's dim_BranchLocation enrichment
logic (df_Dim_Location.Dataflow) - no bug found in this table's
business logic during review, so no redesign, unlike dim_DateTable.
Sourced from the new BranchOperational bronze table (a Dataflow Gen2
ingestion of an EquipRDB view that isn't in JD's Bronze mirror, since
JD's replication only covers base tables) via a cross-workspace
shortcut, same 'shortcuts, not copies' pattern already used for
Silver_InTrans and GlTrans.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git fetch origin dev
git log --oneline HEAD..origin/dev
```
If the last command shows commits, report NEEDS_CONTEXT rather than pushing. Otherwise:
```bash
git push origin dev
```

- [ ] **Step 6: Brian confirms Dev picked up the notebook and runs it**

`DP - Presentation - Dev` → Source control → **Update all**. Open `Build_Gold_BranchLocation.Notebook` and run all cells.

- [ ] **Step 7: Report back the notebook's own output**

Row counts at each stage and the Seminole spot check.

---

### Task 5: Independently verify `dim_BranchLocation`

**Files:**
- Create: `.claude/queries/adhoc/dp-bronze-verify/verify_gold_branchlocation.py`

- [ ] **Step 1: Write the verification script**

```python
"""
DP GOLD BRANCHLOCATION VERIFICATION
============================================================================
Independent check of dim_BranchLocation (built by
Build_Gold_BranchLocation.Notebook) - confirms row count, that Seminole
(BranchID '1') survived filtering (the specific branch a prior production
bug - arbitrary Table.Skip(30) - used to drop, per that table's own header
comment), and spot-checks BranchType/RegionalClassification for a few known
branches against the documented business rules.

Run manually after Task 4 confirms the notebook ran successfully.
============================================================================
"""

import duckdb

DP_PRESENTATION_WS_ID = "73fd5443-240e-410a-990a-98827f32c087"
DP_PRESENTATION_LH_ID = "966efc8a-16f9-423b-aa43-e368fcd8fb91"
dp_base = f"abfss://{DP_PRESENTATION_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_PRESENTATION_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=== Check 1: row count ===")
row_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/dim_BranchLocation')").fetchone()[0]
print(f"Row count: {row_count} (production has 69 operational branches - expect a similar count)")

print("\n=== Check 2: Seminole (BranchID '1') present and correctly classified ===")
seminole = con.execute(f"""
    SELECT BranchKey, Branch, BranchType, BranchID, State, City, RegionalClassification, DataQualityScore
    FROM delta_scan('{dp_base}/dim_BranchLocation')
    WHERE BranchID = '1'
""").df()
print(seminole.to_string())
print(f"Expect exactly 1 row, BranchType='Main Branch', RegionalClassification='West Texas': "
      f"{'PASS' if len(seminole) == 1 and seminole['BranchType'][0] == 'Main Branch' and seminole['RegionalClassification'][0] == 'West Texas' else 'FAIL'}")

print("\n=== Check 3: no Hourly/Salary branches leaked through ===")
leaked = con.execute(f"""
    SELECT COUNT(*) FROM delta_scan('{dp_base}/dim_BranchLocation')
    WHERE BranchID LIKE 'H%' OR BranchID LIKE 'S%'
""").fetchone()[0]
print(f"Hourly/Salary branches in output (expect 0): {leaked}")

print("\n=== Check 4: BranchType distribution sanity ===")
breakdown = con.execute(f"""
    SELECT BranchType, COUNT(*) AS cnt
    FROM delta_scan('{dp_base}/dim_BranchLocation')
    GROUP BY BranchType
    ORDER BY cnt DESC
""").df()
print(breakdown.to_string())
```

- [ ] **Step 2: Run it**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
export PATH="$HOME/.local/bin:$PATH"
python ".claude/queries/adhoc/dp-bronze-verify/verify_gold_branchlocation.py"
```
Expected: a sensible row count, Check 2 shows PASS, Check 3 shows 0, Check 4 shows a mix of Main Branch/IS Shop/Set-Up Shop/CP Shop (not 100% one category).

**If Check 2 or Check 3 fails: stop, investigate before proceeding to Task 6.**

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add .claude/queries/adhoc/dp-bronze-verify/verify_gold_branchlocation.py
git commit -m "Add dim_BranchLocation verification script

Confirms row count, Seminole (BranchID '1') present and correctly
classified - the specific branch a prior production bug (arbitrary
Table.Skip(30)) used to drop - and no Hourly/Salary branches leaked
through the filter.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 6: Update the reference doc

**Files:**
- Modify: `docs/architecture/data-platform-workspaces.md`

- [ ] **Step 1: Add both new tables and the bronze ingestion to the Lakehouses section**

Add to the existing `DP_Staging` row's Contents: `Tables/BranchOperational` — Dataflow Gen2 ingestion (`df_BranchOperational_Raw`, direct ODBC pull from `EquipRDB`'s `BranchOperational` view — not a JD Bronze mirror shortcut, since JD's replication doesn't cover views) verified 2026-09-09.

Add to the existing `DP_Presentation` row's Contents: `Tables/BranchOperational` — OneLake shortcut into `DP_Staging.BranchOperational`. `Tables/dim_DateTable` — built by `Build_Gold_DateTable.Notebook`, pure calendar generation, no source dependency. `Tables/dim_BranchLocation` — built by `Build_Gold_BranchLocation.Notebook`.

Add a new subsection:

```markdown
### `dim_DateTable` — deliberately slimmer than production, not an incomplete port

Production's `dim_DateTable` (`LH_Master_Data`) has 76 columns. This one has 28. The
missing ~48 are every "today"-relative column (`IsCurrentYear`, `IsCurrentMonth`,
`IsPrevious*`, `IsYearToDate`/`IsQuarterToDate`/`IsMonthToDate`, every `IsRolling*`,
`IsLast*Days`, `IsNext30Days`, `IsSameMonthLastYear`/`IsSameQuarterLastYear`,
`RollingPeriodCategory`, `DaysFromToday`, `YearOffset`) — all of which were computed off
`DateTime.LocalNow()` baked into static refresh-time columns in production, the same
UTC-not-actual-local-time bug class already found and fixed twice this session
(`Fact_PartsAdjustments.LoadedDatetime`, and the documented 2026-02-27 Data Refresh Table
fix). Confirmed live and silently wrong for hours around midnight in every one of those
flags in production, the whole time.

**This was a deliberate redesign, agreed with Brian 2026-09-09, not a mistake or an
unfinished port:** that class of logic belongs in report-layer DAX measures (or a
calculation group) evaluated dynamically against `TODAY()` at query time, not frozen at
whatever moment the backend last refreshed. It will come back as report-layer work when
each report actually migrates onto this backend — deliberately not part of this table.

Verified 2026-09-09 via `verify_gold_datetable.py`: 4,018 rows (2020-01-01 to
2030-12-31, matching production's range), 28 columns, hand-computed spot checks correct
for three known dates, zero dropped columns leaked back in.

### `dim_BranchLocation` — faithful port, no bug found

Unlike `dim_DateTable`, no correctness issue was found in this table's enrichment logic
during review — the `MarketPresence`/`TerritoryCoverage`/`OperationalPriority`/
`RegionalClassification`/`ServiceHours`/`DistanceFromHub`/`DataQualityScore` heuristics
are all pattern-matched on `BranchID`/`BranchName`/`State`/`City`, none date-dependent.
Ported faithfully to PySpark from production's `dim_BranchLocation.pq`.

Its source, `BranchOperational`, is an EquipRDB **view**, not a base table — confirmed
this session it isn't in JD's Bronze mirror (JD's replication apparently only covers
base tables). Gets its own small Dataflow Gen2 ingestion instead (same mechanism
production already uses), landing into `DP_Staging`, then reaches the gold notebook via
a cross-workspace shortcut — same "shortcuts, not copies" pattern as `Silver_InTrans`/
`GlTrans`.

Verified 2026-09-09 via `verify_gold_branchlocation.py`: Seminole (`BranchID '1'` — the
specific branch a prior production bug, an arbitrary `Table.Skip(30)`, used to drop) is
present and correctly classified as `Main Branch` / `West Texas`, zero Hourly/Salary
branches leaked through the filter, `BranchType` distribution shows a healthy mix
(not collapsed into one category).
```

- [ ] **Step 2: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add docs/architecture/data-platform-workspaces.md
git commit -m "Record dim_DateTable and dim_BranchLocation gold tables

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 7: Final end-to-end check

**Files:** none

- [ ] **Step 1: Confirm both repos clean**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs" && git status --short
cd "C:\Users\bfox\Documents\Git-Projects\data-projects" && git status --short
```
Expected: both clean (or only unrelated pre-existing noise, not anything from this plan).

**No report is repointed at either of these tables as part of this plan** — Brian explicitly paused report migration to focus on foundational backend work. That's a deliberate future step, not an oversight here.
