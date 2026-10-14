# MD Invoices Monthly Snapshot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up monthly-snapshot infrastructure for the MD Invoices With No Freight open-order backlog, so point-in-time history accumulates for future trend analysis — mirroring the existing Open Parts Tickets snapshot pattern.

**Architecture:** A new Fabric notebook reads the live `Fact_MDInvoices_NoFreight` Lakehouse table on the 1st of each month, stamps a `SnapshotDate`, and appends into a new `Fact_MDInvoices_NoFreight_Snapshot` Delta table. A new semantic model table wires that Delta table in via the SQL Analytics Endpoint, with its own copies of the three DAX calculated columns (`MissedFreightAmount`, `PctFreightDifference`, `FreightBucket`) since those don't exist in the Lakehouse. No trend page yet — infrastructure only.

**Tech Stack:** Fabric Lakehouse (Delta/PySpark notebook), Fabric Pipeline (schedule), Power BI semantic model (TMDL), DAX.

**Spec:** `docs/superpowers/specs/2026-07-08-md-invoices-monthly-snapshot-design.md`

---

## Important: This plan has two phases

**Phase 1 (Tasks 1–6)** is fully executable in this repo — creating reference files, TMDL edits, and docs. An agent can do all of it.

**Phase 2 (Tasks 7–8)** happens in the Fabric portal and Power BI Desktop — a browser/GUI environment no coding agent in this repo has access to. These are written as a precise runbook for Brian to execute by hand, using the exact code/config produced in Phase 1. **Do not attempt to skip, simulate, or mark these complete without Brian confirming he did them** — Task 8 in particular depends on live data that only exists after Task 7 runs.

---

## Phase 1 — Repo Changes

### Task 1: Create the snapshot notebook reference script

**Files:**

- Create: `projects/md invoices with no freight - report/queries/notebooks/nb_Snapshot_MDInvoices_NoFreight.py`

- [ ] **Step 1: Write the notebook reference file**

```python
# ============================================================================
# NOTEBOOK: nb_Snapshot_MDInvoices_NoFreight
# ============================================================================
#
# PURPOSE:
#   Takes a beginning-of-month snapshot of all currently open MD (Machine
#   Down) parts orders and appends it to Fact_MDInvoices_NoFreight_Snapshot
#   in LH_Master_Data. Run on the 1st of each month (via
#   Pipeline_Monthly_MDInvoices_Snapshot).
#
# GRAIN: One row per open MD order line per SnapshotDate (beginning of month)
# SOURCE: Fact_MDInvoices_NoFreight (already refreshed by daily pipeline, Phase 4)
# TARGET: Fact_MDInvoices_NoFreight_Snapshot (Delta table, append mode)
#
# SCHEDULING:
#   Monthly pipeline scheduled for 5:30 AM CST on the 1st of each month.
#   The 5:30 AM time ensures the 4:15 AM master orchestrator (~80 min) has
#   already refreshed Fact_MDInvoices_NoFreight before this runs.
#
# BACKFILL NOTE:
#   Because Fact_MDInvoices_NoFreight only shows CURRENTLY open orders,
#   there is no way to backfill prior months. The snapshot history begins
#   from the first time this notebook runs.
#
# EXCLUDED COLUMNS:
#   MissedFreightAmount, PctFreightDifference, and FreightBucket are NOT
#   read here — they are DAX calculated columns that exist only in the
#   semantic model, not in this Lakehouse Delta table. They are recreated
#   on the semantic-model side (Fact_MDInvoices_NoFreight_Snapshot.tmdl).
#
# DUPLICATE PROTECTION:
#   The notebook checks for an existing snapshot before writing.
#   Safe to rerun — it will skip if the month is already captured.
#
# ============================================================================

# ============================================================================
# CELL 1 — SETUP
# Paste this into the first code cell of the Fabric notebook.
# ============================================================================

from pyspark.sql import functions as F
from datetime import date

# SnapshotDate is always the 1st of the CURRENT month.
# This is a permanent historical record — the date does not drift.
today = date.today()
snapshot_date = today.replace(day=1)
snapshot_table = "Fact_MDInvoices_NoFreight_Snapshot"

print(f"Snapshot date : {snapshot_date}")
print(f"Target table  : {snapshot_table}")
print(f"Run date      : {today}")


# ============================================================================
# CELL 2 — DUPLICATE GUARD
# Paste this into the second code cell.
# Prevents double-writing if the notebook is accidentally rerun.
# ============================================================================

snapshot_ready = False

try:
    existing = spark.sql(f"""
        SELECT COUNT(*) AS cnt
        FROM {snapshot_table}
        WHERE SnapshotDate = '{snapshot_date}'
    """).collect()[0]["cnt"]

    if existing > 0:
        print(f"SKIPPED: Snapshot for {snapshot_date} already exists ({existing} rows). No action taken.")
    else:
        print(f"No existing snapshot for {snapshot_date}. Ready to proceed.")
        snapshot_ready = True

except Exception as e:
    # Table does not exist yet — expected on the very first run.
    # saveAsTable will create it automatically on the first write.
    print(f"Note: Snapshot table not found (expected on first run). Will create on write.")
    print(f"Detail: {e}")
    snapshot_ready = True


# ============================================================================
# CELL 3 — READ AND WRITE SNAPSHOT
# Paste this into the third code cell.
# Only runs if snapshot_ready = True (set by Cell 2).
# ============================================================================

if not snapshot_ready:
    print("No action taken — snapshot for this month already exists.")
else:
    # Read the current open MD orders from the live fact table.
    # This table is refreshed daily by the main pipeline (Phase 4).
    df = spark.sql("""
        SELECT
            FileNumber,
            LineNumber,
            Branch,
            Franchise,
            CustomerNumber,
            OrderDate,
            CustomerOrderNumber,
            RONumber,
            PartNumber,
            OrderQty,
            UnitPrice,
            UnitCost,
            LineTotal,
            Weight,
            TotalLineWeight,
            TotalFreightCharged,
            FreightLineCount,
            FreightStatus,
            Salesperson,
            JobCode,
            SuppliedQty,
            BackorderQty,
            OrderType
        FROM Fact_MDInvoices_NoFreight
    """)

    # Count rows before writing to avoid a second scan
    row_count = df.count()
    print(f"Open MD order lines to snapshot: {row_count}")

    # Add the snapshot date (always the 1st of the current month)
    df = df.withColumn("SnapshotDate", F.lit(str(snapshot_date)).cast("date"))

    # Append to the snapshot table.
    # mode="append"    — never overwrites existing snapshots
    # mergeSchema=True — handles any future column additions gracefully
    df.write \
        .mode("append") \
        .option("mergeSchema", "true") \
        .saveAsTable(snapshot_table)

    print(f"SUCCESS: {row_count} rows written to {snapshot_table} for {snapshot_date}")


# ============================================================================
# CELL 4 — VERIFICATION (optional, run manually to confirm)
# Paste this into a fourth code cell.
# Use after the first few runs to confirm snapshot history is building correctly.
# ============================================================================

# Uncomment and run manually to check snapshot history:
#
# summary = spark.sql("""
#     SELECT
#         SnapshotDate,
#         COUNT(DISTINCT FileNumber) AS Open_Order_Count,
#         ROUND(SUM(TotalFreightCharged), 2) AS Total_Freight_Charged,
#         ROUND(SUM(TotalLineWeight), 2) AS Total_Weight
#     FROM Fact_MDInvoices_NoFreight_Snapshot
#     GROUP BY SnapshotDate
#     ORDER BY SnapshotDate DESC
# """)
# summary.show()
```

- [ ] **Step 2: Commit**

```bash
git add "projects/md invoices with no freight - report/queries/notebooks/nb_Snapshot_MDInvoices_NoFreight.py"
git commit -m "Add reference notebook script for MD Invoices monthly snapshot"
```

---

### Task 2: Add the new semantic model table (TMDL)

**Files:**

- Create: `projects/md invoices with no freight - report/reports/current/MD Invoices With No Freight.SemanticModel/definition/tables/Fact_MDInvoices_NoFreight_Snapshot.tmdl`

- [ ] **Step 1: Write the new table file**

Column properties (dataType/formatString/summarizeBy) match `Fact_MDInvoices_NoFreight.tmdl` exactly for every shared column. The three calculated columns are byte-for-byte identical formulas to the live table's versions, just referencing this table's name.

```
table Fact_MDInvoices_NoFreight_Snapshot
	lineageTag: 2a911457-9498-4a6a-8801-d8bd6c9d406b

	column FileNumber
		dataType: int64
		formatString: 0
		lineageTag: 8a42dabd-98e9-4009-8162-ab14c341caf8
		summarizeBy: none
		sourceColumn: FileNumber

		annotation SummarizationSetBy = User

	column LineNumber
		dataType: int64
		formatString: 0
		lineageTag: 04635e68-ab12-4939-837e-33551410db71
		summarizeBy: none
		sourceColumn: LineNumber

		annotation SummarizationSetBy = User

	column Branch
		dataType: string
		lineageTag: 9003adc6-93e7-4194-9631-622fa005503e
		summarizeBy: none
		sourceColumn: Branch

		annotation SummarizationSetBy = Automatic

	column Franchise
		dataType: string
		lineageTag: a2f092de-a198-4cc6-a096-2e3d64757091
		summarizeBy: none
		sourceColumn: Franchise

		annotation SummarizationSetBy = Automatic

	column CustomerNumber
		dataType: string
		lineageTag: 373fe7cd-05db-4d57-969f-072b2baa6a8c
		summarizeBy: none
		sourceColumn: CustomerNumber

		annotation SummarizationSetBy = Automatic

	column OrderDate
		dataType: dateTime
		formatString: Short Date
		lineageTag: 5865c309-8d29-425e-b996-1abf2fa7296a
		summarizeBy: none
		sourceColumn: OrderDate

		annotation SummarizationSetBy = Automatic

		annotation UnderlyingDateTimeDataType = Date

	column CustomerOrderNumber
		dataType: string
		lineageTag: 3b5c8c19-a60f-458e-8679-fb56dc357c04
		summarizeBy: none
		sourceColumn: CustomerOrderNumber

		annotation SummarizationSetBy = Automatic

	column RONumber
		dataType: int64
		formatString: 0
		lineageTag: 008baa52-2b05-4e5e-83d9-f29c796951af
		summarizeBy: none
		sourceColumn: RONumber

		annotation SummarizationSetBy = User

	column PartNumber
		dataType: string
		lineageTag: fda34bf0-ac1c-4ae4-a942-9e33620261b6
		summarizeBy: none
		sourceColumn: PartNumber

		annotation SummarizationSetBy = Automatic

	column OrderQty
		dataType: double
		lineageTag: ebd9874e-935e-4d62-a04a-48b21ce23acb
		summarizeBy: sum
		sourceColumn: OrderQty

		annotation SummarizationSetBy = Automatic

		annotation PBI_FormatHint = {"isGeneralNumber":true}

	column UnitPrice
		dataType: double
		lineageTag: a1755adf-c5fa-4d73-9fae-cb1b33f34e2e
		summarizeBy: sum
		sourceColumn: UnitPrice

		annotation SummarizationSetBy = Automatic

		annotation PBI_FormatHint = {"isGeneralNumber":true}

	column UnitCost
		dataType: double
		lineageTag: 154ea0ec-d60e-4443-8d2f-875228757ed1
		summarizeBy: sum
		sourceColumn: UnitCost

		annotation SummarizationSetBy = Automatic

		annotation PBI_FormatHint = {"isGeneralNumber":true}

	column LineTotal
		dataType: double
		lineageTag: 6e59f9ea-58e1-48f2-b05f-6450e949c60d
		summarizeBy: sum
		sourceColumn: LineTotal

		annotation SummarizationSetBy = Automatic

		annotation PBI_FormatHint = {"isGeneralNumber":true}

	column Weight
		dataType: double
		lineageTag: 4116b89f-ac23-4836-9955-ae3566921268
		summarizeBy: sum
		sourceColumn: Weight

		annotation SummarizationSetBy = Automatic

		annotation PBI_FormatHint = {"isGeneralNumber":true}

	column TotalLineWeight
		dataType: double
		lineageTag: 7a7a1a48-c007-4dfc-8010-81ec8c3b926d
		summarizeBy: sum
		sourceColumn: TotalLineWeight

		annotation SummarizationSetBy = Automatic

		annotation PBI_FormatHint = {"isGeneralNumber":true}

	column TotalFreightCharged
		dataType: double
		lineageTag: a72826da-e4a3-4478-84b8-86bdcbf6136a
		summarizeBy: sum
		sourceColumn: TotalFreightCharged

		annotation SummarizationSetBy = Automatic

		annotation PBI_FormatHint = {"isGeneralNumber":true}

	column FreightLineCount
		dataType: int64
		formatString: 0
		lineageTag: 48a6fdd3-96bc-4871-842b-9f434c000bcd
		summarizeBy: none
		sourceColumn: FreightLineCount

		annotation SummarizationSetBy = User

	column FreightStatus
		dataType: string
		lineageTag: 75323804-7f42-4162-aaaf-5289ad0cf520
		summarizeBy: none
		sourceColumn: FreightStatus

		annotation SummarizationSetBy = Automatic

	column Salesperson
		dataType: string
		lineageTag: 9a7872e6-403b-45aa-8865-c9d4d2ae5e96
		summarizeBy: none
		sourceColumn: Salesperson

		annotation SummarizationSetBy = Automatic

	column JobCode
		dataType: string
		lineageTag: 36cb7de6-3f0b-4e8d-a967-b4a13b90eca2
		summarizeBy: none
		sourceColumn: JobCode

		annotation SummarizationSetBy = Automatic

	column SuppliedQty
		dataType: double
		lineageTag: e7b39c25-c3c1-4bab-afef-4d3dd5cadf59
		summarizeBy: sum
		sourceColumn: SuppliedQty

		annotation SummarizationSetBy = Automatic

		annotation PBI_FormatHint = {"isGeneralNumber":true}

	column BackorderQty
		dataType: double
		lineageTag: 03fd6a1a-4a1b-41d4-a65d-d5502fdcf24e
		summarizeBy: sum
		sourceColumn: BackorderQty

		annotation SummarizationSetBy = Automatic

		annotation PBI_FormatHint = {"isGeneralNumber":true}

	column OrderType
		dataType: string
		lineageTag: aa212310-0279-41b1-b685-17c7bc5047dc
		summarizeBy: none
		sourceColumn: OrderType

		annotation SummarizationSetBy = Automatic

	column SnapshotDate
		dataType: dateTime
		formatString: Long Date
		lineageTag: 6a983a9f-7088-46e3-9cee-d4507830e556
		summarizeBy: none
		sourceColumn: SnapshotDate

		annotation SummarizationSetBy = Automatic

		annotation UnderlyingDateTimeDataType = Date

	column MissedFreightAmount =
			VAR InvTotalWeight =
			    CALCULATE(
			        SUM(Fact_MDInvoices_NoFreight_Snapshot[TotalLineWeight]),
			        ALLEXCEPT(Fact_MDInvoices_NoFreight_Snapshot, Fact_MDInvoices_NoFreight_Snapshot[FileNumber], Fact_MDInvoices_NoFreight_Snapshot[SnapshotDate])
			    )
			VAR ActualFreightAmt =
			    CALCULATE(
			        MAX(Fact_MDInvoices_NoFreight_Snapshot[TotalFreightCharged]),
			        ALLEXCEPT(Fact_MDInvoices_NoFreight_Snapshot, Fact_MDInvoices_NoFreight_Snapshot[FileNumber], Fact_MDInvoices_NoFreight_Snapshot[SnapshotDate])
			    )
			VAR Bracket =
			    FILTER(
			        FreightCalculator,
			        FreightCalculator[PartWeightFrom] <= InvTotalWeight
			            && (FreightCalculator[PartWeightTo] + 1) > InvTotalWeight
			    )
			VAR BaseRate = MAXX(Bracket, FreightCalculator[BaseRate])
			VAR AdditiveRate = MAXX(Bracket, FreightCalculator[AdditiveRatePerPound])
			VAR BaseRateFinal = IF(ISBLANK(BaseRate), 0, BaseRate)
			VAR AdditiveRateFinal = IF(ISBLANK(AdditiveRate), 0.15, AdditiveRate)
			VAR CalcFreight = BaseRateFinal + (AdditiveRateFinal * InvTotalWeight)
			RETURN
			    CalcFreight - ActualFreightAmt
		formatString: $#,##0.00;($#,##0.00);$#,##0.00
		lineageTag: eb592f28-36bb-4fce-bd83-6fd0faead4fc
		summarizeBy: none

		annotation SummarizationSetBy = User

	column PctFreightDifference =
			VAR InvTotalWeight =
			    CALCULATE(
			        SUM(Fact_MDInvoices_NoFreight_Snapshot[TotalLineWeight]),
			        ALLEXCEPT(Fact_MDInvoices_NoFreight_Snapshot, Fact_MDInvoices_NoFreight_Snapshot[FileNumber], Fact_MDInvoices_NoFreight_Snapshot[SnapshotDate])
			    )
			VAR ActualFreightAmt =
			    CALCULATE(
			        MAX(Fact_MDInvoices_NoFreight_Snapshot[TotalFreightCharged]),
			        ALLEXCEPT(Fact_MDInvoices_NoFreight_Snapshot, Fact_MDInvoices_NoFreight_Snapshot[FileNumber], Fact_MDInvoices_NoFreight_Snapshot[SnapshotDate])
			    )
			VAR Bracket =
			    FILTER(
			        FreightCalculator,
			        FreightCalculator[PartWeightFrom] <= InvTotalWeight
			            && (FreightCalculator[PartWeightTo] + 1) > InvTotalWeight
			    )
			VAR BaseRate = MAXX(Bracket, FreightCalculator[BaseRate])
			VAR AdditiveRate = MAXX(Bracket, FreightCalculator[AdditiveRatePerPound])
			VAR BaseRateFinal = IF(ISBLANK(BaseRate), 0, BaseRate)
			VAR AdditiveRateFinal = IF(ISBLANK(AdditiveRate), 0.15, AdditiveRate)
			VAR CalcFreight = BaseRateFinal + (AdditiveRateFinal * InvTotalWeight)
			VAR Diff = CalcFreight - ActualFreightAmt
			VAR AvgFreight = DIVIDE(CalcFreight + ActualFreightAmt, 2)
			RETURN
			    DIVIDE(Diff, AvgFreight)
		formatString: 0.0%;-0.0%;0.0%
		lineageTag: 5dbece6f-0b82-4cd3-9f37-7940049296da
		summarizeBy: none

		annotation SummarizationSetBy = User

	column FreightBucket =
			SWITCH(
			    TRUE(),
			    Fact_MDInvoices_NoFreight_Snapshot[FreightStatus] = "No Freight"
			        || Fact_MDInvoices_NoFreight_Snapshot[FreightStatus] = "No Freight Charged",
			        "No Freight",
			    Fact_MDInvoices_NoFreight_Snapshot[FreightStatus] = "Has Freight"
			        && NOT ISBLANK(Fact_MDInvoices_NoFreight_Snapshot[MissedFreightAmount])
			        && Fact_MDInvoices_NoFreight_Snapshot[MissedFreightAmount] > 1,
			        "Partial Freight",
			    Fact_MDInvoices_NoFreight_Snapshot[FreightStatus] = "Has Freight",
			        "Adequate Freight"
			)
		dataType: string
		lineageTag: 21df33ac-1a79-4cff-96e1-af1c0ce69031
		summarizeBy: none

		annotation SummarizationSetBy = User

	partition Fact_MDInvoices_NoFreight_Snapshot = m
		mode: import
		source =
				let
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
				    dbo_Fact_MDInvoices_NoFreight_Snapshot = Source{[Schema="dbo",Item="Fact_MDInvoices_NoFreight_Snapshot"]}[Data]
				in
				    dbo_Fact_MDInvoices_NoFreight_Snapshot

	annotation PBI_NavigationStepName = Navigation

	annotation PBI_ResultType = Table
```

**Important deviation from the live table's calculated columns, and why:** `Fact_MDInvoices_NoFreight`'s `ALLEXCEPT` only preserves `FileNumber` (there's one `SnapshotDate`-equivalent context per row since it's a live table). This snapshot table has **multiple snapshot dates** in the same table, so `ALLEXCEPT` must also preserve `SnapshotDate` — otherwise `MissedFreightAmount` for a given `FileNumber` would blend line weights/freight across every month that order number happened to appear open in, instead of scoping to that specific snapshot. This is the one formula change from a pure copy-paste; everything else is identical.

- [ ] **Step 2: Verify TMDL syntax has no `//` comments and no tab/space mixing issues**

```bash
grep -n "//" "projects/md invoices with no freight - report/reports/current/MD Invoices With No Freight.SemanticModel/definition/tables/Fact_MDInvoices_NoFreight_Snapshot.tmdl"
```

Expected: no output (no matches). Per this repo's CLAUDE.md, `//` anywhere in a `.tmdl` file causes a Desktop parse error.

- [ ] **Step 3: Commit**

```bash
git add "projects/md invoices with no freight - report/reports/current/MD Invoices With No Freight.SemanticModel/definition/tables/Fact_MDInvoices_NoFreight_Snapshot.tmdl"
git commit -m "Add Fact_MDInvoices_NoFreight_Snapshot semantic model table"
```

---

### Task 3: Register the new table in model.tmdl

**Files:**

- Modify: `projects/md invoices with no freight - report/reports/current/MD Invoices With No Freight.SemanticModel/definition/model.tmdl:29`

- [ ] **Step 1: Add the ref table line**

Current content around line 29:

```
ref table Fact_MDInvoices_Closed
ref table '% Freight Difference Threshold'
```

Change to:

```
ref table Fact_MDInvoices_Closed
ref table Fact_MDInvoices_NoFreight_Snapshot
ref table '% Freight Difference Threshold'
```

Use the Edit tool with old_string `ref table Fact_MDInvoices_Closed\nref table '% Freight Difference Threshold'` and new_string `ref table Fact_MDInvoices_Closed\nref table Fact_MDInvoices_NoFreight_Snapshot\nref table '% Freight Difference Threshold'`.

Without this line, Desktop will not load the new table file at all — every table in a TMDL-format PBIP model needs a corresponding `ref table` entry in `model.tmdl`.

- [ ] **Step 2: Commit**

```bash
git add "projects/md invoices with no freight - report/reports/current/MD Invoices With No Freight.SemanticModel/definition/model.tmdl"
git commit -m "Register Fact_MDInvoices_NoFreight_Snapshot table in model.tmdl"
```

---

### Task 4: Add relationships

**Files:**

- Modify: `projects/md invoices with no freight - report/reports/current/MD Invoices With No Freight.SemanticModel/definition/relationships.tmdl`

- [ ] **Step 1: Append two new relationships to the end of the file**

Current end of file:

```
relationship d9e23f80-518d-44d3-a192-b8ffe80aaad6
	fromColumn: Fact_MDInvoices_Closed.FreightBucket
	toColumn: dim_FreightPerformanceGroup.Group
```

Use the Edit tool to append after that block:

```
relationship d9e23f80-518d-44d3-a192-b8ffe80aaad6
	fromColumn: Fact_MDInvoices_Closed.FreightBucket
	toColumn: dim_FreightPerformanceGroup.Group

relationship 41e8ee6e-908e-4975-8594-1460cce1bd4c
	fromColumn: Fact_MDInvoices_NoFreight_Snapshot.Branch
	toColumn: dim_BranchLocation.BranchID

relationship 4baad27a-804c-46a8-9fc5-5f8ec59584f7
	fromColumn: Fact_MDInvoices_NoFreight_Snapshot.SnapshotDate
	toColumn: dim_DateTable.Date
```

**Deliberately not related:** `OrderDate` and `FreightBucket` stay unrelated on this table — `OrderDate` to avoid a second active relationship to `dim_DateTable` from the same table (matching the Open Parts Tickets snapshot table precedent), and `FreightBucket` because there's no trend-page tab/slicer UI consuming it yet (unlike the live table, which relates it to `dim_FreightPerformanceGroup` to drive its tab filter). Add that relationship later if/when a trend page needs bucket-based filtering.

- [ ] **Step 2: Commit**

```bash
git add "projects/md invoices with no freight - report/reports/current/MD Invoices With No Freight.SemanticModel/definition/relationships.tmdl"
git commit -m "Relate Fact_MDInvoices_NoFreight_Snapshot to dim_BranchLocation and dim_DateTable"
```

---

### Task 5: Update project documentation

**Files:**

- Modify: `projects/md invoices with no freight - report/CLAUDE.md`
- Modify: `projects/md invoices with no freight - report/PROJECT-SUMMARY.md`

- [ ] **Step 1: Add a "Monthly Snapshot" section to CLAUDE.md**

Insert a new `## Monthly Snapshot (added 2026-07-08)` section immediately after the `## Freight Opportunity Fix (2026-07-06)` section (before `## Known Issues & Gotchas`):

```markdown
## Monthly Snapshot (added 2026-07-08)

Point-in-time history for the open MD freight backlog — mirrors the Open Parts Tickets snapshot pattern (`nb_Snapshot_Parts_Open_Orders` / `Fact_Parts_Open_Orders_Snapshot`).

- **Notebook:** `nb_Snapshot_MDInvoices_NoFreight` in `LH_Master_Data` — reference script at `queries/notebooks/nb_Snapshot_MDInvoices_NoFreight.py` in this project folder
- **Target table:** `Fact_MDInvoices_NoFreight_Snapshot` (Delta, append mode)
- **Pipeline:** `Pipeline_Monthly_MDInvoices_Snapshot` — 5:30 AM CST on the 1st of each month, after the 4:15 AM master orchestrator refreshes `Fact_MDInvoices_NoFreight`
- **First snapshot:** whenever the notebook is first run manually in Fabric. History builds from there — no backfill possible, since the source only reflects currently-open orders.
- **Semantic model table:** `Fact_MDInvoices_NoFreight_Snapshot`, wired to `dim_BranchLocation` (via `Branch`) and `dim_DateTable` (via `SnapshotDate`). `OrderDate` is present but not related, to avoid a second active relationship to `dim_DateTable`.
- **Calculated columns are a third copy.** `MissedFreightAmount`, `PctFreightDifference`, and `FreightBucket` are recreated on this table identically to `Fact_MDInvoices_NoFreight` and `Fact_MDInvoices_Closed` — except `ALLEXCEPT` here also preserves `SnapshotDate` (not just `FileNumber`), since this table holds multiple snapshot dates for the same order number over time. **If the freight-bracket formula changes again, update all three tables.**
- **No trend page yet.** Infrastructure only — revisit once 3+ months of snapshot history exist.
```

- [ ] **Step 2: Add a matching bullet to PROJECT-SUMMARY.md**

Insert after the `## Notes` section header's existing bullets (append as a new bullet at the end of that list):

```markdown
- **2026-07-08:** Added monthly snapshot infrastructure (`nb_Snapshot_MDInvoices_NoFreight` → `Fact_MDInvoices_NoFreight_Snapshot`, `Pipeline_Monthly_MDInvoices_Snapshot`) so the open MD freight backlog has point-in-time history for future trend analysis. No trend page yet — see CLAUDE.md "Monthly Snapshot" section.
```

- [ ] **Step 3: Commit**

```bash
git add "projects/md invoices with no freight - report/CLAUDE.md" "projects/md invoices with no freight - report/PROJECT-SUMMARY.md"
git commit -m "Document MD Invoices monthly snapshot infrastructure"
```

---

### Task 6: Final repo review

- [ ] **Step 1: Confirm all Phase 1 files are committed**

```bash
git status
git log --oneline -6
```

Expected: working tree clean (or only unrelated pre-existing changes from before this plan started), and the last 5 commits are the ones from Tasks 1–5.

- [ ] **Step 2: Push**

```bash
git push
```

(Confirm with Brian before pushing if this wasn't already agreed — pushing to `dev` on `data-projects` is normal per this repo's workflow, but always worth a heads-up.)

---

## Phase 2 — Manual Fabric & Desktop Steps (Brian)

**Progress as of 2026-07-08:** Task 7 complete (notebook + pipeline confirmed working in Fabric). Task 8 Steps 1-3 complete — Desktop refreshes the new table cleanly after the casing fix. Remaining: Step 4 (calculated-column spot-check), Step 4a (SnapshotDate relationship match verification), Step 5-6 (publish to RP-Dev, then Sandbox/production). Trend page/visuals deliberately deferred until 3+ months of snapshot history accumulate (per spec).

**These cannot be executed by a coding agent.** They require the Fabric portal (browser) and Power BI Desktop (GUI), neither of which this repo's tooling can drive. Complete Phase 1 first — you'll paste content from the files it created.

### Task 7: Create and run the Fabric notebook, then create the pipeline

- [X] **Step 1:** In the Fabric portal, open `LH_Master_Data`. Create a new Notebook named `nb_Snapshot_MDInvoices_NoFreight`.
- [X] **Step 2:** Paste each of the four cells from `projects/md invoices with no freight - report/queries/notebooks/nb_Snapshot_MDInvoices_NoFreight.py` (Task 1's output) into four separate code cells, in order. Leave Cell 4 commented out for now.
- [X] **Step 3:** Run the notebook manually (Run All). Confirm Cell 3 prints `SUCCESS: <N> rows written to Fact_MDInvoices_NoFreight_Snapshot for <date>`. This creates the Delta table and writes the first snapshot.
- [ ] **Step 4:** Uncomment Cell 4 and run it standalone to confirm the summary query returns one row for this month with sensible totals.
- [X] **Step 5:** Create a new Pipeline named `Pipeline_Monthly_MDInvoices_Snapshot`. Add a single Notebook activity pointing at `nb_Snapshot_MDInvoices_NoFreight`. Set the schedule: monthly, 1st of the month, 5:30 AM CST (same pattern as `Pipeline_Monthly_Open_Orders_Snapshot` — copy its schedule config if easiest).
- [X] **Step 6:** Save and confirm the pipeline shows the correct next-run date in the Fabric portal.

### Task 8: Wire up the semantic model in Desktop

- [X] **Step 1:** Open `MD Invoices With No Freight.pbip` in Power BI Desktop. **Fully close and reopen Desktop first** if it was already open with this file — brand-new TMDL table files don't hot-reload.
- [X] **Step 2:** In Model view, confirm `Fact_MDInvoices_NoFreight_Snapshot` appears with all 26 columns (23 base + `SnapshotDate` + 3 calculated) and the two new relationships to `dim_BranchLocation` and `dim_DateTable`.
- [X] **Step 3:** Refresh just this table (right-click → Refresh, or refresh the whole model). Confirm it loads without error and row count matches what the notebook reported. **Hit a casing mismatch on first attempt** ("the key didn't match any rows in the table") — `saveAsTable()` lowercased the Delta table name in the Hive metastore; fixed by updating the partition's `Item="..."` to `fact_mdinvoices_nofreight_snapshot` (commit `e8fa269f`). Refresh succeeded after that fix.
- [ ] **Step 4:** Spot-check the calculated columns: add `Fact_MDInvoices_NoFreight_Snapshot` to a temporary table visual with `FileNumber`, `SnapshotDate`, `TotalLineWeight`, `TotalFreightCharged`, `MissedFreightAmount`, `PctFreightDifference`, `FreightBucket`. Confirm `FreightBucket` values look sane (No Freight / Partial Freight / Adequate Freight) and `MissedFreightAmount` isn't blending across snapshot dates for repeat order numbers. Delete the temporary visual when done.
- [ ] **Step 4a:** Verify the `SnapshotDate` → `dim_DateTable.Date` relationship actually matches rows (not just that the calculated columns look right). Add a visual grouping `Fact_MDInvoices_NoFreight_Snapshot[SnapshotDate]` by `dim_DateTable[Date]` — or check Model view's relationship diagnostics — and confirm no blank/unmatched rows on either side. Unlike `OrderDate` (which gets an explicit `DateTime.Date` truncation step in the partition), `SnapshotDate` relies on the notebook's `.cast("date")` already producing a clean date with no time component; this step confirms that assumption held once real data exists, since it was never verified against a live table during Phase 1's repo-only work.
- [ ] **Step 5:** Publish to `RP - Dev` to verify privately, per this repo's standard deployment workflow (Desktop → RP-Dev → Sandbox/production).
- [ ] **Step 6:** Once satisfied, publish to `RP - Parts Reports` (production) and commit via Fabric Git Integration, following the same `dev → main` PR flow as any other change to this report.

---

## Explicitly Deferred (Not In This Plan)

- Trend page / visuals on `Fact_MDInvoices_NoFreight_Snapshot` — wait for 3+ months of history
- New measures against the snapshot table — none needed until the trend page is built
- `FreightBucket` → `dim_FreightPerformanceGroup` relationship — add only if a future trend page needs tab-style bucket filtering
