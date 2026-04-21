# CU Usage Report

**Generated:** 2026-04-21 08:01:33
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1397.7 CU |
| Operations | 126 |
| Avg per Operation | 11.1 CU |
| Peak Operation | 37.2 CU |
| F4 Capacity Used | 60.7% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 99.2 | 33.1 | 3 |
| df_Fact_WorkOrderParts | 63.2 | 31.6 | 2 |
| df_Fact_Parts_Details | 59.2 | 29.6 | 2 |
| df_InTrans_PartsCounter_Raw | 45.8 | 22.9 | 2 |
| df_Invoice_Raw | 42 | 21 | 2 |
| df_Fact_LaborJobSummary | 35.2 | 17.6 | 2 |
| df_Fact_First_Pass_Fill | 35.2 | 17.6 | 2 |
| df_GlTrans_Raw | 34.5 | 17.2 | 2 |
| df_Fact_Invoice_UniqueCustomers | 33.2 | 16.6 | 2 |
| df_Dim_Part | 32.7 | 16.4 | 2 |

## Recommendations

- WARNING: Using 60.7% of F4 capacity - monitor closely
- Consider spreading refreshes: 126 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

