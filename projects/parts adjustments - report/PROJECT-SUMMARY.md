# Parts Adjustments Report — Project Summary

## Purpose

Tracks all inventory adjustments by type, branch, and time period. Measures the dollar cost and line count of adjustments across six PA types, compares gross positive/negative splits, and benchmarks adjustment activity against total inventory value.

**Key question answered:** "How much inventory are we adjusting — by type, by branch, and is it trending better or worse over time?"

## Current Status (March 2026)

Production report, refreshed daily by 5 AM. Four pages: Overview, Details, % by Branch, Trends.

Recent additions:
- **Trends page (March 2026):** Line chart page showing annual cost and lines trend. `Total Adjustment Lines` measure added (no R12 filter) alongside existing `Absolute Adjustment $` for use on time-axis visuals.
- **PAType sort order (March 2026):** `dim_PAType` calculated table added to sort PAType slicer with Stock Check first, remaining types alphabetically.

## Report Pages

| Page | Purpose |
|------|---------|
| Parts Adjustments - Overview | Hero cards + PA Type breakdown cards; metric switcher (Dollar / Qty / Lines) |
| Parts Adjustments - Details | Transaction-level drill table filtered by PA Type tabs |
| Parts Adjustments - % by Branch | Branch-level adjustment % vs. inventory benchmarks |
| Parts Adjustments - Trends | Year-over-year cost and lines trend chart |

## Semantic Model

**Location:** `reports/current/Parts Adjustments.SemanticModel/`

### Tables

| Table | Source | Notes |
|-------|--------|-------|
| `Fact_PartsAdjustments` | `LH_Master_Data.Fact_PartsAdjustments` | Main fact; InTrans joined to GlTrans on RONumber = DocRef |
| `jdis_Part_Information` | `LH_Master_Data.jdis_Part_Information` | Parts catalog; provides `InventoryCost`, `QuantityOnHand` for benchmarks |
| `dim_BranchLocation` | `LH_Master_Data.dim_BranchLocation` | Branch filter |
| `dim_DateTable` | `LH_Master_Data.dim_DateTable` | Date dimension |
| `dim_AdjustmentType` | Lakehouse | PA Type dimension; `AdjustmentTypeName` used in HTML measure CALCULATE filters |
| `dim_Parts` | `LH_Master_Data.dim_Parts` | Parts lookup |
| `dim_PAType` | Calculated table | Sort-order table for PAType slicer; Stock Check = 1, others alphabetical 2–7 |
| `MetricSelector` | Calculated | Dollar / Qty / Lines switcher for dynamic measures |
| `MeasureSelector` | Calculated | Index for Selected Measure (% to inventory ratios) |
| `_Measures` | Calculated (dummy partition) | Holds all DAX measures |

### PA Type Classification

Derived from `GlTrans.SubAccount` in the dataflow:

| SubAccount | PA Type |
|-----------|---------|
| 1 | Stock Check |
| 2 | Customer BIN |
| 3 | Damaged |
| 4 | Lost |
| 5 | Overage |
| 6 | Count Off |
| null / other | Unknown |

### Key Columns in Fact_PartsAdjustments

| Column | Description |
|--------|-------------|
| `CostValue` | Raw adjustment cost (positive or negative) |
| `AbsCost` | `ABS(CostValue)` — gross cost regardless of direction |
| `PositiveCost` | CostValue where positive only (else 0) |
| `NegativeCost` | CostValue where negative only (else 0) |
| `Qty` | Raw adjustment quantity (positive or negative) |
| `AbsQty` | `ABS(Qty)` |
| `PositiveQty` / `NegativeQty` | Split quantities |
| `IsPositiveQty` / `IsNegativeQty` | Boolean flags |
| `PAType` | Derived text classification (from SubAccount) |
| `TransDatetime` | Transaction date/time |
| `RONumber` | Links to GlTrans.DocRef for SubAccount classification |

### Key Measures (in _Measures.tmdl)

**R12 measures** (DATESINPERIOD filter, -12 months from MAX TransDatetime):
- `Total Adjustments $ (R12)` = Positive + ABS(Negative) adjustment cost
- `Total Adjustment Lines (R12)` = COUNTROWS with Qty <> 0
- `Positive Adjustment $ (R12)` / `Negative Adjustment $ (R12)` / `Total Qty (R12)` — splits

**Trend measures** (no time filter — respond to chart axis context):
- `Absolute Adjustment $` = `SUMX(Fact_PartsAdjustments, ABS(CostValue))` — gross cost for trend chart
- `Total Adjustment Lines` = `COUNTROWS(Fact_PartsAdjustments)` — gross lines for trend chart

**Inventory benchmarks:**
- `Total Inventory $` = `SUM(jdis_Part_Information[InventoryCost])`
- `Adjustment $ to Inventory $` = `Total Adjustments $ (R12) / Total Inventory $`
- `Adjustment Lines to Inventory Lines` = `Total Adjustment Lines (R12) / Total Parts`

**Dynamic metric switcher** (`MetricSelector` drives `_DynamicTotal`, `_DynamicPositive`, `_DynamicNegative`):
- Switches between Dollar, Qty, and Lines modes across all PA Type cards and charts

## Source Join Logic

```
InTrans (527K rows)  ← LEFT JOIN →  GlTrans (deduplicated to ~2K unique DocRefs)
     RONumber                              DocRef
```

GlTrans is deduplicated before the join to prevent row explosion. The `SubAccount` column from GlTrans determines PA Type. `Unknown` results when a matching DocRef is not found.

## Refresh Schedule

- **Tier 1 — Daily:** 5 AM via `Pipeline_Master_Orchestrator`
- Expected refresh time: 2–5 minutes

## Files in This Project

```
projects/parts adjustments - report/
├── PROJECT-SUMMARY.md                      # This file
├── queries/
│   └── fact table/
│       └── Fact_PartsAdjustments.pq        # Dataflow query (gold-standard ref)
└── reports/
    ├── archive/                            # Prior version of semantic model
    └── current/
        ├── Parts Adjustments.pbix
        ├── Parts Adjustments.Report/
        └── Parts Adjustments.SemanticModel/
            └── definition/
                └── tables/
                    ├── _Measures.tmdl
                    ├── Fact_PartsAdjustments.tmdl
                    ├── dim_BranchLocation.tmdl
                    ├── dim_DateTable.tmdl
                    ├── dim_AdjustmentType.tmdl
                    ├── dim_Parts.tmdl
                    └── jdis_Part_Information.tmdl
```
