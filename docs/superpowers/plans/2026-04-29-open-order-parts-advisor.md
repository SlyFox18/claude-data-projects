# Open Order Parts Advisor — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Power BI report that identifies recommended parts for open work/repair orders based on 3 years of historical job code → part frequency analysis, enabling the After Market Sales Manager and Corp Service Manager to call branches about missing parts before the order is invoiced.

**Architecture:** Three Dataflow Gen2 Lakehouse tables (Fact_JobCodePartFrequency, Fact_OpenOrders, Fact_OpenOrderParts) pre-compute historical frequencies and open order state. A DAX calculated table (Recommendations) cross-joins them at model refresh time to produce a flat, ranked recommendation list. Report has three pages: Branch Summary (landing) → Open Orders → RO Detail (drill-through).

**Tech Stack:** Fabric Dataflow Gen2 (Power Query M), Power BI Desktop (DAX), Fabric Lakehouse (Delta tables), ODBC `dsn=EquipRDB64` (SQL Anywhere source system)

**Spec:** `docs/superpowers/specs/2026-04-29-open-order-parts-advisor-design.md`

---

## File Structure

### data-projects (queries, docs — does NOT affect Fabric directly)
| Action | Path |
|---|---|
| Create | `projects/open-order-parts-advisor/README.md` |
| Create | `projects/open-order-parts-advisor/ARCHITECTURE.md` |
| Create | `.claude/queries/facts/Fact_JobCodePartFrequency.pq` |
| Create | `.claude/queries/facts/Fact_OpenOrders.pq` |
| Create | `.claude/queries/facts/Fact_OpenOrderParts.pq` *(conditional — Task 5)* |
| Update | `projects/refresh-pipeline/pipeline-schedule.md` |

### fabric-workspace-docs (Fabric Git Integration mirror — populated after publish + commit from Fabric UI)
Auto-created after publish and Fabric Git Integration commit:
- `RP-Dev.Workspace/Open Order Parts Advisor.SemanticModel/`
- `RP-Dev.Workspace/Open Order Parts Advisor.Report/`
- `LH_Master_Data.Workspace/` — new dataflow entries

---

## Task 1: Investigation — Source Table Discovery

**Files:** No files created. Investigation only.

- [ ] **Step 1: Find the open order parts table**

In a new Dataflow Gen2 in LH_Master_Data (do not save), add a Blank Query and paste:

```m
let
    Source = Odbc.Query("dsn=EquipRDB64",
        "SELECT table_name
         FROM sys.systable
         WHERE table_type = 'BASE'
         AND table_name LIKE 'wk%'
         ORDER BY table_name")
in
    Source
```

Run the preview. Look for candidates: `wkpart`, `wkpartfile`, `wkparts`, `wkprt`, or similar. Record the table name.

- [ ] **Step 2: Inspect candidate table columns**

Replace `wkpart` with the table name found above:

```m
let
    Source = Odbc.Query("dsn=EquipRDB64",
        "SELECT sc.column_name, sc.domain_name
         FROM sys.syscolumn sc
         JOIN sys.systable st ON sc.table_id = st.table_id
         WHERE st.table_name = 'wkpart'
         ORDER BY sc.column_id")
in
    Source
```

Identify: the work order number field, the part number field, and whether a branch field exists. Record exact column names — needed for Task 5.

- [ ] **Step 3: Check wkothsub for a job description column**

```m
let
    Source = Odbc.Query("dsn=EquipRDB64",
        "SELECT sc.column_name
         FROM sys.syscolumn sc
         JOIN sys.systable st ON sc.table_id = st.table_id
         WHERE st.table_name = 'wkothsub'
         ORDER BY sc.column_id")
in
    Source
```

Look for `JOB_DESC`, `JOB_DESCRIPTION`, or `JOB_NAME`. If found, note it — it can optionally be added to Fact_JobCodePartFrequency and Fact_OpenOrders.

- [ ] **Step 4: Check InTrans_Incremental date range in the Lakehouse**

In the Lakehouse analytics endpoint (Fabric → LH_Master_Data → SQL analytics endpoint → New query), run:

```sql
SELECT
    MIN(TransDatetime) AS OldestRecord,
    MAX(TransDatetime) AS NewestRecord,
    COUNT(*)           AS TotalRows
FROM InTrans_Incremental
```

Expected: If OldestRecord is 2023 or earlier, `Fact_JobCodePartFrequency` will have a full 3 years. If OldestRecord is 2024+, note this — v1 will have ~2 years of history. A backfill can be done later.

- [ ] **Step 5: Confirm open order status filter values**

```m
let
    Source = Odbc.Query("dsn=EquipRDB64",
        "SELECT ro_closed_ind, RO_STATUS, COUNT(*) AS cnt
         FROM WKROFILE
         GROUP BY ro_closed_ind, RO_STATUS
         ORDER BY cnt DESC")
in
    Source
```

Expected: `ro_closed_ind = 'N'` should be the largest group — these are open orders. Confirm this before Task 4.

- [ ] **Step 6: Record findings**

Write down in a comment block at the top of your first .pq file (Task 3):
- Open order parts table name and column names (or "not found")
- Whether wkothsub has a job description column
- Oldest InTrans_Incremental record date
- Confirmed open order filter: `ro_closed_ind = 'N'` (or the actual value found)

---

## Task 2: Project Scaffold

**Files:**
- Create: `projects/open-order-parts-advisor/README.md`
- Create: `projects/open-order-parts-advisor/ARCHITECTURE.md`

- [ ] **Step 1: Create README.md**

```markdown
# Open Order Parts Advisor

**Status:** In Development
**Workspace:** RP - Sandbox (testing) → RP - Service Reports (production)
**Spec:** [Design Spec](../../docs/superpowers/specs/2026-04-29-open-order-parts-advisor-design.md)

## Purpose

Surfaces recommended parts for open work orders based on 3 years of historical
job code → part frequency analysis. Helps the After Market Sales Manager and Corp
Service Manager identify parts that should be on an open order before it is invoiced.

## Report Pages

1. **Branch Summary** — scoreboard by branch: open ROs, total recommendations, est. $ opportunity
2. **Open Orders** — RO list sorted by estimated $ opportunity (drill-through to Page 3)
3. **RO Detail** — flat recommendation list for one RO, sorted by frequency %

## Data Tables

| Table | Grain | Source | Refresh |
|---|---|---|---|
| Fact_JobCodePartFrequency | JobCode × PartNumber | wkothsub + InTrans_Incremental | Full daily, Phase 4 |
| Fact_OpenOrders | WorkOrder × JobCode | WKROFILE + wkothsub | Full daily, Phase 4 |
| Fact_OpenOrderParts | WorkOrder × PartNumber | [TBD source table] | Full daily, Phase 4 |
| Recommendations | WorkOrder × JobCode × PartNumber | DAX calculated table | At model refresh |

## Query Library
- `.claude/queries/facts/Fact_JobCodePartFrequency.pq`
- `.claude/queries/facts/Fact_OpenOrders.pq`
- `.claude/queries/facts/Fact_OpenOrderParts.pq`

## Known Limitation (v1)
If the open order parts source table was not found during investigation, part suppression
is disabled. Recommendations may include parts already on the order. See ARCHITECTURE.md.
```

- [ ] **Step 2: Create ARCHITECTURE.md**

```markdown
# Open Order Parts Advisor — Architecture

## Critical Join Warning

**InTrans RONumber = Invoice Number (NOT work order number)**

`InTrans_Incremental.RONumber` (source column: `REF_NO`) is the INVOICE number,
not the work order number. Joining on work order number produces ~1% of correct
row count. Always join: `wkothsub.InvoiceNumber = InTrans_Incremental.RONumber`.

This is the same bug that was fixed in Fact_WorkOrderParts (Inspections report).

## Frequency Calculation Logic

For each job code that appears on invoiced work orders (last 3 years):
- TotalOrdersWithJobCode = DISTINCT work orders where this job code appeared
- TimesWithPart = DISTINCT work orders where this job code AND this part appeared together
- FrequencyPct = TimesWithPart / TotalOrdersWithJobCode

Frequencies are GLOBAL (all branches combined) for statistical reliability.

## Investigation Findings

*(Fill in after Task 1)*
- Open order parts table: [table name or "not found"]
- Job description column in wkothsub: [column name or "not present"]
- InTrans_Incremental oldest record: [date]
- Open order filter: [confirmed SQL WHERE clause]
```

- [ ] **Step 3: Commit scaffold**

```bash
git add projects/open-order-parts-advisor/
git commit -m "feat(open-order-parts-advisor): add project scaffold"
```

---

## Task 3: Build df_JobCodePartFrequency

**Files:**
- Create: `.claude/queries/facts/Fact_JobCodePartFrequency.pq`

- [ ] **Step 1: Validate source join volumes before building**

In a blank Dataflow Gen2 query (do not save), run this to confirm the join produces reasonable data:

```m
let
    ThreeYearsAgo = Date.AddYears(Date.From(DateTime.LocalNow()), -3),
    DateStr = "'" & Date.ToText(ThreeYearsAgo, "yyyy-MM-dd") & "'",
    SQL = "SELECT COUNT(DISTINCT JOB_CODE) AS UniqueJobCodes,
                  COUNT(DISTINCT RO_NUMBER) AS UniqueWorkOrders,
                  COUNT(*) AS TotalRows
           FROM wkothsub
           WHERE INVOICE_DATE >= " & DateStr & "
             AND INVOICE_NO IS NOT NULL
             AND INVOICE_NO <> ''",
    Source = Odbc.Query("dsn=EquipRDB64", SQL)
in
    Source
```

Expected: UniqueJobCodes in the dozens to hundreds, UniqueWorkOrders in the tens of thousands. If either is near zero, the filter or column names are wrong.

- [ ] **Step 2: Create the query file**

Create `.claude/queries/facts/Fact_JobCodePartFrequency.pq`:

```m
/*
============================================================================
Query: Fact_JobCodePartFrequency
Dataflow: df_JobCodePartFrequency
Location: LH_Master_Data → Dataflows → 04 - Fact
============================================================================

PURPOSE: Pre-computed historical frequency table for the Open Order Parts
Advisor. For each job code, what % of invoiced work orders also had each part?

GRAIN: One row per JobCode × PartNumber
SOURCE: wkothsub (job codes, invoiced WOs) joined to InTrans_Incremental
        (parts on those invoices) via InvoiceNumber = RONumber
FILTER: Invoiced orders only, last 3 years rolling. All branches combined.

OUTPUT COLUMNS:
  JobCode                   TEXT  — job code (e.g. 8R)
  PartNumber                TEXT  — part number
  TimesWithPart             INT   — distinct WOs where this job + part appeared
  TotalOrdersWithJobCode    INT   — distinct WOs where this job code appeared
  FrequencyPct              FLOAT — TimesWithPart / TotalOrdersWithJobCode

⚠️ CRITICAL JOIN: wkothsub.InvoiceNumber = InTrans_Incremental.RONumber
   RONumber in InTrans is the INVOICE number, not the work order number.
   Joining on work order number produces ~1% of the correct row count.

REFRESH: Full daily, Phase 4
NOTE: In Fabric Dataflow Gen2, replace the InTrans ODBC source below with
      a Lakehouse connector pointing to InTrans_Incremental in LH_Master_Data.
============================================================================
*/

let
    // =====================================================================
    // DATE RANGE — 3 YEARS ROLLING
    // =====================================================================
    ThreeYearsAgo = Date.AddYears(Date.From(DateTime.LocalNow()), -3),
    DateStr = "'" & Date.ToText(ThreeYearsAgo, "yyyy-MM-dd") & "'",

    // =====================================================================
    // STEP 1: INVOICED JOB CODES FROM wkothsub (3 YEARS)
    // Selects distinct Branch + WorkOrder + JobCode + InvoiceNumber rows
    // where the order has been invoiced in the last 3 years.
    // =====================================================================
    SQL_Jobs =
        "SELECT DISTINCT
             RO_BRANCH  AS Branch,
             RO_NUMBER  AS WorkOrder,
             JOB_CODE   AS JobCode,
             INVOICE_NO AS InvoiceNumber
         FROM wkothsub
         WHERE INVOICE_DATE >= " & DateStr & "
           AND INVOICE_NO IS NOT NULL
           AND INVOICE_NO <> ''",

    Jobs = Odbc.Query("dsn=EquipRDB64", SQL_Jobs),
    Jobs_Typed = Table.TransformColumnTypes(Jobs, {
        {"Branch",        type text},
        {"WorkOrder",     type text},
        {"JobCode",       type text},
        {"InvoiceNumber", type text}
    }),

    // =====================================================================
    // STEP 2: DENOMINATOR — TOTAL DISTINCT WORK ORDERS PER JOB CODE
    // Used as the divisor when calculating FrequencyPct.
    // =====================================================================
    TotalsByJobCode = Table.Group(
        Jobs_Typed,
        {"JobCode"},
        {{"TotalOrdersWithJobCode",
          each List.Count(List.Distinct([WorkOrder])),
          Int64.Type}}
    ),

    // =====================================================================
    // STEP 3: PARTS FROM InTrans_Incremental
    // In Fabric Dataflow Gen2: Get Data → Fabric Lakehouse → LH_Master_Data
    //   → Table: InTrans_Incremental → keep Branch, RONumber, PartNumber only.
    // Replace the ODBC query below with the Lakehouse connector in Fabric.
    // The Lakehouse column name is RONumber (source column REF_NO).
    // =====================================================================
    SQL_Parts =
        "SELECT DISTINCT
             BRANCH   AS Branch,
             REF_NO   AS InvoiceNumber,
             PART_NO  AS PartNumber
         FROM InTrans
         WHERE PART_NO IS NOT NULL
           AND PART_NO <> ''",

    Parts = Odbc.Query("dsn=EquipRDB64", SQL_Parts),
    Parts_Typed = Table.TransformColumnTypes(Parts, {
        {"Branch",        type text},
        {"InvoiceNumber", type text},
        {"PartNumber",    type text}
    }),

    // =====================================================================
    // STEP 4: JOIN JOBS TO PARTS VIA INVOICE NUMBER + BRANCH
    // ⚠️ JOIN KEY IS INVOICE NUMBER (InvoiceNumber = InvoiceNumber)
    //    Do NOT join on WorkOrder — that produces ~1% of correct rows.
    // =====================================================================
    Joined = Table.NestedJoin(
        Jobs_Typed,  {"InvoiceNumber", "Branch"},
        Parts_Typed, {"InvoiceNumber", "Branch"},
        "Parts",
        JoinKind.Inner
    ),
    Expanded = Table.ExpandTableColumn(Joined, "Parts", {"PartNumber"}),
    WithParts = Table.SelectRows(Expanded,
        each [PartNumber] <> null and [PartNumber] <> ""),

    // =====================================================================
    // STEP 5: NUMERATOR — TIMES EACH PART APPEARED WITH EACH JOB CODE
    // =====================================================================
    FrequencyBase = Table.Group(
        WithParts,
        {"JobCode", "PartNumber"},
        {{"TimesWithPart",
          each List.Count(List.Distinct([WorkOrder])),
          Int64.Type}}
    ),

    // =====================================================================
    // STEP 6: JOIN TOTALS AND CALCULATE FrequencyPct
    // =====================================================================
    WithTotals = Table.NestedJoin(
        FrequencyBase,   {"JobCode"},
        TotalsByJobCode, {"JobCode"},
        "Totals",
        JoinKind.Inner
    ),
    WithTotalsExpanded = Table.ExpandTableColumn(
        WithTotals, "Totals", {"TotalOrdersWithJobCode"}),

    WithFrequency = Table.AddColumn(
        WithTotalsExpanded,
        "FrequencyPct",
        each if [TotalOrdersWithJobCode] = 0 then 0
             else [TimesWithPart] / [TotalOrdersWithJobCode],
        type number),

    // =====================================================================
    // FINAL TYPES
    // =====================================================================
    Final = Table.TransformColumnTypes(WithFrequency, {
        {"JobCode",                type text},
        {"PartNumber",             type text},
        {"TimesWithPart",          Int64.Type},
        {"TotalOrdersWithJobCode", Int64.Type},
        {"FrequencyPct",           type number}
    })
in
    Final
```

- [ ] **Step 3: Create Dataflow Gen2 in Fabric**

1. Fabric → LH_Master_Data → New → Dataflow Gen2
2. Name: `df_JobCodePartFrequency`
3. Get Data → ODBC (dsn=EquipRDB64) → add wkothsub query (SQL from Step above)
4. Get Data → Fabric Lakehouse → LH_Master_Data → InTrans_Incremental table → keep only `Branch`, `RONumber`, `PartNumber` columns
5. Apply the M transformations from the .pq file (Steps 2–6)
6. Output destination → LH_Master_Data Lakehouse → table name: `Fact_JobCodePartFrequency` → replace if exists
7. Save and Run

- [ ] **Step 4: Validate output in Lakehouse analytics endpoint**

```sql
SELECT
    COUNT(*)                 AS TotalRows,
    COUNT(DISTINCT JobCode)  AS UniqueJobCodes,
    COUNT(DISTINCT PartNumber) AS UniquePartNumbers,
    MIN(FrequencyPct)        AS MinFreq,
    MAX(FrequencyPct)        AS MaxFreq,
    AVG(FrequencyPct)        AS AvgFreq
FROM Fact_JobCodePartFrequency
```

Expected: TotalRows in the thousands to tens of thousands. MaxFreq = 1.0. AvgFreq between 0.10–0.50. If TotalRows < 100, the invoice number join failed — verify column names.

- [ ] **Step 5: Spot-check a known job code**

Replace `'8R'` with a job code you know is common:

```sql
SELECT * FROM Fact_JobCodePartFrequency
WHERE JobCode = '8R'
ORDER BY FrequencyPct DESC
LIMIT 20
```

The top parts should make intuitive sense for that job type.

- [ ] **Step 6: Commit**

```bash
git add .claude/queries/facts/Fact_JobCodePartFrequency.pq
git commit -m "feat(open-order-parts-advisor): add Fact_JobCodePartFrequency dataflow query"
```

---

## Task 4: Build df_OpenOrders

**Files:**
- Create: `.claude/queries/facts/Fact_OpenOrders.pq`

- [ ] **Step 1: Confirm open order count from WKROFILE**

Using the `ro_closed_ind` value confirmed in Task 1 (expected `'N'`):

```m
let
    Source = Odbc.Query("dsn=EquipRDB64",
        "SELECT COUNT(DISTINCT RO_NUMBER) AS OpenOrders,
                COUNT(DISTINCT BRANCH) AS Branches
         FROM WKROFILE
         WHERE ro_closed_ind = 'N'")
in
    Source
```

Expected: OpenOrders in the hundreds. If zero, the status filter value is wrong — go back to Task 1 Step 5.

- [ ] **Step 2: Create the query file**

Create `.claude/queries/facts/Fact_OpenOrders.pq`:

```m
/*
============================================================================
Query: Fact_OpenOrders
Dataflow: df_OpenOrders
Location: LH_Master_Data → Dataflows → 04 - Fact
============================================================================

PURPOSE: All currently open (not-yet-invoiced) work orders with their job codes.
Combined with Fact_JobCodePartFrequency in the Recommendations DAX calculated
table to produce part recommendations.

GRAIN: One row per WorkOrder × JobCode
SOURCE: WKROFILE (open order filter) INNER JOIN wkothsub (job codes)
FILTER: ro_closed_ind = 'N' (open orders only)

NOTE: wkothsub has 2023+ scope via incremental refresh. Open orders older than
3 years without recent modifications may not have job codes visible here.
In practice this affects a negligible number of orders.

OUTPUT COLUMNS:
  WorkOrderNumber  TEXT  — work order / RO number
  BranchCode       TEXT  — branch identifier
  CustomerNumber   TEXT  — customer account (joins to dim_CustomerList)
  JobCode          TEXT  — job code on this open order
  OpenDate         DATE  — work order creation date

REFRESH: Full daily, Phase 4 — small dataset (hundreds to low thousands of rows)
============================================================================
*/

let
    // =====================================================================
    // STEP 1: OPEN WORK ORDERS FROM WKROFILE
    // Adjust the WHERE clause if Task 1 found a different status value.
    // =====================================================================
    SQL_OpenOrders =
        "SELECT
             BRANCH        AS BranchCode,
             RO_NUMBER     AS WorkOrderNumber,
             CHARGE_ACCT   AS CustomerNumber,
             Creation_Date AS OpenDate
         FROM WKROFILE
         WHERE ro_closed_ind = 'N'",

    OpenOrders = Odbc.Query("dsn=EquipRDB64", SQL_OpenOrders),
    OpenOrders_Typed = Table.TransformColumnTypes(OpenOrders, {
        {"BranchCode",      type text},
        {"WorkOrderNumber", type text},
        {"CustomerNumber",  type text},
        {"OpenDate",        type date}
    }),

    // =====================================================================
    // STEP 2: JOB CODES FROM wkothsub FOR OPEN ORDERS
    // Open orders have no invoice number yet (INVOICE_NO is null/empty).
    // =====================================================================
    SQL_Jobs =
        "SELECT
             RO_BRANCH AS BranchCode,
             RO_NUMBER AS WorkOrderNumber,
             JOB_CODE  AS JobCode
         FROM wkothsub
         WHERE INVOICE_NO IS NULL
            OR INVOICE_NO = ''",

    Jobs = Odbc.Query("dsn=EquipRDB64", SQL_Jobs),
    Jobs_Typed = Table.TransformColumnTypes(Jobs, {
        {"BranchCode",      type text},
        {"WorkOrderNumber", type text},
        {"JobCode",         type text}
    }),

    // =====================================================================
    // STEP 3: JOIN OPEN ORDERS TO JOB CODES
    // INNER JOIN — only include open orders that have at least one job code.
    // =====================================================================
    Joined = Table.NestedJoin(
        OpenOrders_Typed, {"WorkOrderNumber", "BranchCode"},
        Jobs_Typed,       {"WorkOrderNumber", "BranchCode"},
        "Jobs",
        JoinKind.Inner
    ),
    Expanded = Table.ExpandTableColumn(Joined, "Jobs", {"JobCode"}),
    WithJobCodes = Table.SelectRows(Expanded,
        each [JobCode] <> null and [JobCode] <> ""),

    // =====================================================================
    // FINAL TYPES
    // =====================================================================
    Final = Table.TransformColumnTypes(WithJobCodes, {
        {"WorkOrderNumber", type text},
        {"BranchCode",      type text},
        {"CustomerNumber",  type text},
        {"JobCode",         type text},
        {"OpenDate",        type date}
    })
in
    Final
```

- [ ] **Step 3: Create Dataflow Gen2 in Fabric**

1. Fabric → LH_Master_Data → New → Dataflow Gen2
2. Name: `df_OpenOrders`
3. Get Data → ODBC (dsn=EquipRDB64) → add WKROFILE query (SQL from Step 1 above)
4. Get Data → ODBC (dsn=EquipRDB64) → add wkothsub query (SQL from Step 2 above)
5. Apply the join transformation (Step 3 from .pq above)
6. Output destination → LH_Master_Data Lakehouse → table name: `Fact_OpenOrders` → replace if exists
7. Save and Run

- [ ] **Step 4: Validate output**

```sql
SELECT
    COUNT(*)                      AS TotalRows,
    COUNT(DISTINCT WorkOrderNumber) AS UniqueOpenOrders,
    COUNT(DISTINCT BranchCode)    AS UniqueBranches,
    COUNT(DISTINCT JobCode)       AS UniqueJobCodes,
    MIN(OpenDate)                 AS OldestOpenOrder,
    MAX(OpenDate)                 AS NewestOpenOrder
FROM Fact_OpenOrders
```

Expected: UniqueOpenOrders in the hundreds. UniqueBranches up to 15. OldestOpenOrder should not be more than ~2 years ago (very old open orders indicate data issues). NewestOpenOrder should be recent (today or yesterday).

- [ ] **Step 5: Commit**

```bash
git add .claude/queries/facts/Fact_OpenOrders.pq
git commit -m "feat(open-order-parts-advisor): add Fact_OpenOrders dataflow query"
```

---

## Task 5: Build df_OpenOrderParts (conditional on Task 1 finding the table)

**Files:**
- Create: `.claude/queries/facts/Fact_OpenOrderParts.pq` *(if table found)*
- Update: `projects/open-order-parts-advisor/README.md` *(if table not found — add fallback note)*

### If the source table WAS found in Task 1:

- [ ] **Step 1: Confirm the table has data for open orders**

Replace `wkpart`, `WO_NO`, `BRANCH`, `PART_NO` with the actual names from Task 1:

```m
let
    Source = Odbc.Query("dsn=EquipRDB64",
        "SELECT COUNT(*) AS TotalRows,
                COUNT(DISTINCT WO_NO) AS UniqueWorkOrders
         FROM wkpart
         WHERE PART_NO IS NOT NULL AND PART_NO <> ''")
in
    Source
```

Expected: UniqueWorkOrders should roughly match Fact_OpenOrders distinct WO count.

- [ ] **Step 2: Create the query file**

Create `.claude/queries/facts/Fact_OpenOrderParts.pq` — **replace column names with actuals from Task 1**:

```m
/*
============================================================================
Query: Fact_OpenOrderParts
Dataflow: df_OpenOrderParts
Location: LH_Master_Data → Dataflows → 04 - Fact
============================================================================

PURPOSE: Parts already committed to open (not-yet-invoiced) work orders.
Used in the Recommendations DAX calculated table to suppress parts that are
already on the order from appearing as recommendations.

GRAIN: One row per WorkOrder × PartNumber
SOURCE TABLE: [update with table name from Task 1 investigation]

⚠️ Column names below are placeholders — update from Task 1 findings:
   Table:  wkpart     → actual table name
   Column: WO_NO      → work order number column
   Column: BRANCH_COL → branch column
   Column: PART_NO    → part number column

REFRESH: Full daily, Phase 4
============================================================================
*/

let
    // =====================================================================
    // UPDATE COLUMN NAMES BASED ON Task 1 INVESTIGATION FINDINGS
    // =====================================================================
    SQL =
        "SELECT
             BRANCH_COL AS BranchCode,
             WO_NO      AS WorkOrderNumber,
             PART_NO    AS PartNumber
         FROM wkpart
         WHERE PART_NO IS NOT NULL
           AND PART_NO <> ''",

    Source = Odbc.Query("dsn=EquipRDB64", SQL),
    Typed = Table.TransformColumnTypes(Source, {
        {"BranchCode",      type text},
        {"WorkOrderNumber", type text},
        {"PartNumber",      type text}
    })
in
    Typed
```

- [ ] **Step 3: Create Dataflow Gen2 in Fabric**

1. New → Dataflow Gen2, name: `df_OpenOrderParts`
2. Get Data → ODBC (dsn=EquipRDB64) → apply SQL from .pq above
3. Output → LH_Master_Data → table: `Fact_OpenOrderParts` → replace if exists
4. Save and Run

- [ ] **Step 4: Validate output**

```sql
SELECT
    COUNT(*)                        AS TotalRows,
    COUNT(DISTINCT WorkOrderNumber) AS UniqueOpenOrders,
    COUNT(DISTINCT PartNumber)      AS UniquePartNumbers
FROM Fact_OpenOrderParts
```

Expected: UniqueOpenOrders close to Fact_OpenOrders distinct WO count. If zero, the source table is empty or filter is wrong.

- [ ] **Step 5: Commit**

```bash
git add .claude/queries/facts/Fact_OpenOrderParts.pq
git commit -m "feat(open-order-parts-advisor): add Fact_OpenOrderParts dataflow query"
```

### If the source table was NOT found in Task 1:

- [ ] **Step 1: Add fallback note to README.md and ARCHITECTURE.md**

In `projects/open-order-parts-advisor/README.md`, add a Known Limitations section:

```markdown
## v1 Limitation: Part Suppression Disabled

The source table for parts on open (not-yet-invoiced) orders was not identified
before the v1 build. Recommendations show ALL historical parts for each job code
regardless of whether they are already on the open order.

Managers should cross-check recommendations against the actual RO before calling.

**Resolution:** Once source table is identified, build `df_OpenOrderParts` and
update the `Recommendations` DAX table to use the suppression version (see ARCHITECTURE.md).
```

- [ ] **Step 2: Commit fallback documentation**

```bash
git add projects/open-order-parts-advisor/README.md
git commit -m "docs(open-order-parts-advisor): note v1 part suppression limitation"
```

---

## Task 6: Add Dataflows to Phase 4 Pipeline

**Files:**
- Update: `projects/refresh-pipeline/pipeline-schedule.md`

- [ ] **Step 1: Identify the Phase 4 pipeline in Fabric**

In LH_Master_Data, open the pipeline that runs Phase 4 facts. Reference `projects/refresh-pipeline/pipeline-schedule.md` to find the right pipeline name and which wave has capacity.

- [ ] **Step 2: Add new dataflows to Phase 4**

In the pipeline editor, add three new Dataflow activities:
- `df_JobCodePartFrequency` — add to the **last wave** of Phase 4 (it's the most compute-intensive; don't block other fact tables)
- `df_OpenOrders` — add alongside `df_JobCodePartFrequency` or in a new wave (it's fast)
- `df_OpenOrderParts` — add alongside `df_OpenOrders` (fast)

Keep total concurrent DFs per wave to 4–5 (F4 capacity constraint).

If all Phase 4 waves are already at 5 DFs, create a new wave after the last existing wave and add all three there.

- [ ] **Step 3: If df_OpenOrderParts uses a new ODBC table, add it to Phase 1**

If the open order parts source table (e.g., `wkpart`) is NOT already a Lakehouse raw table:
1. Create a new Dataflow Gen2 for it: `df_[TableName]_Raw`
2. Save the raw query to `.claude/queries/raw-tables/[TableName].pq`
3. Add it to Phase 1 of the pipeline (alongside other raw sources)
4. Commit the .pq file

- [ ] **Step 4: Update pipeline-schedule.md**

Add entries for the three new dataflows in `projects/refresh-pipeline/pipeline-schedule.md`:

```markdown
| df_JobCodePartFrequency | Phase 4, Wave [N] | Full | Est. [TBD after first run] min |
| df_OpenOrders           | Phase 4, Wave [N] | Full | Est. 1-2 min                   |
| df_OpenOrderParts       | Phase 4, Wave [N] | Full | Est. 1-2 min                   |
```

- [ ] **Step 5: Run a manual Phase 4 test**

Trigger a manual run of Phase 4 only. Verify all three dataflows complete without errors. Check that Lakehouse tables exist and have row counts from Task 3–5 validations.

- [ ] **Step 6: Commit**

```bash
git add projects/refresh-pipeline/pipeline-schedule.md
git add .claude/queries/raw-tables/  # if a new raw table was added
git commit -m "feat(open-order-parts-advisor): add Phase 4 pipeline entries"
```

---

## Task 7: Create Semantic Model in Power BI Desktop

**Files:** Created by Desktop publish, then auto-populated in fabric-workspace-docs after Fabric Git Integration commit.

- [ ] **Step 1: Open Power BI Desktop — new file**

File → New. Save as `Open Order Parts Advisor.pbix`.

- [ ] **Step 2: Connect to Lakehouse tables**

Home → Get Data → Fabric → Lakehouse → connect to `LH_Master_Data`.

Import these tables (Import mode — not DirectQuery):
- `Fact_JobCodePartFrequency`
- `Fact_OpenOrders`
- `Fact_OpenOrderParts` *(if built)*
- `dim_BranchLocation`
- `dim_CustomerList`
- `dim_Parts`
- `dim_DateTable`

- [ ] **Step 3: Set up model relationships**

In Model view, create these relationships (all Many-to-One, Single direction filter):

| From (Many side) | To (One side) | Key column |
|---|---|---|
| `Fact_OpenOrders[BranchCode]` | `dim_BranchLocation[BranchCode]` | BranchCode |
| `Fact_OpenOrders[CustomerNumber]` | `dim_CustomerList[CustomerNumber]` | CustomerNumber |
| `Fact_OpenOrders[OpenDate]` | `dim_DateTable[Date]` | Date |

Do NOT create relationships between:
- `Fact_OpenOrders` and `Fact_JobCodePartFrequency` (the DAX handles this)
- `Fact_OpenOrders` and `Fact_OpenOrderParts` (the DAX handles this)
- `Fact_JobCodePartFrequency` and `dim_Parts` (LOOKUPVALUE is used in the calculated table)

- [ ] **Step 4: Create the Recommendations calculated table**

Modeling → New Table. Paste this DAX — use the **WITH suppression** version if `Fact_OpenOrderParts` was built, or the **WITHOUT suppression** version otherwise:

**WITH suppression (Fact_OpenOrderParts was built):**
```dax
Recommendations =
ADDCOLUMNS(
    GENERATE(
        Fact_OpenOrders,
        VAR vJobCode = Fact_OpenOrders[JobCode]
        VAR vWONumber = Fact_OpenOrders[WorkOrderNumber]
        VAR vExistingParts =
            CALCULATETABLE(
                VALUES(Fact_OpenOrderParts[PartNumber]),
                Fact_OpenOrderParts[WorkOrderNumber] = vWONumber
            )
        RETURN
            FILTER(
                Fact_JobCodePartFrequency,
                Fact_JobCodePartFrequency[JobCode] = vJobCode
                    && NOT(
                        Fact_JobCodePartFrequency[PartNumber]
                            IN vExistingParts
                    )
            )
    ),
    "SellPrice", LOOKUPVALUE(
        dim_Parts[SellPrice1],
        dim_Parts[PartNumber], Fact_JobCodePartFrequency[PartNumber]
    ),
    "PartDescription", LOOKUPVALUE(
        dim_Parts[Description],
        dim_Parts[PartNumber], Fact_JobCodePartFrequency[PartNumber]
    )
)
```

**WITHOUT suppression (v1 fallback — Fact_OpenOrderParts not built):**
```dax
Recommendations =
ADDCOLUMNS(
    GENERATE(
        Fact_OpenOrders,
        VAR vJobCode = Fact_OpenOrders[JobCode]
        RETURN
            FILTER(
                Fact_JobCodePartFrequency,
                Fact_JobCodePartFrequency[JobCode] = vJobCode
            )
    ),
    "SellPrice", LOOKUPVALUE(
        dim_Parts[SellPrice1],
        dim_Parts[PartNumber], Fact_JobCodePartFrequency[PartNumber]
    ),
    "PartDescription", LOOKUPVALUE(
        dim_Parts[Description],
        dim_Parts[PartNumber], Fact_JobCodePartFrequency[PartNumber]
    )
)
```

- [ ] **Step 5: Validate the Recommendations table**

In DAX query view (Modeling → DAX query view), run:

```dax
EVALUATE
ROW(
    "TotalRows",        COUNTROWS(Recommendations),
    "UniqueWorkOrders", DISTINCTCOUNT(Recommendations[WorkOrderNumber]),
    "UniqueJobCodes",   DISTINCTCOUNT(Recommendations[JobCode]),
    "UniqueParts",      DISTINCTCOUNT(Recommendations[PartNumber])
)
```

Expected: TotalRows > 0, UniqueWorkOrders matches Fact_OpenOrders distinct WO count, UniqueJobCodes > 0. If TotalRows = 0, the GENERATE join is failing — verify JobCode values are identical (same casing, no trailing spaces) between Fact_OpenOrders and Fact_JobCodePartFrequency.

- [ ] **Step 6: Add measures**

Modeling → New Measure (on the `Recommendations` table, or create a separate `_Measures` blank table via Enter Data):

```dax
-- Count of distinct open ROs that have at least one recommendation
Open ROs with Recommendations =
DISTINCTCOUNT(Recommendations[WorkOrderNumber])
```

```dax
-- Total recommendation rows visible
Total Recommendations =
COUNTROWS(Recommendations)
```

```dax
-- Sum of SellPrice across all visible recommendations
Est $ Opportunity =
SUMX(
    Recommendations,
    Recommendations[SellPrice]
)
```

```dax
-- Top recommendation for each RO (used on Open Orders page)
Top Recommendation =
VAR TopRow =
    TOPN(
        1,
        FILTER(
            Recommendations,
            Recommendations[WorkOrderNumber] = MAX(Recommendations[WorkOrderNumber])
        ),
        Recommendations[FrequencyPct],
        DESC
    )
RETURN
    CONCATENATEX(
        TopRow,
        Recommendations[PartNumber]
            & " (" & FORMAT(Recommendations[FrequencyPct], "0%") & ")",
        ", "
    )
```

- [ ] **Step 7: Validate measures in Desktop**

Add a Card visual with `[Open ROs with Recommendations]`. Should show a non-zero number. If zero, the Recommendations table is empty — repeat Step 5 to diagnose.

- [ ] **Step 8: Save the file**

File → Save. Keep the .pbix locally — do not publish yet.

---

## Task 8: Build Report Pages

- [ ] **Step 1: Page 1 — Branch Summary (landing page)**

1. Rename "Page 1" to `Branch Summary`
2. Add a **Table** visual with these fields (in order):
   - `dim_BranchLocation[BranchName]`
   - `[Open ROs with Recommendations]`
   - `[Total Recommendations]`
   - `[Est $ Opportunity]`
3. Sort by `[Est $ Opportunity]` descending (click column header in visual)
4. Format `[Est $ Opportunity]` as Currency, 0 decimal places
5. Add a **Slicer** visual: `dim_BranchLocation[BranchName]`, style: Dropdown
6. Page title text box: "Branch Summary — Open Order Opportunity"
7. View → Sync Slicers → enable sync to Pages 2 and 3

- [ ] **Step 2: Page 2 — Open Orders**

1. Add new page, name: `Open Orders`
2. Add a **Table** visual with these fields:
   - `Fact_OpenOrders[WorkOrderNumber]`
   - `dim_CustomerList[DisplayName]`
   - `dim_BranchLocation[BranchName]`
   - A measure for distinct job codes — add this measure to the `_Measures` table in Task 7 Step 6, then use it here:
     ```dax
     # Job Codes =
     CALCULATE(
         DISTINCTCOUNT(Fact_OpenOrders[JobCode]),
         ALLEXCEPT(Fact_OpenOrders, Fact_OpenOrders[WorkOrderNumber])
     )
     ```
   - `[Total Recommendations]`
   - `[Est $ Opportunity]`
   - `[Top Recommendation]`
3. Sort by `[Est $ Opportunity]` descending
4. Format `[Est $ Opportunity]` as Currency, 0 decimal places
5. Enable drill-through on `Fact_OpenOrders[WorkOrderNumber]` → right-click column in visual → Add as drill-through field
6. Add Branch slicer (synced from Page 1 via Sync Slicers)

- [ ] **Step 3: Page 3 — RO Detail (drill-through target)**

1. Add new page, name: `RO Detail`
2. In Format Pane → Page Information → set **Drill through** = On, set the drill-through field to `Recommendations[WorkOrderNumber]`
3. Add **Card** visuals across the top:
   - `Recommendations[WorkOrderNumber]` (First value — use a measure: `RO Number = FIRSTNONBLANK(Recommendations[WorkOrderNumber], 1)`)
   - `Recommendations[BranchCode]` (or `dim_BranchLocation[BranchName]`)
   - `Recommendations[OpenDate]` (use measure: `Open Date = MIN(Fact_OpenOrders[OpenDate])`)
   - `[Est $ Opportunity]`
4. Add an optional **Slicer**: `Recommendations[JobCode]`, style: Dropdown. Label: "Filter by Job Code"
5. Add the main **Table** visual — flat recommendation list:
   - `Recommendations[PartNumber]`
   - `Recommendations[PartDescription]`
   - `Recommendations[JobCode]`
   - `Recommendations[FrequencyPct]` — format as Percentage, 0 decimal places; add conditional formatting (Rules): ≥ 0.50 → Red `#ef4444`, 0.20–0.49 → Yellow `#fbbf24`, < 0.20 → Gray `#9ca3af`
   - A "Appears On" text column — create measure: `Appears On = MAX(Recommendations[TimesWithPart]) & " of " & MAX(Recommendations[TotalOrdersWithJobCode]) & " orders"`
   - `Recommendations[SellPrice]` — format as Currency, 2 decimal places
6. Sort table by `Recommendations[FrequencyPct]` descending
7. Insert → Buttons → Back (for navigation return to Open Orders)

- [ ] **Step 4: Cross-page validation**

Find a known open RO in the source system that has a common job code (e.g., oil change, inspection, A/C repair). Then:

1. Navigate to Branch Summary — confirm the branch appears with a non-zero $ opportunity
2. Click through to Open Orders (or filter by branch) — confirm the RO appears in the list
3. Drill through to RO Detail — verify:
   - The job code from the open order is shown
   - Recommended parts are listed
   - FrequencyPct values are non-zero and below 1.0
   - Color coding is applied (red/yellow/gray)
   - If `Fact_OpenOrderParts` was built, confirm known parts are NOT in the recommendation list

---

## Task 9: Publish and Validate

- [ ] **Step 1: Publish to RP - Dev**

File → Publish → Select workspace: `RP - Dev`. Overwrite if prompted.

- [ ] **Step 2: Open report in browser, verify all three pages**

In Fabric, open the report in RP - Dev. Navigate all three pages. Check:
- Branch Summary loads with branch data
- Open Orders shows open ROs with non-zero $ opportunity
- Drill-through works (right-click RO# → Drill through → RO Detail)
- Color coding on FrequencyPct is visible

- [ ] **Step 3: Commit from Fabric Git Integration**

In Fabric → RP - Dev workspace → top navigation → Git Integration → Commit.
Push to `dev` branch in `fabric-workspace-docs`.

- [ ] **Step 4: Commit documentation to data-projects**

```bash
git add projects/open-order-parts-advisor/
git add .claude/queries/facts/
git commit -m "feat(open-order-parts-advisor): complete v1 — dataflows, model, report"
git push origin dev
```

- [ ] **Step 5: Push data-projects to origin**

```bash
git push origin dev
```

Note: Do NOT open a PR to main until stakeholders have reviewed the report in RP - Sandbox.
Standard path: RP - Dev → RP - Sandbox via "Dev Pipeline" → stakeholder review → publish directly to RP - Service Reports → PR dev → main in fabric-workspace-docs.

---

## Validation Checklist (before presenting to stakeholders)

- [ ] `Fact_JobCodePartFrequency` has rows for multiple job codes
- [ ] `Fact_OpenOrders` row count matches known open order volume from source system
- [ ] `Recommendations` calculated table is non-empty (TotalRows > 0)
- [ ] FrequencyPct values range between 0 and 1 (not all exactly 1.0 or 0.0)
- [ ] SellPrice is populated on recommendations (not all null)
- [ ] Branch Summary page sorts branches by $ opportunity descending
- [ ] Drill-through from Open Orders → RO Detail works
- [ ] Color coding applied on FrequencyPct (red ≥50%, yellow 20–49%, gray <20%)
- [ ] Branch slicer filters all pages correctly
- [ ] Part descriptions come from `dim_Parts[Description]`, not InTrans (verify on RO Detail page)
