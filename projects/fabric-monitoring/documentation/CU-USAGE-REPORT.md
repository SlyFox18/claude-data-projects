# CU Usage Report

**Generated:** 2026-06-23 08:01:41
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1450.4 CU |
| Operations | 137 |
| Avg per Operation | 10.6 CU |
| Peak Operation | 38.5 CU |
| F4 Capacity Used | 63% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 101.8 | 33.9 | 3 |
| df_Fact_Service_Invoices | 61.2 | 30.6 | 2 |
| df_Fact_WorkOrderParts | 55.2 | 27.6 | 2 |
| df_Fact_Parts_Details | 55.2 | 27.6 | 2 |
| df_Fact_Inventory | 49.2 | 24.6 | 2 |
| df_Fact_Service_Detail | 43.2 | 21.6 | 2 |
| df_Invoice_Raw | 42 | 21 | 2 |
| df_InTrans_PartsCounter_Raw | 39.5 | 19.8 | 2 |
| df_Fact_PartSales_24Hours | 36.8 | 12.3 | 3 |
| df_Fact_Parts_Invoices | 35.2 | 17.6 | 2 |

## Recommendations

- WARNING: Using 63% of F4 capacity - monitor closely
- Consider spreading refreshes: 137 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

