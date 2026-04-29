# CU Usage Report

**Generated:** 2026-04-29 08:01:40
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1448.1 CU |
| Operations | 130 |
| Avg per Operation | 11.1 CU |
| Peak Operation | 33.5 CU |
| F4 Capacity Used | 62.9% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 64.5 | 32.2 | 2 |
| df_Fact_Service_Invoices | 61.2 | 30.6 | 2 |
| df_Fact_WorkOrderParts | 61.2 | 30.6 | 2 |
| df_Fact_Inventory | 53.2 | 26.6 | 2 |
| df_Fact_Parts_Details | 53.2 | 26.6 | 2 |
| df_Fact_Transfers | 47.2 | 23.6 | 2 |
| df_Invoice_Raw | 42 | 21 | 2 |
| df_InTrans_PartsCounter_Raw | 42 | 21 | 2 |
| df_GlTrans_Raw | 40.8 | 20.4 | 2 |
| df_Fact_PartSales_24Hours | 38.8 | 12.9 | 3 |

## Recommendations

- WARNING: Using 62.9% of F4 capacity - monitor closely
- Consider spreading refreshes: 130 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

