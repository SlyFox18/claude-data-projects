# CU Usage Report

**Generated:** 2026-08-14 08:01:36
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1298.9 CU |
| Operations | 140 |
| Avg per Operation | 9.3 CU |
| Peak Operation | 38.5 CU |
| F4 Capacity Used | 56.4% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 113 | 37.7 | 3 |
| df_Dim_Part | 54.9 | 27.4 | 2 |
| df_InTrans_PartsCounter_Raw | 45.8 | 22.9 | 2 |
| df_Fact_Transfers | 45.2 | 22.6 | 2 |
| df_Invoice_Raw | 44.5 | 22.2 | 2 |
| df_Fact_Parts_Details | 43.2 | 21.6 | 2 |
| df_GlTrans_Raw | 37 | 18.5 | 2 |
| df_Fact_First_Pass_Fill | 33.2 | 16.6 | 2 |
| df_InHist_PmManage_Raw | 32 | 16 | 2 |
| df_Fact_Service_Invoices | 29.2 | 14.6 | 2 |

## Recommendations

- Consider spreading refreshes: 140 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

