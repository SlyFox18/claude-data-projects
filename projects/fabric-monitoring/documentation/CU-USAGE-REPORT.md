# CU Usage Report

**Generated:** 2026-05-20 08:01:37
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1422.3 CU |
| Operations | 135 |
| Avg per Operation | 10.5 CU |
| Peak Operation | 33.5 CU |
| F4 Capacity Used | 61.7% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 95.5 | 31.8 | 3 |
| df_Fact_ServiceTimeSheet_Audit | 46 | 9.2 | 5 |
| df_Invoice_Raw | 42 | 21 | 2 |
| df_InTrans_PartsCounter_Raw | 42 | 21 | 2 |
| df_GlTrans_Raw | 37 | 18.5 | 2 |
| df_Fact_First_Pass_Fill | 35.6 | 17.8 | 2 |
| df_Fact_Invoice_UniqueCustomers | 35.2 | 17.6 | 2 |
| df_Fact_Service_Invoices | 31.6 | 31.6 | 1 |
| df_Dim_Part | 30.9 | 15.4 | 2 |
| df_InHist_PmManage_Raw | 30.8 | 15.4 | 2 |

## Recommendations

- WARNING: Using 61.7% of F4 capacity - monitor closely
- Consider spreading refreshes: 135 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

