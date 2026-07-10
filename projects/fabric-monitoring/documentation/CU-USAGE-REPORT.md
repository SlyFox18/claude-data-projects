# CU Usage Report

**Generated:** 2026-07-10 08:01:42
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1441 CU |
| Operations | 134 |
| Avg per Operation | 10.8 CU |
| Peak Operation | 36 CU |
| F4 Capacity Used | 62.5% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 75.5 | 25.2 | 3 |
| df_Fact_Service_Invoices | 65.2 | 32.6 | 2 |
| df_Fact_Parts_Details | 59.2 | 29.6 | 2 |
| df_Fact_WorkOrderParts | 57.2 | 28.6 | 2 |
| df_InTrans_PartsCounter_Raw | 48.2 | 24.1 | 2 |
| df_Fact_Service_Detail | 47.2 | 23.6 | 2 |
| df_Invoice_Raw | 44.5 | 22.2 | 2 |
| df_Fact_First_Pass_Fill | 37.2 | 18.6 | 2 |
| df_GlTrans_Raw | 35.8 | 17.9 | 2 |
| df_Fact_LaborJobSummary | 35.6 | 17.8 | 2 |

## Recommendations

- WARNING: Using 62.5% of F4 capacity - monitor closely
- Consider spreading refreshes: 134 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

