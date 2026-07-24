# CU Usage Report

**Generated:** 2026-07-24 08:01:30
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 568.3 CU |
| Operations | 84 |
| Avg per Operation | 6.8 CU |
| Peak Operation | 42.2 CU |
| F4 Capacity Used | 24.7% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 48.8 | 7 | 7 |
| df_Fact_Service_Invoices | 31.6 | 31.6 | 1 |
| df_InTrans_PartsCounter_Raw | 30 | 7.5 | 4 |
| df_Invoice_Raw | 23.5 | 5.9 | 4 |
| df_Fact_Service_Detail | 21.6 | 21.6 | 1 |
| df_GlTrans_Raw | 20 | 5 | 4 |
| df_Fact_Parts_Invoices | 19.6 | 19.6 | 1 |
| df_Fact_ServiceTimeSheet_Audit | 19.6 | 19.6 | 1 |
| df_InHist_PmManage_Raw | 18.8 | 4.7 | 4 |
| df_Fact_First_Pass_Fill | 17.6 | 17.6 | 1 |

## Recommendations

- Consider spreading refreshes: 84 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

