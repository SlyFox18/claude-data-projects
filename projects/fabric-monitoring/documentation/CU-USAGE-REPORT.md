# CU Usage Report

**Generated:** 2026-08-05 08:01:38
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 875.4 CU |
| Operations | 94 |
| Avg per Operation | 9.3 CU |
| Peak Operation | 37.2 CU |
| F4 Capacity Used | 38% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 108 | 36 | 3 |
| df_InTrans_Incremental | 99.9 | 14.3 | 7 |
| df_Invoice_Raw | 42 | 21 | 2 |
| df_InTrans_PartsCounter_Raw | 38.2 | 19.1 | 2 |
| df_PartsLookup_Sync_Incremental | 35.4 | 17.7 | 2 |
| df_GlTrans_Raw | 34.5 | 17.2 | 2 |
| df_InHist_PmManage_Raw | 32 | 16 | 2 |
| df_WKROFILE_Raw | 27 | 13.5 | 2 |
| df_Fact_ServiceTimeSheet_Audit | 19.6 | 19.6 | 1 |
| df_InMaster_Raw | 19.5 | 9.8 | 2 |

## Recommendations

- Consider spreading refreshes: 94 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

