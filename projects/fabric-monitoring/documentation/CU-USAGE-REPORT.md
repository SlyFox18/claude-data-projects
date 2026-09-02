# CU Usage Report

**Generated:** 2026-09-02 08:01:50
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1048.2 CU |
| Operations | 157 |
| Avg per Operation | 6.7 CU |
| Peak Operation | 19.6 CU |
| F4 Capacity Used | 45.5% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_InMaster_PartsLookup_Raw | 54.8 | 5 | 11 |
| df_JDIS_PART_INFORMATION_Raw | 33.2 | 16.6 | 2 |
| df_Fact_AdjustmentPairs | 30.8 | 10.3 | 3 |
| df_GlTrans_Raw | 29.5 | 14.8 | 2 |
| df_Fact_PartSales_24Hours | 26.8 | 8.9 | 3 |
| df_Fact_First_Pass_Fill | 25.2 | 12.6 | 2 |
| df_Fact_Transfers | 23.2 | 11.6 | 2 |
| df_Fact_WorkOrderParts | 21.2 | 10.6 | 2 |
| df_Fact_Equipment_Sales | 21.2 | 10.6 | 2 |
| df_InTrans_PartsCounter_Raw | 20.8 | 10.4 | 2 |

## Recommendations

- Consider spreading refreshes: 157 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

