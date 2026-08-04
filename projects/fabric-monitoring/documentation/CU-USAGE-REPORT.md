# CU Usage Report

**Generated:** 2026-08-04 08:01:48
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1298.8 CU |
| Operations | 141 |
| Avg per Operation | 9.2 CU |
| Peak Operation | 38.5 CU |
| F4 Capacity Used | 56.4% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 110.5 | 36.8 | 3 |
| df_PartsLookup_Sync | 83.1 | 27.7 | 3 |
| df_Fact_Transfers | 47.2 | 23.6 | 2 |
| df_Invoice_Raw | 43.2 | 21.6 | 2 |
| df_InTrans_PartsCounter_Raw | 37 | 18.5 | 2 |
| df_GlTrans_Raw | 34.5 | 17.2 | 2 |
| df_Fact_PartSales_24Hours | 32.8 | 10.9 | 3 |
| df_InHist_PmManage_Raw | 32 | 16 | 2 |
| df_InMaster_PartsLookup_Raw | 31.5 | 7.9 | 4 |
| df_Fact_First_Pass_Fill | 31.2 | 15.6 | 2 |

## Recommendations

- Consider spreading refreshes: 141 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

