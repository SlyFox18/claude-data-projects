# CU Usage Report

**Generated:** 2026-02-24 14:04:01
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 693.2 CU |
| Operations | 54 |
| Avg per Operation | 12.8 CU |
| Peak Operation | 87.6 CU |
| F4 Capacity Used | 30.1% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_Fact_WorkOrderParts | 242.8 | 80.9 | 3 |
| df_FactPartTransactions_Incremental | 54 | 27 | 2 |
| df_Fact_Inventory | 35.6 | 35.6 | 1 |
| df_Fact_Invoice_UniqueCustomers | 31.6 | 31.6 | 1 |
| df_Fact_Invoice_InventoryAnalysis | 27.2 | 13.6 | 2 |
| df_Fact_Top50_JobCodes | 25.2 | 12.6 | 2 |
| df_Fact_First_Pass_Fill | 23.6 | 23.6 | 1 |
| df_InHist_PmManage_Raw | 23 | 7.7 | 3 |
| df_Fact_InTrans_UniqueCustomers | 21.2 | 10.6 | 2 |
| df_Fact_Service_Parts_Detail | 19.6 | 19.6 | 1 |

## Recommendations

- Consider spreading refreshes: 22 operations at hour 9

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

