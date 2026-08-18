# CU Usage Report

**Generated:** 2026-08-18 08:01:38
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1426.2 CU |
| Operations | 147 |
| Avg per Operation | 9.7 CU |
| Peak Operation | 42.2 CU |
| F4 Capacity Used | 61.9% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 119.2 | 39.8 | 3 |
| df_Invoice_Raw | 45.8 | 22.9 | 2 |
| df_Fact_Parts_Details | 43.2 | 21.6 | 2 |
| df_Fact_Transfers | 43.2 | 21.6 | 2 |
| df_InTrans_PartsCounter_Raw | 39.5 | 19.8 | 2 |
| df_InHist_PmManage_Raw | 34.5 | 17.2 | 2 |
| df_GlTrans_Raw | 34.5 | 17.2 | 2 |
| df_Fact_WorkOrderParts | 33.2 | 16.6 | 2 |
| df_Fact_PartSales_24Hours | 32.8 | 10.9 | 3 |
| df_Fact_First_Pass_Fill | 31.2 | 15.6 | 2 |

## Recommendations

- WARNING: Using 61.9% of F4 capacity - monitor closely
- Consider spreading refreshes: 147 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

