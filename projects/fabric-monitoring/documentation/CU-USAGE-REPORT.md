# CU Usage Report

**Generated:** 2026-05-14 08:01:32
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1478.6 CU |
| Operations | 134 |
| Avg per Operation | 11 CU |
| Peak Operation | 38.5 CU |
| F4 Capacity Used | 64.2% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 138 | 27.6 | 5 |
| df_Fact_InternalWorkOrders | 62 | 12.4 | 5 |
| df_Fact_WorkOrderParts | 57.2 | 28.6 | 2 |
| df_Fact_Parts_Details | 55.2 | 27.6 | 2 |
| df_InTrans_PartsCounter_Raw | 52 | 26 | 2 |
| df_Fact_Transfers | 51.2 | 25.6 | 2 |
| df_Fact_Service_Detail | 45.2 | 22.6 | 2 |
| df_Invoice_Raw | 42 | 21 | 2 |
| df_Fact_LaborJobSummary | 37.2 | 18.6 | 2 |
| df_GlTrans_Raw | 33.2 | 16.6 | 2 |

## Recommendations

- WARNING: Using 64.2% of F4 capacity - monitor closely
- Consider spreading refreshes: 134 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

