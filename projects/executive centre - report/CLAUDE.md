# Executive Centre Report — AI Context

## Status: Planning / Not Yet Started

This project is in the research and architecture phase. No dataflows or semantic model exist yet. This file documents what we know so far and the questions that need answers before building begins.

---

## Business Purpose

Replicates the **Executive Centre** report from the legacy TE2 system. The report provides executive-level profitability views across two primary tabs:

- **Parts Tab** — Sales, cost, and gross profit by trade type (module_type = 'I') grouped by customer trade type
- **Service Tab** — Sales, cost, and gross profit by trade type (module_type = 'W') grouped by customer trade type

Both tabs share the same underlying grain — one row per invoice — and trade type is sourced from `dim_CustomerList.TradeType`, not from the work order.

**Primary users:** Executive leadership, branch managers

---

## Source System Tables Researched

### Invoice (WKRFILE)
The primary source for both tabs.

| Source Column | Power BI Column | Notes |
|---|---|---|
| `document_no` | `DocumentNo` | Invoice/document number |
| `invo_type` | `InvoiceType` | Filter: `I` = standard invoice, `C` = credit memo |
| `module_type` | `ModuleType` | `I` = Parts tab, `W` = Service tab |
| `branch` | `Branch` | → dim_BranchLocation |
| `customer_no` | `CustomerNumber` | → dim_CustomerList |
| `salesman` | `Salesperson` | **NOT in current Invoice raw table — needs to be added** |
| `part_saleman_for_wks` | `ServiceSalesperson` | **NOT in current Invoice raw table — needs to be added** |
| `ro_number` | `RONumber` | Work order number → WKROFILE (if service detail needed) |
| `invo_datetime` | `InvoiceDate` | → dim_DateTable |
| `parts_sale_val` | `PartsSaleVal` | ✅ Already in raw table |
| `parts_cost_val` | `PartsCostVal` | ✅ Already in raw table |
| `labour_sale_val` | `LabourSaleVal` | ✅ Already in raw table |
| `labour_cost_val` | `LabourCostVal` | ✅ Already in raw table |
| `sublet_sal_val` | `SubletSaleVal` | ✅ Already in raw table |
| `sublet_cost_val` | `SubletCostVal` | ✅ Already in raw table |
| `other_sale_val` | `OtherSaleVal` | ✅ Already in raw table |

### WKROFILE (Work Order file)
Investigated as a potential source for trade type on the Service tab. **Finding: not needed.** The `CODE` column (suspected trade type) is 100% null. Trade type comes from `dim_CustomerList.TradeType` for both tabs.

### ArMaster_Customer
Confirmed `TradeType` column exists here. It is surfaced in Power BI via `dim_CustomerList.TradeType` (calculated column already present).

### GlTrans / GlMaster / GlStdJnl / BankList
Explored in session 2026-04-13 as potential sources for a financial/GL tab. These are available if a GL or bank reconciliation tab is ever added. Documentation saved in `.claude/queries/raw-tables/`.

---

## Proposed Architecture

### One Fact Table: Fact_ExecutiveCentre

**Grain:** One row per invoice (document_no)
**Source:** Invoice raw table (filtered to invo_type IN ('I', 'C'))

```
Fact_ExecutiveCentre
├── DocumentNo         (invoice/document number)
├── ModuleType         (I = Parts, W = Service)
├── Branch             → dim_BranchLocation
├── CustomerNumber     → dim_CustomerList (TradeType lives here)
├── Salesperson        (from Invoice.salesman)
├── ServiceSalesperson (from Invoice.part_saleman_for_wks)
├── RONumber           (work order number, for drill-through if needed)
├── InvoiceDate        → dim_DateTable
├── PartsSaleVal
├── PartsCostVal
├── LabourSaleVal
├── LabourCostVal
├── SubletSaleVal
├── SubletCostVal
└── OtherSaleVal
```

**Report tabs = page-level filters in Power BI:**
- Parts tab → `ModuleType = "I"`
- Service tab → `ModuleType = "W"`

**Trade type row groupings** on both tabs come from `dim_CustomerList.TradeType` (already populated, no new dimension work needed).

**DAX calculated measures:**
- `GrossProfit = SaleVal - CostVal`
- `GP% = GrossProfit / TotalSaleVal`
- Today, MTD, YTD variants using `dim_DateTable`

### Minimal Date Measures Needed
The source report shows **Today** and **MTD** columns for each trade type row. Standard date intelligence via `dim_DateTable` covers both.

---

## Raw Table Change Required

The existing `Invoice` raw table in `.claude/queries/raw-tables/Invoice.pq` needs two columns added:

- `salesman` → rename to `Salesperson`
- `part_saleman_for_wks` → rename to `ServiceSalesperson`

**Risk:** Additive columns only — no breaking changes to existing reports. Safe to add.

The `invo_type` filter (keep only I and C) should be applied in the **fact table query**, not the raw table, to avoid filtering data that other reports may need from the raw source.

---

## Open Questions (for stakeholder before building)

1. **Scope** — Parts and Service tabs only, or Vehicle Sales tab too?
2. **Min Acceptable Profit** — Is this a fixed threshold or a user-configurable slicer in the report?
3. **Salesperson tab** — The legacy report has a salesperson breakdown. Is that required in the Power BI version?
4. **Date ranges** — Source shows Today and MTD. Do they also need YTD or a custom date range slicer?
5. **Branch filter** — Should the report default to all branches or a specific selection?
6. **Audience access** — Who gets access? Determines workspace and RLS needs.

---

## Known Gotchas

- `WKROFILE.CODE` is 100% null — do not use as trade type source
- `part_saleman_for_wks` is the service salesperson field on Invoice, not on WKROFILE
- Existing Invoice raw table excludes `salesman` and `part_saleman_for_wks` — they need to be added before the fact table query will work
- Trade type for Service tab comes from `dim_CustomerList.TradeType`, same as Parts tab — no separate lookup needed

---

## Refresh Tier

Proposed: **Tier 1** (fresh by 8 AM daily) — executive-facing report, same priority as Customer Anatomy.

Fact table dependency chain: Invoice raw table → Fact_ExecutiveCentre → Semantic Model

---

## Related Files

- Raw table query: `.claude/queries/raw-tables/Invoice.pq`
- GL raw tables (if GL tab added later): `.claude/queries/raw-tables/GlTrans_Full.pq`, `GlMaster.pq`, `GlStdJnl.pq`, `BankList.pq`
- Customer dimension: `dim_CustomerList` (TradeType already populated)
