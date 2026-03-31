# CU Usage Report

**Generated:** 2026-03-31 08:01:21
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 722.2 CU |
| Operations | 126 |
| Avg per Operation | 5.7 CU |
| Peak Operation | 35.6 CU |
| F4 Capacity Used | 31.3% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_Fact_Service_Invoices | 65.2 | 32.6 | 2 |
| df_Fact_Inventory | 55.2 | 27.6 | 2 |
| df_Fact_Parts_Details | 55.2 | 27.6 | 2 |
| df_Fact_Transfers | 49.2 | 24.6 | 2 |
| df_Fact_Service_Detail | 47.2 | 23.6 | 2 |
| df_Invoice_Raw | 42 | 21 | 2 |
| df_Fact_LaborJobSummary | 39.2 | 19.6 | 2 |
| df_Fact_Parts_Invoices | 39.2 | 19.6 | 2 |
| df_Fact_WorkOrderParts | 35.6 | 35.6 | 1 |
| df_Fact_Invoice_UniqueCustomers | 35.2 | 17.6 | 2 |

## Recommendations

- Consider spreading refreshes: 126 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

