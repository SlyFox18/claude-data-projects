# CU Usage Report

**Generated:** 2026-08-26 08:01:44
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | -5582 CU |
| Operations | 210 |
| Avg per Operation | -26.6 CU |
| Peak Operation | 37.2 CU |
| F4 Capacity Used | -242.3% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 103.8 | 20.8 | 5 |
| df_InMaster_PartsLookup_Raw | 91 | 5.7 | 16 |
| df_Fact_First_Pass_Fill | 62 | 12.4 | 5 |
| df_Fact_Parts_Details | 44.8 | 14.9 | 3 |
| df_InTrans_PartsCounter_Raw | 43.8 | 8.8 | 5 |
| df_Invoice_Raw | 42.8 | 10.7 | 4 |
| df_GlTrans_Raw | 42.8 | 10.7 | 4 |
| df_Fact_WorkOrderParts | 40.8 | 13.6 | 3 |
| df_InHist_PmManage_Raw | 40 | 8 | 5 |
| df_Dim_Part | 38.4 | 19.2 | 2 |

## Recommendations

- Consider spreading refreshes: 210 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

