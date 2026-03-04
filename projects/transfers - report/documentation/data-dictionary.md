# Transfers Report — Data Dictionary

**Last Updated:** 03/04/2026
**Scope:** All columns across the three fact tables in the Transfers semantic model, plus calculated columns and key dimension references.

---

## Fact_Transfers

**Source:** `InTrans_Incremental` (Lakehouse table)
**Grain:** One row per inventory transaction (`TransId` is the natural key)
**Date Range:** 2023-01-01 to current
**Rows:** ~10M+ in source; filtered to Types T/I/C/P and Branch 12 excluded
**Dataflow:** `df_Fact_Transfers`

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `DateKey` | Int64 | No | YYYYMMDD integer. Foreign key → `dim_DateTable[DateKey]`. |
| `Date` | Date | No | Transaction date (derived from `TransDatetime`). Convenience field for date formatting. |
| `TransId` | Int64 | No | Natural grain key. Unique transaction ID from the source system. Use `COUNTROWS` or `DISTINCTCOUNT(TransId)` to count transactions. |
| `TransDatetime` | DateTime | No | Full transaction timestamp from `InTrans_Incremental`. More precise than `Date` — use when time-of-day matters. |
| `RONumber` | Text | Yes | Repair Order or reference number associated with the transaction. Upper-cased. |
| `Branch` | Text | No | Source branch code. Foreign key → `dim_BranchLocation[BranchID]` (active relationship). Includes sub-branch codes like `8I`, `95I`, `93C`. |
| `TransferBranch` | Text | Yes | Destination branch code for Type = T transfers. Null for non-transfer types (I, C, P). Foreign key → `dim_BranchLocation[BranchID]` (inactive — use `USERELATIONSHIP` in DAX). |
| `PartNumber` | Text | Yes | Part number. Upper-cased. Foreign key → `dim_Parts[PartNumber]`. |
| `Franchise` | Text | Yes | Manufacturer/brand code (e.g., JD, WF, HN). Upper-cased. |
| `Type` | Text | No | Transaction type. Values: `T` (Transfer), `I` (Invoice/Counter Sale), `C` (Credit), `P` (Purchase from Supplier). |
| `TransferSubType` | Text | Yes | Transfer sub-type classification. Populated only for Type = T; null for I/C/P. Values: `Work Order`, `Counter`, `Stock`, `Unknown`. Sorted by `TransferSubTypeSortOrder`. See classification logic below. |
| `TransferSubTypeSortOrder` | Int64 | Yes | **Hidden.** Sort column for `TransferSubType`: Work Order=1, Counter=2, Stock=3, Unknown=4. Do not use directly in visuals. |
| `Qty` | Number | Yes | Transaction quantity. Positive = movement out of `Branch`, negative = credits/returns. |
| `CostValue` | Number | Yes | Dollar cost value of the transaction at the branch's cost basis. |
| `OrderQty` | Number | Yes | Quantity originally ordered. **~12% null** for Type T rows, concentrated in 2023. Null means "not tracked" — do NOT treat as zero. |
| `ShippedQty` | Number | Yes | Quantity shipped/dispatched. **~12% null** for Type T rows, concentrated in 2023. Null means "not tracked" — do NOT treat as zero. |
| `OrderSalesman` | Text | Yes | Salesperson or staff member who initiated the order/transfer. Upper-cased. |

### TransferSubType Classification Logic

Based on the numeric value of `SoRoRef` from the source (removed from the table after classification):

| Condition | Value | Meaning |
|-----------|-------|---------|
| `SoRoRef` is null, 0, 1, or < 100,000 | `Stock` | No valid demand reference — replenishment transfer |
| 100,000 ≤ `SoRoRef` ≤ 999,999 | `Work Order` | 6-digit Repair Order number — service shop demand |
| 1,000,000 ≤ `SoRoRef` ≤ 9,999,999 | `Counter` | 7-digit Sales Order number — customer-facing demand |
| `SoRoRef` ≥ 10,000,000 | `Unknown` | Future-proofing; zero rows expected in 2023+ data |

---

## Fact_OutstandingTransfers

**Source:** `Parts_InterbranchTransfers` (Lakehouse) joined to `InSalPar` (direct ODBC)
**Grain:** One row per outstanding part line (`PartTicket` + `Line_No` is the composite key)
**Rows:** Current outstanding only — completed transfers are not included
**Dataflow:** `df_Fact_Transfers` (same dataflow as Fact_Transfers)

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `DateKey` | Int64 | Yes | YYYYMMDD integer derived from `InSalPar.Creation_Datetime`. Foreign key → `dim_DateTable[DateKey]`. |
| `Date` | Date | Yes | Transfer order creation date (when the line was placed in InSalPar). |
| `TransDatetime` | DateTime | Yes | Full creation timestamp from `InSalPar.Creation_Datetime`. |
| `PartTicket` | Int64 | No | Transfer order/ticket number. Corresponds to `InSalOrd` FILE_NO and `Parts_InterbranchTransfers.PartTicket`. One ticket can have multiple rows (one per part line). |
| `Line_No` | Int64 | Yes | Line number within the transfer ticket. Together with `PartTicket`, forms the composite grain key. |
| `RequestingBranch` | Text | No | Branch that requested the parts (waiting to receive). Foreign key → `dim_BranchLocation[BranchID]` (active relationship). |
| `SupplyingBranch` | Text | No | Branch sending the parts. Foreign key → `dim_BranchLocation[BranchID]` (inactive — use `USERELATIONSHIP` to filter by supplying branch). |
| `PartNumber` | Text | Yes | Part number being transferred. Upper-cased. Foreign key → `dim_Parts[PartNumber]`. |
| `TransferSubType` | Text | Yes | Same classification as `Fact_Transfers`: `Work Order`, `Counter`, `Stock`, `Unknown`. Derived from `InSalPar.SO_RO_Ref` using identical numeric range logic. |
| `FulfillmentStatus` | Text | No | Shipment status of this part line. **Computed in the dataflow** (not a DAX calculated column). Values: `Pending`, `Partial`, `Shipped`. See details below. |
| `OrderQty` | Number | Yes | Total quantity ordered for this part line (`InSalPar.ORDER_QTY`). |
| `ShippedQty` | Number | Yes | Quantity dispatched from the supplying branch (`InSalPar.SHIPPED_QTY`). |
| `SuppliedQty` | Number | Yes | Quantity confirmed received at the requesting branch (`InSalPar.SUPPLIED_QTY`). Always < `ShippedQty` for all rows in this table (by construction of the outstanding filter). |
| `OpenQty` | Number | No | Per-line outstanding quantity = `ShippedQty - SuppliedQty`. Always > 0 by construction. This is the quantity in transit between branches. |
| `OrderAge` | Int64 | Yes | Days since the transfer order was placed. **Calculated by the source system**, not derived from `Date` in Power BI. Reflects the age of the ticket, not the individual line. |

### Calculated Columns (DAX)

| Column | Expression | Values | Notes |
|--------|------------|--------|-------|
| `Aging Bucket` | `SWITCH(TRUE(), OrderAge ≤ 7, "0–7 Days", OrderAge ≤ 30, "8–30 Days", OrderAge ≤ 60, "31–60 Days", "61+ Days")` | 0–7 Days, 8–30 Days, 31–60 Days, 61+ Days | Used for conditional formatting color bands on the table |

### FulfillmentStatus Values

| Value | Condition | Interpretation |
|-------|-----------|---------------|
| `Pending` | `ShippedQty = 0` or null | Nothing has left the supplying branch yet |
| `Partial` | `0 < ShippedQty < OrderQty` | Some quantity has shipped, remainder still at supplying branch |
| `Shipped` | `ShippedQty = OrderQty` | Full order quantity dispatched — in transit, awaiting confirmation at requesting branch |

> **Important:** `Shipped` does **not** mean received. All rows in this table have `SuppliedQty < ShippedQty`, meaning receipt has not been confirmed regardless of fulfillment status.

### Outstanding Filter Logic

Only records meeting both conditions appear in this table:
1. `Parts_InterbranchTransfers.InTransitQuantity > 0` — ticket is outstanding at the ticket level
2. `InSalPar.SHIPPED_QTY > InSalPar.SUPPLIED_QTY` — this specific part line is still in transit

---

## Inv_Snapshot

**Source:** `jdis_Part_Information` (Lakehouse table)
**Grain:** One row per part per branch (current on-hand snapshot)
**Scope:** Rows where `InventoryCost ≠ 0` only (zero-cost rows filtered out)
**Dataflow:** `df_Fact_Transfers` (same dataflow as the two fact tables above)

> **Point-in-time table.** This is a daily snapshot of current inventory — it does not contain history. The date slicer does not affect `Inv_Snapshot` values.

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `Branch` | Text | No | Branch code holding this inventory. Foreign key → `dim_BranchLocation[BranchID]`. |
| `PartNumber` | Text | No | Part number. Foreign key → `dim_Parts[PartNumber]`. |
| `QuantityOnHand` | Number | No | Current on-hand quantity at this branch for this part. Formatted as integer (#,0). |
| `InventoryCost` | Number | No | Current on-hand inventory value at cost ($#,##0.00). Rows where this equals zero are excluded from the table. |

---

## Key DAX Measures (Reference)

These measures are defined in `_Measures.tmdl`. This is not an exhaustive list — see the TMDL file for the full measure library.

### Fact_Transfers Measures

| Measure | Logic | Used On |
|---------|-------|---------|
| Transfer Qty | `SUM(Fact_Transfers[Qty])` filtered to Type = "T" | Pages 1, 2 |
| Transfer Lines | `COUNTROWS(Fact_Transfers)` filtered to Type = "T" | Pages 1, 2 |
| Transfer Cost | `SUM(Fact_Transfers[CostValue])` filtered to Type = "T" | Pages 1, 2 |
| Transfers In | Transfer activity where `TransferBranch` = selected branch (uses `USERELATIONSHIP`) | Page 1 balance chart |
| Transfers Out | Transfer activity where `Branch` = selected branch | Page 1 balance chart |

### Fact_OutstandingTransfers Measures

| Measure | Logic | Used On |
|---------|-------|---------|
| FulfillmentStatus Color Key | `SWITCH(SELECTEDVALUE(FulfillmentStatus), "Shipped", 1, "Pending", 2, "Partial", 3)` | Page 3 conditional formatting |
| Age Band | Numeric bucket (1–4) mapped from `Aging Bucket` values | Page 3 conditional formatting |

### Inv_Snapshot Measures

| Measure | Logic | Used On |
|---------|-------|---------|
| Total Inventory Qty | `SUM(Inv_Snapshot[QuantityOnHand])` | Page 2 |
| Total Inventory Cost | `SUM(Inv_Snapshot[InventoryCost])` | Page 2 |

---

## Shared Dimensions (Reference)

These dimensions are shared across multiple reports in the data model. Full definitions are in the shared query library (`.claude/queries/dimensions/`).

| Dimension | Key Column | Description |
|-----------|-----------|-------------|
| `dim_DateTable` | `DateKey` (Int64, YYYYMMDD) | Universal date dimension with Year, Quarter, Month, Week, Day hierarchy |
| `dim_BranchLocation` | `BranchID` (Text) | Branch/location dimension including sub-branches (8I, 95I, etc.) |
| `dim_Parts` | `PartNumber` (Text) | Parts master including Description, Franchise, and part attributes |
