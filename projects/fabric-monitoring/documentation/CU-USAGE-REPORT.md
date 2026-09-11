# CU Usage Report

**Generated:** 2026-09-11 08:01:41
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1014.1 CU |
| Operations | 151 |
| Avg per Operation | 6.7 CU |
| Peak Operation | 22.8 CU |
| F4 Capacity Used | 44% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 58.2 | 19.4 | 3 |
| df_InMaster_PartsLookup_Raw | 57.8 | 5.2 | 11 |
| df_InTrans_PartsCounter_Raw | 33 | 16.5 | 2 |
| df_GlTrans_Raw | 31.8 | 15.9 | 2 |
| df_Fact_InSalOrd_InSalPar | 24.8 | 12.4 | 2 |
| df_Fact_PendingInspections | 23.2 | 7.7 | 3 |
| df_Fact_Planter_Inspection_Part_Sales | 22.8 | 11.4 | 2 |
| df_Invoice_Raw | 21.8 | 10.9 | 2 |
| df_Fact_WorkOrderParts | 20.8 | 10.4 | 2 |
| df_Fact_First_Pass_Fill | 20.8 | 10.4 | 2 |

## Recommendations

- Consider spreading refreshes: 151 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

