# CU Usage Report

**Generated:** 2026-05-06 08:01:45
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1521.4 CU |
| Operations | 139 |
| Avg per Operation | 10.9 CU |
| Peak Operation | 33.6 CU |
| F4 Capacity Used | 66% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 98 | 32.7 | 3 |
| df_Fact_WorkOrderParts | 65.2 | 32.6 | 2 |
| df_Fact_Service_Invoices | 61.2 | 30.6 | 2 |
| df_Fact_Parts_Details | 57.2 | 28.6 | 2 |
| df_Fact_Inventory | 55.2 | 27.6 | 2 |
| df_Fact_Service_Detail | 45.2 | 22.6 | 2 |
| df_InTrans_PartsCounter_Raw | 40.8 | 20.4 | 2 |
| df_Invoice_Raw | 40.8 | 20.4 | 2 |
| df_Fact_PartSales_24Hours | 36.8 | 12.3 | 3 |
| df_GlTrans_Raw | 35.8 | 17.9 | 2 |

## Recommendations

- WARNING: Using 66% of F4 capacity - monitor closely
- Consider spreading refreshes: 139 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

