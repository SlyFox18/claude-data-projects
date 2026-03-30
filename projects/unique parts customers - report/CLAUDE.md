# Unique Parts Customers — Claude Context

## Report Overview
- **Business purpose:** Provides detailed parts transaction data for 11 designated "unique" customer groups — showing sales, cost, margin, and YTD/PYTD comparisons across both InTrans (line-item) and Invoice (order-level) grain views.
- **Primary users:** Parts managers, sales leadership, CSM team tracking unique customer accounts
- **Workspace:** RP - Parts Reports
- **Refresh tier:** Tier 2 — Daily (can finish after 8 AM)
- **Status:** Production

## Semantic Model

### Fact Tables
| Table | Grain | Key Fields | Notes |
|-------|-------|------------|-------|
| `Fact_InTrans_UniqueCustomers` | One row per parts transaction line | TransactionKey, DateKey, BranchKey, CustomerKey, PartNumber, SaleValue, CostValue, MarginAmount, MarginPercent, Qty, Type, TradeType, RONumber, SalesType | From `dbo.Fact_InTrans_UniqueCustomers` |
| `Fact_Invoice_UniqueCustomers` | One row per invoice | TransactionKey, DateKey, BranchKey, CustomerKey, InvoiceNumber, WorkOrderNumber, CustomerOrderNumber, PartsSaleValue, PartsCostValue, MarginAmount, MarginPercent, SalesType | From `dbo.Fact_Invoice_UniqueCustomers` |

### Dimensions
| Table | Source | Key Relationship |
|-------|--------|-----------------|
| `dim_UniqueCustomers` | Lakehouse | `Fact_Invoice_UniqueCustomers.CustomerKey → dim_UniqueCustomers.CustomerKey`; `Fact_InTrans_UniqueCustomers.CustomerKey → dim_UniqueCustomers.CustomerKey` |
| `dim_CustomerList` | Shared Lakehouse dimension | Both fact tables also relate to `dim_CustomerList.CustomerKey` |
| `dim_BranchLocation` | Shared Lakehouse dimension | Both fact tables relate via `BranchKey` |
| `dim_DateTable` | Shared Lakehouse dimension | Both fact tables relate via `DateKey` |

Note: Both fact tables have **two customer relationships** — one to `dim_UniqueCustomers` and one to `dim_CustomerList`. This provides both unique-customer-specific filtering and access to the full customer dimension attributes (CSM, route day, etc.).

### Key Measures (in `MeasuresTable`)
| Measure | Description |
|---------|-------------|
| `InTrans_Sales` | SUM of Fact_InTrans_UniqueCustomers[SaleValue] |
| `InTrans_Cost` | SUM of Fact_InTrans_UniqueCustomers[CostValue] |
| `InTrans_Margin` | InTrans_Sales - InTrans_Cost |
| `InTrans_Margin%` | DIVIDE(InTrans_Margin, InTrans_Sales) |
| `Invoice_Sales` | SUM of Fact_Invoice_UniqueCustomers[PartsSaleValue] |
| `Invoice_Cost` | SUM of Fact_Invoice_UniqueCustomers[PartsCostValue] |
| `Invoice_Margin` | Invoice_Sales - Invoice_Cost |
| `Invoice_Margin%` | DIVIDE(Invoice_Margin, Invoice_Sales) |
| `Total_Sales` | InTrans_Sales + Invoice_Sales |
| `Total_Cost` | InTrans_Cost + Invoice_Cost |
| `Total_Margin` | Total_Sales - Total_Cost |
| `Total_Margin%` | DIVIDE(Total_Margin, Total_Sales) |
| `YTD_Sales` | YTD of Total_Sales — dynamic: if one year selected uses that year, else defaults to current year |
| `YTD_Cost` | YTD of Total_Cost — **hardcoded to 2025** (stale — needs updating each year) |
| `YTD_Margin` | YTD of Total_Margin — **hardcoded to 2025** |
| `PYTD_Sales` | YTD of Total_Sales — **hardcoded to 2024** |
| `PYTD_Cost` | YTD of Total_Cost — **hardcoded to 2024** |
| `PYTD_Margin` | YTD of Total_Margin — **hardcoded to 2024** |
| `YTD_Sales_v2` | YTD sales only when single year selected (blank otherwise) |
| `Monthly_YTD_Sales` | Rolling YTD using DATESYTD |
| `Monthly_Previous_Sales` | Prior year sales via DATEADD(-1, YEAR) |
| `2025_Sales_Counter` | 2025 OTC sales (hardcoded year) |
| `2025_Sales_WorkOrder` | 2025 work order sales (hardcoded year) |

## Report Pages
| Page | Purpose | Visibility |
|------|---------|------------|
| Unique Parts | Main sales view — all unique customer activity | Visible |
| Comparison | Side-by-side comparison view | Hidden |
| Customer Details | Individual customer drill-down | Hidden |
| (Tooltip pages) | Tooltip overlays for visuals | Hidden |

## Data Flow
```
EquipRDB (ODBC) → InTrans_Incremental (Lakehouse) → Fact_InTrans_UniqueCustomers (Lakehouse)
EquipRDB (ODBC) → Invoice (Lakehouse) → Fact_Invoice_UniqueCustomers (Lakehouse)
lookup_UniqueCustomers_Invoice → dim_UniqueCustomers (Lakehouse)
```

## Known Issues & Gotchas
- **Hardcoded years in YTD/PYTD measures:** `YTD_Cost`, `YTD_Margin`, `PYTD_Sales`, `PYTD_Cost`, `PYTD_Margin`, `2025_Sales_Counter`, `2025_Sales_WorkOrder` all contain hardcoded year values (2024 or 2025). These need updating each calendar year. `YTD_Sales` uses a dynamic approach — the others do not.
- **Dual customer relationships:** Both fact tables join to both `dim_UniqueCustomers` and `dim_CustomerList`. This is intentional but unusual — use care when writing new DAX that filters by customer attributes.
- **Two fact table grains:** InTrans is line-item grain; Invoice is order-level grain. `Total_Sales = InTrans_Sales + Invoice_Sales` combines both — understand which grain a visual is using before adding measures.
- **Unique customer definition:** The 11 customer groups are defined in `lookup_UniqueCustomers_Invoice`. See `CROSS-REPORT-FLAGS.md` for full group definitions and identification logic.

## Refresh Pipeline Position
- Tier 2: Daily, after 8 AM
- Depends on `Fact_InTrans_UniqueCustomers` and `Fact_Invoice_UniqueCustomers` fact table refreshes (Phase 4)
- Which pipeline phase builds these fact tables: confirm in `projects/refresh-pipeline/`

## Related Documentation
- `CROSS-REPORT-FLAGS.md` — documents the 11 unique customer groups and cross-report integration

## Documentation Status
- In-repo docs: ✅ CLAUDE.md | ✅ PROJECT-SUMMARY.md
- Obsidian stakeholder docs: ✅ Complete — `Data Projects/Reports/Unique Parts Customers.md`
