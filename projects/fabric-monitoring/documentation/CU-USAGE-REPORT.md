# CU Usage Report

**Generated:** 2026-10-01 08:01:32
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1002.8 CU |
| Operations | 162 |
| Avg per Operation | 6.2 CU |
| Peak Operation | 24 CU |
| F4 Capacity Used | 43.5% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_InMaster_PartsLookup_Raw | 57.8 | 5.2 | 11 |
| df_JDIS_PART_INFORMATION_Raw | 55.8 | 18.6 | 3 |
| df_GlTrans_Raw | 35.5 | 17.8 | 2 |
| df_InTrans_PartsCounter_Raw | 31.8 | 15.9 | 2 |
| df_Dim_Part | 30.6 | 15.3 | 2 |
| df_Fact_Parts_Details | 22.8 | 11.4 | 2 |
| df_Fact_Transfers | 20.8 | 10.4 | 2 |
| df_InHist_PmManage_Raw | 20.5 | 10.2 | 2 |
| df_Invoice_Raw | 20.5 | 10.2 | 2 |
| df_Fact_Service_Detail | 16.8 | 8.4 | 2 |

## Recommendations

- Consider spreading refreshes: 162 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

