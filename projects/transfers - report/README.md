# Transfers Report

**Status:** Sandbox (RP - Sandbox) — pending promotion to production
**Department:** Parts | Operations
**Business Owner:** Parts Operations Stakeholder
**Report Tier:** Tier 1 (daily, fresh by 8 AM)
**Created:** 02/25/2026 | **Last Updated:** 03/04/2026

---

## Overview

Tracks inter-branch parts transfers — analyzing movement of parts between branch locations, classifying transfer types (Work Order, Counter, Stock), and providing visibility into open/outstanding transfer orders.

**Key Business Questions:**
- Which branches are the highest senders and receivers of transferred parts?
- What is driving transfers — service shop demand (Work Orders), customer orders (Counter), or replenishment (Stock)?
- How does transfer volume compare to total on-hand inventory at each location?
- Which outstanding transfers are aging and may need follow-up?

---

## Report Pages

| # | Page Name | Fact Table | Purpose |
|---|-----------|------------|---------|
| 1 | **Transfers** | `Fact_Transfers` | Transfer activity by branch — qty, cost, lines broken down by sub-type |
| 2 | **Inventory View** | `Fact_Transfers` + `Inv_Snapshot` | Transfer qty/cost as a % of total on-hand inventory by part/branch |
| 3 | **Outstanding Transfers** | `Fact_OutstandingTransfers` | Open transfer orders — aging, fulfillment status, part-line detail |
| — | ToolTip 1 | — | Hidden tooltip page (Page 1 visuals) |
| — | ToolTip 2 | — | Hidden tooltip page (Page 2 visuals) |

---

## Data Model

### Fact Tables

| Table | Dataflow | Source | Grain | Purpose |
|-------|----------|--------|-------|---------|
| `Fact_Transfers` | `df_Fact_Transfers` | `InTrans_Incremental` | One row per transfer transaction line | Transfer history — Pages 1 & 2 |
| `Fact_OutstandingTransfers` | `df_Fact_Transfers` | `Parts_InterbranchTransfers` + `InSalPar` | One row per outstanding part line per ticket | Open transfers — Page 3 |
| `Inv_Snapshot` | `df_Fact_Transfers` | `jdis_Part_Information` | One row per part per branch | On-hand inventory context — Page 2 |

> **Note:** All three fact tables are built by a single dataflow (`df_Fact_Transfers`). Refreshing it updates all three.

### Dimensions

| Dimension | Relationship | Notes |
|-----------|-------------|-------|
| `dim_DateTable` | `Fact_Transfers[DateKey]` → `dim_DateTable[DateKey]` | Shared dimension |
| `dim_BranchLocation` | `Fact_Transfers[Branch]` → `dim_BranchLocation[BranchID]` (active) | Source branch |
| `dim_BranchLocation` | `Fact_Transfers[TransferBranch]` → `dim_BranchLocation[BranchID]` (inactive) | Destination branch |
| `dim_Parts` | `Fact_Transfers[PartNumber]` → `dim_Parts[PartNumber]` | Shared dimension |
| `dim_DateTable` | `Fact_OutstandingTransfers[DateKey]` → `dim_DateTable[DateKey]` | |
| `dim_BranchLocation` | `Fact_OutstandingTransfers[RequestingBranch]` → `dim_BranchLocation[BranchID]` (active) | Requesting branch |
| `dim_BranchLocation` | `Fact_OutstandingTransfers[SupplyingBranch]` → `dim_BranchLocation[BranchID]` (inactive) | Supplying branch |
| `dim_Parts` | `Fact_OutstandingTransfers[PartNumber]` → `dim_Parts[PartNumber]` | |
| `dim_BranchLocation` | `Inv_Snapshot[Branch]` → `dim_BranchLocation[BranchID]` | |

### Raw Tables

| Raw Table | Lakehouse Table | Used By | Purpose |
|-----------|----------------|---------|---------|
| `InTrans_Incremental` | `InTrans_Incremental` | `Fact_Transfers` | Core transfer transaction history |
| `Parts_InterbranchTransfers` | `Parts_InterbranchTransfers` | `Fact_OutstandingTransfers` | Outstanding ticket headers (ticket-level, no part detail) |
| `InSalPar` | *(direct ODBC in dataflow)* | `Fact_OutstandingTransfers` | Part-line detail joined to outstanding tickets |
| `jdis_Part_Information` | `jdis_Part_Information` | `Inv_Snapshot` | Current on-hand qty/cost by part/branch |

---

## Business Logic

### Transfer Sub-Type Classification

Transfers are classified into three operational categories:

| Sub-Type | Meaning | Classification Source |
|----------|---------|----------------------|
| **Work Order** | Transfer to fulfill a repair order (service shop demand) | `InTrans` type field / `InSalPar.SoRoRef` range 100,000–999,999 |
| **Counter** | Transfer to fulfill a customer sales order (counter demand) | `InTrans` type field / `InSalPar.SoRoRef` range 1,000,000–9,999,999 |
| **Stock** | Replenishment transfer (no specific demand order) | `InTrans` type field / `InSalPar.SoRoRef` < 100,000 or null |
| **Unknown** | Cannot be classified | `InSalPar.SoRoRef` ≥ 10,000,000 — expected near-zero |

### FulfillmentStatus (Outstanding Transfers)

Added to `Fact_OutstandingTransfers` at the dataflow level — classifies each part line by how much of the ordered quantity has shipped from the supplying branch:

| Status | Condition |
|--------|-----------|
| **Pending** | `ShippedQty = 0` — nothing has left the supplying branch |
| **Partial** | `0 < ShippedQty < OrderQty` — partially dispatched |
| **Shipped** | `ShippedQty = OrderQty` — fully dispatched, awaiting receipt at requesting branch |

### Aging Bucket (Outstanding Transfers)

DAX calculated column on `Fact_OutstandingTransfers[OrderAge]`:

| Bucket | Range |
|--------|-------|
| 0–7 Days | ≤ 7 days |
| 8–30 Days | 8–30 days |
| 31–60 Days | 31–60 days |
| 61+ Days | > 60 days |

### Branch 12 Exclusion

Both fact tables exclude records where `RequestingBranch` or `SupplyingBranch` starts with `"12"`. Branch 12 (O'Donnell) is covered by the separate **Combine Vault Sales** report.

---

## Refresh Pipeline

### Pipeline Chain (added 03/04/2026)

```
Phase 1 — Raw Data (Pipeline_Raw_Data)
  └── Refresh_Parts_InterbranchTransfer_Raw   [Batch 1, parallel]

Phase 4 — Facts (Pipeline_Facts)
  └── Refresh_Fact_Transfers                  [Wave C]
        → builds Fact_Transfers, Fact_OutstandingTransfers, Inv_Snapshot

Phase 5 — Semantic Models (Pipeline_SemanticModels)
  └── Refresh_Transfers_SM                    [Wave A4]
```

### Key IDs

| Item | ID |
|------|----|
| Transfers SemanticModel (Sandbox) | `46ceabde-9d36-b8e7-46ea-817eeb9b5dfe` |
| df_Fact_Transfers dataflow | `ce778550-1811-9ac7-4a01-096e0d3d6a4f` |
| df_Parts_InterbranchTransfer_Raw dataflow | `e50d9c54-2d47-8416-4a98-992636254981` |
| RP - Sandbox workspace | `ba9d8de4-ef13-44e6-9156-e23a2511f3ad` |

### Dependencies

```
Parts_InterbranchTransfers (Raw)  ─┐
InTrans_Incremental (Phase 2)      ├──> df_Fact_Transfers ──> Transfers SM
jdis_Part_Information (Raw)       ─┘
Dimensions (Phase 3)              ─┘
```

---

## Project Structure

```
transfers - report/
├── queries/
│   ├── fact-tables/
│   │   ├── Fact_Transfers.pq               # Transfer history query
│   │   └── Fact_OutstandingTransfers.pq    # Outstanding transfers query
│   └── raw-tables/
│       └── Raw_Parts_InterbranchTransfers.pq
├── reports/
│   ├── Transfers.Report/                   # Report definition (PBIR format)
│   └── Transfers.SemanticModel/            # Semantic model (TMDL format)
│       └── definition/
│           ├── tables/
│           │   ├── _Measures.tmdl
│           │   ├── Fact_Transfers.tmdl
│           │   ├── Fact_OutstandingTransfers.tmdl
│           │   ├── Inv_Snapshot.tmdl
│           │   ├── dim_BranchLocation.tmdl
│           │   ├── dim_DateTable.tmdl
│           │   └── dim_Parts.tmdl
│           └── relationships.tmdl
└── README.md
```

---

## Known Issues & Limitations

| Issue | Status | Notes |
|-------|--------|-------|
| Branch 12 data excluded | By design | Covered by Combine Vault Sales report |
| TransferBranch relationship inactive | By design | Use DAX `USERELATIONSHIP` when filtering by destination branch |
| SupplyingBranch relationship inactive | By design | Active relationship is on RequestingBranch |
| Page 4 (Profitability) not built | Future | Requires fuel/labor/vehicle cost data — sources not yet identified |

---

## Change Log

| Date | Change | Impact |
|------|--------|--------|
| 02/25/2026 | Initial report scaffold created | Low |
| 03/03/2026 | Added Page 3 (Outstanding Transfers) + Parts_InterbranchTransfers raw table | High |
| 03/03/2026 | Fixed join key: InSalPar.FILE_NO = PartTicket (replaced wrong InTrans join) | High |
| 03/04/2026 | Added FulfillmentStatus column to Fact_OutstandingTransfers (dataflow level) | Medium |
| 03/04/2026 | Added opacity dimming to Page 1 hero card (TransferSubType selection) | Low |
| 03/04/2026 | Added date range display to page headers | Low |
| 03/04/2026 | Wired all three pipeline phases (Raw, Facts, SM) | High |

---

## Related Documentation

- **Architecture decisions:** `ARCHITECTURE.md` *(see this file for the InSalPar join key rationale)*
- **Fact table queries:** `queries/fact-tables/`
- **Raw table queries:** `queries/raw-tables/`
- **Pipeline docs:** `projects/refresh-pipeline/REFRESH-PIPELINE.md`
- **Shared dimensions:** `.claude/queries/dimensions/`
