# Planter Inspection Part Sales — Claude Context

## Report Overview
- **Business purpose:** Tracks the connection between planter inspections (performed by the Lorenzo team/91I branch) and downstream parts revenue. Answers: who got inspected, did they convert to buying parts, and how much revenue did the inspection activity drive?
- **Primary users:** Service/parts management, branch managers, Lorenzo team
- **Workspace:** RP - Sandbox (published for stakeholder review)
- **Refresh tier:** TBD (Tier 2 candidate) — added to Facts and Semantic Model pipelines
- **Status:** Sandbox — Published for Stakeholder Review

## Semantic Model

**Path:** `reports/new report/Planter Inspection Part Sales.SemanticModel/definition/`

Note: There are two semantic model folders in `reports/new report/` — `Planter Inspection Part Sales.SemanticModel` and `Planter Inspection Part Sales - V2.SemanticModel`. The V2 model is the active one (it contains `Fact_PlanterInvoiceAllParts`); the first is an earlier iteration.

### Fact Tables
| Table | Grain | Key Fields | Notes |
|-------|-------|------------|-------|
| `Fact_PlanterInspections` | One row per planter inspection job per work order (invoiced) | BranchCode, WorkOrderNumber, InvoiceNumber, CustomerNumber, InvoicedLaborAmount, InvoiceDate | ~100–500 rows/season. The "spine" — everything joins back to InvoiceNumber. Sources: wkothsub + WKROFILE |
| `Fact_PlanterPartSales` | One row per part transaction line | BranchCode, InvoiceNumber, CustomerNumber, PartNumber, Franchise, SaleValue, CostValue | Parts sold to planter inspection customers. ZP franchise = promo items. Source: Lakehouse table `Fact_PlanterPartSales` (dataflow) |
| `Fact_PlanterInvoiceAllParts` | One row per part transaction line | BranchCode, InvoiceNumber, CustomerNumber, PartNumber, SaleValue, CostValue, IsPlanterPart | All parts on invoices that included ≥1 planter part. IsPlanterPart = boolean flag set at SQL time via LEFT JOIN. Uses native SQL query (see gotchas). Source: InTrans_Incremental + dim_Parts |
| `Fact_PlanterInspectionParts` | One row per part transaction per inspection invoice | BranchCode, InvoiceNumber, CustomerNumber, PartNumber, SaleValue | Parts on the inspection invoices themselves. **Currently in the model but unused** — candidate for retirement. Sources: wkothsub + InTrans_Incremental |

### Dimensions
| Table | Source | Key Relationship |
|-------|--------|-----------------|
| `dim_BranchLocation` | Shared Lakehouse table | BranchCode → BranchID |
| `dim_CustomerList` | Shared Lakehouse table | CustomerNumber → CustomerNumber |
| `dim_DateTable` | Shared Lakehouse table | TransactionDate / InvoiceDate → Date |
| `dim_Parts` | Shared Lakehouse table | PartNumber → PartNumber (used by Fact_PlanterInspectionParts and Fact_PlanterInvoiceAllParts) |

### Key Measures

**Page 1 — Inspection Part Sales:**
| Measure | Description |
|---------|-------------|
| `Total Parts Sale $` | Parts revenue from inspection customers; excludes ZP franchise (promo items) |
| `Total Parts Cost $` | Parts cost from inspection customers; excludes ZP |
| `Total Labor $` | Total labor invoiced from planter inspections |
| `Total Planter Inspections` | Distinct count of inspection invoice numbers |
| `Inspections with Part Sales` | Distinct customers who had an inspection AND bought parts (customer grain) |
| `Inspections with Planter Promo` | Distinct customers who had inspection AND used `*PLANTER` promo (ZP franchise) |
| `Parts Multiplier` | Parts revenue ÷ labor revenue — how many $ of parts per $1 of inspection labor |
| `Converted` | "Yes" / "No" — did this customer buy parts after the inspection? |
| `Has Planter Promo` | "Yes" / "No" — did this customer use the planter promo? |
| `Hero Card - Inspection Part Sales` | HTML KPI card: Parts Sale / Cost / Labor / Margin (left) + Inspection count / W/ Parts / Promo (right) |

**Page 2 — Planter Part Sales:**
| Measure | Description |
|---------|-------------|
| `Total Invoice Parts Sale $` | All parts on planter invoices, inspection customers only |
| `Total Invoice Parts Cost $` | Cost for the same scope |
| `Invoice Parts Margin %` | Derived margin % |
| `Planter Parts $` | IsPlanterPart = TRUE subset of invoice parts |
| `Add-On Parts $` | IsPlanterPart = FALSE subset (non-planter parts sold on same invoice) |
| `Hero Card - Planter Part Sales` | HTML equation card: Planter Parts + Add-On Parts = Total | Cost | Margin |

## Report Pages
| Page | Purpose | Key Visuals |
|------|---------|-------------|
| Page 1: Planter Inspection Part Sales | Inspection customer overview — who was inspected, conversion rate, parts/labor revenue | Hero KPI card, customer table (Converted flag, Parts $, Multiplier), slicers (branch, date) |
| Page 2: Planter Part Sales | Invoice-level parts breakdown — planter vs add-on split for inspection customers | Hero equation card (Planter + Add-On = Total), bar chart by branch, customer detail table |

## Data Flow

```
wkothsub (job codes)          →  Fact_PlanterInspections
WKROFILE (work order header)  →  Fact_PlanterInspections (customer number)
InTrans_Incremental + wkothsub →  Fact_PlanterInspectionParts (UNUSED)
Lakehouse Fact_PlanterPartSales → Fact_PlanterPartSales (separate dataflow)
InTrans_Incremental + dim_Parts → Fact_PlanterInvoiceAllParts (native SQL)
```

Key non-standard pattern: **Fact_PlanterInvoiceAllParts** uses a native SQL query (`Sql.Database([Query=...])`) instead of Power Query table steps. This bypasses the folding engine entirely and is required to avoid a 15+ minute timeout caused by double-scanning InTrans_Incremental (10M+ rows).

## Known Issues & Gotchas

### Critical Design: Parts/Inspections Are on Different Invoices
The Lorenzo team (91I) performs the inspection; customers buy parts at their **home branch** on a separate invoice. Page 1 uses a **customer-number join** (not invoice join) between inspections and parts. This is intentional and correct — do not try to join on InvoiceNumber between these two tables.

### Page 2 Inspection Customer Filter Must Live in DAX
Without the `VAR _InspectionCustomers = VALUES(Fact_PlanterInspections[CustomerNumber])` filter baked into Page 2 measures, the hero card shows $17M (all customers) instead of ~$3.6M (inspection customers). Visual-level filters alone do not affect the HTML card measure. All four Page 2 measures include this filter.

### IsPlanterPart Flag — No Model Relationship Needed
The `IsPlanterPart` boolean in `Fact_PlanterInvoiceAllParts` is set at SQL query time via LEFT JOIN to `dim_Parts` (commodity codes 310–318 OR `PartNumber LIKE '%PLANTER%'`). The `dim_Parts` relationship exists for slicing/filtering but plays no role in the flag. Do NOT create a separate M2M relationship to a parts lookup table — that was the bug in the old report.

### Old Report M2M Bug (Fixed in New Report)
The old report had `Planter_Part_List` (branch-level jdis data, 22K+ rows) in a many-to-many relationship with `Planter_Parts`. Visuals on the old Page 2 were filtered by `pi_Commodity_Code` from `Planter_Part_List`, which caused fan-out. The old $756K figure is **untrustworthy** — the new report's figures ($3.6M Planter Parts, inspection customers) are the first reliable numbers.

### Planter Part Classification
Commodity codes 310–318 are all planter-specific hardware (including bolts, nuts, screws made specifically for planters). 3,500+ parts in this range is expected and correct. The old report's lower figure was caused by M2M fan-out, not a difference in scope.

### ZP Franchise = Promo Items
`Franchise = 'ZP'` rows are promo/discount items (e.g., `PartNumber = '*PLANTER'`). Filter ZP **out** for real parts dollar measures (`Franchise <> 'ZP'`). Keep ZP **in** the table so the Planter Promo flag can detect whether `*PLANTER` appeared on the invoice.

### CustomerNumber Float Conversion (Fact_PlanterInspections)
WKROFILE.AccountNumber is stored as float in the Lakehouse (e.g., `28840.000000`). The query converts it via `Int64.From` then `Text.From` to get a clean account number string matching `dim_CustomerList.CustomerNumber`.

### Fact_PlanterInspectionParts — Unused, Candidate for Retirement
This table is in the model and has relationships, but no measures reference it. Page 1 measures use `Fact_PlanterPartSales` instead. Consider removing it to simplify the model.

## Refresh Pipeline Position
- Added to **Facts pipeline** (Phase 4) and **Semantic Model pipeline** (Phase 5)
- Dependencies: wkothsub, WKROFILE, InTrans_Incremental (Phase 2), dim_Parts (Phase 3)
- **Fact dataflow avg refresh: ~1:40** (measured baseline)
- Semantic model refresh: fast (small model, no measured baseline yet but expected < 1 min)
- Will be assigned a Tier when promoted to production

## Query Files
| File | Purpose |
|------|---------|
| `queries/new report/Fact_PlanterInspections.pq` | Planter inspection labor facts |
| `queries/new report/Fact_PlanterInspectionParts.pq` | Parts on inspection invoices (unused in model) |
| `queries/new report/Fact_PlanterInvoiceAllParts.pq` | All parts on planter invoices (native SQL) |
| `queries/old report/Planter_Parts.pq` | Old report query — reference only, do not use |
| `queries/old report/Planter_Part_List.pq` | Old report M2M table — shows what not to do |

## Documentation Status
- In-repo docs: ✅ CLAUDE.md | ✅ PROJECT-SUMMARY.md
- Obsidian stakeholder docs: ✅ Complete — `Data Projects/Reports/Planter Inspection Part Sales.md`
