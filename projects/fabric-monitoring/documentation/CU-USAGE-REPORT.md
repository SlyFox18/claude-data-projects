# CU Usage Report

**Generated:** 2026-05-13 08:01:42
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1391.1 CU |
| Operations | 130 |
| Avg per Operation | 10.7 CU |
| Peak Operation | 38.5 CU |
| F4 Capacity Used | 60.4% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 132.8 | 33.2 | 4 |
| df_Fact_WorkOrderParts | 55.2 | 27.6 | 2 |
| df_Fact_Inventory | 51.2 | 25.6 | 2 |
| df_InTrans_PartsCounter_Raw | 47 | 23.5 | 2 |
| df_Invoice_Raw | 43.2 | 21.6 | 2 |
| df_Fact_Service_Detail | 43.2 | 21.6 | 2 |
| df_GlTrans_Raw | 32 | 16 | 2 |
| df_Fact_Service_Invoices | 27.6 | 27.6 | 1 |
| df_Fact_Parts_Details | 27.6 | 27.6 | 1 |
| df_Fact_CustomerPerformance | 27.2 | 13.6 | 2 |

## Recommendations

- WARNING: Using 60.4% of F4 capacity - monitor closely
- Consider spreading refreshes: 130 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

