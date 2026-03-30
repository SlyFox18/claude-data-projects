# Pin Capture — Project Summary

## Overview
This report tracks how consistently parts staff are recording equipment PINs (serial/identification numbers) on parts transactions. A PIN ties a parts sale to a specific piece of equipment, enabling warranty tracking, service history, and equipment-level analytics. The report measures PIN capture rate by branch and franchise, and shows how PIN capture correlates with sales margin.

**Status:** Production
**Workspace:** RP - Parts Reports
**Refreshed:** Daily (Tier 2)

## Report Pages

| Page | Purpose |
|------|---------|
| Overview | Main dashboard — PIN capture rate, transaction counts, sales with/without PIN |
| Branch Summary | PIN capture performance by branch (hidden, accessible within report) |
| Transaction Detail | Line-item detail view of all transactions (hidden) |
| Transaction Drill Through | Drill into specific transactions from summary views |

## Data Model

### Tables
| Table | Type | Source | Description |
|-------|------|--------|-------------|
| `Fact_PinTransactions` | Fact | `InTrans_Incremental` (direct read, 24-month window) | Parts transactions with PIN and Notation fields, sale/cost/margin values, classified as Invoice or Work Order |
| `dim_BranchLocation` | Shared Dimension | Shared | Branch/location reference |
| `dim_DateTable` | Shared Dimension | Shared | Date dimension |
| `dim_Parts` | Shared Dimension | Shared | Parts catalog |
| `dim_CustomerList` | Shared Dimension | Shared | Customer list (no active relationship to fact) |
| `PinFilterOptions` | Reference | Local | Filter options for PIN views |

### Relationships
- `Fact_PinTransactions.Branch` → `dim_BranchLocation.BranchID`
- `Fact_PinTransactions.TransDatetime` → `dim_DateTable.Date`
- `Fact_PinTransactions.PartNumber` → `dim_Parts.PartNumber`

## Key Measures

| Measure | Description |
|---------|-------------|
| Total Transactions | Count of distinct invoices/work orders |
| Transactions with Pins | Invoices/WOs where at least one PIN was recorded |
| % Transactions with Pin | Capture rate — the headline KPI |
| Total Sales | Total parts revenue in the period |
| Sale with Pin | Revenue from transactions where a PIN was captured |
| Total Margin | Margin dollars across all transactions |

## Source System Tables
| ERP Source | Description |
|-----------|-------------|
| InTrans_Incremental | Parts transaction history (Invoice and Credit types, rolling 24 months) |
| wkothsub | Work order sub-table (used to classify transactions as Work Order vs. Invoice) |

## Notes
- **PIN sources:** A PIN can come from the `PinNo` field (formal pin lookup) or the `Notation` field (manually entered). Both are accepted — the report unifies them into a single `Pin Identifier`.
- **Direct InTrans read:** Unlike most reports, this fact is not a pre-built Lakehouse table. The semantic model reads `InTrans_Incremental` directly at import time and performs the `wkothsub` classification join inline.
- **24-month window:** Transactions older than 24 months are excluded. The window is calculated from the start of the current month minus 24 months.
- **Line Item Status Icon:** Each line gets an emoji rating (💎/✅/🟡/🟠/⚪/⚠️) based on PIN capture status combined with margin percentage.
