# CU Usage Report

**Generated:** 2026-05-19 08:01:35
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1508.4 CU |
| Operations | 141 |
| Avg per Operation | 10.7 CU |
| Peak Operation | 38.5 CU |
| F4 Capacity Used | 65.5% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 136.5 | 27.3 | 5 |
| df_Fact_Service_Invoices | 61.2 | 30.6 | 2 |
| df_Fact_WorkOrderParts | 59.2 | 29.6 | 2 |
| df_Fact_Parts_Details | 55.2 | 27.6 | 2 |
| df_Fact_Inventory | 53.2 | 26.6 | 2 |
| df_InTrans_PartsCounter_Raw | 45.8 | 22.9 | 2 |
| df_Fact_PartSales_24Hours | 44.8 | 14.9 | 3 |
| df_Invoice_Raw | 42 | 21 | 2 |
| df_GlTrans_Raw | 34.5 | 17.2 | 2 |
| df_ServiceTimeSheets_Raw | 33 | 4.1 | 8 |

## Recommendations

- WARNING: Using 65.5% of F4 capacity - monitor closely
- Consider spreading refreshes: 141 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

