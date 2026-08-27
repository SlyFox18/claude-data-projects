# Fact_PartAssociation

**Notebook:** `projects/associated parts - report/notebooks/Fact_PartAssociation_Build.ipynb`
**Fabric item:** Notebook in `LH_Master_Data` workspace (create per Task 9 checklist)
**Output:** Lakehouse Delta table `Fact_PartAssociation`

## Purpose

Part×Part market-basket association. For each Franchise × PartA × PartB,
how often do invoices containing PartA also contain PartB — across **all**
sales activity (counter sales and service work order parts alike), not
scoped to a Job Code the way `Fact_JobCodePartFrequency` is.

## Grain

One row per `(Franchise, PartA, PartB)`, directional (PartA→PartB is a
separate row from PartB→PartA).

## Source & Filters

- Source: `InTrans_Incremental` (Lakehouse), last 24 months
- `Type = 'I'` (invoiced sales only), `Qty > 0`
- Basket = one invoice: `(Franchise, Branch, RONumber)`
- Basket-size cap: 25 distinct parts (excludes
  the top ~1% of invoices by distinct-part count — large shop orders/bulk
  counter sales that would otherwise dominate the pair counts without
  reflecting a genuine "these go together" pairing). Determined 2026-08-27
  from real profiling: P99 distinct-parts-per-invoice = 24 across 447,661
  qualifying invoices, rounded up to the nearest 5.
- Minimum `CoOccurrenceCount`: 10 (drops
  one-off noise pairs). Determined 2026-08-27 from real validation: at this
  threshold, `Fact_PartAssociation` has 44,326 rows (vs. 229,452 at a
  threshold of 3, and 108,338 at a threshold of 5) — the only candidate
  landing in a usefully small "tens of thousands" range.

## Output Columns

| Column | Type | Meaning |
|---|---|---|
| `Franchise` | text | Franchise the counts are scoped to |
| `PartA` | text | Anchor part |
| `PartB` | text | Associated/recommended part |
| `CoOccurrenceCount` | int | Invoices (this franchise) containing both A and B |
| `AnchorInvoiceCount` | int | Invoices (this franchise) containing A |
| `AssociatedInvoiceCount` | int | Invoices (this franchise) containing B |
| `TotalInvoiceCount` | int | Total qualifying invoices (this franchise) |

Raw counts, not pre-computed percentages — deliberate, so the semantic
model can produce both a franchise-specific view and a true company-wide
rollup (sum counts, then divide) from one table, and so Lift can be
computed at all. See design doc for full rationale.

## Refresh

Weekly (Tier-3-style cadence, off the daily 4:15 AM orchestrator). Set up
per Task 9's checklist — not yet wired into any pipeline as of this
writing.

## Related

- Precedent: `Fact_JobCodePartFrequency` / `Fact_JobCodePartFrequency_Branch`
  (Inspections report) — same invoice-as-basket join convention, but
  JobCode×Part instead of Part×Part, and pre-computed percentages instead
  of raw counts.
- Full design: `docs/superpowers/specs/2026-08-27-associated-parts-design.md`
- Full validation history (real profiling/threshold numbers): `docs/superpowers/plans/2026-08-27-associated-parts-recommended-parts.md`, Tasks 2-4
