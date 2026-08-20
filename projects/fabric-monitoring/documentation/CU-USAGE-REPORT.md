# CU Usage Report

**Generated:** 2026-08-20 08:01:39
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1364 CU |
| Operations | 150 |
| Avg per Operation | 9.1 CU |
| Peak Operation | 38.5 CU |
| F4 Capacity Used | 59.2% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 109 | 27.2 | 4 |
| df_InMaster_PartsLookup_Raw | 88.5 | 8 | 11 |
| df_Dim_Part | 45.9 | 23 | 2 |
| df_InTrans_PartsCounter_Raw | 44.5 | 22.2 | 2 |
| df_GlTrans_Raw | 39.5 | 19.8 | 2 |
| df_Invoice_Raw | 39.5 | 19.8 | 2 |
| df_Fact_Parts_Details | 39.2 | 19.6 | 2 |
| df_Fact_PartSales_24Hours | 34.8 | 11.6 | 3 |
| df_WKROFILE_Raw | 34 | 8.5 | 4 |
| df_Fact_Parts_Invoices | 33.2 | 16.6 | 2 |

## Recommendations

- Consider spreading refreshes: 150 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

