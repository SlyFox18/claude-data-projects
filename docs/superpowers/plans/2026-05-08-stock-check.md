# Stock Check Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Stock Check report (2-page Power BI report tracking internal work orders on stock equipment) and save all artifacts to the repository.

**Architecture:** One new Fabric Dataflow Gen2 (`df_Fact_InternalWorkOrders`) joins six existing Lakehouse raw tables and writes `Fact_InternalWorkOrders` to the Lakehouse. A Power BI semantic model imports that fact table plus existing dimensions. The report has two pages: Open Stock Checks (active WOs) and Historical Log (all 2026 WOs with expandable job code detail). Power Automate email is out of scope for this plan.

**Tech Stack:** Fabric Dataflow Gen2 (Power Query M), Power BI Desktop (PBIP/TMDL), pbi-cli for TMDL export, git for versioning.

---

## File Map

| File | Action | Purpose |
|---|---|---|
| `projects/stock-check - report/queries/Fact_InternalWorkOrders.pq` | Create | Working copy of the fact table Power Query |
| `.claude/queries/facts/Fact_InternalWorkOrders.pq` | Create | Query library reference copy |
| `projects/stock-check - report/reports/Stock Check.SemanticModel/` | Create | TMDL exported from Desktop |
| `projects/stock-check - report/reports/Stock Check.Report/` | Create | Report PBIR exported from Desktop |

---

## Task 1: Create Project Folder Structure

**Files:**
- Create: `projects/stock-check - report/queries/` (directory)
- Create: `projects/stock-check - report/reports/` (directory)

- [ ] **Step 1: Create the folder structure**

```powershell
New-Item -ItemType Directory -Path "projects\stock-check - report\queries" -Force
New-Item -ItemType Directory -Path "projects\stock-check - report\reports" -Force
```

- [ ] **Step 2: Commit the empty structure**

```bash
git add "projects/stock-check - report/"
git commit -m "scaffold: create stock-check report project folder"
```

---

## Task 2: Build the Fact Table Dataflow in Fabric

Create a new Dataflow Gen2 in **LH_Master_Data → Dataflows → 04 - Fact** named `df_Fact_InternalWorkOrders`. The output table is `Fact_InternalWorkOrders`.

**Files:**
- Create: `projects/stock-check - report/queries/Fact_InternalWorkOrders.pq`

- [ ] **Step 1: Open Fabric, navigate to LH_Master_Data → Dataflows → 04 - Fact, create new Dataflow Gen2 named `df_Fact_InternalWorkOrders`**

- [ ] **Step 2: In the dataflow editor, open Advanced Editor and paste this complete query**

```powerquery
/*
============================================================================
Query: Fact_InternalWorkOrders
Dataflow: df_Fact_InternalWorkOrders
Location: LH_Master_Data → Dataflows → 04 - Fact
============================================================================

PURPOSE: Internal work orders (stock checks) with job code detail.
An "internal" WO is any work order where wkrodesc.JobType = "i" —
these represent service work performed on unsold stock equipment.

GRAIN: One row per WorkOrder × JobCode
DATE SCOPE: CreatedOn >= 2026-01-01 (adjust start date in STEP 2 as needed)

SOURCE TABLES (all Lakehouse, no ODBC):
  wkrodesc   — job codes, base table (LINE_NO = 1 pre-filtered in raw table)
  WKROFILE   — WO header: dates, status, equipment identifiers
  wkothsub   — estimated hours, standard labor flag, invoice reference
  wkmechwk   — technician labor (aggregated to WO × JobCode before join)
  vhstock    — Make/Model for stock (unsold) equipment
  WKVEHFL    — Make/Model for registered/fleet equipment (fallback)

OUTPUT: ~7,000–12,000 rows (Internal WOs, 2026 scope)
REFRESH: Full daily, Phase 4
============================================================================
*/

let
    // =========================================================================
    // LAKEHOUSE CONNECTION
    // Workspace: LH_Master_Data  (b48cdb35-7ce3-46de-96df-d70db77649cb)
    // Lakehouse: LH_Master_Data  (3e74497b-8c51-4a1a-91a1-888c59118f48)
    // =========================================================================
    LH_Source    = Lakehouse.Contents([HierarchicalNavigation = null, EnableVorder = true, OutputMetadataRefresh = true]),
    LH_Workspace = LH_Source{[workspaceId = "b48cdb35-7ce3-46de-96df-d70db77649cb"]}[Data],
    LH_Lakehouse = LH_Workspace{[lakehouseId = "3e74497b-8c51-4a1a-91a1-888c59118f48"]}[Data],

    // =========================================================================
    // STEP 1: wkrodesc — Internal job codes only
    // The raw Lakehouse table already has LINE_NO = 1 applied (one row per
    // job code per WO). Filter to JobType = "i" for Internal WOs only.
    // =========================================================================
    wkrodesc_Raw  = LH_Lakehouse{[Id = "wkrodesc", ItemKind = "Table"]}[Data],
    wkrodesc_Cols = Table.SelectColumns(wkrodesc_Raw,
                        {"Branch", "WorkOrder", "JobCode", "JobType", "JobValue"}),
    InternalJobs  = Table.SelectRows(wkrodesc_Cols, each [JobType] = "i"),
    InternalJobs_Typed = Table.TransformColumnTypes(InternalJobs, {
                        {"Branch",   type text},
                        {"WorkOrder", type text},
                        {"JobCode",  type text},
                        {"JobType",  type text},
                        {"JobValue", type number}
                    }),

    // =========================================================================
    // STEP 2: WKROFILE — WO header, filtered to 2026-01-01 forward
    // IsClosed is text "Y" / "N" (not boolean) — use "N" for open WOs in DAX.
    // =========================================================================
    WKROFILE_Raw  = LH_Lakehouse{[Id = "WKROFILE", ItemKind = "Table"]}[Data],
    WKROFILE_Cols = Table.SelectColumns(WKROFILE_Raw,
                        {"Branch", "WorkOrder", "StockNumber", "Registration",
                         "CreatedOn", "ClosedDate", "ProgressStatus", "IsClosed"}),
    WKROFILE_2026 = Table.SelectRows(WKROFILE_Cols,
                        each [CreatedOn] <> null and [CreatedOn] >= #date(2026, 1, 1)),
    WKROFILE_Typed = Table.TransformColumnTypes(WKROFILE_2026, {
                        {"Branch",         type text},
                        {"WorkOrder",      type text},
                        {"StockNumber",    type text},
                        {"Registration",   type text},
                        {"CreatedOn",      type date},
                        {"ClosedDate",     type date},
                        {"ProgressStatus", type text},
                        {"IsClosed",       type text}
                    }),

    // =========================================================================
    // STEP 3: wkothsub — estimated hours and operational flags per job
    // =========================================================================
    wkothsub_Raw  = LH_Lakehouse{[Id = "wkothsub", ItemKind = "Table"]}[Data],
    wkothsub_Cols = Table.SelectColumns(wkothsub_Raw,
                        {"Branch", "WorkOrder", "JobCode", "JobType",
                         "EstHours", "IsStandardLabor", "IsNonRevenue", "InvoiceNumber"}),
    wkothsub_Typed = Table.TransformColumnTypes(wkothsub_Cols, {
                        {"Branch",          type text},
                        {"WorkOrder",       type text},
                        {"JobCode",         type text},
                        {"JobType",         type text},
                        {"EstHours",        type number},
                        {"IsStandardLabor", type text},
                        {"IsNonRevenue",    type text},
                        {"InvoiceNumber",   type text}
                    }),

    // =========================================================================
    // STEP 4: wkmechwk — aggregate actual and invoiced hours to WO × JobCode grain
    // wkmechwk has one row per technician per day per job — sum before joining.
    // =========================================================================
    wkmechwk_Raw  = LH_Lakehouse{[Id = "wkmechwk", ItemKind = "Table"]}[Data],
    wkmechwk_Cols = Table.SelectColumns(wkmechwk_Raw,
                        {"Branch", "WorkOrder", "JobCode", "JobType",
                         "HoursWorked", "InvoiceHours"}),
    wkmechwk_Typed = Table.TransformColumnTypes(wkmechwk_Cols, {
                        {"Branch",       type text},
                        {"WorkOrder",    type text},
                        {"JobCode",      type text},
                        {"JobType",      type text},
                        {"HoursWorked",  type number},
                        {"InvoiceHours", type number}
                    }),
    wkmechwk_Agg  = Table.Group(wkmechwk_Typed,
                        {"Branch", "WorkOrder", "JobCode", "JobType"},
                        {
                            {"HoursWorked",  each List.Sum(List.RemoveNulls([HoursWorked])),  type number},
                            {"InvoiceHours", each List.Sum(List.RemoveNulls([InvoiceHours])), type number}
                        }),

    // =========================================================================
    // STEP 5: vhstock — Make/Model for stock (unsold) equipment
    // Full-extract table — all stock units including unsold are present.
    // =========================================================================
    vhstock_Raw     = LH_Lakehouse{[Id = "vhstock", ItemKind = "Table"]}[Data],
    vhstock_Cols    = Table.SelectColumns(vhstock_Raw, {"StockNumber", "Make", "Model"}),
    vhstock_Renamed = Table.RenameColumns(vhstock_Cols,
                        {{"Make", "StockMake"}, {"Model", "StockModel"}}),

    // =========================================================================
    // STEP 6: WKVEHFL — Make/Model for registered/fleet vehicles (fallback)
    // Used when WKROFILE.Registration is populated and StockNumber is null.
    // =========================================================================
    WKVEHFL_Raw     = LH_Lakehouse{[Id = "WKVEHFL", ItemKind = "Table"]}[Data],
    WKVEHFL_Cols    = Table.SelectColumns(WKVEHFL_Raw, {"Registration", "Make", "Model"}),
    WKVEHFL_Renamed = Table.RenameColumns(WKVEHFL_Cols,
                        {{"Make", "RegMake"}, {"Model", "RegModel"}}),

    // =========================================================================
    // STEP 7: Join InternalJobs → WKROFILE (INNER — only WOs in scope)
    // =========================================================================
    Join_WO       = Table.NestedJoin(
                        InternalJobs_Typed, {"Branch", "WorkOrder"},
                        WKROFILE_Typed,     {"Branch", "WorkOrder"},
                        "WOHeader", JoinKind.Inner),
    Expand_WO     = Table.ExpandTableColumn(Join_WO, "WOHeader",
                        {"StockNumber", "Registration", "CreatedOn",
                         "ClosedDate", "ProgressStatus", "IsClosed"}),

    // =========================================================================
    // STEP 8: Join → wkothsub (LEFT — job may not yet have an invoice)
    // =========================================================================
    Join_Sub      = Table.NestedJoin(
                        Expand_WO,        {"Branch", "WorkOrder", "JobCode", "JobType"},
                        wkothsub_Typed,   {"Branch", "WorkOrder", "JobCode", "JobType"},
                        "SubInfo", JoinKind.Left),
    Expand_Sub    = Table.ExpandTableColumn(Join_Sub, "SubInfo",
                        {"EstHours", "IsStandardLabor", "IsNonRevenue", "InvoiceNumber"}),

    // =========================================================================
    // STEP 9: Join → wkmechwk aggregated hours (LEFT — WO may have no labor yet)
    // =========================================================================
    Join_Hours    = Table.NestedJoin(
                        Expand_Sub,       {"Branch", "WorkOrder", "JobCode", "JobType"},
                        wkmechwk_Agg,     {"Branch", "WorkOrder", "JobCode", "JobType"},
                        "HourInfo", JoinKind.Left),
    Expand_Hours  = Table.ExpandTableColumn(Join_Hours, "HourInfo",
                        {"HoursWorked", "InvoiceHours"}),

    // =========================================================================
    // STEP 10: Join → vhstock for stock equipment Make/Model (LEFT)
    // =========================================================================
    Join_Stock    = Table.NestedJoin(
                        Expand_Hours, {"StockNumber"},
                        vhstock_Renamed, {"StockNumber"},
                        "StockEq", JoinKind.Left),
    Expand_Stock  = Table.ExpandTableColumn(Join_Stock, "StockEq",
                        {"StockMake", "StockModel"}),

    // =========================================================================
    // STEP 11: Join → WKVEHFL for registered vehicle Make/Model (LEFT fallback)
    // =========================================================================
    Join_Veh      = Table.NestedJoin(
                        Expand_Stock, {"Registration"},
                        WKVEHFL_Renamed, {"Registration"},
                        "RegEq", JoinKind.Left),
    Expand_Veh    = Table.ExpandTableColumn(Join_Veh, "RegEq",
                        {"RegMake", "RegModel"}),

    // =========================================================================
    // STEP 12: Resolve Make/Model — prefer vhstock, fall back to WKVEHFL
    // =========================================================================
    With_Make     = Table.AddColumn(Expand_Veh, "Make",
                        each if [StockMake] <> null and [StockMake] <> ""
                             then [StockMake] else [RegMake],
                        type text),
    With_Model    = Table.AddColumn(With_Make, "Model",
                        each if [StockModel] <> null and [StockModel] <> ""
                             then [StockModel] else [RegModel],
                        type text),

    // =========================================================================
    // STEP 13: Select final columns and apply types
    // =========================================================================
    Selected      = Table.SelectColumns(With_Model, {
                        "Branch", "WorkOrder", "JobCode", "JobType", "JobValue",
                        "CreatedOn", "ClosedDate", "ProgressStatus", "IsClosed",
                        "StockNumber", "Registration", "Make", "Model",
                        "EstHours", "IsStandardLabor", "IsNonRevenue", "InvoiceNumber",
                        "HoursWorked", "InvoiceHours"
                    }),
    Final         = Table.TransformColumnTypes(Selected, {
                        {"Branch",          type text},
                        {"WorkOrder",       type text},
                        {"JobCode",         type text},
                        {"JobType",         type text},
                        {"JobValue",        type number},
                        {"CreatedOn",       type date},
                        {"ClosedDate",      type date},
                        {"ProgressStatus",  type text},
                        {"IsClosed",        type text},
                        {"StockNumber",     type text},
                        {"Registration",    type text},
                        {"Make",            type text},
                        {"Model",           type text},
                        {"EstHours",        type number},
                        {"IsStandardLabor", type text},
                        {"IsNonRevenue",    type text},
                        {"InvoiceNumber",   type text},
                        {"HoursWorked",     type number},
                        {"InvoiceHours",    type number}
                    })
in
    Final
```

- [ ] **Step 3: Configure the dataflow output — set destination table to `Fact_InternalWorkOrders` in LH_Master_Data Lakehouse, Update method: Replace**

- [ ] **Step 4: Save and run the dataflow. Wait for completion.**

- [ ] **Step 5: Verify row count and spot-check known values**

In the Fabric Lakehouse SQL analytics endpoint, run:

```sql
-- Row count sanity check (expect 5,000–15,000 rows for 2026 YTD)
SELECT COUNT(*) AS TotalRows FROM dbo.Fact_InternalWorkOrders;

-- All rows should be Internal type
SELECT DISTINCT JobType FROM dbo.Fact_InternalWorkOrders;
-- Expected: single row with value 'i'

-- Spot-check: WO 689570 (Branch 11, 5/5/2026 from source report)
SELECT * FROM dbo.Fact_InternalWorkOrders
WHERE WorkOrder = '689570'
ORDER BY JobCode;
-- Expected: multiple rows (one per job code), CreatedOn = 2026-05-05, Branch = '11'

-- Confirm IsClosed values
SELECT IsClosed, COUNT(*) AS WOCount
FROM dbo.Fact_InternalWorkOrders
GROUP BY IsClosed;
-- Expected: rows for 'Y' (closed) and 'N' (open) — no nulls

-- Confirm Make/Model populated for stock units
SELECT TOP 20 WorkOrder, StockNumber, Make, Model
FROM dbo.Fact_InternalWorkOrders
WHERE StockNumber IS NOT NULL
ORDER BY CreatedOn DESC;
-- Expected: Make and Model should not be blank for units with a StockNumber
```

- [ ] **Step 6: If Make/Model columns are blank for stock units despite a populated StockNumber, the vhstock join key may differ. Check the actual column name:**

```sql
SELECT TOP 5 * FROM dbo.vhstock;
-- Confirm the stock number column name matches 'StockNumber'
-- If it's different (e.g., 'No', 'StockNo'), update STEP 5 in the query:
-- vhstock_Cols = Table.SelectColumns(vhstock_Raw, {"ActualKeyName", "Make", "Model"}),
-- vhstock_Renamed = Table.RenameColumns(vhstock_Cols,
--     {{"ActualKeyName", "StockNumber"}, {"Make", "StockMake"}, {"Model", "StockModel"}}),
```

---

## Task 3: Save Query to Library and Commit

**Files:**
- Create: `projects/stock-check - report/queries/Fact_InternalWorkOrders.pq`
- Create: `.claude/queries/facts/Fact_InternalWorkOrders.pq`

- [ ] **Step 1: Save the working query (same content as Task 2 Step 2) to the project folder**

Save the full query text to `projects/stock-check - report/queries/Fact_InternalWorkOrders.pq`. This is the identical content from Task 2.

- [ ] **Step 2: Copy to the shared query library**

Copy the same file to `.claude/queries/facts/Fact_InternalWorkOrders.pq`.

- [ ] **Step 3: Commit**

```bash
git add "projects/stock-check - report/queries/Fact_InternalWorkOrders.pq"
git add ".claude/queries/facts/Fact_InternalWorkOrders.pq"
git commit -m "feat: add Fact_InternalWorkOrders power query"
```

---

## Task 4: Build Semantic Model in Power BI Desktop

Open Power BI Desktop, create a new PBIP file named `Stock Check` in `projects/stock-check - report/reports/`.

**Files:**
- Create: `projects/stock-check - report/reports/Stock Check.SemanticModel/` (via Desktop export)

- [ ] **Step 1: In Power BI Desktop → New → create blank report. Save as PBIP to `projects/stock-check - report/reports/Stock Check.pbip`**

- [ ] **Step 2: Connect to the Fact_InternalWorkOrders Lakehouse table**

Home → Get Data → More → Microsoft Fabric → Lakehouse (or use SQL Server connector with the Fabric SQL endpoint). Import `Fact_InternalWorkOrders`.

SQL endpoint: `xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com`  
Database: `LH_Master_Data`  
Table: `dbo.Fact_InternalWorkOrders`

- [ ] **Step 3: Import shared dimension tables from the same SQL endpoint**

Import: `dbo.dim_BranchLocation`, `dbo.dim_DateTable`, `dbo.Data Refresh`

- [ ] **Step 4: Create relationships**

In Model view, create:
- `Fact_InternalWorkOrders[Branch]` → `dim_BranchLocation[BranchID]` (Many to One, Single)
- `Fact_InternalWorkOrders[CreatedOn]` → `dim_DateTable[Date]` (Many to One, Single)

- [ ] **Step 5: Verify relationships work — in Report view, drag Branch and a count of WorkOrder into a table visual. Confirm branch names appear (not just IDs).**

---

## Task 5: Create DAX Measures

Create a new table `_Measures` (Enter Data → empty table, delete the default column, rename to `_Measures`). Add all measures to this table.

**Files:**
- Modify: `Stock Check.SemanticModel/definition/tables/_Measures.tmdl` (via Desktop, exported after)

- [ ] **Step 1: Add core count measures**

```dax
Total WOs = DISTINCTCOUNT(Fact_InternalWorkOrders[WorkOrder])
```

```dax
Open WOs = 
CALCULATE(
    DISTINCTCOUNT(Fact_InternalWorkOrders[WorkOrder]),
    Fact_InternalWorkOrders[IsClosed] = "N"
)
```

```dax
Branches with Open WOs = 
CALCULATE(
    DISTINCTCOUNT(Fact_InternalWorkOrders[Branch]),
    Fact_InternalWorkOrders[IsClosed] = "N"
)
```

```dax
Active Branches = DISTINCTCOUNT(Fact_InternalWorkOrders[Branch])
```

- [ ] **Step 2: Add days-based measures**

```dax
Days Open = 
VAR _Created = MIN(Fact_InternalWorkOrders[CreatedOn])
RETURN
    IF(
        HASONEVALUE(Fact_InternalWorkOrders[WorkOrder]),
        TODAY() - _Created,
        BLANK()
    )
```

```dax
Days Open or to Close = 
VAR _IsClosed  = MAX(Fact_InternalWorkOrders[IsClosed])
VAR _Created   = MIN(Fact_InternalWorkOrders[CreatedOn])
VAR _Closed    = MAX(Fact_InternalWorkOrders[ClosedDate])
RETURN
    IF(_IsClosed = "N",
        TODAY() - _Created,
        IF(NOT ISBLANK(_Closed), _Closed - _Created, BLANK())
    )
```

```dax
Avg Days Open = 
AVERAGEX(
    FILTER(
        VALUES(Fact_InternalWorkOrders[WorkOrder]),
        CALCULATE(MAX(Fact_InternalWorkOrders[IsClosed])) = "N"
    ),
    TODAY() - CALCULATE(MIN(Fact_InternalWorkOrders[CreatedOn]))
)
```

```dax
Over 14 Days = 
COUNTX(
    FILTER(
        VALUES(Fact_InternalWorkOrders[WorkOrder]),
        CALCULATE(MAX(Fact_InternalWorkOrders[IsClosed])) = "N"
            && (TODAY() - CALCULATE(MIN(Fact_InternalWorkOrders[CreatedOn]))) > 14
    ),
    Fact_InternalWorkOrders[WorkOrder]
)
```

```dax
Avg Days to Close = 
AVERAGEX(
    FILTER(
        SUMMARIZE(
            FILTER(Fact_InternalWorkOrders, Fact_InternalWorkOrders[IsClosed] = "Y"),
            Fact_InternalWorkOrders[WorkOrder],
            "CreatedOn",  MIN(Fact_InternalWorkOrders[CreatedOn]),
            "ClosedDate", MAX(Fact_InternalWorkOrders[ClosedDate])
        ),
        NOT ISBLANK([ClosedDate])
    ),
    [ClosedDate] - [CreatedOn]
)
```

- [ ] **Step 3: Add hours measures**

```dax
Hrs Worked = SUM(Fact_InternalWorkOrders[HoursWorked])
```

```dax
Hrs Invoiced = SUM(Fact_InternalWorkOrders[InvoiceHours])
```

```dax
Hrs Estimated = SUM(Fact_InternalWorkOrders[EstHours])
```

- [ ] **Step 4: Add status label and conditional formatting measures**

```dax
Progress Status Label = 
SWITCH(
    SELECTEDVALUE(Fact_InternalWorkOrders[ProgressStatus]),
    "bi",  "Booked-In",
    "va",  "Equipment Arrived",
    "wip", "Work Commenced",
    "wf",  "Work Finished",
    "iv",  "Equipment Invoiced",
    "ca",  "Customer Advised",
    "vp",  "Equipment Picked-up",
    SELECTEDVALUE(Fact_InternalWorkOrders[ProgressStatus])
)
```

```dax
Days Open Color = 
IF([Days Open] > 14, "#FCA5A5", BLANK())
```

- [ ] **Step 5: Add header banner measure**

```dax
Page Banner = 
VAR _Date = FORMAT(TODAY(), "MMM D, YYYY")
RETURN
"<div style='
    font-family: Segoe UI, Arial, sans-serif;
    height: 70px;
    padding: 12px 20px;
    background: linear-gradient(135deg, #1D3C4E 0%, #2E5266 50%, #3A7CA5 100%);
    border-radius: 8px;
    color: white;
    display: flex;
    align-items: center;
    justify-content: space-between;
    box-sizing: border-box;
'>
    <div style=''display:flex;align-items:center;gap:12px;''>
        <div style=''font-size:28px;''>🔧</div>
        <div>
            <div style=''font-size:11px;opacity:0.8;letter-spacing:1px;''>SERVICE REPORTS</div>
            <div style=''font-size:18px;font-weight:bold;''>Stock Checks — Internal Work Orders</div>
        </div>
    </div>
    <div style=''text-align:right;font-size:11px;opacity:0.8;''>
        <div>" & _Date & "</div>
    </div>
</div>"
```

- [ ] **Step 6: Verify key measures in the Data Model view**

In Power BI Desktop, open the DAX query window (View → DAX query view) and run:

```dax
EVALUATE
ROW(
    "Total WOs",          [Total WOs],
    "Open WOs",           [Open WOs],
    "Avg Days Open",      [Avg Days Open],
    "Over 14 Days",       [Over 14 Days],
    "Branches w/ Open",   [Branches with Open WOs]
)
```

Expected: Total WOs > 200, Open WOs > 0, both numbers are reasonable given the date scope.

---

## Task 6: Build Page 1 — Open Stock Checks

**Files:**
- Modify: `Stock Check.Report/` (via Desktop, exported after)

- [ ] **Step 1: Rename the default page to "Open Stock Checks"**

- [ ] **Step 2: Set a page-level filter — IsClosed = "N"**

In the Filters pane → Page level filters → drag `Fact_InternalWorkOrders[IsClosed]` → filter to value "N". This ensures all visuals on this page show only open WOs.

- [ ] **Step 3: Add the header banner**

Insert → HTML Content visual → set value to `[Page Banner]` measure. Position across the full width at the top. Height ~70px.

- [ ] **Step 4: Add 4 KPI card visuals**

Insert 4 New Card visuals in a row below the banner:

| Card | Measure | Label |
|---|---|---|
| 1 | `[Open WOs]` | "Open WOs" |
| 2 | `[Branches with Open WOs]` | "Branches" |
| 3 | `[Avg Days Open]` | "Avg Days Open" |
| 4 | `[Over 14 Days]` | "Over 14 Days" |

Format card 4: set title color to amber (#F59E0B) to flag urgency.

- [ ] **Step 5: Add the branch bar chart**

Insert → Bar chart (Clustered bar). Configure:
- Y-axis: `dim_BranchLocation[BranchName]`
- X-axis: `[Open WOs]`
- Sort: by `[Open WOs]` descending
- Title: "Open WOs by Branch"

Position to the left half of the lower canvas area.

- [ ] **Step 6: Add Equipment calculated column to the semantic model**

In Power BI Desktop → Table view → select `Fact_InternalWorkOrders` → New column:

```dax
Equipment = Fact_InternalWorkOrders[Make] & " " & Fact_InternalWorkOrders[Model]
```

- [ ] **Step 7: Add the open WOs table**

Insert → Table. Configure columns in this order:

| Column/Measure | Display Name |
|---|---|
| `Fact_InternalWorkOrders[WorkOrder]` | WO # |
| `dim_BranchLocation[BranchName]` | Branch |
| `Fact_InternalWorkOrders[Equipment]` | Make / Model |
| `Fact_InternalWorkOrders[StockNumber]` | Stock # |
| `Fact_InternalWorkOrders[CreatedOn]` | Date In |
| `[Days Open]` | Days Open |
| `[Progress Status Label]` | Status |

Sort table by `[Days Open]` descending (longest open at top).

- [ ] **Step 8: Apply conditional formatting to Days Open column**

Select the table → Format → Conditional formatting → Days Open → Background color → Rules:
- If value > 14 → background color `#FCA5A5` (light red)
- Else → no color

- [ ] **Step 9: Add Branch and Status slicers**

Insert two Slicer visuals:
- Slicer 1: `dim_BranchLocation[BranchName]` — style: Dropdown
- Slicer 2: `Fact_InternalWorkOrders[ProgressStatus]` — use `[Progress Status Label]` or the raw field — style: Dropdown

Position slicers in the top-right area.

- [ ] **Step 10: Verify Page 1**

Confirm that:
- KPI cards show non-zero values
- Bar chart shows branches with open WOs
- Table shows the open WOs with red highlighting on Days Open > 14
- Removing the page filter shows additional rows (confirming filter is working)

---

## Task 7: Build Page 2 — Historical Log

- [ ] **Step 1: Add a new report page named "Historical Log"**

Right-click the page tab → Add page → rename to "Historical Log". No page-level filter — this page shows all WOs.

- [ ] **Step 2: Add the header banner**

Same `[Page Banner]` measure in an HTML Content visual across the top.

- [ ] **Step 3: Add slicers row**

Insert 4 slicers across a row below the banner:

| Slicer | Field | Style |
|---|---|---|
| Date Range | `dim_DateTable[Date]` | Between (date range picker) |
| Branch | `dim_BranchLocation[BranchName]` | Dropdown |
| Status | `Fact_InternalWorkOrders[ProgressStatus]` | Dropdown |
| WO Search | `Fact_InternalWorkOrders[WorkOrder]` | Dropdown (or Search slicer type) |

Set the Date Range slicer default to show 2026-01-01 through today.

- [ ] **Step 4: Add 4 KPI summary cards**

| Card | Measure | Label |
|---|---|---|
| 1 | `[Total WOs]` | "Total WOs" |
| 2 | `[Open WOs]` | "Still Open" |
| 3 | `[Avg Days to Close]` | "Avg Days to Close" |
| 4 | `[Active Branches]` | "Active Branches" |

- [ ] **Step 5: Add the expandable WO matrix**

Insert → Matrix visual. Configure:

- Rows: `Fact_InternalWorkOrders[WorkOrder]` (parent), then `Fact_InternalWorkOrders[JobCode]` (child)
- Values:

| Value | Display Name |
|---|---|
| `Fact_InternalWorkOrders[Make]` (first value, use Max aggregation) | Make |
| `Fact_InternalWorkOrders[StockNumber]` (Max) | Stock # |
| `Fact_InternalWorkOrders[CreatedOn]` (Min, formatted as date) | Date In |
| `Fact_InternalWorkOrders[ClosedDate]` (Max, formatted as date) | Date Closed |
| `[Days Open or to Close]` | Days |
| `[Hrs Worked]` | Hrs Wkd |
| `[Hrs Invoiced]` | Hrs Inv |
| `[Progress Status Label]` | Status |

Note: At the WO (parent) row level, the matrix will show aggregated values. At the JobCode (child) row level, it will show job-specific values. This is the standard Power BI matrix drill-down behavior.

- [ ] **Step 6: Configure the matrix**

- Turn off column subtotals (Format → Subtotals → Column subtotals → Off)
- Set Row subtotals to show at the WO level but not JobCode level
- Sort rows by `[CreatedOn]` descending (most recent WOs at top)
- Enable "Expand/collapse entire level" button in Format → Row headers

- [ ] **Step 7: Verify Page 2**

Confirm that:
- Total WOs card matches the total visible in the source system Job Code Time Report for the same date range
- Filtering by Branch 11 shows Branch 11 WOs only
- Expanding a WO row reveals its job codes
- Date range slicer filters correctly

---

## Task 8: Export TMDL, Commit, and Publish to Sandbox

**Files:**
- Create: `projects/stock-check - report/reports/Stock Check.SemanticModel/definition/` (all TMDL files)
- Create: `projects/stock-check - report/reports/Stock Check.Report/definition/` (all PBIR files)

- [ ] **Step 1: Export TMDL from the connected pbi-cli**

With Power BI Desktop open and the Stock Check model loaded, run:

```bash
# Connect to the running Desktop instance
pbi connect

# Export TMDL to the project folder
pbi database export-tmdl "projects/stock-check - report/reports/Stock Check.SemanticModel/definition"
```

- [ ] **Step 2: Verify TMDL export**

```bash
ls "projects/stock-check - report/reports/Stock Check.SemanticModel/definition/tables/"
```

Expected files: `Fact_InternalWorkOrders.tmdl`, `dim_BranchLocation.tmdl`, `dim_DateTable.tmdl`, `Data Refresh.tmdl`, `_Measures.tmdl`

- [ ] **Step 3: Verify no `//` comment lines exist in any .tmdl file (they cause parse errors)**

```powershell
Select-String -Path "projects\stock-check - report\reports\Stock Check.SemanticModel\**\*.tmdl" -Pattern "^\s*//" -Recurse
```

Expected: no matches. If any are found, open the file and remove those lines.

- [ ] **Step 4: Save the .pbip file in Desktop to ensure the Report definition is written to disk**

File → Save. The `Stock Check.Report/definition/` folder should now contain the report JSON files.

- [ ] **Step 5: Publish to RP-Sandbox for stakeholder validation**

In Power BI Desktop → Publish → select workspace "RP - Sandbox".

- [ ] **Step 6: Commit all files**

```bash
git add "projects/stock-check - report/"
git add ".claude/queries/facts/Fact_InternalWorkOrders.pq"
git commit -m "feat: stock check report — Page 1 Open WOs, Page 2 Historical Log

Fact_InternalWorkOrders dataflow joins WKROFILE + wkrodesc + wkothsub +
wkmechwk + vhstock + WKVEHFL. Filtered to Internal (JobType='i') WOs,
2026-01-01 scope. Report in RP-Sandbox for validation."
```

---

## Post-Build Validation Checklist

Before marking this plan complete, verify the following against the source system Job Code Time Report (filter to Job Type = Internal, date range 1/1/2026 to today):

- [ ] Total distinct WO count matches (or is within 5% — minor differences expected due to Lakehouse refresh timing)
- [ ] WO 689570 (Branch 11, 5/5/2026) appears on Page 1 with correct job codes visible on Page 2
- [ ] WO 682249 (Branch 11, 1/2/2026) appears on Page 2 with 126+ days open
- [ ] Make/Model column shows equipment names (not blank) for stock units
- [ ] Branches with Open WOs KPI is non-zero
- [ ] Page 1 shows only open WOs (status NOT "Equipment Picked-up" or "Equipment Invoiced")
- [ ] Page 2 expandable matrix shows job codes when a WO row is expanded

---

## Out of Scope (follow-on tasks)

- Power Automate daily email alert (separate task after report is validated in Sandbox)
- Pipeline integration (add `df_Fact_InternalWorkOrders` to Phase 4 after testing)
- Adding the report to Phase 5 semantic model refresh schedule
