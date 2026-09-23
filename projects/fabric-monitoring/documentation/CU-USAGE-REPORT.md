# CU Usage Report

**Generated:** 2026-09-23 08:01:32
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 880.5 CU |
| Operations | 143 |
| Avg per Operation | 6.2 CU |
| Peak Operation | 21.5 CU |
| F4 Capacity Used | 38.2% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_InMaster_PartsLookup_Raw | 59 | 5.4 | 11 |
| df_JDIS_PART_INFORMATION_Raw | 54.5 | 18.2 | 3 |
| df_GlTrans_Raw | 33 | 16.5 | 2 |
| df_Fact_Parts_Details | 22.8 | 11.4 | 2 |
| df_Fact_Transfers | 20.8 | 10.4 | 2 |
| df_InTrans_PartsCounter_Raw | 20.5 | 10.2 | 2 |
| df_Invoice_Raw | 20.5 | 10.2 | 2 |
| df_InHist_PmManage_Raw | 19.2 | 9.6 | 2 |
| df_Fact_First_Pass_Fill | 18.8 | 9.4 | 2 |
| df_Dim_Part | 16.8 | 16.8 | 1 |

## Recommendations

- Consider spreading refreshes: 143 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

