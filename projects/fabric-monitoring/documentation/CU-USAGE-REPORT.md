# CU Usage Report

**Generated:** 2026-05-07 08:01:32
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1774.1 CU |
| Operations | 136 |
| Avg per Operation | 13 CU |
| Peak Operation | 97.2 CU |
| F4 Capacity Used | 77% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_Dim_WkCodeFl | 254.7 | 42.4 | 6 |
| df_JDIS_PART_INFORMATION_Raw | 136.5 | 27.3 | 5 |
| df_Fact_WorkOrderParts | 63.2 | 31.6 | 2 |
| df_Fact_Service_Invoices | 61.2 | 30.6 | 2 |
| df_Fact_Parts_Details | 55.2 | 27.6 | 2 |
| df_Fact_Inventory | 53.2 | 26.6 | 2 |
| df_InTrans_PartsCounter_Raw | 45.8 | 22.9 | 2 |
| df_Fact_Service_Detail | 45.2 | 22.6 | 2 |
| df_Fact_PartSales_24Hours | 42.8 | 14.3 | 3 |
| df_Invoice_Raw | 42 | 21 | 2 |

## Recommendations

- WARNING: Using 77% of F4 capacity - monitor closely
- Consider spreading refreshes: 136 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

