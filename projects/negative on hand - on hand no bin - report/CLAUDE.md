# Negative On Hand / On Hand No Bin — Claude Context

## Report Overview
- **Business purpose:** Inventory exception report that surfaces two distinct data quality issues: (1) parts with a negative bin quantity, and (2) parts with quantity on hand but no bin location assigned. Both conditions indicate a discrepancy between the physical inventory system and what the ERP records show.
- **Primary users:** Parts managers, branch inventory coordinators
- **Workspace:** RP - Parts Reports
- **Refresh tier:** Tier 1 — Daily by 5 AM
- **Status:** Production

## Semantic Model

### Fact Tables
| Table | Grain | Key Fields | Notes |
|-------|-------|------------|-------|
| `Fact_NegativeOnHand_OnHandNoBin` | One row per part-branch combination with an inventory issue | Branch, PartNumber, IssueType, IssueSeverity | Pre-classified in the dataflow — flags, severity, and `InventoryValueAtRisk` are computed upstream, not in DAX |

### Dimensions
| Table | Source | Key Relationship |
|-------|--------|-----------------|
| `dim_BranchLocation` | Shared Lakehouse dimension | `Fact_NegativeOnHand_OnHandNoBin.Branch` → `BranchID` |
| `dim_DateTable` | Shared Lakehouse dimension | No direct relationship to fact (point-in-time snapshot) |
| `Data Refresh` | Calculated table | Refresh timestamp display |

### Key Measures (organized by display folder)

**Basic Issue Counts**
| Measure | Description |
|---------|-------------|
| `Total Parts with Issues` | Count of all rows in the fact (all parts with either issue type) |
| `Parts with Negative Bin Qty` | Count where `HasNegativeBinQty = TRUE` |
| `Parts with On Hand No Bin` | Count where `HasBinQtyNoBin = TRUE` |
| `Parts with Both Issues` | Count where `IssueType = "Both Issues"` |

**Quantity Aggregations**
| Measure | Description |
|---------|-------------|
| `Total Negative Bin Qty` | Sum of bin quantities for negative-bin parts (will be negative) |
| `Total Qty No Bin` | Sum of bin quantities for no-bin parts |
| `Avg Negative Qty per Part` | Average negative bin quantity per affected part |
| `Avg Qty No Bin per Part` | Average unassigned quantity per affected part |
| `Total Qty on Hand` | Sum of `QuantityOnHand` across all issue rows |
| `Total Bulk Bin Qty` | Sum of bulk bin quantities |
| `Total Pending Qty` | Sum of pending quantities |

**Financial Impact**
| Measure | Description |
|---------|-------------|
| `Total Negative Inventory Value` | `ABS(BinQty) * Cost` for negative-bin parts — dollar value of the discrepancy |
| `Total Value No Bin` | `BinQty * Cost` for no-bin parts — dollar value of unlocated inventory |
| `Total Inventory Value at Risk` | Sum of pre-computed `InventoryValueAtRisk` column (from dataflow) |
| `Avg Value at Risk per Part` | Average inventory value at risk per affected part |

**Severity & Priority**
| Measure | Description |
|---------|-------------|
| `Critical Issues` | Count where `IssueSeverity = "Critical"` |
| `High Severity Issues` | Count where `IssueSeverity IN {"High", "High Volume"}` |
| `Parts Recently Requested` | Count where `DaysSinceLastRequest <= 30` — active parts with issues |
| `Parts with Back Orders` | Count where `BackOrderQty > 0` — issue parts also on backorder |
| `Total Back Order Qty` | Sum of backorder quantities across issue parts |

## Report Pages
| Page | Display Name | Purpose | Visibility |
|------|-------------|---------|------------|
| e384167396533ecc066e | Negative on Hand - On Hand no Bin | Single-page exception dashboard | Visible |

## Data Flow
```
EquipRDB (ODBC)
  └─ Parts inventory / bin location source tables
                │
                ▼
  LH_Master_Data (Lakehouse)
  └─ Fact_NegativeOnHand_OnHandNoBin
       (dataflow classifies IssueType, IssueSeverity, InventoryValueAtRisk)
                │
                ▼
  dim_BranchLocation (shared) ──────────┐
                                         ▼
                              Negative On Hand Report
```

**Key design pattern:** Issue classification (`IssueType`, `IssueSeverity`, `HasNegativeBinQty`, `HasBinQtyNoBin`, `InventoryValueAtRisk`) is handled in the **dataflow**, not in DAX. The fact table arrives pre-classified. This keeps DAX measures simple (mostly COUNTROWs and SUM) but means any changes to classification logic require a dataflow edit, not a model edit.

## Known Issues & Gotchas

### No Date Relationship
`Fact_NegativeOnHand_OnHandNoBin` has `DateCreated`, `DateLastRequested`, and `DaysSinceLastRequest` columns but none are related to `dim_DateTable`. The report is a point-in-time snapshot — it always shows current state as of the most recent refresh. `DaysSinceLastRequest` is a pre-computed integer from the dataflow.

### `IssueType` / `IssueSeverity` Values
These are categorical string columns computed in the dataflow. Known `IssueType` value: `"Both Issues"` (part has both negative bin and no-bin). Known `IssueSeverity` values: `"Critical"`, `"High"`, `"High Volume"`. If the dataflow classification rules change, measures referencing these literal strings will silently stop filtering correctly.

### `InventoryValueAtRisk` Pre-computed Column
`InventoryValueAtRisk` is a pre-computed dollar column in the fact table (from the dataflow), while `Total Negative Inventory Value` and `Total Value No Bin` are computed in DAX from `BinQty * Cost`. These may not reconcile if the dataflow's at-risk calculation uses different logic than `ABS(BinQty) * Cost`.

## Refresh Pipeline Position
- **Phase:** Phase 4 (Facts) — `Fact_NegativeOnHand_OnHandNoBin` refreshes in one of the 5 fact waves
- **Dependencies:** `dim_BranchLocation` must be fresh (Phase 3)
- **Phase 5:** Semantic model refresh after fact phases complete

## Documentation Status
- In-repo docs: ✅ CLAUDE.md | ✅ PROJECT-SUMMARY.md
- Obsidian stakeholder docs: ✅ Complete — `Data Projects/Reports/Negative On Hand.md`
