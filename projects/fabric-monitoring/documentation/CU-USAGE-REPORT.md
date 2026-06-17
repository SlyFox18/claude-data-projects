# CU Usage Report

**Generated:** 2026-06-17 08:01:36
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1550.4 CU |
| Operations | 148 |
| Avg per Operation | 10.5 CU |
| Peak Operation | 34.8 CU |
| F4 Capacity Used | 67.3% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 95.5 | 31.8 | 3 |
| df_Fact_ServiceTimeSheet_Audit | 73.6 | 12.3 | 6 |
| df_Fact_Service_Invoices | 61.2 | 30.6 | 2 |
| df_Fact_WorkOrderParts | 59.2 | 29.6 | 2 |
| df_Fact_Parts_Details | 57.2 | 28.6 | 2 |
| df_Fact_Inventory | 51.2 | 25.6 | 2 |
| df_Invoice_Raw | 43.2 | 21.6 | 2 |
| df_InTrans_PartsCounter_Raw | 43.2 | 21.6 | 2 |
| df_Fact_Service_Detail | 43.2 | 21.6 | 2 |
| df_ServiceTimeSheets_Raw | 40.5 | 5.1 | 8 |

## Recommendations

- WARNING: Using 67.3% of F4 capacity - monitor closely
- Consider spreading refreshes: 148 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

