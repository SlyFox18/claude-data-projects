# CU Usage Report

**Generated:** 2026-09-29 08:01:28
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 883 CU |
| Operations | 147 |
| Avg per Operation | 6 CU |
| Peak Operation | 24 CU |
| F4 Capacity Used | 38.3% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 57.8 | 14.4 | 4 |
| df_InMaster_PartsLookup_Raw | 57.8 | 5.2 | 11 |
| df_GlTrans_Raw | 28 | 14 | 2 |
| df_WKROFILE_Raw | 28 | 7 | 4 |
| df_InTrans_PartsCounter_Raw | 23 | 7.7 | 3 |
| df_Fact_PartSales_24Hours | 21.2 | 7.1 | 3 |
| df_Fact_Parts_Details | 20.8 | 10.4 | 2 |
| df_Invoice_Raw | 20.5 | 6.8 | 3 |
| df_Fact_Service_Detail | 18.8 | 9.4 | 2 |
| df_Fact_WorkOrderParts | 18.8 | 9.4 | 2 |

## Recommendations

- Consider spreading refreshes: 147 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

