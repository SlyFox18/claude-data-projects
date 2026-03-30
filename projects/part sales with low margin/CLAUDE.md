# Part Sales with Low Margin — Claude Context

## Report Overview
- **Business purpose:** Identifies parts being sold below target profit margins (Page 1 — transaction history) and flags current inventory where the sell price doesn't cover cost (Page 2 — inventory snapshot). Supports pricing corrections and margin management.
- **Primary users:** Pricing managers, branch managers, finance team
- **Workspace:** RP - Parts Reports (Production)
- **Refresh tier:** Tier 1 — daily 4:15 AM CST, fresh by 8 AM
- **Status:** Production ✅

---

## Semantic Model

**Path:** `reports/current/Part Sales with Low Margin.SemanticModel/definition/`
> Note: This project uses `reports/` (plural), not `report/` like most other projects.

### Tables
| Table | Role | Grain | Source | Row Count |
|-------|------|-------|--------|-----------|
| `Fact_InTrans` | Fact (Page 1) | One row per parts sales transaction (Type='I') | InTrans_Incremental (Lakehouse) | ~3–6M rows |
| `dim_Parts_LowMargin` | Standalone snapshot (Page 2) | One row per part+branch combination with low margin flag | jdis_Part_Information + InMaster (Lakehouse) | ~150–155K rows |
| `dim_BranchLocation` | Shared dimension | Branch | Lakehouse | Small |
| `dim_CustomerList` | Shared dimension | Customer | Lakehouse | ~5K |
| `dim_DateTable` | Shared dimension | Date | Lakehouse | |
| `dim_Parts` | Shared dimension | Part | Lakehouse | ~50K |

### Relationships
```
Fact_InTrans[Branch]          → dim_BranchLocation[BranchID]     (M:1, single direction)
Fact_InTrans[TransDatetime]   → dim_DateTable[Date]               (M:1, single direction)
Fact_InTrans[CustomerNo]      → dim_CustomerList[AccountNumber]   (M:1, single direction)
dim_Parts_LowMargin[Branch]   → dim_BranchLocation[BranchID]     (M:1, BIDIRECTIONAL ⚠️)
```

**Note on missing dim_Parts relationship:**
`dim_Parts` is loaded in the model but has no active relationship to `Fact_InTrans`. If users expect to filter Page 1 transactions by part attributes (description, category), this relationship would need to be added: `Fact_InTrans[PartNumber]` → `dim_Parts[PartNumber]` (M:1, single direction).

`dim_Parts_LowMargin` has no model relationship to `Fact_InTrans` or `dim_Parts` — it serves Page 2 independently. Cross-table lookups use LOOKUPVALUE (see below).

### Calculated Columns on Fact_InTrans
These DAX calculated columns are pre-computed at refresh for performance. They use **LOOKUPVALUE with a three-key compound lookup** (PartNumber + Branch + Franchise) — NOT RELATED(), so no inactive relationship to dim_Parts_LowMargin is needed. The three-key join is important: dim_Parts_LowMargin is branch+franchise-specific, not just part-specific.

| Column | Description |
|--------|-------------|
| `LowMarginFlag` | `LOOKUPVALUE(dim_Parts_LowMargin[LowMarginFlag], ...PartNumber, Branch, Franchise...)` — "LOW" if flagged |
| `StockOrderPrice` | `LOOKUPVALUE(dim_Parts_LowMargin[StockOrderPrice], ...PartNumber, Branch, Franchise...)` |
| `ListPriceManuf` | LOOKUPVALUE of dim_Parts_LowMargin[ListPrice] using same three-key join |
| `OriginalMarginDollars` | (ListPriceManuf - StockOrderPrice) × Qty |
| `ActualMarginDollars` | SaleValue - CostValue |
| `MarginDiscrepancyDollars` | ActualMarginDollars - OriginalMarginDollars |
| `IsLowMarginFlagged` | Boolean: LowMarginFlag = "LOW" |

**Why three keys?** A part can have different stock order prices and low margin flags at different branches and franchises. Using only PartNumber would return wrong values when the same part exists at multiple branches with different pricing.

### Key Measures
**Page 1 (Transaction measures — source: Fact_InTrans):**
| Measure | Description |
|---------|-------------|
| `Total Sales Value` | SUM of SaleValue |
| `Actual Margin $` | SUM of ActualMarginDollars |
| `Actual Margin %` | Actual Margin $ ÷ Total Sales Value |
| `Original Margin $` | SUM of OriginalMarginDollars (expected profit at stock order price) |
| `Original Margin %` | Original Margin $ ÷ Total Sales Value |
| `Margin Discrepancy $` | Actual Margin $ − Original Margin $ |
| `Total Transactions` | COUNTROWS of Fact_InTrans |

**Page 2 (Inventory measures — source: dim_Parts_LowMargin):**
| Measure | Description |
|---------|-------------|
| `Desired Margin $` | (SellPrice1 × OnHandQty) − (Cost × OnHandQty) — target profit using jdis Cost |
| `Desired Margin %` | Desired Margin $ ÷ Sell Value |
| `Actual Margin $ (INV)` | (SellPrice1 × OnHandQty) − InventoryCost |
| `Actual Margin % (INV)` | Actual Margin $ (INV) ÷ Sell Value |
| `Margin $ Discrepancy` | Actual Margin $ (INV) − Desired Margin $ |
| `New Sell Price` | Recommended price to close the margin gap |
| `Positive Margin $ Discrepancy` | Parts where actual > desired (ADDCOLUMNS with direct columns — see critical bug below) |
| `Negative Margin $ Discrepancy` | Parts where actual < desired (same pattern) |
| `Net Margin $ Discrepancy` | Positive + Negative |

---

## Report Pages
| Page | Purpose | Key Visuals |
|------|---------|-------------|
| **Parts Sales with Low Margins** | Transaction-level history — which parts sold below margin, by whom, when, where | Filterable table, slicers for branch/franchise/date/part/customer |
| **Inventory Cost Discrepancy** | Current stock snapshot — which parts have a pricing gap today + KPI cards | KPI cards (Positive/Negative/Net discrepancy), detail table with New Sell Price |
| **Low Action Items** | Prioritized action list filtered to most impactful items | Filtered table for immediate pricing action |

---

## Data Flow

```
InTrans_Incremental (Lakehouse)     → filtered to Type='I', date range → Fact_InTrans
jdis_Part_Information (Lakehouse)   ↘
InMaster (Lakehouse)                → joined + filtered → dim_Parts_LowMargin
```

**Two independent paths:** Fact_InTrans and dim_Parts_LowMargin are populated separately and serve different report pages. They share no active model relationship.

---

## Known Issues & Gotchas

### 1. ⚠️ CRITICAL — KPI Bug: Old Report Values Were Wrong (FIXED)
The legacy report's Page 2 KPI cards showed $5.31M positive margin discrepancy. The actual correct value is ~$2.09M. The legacy bug: measuring inside `ADDCOLUMNS` using measures that call `SUM()` causes the entire column to be aggregated instead of row-by-row evaluation.

**Rule to never break:** The `Positive Margin $ Discrepancy` and `Negative Margin $ Discrepancy` measures MUST use direct column references (`[SellPrice1]`, `[OnHandQty]`, `[Cost]`, `[InventoryCost]`) inside `ADDCOLUMNS`, NOT wrapped measures like `[Sell Price]` or `[Total SOH Qty]`. See `docs/03-fixes-applied/KPI-Measures-Fix.md` and `docs/04-discoveries/Old-Report-Bug-Found.md`.

### 2. Cost vs. StockOrderPrice — Two Different Fields
`dim_Parts_LowMargin` has two cost-like fields:
- `StockOrderPrice` — the price stock was ordered at (original/legacy baseline)
- `Cost` — the jdis cost field (current cost basis, used for Desired Margin calculations)
These are NOT interchangeable. Page 2 "Desired Margin" uses `Cost`. Do not swap them.

### 3. dim_Parts Duplicate Rows (FIXED)
During migration, duplicate rows in `dim_Parts` were discovered causing row inflation in joins. The dataflow query was fixed. See `queries/dimensions/FIX-APPLIED-dim_Parts-Duplicates.md`. Do not revert to the pre-fix query.

### 4. dim_Parts_LowMargin is Bidirectional on Branch — Performance Risk
The relationship `dim_Parts_LowMargin[Branch] → dim_BranchLocation[BranchID]` uses `crossFilteringBehavior: bothDirections`. Per project conventions, bidirectional relationships carry performance risk and filter ambiguity. Monitor if Page 2 performance degrades as the table grows.

### 5. Row Count Gap vs. Old Report
New report has ~150,889 rows in dim_Parts_LowMargin; old report had ~155,014 rows (4,125 fewer, ~2.7% gap). Root cause is different source filtering logic. This is documented and accepted — the new counts are correct. Do not add logic to pad rows to match the old report.

### 6. dim_Parts Has No Relationship to Fact_InTrans
`dim_Parts` is in the model but unrelated to `Fact_InTrans`. Part attribute filtering on Page 1 (by description, category, etc.) is not currently supported via slicers from dim_Parts. If this is ever needed, add: `Fact_InTrans[PartNumber]` → `dim_Parts[PartNumber]` (M:1, single direction).

---

## Refresh Pipeline Position
- **Phase:** Phase 4 — Facts (Parts)
- **Dependencies:** InTrans_Incremental (Phase 2), jdis_Part_Information + InMaster (Phase 1 Raw) must complete first
- **Fact_InTrans refresh time:** ~5–8 minutes (3–6M rows with calculated columns)
- **No incremental refresh** on Fact_InTrans for this report (unlike InTrans_Incremental which uses RangeStart/RangeEnd)

---

## Documentation Status
- In-repo docs: ✅ CLAUDE.md | ✅ PROJECT-SUMMARY.md (at `docs/01-getting-started/PROJECT-SUMMARY.md`)
- Full docs in: `docs/01-getting-started/`, `docs/02-implementation/`, `docs/03-fixes-applied/`, `docs/04-discoveries/`
- Obsidian stakeholder docs: ✅ Complete — `Data Projects/Reports/Part Sales with Low Margin.md`

## Key Reference Files
| File | Contents |
|------|----------|
| `docs/01-getting-started/PROJECT-SUMMARY.md` | Business overview, pages, metrics |
| `docs/02-implementation/MEASURE-REFERENCE.md` | All DAX measures with formulas |
| `docs/02-implementation/SETUP-GUIDE.md` | Step-by-step implementation guide |
| `docs/03-fixes-applied/KPI-Measures-Fix.md` | The ADDCOLUMNS row context fix |
| `docs/04-discoveries/Old-Report-Bug-Found.md` | Full story on the $5.31M → $2.09M correction |
| `docs/04-discoveries/Cost-vs-StockOrderPrice.md` | Cost field explanation |
| `queries/dimensions/FIX-APPLIED-dim_Parts-Duplicates.md` | dim_Parts duplicate fix |
