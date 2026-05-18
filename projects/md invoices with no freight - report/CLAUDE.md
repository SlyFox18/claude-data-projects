# MD Invoices With No Freight — Claude Context

## Report Overview
- **Business purpose:** Identifies Machine Down (emergency) parts orders where freight was not charged or was under-charged. Calculates what freight should have been based on part weights and a carrier rate table, and surfaces the missed revenue opportunity by branch and salesperson.
- **Primary users:** Branch managers, parts/service leadership, salespersons
- **Workspace:** RP - Parts Reports (production)
- **Refresh tier:** Tier 2 — daily
- **Status:** Production

## Semantic Model

### Fact Tables
| Table | Grain | Key Fields | Notes |
|-------|-------|------------|-------|
| Fact_MDInvoices_NoFreight | One row per part line on an open MD order | FileNumber, LineNumber, Branch, PartNumber, TotalLineWeight, TotalFreightCharged, FreightStatus | Open orders only; sourced from insalpar (PurOrderType = 'E') |
| Fact_MDInvoices_Closed | One row per invoiced part line on a closed MD order | FileNumber, TransId, Branch, PartNumber, TotalLineWeight, TotalFreightCharged, FreightStatus | Closed orders 2024-01-01 forward; uses SQL endpoint approach — NOT Power Query Mashup engine |

### Dimensions
| Table | Source | Key Relationship |
|-------|--------|-----------------|
| dim_BranchLocation | Shared Lakehouse | Branch → both Fact tables |
| dim_DateTable | Shared Lakehouse | OrderDate / InvoiceDate → Fact tables |
| dim_CustomerList | Shared Lakehouse | CustomerNumber → Fact tables |
| dim_Parts | Shared Lakehouse | PartNumber → Fact tables |
| dim_Franchise | Shared Lakehouse | Franchise → Fact tables |
| dim_Salesperson | Shared Lakehouse | Salesperson → Fact tables |
| FreightCalculator | LH_Master_Data Delta table (no dataflow — manually maintained) | No model relationship — used only in DAX via FILTER/MAXX lookup |
| dim_FreightPerformanceGroup | DAX DATATABLE (calculated) | Slicer: No Freight / Needs Review / Good / Above Baseline |

### Key Measures — Open Orders
| Measure | What It Calculates |
|---------|-------------------|
| Total MD Invoices | DISTINCTCOUNT of open MD order numbers |
| Total Invoices No Freight | Orders with no freight line (part 3750) at all |
| Total Invoices With Freight | Orders where part 3750 has a positive amount |
| No Freight Rate | % of MD invoices with zero freight charged |
| Total Parts Value | SUM of LineTotal across all open MD lines |
| Total Weight | SUM of TotalLineWeight across all open MD lines |
| Actual Freight | SUM of TotalFreightCharged per order (from part 3750 lines) |
| Calculated Freight | Estimated freight using FreightCalculator rate table |
| Missed Freight | Calculated minus Actual (the opportunity gap) |
| Freight Above Baseline | Orders where actual exceeded calculated |
| Freight Opportunity | Orders where actual was below calculated |

Closed invoice equivalents exist for all measures above with a `Closed -` prefix.

## Report Pages
| Page | Purpose | Key Visuals |
|------|---------|-------------|
| Open Orders | List of open MD invoices with freight status detail | Hero card, invoice table with FreightStatus color coding, group filter tabs |
| Open Performance | Branch and salesperson performance on open orders | Hero card, ranked tables by no-freight rate and opportunity |
| Closed Invoices | Historical closed MD invoice freight analysis (2024+) | Hero card, invoice detail table |
| Closed Performance | Branch and salesperson performance on closed invoices | Hero card, ranked tables |
| How It Works | Embedded plain-English methodology explanation | HTML visual describing freight detection and calculation logic |

## Data Flow
```
insalpar (ODBC)         → insalpar (Raw, Phase 1)      → Fact_MDInvoices_NoFreight (Phase 4)
Insalpar_Audit (ODBC)   → Insalpar_Audit (Raw, Phase 1) ┐
InTrans_Incremental     → (Phase 2)                     ┘→ Fact_MDInvoices_Closed (Phase 4)
jdis_Part_Information   → (Raw, Phase 1)                 → weight lookup in both fact queries
Insalord                → (Raw, Phase 1)                 → order header data for open fact
FreightCalculator       → (manual Delta table)           → DAX measure lookups only
```

## Freight Calculation Logic — Read Before Modifying Measures

**FreightCalculator table:** Weight brackets with `BaseRate` and `AdditiveRatePerPound` columns.
Last updated: 2026-05-18 (extended beyond old 249 lb ceiling to 999,999 lbs).

**Rate structure (two tiers by total order weight):**
- **≤ 150 lbs total order weight:** One `BaseRate` per order (looked up by total weight bracket) + `AdditiveRatePerPound × TotalLineWeight` per line
- **> 150 lbs total order weight:** No base rate ($0). Each line calculated independently:
  - 151–499 lbs: $1.10/lb
  - 500–999 lbs: $0.45/lb
  - 1,000–1,999 lbs: $0.32/lb
  - 2,000–4,999 lbs: $0.25/lb
  - 5,000+ lbs: $0.15/lb

**DAX filter boundary handling:** Uses `(PartWeightTo + 1) > LineWeight` (not `>=`) to correctly match decimal weights at bracket edges (e.g., 30.7 lbs correctly resolves to the 26–30 bracket).

**Fallbacks:** `BaseRate` defaults to $0 if no bracket found; `AdditiveRatePerPound` defaults to $0.15.

## How Freight Is Detected

Freight is stored as a **line item with PartNumber = 3750** on the invoice — it is NOT in `Insalord.Freight` (that field is unused in the source system). Three statuses:
- **No Freight** — no 3750 line exists on the order (never entered)
- **No Freight Charged** — 3750 line exists but amount is $0
- **Has Freight** — 3750 line exists with a positive amount

Multiple 3750 lines per order are valid (one per shipment). `TotalFreightCharged` = SUM of all.

## Known Issues & Gotchas

- **FreightCalculator has no dataflow.** It is a manually maintained Delta table. To update rates: upload new CSV to Lakehouse Files, then use a PySpark notebook with `.save("Tables/FreightCalculator")` — do NOT use `saveAsTable()` (Hive metastore casing causes `freightcalculator` vs `FreightCalculator` conflicts). See `Freight Calculator/` folder for the current CSV source files.
- **Fact_MDInvoices_Closed uses the SQL Analytics Endpoint directly** (T-SQL, not Power Query Mashup engine). This avoids loading the 10M+ row InTrans_Incremental table into memory. If the SQL endpoint URL changes, update the `SqlEndpoint` variable in `queries/fact tables/Fact_MDInvoices_Closed.pq`.
- **Closed orders disappear from insalpar when invoiced** — they are recovered via `Insalpar_Audit`, which permanently records all changes (including deletes) to insalpar. The audit table is the only source of historical emergency FileNos.
- **Weight is stored as varchar in jdis_Part_Information** — converted via `TRY_CAST` (SQL) or `Number.From` with try/otherwise (Power Query). Falls back to 0 for parts not found in jdis.
- **Negative 3750 values are valid** — freight credits/adjustments. Included in TotalFreightCharged (correct behavior per investigation).
- **Some older orders (2018–2019) have NULL UnitCost** — expected, not a bug.

## Refresh Pipeline Position
- **Fact_MDInvoices_NoFreight:** Phase 4 — `df_Fact_MDInvoices_NoFreight`. Depends on insalpar, Insalord, jdis_Part_Information (all Phase 1).
- **Fact_MDInvoices_Closed:** Phase 4 — `df_Fact_MDInvoices_Closed`. Depends on Insalpar_Audit (Phase 1), InTrans_Incremental (Phase 2), jdis_Part_Information (Phase 1).
- FreightCalculator is static — refreshes only when manually updated via notebook.

## Freight Calculator Source Files
- **Updated CSV (use this):** `Freight Calculator/FREIGHT CALCULATOR 2026 - UPDATED.csv`
- **Original reference:** `Freight Calculator/FREIGHT CALCULATOR 2026.csv`

## Documentation Status
- In-repo docs: ✅ CLAUDE.md | ✅ PROJECT-SUMMARY.md
- Obsidian stakeholder docs: ✅ Complete — `Data Projects/Reports/MD Invoices With No Freight.md`
