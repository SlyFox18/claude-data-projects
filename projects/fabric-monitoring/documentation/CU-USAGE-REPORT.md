# CU Usage Report

**Generated:** 2026-08-21 08:01:39
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1437 CU |
| Operations | 156 |
| Avg per Operation | 9.2 CU |
| Peak Operation | 38.5 CU |
| F4 Capacity Used | 62.4% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 115.2 | 28.8 | 4 |
| df_InMaster_PartsLookup_Raw | 88.5 | 8 | 11 |
| df_InTrans_PartsCounter_Raw | 48.2 | 24.1 | 2 |
| df_Dim_Part | 47.4 | 23.7 | 2 |
| df_Fact_Parts_Details | 45.2 | 22.6 | 2 |
| df_Fact_Transfers | 45.2 | 22.6 | 2 |
| df_GlTrans_Raw | 35.8 | 17.9 | 2 |
| df_InHist_PmManage_Raw | 35.8 | 17.9 | 2 |
| df_WKROFILE_Raw | 35.2 | 8.8 | 4 |
| df_Fact_PartSales_24Hours | 30.8 | 10.3 | 3 |

## Recommendations

- WARNING: Using 62.4% of F4 capacity - monitor closely
- Consider spreading refreshes: 156 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

