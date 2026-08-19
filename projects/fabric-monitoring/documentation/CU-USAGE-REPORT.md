# CU Usage Report

**Generated:** 2026-08-19 08:01:39
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1363.3 CU |
| Operations | 148 |
| Avg per Operation | 9.2 CU |
| Peak Operation | 39.8 CU |
| F4 Capacity Used | 59.2% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 106.8 | 35.6 | 3 |
| df_InMaster_PartsLookup_Raw | 60.5 | 7.6 | 8 |
| df_Dim_Part | 45.9 | 23 | 2 |
| df_Invoice_Raw | 40.8 | 20.4 | 2 |
| df_InTrans_PartsCounter_Raw | 39.5 | 19.8 | 2 |
| df_Fact_Transfers | 39.2 | 19.6 | 2 |
| df_GlTrans_Raw | 38.2 | 19.1 | 2 |
| df_InHist_PmManage_Raw | 32 | 16 | 2 |
| df_Fact_First_Pass_Fill | 31.2 | 15.6 | 2 |
| df_WKROFILE_Raw | 27 | 13.5 | 2 |

## Recommendations

- Consider spreading refreshes: 148 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

