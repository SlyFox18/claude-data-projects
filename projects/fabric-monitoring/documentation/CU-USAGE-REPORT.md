# CU Usage Report

**Generated:** 2026-10-08 08:01:31
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 907.5 CU |
| Operations | 140 |
| Avg per Operation | 6.5 CU |
| Peak Operation | 24 CU |
| F4 Capacity Used | 39.4% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 57 | 19 | 3 |
| df_InMaster_PartsLookup_Raw | 52.5 | 5.2 | 10 |
| df_Dim_Part | 32.1 | 16 | 2 |
| df_GlTrans_Raw | 31.8 | 15.9 | 2 |
| df_InTrans_PartsCounter_Raw | 28 | 14 | 2 |
| df_Fact_Parts_Details | 24.8 | 12.4 | 2 |
| df_Invoice_Raw | 20.5 | 10.2 | 2 |
| df_InHist_PmManage_Raw | 19.2 | 9.6 | 2 |
| df_Fact_Invoice_UniqueCustomers | 18.8 | 9.4 | 2 |
| df_Fact_First_Pass_Fill | 18.8 | 9.4 | 2 |

## Recommendations

- Consider spreading refreshes: 140 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

