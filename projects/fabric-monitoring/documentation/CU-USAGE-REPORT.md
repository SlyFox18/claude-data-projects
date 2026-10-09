# CU Usage Report

**Generated:** 2026-10-09 08:01:47
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 905.5 CU |
| Operations | 142 |
| Avg per Operation | 6.4 CU |
| Peak Operation | 24 CU |
| F4 Capacity Used | 39.3% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_InMaster_PartsLookup_Raw | 65.2 | 5.9 | 11 |
| df_JDIS_PART_INFORMATION_Raw | 58.2 | 19.4 | 3 |
| df_Dim_Part | 32.1 | 16 | 2 |
| df_InTrans_PartsCounter_Raw | 29.2 | 14.6 | 2 |
| df_Fact_Parts_Details | 24.8 | 12.4 | 2 |
| df_Fact_Transfers | 20.8 | 10.4 | 2 |
| df_Invoice_Raw | 20.5 | 10.2 | 2 |
| df_InHist_PmManage_Raw | 19.2 | 9.6 | 2 |
| df_Fact_MDInvoices_NoFreight | 19.2 | 6.4 | 3 |
| df_Fact_Invoice_UniqueCustomers | 18.8 | 9.4 | 2 |

## Recommendations

- Consider spreading refreshes: 142 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

