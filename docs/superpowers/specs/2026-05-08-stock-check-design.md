# Stock Check — Design Spec

**Date:** 2026-05-08  
**Requested by:** Corp Aftermarket Sales Manager  
**Primary audience:** Corp Sales Manager  
**Project folder:** `projects/stock-check - report/`

---

## Purpose

Internal work orders (wo_type = `'i'`) represent service work performed on stock (unsold) equipment. When one is entered, the Corp Sales Manager currently has no visibility until he manually checks the source system. This project delivers two things:

1. **Power BI report** — operational dashboard showing open stock check WOs and a searchable historical log
2. **Power Automate email** — daily digest of new internal WOs entered the previous day, sent each morning after the pipeline

---

## Architecture

```
Lakehouse raw tables (already refreshed daily)
  WKROFILE · wkrodesc · wkothsub · wkmechwk · vhstock · WKVEHFL
          │
          ▼  Phase 4 dataflow
  Fact_InternalWorkOrders  (WO × JobCode grain)
          │
          ├──▶  Power BI Semantic Model
          │         └──▶  Stock Check Report (2 pages)
          │
          └──▶  Power Automate (post-report build)
                    └──▶  Daily email → Corp Sales Manager
```

---

## Fact Table — `Fact_InternalWorkOrders`

**Dataflow:** `df_Fact_InternalWorkOrders`  
**Location:** LH_Master_Data → Dataflows → 04 - Fact  
**Grain:** One row per Work Order × Job Code  
**Refresh:** Full daily, Phase 4  
**Estimated rows:** ~7,000–10,000 (Internal WOs only, 2026-01-01 scope)

### Source Joins

| Table | Join Key | Purpose |
|---|---|---|
| `wkrodesc` | — base table | Job codes; filter `JobType = 'i'` (Internal) |
| `WKROFILE` | `Branch + WorkOrder` | WO header: dates, status, equipment identifiers; filter `CreatedOn >= 2026-01-01` |
| `wkothsub` | `Branch + WorkOrder + JobCode + JobType` | Estimated hours, standard labor flag, invoice reference |
| `wkmechwk` (aggregated) | `Branch + WorkOrder + JobCode + JobType` | Actual and invoiced hours — SUM per WO × JobCode before joining |
| `vhstock` | `StockNumber` (LEFT JOIN) | Make, Model for stock units |
| `WKVEHFL` | `Registration` (LEFT JOIN) | Make, Model for registered/fleet units (fallback) |

### Output Columns

| Column | Source | Notes |
|---|---|---|
| Branch | WKROFILE | text |
| WorkOrder | WKROFILE | text |
| JobCode | wkrodesc | e.g., `/IS-TRACTOR INSPECT` |
| JobType | wkrodesc | `'i'` for all rows in this table |
| JobValue | wkrodesc | numeric |
| CreatedOn | WKROFILE | date — WO creation date |
| ClosedDate | WKROFILE | date, nullable |
| ProgressStatus | WKROFILE | raw code: `bi`, `va`, `wip`, `wf`, `iv`, `ca`, `vp` |
| IsClosed | WKROFILE | boolean |
| StockNumber | WKROFILE | nullable; stock unit identifier |
| Registration | WKROFILE | nullable; registered equipment identifier |
| Make | vhstock / WKVEHFL | `COALESCE(vhstock.Make, WKVEHFL.Make)` |
| Model | vhstock / WKVEHFL | `COALESCE(vhstock.Model, WKVEHFL.Model)` |
| EstHours | wkothsub | estimated labor hours per job |
| IsStandardLabor | wkothsub | Y/N flag |
| IsNonRevenue | wkothsub | Y/N flag |
| InvoiceNumber | wkothsub | nullable; populated once invoiced |
| HoursWorked | wkmechwk | SUM(HoursWorked) per WO × JobCode |
| InvoiceHours | wkmechwk | SUM(InvoiceHours) per WO × JobCode |

### Build Note — vhstock scope

`vhstock` is a full-extract table (no incremental refresh applied), so all stock units including unsold/in-stock equipment are present. The join on `StockNumber` is safe to use without additional validation.

---

## Semantic Model

**Tables imported from Lakehouse:**
- `Fact_InternalWorkOrders`
- `dim_BranchLocation`
- `dim_DateTable`
- `Data Refresh`

**Relationships:**
- `Fact_InternalWorkOrders[Branch]` → `dim_BranchLocation[BranchID]` (single direction)
- `Fact_InternalWorkOrders[CreatedOn]` → `dim_DateTable[Date]` (single direction)

### Key DAX Measures

| Measure | Logic |
|---|---|
| `Total WOs` | `DISTINCTCOUNT(Fact_InternalWorkOrders[WorkOrder])` |
| `Open WOs` | DISTINCTCOUNT WorkOrder where IsClosed = false |
| `Branches with Open WOs` | DISTINCTCOUNT Branch where IsClosed = false |
| `Avg Days Open` | Average of TODAY() − CreatedOn across open WOs |
| `Days Open` | TODAY() − MIN(CreatedOn) — used in table, scoped per WO |
| `Over 14 Days` | COUNTROWS of open WOs where Days Open > 14 |
| `Avg Days to Close` | Average of ClosedDate − CreatedOn for closed WOs |
| `Hrs Worked` | SUM(HoursWorked) |
| `Hrs Invoiced` | SUM(InvoiceHours) |
| `Hrs Estimated` | SUM(EstHours) |
| `Progress Status Label` | SWITCH on ProgressStatus: `bi`→"Booked-In", `va`→"Equipment Arrived", `wip`→"Work Commenced", `wf`→"Work Finished", `iv`→"Equipment Invoiced", `ca`→"Customer Advised", `vp`→"Equipment Picked-up" |

---

## Report — Stock Check

**Workspace:** RP - Sandbox (test) → RP - Service Reports (production)  
**Audience:** Corp Sales Manager

### Page 1 — Open Stock Checks

Shows only WOs where `IsClosed = false` (equipment still in the shop or not yet fully processed).

**Layout:**
- Header banner (HTML): page title + last refresh timestamp
- KPI cards row (4 cards): Open WOs · Branches with Open WOs · Avg Days Open · Over 14 Days
- Branch bar chart: horizontal bar, Open WOs by Branch, sorted descending
- Table (below chart): WO#, Branch, Make/Model, Stock#, Date In, Days Open, Status

**Table column details:**
- Days Open — numeric, highlighted red if > 14
- Status — human-readable label (from `Progress Status Label` measure)
- Make/Model — combined single column (`Make & " " & Model`)

**Slicers:** Branch (dropdown), Status (dropdown)

### Page 2 — Historical Log

All internal WOs from 2026-01-01 forward, regardless of open/closed status.

**Layout:**
- Slicers row: Date Range (CreatedOn), Branch, Status, WO# search
- KPI summary cards: Total WOs · Open WOs · Avg Days to Close · Active Branches
- Expandable table — WO level with job code drill-down:
  - WO level columns: WO#, Branch, Make/Model, Stock#, Date In, Date Closed, Days Open/to Close, Total Hrs Worked, Total Hrs Invoiced, Status
  - Job code level columns (expanded): Job Code, Est Hrs, Hrs Worked, Hrs Invoiced, Standard Labor (Y/N)

**Expand/collapse:** Implemented as a Power BI matrix with WorkOrder as row parent and JobCode as row child. Alternatively a table with row-level hierarchy if matrix behavior is limiting.

---

## Power Automate Email Alert

> **Scope:** Build and test after the Power BI report is complete and validated.

**Trigger:** Scheduled recurrence — daily at 7:00 AM CST (after pipeline completes ~6:00 AM)

**Data source:** Lakehouse SQL analytics endpoint  
**Query:** Select from `Fact_InternalWorkOrders` where `CreatedOn = CAST(DATEADD(day, -1, CAST(GETDATE() AS DATE)) AS DATE)`

**Skip condition:** If query returns 0 rows, do not send (no email for days with no new stock checks)

**Email content:**
- Subject: `Stock Check Alert — {N} Internal WOs Entered {yesterday's date}`
- Table: WO#, Branch, Make/Model, Stock#, Date Entered, Status (color-coded badge)
- Footer: "View Full Report" button linking to the Power BI report URL
- Recipient: Corp Sales Manager

**Status badge colors:**
- Work Commenced / Work Finished → amber
- Equipment Picked-up → green
- Booked-In / Equipment Arrived → blue
- Equipment Invoiced → gray

---

## Open Questions (to resolve during build)

1. **Email recipient email address** — confirm with requestor before configuring the flow
2. **Pipeline placement** — to be determined after report build and testing; likely Phase 4 medium wave

---

## Out of Scope (v1)

- Estimated vs. actual cost variance analysis
- Technician-level detail (who worked on the WO)
- Warranty claim tracking
- Parts cost per WO
- Multi-recipient email / distribution list
