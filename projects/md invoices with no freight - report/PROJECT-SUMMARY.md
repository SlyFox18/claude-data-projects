# MD Invoices With No Freight — Project Summary

## Overview

This report tracks freight charges on **Machine Down (MD) emergency parts orders** — the rush orders placed when a customer's equipment breaks down in the field. When a machine is down, parts are ordered as emergency/priority, and freight should be charged. This report identifies where freight was missed or under-charged, and estimates the revenue opportunity by branch and salesperson.

**Status:** Production ✅
**Workspace:** RP - Parts Reports
**Refreshed:** Daily (Tier 2)

---

## Report Pages

| Page | Purpose |
|------|---------|
| **Open Orders** | Live view of all open MD invoices — freight status (No Freight / Has Freight), actual vs. calculated freight, and missed opportunity per invoice |
| **Open Performance** | Branch and salesperson performance rankings on open orders — no-freight rate, opportunity, above-baseline summary |
| **Closed Invoices** | Historical analysis of closed MD invoices from January 2024 forward — same freight status breakdown as open orders |
| **Closed Performance** | Branch and salesperson performance on closed historical invoices |
| **How It Works** | Plain-English explanation of how MD orders are identified, how freight is detected, and how the freight calculation works |

---

## Data Model

### Tables

| Table | Type | Source | Description |
|-------|------|--------|-------------|
| Fact_MDInvoices_NoFreight | Fact | df_Fact_MDInvoices_NoFreight | One row per part line on an open MD order. Includes weight, freight status, actual and calculated freight. |
| Fact_MDInvoices_Closed | Fact | df_Fact_MDInvoices_Closed (SQL endpoint) | One row per invoiced part line on a closed MD order. Sourced via T-SQL against the Lakehouse SQL endpoint to avoid loading 10M+ InTrans rows. |
| FreightCalculator | Lookup | Manual Delta table (no dataflow) | Weight bracket table with base rate and additive rate per pound. Updated via PySpark notebook when carrier rates change. |
| dim_FreightPerformanceGroup | Calculated | DAX DATATABLE | Three-group slicer: No Freight / Needs Review / Good / Above Baseline |
| dim_BranchLocation | Dimension | Shared Lakehouse | Branch names and regions |
| dim_DateTable | Dimension | Shared Lakehouse | Calendar dimension for date filtering |
| dim_CustomerList | Dimension | Shared Lakehouse | Customer dimension with CSM and engagement data |
| dim_Parts | Dimension | Shared Lakehouse | Parts catalog dimension |
| dim_Franchise | Dimension | Shared Lakehouse | Manufacturer/franchise dimension |
| dim_Salesperson | Dimension | Shared Lakehouse | Salesperson names and codes |

### Relationships
Both fact tables join to all shared dimensions on Branch, CustomerNumber, PartNumber, and OrderDate/InvoiceDate. The FreightCalculator table has **no model relationship** — it is accessed exclusively through DAX FILTER/MAXX lookups inside the Calculated Freight measure.

---

## Key Measures

| Measure | Description |
|---------|-------------|
| Total MD Invoices | Count of distinct open MD order numbers |
| No Freight Rate | Percentage of MD invoices with zero freight charged |
| Actual Freight | Total freight dollar amount actually charged (from part 3750 line items) |
| Calculated Freight | Estimated freight based on part weights and the carrier rate table |
| Missed Freight | Gap between calculated and actual freight — the revenue opportunity |
| Freight Above Baseline | Amount where actual freight exceeded the calculated baseline |
| Freight Opportunity | Potential revenue on orders where freight was missed or under-charged |

All measures have `Closed -` prefix equivalents that apply to the historical closed invoice data.

---

## Source System Tables

| Table | Purpose in This Report |
|-------|----------------------|
| insalpar | Open parts order lines — identifies MD orders via PurOrderType = 'E' |
| Insalpar_Audit | Permanent audit log of insalpar changes — used to recover closed MD order numbers |
| Insalord | Order header data (customer, date) joined to open fact |
| InTrans_Incremental | Closed invoice transaction lines (10M+ rows) — joined to recovered MD FileNos |
| jdis_Part_Information | Parts master with weight — provides per-part weight for freight calculation |

---

## How the Freight Calculation Works

Freight is estimated in two parts using the **FreightCalculator** rate table:

**If total order weight ≤ 150 lbs:**
`Calculated Freight = Base Rate (once per order) + Sum of (Rate per lb × Line Weight) for each part line`

**If total order weight > 150 lbs:**
No base rate. Each part line is calculated independently at its own CWT (per-100-lb) rate:
- 151–499 lbs: $1.10/lb
- 500–999 lbs: $0.45/lb
- 1,000–1,999 lbs: $0.32/lb
- 2,000–4,999 lbs: $0.25/lb
- 5,000+ lbs: $0.15/lb

---

## Notes

- Freight is stored as a separate line item on the invoice (part number 3750), not in a freight field. This is how the source system works.
- Open orders disappear from the source parts table when they are invoiced and closed. Closed history is recovered via the Insalpar_Audit table, which permanently records all changes.
- The FreightCalculator rate table was extended on 2026-05-18 from a 249 lb ceiling to 999,999 lbs, using confirmed carrier rates. The source CSV is kept in `Freight Calculator/` within this project folder.
- The closed fact table uses the Lakehouse SQL Analytics Endpoint (T-SQL) rather than Power Query for performance — avoids loading 10M+ InTrans rows into memory.
