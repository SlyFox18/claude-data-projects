# CU Usage Report

**Generated:** 2026-09-09 08:02:34
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1014.2 CU |
| Operations | 149 |
| Avg per Operation | 6.8 CU |
| Peak Operation | 19 CU |
| F4 Capacity Used | 44% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_InMaster_PartsLookup_Raw | 52.5 | 5.2 | 10 |
| df_JDIS_PART_INFORMATION_Raw | 52 | 17.3 | 3 |
| df_Dim_Part | 33.6 | 16.8 | 2 |
| df_Fact_Planter_Inspection_Part_Sales | 32.8 | 16.4 | 2 |
| df_GlTrans_Raw | 29.2 | 14.6 | 2 |
| df_Fact_NegativeOnHand_OnHandNoBin | 26.8 | 13.4 | 2 |
| df_WKROFILE_Raw | 24.5 | 8.2 | 3 |
| df_InTrans_Incremental | 22.2 | 5.6 | 4 |
| df_Invoice_Raw | 21.8 | 10.9 | 2 |
| df_Fact_First_Pass_Fill | 20.8 | 10.4 | 2 |

## Recommendations

- Consider spreading refreshes: 149 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

