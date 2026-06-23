# Service Time Sheets — Claude Context

## Status
**Production** ✅ — Live in RP - Service Reports. Built 2026-05-28. Invoice Labor Reconciliation page added 2026-06-22.

## Business Purpose
Payroll audit tool for service technician draw pay. Two complementary perspectives:
- **Time Sheet Audit** — starts from submitted Excel time sheets, cross-references against EquipRDB invoice records, classifies each submission into audit buckets before draw pay is approved.
- **Invoice Labor Reconciliation** — starts from every closed EquipRDB work order with labor invoiced, checks whether a matching time sheet exists, and compares hours/dollars from the invoice side.

Primary audience: CFO, Service Manager, Payroll.

## Semantic Model
**Path:** `reports/Service Time Sheets.SemanticModel/definition/`

### Fact Tables (2)
| Table | Grain | Source | Pipeline |
|---|---|---|---|
| Fact_ServiceTimeSheet_Audit | Technician × RO × Pay period | service_time_sheets + TechnicianInvoiceDetail + TechnicianPunchedDetail + WKROFILE | Phase 4 |
| Fact_InvoiceLabor | TechCode × closed WorkOrder | TechnicianInvoiceDetail + WKROFILE + service_time_sheets + dim_CustomerList | Phase 4 |

**No shared dimension relationships.** Both fact tables are fully denormalized. All slicing is done on fact table columns directly. This is intentional.

**Fact_InvoiceLabor — key design notes:**
- Filtered to `InvoiceDate >= 2026-01-01` (historical data pre-dates the report)
- `IsClosed = "Y"` gates inclusion — only finalized invoices
- WKROFILE `AccountNumber` is stored as Decimal in the Lakehouse; must route through `Int64.From` before `Text.From` to avoid "51200.0" suffix breaking the join to `dim_CustomerList`
- Five ReconciliationStatus buckets: No Draw Expected / Missing Sheet / Match / Overclaimed / Underclaimed

### EquipRDB Source Tables Used
- `TechnicianInvoiceDetail` — invoiced hours and dollars; only present for invoiced job codes
- `TechnicianPunchedDetail` — all clocked hours regardless of invoice status (Audit only)
- `WKROFILE` — RO header; `IsClosed = "Y"` is the authoritative closure signal
- `dim_CustomerList` — customer name, type, key account flag (Invoice Labor only; joined via AccountNumberText)

## Seven AuditStatus Buckets (evaluated in order)
1. **Draw - Open RO** — InvoicedHrs = null AND any Draw1/2/3/FinalDrawHrs > 0
2. **Pending Invoice** — InvoicedHrs = null AND no draw history
3. **Match** — ABS(CrossPeriodClaimedHrs − Invoiced) < 0.001 hrs
4. **Invoiced More Than Claimed** — system billed more than tech claimed (CrossPeriod basis)
5. **Partial Invoice - In Progress** — Claimed > Invoiced AND IsClosed ≠ "Y" AND PunchedHrs > InvoicedHrs × 1.1
6. **Draw - In Progress** — has PctComplete < 1.0 (job not 100% complete per CFO draw tracking)
7. **Claimed More Than Invoiced** — everything else where CrossPeriodClaimed > Invoiced (real flag)

**CrossPeriodClaimedHrs** is the sum of TotalClaimedHrs across ALL pay periods for the same RONumber+TechNum. HoursDifference = CrossPeriodClaimedHrs − InvoicedHrs. This prevents multi-draw scenarios from incorrectly landing in "Claimed More" or "Invoiced More" based on a single period's hours.

**Critical distinction:** `IsClosed = "Y"` from WKROFILE is what separates bucket 5 (open RO, more billing coming) from bucket 6 (closed RO, real discrepancy). Do not remove or weaken this check.

**Draw vs Pending Invoice:** A draw advance fills in Draw1–FinalDrawHrs (cross-period history). Completed work only fills CurrentDrawHrs. If InvoicedHrs is null and there is no draw history, it is "Pending Invoice" — not a draw.

## Pay Rates
- Level 3 = $40/hr, Level 4 = $43/hr, Level 5 = $46/hr
- SM (Service Manager) = null pay rate, excluded from dollar calculations
- Validate with HR before any production payroll run

## Column Layout Auto-Detection
The raw dataflow reads the column 13 header in row 7 of each tech tab:
- Starts with "shop" → Shop/Field layout (ShopHrs + FieldHrs + AfterHours ± Mileage)
- Starts with "current" → Standard layout (CurrentDrawHrs + AfterHours ± Mileage)

`TotalClaimedHrs = (CurrentDrawHrs ?? ShopHrs + FieldHrs) + AfterHours`

## Report Pages (7)
| Page | Name | Purpose |
|---|---|---|
| Home | Navigation & Guide | Drill-through flow diagram + audit status color legend |
| 1 | Executive Summary | Hero card KPIs + Tech Risk Leaderboard + Location Scorecard |
| 2 | Time Sheet Audit | Full row-level detail table |
| 3 | Tech Audit Detail | Per-tech drill-through (right-click tech name on page 2) |
| 4 | Multi-Tech RO Detail | Per-RO drill-through (right-click RO on page 3) |
| 5 | Multi-Tech RO Review | Standalone shared-work RO table |
| 6 | Invoice Labor Reconciliation | Invoice-centric view from Fact_InvoiceLabor; month slicer + collapsible branch/tech slicers; hero card + row-level detail table |

## Key Measures to Know

**Time Sheet Audit:**
- `# Pending` = Partial Invoice - In Progress (◆ in hero card) — NOT the same as `# Pending Invoice`
- `Net Overclaim $` = TechPay − LaborBilled scoped to "Claimed More Than Invoiced" rows
- `Underpay Risk $` = (InvoicedHrs − ClaimedHrs) × PayRate for "Invoiced More" rows
- `Overclaim Rate %` = # Claimed More ÷ (Match + Claimed More + Invoiced More)

**Invoice Labor Reconciliation (IL prefix):**
- `IL Total Labor Billed` / `IL Total Tech Draw Paid` / `IL Labor Gap` / `IL Labor Gap %`
- `IL Total WOs` / `IL Total Invoiced Hrs` / `IL Total Claimed Hrs`
- `# IL Match` / `# IL Overclaimed` / `# IL Underclaimed` / `# IL Missing Sheet` / `# IL No Draw Expected`
- `IL Row Color` — background CF by ReconciliationStatus (use on table rows)
- `IL Status Color` — font color CF for Reconciliation column
- `Hero Card - Invoice Labor` — HTML hero card (6 sections: WOs / Labor Billed / Tech Labor Paid / Labor Margin / Margin % / Match-Over-Under counts)

All hero cards are HTML measures in `_Measures.tmdl`.

## Known Gotchas
- **Fan-out prevention:** TID and TPD are grouped to {WorkOrder, TechCode} BEFORE the join to the fact table. If you ever see inflated InvoicedHrs or PunchedHrs, check whether grouping was accidentally removed.
- **RONumber type:** RONumber is a float in the source. Converted to text (`RONumberText`) for all joins. Never join on the numeric RONumber column — the text version is the key.
- **Branch resolution:** TID Branch is preferred (invoiced ROs). Falls back to TPD Branch for open ROs. If both null, Branch is blank — this can happen for ROs with no system records at all.
- **Match tolerance is 0.001 hrs** — intentionally tight to catch any real billing gap. Do not loosen without discussing with CFO.
- **Credit/reversal rows:** Negative InvoicedHrs from billing reversals. The `PunchedHrs > InvoicedHrs × 1.1` guard in bucket 5 prevents these from incorrectly landing in "Partial Invoice."
- **TMDL files do NOT support `//` comments** at the structural level. DAX `//` inside backtick measure expressions is fine. Never add `//` comment lines between TMDL keywords.
- **WKROFILE AccountNumber is Decimal in the Lakehouse** — `Text.From(51200.0)` produces "51200.0", not "51200", breaking the join to `dim_CustomerList`. Always route through `Int64.From` first: `Text.From(Int64.From([AccountNumber]))`. Pattern is already in `Fact_InvoiceLabor.pq`.
- **Lineage tag uniqueness in TMDL** — Power BI Desktop will refuse to open the file if any two measures share the same lineageTag. When generating fake tags using the `f0f1f2f3-f4f5-4f67-a001-XXXXXXXXXXXX` pattern, check existing tags in the file first to avoid collision. The IL measures use `...0101`–`...0110`, `...0120`–`...0128`, `...0131`.

## Pipeline Placement
- `df_ServiceTimeSheets_Raw` → Phase 1 (Raw Sources)
- `Fact_ServiceTimeSheet_Audit` → Phase 4 (Facts)
- `Fact_InvoiceLabor` → Phase 4 (Facts, depends on dim_CustomerList)
- Semantic model refresh → Phase 5

## Files
- `queries/df_ServiceTimeSheets_Raw.pq` — SharePoint ingestion query (multi-layout Excel normalization)
- `queries/Fact_ServiceTimeSheet_Audit.pq` — Fact table ETL (four-source join + audit logic)
- `queries/Fact_InvoiceLabor.pq` — Invoice Labor fact table ETL (TID + WKROFILE + sheets + dim_CustomerList)
- `reports/Service Time Sheets.SemanticModel/definition/tables/_Measures.tmdl` — all DAX (Audit + IL measures)
- `reports/Service Time Sheets.SemanticModel/definition/tables/Fact_ServiceTimeSheet_Audit.tmdl` — audit fact table schema
- `reports/Service Time Sheets.SemanticModel/definition/tables/Fact_InvoiceLabor.tmdl` — invoice labor fact table schema
- `documentation/SERVICE-MANAGER-GUIDE.md` — Corp Service Manager quick reference (actionable, with examples)
- `README.md` — full project documentation
