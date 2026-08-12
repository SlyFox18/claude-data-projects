# CU Usage Report

**Generated:** 2026-08-12 08:01:52
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1661.1 CU |
| Operations | 132 |
| Avg per Operation | 12.6 CU |
| Peak Operation | 155.6 CU |
| F4 Capacity Used | 72.1% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_Fact_PriceUpdate_Enriched | 344 | 86 | 4 |
| df_JDIS_PART_INFORMATION_Raw | 109.2 | 36.4 | 3 |
| df_Dim_Part | 103.8 | 26 | 4 |
| df_Invoice_Raw | 45.8 | 22.9 | 2 |
| df_Fact_Transfers | 45.2 | 22.6 | 2 |
| df_Fact_Parts_Details | 43.2 | 21.6 | 2 |
| df_InTrans_PartsCounter_Raw | 39.5 | 19.8 | 2 |
| df_GlTrans_Raw | 37 | 18.5 | 2 |
| df_Fact_First_Pass_Fill | 35.2 | 17.6 | 2 |
| df_InHist_PmManage_Raw | 33.2 | 16.6 | 2 |

## Recommendations

- WARNING: Using 72.1% of F4 capacity - monitor closely
- Consider spreading refreshes: 132 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

