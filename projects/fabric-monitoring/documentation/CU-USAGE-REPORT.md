# CU Usage Report

**Generated:** 2026-09-03 08:01:49
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1086.6 CU |
| Operations | 155 |
| Avg per Operation | 7 CU |
| Peak Operation | 23.5 CU |
| F4 Capacity Used | 47.2% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_InMaster_PartsLookup_Raw | 62.2 | 5.7 | 11 |
| df_JDIS_PART_INFORMATION_Raw | 55.5 | 18.5 | 3 |
| df_Dim_Part | 30.9 | 15.4 | 2 |
| df_Fact_PartSales_24Hours | 30.8 | 10.3 | 3 |
| df_InTrans_PartsCounter_Raw | 29.2 | 9.8 | 3 |
| df_GlTrans_Raw | 28.2 | 14.1 | 2 |
| df_Invoice_Raw | 25.5 | 8.5 | 3 |
| df_Fact_Parts_With_Open_Orders | 23.2 | 11.6 | 2 |
| df_Fact_Parts_Details | 23.2 | 11.6 | 2 |
| df_Fact_InTrans_UniqueCustomers | 23.2 | 11.6 | 2 |

## Recommendations

- Consider spreading refreshes: 155 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

