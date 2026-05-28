# CU Usage Report

**Generated:** 2026-05-28 08:01:35
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 2184.5 CU |
| Operations | 196 |
| Avg per Operation | 11.1 CU |
| Peak Operation | 38.5 CU |
| F4 Capacity Used | 94.8% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_Fact_ServiceTimeSheet_Audit | 202.4 | 14.5 | 14 |
| df_JDIS_PART_INFORMATION_Raw | 192.5 | 27.5 | 7 |
| df_Fact_Service_Invoices | 92.8 | 30.9 | 3 |
| df_Fact_PartSales_24Hours | 75.6 | 12.6 | 6 |
| df_Fact_Transfers | 74.8 | 24.9 | 3 |
| df_InTrans_PartsCounter_Raw | 70.5 | 23.5 | 3 |
| df_Invoice_Raw | 65.5 | 21.8 | 3 |
| df_Fact_Service_Detail | 62.8 | 20.9 | 3 |
| df_Fact_WorkOrderParts | 55.2 | 27.6 | 2 |
| df_GlTrans_Raw | 54.2 | 18.1 | 3 |

## Recommendations

- CRITICAL: Using 94.8% of F4 capacity - consider upgrading to F8 or F16
- Consider spreading refreshes: 196 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

