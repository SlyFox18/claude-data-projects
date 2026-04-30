# CU Usage Report

**Generated:** 2026-04-30 08:01:34
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1407.4 CU |
| Operations | 122 |
| Avg per Operation | 11.5 CU |
| Peak Operation | 38.5 CU |
| F4 Capacity Used | 61.1% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 128 | 25.6 | 5 |
| df_Fact_Service_Invoices | 61.2 | 30.6 | 2 |
| df_Fact_WorkOrderParts | 59.2 | 29.6 | 2 |
| df_Fact_Inventory | 51.2 | 25.6 | 2 |
| df_Fact_Transfers | 49.2 | 24.6 | 2 |
| df_InTrans_PartsCounter_Raw | 47 | 23.5 | 2 |
| df_Fact_Service_Detail | 43.2 | 21.6 | 2 |
| df_GlTrans_Raw | 40.8 | 20.4 | 2 |
| df_Invoice_Raw | 40.8 | 20.4 | 2 |
| df_Fact_PartSales_24Hours | 38.8 | 12.9 | 3 |

## Recommendations

- WARNING: Using 61.1% of F4 capacity - monitor closely
- Consider spreading refreshes: 122 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

