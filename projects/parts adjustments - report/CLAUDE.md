# Parts Adjustments — Claude Context

## Report Overview
- **Business purpose:** Tracks inventory adjustments by PA type (Stock Check, Customer BIN, Damaged, Lost, Overage, Count Off) across branches — measuring adjustment cost and line count, trending over time, and benchmarking against total inventory value.
- **Primary users:** Parts managers, inventory control, branch managers
- **Workspace:** RP - Parts Reports
- **Refresh tier:** Tier 1 — Daily by 5 AM
- **Status:** Production

## Semantic Model
**Path:** `reports/current/Parts Adjustments.SemanticModel/definition/`

### Fact Tables
| Table | Grain | Key Fields | Notes |
|-------|-------|------------|-------|
| `Fact_PartsAdjustments` | One row per adjustment transaction | CostValue, AbsCost, PositiveCost, NegativeCost, Qty, AbsQty, PAType, TransDatetime, RONumber | InTrans joined to GlTrans on RONumber=DocRef. GlTrans.SubAccount → PAType. |

### Dimensions
| Table | Source | Key Relationship |
|-------|--------|-----------------|
| `dim_BranchLocation` | Shared Lakehouse | Branch filter |
| `dim_DateTable` | Shared Lakehouse | Date dimension |
| `dim_AdjustmentType` | Lakehouse | PA Type dimension — `AdjustmentTypeName` used in HTML measure CALCULATE filters |
| `dim_Parts` | Shared Lakehouse | Parts lookup |
| `dim_PAType` | Calculated table | Sort-order override: Stock Check=1, others alphabetical 2–7 |
| `jdis_Part_Information` | JDIS (1M+ rows) | Inventory cost and on-hand qty for benchmark measures |
| `MetricSelector` | Calculated | Dollar/Qty/Lines switcher (drives `_DynamicTotal`, `_DynamicPositive`, `_DynamicNegative`) |
| `MeasureSelector` | Calculated | Index for Selected Measure (% to inventory ratios) |
| `_Measures` | Dummy partition | Holds all DAX measures |

### PA Type Classification (from GlTrans.SubAccount)
| SubAccount | PA Type |
|-----------|---------|
| 1 | Stock Check |
| 2 | Customer BIN |
| 3 | Damaged |
| 4 | Lost |
| 5 | Overage |
| 6 | Count Off |
| null/other | Unknown |

### Key Measures
| Measure | Description |
|---------|-------------|
| `Total Adjustments $ (R12)` | Positive + ABS(Negative) adjustment cost, last 12 months |
| `Total Adjustment Lines (R12)` | COUNTROWS where Qty <> 0, last 12 months |
| `Absolute Adjustment $` | SUMX(ABS(CostValue)) — no R12 filter, for trend chart time axis |
| `Total Adjustment Lines` | COUNTROWS — no R12 filter, for trend chart |
| `Total Inventory $` | SUM(jdis_Part_Information[InventoryCost]) |
| `Adjustment $ to Inventory $` | Total Adjustments $ (R12) / Total Inventory $ |
| `Adjustment Lines to Inventory Lines` | Total Adjustment Lines (R12) / Total Parts |
| `_DynamicTotal` | Switches between Dollar/Qty/Lines based on MetricSelector |

## Report Pages
| Page | Purpose | Visibility |
|------|---------|------------|
| Parts Adjustments - Overview | Hero cards + PA Type breakdown; metric switcher | Visible |
| Parts Adjustments - Details | Transaction-level table filtered by PA Type tabs | Visible |
| Parts Adjustments - % by Branch | Branch adjustment % vs. inventory benchmarks | Visible |
| Parts Adjustments - Trends | Year-over-year cost and lines trend chart (added March 2026) | Visible |

## Data Flow
```
EquipRDB (ODBC) → InTrans (Lakehouse)  ─┐
                                         ├─ LEFT JOIN on RONumber=DocRef → Fact_PartsAdjustments
EquipRDB (ODBC) → GlTrans (Lakehouse)  ─┘
JDIS → jdis_Part_Information (Lakehouse) → benchmark measures only
```

## Known Issues & Gotchas
- **GlTrans deduplication required:** GlTrans has ~2K unique DocRefs but can have multiple rows per DocRef. It must be deduplicated in the dataflow before joining to InTrans (~527K rows) to prevent row explosion.
- **R12 vs. trend measures:** Two separate sets — R12 measures (DATESINPERIOD filter) for KPI cards, and unfiltered measures (Absolute Adjustment $, Total Adjustment Lines) for the Trends page time axis. Do not use R12 measures on time-axis visuals.
- **HTML measures reference AdjustmentTypeName:** The card visuals on Overview use an HTML measure that hard-references `AdjustmentTypeName` values from `dim_AdjustmentType` in CALCULATE filters. If those values change, the HTML measure breaks.
- **dim_PAType sort table:** Added March 2026 to control PAType slicer order (Stock Check first). This is a calculated table, not a Lakehouse table.

## Refresh Pipeline Position
- Tier 1: Daily by 5 AM
- `Fact_PartsAdjustments` built in Phase 4 (Facts wave)
- Depends on InTrans and GlTrans both refreshing in Phase 1 (Raw)

## Documentation Status
- In-repo docs: ✅ CLAUDE.md | ✅ PROJECT-SUMMARY.md
- Obsidian stakeholder docs: ✅ Complete — `Data Projects/Reports/Parts Adjustments.md`
