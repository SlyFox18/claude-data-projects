# Associated Parts — Claude Context

## Report Overview
- **Business purpose:** For any selected part, shows the parts customers most reliably buy alongside it — a Part×Part market-basket association across all sales (counter and service work order alike), for parts reordering and recommendation decisions.
- **Primary users:** Parts managers, counter staff
- **Workspace:** RP - Parts Reports (target production workspace; not yet published — see Task 9)
- **Refresh tier:** Weekly (Tier-3-style cadence, off the daily 4:15 AM orchestrator — association patterns are slow-moving and don't need daily freshness)
- **Status:** In development

## Semantic Model

### Fact Tables
| Table | Grain | Key Fields | Notes |
|-------|-------|------------|-------|
| `Fact_PartAssociation` | One row per Franchise × PartA × PartB (directional) | CoOccurrenceCount, AnchorInvoiceCount, AssociatedInvoiceCount, TotalInvoiceCount | Raw counts, not pre-computed percentages — lets DAX correctly roll up to a company-wide (all-franchise) view. Built by a weekly Fabric Notebook, not a Dataflow Gen2 — see Known Issues. |

### Dimensions
| Table | Source | Key Relationship |
|-------|--------|-----------------|
| `dim_Parts_Selected` | Local import of shared `dim_Parts` | `Fact_PartAssociation.PartA → dim_Parts_Selected.PartNumber` |
| `dim_Parts_Recommended` | Local import of shared `dim_Parts` | `Fact_PartAssociation.PartB → dim_Parts_Recommended.PartNumber` |
| `dim_Franchise` | Local import of shared `dim_Franchise` | `Fact_PartAssociation.Franchise → dim_Franchise.Franchise` |

Note: `dim_Parts` is imported **twice** under different table names
(role-playing dimension pattern) because the fact table needs to relate to
it once as "the part the user selected" and once as "the recommended
part." The shared `dim_Parts` dimension itself is untouched — this model
just reads it twice locally.

### Key Measures (in `MeasuresTable`)
| Measure | Description |
|---------|-------------|
| `Co-Occurrence Count` | SUM of Fact_PartAssociation[CoOccurrenceCount] |
| `Anchor Invoices` | De-duplicated (Franchise, PartA) sum of AnchorInvoiceCount — **not** a plain SUM, because AnchorInvoiceCount repeats across every PartB row for the same PartA; a plain SUM would overcount whenever more than one associated part is in context |
| `Associated Invoices` | Same de-duplication pattern, keyed on (Franchise, PartB) |
| `Total Invoices` | Same de-duplication pattern, keyed on Franchise alone |
| `Confidence %` | DIVIDE([Co-Occurrence Count], [Anchor Invoices]) — "of everyone who bought the selected part, what % also bought this one" |
| `Baseline %` | DIVIDE([Associated Invoices], [Total Invoices]) — how often the associated part sells anyway, regardless of the selected part |
| `Lift` | DIVIDE([Confidence %], [Baseline %]) — how much more likely the pairing is than chance; ~1 means the associated part is just universally popular (not a real signal) |

## Report Pages
| Page | Purpose | Visibility |
|------|---------|------------|
| Associated Parts | Part picker + ranked associated-parts table + context card | Visible (not yet built — see Task 9) |

## Data Flow
```
EquipRDB (ODBC) → InTrans_Incremental (Lakehouse)
  → Fact_PartAssociation_Build.ipynb (Fabric Notebook, weekly, DuckDB compute + Spark write)
  → Fact_PartAssociation (Lakehouse Delta table)
```

## Known Issues & Gotchas
- **Not a Dataflow Gen2 fact table** — unlike most fact tables in this repo, `Fact_PartAssociation` is built by a Fabric Notebook. This was a deliberate choice: the Part×Part self-join-on-invoice is the same shape that caused two real multi-minute-to-45-minute M-engine hangs elsewhere (dim_Parts, Fact_PriceUpdate_Enriched) — see the design spec for full reasoning.
- **`AnchorInvoiceCount`/`AssociatedInvoiceCount`/`TotalInvoiceCount` are repeated values, not additive facts** — always aggregate them through the `Anchor Invoices`/`Associated Invoices`/`Total Invoices` measures (which de-duplicate via SUMMARIZE first), never with a bare SUM in new DAX. A bare SUM silently overcounts as soon as more than one row shares the same PartA/PartB/Franchise.
- **Basket-size cap and minimum co-occurrence threshold are data-driven constants**, not universal truths — determined once from a real-data profiling pass (see `docs/superpowers/plans/2026-08-27-associated-parts-recommended-parts.md`, Tasks 2-3) and hardcoded into the notebook. Re-profile if InTrans sales patterns change materially (e.g., after a franchise mix shift).
- **Not yet published anywhere** — semantic model and notebook exist as local files only as of this writing; see Task 9 for the remaining manual Fabric/Desktop steps.

## Refresh Pipeline Position
- Weekly, off the daily Phase 1-5 orchestrator entirely (not yet scheduled — see Task 9)
- Depends on `InTrans_Incremental` (Phase 2, daily) being current

## Documentation Status
- In-repo docs: ✅ CLAUDE.md | ⬜ PROJECT-SUMMARY.md (add if/when this report gets a formal stakeholder handoff)
- Obsidian stakeholder docs: ⬜ Not yet created — run `/document-report` once the report is live in Sandbox/production
