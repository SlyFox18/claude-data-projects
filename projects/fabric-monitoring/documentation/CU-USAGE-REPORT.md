# CU Usage Report

**Generated:** 2026-10-07 08:01:47
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 894.9 CU |
| Operations | 148 |
| Avg per Operation | 6 CU |
| Peak Operation | 19 CU |
| F4 Capacity Used | 38.8% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_InMaster_PartsLookup_Raw | 58.8 | 5.9 | 10 |
| df_JDIS_PART_INFORMATION_Raw | 55.8 | 18.6 | 3 |
| df_GlTrans_Raw | 30.5 | 15.2 | 2 |
| df_Fact_PartSales_24Hours | 23.2 | 7.7 | 3 |
| df_InTrans_PartsCounter_Raw | 20.5 | 10.2 | 2 |
| df_Invoice_Raw | 20.5 | 10.2 | 2 |
| df_InHist_PmManage_Raw | 19.2 | 9.6 | 2 |
| df_Fact_First_Pass_Fill | 18.8 | 9.4 | 2 |
| df_Fact_WorkOrderParts | 18.8 | 9.4 | 2 |
| df_Fact_LaborJobSummary | 16.8 | 8.4 | 2 |

## Recommendations

- Consider spreading refreshes: 148 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

