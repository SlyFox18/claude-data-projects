# CU Usage Report

**Generated:** 2026-09-25 08:01:31
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 903 CU |
| Operations | 144 |
| Avg per Operation | 6.3 CU |
| Peak Operation | 22.8 CU |
| F4 Capacity Used | 39.2% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 58.2 | 19.4 | 3 |
| df_InMaster_PartsLookup_Raw | 53.8 | 5.4 | 10 |
| df_Dim_Part | 32.7 | 16.4 | 2 |
| df_GlTrans_Raw | 26.8 | 13.4 | 2 |
| df_Fact_Parts_Details | 24.8 | 12.4 | 2 |
| df_InTrans_PartsCounter_Raw | 21.8 | 10.9 | 2 |
| df_Fact_Transfers | 20.8 | 10.4 | 2 |
| df_Fact_Parts_Invoices | 18.8 | 9.4 | 2 |
| df_Fact_Service_Detail | 18.8 | 9.4 | 2 |
| df_InHist_PmManage_Raw | 18 | 9 | 2 |

## Recommendations

- Consider spreading refreshes: 144 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

