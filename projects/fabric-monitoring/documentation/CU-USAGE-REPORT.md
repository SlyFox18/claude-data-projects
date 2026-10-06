# CU Usage Report

**Generated:** 2026-10-06 08:01:27
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 868.8 CU |
| Operations | 145 |
| Avg per Operation | 6 CU |
| Peak Operation | 19 CU |
| F4 Capacity Used | 37.7% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_InMaster_PartsLookup_Raw | 56.5 | 5.1 | 11 |
| df_JDIS_PART_INFORMATION_Raw | 54.5 | 18.2 | 3 |
| df_GlTrans_Raw | 28 | 14 | 2 |
| df_Fact_Parts_Details | 20.8 | 10.4 | 2 |
| df_InTrans_PartsCounter_Raw | 20.5 | 10.2 | 2 |
| df_Invoice_Raw | 20.5 | 10.2 | 2 |
| df_Fact_First_Pass_Fill | 18.8 | 9.4 | 2 |
| df_Fact_Service_Detail | 18.8 | 9.4 | 2 |
| df_InHist_PmManage_Raw | 18 | 9 | 2 |
| df_Fact_Parts_Invoices | 16.8 | 8.4 | 2 |

## Recommendations

- Consider spreading refreshes: 145 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

