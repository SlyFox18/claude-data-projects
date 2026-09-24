# CU Usage Report

**Generated:** 2026-09-24 08:01:30
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 958.9 CU |
| Operations | 153 |
| Avg per Operation | 6.3 CU |
| Peak Operation | 22.8 CU |
| F4 Capacity Used | 41.6% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 60.8 | 20.2 | 3 |
| df_InMaster_PartsLookup_Raw | 59 | 5.4 | 11 |
| df_Dim_Part | 32.7 | 16.4 | 2 |
| df_GlTrans_Raw | 31.8 | 15.9 | 2 |
| df_Fact_PartSales_24Hours | 25.2 | 8.4 | 3 |
| df_InTrans_PartsCounter_Raw | 23 | 11.5 | 2 |
| df_Fact_WorkOrderParts | 20.8 | 10.4 | 2 |
| df_Fact_Transfers | 20.8 | 10.4 | 2 |
| df_Invoice_Raw | 20.5 | 10.2 | 2 |
| df_InHist_PmManage_Raw | 19.2 | 9.6 | 2 |

## Recommendations

- Consider spreading refreshes: 153 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

