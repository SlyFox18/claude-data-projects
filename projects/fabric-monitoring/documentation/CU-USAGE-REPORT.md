# CU Usage Report

**Generated:** 2026-04-24 08:01:30
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1524.6 CU |
| Operations | 133 |
| Avg per Operation | 11.5 CU |
| Peak Operation | 38.5 CU |
| F4 Capacity Used | 66.2% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 99.2 | 33.1 | 3 |
| df_Fact_Service_Invoices | 65.2 | 32.6 | 2 |
| df_Fact_WorkOrderParts | 59.2 | 29.6 | 2 |
| df_Fact_Parts_Details | 57.2 | 28.6 | 2 |
| df_Fact_Inventory | 57.2 | 28.6 | 2 |
| df_Fact_Service_Detail | 47.2 | 23.6 | 2 |
| df_InTrans_PartsCounter_Raw | 45.8 | 22.9 | 2 |
| df_Fact_PartSales_24Hours | 44.8 | 14.9 | 3 |
| df_Fact_Parts_Invoices | 43.2 | 21.6 | 2 |
| df_Invoice_Raw | 42 | 21 | 2 |

## Recommendations

- WARNING: Using 66.2% of F4 capacity - monitor closely
- Consider spreading refreshes: 133 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

