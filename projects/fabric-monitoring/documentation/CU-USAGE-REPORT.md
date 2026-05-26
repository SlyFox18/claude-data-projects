# CU Usage Report

**Generated:** 2026-05-26 08:01:29
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1545.5 CU |
| Operations | 134 |
| Avg per Operation | 11.5 CU |
| Peak Operation | 36.2 CU |
| F4 Capacity Used | 67.1% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 126.8 | 31.7 | 4 |
| df_Fact_Service_Invoices | 65.2 | 32.6 | 2 |
| df_Fact_WorkOrderParts | 59.2 | 29.6 | 2 |
| df_Fact_Inventory | 57.2 | 28.6 | 2 |
| df_Fact_Transfers | 51.2 | 25.6 | 2 |
| df_Invoice_Raw | 47.8 | 23.9 | 2 |
| df_InTrans_PartsCounter_Raw | 46 | 23 | 2 |
| df_Fact_Service_Detail | 43.2 | 21.6 | 2 |
| df_Fact_First_Pass_Fill | 42.8 | 14.3 | 3 |
| df_Fact_Parts_Invoices | 37.2 | 18.6 | 2 |

## Recommendations

- WARNING: Using 67.1% of F4 capacity - monitor closely
- Consider spreading refreshes: 134 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

