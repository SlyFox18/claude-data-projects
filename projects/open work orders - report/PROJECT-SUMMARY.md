# Open Work Orders — Project Summary

## Overview

The Open Work Orders report (also called the WIP Report) tracks every service work order that has been written up but not yet invoiced — across all 15 branches. It provides aging analysis so service managers can see at a glance how much work is sitting in each stage, where jobs are stalling, and how much revenue is tied up in open work.

**Status:** Production ✅
**Workspace:** RP - Service Reports
**Refreshed:** Daily — 4:15 AM CST, Tier 1 (fresh by 8 AM)

---

## Report Pages

| Page | Purpose |
|------|---------|
| **WIP Overview** | Executive summary: total sales by type (Parts/Labor/Sublet/Other), aging bucket cards showing WO count and sales for each age range, and a branch-by-branch aging composition chart |
| **WIP Details** | Row-level drill-down table of every open work order — customer, branch, technician, equipment model, aging bucket, days since last labor (color-coded), revenue breakdown |

---

## Data Model

### Tables
| Table | Type | Source | Description |
|-------|------|--------|-------------|
| `Fact_OpenWorkOrders` | Fact | Lakehouse (Power Query) | One row per open work order. ~2–3K rows. Includes aging bucket, revenue by type, technician, customer, equipment model. |
| `dim_BranchLocation` | Dimension | Shared Lakehouse | Branch names and IDs |
| `dim_CustomerList` | Dimension | Shared Lakehouse | Customer master — name lookup via AccountNumberText |
| `dim_Technician_Code_Names` | Dimension | Lakehouse | Technician code → name lookup |
| `dim_AgingBucket` | Dimension | DAX DATATABLE (calculated) | Disconnected slicer: 6 aging buckets with sort order and display color. No relationship to fact table. |
| `dim_DateTable` | Dimension | Shared Lakehouse | Date dimension. DateKey column exists on fact table but no active relationship is defined. |

### Relationships
```
Fact_OpenWorkOrders[Branch]            → dim_BranchLocation[BranchID]         (M:1)
Fact_OpenWorkOrders[AccountNumberText] → dim_CustomerList[AccountNumberText]   (M:1)
Fact_OpenWorkOrders[TechCode]          → dim_Technician_Code_Names[TechnicianCode]  (M:M, bidirectional ⚠️)
dim_AgingBucket                        — disconnected (no relationship)
dim_DateTable                          — no active relationship defined
```

> ⚠️ The TechCode relationship is many-to-many with bidirectional filtering. This is a potential performance risk if the report grows. See CLAUDE.md for details.

---

## Key Measures

| Measure | Description |
|---------|-------------|
| `Total Open Work Orders` | Count of all active uninvoiced work orders |
| `Total Sales` | Total revenue on open WOs (Labor + Parts + Sublet + Other) |
| `Part Sales` | Parts revenue on open WOs |
| `Labor Sales` | Labor revenue on open WOs |
| `Sublet Sales` | Sublet/outside work revenue |
| `Other Sales` | Other revenue |
| `WO Count - [Bucket]` | Count of WOs in each aging bucket (6 measures, one per bucket) |
| `Sales - [Bucket]` | Total revenue in each aging bucket (6 measures) |
| `Work Orders by Selected Aging` | Dynamic count — responds to dim_AgingBucket slicer selection |
| `Sales by Selected Aging` | Dynamic sales — responds to dim_AgingBucket slicer selection |
| `Customer Name` | Cascading lookup: dim_CustomerList → TechnicianPunch fallback |
| `Days Since Last Labor Color` | Hex color for conditional formatting (Green/Orange/Red/Gray) |
| `Open WO - Aging Summary Card (HTML)` | Rich HTML card showing all 6 aging buckets with counts and sales |
| `Open WO - Branch Aging Composition (HTML)` | Proportional stacked bar chart per branch, HTML-rendered |

---

## Aging Bucket Logic

Buckets are pre-computed in Power Query (not DAX) and stored in `Fact_OpenWorkOrders[AgingBucket]`:

| Bucket | Condition | Display Color |
|--------|-----------|---------------|
| Not Started | No labor punch recorded (DaysSinceLastLabor ≥ 45,000) | Gray |
| 1 - 7 Days | DaysSinceCreationDate 1–7 | Blue |
| 8 - 14 Days | DaysSinceCreationDate 8–14 | Green |
| 15 - 30 Days | DaysSinceCreationDate 15–30 | Yellow |
| 31 - 60 Days | DaysSinceCreationDate 31–60 | Orange |
| 60+ Days | DaysSinceCreationDate > 60 | Red |

**Not Started takes precedence** over time buckets — a job without any technician punch is always "Not Started" regardless of creation date.

---

## Source System Tables

All sourced from `LH_Master_Data` Lakehouse via SQL analytics endpoint:

| Lakehouse Table | Source System Table | What It Provides |
|-----------------|--------------------|--------------------|
| `RepairOrderDetail` | wkothsub / ODBC | Core WO data: branch, work order #, job code, dates, revenue by type, status |
| `WKROFILE` | ODBC | Customer account number, payment method, franchise, equipment registration |
| `TechnicianPunchedDetail` | ODBC | Equipment model, technician code, customer name (grouped to one row per WO) |

**Filter applied:** `StatusDisplay <> 'Invoiced'` — only open jobs are loaded.

---

## Progress Status Codes

The `ProgressStatusDisplay` column maps raw `ROProgressStatus` codes to friendly names:

| Code | Display | Code | Display |
|------|---------|------|---------|
| BI | Booked In | WO | Worked |
| BY | Booked in on Yard | WP | T-Complete |
| CA | Customer Advised | CP | Complete Priced |
| CO | Collection | CS | Complete Service Manager |
| CW | Customer Waiting | SC | Sundry WO - Complete |
| DA | Warranty JAD | WC | Warranty Complete |
| DP | In Delay - Part | WF | Invoiced |
| MI | More Info Needed | WJ | Warranty JAD |

---

## Migration Notes

This is a full rebuild of the legacy Open Work Orders report. The old model loaded ~1.7 million rows across 5 tables (TechnicianInvoiceDetail + TechnicianPunchedDetail in full). The new model loads only ~3,000 rows — the open work order summary with pre-aggregated technician data.

| | Old Model | New Model |
|-|-----------|-----------|
| Row count | ~1.7M | ~3K |
| Refresh time | ~3:30 min | <30 sec |
| Relationships | Multiple M:M, bidirectional | Mostly clean star schema |
| Aging | Hardcoded SQL + duplicate DAX | Pre-computed in Power Query |

Old report files preserved in `report/archive/` for reference.

---

## Files in This Project

| File / Folder | Purpose |
|---------------|---------|
| `CLAUDE.md` | Technical context for Claude — fact table schema, known issues, gotchas |
| `PROJECT-SUMMARY.md` | This file — overall project reference |
| `MIGRATION-PLAN.md` | Original design document — star schema decisions, what was eliminated |
| `queries/fact tables/` | Power Query `.pq` files for Fact_OpenWorkOrders |
| `queries/dimensions/` | DAX file for dim_AgingBucket |
| `queries/dax-measures/Core_Measures.dax` | All DAX measures with documentation |
| `report/current/` | Live TMDL semantic model and report definition |
| `report/archive/` | Legacy .pbip report preserved for reference |
| `info-exports/` | Column/measure/relationship exports from old and new reports |
