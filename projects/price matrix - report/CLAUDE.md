# Price Matrix — Claude Context

## Report Overview
- **Business purpose:** Analyzes parts pricing strategy performance — compares actual margin achieved vs. the effective list price baseline to measure how much the matrix pricing strategy is generating in incremental margin. Answers: "Is our price matrix working?"
- **Primary users:** Parts managers, sales leadership, pricing team
- **Workspace:** RP - Parts Reports
- **Refresh tier:** Tier 3 — Weekly (Monday at 5 AM)
- **Status:** Production

## Semantic Model
**Path:** `reports/current/Price Matrix.SemanticModel/`

### Fact Tables
| Table | Grain | Key Fields | Notes |
|-------|-------|------------|-------|
| `Fact_Part_Transactions` | One row per parts transaction | SaleAmount, CostAmount, EffectiveListSalVal, MatrixSaleGained, MatrixMarginGained, SalesType, TransactionTradeType | FranchiseKey=7 (JD only), Type IN ('C','I'), last 13 months. SalesType = "Work Order" or "Over the Counter". |
| `Fact_Inventory` | One row per part × branch | ListPrice (used to classify parts into price tiers), Current12MoSales | On-hand snapshot — ListPrice determines tier assignment |

### Dimensions
| Table | Source | Key Relationship |
|-------|--------|-----------------|
| `Price_Matrix` | OneDrive CSV | Tier ranges + target markup % — source of truth for pricing strategy. No dataflow — read directly by semantic model. |
| `dim_BranchLocation` | Shared Lakehouse | Branch filter |
| `dim_Parts` | Shared Lakehouse | Parts reference |
| `dim_Franchise` | Shared Lakehouse | Franchise reference (JD = FranchiseKey 7) |
| `dim_DateTable` | Shared Lakehouse | Date dimension |
| `Range Selection` | Calculated | Price range selector for visual filtering |
| `New Markup %` | Calculated | Calculator page inputs for what-if scenarios |
| `MeasuresTable` | Calculated (GENERATESERIES dummy) | Holds all DAX measures |

### Key Calculated Columns (in Fact_Part_Transactions — built in dataflow)
| Column | Description |
|--------|-------------|
| `EffectiveListSalVal` | What the sale would have been at effective list price (adjusts for warranty: TradeType=W uses actual) |
| `EffectiveListMargin` | EffectiveListSalVal - CostAmount |
| `MatrixSaleGained` | SaleAmount - EffectiveListSalVal (incremental revenue from matrix) |
| `MatrixMarginGained` | Incremental margin from matrix pricing |
| `SalesType` | "Work Order" or "Over the Counter" (derived from TransactionDescription in dataflow) |

### Key Measures (in MeasuresTable)
| Measure | Description |
|---------|-------------|
| `Transaction Sales $ for Parts in Range` | Actual revenue for parts in the selected price tier |
| `Transaction Margin % for Parts in Range` | Actual weighted margin % for parts in tier |
| `Effective List Margin % for Parts in Range` | Baseline margin if parts were priced at list |
| `Matrix Margin % Gained` | Actual margin % - effective list margin % (positive = matrix is working) |
| `Turn for Parts in Range (12 Month)` | 12-month inventory turn for parts in tier |

All "for Parts in Range" measures share the same pattern:
1. Get selected price range from `Price_Matrix[value_from/to]`
2. Build virtual table of parts in Fact_Inventory whose ListPrice falls in range AND have 12-month sales > 0
3. Filter Fact_Part_Transactions to those parts via TREATAS

## Report Pages
| Page | Purpose | Visibility |
|------|---------|------------|
| Price Matrix - Sales | Main analysis — actual vs. expected margin by price tier | Visible |
| Price Matrix - Inventory | Inventory health by tier — turn, stock levels, aging | Visible |
| Price Matrix - Charts | Visual summary for leadership | Visible |
| Price Matrix - Calculator | What-if pricing scenario tool | Visible |

## Data Flow
```
EquipRDB (ODBC) → InTrans (Lakehouse) → Fact_Part_Transactions (Lakehouse)
EquipRDB (ODBC) → jdis/inventory → Fact_Inventory (Lakehouse)
OneDrive CSV → Price_Matrix (semantic model direct — no Lakehouse staging)
```

## Known Issues & Gotchas
- **Price_Matrix from OneDrive:** The `Price_Matrix` table reads from an OneDrive CSV file directly in the semantic model partition — NOT via a Lakehouse table. If the OneDrive file is moved or renamed, this connection breaks. Changes to pricing tiers require updating this file, not a dataflow.
- **FranchiseKey=7 filter:** Only John Deere parts (FranchiseKey=7) are included. This is intentional — price matrix strategy is JD-specific. Do not remove this filter.
- **13-month rolling window:** The Fact_Part_Transactions partition uses `DateTime.LocalNow()` as the date boundary — this has DST implications. Review when the UTC bug fix applies here. As of this writing, the datetime is used for a date comparison, not display, so impact is minimal.
- **Effective list calculation (warranty):** `TransactionTradeType = "W"` (warranty) uses the actual SaleAmount as the effective list — warranties don't participate in matrix markup, so there's no "gained" amount. Other types: effective list = SaleAmount × (1 - ((SellPrice1SaleVal - ListSaleVal) / SellPrice1SaleVal)).
- **Parts in Range pattern:** The tier classification happens at query time using ListPrice from Fact_Inventory — a part can change tiers if its list price changes. This is intentional.

## Refresh Pipeline Position
- Tier 3: Weekly, Monday at 5 AM
- Runs after all Tier 1 and Tier 2 reports complete
- Depends on Fact_Part_Transactions and Fact_Inventory (Phase 4)

## Documentation Status
- In-repo docs: ✅ CLAUDE.md | ✅ PROJECT-SUMMARY.md
- Obsidian stakeholder docs: ✅ Complete — `Data Projects/Reports/Price Matrix.md`
- Extended calculation docs: `Price Matrix - Sales Report - Calculation Documentation.md`
