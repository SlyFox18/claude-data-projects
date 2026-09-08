# CU Usage Report

**Generated:** 2026-09-08 08:01:48
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1040.3 CU |
| Operations | 157 |
| Avg per Operation | 6.6 CU |
| Peak Operation | 20.4 CU |
| F4 Capacity Used | 45.2% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_InMaster_PartsLookup_Raw | 57.8 | 5.2 | 11 |
| df_JDIS_PART_INFORMATION_Raw | 54.5 | 18.2 | 3 |
| df_Fact_Top50_JobCodes | 30.8 | 15.4 | 2 |
| df_GlTrans_Raw | 28 | 14 | 2 |
| df_InTrans_Incremental | 25.2 | 6.3 | 4 |
| df_Fact_Parts_Details | 24.8 | 12.4 | 2 |
| df_Fact_PartsPromo | 22.8 | 11.4 | 2 |
| df_Fact_Transfers | 22.8 | 11.4 | 2 |
| df_Fact_PartSales_24Hours | 21.2 | 7.1 | 3 |
| df_Fact_First_Pass_Fill | 20.8 | 10.4 | 2 |

## Recommendations

- Consider spreading refreshes: 157 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

