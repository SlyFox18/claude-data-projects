# Data Freshness Report

**Generated:** 2026-03-26 08:01:33
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 62 | 77.5% |
| Stale | 0 | 0% |
| Critical | 0 | 0% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_Part | 2026-03-26 10:08:43 | -2.1 | [OK] Fresh |
| df_Dim_Customer | 2026-03-26 10:06:12 | -2.1 | [OK] Fresh |
| df_Dim_Date | 2026-03-26 10:05:41 | -2.1 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-03-26 10:11:28 | -2.2 | [OK] Fresh |
| df_Dim_Technicans | 2026-03-26 10:10:58 | -2.2 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-03-26 10:15:13 | -2.2 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-03-26 10:11:33 | -2.2 | [OK] Fresh |
| df_Dim_JobCode | 2026-03-26 10:11:28 | -2.2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_InSalOrd_InSalPar | 2026-03-25 10:23:56 | 21.6 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-03-25 10:24:54 | 21.6 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-03-25 10:23:53 | 21.6 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-03-25 10:23:54 | 21.6 | [OK] Fresh |
| df_Fact_Service_Invoices | Error | 0 | [?] Error |
| df_Fact_Parts_Details | Error | 0 | [?] Error |
| df_Fact_Service_Detail | Error | 0 | [?] Error |
| df_Fact_WorkOrderParts | Error | 0 | [?] Error |
| df_Fact_Inventory | Error | 0 | [?] Error |
| df_Fact_Parts_Invoices | 2026-03-26 11:09:07 | -3.1 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-03-26 11:08:32 | -3.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-03-26 11:07:34 | -3.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-03-26 11:07:06 | -3.1 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-03-26 11:08:36 | -3.1 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-03-26 11:07:33 | -3.1 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-03-26 11:16:04 | -3.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-03-26 11:12:21 | -3.2 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-03-26 11:16:04 | -3.2 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-03-26 11:16:07 | -3.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-03-26 11:11:53 | -3.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-03-26 11:13:20 | -3.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-03-26 11:11:51 | -3.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-03-26 11:11:53 | -3.2 | [OK] Fresh |
| df_Fact_Transfers | 2026-03-26 11:36:16 | -3.6 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-03-26 12:58:30 | -5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_WKROFILE_Raw | 2026-03-26 09:20:16 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-03-26 09:21:16 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-03-26 09:17:46 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-03-26 09:22:46 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-03-26 09:23:46 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-03-26 09:25:46 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-03-26 09:45:06 | -1.7 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-03-26 09:45:07 | -1.7 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-03-26 09:42:22 | -1.7 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-03-26 09:46:07 | -1.7 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-03-26 09:46:06 | -1.7 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-03-26 09:45:37 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-03-26 09:51:21 | -1.8 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-03-26 09:51:23 | -1.8 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-03-26 09:49:52 | -1.8 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-03-26 09:49:51 | -1.8 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-03-26 09:49:51 | -1.8 | [OK] Fresh |
| df_INSALORD_Raw | 2026-03-26 09:49:23 | -1.8 | [OK] Fresh |
| df_InMaster_Raw | 2026-03-26 09:47:09 | -1.8 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-03-26 09:54:07 | -1.9 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-03-26 09:57:54 | -1.9 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-03-26 09:57:23 | -1.9 | [OK] Fresh |
| df_WarClaim_Raw | 2026-03-26 09:57:51 | -1.9 | [OK] Fresh |
| df_VhTrans_Raw | 2026-03-26 09:54:05 | -1.9 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-03-26 09:57:51 | -1.9 | [OK] Fresh |
| df_CONTACT_Raw | 2026-03-26 09:57:51 | -1.9 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-03-26 09:57:53 | -1.9 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-03-26 09:57:51 | -1.9 | [OK] Fresh |
| df_Technician_Raw | 2026-03-26 09:57:55 | -1.9 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-03-26 09:54:36 | -1.9 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-03-26 09:55:09 | -1.9 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-03-26 09:53:36 | -1.9 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-03-26 09:54:05 | -1.9 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-03-26 09:58:21 | -2 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

