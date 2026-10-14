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
| `dim_BranchPartInventory` | Lookup table (no model relationship) | Branch + PartNumber grain, sourced from `jdis_Part_Information` scoped to actual (TransferBranch, PartNumber) pairs from `Fact_Branch12_Transactions` — not just any branch that happens to stock a vault part. Matched via a filtered `SUMX` in DAX (no `LOOKUPVALUE`/no relationship). Added 2026-07-06, reworked 2026-07-07 for the "Greater than Zero" page — see gotcha below. |
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
| `Qty on Hand (By Location)` / `Bin Qty (By Location)` | `SUMX(FILTER(dim_BranchPartInventory, ...))` against the currently-selected `dim_BranchLocation[BranchID]` set (a `Branch` display label can map to several `BranchID`s — main branch + IS/Set-Up/CP shop codes — hence summing over a filtered set instead of `LOOKUPVALUE`, which errors on multi-row matches) + part. Deliberately **unconditional** — do not bake a `[Demands]`-based gate (or any Branch/Demands-derived visual filter) into these measures or this visual. Clutter suppression (hiding branches with no real transfer history) is handled entirely at the **data level** in `dim_BranchPartInventory`'s dataflow (compound-key scope on TransferBranch+PartNumber), not in DAX — see gotcha below for why. Blank at the part-level (no branch selected) row by design (`HASONEVALUE` check only). |
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

### `dim_BranchPartInventory` (Location On-Hand/Bin Qty)
Added 2026-07-06 to answer "does the destination branch still have this part on hand?" on the Greater than Zero page. Grain is Branch + PartNumber, sourced from `jdis_Part_Information` (the same raw table `dim_Branch12_Parts` reads from, just not filtered to Branch 12). Because it's scoped to vault transfer history, its refresh must run **after** `Fact_Branch12_Transactions` (Phase 4), not with the earlier 7:45 AM dimensional wave that `dim_Branch12_Parts` runs in.

**Reworked 2026-07-07 — scope by (TransferBranch, PartNumber) compound key, not PartNumber alone.** The original version joined `jdis_Part_Information` to the vault's distinct part list on `PartNumber` only, which pulled in a row for *every* branch that happens to independently stock a given vault part — including branches the vault never actually transferred that part to. That surfaced as extra "clutter" rows on the report (real inventory numbers, but no transfer/demand history at all).

**Do not try to fix "clutter" (stray branch rows with no real transfer history) with DAX-side filtering in this report — root cause found and documented 2026-07-07.** Several attempts — gating the `(By Location)` measures on `[Demands] > 0`, switching `LOOKUPVALUE` for `CALCULATE`/`TREATAS`, adding a visual-level filter card, and tightening `dim_BranchPartInventory`'s own dataflow scope with `IsSale = TRUE` — all moved the Greater than Zero matrix's Grand Total for measures that don't even reference `dim_BranchPartInventory` (`Qty on Hand (Vault Total)`, `Inventory Value (Vault Total)`). Captured the actual DAX query via `trace_operations` (Power BI Desktop's own generated query, not something we wrote) to find out why:

The page's **pre-existing** "Qty on Hand > 0" filter card — present before any of this work — compiles to a `SUMMARIZECOLUMNS('dim_Branch12_Parts'[PartNumber], 'dim_BranchLocation'[Branch], <every value column on the visual>...)` filtered to `[Qty on Hand] > 0`. This runs at the same Part × Branch grain as the matrix's row hierarchy (Power BI does this automatically for measure-based Advanced filters on a matrix with 2 row levels). `SUMMARIZECOLUMNS` silently drops any row where *every* requested value column is blank. Most existing measures (`Qty on Hand (Vault Total)`, `Part Description`, etc.) are blank at the branch sub-row level by design, so a (Part, Branch) row only survives if `Demands`/`Qty`/`Days - Last Sale` are non-blank there — i.e. genuine transfer history. **If a part has real on-hand inventory but zero branches with any transfer history, every one of its rows gets dropped, and the whole part silently disappears from the page — including its Grand Total contribution.** This was already true before `dim_BranchPartInventory` existed; it's a latent quirk of the page's own original filter design, not something introduced here.

Adding `Qty on Hand (By Location)`/`Bin Qty (By Location)` as new value columns changed the outcome: if `dim_BranchPartInventory` has *any* row for a (Part, Branch) pair — even an incidental one, unrelated to real transfer history — that alone is enough to save the row (and therefore the whole part) from being dropped. Every experiment above changed how many of these previously-hidden "orphan" parts (real stock, zero transfer history anywhere) got revived or re-excluded, which is why the Grand Total kept swinging by amounts far too large to be explained by the handful of visible clutter rows.

**Practical implication: the "true" $330,921.59 total (independently verified via `CALCULATE(SUM(dim_Branch12_Parts[...]), dim_Branch12_Parts[QuantityOnHand] > 0)`) was never actually the right comparison baseline** — it ignores the page's own pre-existing "needs at least one branch with transfer history" requirement. **Current accepted state: the compound-key join on `(TransferBranch, PartNumber)` *without* an `IsSale` condition** (see the dataflow's `.pq` file) — this revives close to all of the legitimate orphan parts, landing within ~0.5% of the naive total, which is about as close as achievable without restructuring the page's own filter mechanism. Known, accepted cosmetic gap: a branch whose only transfer record is an inbound (non-sale) addition will still show a stray zero-value row. If this needs to be closed later, the real fix is converting the page's "Qty on Hand > 0" filter from a measure-based Advanced filter to a calculated-column-based Categorical filter on `dim_Branch12_Parts` (which doesn't trigger this row-survival mechanism) — a separate, more invasive report change, intentionally not done here.

No model relationship — matched via a filtered `SUMX` in the `(By Location)` measures, same no-relationship spirit as other cross-report lookup tables in this repo, just not `LOOKUPVALUE` (see measure table above for why).

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
