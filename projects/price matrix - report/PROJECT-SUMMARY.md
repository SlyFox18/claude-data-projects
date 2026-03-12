# Price Matrix Report — Project Summary

## Purpose

Analyzes parts pricing strategy performance across price tiers. Compares actual margin achieved to the effective list price baseline to measure how much revenue and margin the matrix pricing strategy is generating.

**Key question answered:** "Is our price matrix working — are we hitting target margins by price tier?"

## Current Status (March 2026)

Production report, refreshed weekly (Monday). Four pages: Sales, Inventory, Charts, Calculator.

Recent additions:
- **SalesType slicer (March 2026):** `SalesType` column already present in `Fact_Part_Transactions` with values "Work Order" and "Over the Counter". No DAX changes needed — direct slicer on the column filters all page visuals.

## Report Pages

| Page | Purpose |
|------|---------|
| Price Matrix - Sales | Main analysis table — actual vs. expected margin by price tier |
| Price Matrix - Inventory | Inventory health by tier — turn, stock levels, aging |
| Price Matrix - Charts | Visual summary for leadership |
| Price Matrix - Calculator | What-if pricing scenarios |

## Semantic Model

**Location:** `reports/current/Price Matrix.SemanticModel/`

### Tables

| Table | Source | Notes |
|-------|--------|-------|
| `Fact_Part_Transactions` | `LH_Master_Data.Fact_Part_Transactions` | FranchiseKey=7 (JD only), Type IN ('C','I'), last 13 months |
| `Fact_Inventory` | `LH_Master_Data.Fact_Inventory` | Current inventory snapshot; ListPrice used to classify into tiers |
| `Price_Matrix` | OneDrive CSV | Tier ranges and target markup %; source of truth for pricing strategy |
| `dim_BranchLocation` | `LH_Master_Data.dim_BranchLocation` | Branch filter |
| `dim_Parts` | `LH_Master_Data.dim_Parts` | Parts lookup |
| `dim_Franchise` | `LH_Master_Data.dim_Franchise` | Franchise lookup |
| `dim_DateTable` | `LH_Master_Data.dim_DateTable` | Date dimension |
| `MeasuresTable` | Calculated (GENERATESERIES dummy) | Holds all DAX measures |
| `Range Selection` | Calculated | Price range selector |
| `New Markup %` | Calculated | Calculator page inputs |

### Key Columns in Fact_Part_Transactions

| Column | Description |
|--------|-------------|
| `SalesType` | "Work Order" or "Over the Counter" — derived from TransactionDescription in dataflow |
| `EffectiveListSalVal` | What the sale would have been at effective list price |
| `EffectiveListMargin` | EffectiveListSalVal - CostAmount |
| `MatrixSaleGained` | Actual SaleAmount - EffectiveListSalVal (extra revenue from matrix) |
| `MatrixMarginGained` | Extra margin from matrix pricing |
| `TransactionTradeType` | Trade type at transaction level (W = warranty, affects effective list calc) |

### Fact Table Source Filter Logic

```powerquery
FilteredRows = Table.SelectRows(source, each [TransactionDate] >= Date.AddMonths(Date.From(DateTime.LocalNow()), -13)),
#"Filtered Rows" = Table.SelectRows(FilteredRows, each ([FranchiseKey] = 7) and ([Type] = "C" or [Type] = "I"))
```

### Key Measures (in MeasuresTable.tmdl)

All "for Parts in Range" measures follow the same pattern:
1. Determine the current price range from `SELECTEDVALUE(Price_Matrix[value_from/to])`
2. Build a virtual table of parts whose inventory ListPrice falls in that range (with 12-month sales activity)
3. Filter `Fact_Part_Transactions` to only those parts

Core measures:
- `Transaction Sales $ for Parts in Range` — actual revenue
- `Transaction Margin % for Parts in Range` — actual weighted margin %
- `Effective List Margin % for Parts in Range` — baseline margin at list pricing
- `Matrix Margin % Gained` — actual - effective list (measures matrix effectiveness)
- `Turn for Parts in Range (12 Month)` — 12-month inventory turn

## Business Logic Reference

### How Parts Are Classified

- Parts classified by **current ListPrice** from `Fact_Inventory`
- Only parts with `Current12MoSales > 0` are included (active parts only)
- A part with ListPrice $125 → goes into the $100–$149.99 tier

### Effective List Calculation (in Fact_Part_Transactions dataflow)

```
EffectiveListSalVal =
  IF TradeType = "W" (warranty): use actual SaleAmount
  ELSE: SaleAmount × (1 - % Change)
  where % Change = (SellPrice1SaleVal - ListSaleVal) / SellPrice1SaleVal

MatrixSaleGained = SaleAmount - EffectiveListSalVal
```

### Price_Matrix CSV

Source of truth for tier ranges and target markups. Stored in OneDrive, read directly by the semantic model. Changes to pricing strategy require updating this file — no dataflow changes needed.

## Refresh Schedule

- **Tier 3 — Weekly:** Monday at 5 AM via `Pipeline_Master_Orchestrator`
- Runs after all Tier 1 and Tier 2 reports complete
- `Fact_Part_Transactions` pulls last 13 months at each weekly refresh

## Documentation

- **Calculation detail:** `Price Matrix - Sales Report - Calculation Documentation.md` (this folder) — measure-by-measure breakdown with examples and stakeholder notes
- **Obsidian vault:** `Data Projects/Reports/Price Matrix.md` — stakeholder-friendly overview

## Files in This Project

```
projects/price matrix - report/
├── PROJECT-SUMMARY.md                                    # This file
├── Price Matrix - Sales Report - Calculation Documentation.md   # Detailed measure docs
├── queries/
│   └── fact tables/
│       └── Fact_Part_Transactions.pq                    # Dataflow query (gold-standard ref)
└── reports/current/
    ├── Price Matrix.pbix
    ├── Price Matrix.Report/
    └── Price Matrix.SemanticModel/
```
