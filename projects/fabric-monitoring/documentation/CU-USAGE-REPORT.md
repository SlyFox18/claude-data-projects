# CU Usage Report

**Generated:** 2026-09-16 08:01:31
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 951.7 CU |
| Operations | 149 |
| Avg per Operation | 6.4 CU |
| Peak Operation | 17.8 CU |
| F4 Capacity Used | 41.3% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_InMaster_PartsLookup_Raw | 61.5 | 5.6 | 11 |
| df_JDIS_PART_INFORMATION_Raw | 50.8 | 16.9 | 3 |
| df_GlTrans_Raw | 30.5 | 15.2 | 2 |
| df_InTrans_PartsCounter_Raw | 25.5 | 12.8 | 2 |
| df_Fact_PartSales_24Hours | 23.2 | 7.7 | 3 |
| df_Fact_Transfers | 20.8 | 10.4 | 2 |
| df_Invoice_Raw | 20.5 | 10.2 | 2 |
| df_InHist_PmManage_Raw | 19.2 | 9.6 | 2 |
| df_Fact_Service_Detail | 18.8 | 9.4 | 2 |
| df_Fact_Invoice_UniqueCustomers | 16.8 | 8.4 | 2 |

## Recommendations

- Consider spreading refreshes: 149 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

