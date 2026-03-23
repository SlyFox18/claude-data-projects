# Open Work Orders — Claude Context

## Report Overview
- **Business purpose:** Tracks every open (uninvoiced) service work order across all 15 branches with aging analysis. The core question: how much WIP is sitting out there, how old is it, and where is it stalled?
- **Primary users:** Service managers, branch managers, operations leadership
- **Workspace:** RP - Service Reports (Production)
- **Refresh tier:** Tier 1 — daily 3:30 AM CST, fresh by 8 AM
- **Status:** Production ✅

---

## Semantic Model

**Path:** `report/current/Open Work Orders.SemanticModel/definition/`

### Fact Tables
| Table | Grain | Key Fields | Row Count (approx) |
|-------|-------|------------|-------------------|
| `Fact_OpenWorkOrders` | One row per open work order (Branch + WorkOrder) | Branch, WorkOrder, AgingBucket, TotalRevenue, DaysSinceCreationDate, DaysSinceLastLabor | ~2,000–3,000 rows |

### Dimensions
| Table | Source | Key Relationship |
|-------|--------|-----------------|
| `dim_BranchLocation` | Shared Lakehouse dimension | `Fact[Branch]` → `dim_BranchLocation[BranchID]` (M:1) |
| `dim_CustomerList` | Shared Lakehouse dimension | `Fact[AccountNumberText]` → `dim_CustomerList[AccountNumberText]` (M:1) |
| `dim_Technician_Code_Names` | Lakehouse table | `Fact[TechCode]` → `dim_Technician_Code_Names[TechnicianCode]` (**M:M, bidirectional** — see gotchas) |
| `dim_AgingBucket` | DAX DATATABLE (calculated) | **No relationship** — disconnected slicer |
| `dim_DateTable` | Shared Lakehouse dimension | **No active relationship** — DateKey column exists in fact but no relationship defined in model |

### Key Measures
| Measure | Description |
|---------|-------------|
| `Total Open Work Orders` | COUNTROWS of fact table — count of all active jobs |
| `Total Sales` | SUM of TotalRevenue across all open WOs |
| `Part Sales` / `Labor Sales` / `Sublet Sales` / `Other Sales` | Revenue by type |
| `WO Count - 60+ Days` through `WO Count - Not Started` | Hardcoded CALCULATE counts per aging bucket |
| `Sales - 60+ Days` through `Sales - Not Started` | Hardcoded CALCULATE sales per aging bucket |
| `Work Orders by Selected Aging` | Dynamic count using SELECTEDVALUE on disconnected dim_AgingBucket slicer |
| `Sales by Selected Aging` | Dynamic sales using SELECTEDVALUE on disconnected dim_AgingBucket slicer |
| `Customer Name` | Cascading lookup: dim_CustomerList[DisplayName] → CustomerNamePunch fallback → "Customer Not Found" |
| `Days Since Last Labor Color` | Hex color for conditional formatting: Gray (null) / Red (>14 days) / Orange (>7 days) / Green (≤7 days) |
| `Open WO - Aging Summary Card (HTML)` | Full HTML card rendering all 6 aging buckets with WO count + sales |
| `Open WO - Branch Aging Composition (HTML)` | Stacked bar chart HTML showing aging mix per branch |

---

## Report Pages
| Page | Purpose | Key Visuals |
|------|---------|-------------|
| **WIP Overview** | Summary dashboard for all open work orders | HTML hero card (total sales by type), HTML aging summary card (6 buckets), HTML branch aging composition chart |
| **WIP Details** | Row-level drill-down of individual work orders | Table with WO#, customer, branch, technician, model, aging bucket, days since last labor (color-coded), revenue |

---

## Data Flow

```
RepairOrderDetail (Lakehouse)    — core WO data, filtered to StatusDisplay <> 'Invoiced'
WKROFILE (Lakehouse)             — AccountNumber, PaymentMethod, Franchise, Registration
TechnicianPunchedDetail (Lakehouse) — grouped by WorkOrder: EquipmentModel, TechCode, CustomerNamePunch
         ↓
Fact_OpenWorkOrders (Power Query join + calculated columns)
         ↓
Open Work Orders Report
```

**Source:** All three tables read from Lakehouse SQL analytics endpoint (`LH_Master_Data`), not direct ODBC. Connection string in `Fact_OpenWorkOrders` partition source.

**Calculated columns added in Power Query (not DAX):**
- `DaysSinceLastLabor` — `DateTime.LocalNow() - LastLaborPunch` in days
- `AgingBucket` — uses DaysSinceLastLabor >= 45000 as "Not Started" signal; otherwise buckets by DaysSinceCreationDate
- `AgingSortOrder` — integer 1–6 for consistent sort (60+ = 1, Not Started = 6)
- `ProgressStatusDisplay` — maps 15 ROProgressStatus codes to friendly names (see query for full mapping)
- `DateKey` — date cast of CreationDate for dim_DateTable join (no active relationship currently)
- `AccountNumberText` — text cast of AccountNumber for dim_CustomerList join

---

## Known Issues & Gotchas

### 1. Bidirectional M:M on dim_Technician_Code_Names — Performance Risk
The `TechCode → TechnicianCode` relationship uses `crossFilteringBehavior: bothDirections` and `toCardinality: many` (M:M). Per project conventions, bidirectional relationships cause ambiguous filter paths and performance degradation. This should be reviewed if performance issues emerge. Consider changing to M:1 with single-direction filtering, or using LOOKUPVALUE in a measure/calculated column instead.

### 2. dim_DateTable Has No Active Relationship
`DateKey` exists on the fact table and `dim_DateTable` is in the model, but there is **no relationship defined** between them in `relationships.tmdl`. Date-based filtering/slicing will not work until this relationship is created: `Fact_OpenWorkOrders[DateKey] → dim_DateTable[Date]` (M:1). This may be intentional if date filtering isn't needed (WIP = current snapshot), or may be an oversight.

### 3. "Not Started" Logic Uses 45000-Day Threshold
When `LastLaborPunch` is null or defaults to 1/1/1900, `DaysSinceLastLabor` comes out as ~46,046 days. The Power Query aging logic uses `>= 45000` to detect this. Do not change the logic to check for null alone — the 1900-01-01 default date is the real signal.

### 4. DateTime.LocalNow() in Power Query
`DaysSinceLastLabor` is calculated using `DateTime.LocalNow()` in the fact table's Power Query. In Fabric/Power BI Service, `DateTime.LocalNow()` returns UTC. Since this is a day-count (not timestamp), the 6-hour CST offset only causes a discrepancy for jobs where the last punch was after ~6 PM CST. Low impact for WIP analysis but worth noting if exact day counts are disputed. See `.claude/queries/DATA-REFRESH-TEMPLATE.pq` for the UTC→Central conversion pattern if precision becomes required.

### 5. AgingBucket Pre-Computed in Power Query
Unlike most reports where aging is calculated in DAX, the `AgingBucket` column is computed at load time in Power Query. This is efficient (no runtime calculation) but means aging buckets are locked at the time of last refresh. A work order doesn't "age" visually until the next pipeline run.

### 6. Migration Eliminated ~1.7M Rows
The old model pulled `TechnicianInvoiceDetail` (~917K rows) and `TechnicianPunchedDetail` (~717K rows) in full. The new model only uses a grouped aggregate of `TechnicianPunchedDetail` (one row per WorkOrder). If someone asks why those tables are missing, that's intentional — the full detail is not needed for WIP analysis.

---

## Refresh Pipeline Position
- **Phase:** Phase 4 — Facts (Service)
- **Dependencies:** RepairOrderDetail, WKROFILE, TechnicianPunchedDetail must be refreshed in Phase 1 (Raw Sources) first
- **Expected refresh time:** < 30 seconds (was ~3:30 min in old model — 85% improvement)
- **No incremental refresh** — table is small (~3K rows), full refresh is fast

---

## Documentation Status
- In-repo docs: ✅ CLAUDE.md | ✅ PROJECT-SUMMARY.md
- Obsidian stakeholder docs: ✅ Complete — `Data Projects/Reports/Open Work Orders.md`
