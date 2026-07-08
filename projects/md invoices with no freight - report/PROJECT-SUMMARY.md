# MD Invoices With No Freight — Project Summary

## Overview

This report tracks freight charges on **Machine Down (MD) emergency parts orders** — the rush orders placed when a customer's equipment breaks down in the field. When a machine is down, parts are ordered as emergency/priority, and freight should be charged. This report identifies where freight was missed or under-charged, and estimates the revenue opportunity by branch and salesperson.

**Status:** Production ✅
**Workspace:** RP - Parts Reports
**Refreshed:** Daily (Tier 2)

---

## Report Pages

| Page                         | Purpose                                                                                                                                           |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Open Orders**        | Live view of all open MD invoices — freight status (No Freight / Has Freight), actual vs. calculated freight, and missed opportunity per invoice |
| **Open Performance**   | Branch and salesperson performance rankings on open orders — no-freight rate, opportunity, above-baseline summary                                |
| **Closed Invoices**    | Historical analysis of closed MD invoices from January 2024 forward — same freight status breakdown as open orders                               |
| **Closed Performance** | Branch and salesperson performance on closed historical invoices                                                                                  |
| **How It Works**       | Plain-English explanation of how MD orders are identified, how freight is detected, and how the freight calculation works                         |

---

## Data Model

### Tables

| Table                       | Type       | Source                                   | Description                                                                                                                                   |
| --------------------------- | ---------- | ---------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| Fact_MDInvoices_NoFreight   | Fact       | df_Fact_MDInvoices_NoFreight             | One row per part line on an open MD order. Includes weight, freight status, actual and calculated freight.                                    |
| Fact_MDInvoices_Closed      | Fact       | df_Fact_MDInvoices_Closed (SQL endpoint) | One row per invoiced part line on a closed MD order. Sourced via T-SQL against the Lakehouse SQL endpoint to avoid loading 10M+ InTrans rows. |
| FreightCalculator           | Lookup     | Manual Delta table (no dataflow)         | Weight bracket table with base rate and additive rate per pound. Updated via PySpark notebook when carrier rates change.                      |
| dim_FreightPerformanceGroup | Calculated | DAX DATATABLE                            | Three-group slicer: No Freight / Partial Freight / Adequate Freight                                                                           |
| dim_BranchLocation          | Dimension  | Shared Lakehouse                         | Branch names and regions                                                                                                                      |
| dim_DateTable               | Dimension  | Shared Lakehouse                         | Calendar dimension for date filtering                                                                                                         |
| dim_CustomerList            | Dimension  | Shared Lakehouse                         | Customer dimension with CSM and engagement data                                                                                               |
| dim_Parts                   | Dimension  | Shared Lakehouse                         | Parts catalog dimension                                                                                                                       |
| dim_Franchise               | Dimension  | Shared Lakehouse                         | Manufacturer/franchise dimension                                                                                                              |
| dim_Salesperson             | Dimension  | Shared Lakehouse                         | Salesperson names and codes                                                                                                                   |

### Relationships

Both fact tables join to all shared dimensions on Branch, CustomerNumber, PartNumber, and OrderDate/InvoiceDate. The FreightCalculator table has **no model relationship** — it is accessed exclusively through DAX FILTER/MAXX lookups inside the Calculated Freight measure.

---

## Key Measures

| Measure                | Description                                                              |
| ---------------------- | ------------------------------------------------------------------------ |
| Total MD Invoices      | Count of distinct open MD order numbers                                  |
| No Freight Rate        | Percentage of MD invoices with zero freight charged                      |
| Actual Freight         | Total freight dollar amount actually charged (from part 3750 line items) |
| Calculated Freight     | Estimated freight based on part weights and the carrier rate table       |
| Missed Freight         | Gap between calculated and actual freight for a single invoice (detail rows only) |
| Freight Above Baseline | Amount where actual freight exceeded the calculated baseline             |
| Freight Opportunity    | Total potential revenue across all under-billed orders (No Freight + Partial Freight invoices combined; fully-billed/over-billed orders never reduce this number) |

All measures have `Closed -` prefix equivalents that apply to the historical closed invoice data.

---

## Source System Tables

| Table                 | Purpose in This Report                                                             |
| --------------------- | ---------------------------------------------------------------------------------- |
| insalpar              | Open parts order lines — identifies MD orders via PurOrderType = 'E'              |
| Insalpar_Audit        | Permanent audit log of insalpar changes — used to recover closed MD order numbers |
| Insalord              | Order header data (customer, date) joined to open fact                             |
| InTrans_Incremental   | Closed invoice transaction lines (10M+ rows) — joined to recovered MD FileNos     |
| jdis_Part_Information | Parts master with weight — provides per-part weight for freight calculation       |

---

## How the Freight Calculation Works

Freight is estimated using a single lookup against the **FreightCalculator** rate table:

`Calculated Freight = Base Rate + (Additive Rate per lb × Total Order Weight)`

The **total weight of all part lines on the order** (not each line's individual weight) is looked up once in the FreightCalculator bracket table. That one bracket provides both the Base Rate and the Additive Rate per pound used for the whole order:

- **Orders ≤ 150 lbs total weight:** the matching bracket has a non-zero Base Rate.
- **Orders > 150 lbs total weight:** the matching bracket's Base Rate is $0 — only the additive rate applies.

### Step-by-Step Examples

**Order with 100 lbs total weight (10 part lines):**
Bracket lookup for 100 lbs → Base Rate $120.00, Additive Rate $1.31/lb
**Calculated Freight = $120.00 + (100 × $1.31) = $251.00**

**Order with 300 lbs total weight (2 part lines: 100 lbs + 200 lbs):**
Bracket lookup for 300 lbs → Base Rate $0.00 (over 150 lbs), Additive Rate $1.10/lb
**Calculated Freight = $0.00 + (300 × $1.10) = $330.00**

Key points to communicate to stakeholders:

- Individual part line weights no longer drive the rate — only the **order's total weight** determines which bracket (and therefore which rate) applies.
- `TotalLineWeight` in the data = `part weight × quantity ordered` for that line; these are summed across all lines on the order to get the total weight used for the bracket lookup.
- The base and additive rates come from the `FreightCalculator` table, which is updated manually via PySpark notebook when carrier rates change. It has no automated dataflow.

### % Freight Difference

A per-invoice metric that shows how far the actual freight charged deviates from the calculated baseline, expressed as a percentage. Uses the average of the two values as the denominator (symmetric percent difference):

```
% Freight Difference = (Calculated − Actual) / ((Calculated + Actual) / 2)
```

**Example:**

- Calculated Freight = $10
- Actual Freight = $8
- Difference = $10 − $8 = $2
- Average = ($10 + $8) / 2 = $9
- % Freight Difference = $2 / $9 = **22.2%**

A positive value means actual was below calculated (under-charged). A negative value means actual exceeded calculated (above baseline). Zero means exact match.

### Alert Threshold (Open Orders page)

An "Alert Threshold %" slider on the Open Orders page (next to the freight-status tabs) highlights any invoice whose % Freight Difference is at or above the selected percentage. This previews a planned **Power Automate flow** that will email the branch manager when an invoice crosses the threshold — the stakeholder hasn't settled on a final percentage yet, so the slider lets them test different cutoffs against real data (how many invoices would alert at 15% vs. 25% vs. 50%) before that number gets locked into the flow. Default starting threshold is 15%, adjustable live in the report.

---

## Notes

- Freight is stored as a separate line item on the invoice (part number 3750), not in a freight field. This is how the source system works.
- Open orders disappear from the source parts table when they are invoiced and closed. Closed history is recovered via the Insalpar_Audit table, which permanently records all changes.
- The FreightCalculator rate table was extended on 2026-05-18 from a 249 lb ceiling to 999,999 lbs, using confirmed carrier rates. The source CSV is kept in `Freight Calculator/` within this project folder.
- The closed fact table uses the Lakehouse SQL Analytics Endpoint (T-SQL) rather than Power Query for performance — avoids loading 10M+ InTrans rows into memory.
- **2026-07-06 fix:** "Freight Opportunity" now means the same thing on the Open and Closed pages (sum of missed freight from No Freight + Partial Freight orders), the freight-status tab totals now compute correctly, and a data bug that was overstating "Actual Freight" totals was found and corrected. Numbers shown before this date may have been overstated.
- **2026-07-08:** Added monthly snapshot infrastructure — `nb_Snapshot_MDInvoices_NoFreight` notebook and `Pipeline_Monthly_MDInvoices_Snapshot` pipeline confirmed working in Fabric, `Fact_MDInvoices_NoFreight_Snapshot` semantic model table refreshes cleanly in Desktop. Not yet published to RP-Dev/Sandbox/production. So the open MD freight backlog will have point-in-time history for future trend analysis. No trend page yet — see CLAUDE.md "Monthly Snapshot" section.
