# CU Usage Report

**Generated:** 2026-05-08 08:01:34
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1577.2 CU |
| Operations | 135 |
| Avg per Operation | 11.7 CU |
| Peak Operation | 38.5 CU |
| F4 Capacity Used | 68.5% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 98 | 32.7 | 3 |
| df_Fact_Service_Invoices | 63.2 | 31.6 | 2 |
| df_Fact_WorkOrderParts | 59.2 | 29.6 | 2 |
| df_Fact_Parts_Details | 55.2 | 27.6 | 2 |
| df_Fact_JobCodeFrequency_Branch | 55.2 | 27.6 | 2 |
| df_Fact_Inventory | 51.2 | 25.6 | 2 |
| df_Fact_Transfers | 47.2 | 23.6 | 2 |
| df_InTrans_PartsCounter_Raw | 44.5 | 22.2 | 2 |
| df_Invoice_Raw | 42 | 21 | 2 |
| df_Fact_PartSales_24Hours | 38.8 | 12.9 | 3 |

## Recommendations

- WARNING: Using 68.5% of F4 capacity - monitor closely
- Consider spreading refreshes: 135 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

