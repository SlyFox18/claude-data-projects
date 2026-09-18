# CU Usage Report

**Generated:** 2026-09-18 08:01:34
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 914.2 CU |
| Operations | 147 |
| Avg per Operation | 6.2 CU |
| Peak Operation | 22.8 CU |
| F4 Capacity Used | 39.7% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 55.8 | 18.6 | 3 |
| df_InMaster_PartsLookup_Raw | 53.8 | 5.4 | 10 |
| df_GlTrans_Raw | 25.5 | 12.8 | 2 |
| df_Fact_Parts_Details | 24.8 | 12.4 | 2 |
| df_Fact_PartSales_24Hours | 23.2 | 7.7 | 3 |
| df_InTrans_PartsCounter_Raw | 21.8 | 10.9 | 2 |
| df_Invoice_Raw | 20.5 | 10.2 | 2 |
| df_Fact_Invoice_InventoryAnalysis | 18.8 | 9.4 | 2 |
| df_Fact_WorkOrderParts | 18.8 | 9.4 | 2 |
| df_InHist_PmManage_Raw | 18 | 9 | 2 |

## Recommendations

- Consider spreading refreshes: 147 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

