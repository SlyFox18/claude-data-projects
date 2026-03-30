# Planter Inspection Part Sales — Project Summary

## Overview

This report connects planter inspection activity to parts revenue. It answers the question: when customers receive a planter inspection from the Lorenzo team, do they convert to buying planter parts — and how much revenue does that inspection activity generate? Page 1 focuses on the inspection-to-parts conversion story; Page 2 breaks down the invoice-level parts mix for those same customers.

**Status:** Sandbox — Published for Stakeholder Review
**Workspace:** RP - Sandbox
**Refreshed:** Daily via Facts + Semantic Model pipelines (~1:40 fact dataflow avg)

---

## Report Pages

| Page | Purpose |
|------|---------|
| Planter Inspection Part Sales | Shows which customers received a planter inspection, whether they converted to buying parts, parts/labor revenue totals, and planter promo uptake. Designed for management and the Lorenzo team to track inspection ROI. |
| Planter Part Sales | Breaks down parts revenue on planter-related invoices into "Planter Parts" vs "Add-On Parts" using an equation narrative (Planter + Add-On = Total). Scoped to inspection customers only. |

---

## Data Model

### Tables

| Table | Type | Source | Description |
|-------|------|--------|-------------|
| `Fact_PlanterInspections` | Fact | wkothsub + WKROFILE (Lakehouse) | One row per invoiced planter inspection work order. Columns: branch, work order, invoice number, customer, labor amount, dates. ~100–500 rows/season. |
| `Fact_PlanterPartSales` | Fact | Lakehouse table (dataflow) | Parts sold to planter inspection customers. Includes ZP (promo) rows — filter in DAX for real parts vs promo. |
| `Fact_PlanterInvoiceAllParts` | Fact | InTrans_Incremental + dim_Parts (native SQL) | All part transactions on invoices that contained at least one planter-classified part. Has `IsPlanterPart` boolean column set at query time. Powers Page 2. |
| `Fact_PlanterInspectionParts` | Fact | wkothsub + InTrans_Incremental | Parts on inspection invoices directly. In the model but currently unused — candidate for removal. |
| `dim_BranchLocation` | Dimension | Shared (Lakehouse) | 15 branch locations |
| `dim_CustomerList` | Dimension | Shared (Lakehouse) | Customer master with CSM, route day, engagement level |
| `dim_DateTable` | Dimension | Shared (Lakehouse) | Universal date dimension |
| `dim_Parts` | Dimension | Shared (Lakehouse) | Parts catalog — commodity codes 310–318 = planter hardware |

### Relationships

All fact tables connect to shared dimensions on:
- `BranchCode → dim_BranchLocation.BranchID`
- `CustomerNumber → dim_CustomerList.CustomerNumber`
- `TransactionDate/InvoiceDate → dim_DateTable.Date`
- `PartNumber → dim_Parts.PartNumber` (Fact_PlanterInspectionParts and Fact_PlanterInvoiceAllParts only)

**Important:** `Fact_PlanterInspections` and `Fact_PlanterPartSales` share no direct relationship — they connect at the customer level. The inspection and the parts purchase happen on different invoices at different branches.

---

## Key Measures

| Measure | Description |
|---------|-------------|
| `Total Parts Sale $` | Parts revenue from customers who received a planter inspection (excludes promo items) |
| `Total Parts Cost $` | Parts cost for the same customer group |
| `Total Labor $` | Labor revenue from planter inspections |
| `Total Planter Inspections` | Count of planter inspections performed |
| `Inspections with Part Sales` | How many inspection customers also bought planter parts |
| `Inspections with Planter Promo` | How many inspection customers used the *PLANTER promo |
| `Parts Multiplier` | Parts revenue per $1 of labor — measures inspection ROI in parts dollars |
| `Converted` | "Yes" / "No" — did this customer buy parts after their inspection? |
| `Planter Parts $` | Dollar value of planter-classified parts on planter invoices (inspection customers) |
| `Add-On Parts $` | Dollar value of non-planter parts sold on the same planter invoices |
| `Total Invoice Parts Sale $` | Planter Parts + Add-On Parts combined (full invoice total) |
| `Invoice Parts Margin %` | Overall gross margin % for planter invoice parts |

---

## Source System Tables

| Source Table | What It Contains | Used By |
|--------------|-----------------|---------|
| `wkothsub` | Service job codes and work order invoices | Fact_PlanterInspections, Fact_PlanterInspectionParts |
| `WKROFILE` | Work order header — customer number (CHARGE_ACCT), creation date | Fact_PlanterInspections |
| `InTrans_Incremental` | All parts transactions (10M+ rows, incremental) | Fact_PlanterInspectionParts, Fact_PlanterInvoiceAllParts |
| `Fact_PlanterPartSales` | Pre-built Lakehouse table of planter customer part sales | Fact_PlanterPartSales |
| `dim_Parts` | Parts catalog with commodity codes | Fact_PlanterInvoiceAllParts (planter classification) |

---

## Notes

### Old Report vs New Report
This is a ground-up rebuild of an older report with the same name. The old report had a many-to-many modeling bug (`Planter_Part_List` table with branch-level jdis data in M2M with `Planter_Parts`) that made the old totals (~$756K) untrustworthy. The new report uses a boolean `IsPlanterPart` flag set at SQL query time — no M2M relationship needed.

### Page 2 Native SQL
`Fact_PlanterInvoiceAllParts` uses a native T-SQL query instead of Power Query joins. This was required after the initial Power Query version caused 15+ minute timeouts by double-scanning InTrans_Incremental (10M+ rows). The native SQL query pushes a single optimized plan to the Fabric Lakehouse SQL endpoint.

### Planter Part Classification
Commodity codes 310–318 are all planter-specific hardware. 3,500+ parts in this range is expected — planters have extensive hardware requirements across dozens of models and years. Parts are also caught by `PartNumber LIKE '%PLANTER%'` for promo and specialty items.

### Inspection Customer Scope
Both pages are scoped to customers who received a planter inspection (from `Fact_PlanterInspections`). Page 2 measures hard-code this filter via DAX to ensure the hero card and all visuals stay consistent with the inspection-focused context of the report.
