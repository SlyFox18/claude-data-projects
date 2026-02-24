# CU Usage Report

**Generated:** 2026-02-24 14:54:01
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 681.9 CU |
| Operations | 54 |
| Avg per Operation | 12.6 CU |
| Peak Operation | 87.6 CU |
| F4 Capacity Used | 29.6% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_Fact_WorkOrderParts | 173.2 | 86.6 | 2 |
| df_FactPartTransactions_Incremental | 107.6 | 35.9 | 3 |
| df_Fact_Service_Invoices | 43.6 | 43.6 | 1 |
| df_Fact_Service_Parts_Detail | 35.2 | 17.6 | 2 |
| df_Fact_Invoice_UniqueCustomers | 31.6 | 31.6 | 1 |
| df_InHist_PmManage_Raw | 27.8 | 6.9 | 4 |
| df_Fact_First_Pass_Fill | 23.6 | 23.6 | 1 |
| df_Fact_InTrans_UniqueCustomers | 21.2 | 10.6 | 2 |
| df_Fact_Branch12_Transactions | 19.2 | 9.6 | 2 |
| df_GlTrans_Raw | 18.8 | 3.8 | 5 |

## Recommendations

- Consider spreading refreshes: 22 operations at hour 9

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

