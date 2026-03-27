# CU Usage Report

**Generated:** 2026-03-27 08:01:24
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1872.3 CU |
| Operations | 137 |
| Avg per Operation | 13.7 CU |
| Peak Operation | 111.6 CU |
| F4 Capacity Used | 81.3% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_Fact_WorkOrderParts | 190.8 | 63.6 | 3 |
| df_JDIS_PART_INFORMATION_Raw | 129 | 32.2 | 4 |
| df_Fact_Planter_Inspection_Part_Sales | 88.8 | 29.6 | 3 |
| df_Fact_Inventory | 84.8 | 28.3 | 3 |
| df_Fact_Transfers | 70.8 | 23.6 | 3 |
| df_Fact_Parts_Invoices | 64.8 | 21.6 | 3 |
| df_Fact_PartSales_24Hours | 64.4 | 16.1 | 4 |
| df_Fact_LaborJobSummary | 56.8 | 18.9 | 3 |
| df_Fact_First_Pass_Fill | 56.8 | 18.9 | 3 |
| df_Fact_Invoice_UniqueCustomers | 48.8 | 16.3 | 3 |

## Recommendations

- CRITICAL: Using 81.3% of F4 capacity - consider upgrading to F8 or F16
- Consider spreading refreshes: 137 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

