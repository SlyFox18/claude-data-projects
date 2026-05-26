# Open Order Parts Advisor — Design Spec

**Date:** 2026-04-29
**Status:** Approved — ready for implementation planning
**Working Title:** Open Order Parts Advisor *(final name TBD)*
**Workspace path:** RP - Sandbox (development/validation) → RP - Service Reports (production)

---

## Problem Statement

Service and repair orders often close without all the parts that historically appear with the same job codes. By the time an invoice is cut, the opportunity to add those parts is gone. This report surfaces — while orders are still open — the parts most likely to belong on each active work order based on 3 years of completed order history, so managers can act before the window closes.

---

## Audience

| Role | How they use it |
|---|---|
| After Market Sales Manager | Reviews open orders across branches, calls service writers to prompt part additions |
| Corp Service Manager | Monitors branch-level opportunity, prioritizes outreach by $ impact |

**v1 action:** Phone call to branch. Notifications and downstream integrations are future scope.

---

## Architecture

### Approach: Hybrid — Pre-computed frequency table + DAX join

The historical frequency calculation is computationally expensive (3 years × all job codes × 10M+ InTrans rows). Rather than computing this in DAX at query time (the pattern used in Inspections `ServiceRecommendations`, which works at small scale for 111 inspection codes), we pre-compute frequencies in a Dataflow Gen2 and land the results in the Lakehouse. The semantic model then uses a lightweight DAX calculated table to cross-join open orders against pre-computed frequencies and suppress already-on-order parts.

```
Raw Tables (existing)
  wkothsub  →  job codes on work orders
  wkrofile  →  work order status / header
  InTrans   →  parts on invoiced orders (existing incremental, 2024+)
  Invoice   →  invoice ↔ work order link
  [TBD]     →  parts on open (not-yet-invoiced) orders

Dataflow: df_JobCodePartFrequency  →  Fact_JobCodePartFrequency  (Lakehouse)
Dataflow: df_OpenOrders            →  Fact_OpenOrders             (Lakehouse)
Dataflow: df_OpenOrderParts        →  Fact_OpenOrderParts         (Lakehouse, pending table discovery)

Semantic Model:
  Fact_JobCodePartFrequency  +  Fact_OpenOrders  +  Fact_OpenOrderParts
    → DAX Calculated Table: Recommendations
    → Report pages
```

---

## Data Model

### Fact_JobCodePartFrequency

**Built by:** `df_JobCodePartFrequency` (new Dataflow Gen2)
**Grain:** One row per JobCode × PartNumber combination
**Source tables:** `wkothsub` → `Invoice` → `InTrans` (same join pattern as `Fact_WorkOrderParts` in Inspections — join key is invoice number, NOT work order number)
**Filter:** Invoiced orders only, last 3 years rolling
**Frequency scope:** Global (all branches combined) for statistical reliability

| Column | Description |
|---|---|
| JobCode | Job code (e.g., 8R) |
| JobDescription | Job code description (e.g., A/C Repair) |
| PartNumber | Part number |
| TotalOrdersWithJobCode | Distinct WO count where this job code appeared (invoiced, 3yr) |
| TimesWithPart | Distinct WO count where this job code AND this part appeared together |
| FrequencyPct | TimesWithPart ÷ TotalOrdersWithJobCode |

**Pipeline:** Phase 4, full refresh daily
**Performance note:** This query processes 3 years of InTrans (large). Column selection and pre-aggregation strategy should follow Inspections performance patterns. Monitor refresh time.

---

### Fact_OpenOrders

**Built by:** `df_OpenOrders` (new Dataflow Gen2)
**Grain:** One row per WorkOrder × JobCode
**Source tables:** `wkrofile` (status filter) + `wkothsub` (job codes)
**Filter:** `StatusDisplay NOT "Invoiced"` — same status logic as `Fact_PendingInspections`

| Column | Description |
|---|---|
| WorkOrderNumber | Work order / RO number |
| BranchCode | Branch identifier |
| CustomerNumber | Customer number (for dim_CustomerList join) |
| JobCode | Job code on this open order |
| JobDescription | Job code description |
| OpenDate | Work order creation / open date |

**Pipeline:** Phase 4, full refresh daily (small dataset — expected hundreds to low thousands of rows)

---

### Fact_OpenOrderParts

**Built by:** `df_OpenOrderParts` (new Dataflow Gen2)
**Grain:** One row per WorkOrder × PartNumber
**Source table:** TBD — believed to be `wkpart` or `wkpartfile` in source system. Must investigate via ODBC early in build.
**Purpose:** Suppresses parts already on an open order from appearing in recommendations

| Column | Description |
|---|---|
| WorkOrderNumber | Work order / RO number |
| PartNumber | Part number already committed to this order |

**Pipeline:** Phase 4, full refresh daily
**Fallback:** If source table cannot be found before build deadline, v1 ships without suppression. Recommendations will show all historical parts for each job code. Suppression added in v1.1.

---

### Recommendations (DAX Calculated Table)

**Pattern:** Same as Inspections `ServiceRecommendations` — iterates open orders, looks up historical frequency data, filters out already-on-order parts.
**Logic:**
1. For each row in `Fact_OpenOrders` (each open WO × job code), find all matching rows in `Fact_JobCodePartFrequency` for that job code
2. Filter out any PartNumber that appears in `Fact_OpenOrderParts` for the same WorkOrderNumber
3. Join `dim_Parts` for SellPrice1 and PartDescription

**Output columns:** WorkOrderNumber, BranchCode, CustomerNumber, OpenDate, JobCode, JobDescription, PartNumber, PartDescription, FrequencyPct, TotalOrdersWithJobCode, TimesWithPart, SellPrice

**Estimated size:** ~50K–200K rows depending on open order volume and job code breadth. Acceptable for a calculated table.

---

### Shared Dimensions (no changes required)

| Dimension | Join |
|---|---|
| `dim_BranchLocation` | BranchCode |
| `dim_CustomerList` | CustomerNumber |
| `dim_Parts` | PartNumber (for description and pricing) |
| `dim_DateTable` | OpenDate |

---

## Report Pages

### Page 1: Branch Summary *(landing page)*

**Audience:** Corp Service Manager — "where should I focus today?"

A scoreboard sorted by estimated $ opportunity descending:

| Column | Description |
|---|---|
| Branch | Branch name |
| Open ROs with Recommendations | Count of distinct WOs that have ≥1 recommendation |
| Total Recommendations | Sum of recommendation rows for that branch |
| Est. $ Opportunity | Sum of SellPrice across all recommendations for that branch |

Branch slicer on the page filters Pages 2 and 3.

---

### Page 2: Open Orders

**Audience:** Both managers — "which ROs are the biggest opportunities?"

Flat table of open ROs, default sort by Est. $ Opportunity descending:

| Column | Description |
|---|---|
| RO# / WO# | Work order number (drill-through link to Page 3) |
| Customer | Customer name |
| Branch | Branch name |
| # Job Codes | Distinct job codes on this open order |
| # Recommendations | Recommended parts not already on order |
| Est. $ Opportunity | Sum of SellPrice for this RO's recommendations |
| Top Recommendation | Part # + frequency % of highest-probability missing part |

---

### Page 3: RO Detail *(drill-through)*

**Audience:** Both managers — "what exactly should be on this order?"

**Header:** RO#, Customer, Branch, Open Date, list of job codes on this order

**Main table — flat recommendation list (sorted by FrequencyPct descending):**

| Column | Description |
|---|---|
| Part # | Part number |
| Description | Part description (from dim_Parts — NOT from InTrans) |
| Job Code | Which job code triggered this recommendation |
| Frequency % | Color-coded: 🔴 ≥50%, 🟡 20–49%, ⚪ <20% |
| Appears On | "X of Y orders" — historical context (TimesWithPart of TotalOrdersWithJobCode) |
| Price | SellPrice1 from dim_Parts |

Optional job code slicer at top — filters recommendation list to a specific job code. Not the primary navigation; just a convenience filter.

---

## Pipeline Integration

| Phase | What runs | Where |
|---|---|---|
| Phase 1 | Raw table refresh (existing) — wkothsub, wkrofile, InTrans, Invoice, [new open parts table] | LH_Master_Data |
| Phase 4 | df_JobCodePartFrequency, df_OpenOrders, df_OpenOrderParts | LH_Master_Data |
| Phase 5 | Semantic model refresh | RP - Sandbox → RP - Service Reports |

**Schedule:** 4:15 AM CST Mon–Fri, same as master orchestrator
**Capacity note:** Three new dataflows added to Phase 4. Fact_JobCodePartFrequency may be compute-intensive — monitor CU usage and add to appropriate wave (keep concurrent DFs to 4–5).

---

## Naming Decision

Working title: **Open Order Parts Advisor**
Final name TBD — confirm before publishing to RP - Service Reports.

---

## Open Questions / Risks

| # | Question | Impact | Owner |
|---|---|---|---|
| 1 | What is the source table for parts on open (not-yet-invoiced) orders? | Blocks Fact_OpenOrderParts | Investigate via ODBC at build start |
| 2 | How large is Fact_JobCodePartFrequency in practice? | Pipeline refresh time | Measure during build |
| 3 | Final report name | Report publishing | Brian to decide |

---

## Future Considerations (out of scope for v1)

- Probability threshold slicer (e.g., show only ≥20% recommendations)
- Branch-level frequency calculation (vs. global) if equipment types differ significantly by region
- Push notifications / alerts to service writers
- Minimum sample size indicator (flag job codes with <10 historical appearances as low-confidence)
- Intraday / real-time refresh via DirectQuery or more frequent pipeline runs
