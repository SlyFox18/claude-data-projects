# CU Usage Report

**Generated:** 2026-09-15 08:01:46
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 886 CU |
| Operations | 144 |
| Avg per Operation | 6.2 CU |
| Peak Operation | 19 CU |
| F4 Capacity Used | 38.5% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 53.2 | 17.8 | 3 |
| df_InMaster_PartsLookup_Raw | 52.5 | 5.2 | 10 |
| df_Dim_Part | 32.1 | 16 | 2 |
| df_GlTrans_Raw | 28 | 14 | 2 |
| df_Fact_PartSales_24Hours | 21.2 | 7.1 | 3 |
| df_Invoice_Raw | 20.5 | 10.2 | 2 |
| df_Fact_First_Pass_Fill | 18.8 | 9.4 | 2 |
| df_InHist_PmManage_Raw | 18 | 9 | 2 |
| df_Fact_InTrans_UniqueCustomers | 16.8 | 8.4 | 2 |
| df_Fact_Inventory | 16.8 | 8.4 | 2 |

## Recommendations

- Consider spreading refreshes: 144 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

