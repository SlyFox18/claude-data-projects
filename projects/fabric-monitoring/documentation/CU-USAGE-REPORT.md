# CU Usage Report

**Generated:** 2026-07-02 08:01:34
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1491.2 CU |
| Operations | 134 |
| Avg per Operation | 11.1 CU |
| Peak Operation | 43.5 CU |
| F4 Capacity Used | 64.7% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 77 | 38.5 | 2 |
| df_Fact_Service_Invoices | 67.2 | 33.6 | 2 |
| df_Fact_Parts_Details | 61.2 | 30.6 | 2 |
| df_Fact_Inventory | 55.2 | 27.6 | 2 |
| df_GlTrans_Raw | 47 | 23.5 | 2 |
| df_InTrans_PartsCounter_Raw | 47 | 23.5 | 2 |
| df_Invoice_Raw | 44.5 | 22.2 | 2 |
| df_Fact_Parts_Invoices | 39.2 | 19.6 | 2 |
| df_Fact_First_Pass_Fill | 37.2 | 18.6 | 2 |
| df_Fact_WorkOrderParts | 33.6 | 33.6 | 1 |

## Recommendations

- WARNING: Using 64.7% of F4 capacity - monitor closely
- Consider spreading refreshes: 134 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

