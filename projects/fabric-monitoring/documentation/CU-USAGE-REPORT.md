# CU Usage Report

**Generated:** 2026-08-31 08:11:17
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 582.1 CU |
| Operations | 83 |
| Avg per Operation | 7 CU |
| Peak Operation | 18.5 CU |
| F4 Capacity Used | 25.3% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 18.5 | 18.5 | 1 |
| df_Dim_Part | 17.7 | 17.7 | 1 |
| df_Fact_Service_Detail | 17.6 | 17.6 | 1 |
| df_Fact_InSalOrd_InSalPar | 15.6 | 15.6 | 1 |
| df_Fact_Planter_Inspection_Part_Sales | 15.6 | 15.6 | 1 |
| df_Fact_NegativeOnHand_OnHandNoBin | 13.6 | 13.6 | 1 |
| df_Fact_InTrans_UniqueCustomers | 13.6 | 13.6 | 1 |
| df_GlTrans_Raw | 13.5 | 13.5 | 1 |
| df_Fact_AdjustmentPairs | 13.2 | 6.6 | 2 |
| df_Fact_Parts_Details | 11.6 | 11.6 | 1 |

## Recommendations

- Consider spreading refreshes: 83 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

