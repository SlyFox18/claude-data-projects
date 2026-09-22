# CU Usage Report

**Generated:** 2026-09-22 08:01:33
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 858.1 CU |
| Operations | 140 |
| Avg per Operation | 6.1 CU |
| Peak Operation | 19 CU |
| F4 Capacity Used | 37.2% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_InMaster_PartsLookup_Raw | 57.8 | 5.2 | 11 |
| df_JDIS_PART_INFORMATION_Raw | 55.8 | 18.6 | 3 |
| df_Dim_Part | 33.6 | 16.8 | 2 |
| df_GlTrans_Raw | 28 | 14 | 2 |
| df_Fact_Transfers | 20.8 | 10.4 | 2 |
| df_Invoice_Raw | 20.5 | 10.2 | 2 |
| df_InTrans_PartsCounter_Raw | 20.5 | 10.2 | 2 |
| df_InHist_PmManage_Raw | 18 | 9 | 2 |
| df_Fact_Invoice_UniqueCustomers | 16.8 | 8.4 | 2 |
| df_Fact_First_Pass_Fill | 16.8 | 8.4 | 2 |

## Recommendations

- Consider spreading refreshes: 140 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

