# CU Usage Report

**Generated:** 2026-07-22 08:01:38
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1448.4 CU |
| Operations | 138 |
| Avg per Operation | 10.5 CU |
| Peak Operation | 39 CU |
| F4 Capacity Used | 62.9% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 106.8 | 35.6 | 3 |
| df_Fact_Parts_Details | 55.2 | 27.6 | 2 |
| df_TechnicianPunchedTime_Raw | 47.5 | 15.8 | 3 |
| df_Fact_Transfers | 45.2 | 22.6 | 2 |
| df_InTrans_PartsCounter_Raw | 43.2 | 21.6 | 2 |
| df_GlTrans_Raw | 37 | 18.5 | 2 |
| df_Fact_Parts_Invoices | 35.2 | 17.6 | 2 |
| df_InHist_PmManage_Raw | 34.5 | 17.2 | 2 |
| df_Fact_InTrans_UniqueCustomers | 32.8 | 10.9 | 3 |
| df_Dim_Part | 30.9 | 15.4 | 2 |

## Recommendations

- WARNING: Using 62.9% of F4 capacity - monitor closely
- Consider spreading refreshes: 138 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

