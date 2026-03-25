# Data Freshness Report

**Generated:** 2026-03-25 08:01:18
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 67 | 83.8% |
| Stale | 0 | 0% |
| Critical | 0 | 0% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_Customer | 2026-03-25 09:50:56 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-03-25 09:49:56 | -1.8 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-03-25 09:56:38 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-03-25 09:55:37 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-03-25 09:56:07 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-03-25 09:56:07 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-03-25 09:55:38 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-03-25 09:53:26 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_Service_Detail | 2026-03-25 10:03:03 | -2 | [OK] Fresh |
| df_Fact_Inventory | 2026-03-25 10:04:04 | -2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-03-25 10:04:03 | -2 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-03-25 09:59:33 | -2 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-03-25 10:06:33 | -2.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-03-25 10:04:33 | -2.1 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-03-25 10:15:15 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-03-25 10:12:18 | -2.2 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-03-25 10:10:18 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-03-25 10:14:45 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-03-25 10:16:00 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-03-25 10:15:02 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-03-25 10:15:34 | -2.2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-03-25 10:11:17 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-03-25 10:10:52 | -2.2 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-03-25 10:10:48 | -2.2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-03-25 10:11:19 | -2.2 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-03-25 10:18:44 | -2.3 | [OK] Fresh |
| df_Fact_Transfers | 2026-03-25 10:21:42 | -2.3 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-03-25 10:18:41 | -2.3 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-03-25 10:18:42 | -2.3 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-03-25 10:23:53 | -2.4 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-03-25 10:23:54 | -2.4 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-03-25 10:23:56 | -2.4 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-03-25 10:24:54 | -2.4 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_WKROFILE_Raw | 2026-03-25 09:20:15 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-03-25 09:21:45 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-03-25 09:17:44 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-03-25 09:23:45 | -1.4 | [OK] Fresh |
| df_GlTrans_Raw | 2026-03-25 09:22:53 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-03-25 09:23:15 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-03-25 09:27:45 | -1.4 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-03-25 09:34:10 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-03-25 09:30:26 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-03-25 09:30:26 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-03-25 09:30:57 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-03-25 09:31:56 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-03-25 09:30:56 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-03-25 09:31:57 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-03-25 09:39:51 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-03-25 09:35:39 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-03-25 09:36:08 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-03-25 09:38:51 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-03-25 09:39:21 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-03-25 09:34:38 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-03-25 09:35:08 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-03-25 09:34:39 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-03-25 09:38:54 | -1.6 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-03-25 09:38:51 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-03-25 09:38:52 | -1.6 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-03-25 09:42:03 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-03-25 09:42:33 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-03-25 09:42:33 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-03-25 09:42:35 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-03-25 09:43:33 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-03-25 09:42:33 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-03-25 09:42:34 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-03-25 09:42:35 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-03-25 09:42:36 | -1.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

