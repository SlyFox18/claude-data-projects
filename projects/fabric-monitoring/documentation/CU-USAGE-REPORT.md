# CU Usage Report

**Generated:** 2026-06-05 08:01:46
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1525.4 CU |
| Operations | 139 |
| Avg per Operation | 11 CU |
| Peak Operation | 35.6 CU |
| F4 Capacity Used | 66.2% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_Fact_Parts_Details | 63.2 | 31.6 | 2 |
| df_Fact_Service_Invoices | 61.2 | 30.6 | 2 |
| df_JDIS_PART_INFORMATION_Raw | 60.8 | 30.4 | 2 |
| df_Fact_WorkOrderParts | 59.2 | 29.6 | 2 |
| df_Fact_Inventory | 53.2 | 26.6 | 2 |
| df_InTrans_PartsCounter_Raw | 48.2 | 24.1 | 2 |
| df_Fact_Service_Detail | 47.2 | 23.6 | 2 |
| df_Invoice_Raw | 42 | 21 | 2 |
| df_Fact_PartSales_24Hours | 38.8 | 12.9 | 3 |
| df_GlTrans_Raw | 35.8 | 17.9 | 2 |

## Recommendations

- WARNING: Using 66.2% of F4 capacity - monitor closely
- Consider spreading refreshes: 139 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

