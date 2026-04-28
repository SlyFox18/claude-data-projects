# CU Usage Report

**Generated:** 2026-04-28 08:01:33
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1491 CU |
| Operations | 132 |
| Avg per Operation | 11.3 CU |
| Peak Operation | 32.2 CU |
| F4 Capacity Used | 64.7% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 95.5 | 31.8 | 3 |
| df_Fact_Service_Invoices | 63.2 | 31.6 | 2 |
| df_Fact_WorkOrderParts | 61.2 | 30.6 | 2 |
| df_Fact_Inventory | 55.2 | 27.6 | 2 |
| df_Fact_Transfers | 49.2 | 24.6 | 2 |
| df_Fact_Service_Detail | 47.2 | 23.6 | 2 |
| df_Invoice_Raw | 42 | 21 | 2 |
| df_InTrans_PartsCounter_Raw | 39.5 | 19.8 | 2 |
| df_Fact_PartSales_24Hours | 38.8 | 12.9 | 3 |
| df_Fact_First_Pass_Fill | 35.2 | 17.6 | 2 |

## Recommendations

- WARNING: Using 64.7% of F4 capacity - monitor closely
- Consider spreading refreshes: 132 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

