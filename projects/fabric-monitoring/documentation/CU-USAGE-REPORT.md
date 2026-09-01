# CU Usage Report

**Generated:** 2026-09-01 08:02:10
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1365.4 CU |
| Operations | 198 |
| Avg per Operation | 6.9 CU |
| Peak Operation | 18.5 CU |
| F4 Capacity Used | 59.3% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_InMaster_PartsLookup_Raw | 59.8 | 5.4 | 11 |
| df_JDIS_PART_INFORMATION_Raw | 54.2 | 18.1 | 3 |
| df_Dim_Part | 33.9 | 17 | 2 |
| df_Fact_First_Pass_Fill | 32.8 | 10.9 | 3 |
| df_GlTrans_Raw | 28.2 | 14.1 | 2 |
| df_Fact_Service_Detail | 27.2 | 13.6 | 2 |
| df_Fact_InTrans_UniqueCustomers | 27.2 | 13.6 | 2 |
| df_Fact_PartSales_24Hours | 24.8 | 8.3 | 3 |
| df_Fact_Parts_Details | 23.2 | 11.6 | 2 |
| df_Fact_Planter_Inspection_Part_Sales | 23.2 | 11.6 | 2 |

## Recommendations

- Consider spreading refreshes: 198 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

