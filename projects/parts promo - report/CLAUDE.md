# Parts Promo — Claude Context

## Report Overview
- **Business purpose:** Tracks promotional parts discounts — which parts are being discounted, the discount amount, and the net impact on sales and margin. Shows rolling 12 month vs. prior year rolling 12 month comparisons. Helps management understand the cost of promotional pricing decisions.
- **Primary users:** Parts managers, sales leadership, pricing team
- **Workspace:** RP - Parts Reports (Sandbox pending promotion)
- **Refresh tier:** Tier 1 — Daily by 8 AM
- **Status:** Sandbox — visually verified 2026-07-07 (Net Sales % page bar chart labels); pending promotion to RP - Parts Reports (production) once Brian completes the move

## Semantic Model

### Fact Tables
| Table | Grain | Key Fields | Notes |
|-------|-------|------------|-------|
| `Fact_PartsPromo` | One row per promo line item | REF_NO, PART_NO, TransDatetime, CustomerNo, Franchise, Type, Description, Qty, SaleValue, CostValue, Branch | SaleValue is negative (discount amount). Partition strips time from TransDatetime. From `dbo.Fact_PartsPromo`. |
| `Fact_InTrans_AllPromo` | All InTrans lines for orders that had promos | REF_NO, PART_NO, Branch, DateKey | From `dbo.Fact_InTrans_AllPromo` — provides full order context for promo orders |

### Dimensions
| Table | Source | Key Relationship |
|-------|--------|-----------------|
| `dim_RepairOrder` | Lakehouse | `Fact_PartsPromo.REF_NO → dim_RepairOrder.REF_NO`; `Fact_InTrans_AllPromo.REF_NO → dim_RepairOrder.REF_NO` — contains TotalPartsSales, TotalPartsCost, OriginalMargin, NetOrderValue, NetMargin |
| `dim_Parts` | Shared Lakehouse dimension | `Fact_PartsPromo.PART_NO → dim_Parts.PartNumber`; `Fact_InTrans_AllPromo.PART_NO → dim_Parts.PartNumber` |
| `dim_PromoType` | Dedicated dimension | `Fact_PartsPromo.PART_NO → dim_PromoType.PromoPartNo` — classifies which parts are promo parts |
| `dim_CustomerList` | Shared Lakehouse dimension | `Fact_PartsPromo.CustomerNo → dim_CustomerList.AccountNumber` |
| `dim_BranchLocation` | Shared Lakehouse dimension | `Fact_PartsPromo.Branch → dim_BranchLocation.BranchID`; `Fact_InTrans_AllPromo.Branch → dim_BranchLocation.BranchID` |
| `dim_DateTable` | Shared Lakehouse dimension | `Fact_PartsPromo.TransDatetime → dim_DateTable.Date`; `Fact_InTrans_AllPromo.DateKey → dim_DateTable.Date` |
| `Sales Category` | Reference table | Category classification for sales types |

### Key Measures (in `_Measures`)
| Measure | Description |
|---------|-------------|
| `Discount` | ABS(SUM(Fact_PartsPromo[SaleValue])) — total discount (SaleValue is negative) |
| `Discount %` | Discount / Original Sale Value |
| `Original Sale Value` | Total parts sales from orders that had promos — uses LOOKUPVALUE for row context, TREATAS for aggregation |
| `Cost Value` | Total parts cost from promo orders — same LOOKUPVALUE/TREATAS dual pattern |
| `Original Margin $` | Pre-discount margin from dim_RepairOrder — LOOKUPVALUE/TREATAS pattern |
| `Original Margin %` | Original Margin $ / Original Sale Value |
| `Net Sales Value` | Sales after discount (Original Sale Value + Discount[negative]) |
| `Net Margin $` | Net margin after discount |
| `Net Margin %` | Net Margin $ / Net Sales Value |
| `Promo Count` | COUNTROWS(Fact_PartsPromo) |
| `Orders with Promos` | DISTINCTCOUNT(Fact_PartsPromo[REF_NO]) |
| `Rolling 12M Discount` | Last 12 months discount — uses CROSSFILTER to bypass date relationship |
| `Rolling 12M Net Sales` | Last 12 months net sales — uses CROSSFILTER pattern |
| `Total Sales` | SUM(Fact_InTrans_AllPromo[SaleValue]) — total sales for ALL orders (not just promo), used as the denominator for promo penetration % |
| `Net Sales Value (Filtered)` | Original Sale Value (Filtered) + promo discount — net promo sales in current filter context |
| `Net Sales %` | Net Sales Value (Filtered) / Total Sales — promo penetration ratio, computed per-row so it stays correct regardless of what else is cross-filtered on the page (see Known Issues) |
| `Net Sales Value (Filtered) - Branch Label` | Same value as `Net Sales Value (Filtered)`; carries a dynamic format string that renders `$XXX.XXK (YY.YY%)` as one literal label — feeds only the "Net Sales by Branch" bar chart on the Net Sales % page |

## Report Pages
| Page | Display Name | Purpose | Visibility |
|------|-------------|---------|------------|
| Main | R12 -PY R12 | Rolling 12 vs prior year rolling 12 comparison | Visible |
| Hidden | Details | Transaction detail drill-down | Hidden |
| Hidden | Net Sales % | Net margin % analysis | Hidden |

## Data Flow
```
EquipRDB (ODBC) → dbo.Fact_PartsPromo (Lakehouse) → Fact_PartsPromo (semantic model)
EquipRDB (ODBC) → dbo.Fact_InTrans_AllPromo (Lakehouse) → Fact_InTrans_AllPromo (semantic model)
dbo.dim_RepairOrder → dim_RepairOrder (order-level aggregates for LOOKUPVALUE)
```

## Known Issues & Gotchas
- **LOOKUPVALUE/TREATAS dual pattern:** The cost/sales/margin measures use a dual-path approach — LOOKUPVALUE for single-row context (detail tables), TREATAS for multi-row context (aggregations). This is required because dim_RepairOrder stores order-level totals (not line-level), and we need to correctly aggregate across filtered promo orders. Do not simplify this pattern.
- **SaleValue is negative:** Promo discounts are recorded as negative SaleValue in Fact_PartsPromo. The `Discount` measure uses ABS() to show a positive number. Be aware of this when building new measures.
- **Rolling 12M measures use CROSSFILTER:** `Rolling 12M Discount` and `Rolling 12M Net Sales` use `CROSSFILTER(..., None)` to temporarily disable the date relationship, then filter by TransDatetime directly. This handles the case where the date slicer would otherwise restrict the rolling window.
- **Sandbox status:** This report is in RP - Sandbox pending promotion to production. See `PROJECT-STATUS.md` and `MIGRATION-NOTES.md` for migration context.
- **Archive V2:** There is an archived V2 version at `report/archive/Parts Promo V2.SemanticModel/` with different table names (Parts_Promo, InTrans_All_Promo, Date, Dim_Branch, Base_Customer_Info). Use `report/current/` only.
- **Combined $ + % bar chart labels via dynamic format strings (2026-07-07):** Power BI's native bar/column chart can't plot two independent measures as one label string. The fix used here: duplicate the plotted measure (`Net Sales Value (Filtered) - Branch Label`), then in Desktop set its Format to **Dynamic** (Measure tools ribbon) with a DAX expression that returns the whole label wrapped in `'...'` (forces literal-text rendering) — see the measure's TMDL comment in `_Measures.tmdl` for the exact expression. Requires model compatibility level 1601+ (`FormatStringDefinition` property). Also set the visual's Data Labels > Values > Display Units to **None**, since the dynamic format string does its own /1000 "K" scaling — leaving Auto on double-scales the value. Reusable pattern for any bar/column chart that needs a value + a stable, row-context-scoped percentage in one label (the percentage measure itself must use the row's own filter context, not `ALLSELECTED`/`ALL`, so it isn't corrupted by cross-filter highlighting from clicking within the same or another visual — see `Net Sales %` measure above).

## Refresh Pipeline Position
- Tier 1 target: Daily by 8 AM
- Depends on `Fact_PartsPromo` and `Fact_InTrans_AllPromo` fact table refreshes (Phase 4)
- Not yet in production pipeline (Sandbox)

## Documentation Status
- In-repo docs: ✅ CLAUDE.md | ✅ PROJECT-SUMMARY.md
- Obsidian stakeholder docs: ✅ Complete — `Data Projects/Reports/Parts Promo.md`
