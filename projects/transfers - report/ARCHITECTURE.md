# Transfers Report — Architecture Reference

**Last Updated:** 03/04/2026
**Purpose:** Documents the key design decisions, data architecture, and technical gotchas for this report. Read this before modifying any queries or the semantic model.

---

## Data Flow

```
Source System (ODBC: dsn=EquipRDB64)
    │
    ├── Parts_InterbranchTransfers  ──┐
    │   (VIEW on InSalOrd Type='T')  │
    │                                 ├──> df_Fact_Transfers ──> Lakehouse (LH_Master_Data)
    ├── InSalPar (direct in DF)      │        │
    │                                 │        ├── Fact_Transfers
    ├── InTrans_Incremental  ─────────┘        ├── Fact_OutstandingTransfers
    │   (Lakehouse, Phase 2)                   └── Inv_Snapshot
    │
    └── jdis_Part_Information  ────────────────────────────────> Inv_Snapshot
        (Lakehouse, Phase 1)

Lakehouse Tables
    │
    └──> Transfers.SemanticModel ──> Transfers.Report (RP - Sandbox / RP - Parts Reports)
```

---

## Fact_Transfers

### Source
`InTrans_Incremental` — the Lakehouse table built by the incremental refresh pipeline (Phase 2). Contains 10M+ rows of all inventory transactions across all branches going back several years.

### Scope
- **Date range:** 2023-01-01 forward. Pre-2023 data has different SoRoRef numbering patterns (5-digit counter orders — last seen 7/11/2022) and less consistent OrderQty/ShippedQty population.
- **Transaction types included:** `T` (transfers), `I` (invoices/counter sales), `C` (credits), `P` (purchases from supplier). All four are needed — Page 1 uses only `T`, but Page 2 compares transfer volume against broader sales and purchasing activity.
- **Types excluded:** A (adjustments), R (returns), and all others — not relevant to transfer analysis.

### Transfer Sub-Type Classification

Applies only to `Type = "T"` rows. Non-transfer rows get `null`.

Classification is based on `SoRoRef` — the Sales Order or Repair Order reference number attached to the transfer:

| SoRoRef Value | Sub-Type | Meaning |
|---------------|----------|---------|
| `null`, 0, 1, or < 100,000 | **Stock** | No valid RO/SO reference — replenishment transfer |
| 100,000 – 999,999 (6 digits) | **Work Order** | Repair Order # — service shop demand |
| 1,000,000 – 9,999,999 (7 digits) | **Counter** | Sales Order # — customer-facing demand |
| ≥ 10,000,000 | **Unknown** | Future-proofing; should be zero rows in 2023+ data |

**Why numeric range, not text length:** `SoRoRef` may be stored as a numeric type in the Lakehouse. A numeric range check works correctly regardless of storage type, avoiding text conversion edge cases.

**Why `< 100,000` catches more than just null:** The source system uses `0` and `1` as placeholder values when no real reference exists (102 rows at `0`, 2 rows at `1` in 2023+ data). Treating all values below 100,000 as Stock is more robust than a null check alone.

### Data Quality Notes

- **~12% of Type T rows have NULL `OrderQty` / `ShippedQty`** — this is a source system tracking issue concentrated in 2023 (tracking improved significantly in 2024+). NULLs are **retained as-is** in the fact table. Do NOT default to 0 — that would conflate "not tracked" with "zero ordered."
- **Sub-branch codes** like `8I`, `95I`, `4I`, `93C` are valid and map to `dim_BranchLocation[BranchID]`. Do not strip letters from branch fields.

---

## Fact_OutstandingTransfers

This is the most architecturally complex table in the report. Read this section carefully before modifying the query.

### The Two-Source Design

Outstanding transfer data requires **two source tables**, joined together. Neither source alone is sufficient:

| Source | Role | What it provides | What it lacks |
|--------|------|-----------------|---------------|
| `Parts_InterbranchTransfers` | Ticket header | `RequestingBranch`, `SupplyingBranch`, `OrderAge`, outstanding filter | **No `PartNumber`** — ticket-level summary only |
| `InSalPar` | Part-line detail | `PartNumber`, `OrderQty`, `ShippedQty`, `SuppliedQty`, `SoRoRef`, line date | **No `RequestingBranch`** — can't identify which branch is waiting |

Join key: `InSalPar.FILE_NO = Parts_InterbranchTransfers.PartTicket`

### Why Not InTrans?

InTrans was the first approach attempted. It failed for two reasons:

**Reason 1 — Wrong ID range:** `InTrans.Trans_Id` values are in the 13M+ range. `PartTicket` values are in the 1M–2M range. Joining on `Trans_Id = PartTicket` produces coincidental matches — InTrans records numerically overlapping PartTickets are completely unrelated transactions from approximately 2014.

**Reason 2 — Incomplete coverage:** `InTrans.REF_NO` does equal `PartTicket` for `Type='T'` rows, but InTrans is only populated **after** parts ship. Most outstanding transfers are pre-shipment and have **no InTrans record at all**. Using InTrans as the join target would miss all unshipped pending orders — exactly the records most important to track.

**InSalPar is the correct and complete source.** It contains all part lines for all transfer orders regardless of shipment status.

### The Outstanding Filter — Two Levels

Identifying truly outstanding records requires filtering at two levels:

```
Level 1 (ticket):  Parts_InterbranchTransfers WHERE InTransitQuantity > 0
                   → Identifies which transfer tickets are currently outstanding

Level 2 (line):    InSalPar WHERE SHIPPED_QTY > SUPPLIED_QTY
                   → Identifies which part lines on those tickets are still in transit
                     (shipped from supply branch but not confirmed received)
```

`InTransitQuantity` in `Parts_InterbranchTransfers` is a **ticket-level aggregate** (sum of in-transit qty across all lines). It is used only to identify outstanding ticket numbers — **it is not used for per-line quantity calculations**.

### OpenQty Calculation

Per-line outstanding quantity:

```
OpenQty = SHIPPED_QTY - SUPPLIED_QTY
```

- `SHIPPED_QTY` = quantity dispatched from the supplying branch
- `SUPPLIED_QTY` = quantity confirmed received at the requesting branch
- `OpenQty` > 0 by construction (all rows have `SHIPPED_QTY > SUPPLIED_QTY`)

Do NOT use `InTransitQuantity` for per-line calculations — it is a ticket-level total and would overcount when a ticket has multiple part lines.

### Validated Join (2026-03-03)

Confirmed correct for PartTicket 1459307:
- `Parts_InterbranchTransfers` record: PartTicket 1459307
- `InSalPar` records at FILE_NO 1459307:
  - Line 1: PART_NO=961870, ORDER_QTY=1, SHIPPED=1, SUPPLIED=0 → OpenQty=1
  - Line 2: PART_NO=403279, ORDER_QTY=2, SHIPPED=2, SUPPLIED=0 → OpenQty=2
- These exactly match the InTransitQuantity values in `Parts_InterbranchTransfers`

### FulfillmentStatus

Added at the **dataflow level** (not as a DAX calculated column) — this is intentional. FulfillmentStatus is a business fact about the state of the order line, not a display preference. Computing it in Power Query means:
- It is persisted in the Delta table (no recalculation at model refresh)
- Slicers and filters on it perform at native column speed
- Any future report using `Fact_OutstandingTransfers` gets the status automatically

| Status | Condition |
|--------|-----------|
| **Pending** | `ShippedQty = 0` or null — nothing dispatched yet |
| **Partial** | `0 < ShippedQty < OrderQty` — partially dispatched |
| **Shipped** | `ShippedQty = OrderQty` — fully dispatched, awaiting receipt |

Note: "Shipped" rows are still **outstanding** — they have shipped from the supply branch but have not yet been confirmed received (`SUPPLIED_QTY < SHIPPED_QTY`). The table only contains rows where `SHIPPED_QTY > SUPPLIED_QTY`.

---

## Inv_Snapshot

Built from `jdis_Part_Information` — the current on-hand inventory snapshot by part and branch. Used on Page 2 to provide inventory context alongside transfer volume (e.g., what % of on-hand inventory at a branch is being transferred in/out).

This table is a point-in-time snapshot refreshed daily — it does not have historical versions.

---

## Single Dataflow Architecture

All three fact tables (`Fact_Transfers`, `Fact_OutstandingTransfers`, `Inv_Snapshot`) are built by a **single dataflow: `df_Fact_Transfers`**.

**Implications:**
- A single `RefreshDataflow` pipeline activity (`Refresh_Fact_Transfers`) updates all three tables simultaneously
- If the dataflow fails, all three fact tables are stale — Page 1, 2, and 3 are all affected
- Adding a new fact table query to the report means adding it to this dataflow, not creating a separate one

---

## Semantic Model Relationships

### dim_BranchLocation — Two Roles

`dim_BranchLocation` is used twice in `Fact_Transfers`:

| Relationship | Column | Active | Role |
|-------------|--------|--------|------|
| `Fact_Transfers[Branch]` → `dim_BranchLocation[BranchID]` | Branch | **Yes** | Source branch (where the part came from) |
| `Fact_Transfers[TransferBranch]` → `dim_BranchLocation[BranchID]` | TransferBranch | **No** | Destination branch (where the part is going) |

Only one relationship to the same dimension table can be active at a time. The active relationship is on `Branch` (source) — this is the more commonly filtered direction for "which branch is transferring parts out."

**To filter or slice by destination branch in DAX**, use `USERELATIONSHIP`:

```dax
Transfer Lines to Branch =
CALCULATE(
    [Transfer Lines],
    USERELATIONSHIP(Fact_Transfers[TransferBranch], dim_BranchLocation[BranchID])
)
```

Similarly for `Fact_OutstandingTransfers`:
- Active: `RequestingBranch` → `dim_BranchLocation[BranchID]` (the branch waiting for parts)
- Inactive: `SupplyingBranch` → `dim_BranchLocation[BranchID]` (the branch sending parts)

### No Cross-Table Relationships

`Fact_Transfers`, `Fact_OutstandingTransfers`, and `Inv_Snapshot` are independent fact tables. There are no direct relationships between them — they share dimensions but do not join to each other in the model. Cross-fact comparisons are done in DAX using shared dimension filters.

---

## Branch 12 Exclusion

Branch 12 (O'Donnell) is an internal supply/warehouse location covered by the separate **Combine Vault Sales** report. It is excluded from **both** fact tables to prevent it from skewing branch-to-branch metrics.

The exclusion uses `Text.StartsWith([Branch], "12")` to catch all sub-branch variants (`12`, `12I`, `12S`, etc.). There is no ambiguity risk — legitimate branch IDs only go to 97; no `120`/`121` range exists.

The exclusion applies to **both sides** of a transfer:
- In `Fact_Transfers`: filters out records where `Branch` **or** `TransferBranch` starts with `"12"`
- In `Fact_OutstandingTransfers`: filters out records where `RequestingBranch` **or** `SupplyingBranch` starts with `"12"`

---

## SoRoRef Classification — Consistency Between Fact Tables

Both fact tables use the **identical numeric range logic** to classify `TransferSubType`, but they read `SoRoRef` from different source columns:

| Fact Table | SoRoRef Source | Notes |
|-----------|---------------|-------|
| `Fact_Transfers` | `InTrans_Incremental.SoRoRef` | Column exists in InTrans Lakehouse table |
| `Fact_OutstandingTransfers` | `InSalPar.SO_RO_Ref` | Pulled direct from ODBC in the dataflow |

The classification ranges are identical (< 100K = Stock, 100K–999K = Work Order, 1M–9.9M = Counter) and have been validated against the 2023+ dataset. If the source system ever changes its numbering scheme, both queries must be updated together.

---

## Pipeline Integration

Added to all three pipeline phases on 2026-03-04:

```
Pipeline_Raw_Data
  └── Refresh_Parts_InterbranchTransfer_Raw
        Batch 1 (no dependency — runs at pipeline start)
        dataflowId: e50d9c54-2d47-8416-4a98-992636254981

Pipeline_Facts
  └── Refresh_Fact_Transfers
        Wave C (depends on dims completing)
        dataflowId: ce778550-1811-9ac7-4a01-096e0d3d6a4f
        → builds Fact_Transfers + Fact_OutstandingTransfers + Inv_Snapshot

Pipeline_SemanticModels
  └── Refresh_Transfers_SM
        Wave A4 (depends on all facts completing)
        workspace:  ba9d8de4-ef13-44e6-9156-e23a2511f3ad  (RP - Sandbox)
        dataset_id: 46ceabde-9d36-b8e7-46ea-817eeb9b5dfe
```

When promoting to production, the `workspace_id` and `dataset_id` in `Refresh_Transfers_SM` must be updated to point to the production workspace.

---

## Key Decisions Log

| Decision | Alternatives Considered | Reason Chosen |
|----------|------------------------|---------------|
| Two-source join (Parts_InterbranchTransfers + InSalPar) for Outstanding Transfers | InTrans-based join | InTrans has wrong ID range and misses pre-shipment rows |
| `FulfillmentStatus` at dataflow level | DAX calculated column | Business rule about data state; better filter performance; reusable across reports |
| Numeric range for SoRoRef classification | Text length check | Works regardless of column storage type; handles null/zero placeholders cleanly |
| Single dataflow for all 3 fact tables | Separate dataflows | Reduces pipeline complexity; all three tables share the same refresh cadence |
| Active relationship on `Branch` (not `TransferBranch`) | Active on destination | Source branch is the more commonly filtered dimension; use USERELATIONSHIP for destination |
| Date range from 2023-01-01 | Full history | Pre-2023 has different SoRoRef numbering and inconsistent quantity tracking |
