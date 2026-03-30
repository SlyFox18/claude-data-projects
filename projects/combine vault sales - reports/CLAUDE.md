# Combine Vault Sales — Claude Context

## Report Overview
- **Business purpose:** Tracks parts sales, inventory value, turn rate, and inter-branch transfers specifically for Branch 12 (the "Combine Vault") — a specialized parts vault focused on combine equipment. Includes a restock tool and transfer tracking for managing this location's unique inventory.
- **Primary users:** Branch 12 manager, parts managers, operations
- **Workspace:** RP - Parts Reports
- **Refresh tier:** Tier 2 — Daily
- **Status:** Production

## Semantic Model

### Fact Tables
| Table | Grain | Key Fields | Notes |
|-------|-------|------------|-------|
| `Fact_Branch12_Transactions` | One row per Branch 12 parts transaction | DateKey, PartNumberKey, TransDatetime, Type, Qty, SaleValue, CostValue, MarginDollars, IsSale, IsTransfer | Covers both sales (`IsSale = TRUE`) and transfers (`IsTransfer = TRUE`). Has pre-computed `MarginDollars` and `MarginPercent`. Referenced in measures as lowercase `fact_Branch12_Transactions` — this is a case inconsistency; the table is registered as `Fact_Branch12_Transactions`. |

### Dimensions
| Table | Source | Key Relationship |
|-------|--------|-----------------|
| `dim_Branch12_Parts` | Branch 12-specific parts dimension | `PartNumberKey` → `Fact_Branch12_Transactions.PartNumberKey`. Has `InventoryCost` column for inventory valuation. |
| `dim_Parts` | Shared Lakehouse dimension | `PartNumberKey` → `dim_Branch12_Parts.PartNumberKey` (bidirectional — see gotchas) |
| `dim_BranchLocation` | Shared Lakehouse dimension | `TransferBranch` → `BranchID` — tracks which branch parts are transferred to/from |
| `dim_DateTable` | Shared Lakehouse dimension | `DateKey` → `DateKey` |
| `Stock Status Categories` | Local calculated/reference table | Category classifications for stock status |
| `YTD Metrics` | Local calculated/reference table | Pre-computed YTD comparison benchmarks |

### Key Measures (from `MeasuresTable`)
| Measure | Description |
|---------|-------------|
| `Sales` | Sum of `SaleValue` where `IsSale = TRUE` |
| `Sales R12` | Rolling 12-month sales (uses `dim_DateTable[IsRolling365Days]`) |
| `Total COS R12` | Rolling 12-month cost of sales |
| `Inventory Value` | Sum of `dim_Branch12_Parts[InventoryCost]` — current inventory at cost |
| `Current Turn` | `CostOfSales R12 / Inventory Value` — inventory turns |
| `Margin $` | Sum of `MarginDollars` where `IsSale = TRUE` |
| `Margin %` | `Margin $ / Sales` |
| `Margin $ R12` | Rolling 12-month margin dollars |
| `Previous Year Sales` | DATEADD -1 year |
| `Sales YTD Growth $` | Current YTD vs. same period last year |
| `Show Filter 1` | Displays active Branch filter as text (for slicer context display) |
| `Welcome Name` | Personalized greeting from user principal name |

## Report Pages
| Page | Display Name | Purpose | Visibility |
|------|-------------|---------|------------|
| e384167396533ecc066e | Combine Vault Sales | Main dashboard — sales, turns, margin summary | Visible |
| 4c0d0c1159b4e20070d2 | Restock Tool | Tool for identifying restocking needs | Hidden in view mode |
| bda2d2410d50db3357aa | Transfer Branch | Transfer branch detail/management view | Hidden in view mode |
| 5118f46655ce39e244c7 | Information | Reference/help page | Hidden in view mode |
| 6764b8d317c0a72a9d55 | ToolTip | Hover tooltip | Hidden (tooltip) |
| c76154a9b4db00086b19 | Sales Tool Tip | Sales hover tooltip | Hidden (tooltip) |

## Data Flow
```
EquipRDB (ODBC)
  └─ Branch 12 parts transactions (sales + transfers)
  └─ Branch 12 parts inventory/on-hand data
                │
                ▼
  LH_Master_Data (Lakehouse)
  └─ Fact_Branch12_Transactions
  └─ dim_Branch12_Parts (Branch 12-specific parts dimension)
  └─ dim_Parts (shared), dim_BranchLocation (shared), dim_DateTable (shared)
                │
                ▼
            Combine Vault Sales Report
```

## Known Issues & Gotchas

### `dim_Branch12_Parts` ↔ `dim_Parts` Bidirectional
The relationship between `dim_Branch12_Parts` and `dim_Parts` is bidirectional — one of the rare cases in this repo where bidirectional is auto-detected. Per project conventions, bidirectional relationships are a performance risk. There is also an inactive relationship `Fact_Branch12_Transactions → dim_Parts` directly. The active path goes through `dim_Branch12_Parts`. If you need to add direct part filtering from `dim_Parts` to the fact, you'd need to use `USERELATIONSHIP()`.

### `fact_Branch12_Transactions` Case in Measures
Measures in `MeasuresTable` reference the fact table as lowercase `fact_Branch12_Transactions`. The table is actually registered in the model as `Fact_Branch12_Transactions`. Power BI is case-insensitive in table references so this works, but it's inconsistent with the rest of the codebase.

### `TransferBranch` Relationship
The `TransferBranch` column on the fact joins to `dim_BranchLocation.BranchID`. This enables filtering transfers by destination branch. When filtering by "Branch" normally (via the branch slicer), be aware whether the slicer is filtering on the source (Branch 12) or destination branch.

### Hidden Action Pages
"Restock Tool" and "Transfer Branch" are hidden pages that likely serve as embedded action/management views. They may have buttons, bookmarks, or custom actions not visible in standard view mode. Preserve these pages when updating the report.

### `dim_DateTable[IsRolling365Days]`
Measures using `IsRolling365Days` rely on this custom column in the shared date dimension. If the date dimension is updated, ensure this column still exists.

## Refresh Pipeline Position
- **Phase:** Tier 2 — Phase 5/6 (after Tier 1 reports, can finish after 8 AM)
- **Dependencies:** `Fact_Branch12_Transactions`, `dim_Branch12_Parts` must refresh; `dim_Parts`, `dim_BranchLocation`, `dim_DateTable` (shared dims, Phase 3)

## Documentation Status
- In-repo docs: ✅ CLAUDE.md | ✅ PROJECT-SUMMARY.md
- Obsidian stakeholder docs: ✅ Complete — `Data Projects/Reports/Combine Vault Sales.md`
