# CU Usage Report

**Generated:** 2026-10-02 08:01:32
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 910.2 CU |
| Operations | 143 |
| Avg per Operation | 6.4 CU |
| Peak Operation | 24 CU |
| F4 Capacity Used | 39.5% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 55.8 | 18.6 | 3 |
| df_InMaster_PartsLookup_Raw | 52.5 | 5.2 | 10 |
| df_GlTrans_Raw | 34.2 | 17.1 | 2 |
| df_InTrans_PartsCounter_Raw | 31.8 | 15.9 | 2 |
| df_Fact_Transfers | 20.8 | 10.4 | 2 |
| df_InHist_PmManage_Raw | 20.5 | 10.2 | 2 |
| df_Invoice_Raw | 20.5 | 10.2 | 2 |
| df_Fact_WorkOrderParts | 18.8 | 9.4 | 2 |
| df_Fact_Service_Invoices | 16.8 | 8.4 | 2 |
| df_Fact_PartSales_24Hours | 16.8 | 8.4 | 2 |

## Recommendations

- Consider spreading refreshes: 143 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

