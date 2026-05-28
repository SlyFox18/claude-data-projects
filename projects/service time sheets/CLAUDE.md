# Service Time Sheets — Claude Context

## Status
**Production** ✅ — Live in RP - Service Reports. Built 2026-05-28.

## Business Purpose
Payroll audit tool for service technician draw pay. Reads submitted Excel time sheets from SharePoint, cross-references against EquipRDB invoice and punch records, and classifies every RO submission into one of six audit buckets before draw pay is approved. Primary audience: CFO, Service Manager, Payroll.

## Semantic Model
**Path:** `reports/Service Time Sheets.SemanticModel/definition/`

### Fact Table (1)
| Table | Grain | Source |
|---|---|---|
| Fact_ServiceTimeSheet_Audit | Technician × RO × Pay period | service_time_sheets + TechnicianInvoiceDetail + TechnicianPunchedDetail + WKROFILE |

**No shared dimension relationships.** The fact table is fully denormalized. All slicing is done on fact table columns directly. This is intentional.

### EquipRDB Source Tables Used
- `TechnicianInvoiceDetail` — invoiced hours and dollars; only present for invoiced job codes
- `TechnicianPunchedDetail` — all clocked hours regardless of invoice status
- `WKROFILE` — RO header; `IsClosed = "Y"` is the authoritative closure signal

## Six AuditStatus Buckets (evaluated in order)
1. **Draw - Open RO** — InvoicedHrs = null AND any Draw1/2/3/FinalDrawHrs > 0
2. **Pending Invoice** — InvoicedHrs = null AND no draw history
3. **Match** — ABS(Claimed − Invoiced) < 0.001 hrs
4. **Invoiced More Than Claimed** — system billed more than tech claimed
5. **Partial Invoice - In Progress** — Claimed > Invoiced AND IsClosed ≠ "Y" AND PunchedHrs > InvoicedHrs × 1.1
6. **Claimed More Than Invoiced** — everything else where Claimed > Invoiced (real flag)

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

## Report Pages (6)
| Page | Name | Purpose |
|---|---|---|
| Home | Navigation & Guide | Drill-through flow diagram + audit status color legend |
| 1 | Executive Summary | Hero card KPIs + Tech Risk Leaderboard + Location Scorecard |
| 2 | Time Sheet Audit | Full row-level detail table |
| 3 | Tech Audit Detail | Per-tech drill-through (right-click tech name on page 2) |
| 4 | Multi-Tech RO Detail | Per-RO drill-through (right-click RO on page 3) |
| 5 | Multi-Tech RO Review | Standalone shared-work RO table |

## Key Measures to Know
- `# Pending` = Partial Invoice - In Progress (◆ in hero card) — NOT the same as `# Pending Invoice`
- `Net Overclaim $` = TechPay − LaborBilled scoped to "Claimed More Than Invoiced" rows
- `Underpay Risk $` = (InvoicedHrs − ClaimedHrs) × PayRate for "Invoiced More" rows
- `Overclaim Rate %` = # Claimed More ÷ (Match + Claimed More + Invoiced More)
- Hero cards are HTML measures — all in `_Measures.tmdl` in the `_Measures` table

## Known Gotchas
- **Fan-out prevention:** TID and TPD are grouped to {WorkOrder, TechCode} BEFORE the join to the fact table. If you ever see inflated InvoicedHrs or PunchedHrs, check whether grouping was accidentally removed.
- **RONumber type:** RONumber is a float in the source. Converted to text (`RONumberText`) for all joins. Never join on the numeric RONumber column — the text version is the key.
- **Branch resolution:** TID Branch is preferred (invoiced ROs). Falls back to TPD Branch for open ROs. If both null, Branch is blank — this can happen for ROs with no system records at all.
- **Match tolerance is 0.001 hrs** — intentionally tight to catch any real billing gap. Do not loosen without discussing with CFO.
- **Credit/reversal rows:** Negative InvoicedHrs from billing reversals. The `PunchedHrs > InvoicedHrs × 1.1` guard in bucket 5 prevents these from incorrectly landing in "Partial Invoice."
- **TMDL files do NOT support `//` comments** at the structural level. DAX `//` inside backtick measure expressions is fine. Never add `//` comment lines between TMDL keywords.

## Pipeline Placement
- `df_ServiceTimeSheets_Raw` → Phase 1 (Raw Sources)
- `Fact_ServiceTimeSheet_Audit` → Phase 4 (Facts)
- Semantic model refresh → Phase 5

## Files
- `queries/df_ServiceTimeSheets_Raw.pq` — SharePoint ingestion query (multi-layout Excel normalization)
- `queries/Fact_ServiceTimeSheet_Audit.pq` — Fact table ETL (four-source join + audit logic)
- `reports/Service Time Sheets.SemanticModel/definition/tables/_Measures.tmdl` — all DAX
- `reports/Service Time Sheets.SemanticModel/definition/tables/Fact_ServiceTimeSheet_Audit.tmdl` — table schema
- `README.md` — full project documentation
