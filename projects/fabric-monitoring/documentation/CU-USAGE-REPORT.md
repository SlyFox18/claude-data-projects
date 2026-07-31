# CU Usage Report

**Generated:** 2026-07-31 08:01:30
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1219.2 CU |
| Operations | 138 |
| Avg per Operation | 8.8 CU |
| Peak Operation | 41 CU |
| F4 Capacity Used | 52.9% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 108 | 36 | 3 |
| df_Fact_Parts_Details | 47.2 | 23.6 | 2 |
| df_InTrans_PartsCounter_Raw | 43.2 | 21.6 | 2 |
| df_Invoice_Raw | 43.2 | 21.6 | 2 |
| df_GlTrans_Raw | 35.8 | 17.9 | 2 |
| df_Fact_First_Pass_Fill | 33.2 | 16.6 | 2 |
| df_Fact_PartSales_24Hours | 28.8 | 9.6 | 3 |
| df_WKROFILE_Raw | 25.8 | 12.9 | 2 |
| df_Fact_Transfers | 21.6 | 21.6 | 1 |
| df_Fact_LaborJobSummary | 21.2 | 10.6 | 2 |

## Recommendations

- Consider spreading refreshes: 138 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

