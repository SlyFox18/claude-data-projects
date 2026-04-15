# Executive Centre Report

**Status:** Planning — Not yet built
**Type:** New report (Power BI replacement for TE2 legacy screen)
**Workspace:** TBD (likely RP - Financial Reports or RP - Parts Reports)
**Refresh Tier:** Proposed Tier 1 (daily, fresh by 8 AM)

---

## What This Report Does

The Executive Centre provides a high-level profitability summary for leadership — how much did we sell, what did it cost, and what was the gross profit, broken down by customer type.

It replicates the Executive Centre screen from the legacy TE2 system with two primary views:

- **Parts** — Profitability by trade type for parts sales
- **Service** — Profitability by trade type for service/repair orders

Both views show sales, cost, gross profit, and GP% grouped by the type of customer (Retail, Warranty, Internal, Fleet, etc.).

---

## Data Sources

Pulls from the same Invoice data that powers most existing reports. No new data connections needed — the underlying raw data is already flowing through the pipeline.

---

## Architecture Summary

One fact table (`Fact_ExecutiveCentre`) serves both tabs. The report tabs are simply filtered views of the same data — Parts filters to invoices with `ModuleType = I`, Service filters to `ModuleType = W`.

Customer trade type (Retail, Warranty, Internal, etc.) already exists on `dim_CustomerList` and will power the row groupings on both tabs.

---

## Open Questions Before Build

Before development begins, the following need answers from the requestor:

1. **Scope** — Parts and Service only, or add Vehicle Sales tab?
2. **Min Acceptable Profit** — Fixed threshold or configurable in the report?
3. **Salesperson tab** — Required, or optional for V1?
4. **Date ranges** — Today + MTD only, or also YTD / custom range slicer?
5. **Branch filter** — All branches default, or specific selection?
6. **Access** — Who needs to see it? (Affects workspace and security)

---

## What Needs to Be Built

1. Add two columns to the Invoice raw table dataflow (`Salesperson`, `ServiceSalesperson`)
2. Create `Fact_ExecutiveCentre` dataflow in LH_Master_Data (04 - Fact)
3. Build semantic model with date intelligence measures (Today, MTD, YTD)
4. Build report with two tab views + trade type row groupings
