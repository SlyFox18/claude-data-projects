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
| dim_FreightPerformanceGroup | DAX DATATABLE (calculated) | Slicer: No Freight / Partial Freight / Adequate Freight (renamed 2026-06-29, was Needs Review / Good / Above Baseline). **Now has a real relationship** (added 2026-07-06) to `Fact_MDInvoices_NoFreight[FreightBucket]` and `Fact_MDInvoices_Closed[FreightBucket]` — see "Freight Opportunity Fix" below. |

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
| Missed Freight | Calculated minus Actual, net (can go negative) — used only for the per-invoice detail column, not for aggregate KPIs |
| Freight Above Baseline | Orders where actual exceeded calculated |
| Freight Opportunity | **The canonical Opportunity KPI.** = `No Freight Bucket - Missed Freight` + `Partial Freight Bucket - Missed Freight` (see "Freight Opportunity Fix" below). Always ≥ 0 — Adequate Freight invoices never add to or subtract from it. |

Closed invoice equivalents exist for all measures above with a `Closed -` prefix. `Closed - Freight Opportunity` is defined the identical way (sum of the two Closed bucket measures) — do not confuse with `Closed - Missed Freight`, which is the net per-invoice detail column only.

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

**Rate structure (simplified 2026-06-24 — single bracket lookup on order TOTAL weight):**
- One bracket lookup per order, keyed on the SUM of `TotalLineWeight` across all lines on that order — NOT each line's individual weight
- `Calculated Freight = BaseRate + (AdditiveRatePerPound × TotalOrderWeight)`
- Brackets above 150 lbs have `BaseRate = $0` baked into the FreightCalculator table itself, so this single formula naturally produces "no base rate over 150 lbs" without a separate branch
- Individual line weights no longer affect the rate — only the order's total weight decides which bracket (and therefore which rate) applies
- Applies identically to `Calculated Freight` (open, `Fact_MDInvoices_NoFreight`) and `Closed - Calculated Freight Single Invoice` (closed, `Fact_MDInvoices_Closed`) — keep both in sync if this changes again

**DAX filter boundary handling:** Uses `(PartWeightTo + 1) > InvTotalWeight` (not `>=`) to correctly match decimal weights at bracket edges (e.g., 30.7 lbs correctly resolves to the 26–30 bracket).

**Fallbacks:** `BaseRate` defaults to $0 if no bracket found; `AdditiveRatePerPound` defaults to $0.15.

**Performance — `MissedFreightAmount` calculated column (added 2026-06-24):** `Fact_MDInvoices_NoFreight[MissedFreightAmount]` pre-computes the per-invoice Calculated Freight minus Actual Freight gap **once at refresh time**, using `CALCULATE(..., ALLEXCEPT(Fact_MDInvoices_NoFreight, Fact_MDInvoices_NoFreight[FileNumber]))` to aggregate to the invoice grain from the line-grain fact table. `Is In Selected Group`, `Freight Status Color`, and `Missed Freight Icon` read `MAX(Fact_MDInvoices_NoFreight[MissedFreightAmount])` instead of calling `[Missed Freight]` live.
- **Why:** the Open Orders page tabs (No Freight / Needs Review / Good-Above Baseline) filter the matrix visual using `Is In Selected Group`, a measure-based Advanced filter. Measure-based visual filters can't be pushed to the VertiPaq engine — Power BI falls back to formula-engine row-by-row evaluation across the *entire* table, re-run on every interaction (including each matrix row expand/collapse). With `[Missed Freight]` → `[Calculated Freight]` doing nested `SUMX`/`CALCULATE`/bracket-lookup work, this made every click take 10+ seconds.
- **If adding new freight-status-dependent measures or filters:** read from `MissedFreightAmount` (the column), not `[Missed Freight]` (the measure), to stay fast. Only recompute live if the value must react to interactive slicers beyond the row's own data (it currently does not need to).

**`PctFreightDifference` calculated column (added 2026-06-24):** same caching pattern as `MissedFreightAmount`, but stores the `% Freight Difference` ratio per invoice. Backs the Alert Threshold feature below — added as its own column rather than derived from `MissedFreightAmount` so the threshold comparison never has to call a live measure.

## Alert Threshold (Open Orders page) — future Power Automate hook

A What-If parameter table, `% Freight Difference Threshold` (`GENERATESERIES(0, 200, 1)`, same convention as `New Markup %` in the Price Matrix report), drives a slider on the Open Orders page next to the freight-status tabs.
- `'% Freight Difference Threshold Value'` (lives in the parameter table) = `SELECTEDVALUE(..., 15)` — default 15%, adjustable live.
- `Exceeds Freight Difference Threshold` (`_Measures`) — compares `Fact_MDInvoices_NoFreight[PctFreightDifference]` (cached column) against the selected threshold ÷ 100. Drives `Pct Freight Difference Color` (cell background on % Freight Difference) and `Invoices Exceeding Freight Difference Threshold` (count, not currently on a visual — available for a future card).
- **Why this exists:** the stakeholder wants a Power Automate flow that emails the branch manager when an invoice's % Freight Difference crosses a threshold, but hasn't picked a number yet. This slider lets him test candidate thresholds against live data before that percentage gets hardcoded into the flow. When the number is finalized, hardcode it into the Power Automate trigger (or keep reading this parameter via the dataset if the flow can query it) and consider whether the slider stays in the report or gets removed.

## How Freight Is Detected

Freight is stored as a **line item with PartNumber = 3750** on the invoice — it is NOT in `Insalord.Freight` (that field is unused in the source system). Three statuses:
- **No Freight** — no 3750 line exists on the order (never entered)
- **No Freight Charged** — 3750 line exists but amount is $0
- **Has Freight** — 3750 line exists with a positive amount

Multiple 3750 lines per order are valid (one per shipment). `TotalFreightCharged` = SUM of all.

## Freight Opportunity Fix (2026-07-06)

Ben (stakeholder) flagged that "Opportunity" didn't mean the same thing on the Open vs. Closed pages, and separately that the Partial Freight tab's Total row showed an impossible negative number. Both were real bugs, now fixed:

**1. Inconsistent Opportunity definition.** Open's `Freight Opportunity` summed only positive per-invoice gaps (gross); Closed's Hero Card used `Closed - Missed Freight`, a net figure where over-charged invoices silently offset under-charged ones. Fixed by defining Opportunity identically on both sides: sum of the No Freight bucket's missed freight + the Partial Freight bucket's missed freight (Adequate Freight invoices never contribute). New measures: `No/Partial Freight Bucket - Missed Freight` (both sides), with `Freight Opportunity` / `Closed - Freight Opportunity` as their sum.

**2. Tab Total row showed impossible numbers.** The No Freight / Partial Freight / Adequate Freight tabs filtered the invoice table via `Is In Selected Group`, a measure-based Advanced filter — a known Power BI weak spot where the visual's Total row doesn't reliably respect the same filter as the detail rows. Fixed by adding a real `FreightBucket` calculated column to both fact tables and a genuine relationship to `dim_FreightPerformanceGroup[Group]`, so the tab slicer now filters via a normal relationship instead of a measure comparison. `Is In Selected Group` / `Closed - Is In Selected Group` are no longer used for filtering (left in the model, unused, in case anything else still references them) — the row-level color/icon measures (`Freight Status Color`, `Missed Freight Icon`, etc.) are unaffected.
- **Side effect to know about:** adding that relationship meant the tab slicer started cross-filtering *every* visual on the page connected to the fact table by default (including the Hero Card). Fixed via Edit Interactions (`visualInteractions` in `page.json`) — only the invoice table responds to the tab slicer now. If you add new card/chart visuals to the Open Orders or Closed Invoices pages, you'll likely need to add a `NoFilter` interaction entry for them too, or they'll start changing value when someone clicks a tab.
- **Edit Interactions gotcha:** only add `visualInteractions` entries for genuinely data-bound visual types (card, htmlContent, slicer, chart, table). Including textboxes, images, shapes, page navigators, or visual-group containers crashes Desktop's renderer (`VisualRelationshipService.getRelationship` → undefined). Desktop's own Edit Interactions UI never generates entries for those types — don't hand-add them either.

**3. The real underlying bug: `Actual Freight` overcounted.** `Actual Freight` and `Closed - Actual Freight` used `SUMX(VALUES(FileNumber), MAX(TotalFreightCharged))` — a **bare** aggregation function with no explicit `CALCULATE()` wrapper. This produced wildly inflated totals whenever summed across multiple invoices at once (confirmed via live DAX query: bare `MAX()` gave $11,020.80 for a 32-invoice bucket that should have totaled $1,898.50). This was a pre-existing bug, not something introduced by the tab-filter fix — it just never surfaced until per-bucket totals were scrutinized. Fixed by wrapping in `CALCULATE(MAX(...))`, matching the pattern `Calculated Freight` already used correctly. **This means historical screenshots/exports of "Freight Assigned"/"Freight Collected" Hero Card figures from before 2026-07-06 were likely overstated** — not just the bucket breakdowns.
- **General DAX lesson:** any bare aggregation function (`MAX`, `SUM`, `MIN`, etc., not wrapped in `CALCULATE`) used inside `SUMX(VALUES(Table[Key]), ...)` to de-duplicate a line-grain table to header grain is unreliable under compounded filter contexts. Always wrap it explicitly: `CALCULATE(MAX(Table[Col]))`. Measure references (`[Measure Name]`) inside the same pattern are safe and don't need this — only bare column aggregation functions do. Worth checking other reports in this repo that use the same `SUMX(VALUES(...), MAX(...))` de-dup pattern.

## Known Issues & Gotchas

- **FreightCalculator has no dataflow.** It is a manually maintained Delta table. To update rates: upload new CSV to Lakehouse Files, then use a PySpark notebook with `.save("Tables/FreightCalculator")` — do NOT use `saveAsTable()` (Hive metastore casing causes `freightcalculator` vs `FreightCalculator` conflicts). See `Freight Calculator/` folder for the current CSV source files.
- **Fact_MDInvoices_Closed uses the SQL Analytics Endpoint directly** (T-SQL, not Power Query Mashup engine). This avoids loading the 10M+ row InTrans_Incremental table into memory. If the SQL endpoint URL changes, update the `SqlEndpoint` variable in `queries/fact tables/Fact_MDInvoices_Closed.pq`.
- **Closed orders disappear from insalpar when invoiced** — they are recovered via `Insalpar_Audit`, which permanently records all changes (including deletes) to insalpar. The audit table is the only source of historical emergency FileNos.
- **Weight is stored as varchar in jdis_Part_Information** — converted via `TRY_CAST` (SQL) or `Number.From` with try/otherwise (Power Query). Falls back to 0 for parts not found in jdis.
- **Negative 3750 values are valid** — freight credits/adjustments. Included in TotalFreightCharged (correct behavior per investigation).
- **Some older orders (2018–2019) have NULL UnitCost** — expected, not a bug.
- **Matrix numeric value-well aggregation defaults to the wrong thing.** Adding `RONumber` to a matrix's Values well auto-selected `CountNonNull` (counts lines with a non-blank RO#) instead of showing the actual number. Since RO# is constant per invoice, the fix is `Max` aggregation, not `Sum`/`Count`. Check the aggregation function on any column dropped directly into a matrix/table Values well — Power BI's default choice for numeric columns is not always "show the value."
- **Order Type slicer added 2026-06-24** on the Open Orders page, using `Fact_MDInvoices_NoFreight[OrderType]` (sourced from `Insalord.TYPE`).
- **Freight performance bucket names renamed 2026-06-29** (Ben's feedback): "Needs Review" → "Partial Freight", "Good / Above Baseline" → "Adequate Freight". "No Freight" unchanged. This was a DAX-only change — `dim_FreightPerformanceGroup` (the DATATABLE) and `Is In Selected Group` / `Closed - Is In Selected Group` (both reference the same shared table, so both had to change together). **No fact table or `FreightStatus` column changes** — `FreightStatus` ("No Freight" / "No Freight Charged" / "Has Freight") is a distinct, lower-level concept from these report-level performance buckets. Tab button labels update automatically since they're bound to `dim_FreightPerformanceGroup[Group]`, not hardcoded text. Don't confuse these bucket names with the unrelated `Freight Above Baseline` measure (a dollar-amount KPI) — that measure name was intentionally left alone.
- **Closed Invoices matrix has no RO # column, and can't.** `Fact_MDInvoices_Closed` is built from `Insalpar_Audit` + `InTrans_Incremental` — neither carries RO Number. `Insalord` has it, but there's no `Insalord_Audit` recovery table (unlike `insalpar`), so once an order invoices and drops out of `Insalord`, its RO# isn't recoverable. Don't try to add this column without new source/ETL work.
- **`Closed - % Freight Difference` added 2026-06-29** to mirror page 1's matrix on the Closed Invoices page (Ben's request). Same formula as `% Freight Difference`, built on `[Closed - Calculated Freight]` / `[Closed - Actual Freight]`. Deliberately **no** Alert Threshold slider/conditional coloring on this one — that feature is open-orders-specific for now (see "Alert Threshold" section above); Closed just shows the plain value.

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
