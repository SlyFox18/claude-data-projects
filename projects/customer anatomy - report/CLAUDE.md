# Customer Anatomy Report — Claude Context

## Status
**In Development** — V2 active in RP-Sandbox. V1 archive exists in `reports/archive/` for reference only.

## Business Purpose
Customer health and engagement dashboard. Shows parts/service/equipment revenue by customer, engagement levels, unique customer tracking, and CSM assignments across 15 branch locations.

## Semantic Model
**Path:** `reports/current/Customer Anatomy V2.SemanticModel/definition/`

### Fact Tables (8)
| Table | Grain | Key Source | Notes |
|-------|-------|-----------|-------|
| Fact_CustomerPerformance | Customer × Month | Invoice | Aggregated L1 — main KPI table |
| Fact_Parts_Invoices | Invoice header | Invoice | L2 parts invoice detail |
| Fact_Parts_Detail | Invoice line item | InTrans | L3 parts line detail |
| Fact_Service_Invoices | Invoice header | Invoice | L2 service invoice detail |
| Fact_Service_Detail | Work order job | wkothsub/wkmechwk | L3 service job detail |
| Fact_Service_Parts_Detail | Invoice line item | InTrans | L3 service parts (joins on invoice, NOT work order) |
| Fact_Equipment_Sales | Invoice line | Invoice | Equipment sales |
| Fact_CustomerPerformance (test) | Customer × Month | — | Test version in queries/test queries/ |

### Shared Dimensions (from Lakehouse)
- `dim_CustomerList` — primary customer dim. Has calculated columns: **CSM, Route Day, EngagementLevel, UniqueCustomerGroup, IsUniqueCustomer**
- `dim_BranchLocation`, `dim_DateTable`, `dim_Parts`, `dim_EngagedAcres`, `lookup_UniqueCustomers_Invoice`

### Helper Tables
`_Measures`, `_TestMeasures`, `Data Refresh`, `Status Selector`, `TopN Selector`

## Known Issues & Active Work

### Unknown Customer Problem (~$1.6M service revenue unattributed)
- **Root cause (hypothesis):** `Invoice.BillToAccount` doesn't match `dim_CustomerList.CustomerNumber` for service invoices
- **Investigation plan:** `INVESTIGATION-PLAN-Unknown-Customers.md` — 8 SQL diagnostic queries to run against Fabric SQL analytics endpoint
- **Fix plan:** `IMPLEMENTATION-PLAN-Service-Parts-Detail.md` — adapt Inspections pattern: build `Fact_Service_WorkOrderParts` using `InTrans.CustomerNo` instead of `Invoice.BillToAccount`
- **Parts work fine** — only service is affected

## Key Patterns

### Unique Customer Integration
- 11 customer groups (~513 customers): Manuel/MR Tractor (300), Jim Justice (87), David Arizmendi (59), Dell City (18), Tornillo (23), Oscar (11), Pearsall (10), Danny G (2), Dallyn Clements (1), Benny Gray (1), Owen Bros. (1)
- Lookup table: `lookup_UniqueCustomers_Invoice` in Lakehouse (3 identification methods: CustomerOrderNumber patterns, TradeType, direct CustomerNumber)
- DAX pattern on `dim_CustomerList`: `LOOKUPVALUE` for `UniqueCustomerGroup` and `IsUniqueCustomer` — **no model relationship**
- Dataflow: `df_UniqueCustomer_Lookup` in `03 - Dimensions`
- Edge case: CustomerNumber 25227 matches multiple patterns → resolved to Manuel/MR Tractor by priority order
- Dell City/Tornillo: same customer, split by branch location

### Engagement Levels
- Source: `dim_EngagedAcres` (from external CSV uploaded to Lakehouse Files)
- DAX: `LOOKUPVALUE` on `dim_CustomerList.EngagementLevel`

### HTML Visuals / Badge Colors
- Unique Customer badge: purple `#818cf8`
- Key Customer badge: gold `#fbbf24`

### Multi-Level Fact Pattern
- L1 (aggregated) → KPIs, trend charts
- L2 (invoice detail) → drill-through to invoice list
- L3 (line items) → deepest drill-through

## Queries
- Active queries: `queries/new report/*.pq`
- Old queries: `queries/old report/*.pq` — reference only, V1 architecture
- Test queries: `queries/test queries/*.pq` — experimental, not production

## Files to Know
- `UNIQUE-CUSTOMER-FLAGS.md` — complete unique customer group reference (patterns, edge cases)
- `IMPLEMENTATION-PLAN-Service-Parts-Detail.md` — fix plan for Unknown Customer issue
- `INVESTIGATION-PLAN-Unknown-Customers.md` — diagnostic SQL queries
