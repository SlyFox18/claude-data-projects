# CU Usage Report

**Generated:** 2026-09-30 08:01:23
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 945.3 CU |
| Operations | 157 |
| Avg per Operation | 6 CU |
| Peak Operation | 16.5 CU |
| F4 Capacity Used | 41% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_InMaster_PartsLookup_Raw | 51.2 | 5.1 | 10 |
| df_JDIS_PART_INFORMATION_Raw | 49 | 12.2 | 4 |
| df_Dim_Part | 30.6 | 15.3 | 2 |
| df_GlTrans_Raw | 28 | 14 | 2 |
| df_Fact_PartSales_24Hours | 23.2 | 7.7 | 3 |
| df_Fact_Invoice_UniqueCustomers | 22.8 | 11.4 | 2 |
| df_WKROFILE_Raw | 22 | 7.3 | 3 |
| df_Fact_Parts_Details | 20.8 | 10.4 | 2 |
| df_Fact_Transfers | 20.8 | 10.4 | 2 |
| df_Invoice_Raw | 20.5 | 6.8 | 3 |

## Recommendations

- Consider spreading refreshes: 157 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

