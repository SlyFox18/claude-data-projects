# Associated Parts / Recommended Parts — Report Design

## Overview

A new standalone report that answers "customers who bought Part A also
bought Part B" — a part-to-part market-basket association, computed across
**all sales activity** (counter sales and service work order parts alike),
not scoped to a Job Code the way the existing Inspections "Job Code Parts
Advisor" is.

**Business driver:** Brian wants a reorder/recommendation tool built from
real co-purchase history, generalizing the pattern already proven for
Job Code → Part recommendations (`Fact_JobCodePartFrequency` /
`Fact_JobCodePartFrequency_Branch`, Inspections report) to a Part → Part
grain.

**Precedent this extends:** `Fact_JobCodePartFrequency*.pq`
(`.claude/queries/facts/`) — same invoice-as-basket join convention
(`REF_NO`/`RONumber` = invoice number, confirmed elsewhere in this repo as
NOT the work order number). This design deliberately departs from that
precedent in two ways, both explained below: raw counts instead of
pre-computed percentages, and a DuckDB notebook instead of a Dataflow Gen2
M-engine query.

## Scope & Basket Definition

- **Franchise-aware, company-wide:** all franchises included; `Franchise`
  is part of the fact table's grain (like the `_Branch` JobCode variant),
  so a "company-wide" view is a runtime rollup (sum counts across
  franchise, then compute ratios) rather than a separately computed table.
- **Basket = one invoice.** `(Franchise, Branch, REF_NO)` from
  `InTrans_Incremental`, filtered to `TYPE = 'I'` (invoiced sales only —
  excludes transfers, adjustments, returns) and `QTY > 0`.
- **Time window:** last 24 months, rolling.
- Two parts "go together" if they appear as distinct `PartNumber`s within
  the same basket. Whether the sale originated as a counter sale or a
  service work order line is irrelevant — both feed `InTrans` the same way.

## Grain & Metrics

**`Fact_PartAssociation`** — one row per **ordered** pair
`(Franchise, PartA, PartB)`, `PartA <> PartB`. Ordered/directional because
Confidence(A→B) ≠ Confidence(B→A) — "if you buy a filter you probably also
buy oil" and "if you buy oil you probably also buy a filter" are different
statements with different denominators.

Unlike `Fact_JobCodePartFrequency`, this table stores **raw counts**, not a
pre-computed percentage. This is deliberate: it's what lets one fact table
serve both a franchise-specific view and a true company-wide rollup (sum
counts, then divide — you cannot do that correctly with pre-computed
percentages), and it's what makes the Lift calculation possible at all.

| Column | Type | Meaning |
|---|---|---|
| `Franchise` | text | Franchise the counts are scoped to |
| `PartA` | text | Anchor part |
| `PartB` | text | Associated/recommended part |
| `CoOccurrenceCount` | int | Invoices (this franchise) containing both A and B |
| `AnchorInvoiceCount` | int | Invoices (this franchise) containing A |
| `AssociatedInvoiceCount` | int | Invoices (this franchise) containing B |
| `TotalInvoiceCount` | int | Total qualifying invoices (this franchise) |

**DAX measures** (computed at query time, so they aggregate correctly
whether filtered to one franchise or all of them; the actual shipped
measure names are `Confidence %` and `Baseline %`, not the bare
`Confidence`/`Baseline` used below as shorthand):

- **Confidence** = `CoOccurrenceCount / AnchorInvoiceCount` — "of everyone
  who bought A, what % also bought B"
- **Baseline** = `AssociatedInvoiceCount / TotalInvoiceCount` — "what % of
  all invoices contain B, regardless of A" (how often B just sells anyway)
- **Lift** = `Confidence / Baseline` — how much more likely B is to appear
  *because* A was bought, vs. B's ordinary popularity. Lift ≈ 1 means "B is
  just a universally popular part" (shop rags, grease, common fasteners)
  and should rank low even at high Confidence; Lift > 1 is a genuine pairing
  signal.

This Lift addition is the other deliberate departure from the JobCode
precedent, which only ever computed a Confidence-equivalent
(`FrequencyPct`). Job codes don't have this problem the same way parts do —
a job code's associated parts are already scoped by the work being
performed, whereas a raw part-to-part join has no such natural scoping and
will otherwise surface "everything pairs with WD-40" as a false signal.

## Pipeline & Compute Engine

**Engine: Fabric Notebook + DuckDB** (`delta_scan` against OneLake),
**not** Dataflow Gen2 (M engine), despite Dataflow Gen2 being the
convention for most fact tables in this repo. Part×Part self-join-on-invoice
is a materially heavier combinatorial join than JobCode×Part — this repo
already has two confirmed real incidents (dim_Parts, Fact_PriceUpdate_Enriched)
where bundling this class of heavy per-group logic into the M engine caused
multi-minute-to-45-minute hangs, and this workload is a bigger version of
the same shape. DuckDB is the same engine already proven for ad-hoc
Lakehouse analysis (Kurt Sales pattern) and does self-join/group-by/aggregate
natively.

If DuckDB single-node memory turns out insufficient for 24 months of
`InTrans` self-joined at real volume, fall back to a PySpark notebook for
distributed compute — decide only if profiling shows it's actually needed,
don't pre-build it.

**Notebook logic:**

1. Read `InTrans_Incremental`, filter `TYPE = 'I'`, `QTY > 0`,
   `Trans_Datetime` within the last 24 months.
2. Build baskets: distinct `(Franchise, Branch, REF_NO)` → set of distinct
   `PartNumber`s.
3. **Basket size cap** — profile the real distinct-parts-per-invoice
   distribution first (not yet measured anywhere in this repo), then
   exclude or cap outlier baskets above a data-driven threshold. A single
   large shop order or bulk counter sale with dozens of distinct parts
   generates hundreds of pairs and would otherwise dominate/pollute the
   association signal without reflecting a genuine "these go together"
   decision. Exact cutoff (e.g. a percentile) determined during
   implementation from real data, not guessed here.
4. Generate ordered part pairs within each surviving basket; aggregate into
   the four counts above, grouped by `Franchise`.
5. **Minimum `CoOccurrenceCount` threshold** — drop pairs below a minimum
   (starting point: 5, tuned during implementation) so the table isn't
   dominated by one-off noise pairs and stays a sane size. This is the main
   lever controlling total row count.
6. Write to a new Lakehouse Delta table, `Fact_PartAssociation`.

**Schedule:** weekly, off the daily 4:15 AM Phase 1-5 orchestrator
entirely — same Tier-3-style cadence as Price Matrix / Bin Location.
Association patterns are slow-moving; there's no case for daily freshness,
and keeping this off the critical path avoids adding load to an already
capacity-constrained pipeline.

**Standard Data Refresh watermark** included, same UTC→Central-aware
pattern as every other report (`.claude/queries/DATA-REFRESH-TEMPLATE.pq`).

## Semantic Model

`dim_Parts` is shared across 9+ reports. This fact table needs to join to
it **twice** — once as "the part the user selected" and once as "the
recommended part" — a role-playing-dimension situation. Rather than adding
a second relationship to the shared `dim_Parts` (relationship ambiguity
risk) or forcing every measure through `USERELATIONSHIP()`, this report
gets two **local reference copies**: `dim_Parts_Selected` and
`dim_Parts_Recommended`, each with one single active relationship to
`Fact_PartAssociation` (on `PartA` and `PartB` respectively). Keeps this
report fully self-contained and leaves the shared `dim_Parts` untouched.

**Tables:** `Fact_PartAssociation`, `dim_Parts_Selected`,
`dim_Parts_Recommended`, `dim_Franchise`, Data Refresh table.

## Report — Single Page

- **Part selector** slicer, bound to `dim_Parts_Selected` — search by part
  number or description.
- **Franchise slicer**, defaulting to all franchises combined (measures sum
  raw counts across franchise before computing ratios — a real aggregate,
  not an average-of-percentages error).
- **Main table** — ranked associated parts for the selected part:
  `dim_Parts_Recommended` description, `CoOccurrenceCount`, Confidence %,
  Lift, sorted by Lift (toggleable to Confidence) descending. Top N (e.g.
  20) is a report/DAX-level filter, not baked into the ETL, so it stays
  adjustable without a notebook re-run.
- **Context card** — total invoices for the selected part
  (`AnchorInvoiceCount`), so "90% confidence on 4,000 invoices" and "90%
  confidence on 6 invoices" aren't visually mistaken for equally strong
  signals.

## Open Items (deferred to implementation)

- Exact basket-size cap threshold — requires profiling real
  distinct-parts-per-invoice distribution in `InTrans_Incremental`.
- Exact minimum `CoOccurrenceCount` threshold — starting point 5, tune
  against real row counts and result quality.
- Whether DuckDB alone is sufficient or a PySpark fallback is needed —
  decide from real profiling, not speculatively.
