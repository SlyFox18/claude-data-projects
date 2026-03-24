# Data Freshness Report

**Generated:** 2026-03-24 08:01:22
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 67 | 84.8% |
| Stale | 0 | 0% |
| Critical | 0 | 0% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_Part | 2026-03-24 10:03:56 | -2 | [OK] Fresh |
| df_Dim_Customer | 2026-03-24 10:00:26 | -2 | [OK] Fresh |
| df_Dim_Date | 2026-03-24 09:59:27 | -2 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-03-24 10:06:09 | -2.1 | [OK] Fresh |
| df_Dim_Technicans | 2026-03-24 10:06:11 | -2.1 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-03-24 10:07:41 | -2.1 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-03-24 10:06:40 | -2.1 | [OK] Fresh |
| df_Dim_JobCode | 2026-03-24 10:06:10 | -2.1 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_Inventory | 2026-03-24 10:15:16 | -2.2 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-03-24 10:15:42 | -2.2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-03-24 10:14:40 | -2.2 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-03-24 10:10:14 | -2.2 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-03-24 10:20:58 | -2.3 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-03-24 10:22:01 | -2.3 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-03-24 10:16:12 | -2.3 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-03-24 10:21:59 | -2.3 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-03-24 10:21:27 | -2.3 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-03-24 10:17:11 | -2.3 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-03-24 10:25:43 | -2.4 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-03-24 10:25:43 | -2.4 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-03-24 10:27:13 | -2.4 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-03-24 10:25:46 | -2.4 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-03-24 10:22:28 | -2.4 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-03-24 10:26:18 | -2.4 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-03-24 10:23:03 | -2.4 | [OK] Fresh |
| df_Fact_Transfers | 2026-03-24 10:33:27 | -2.5 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-03-24 10:29:56 | -2.5 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-03-24 10:29:57 | -2.5 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-03-24 10:29:58 | -2.5 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-03-24 10:35:41 | -2.6 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-03-24 10:35:40 | -2.6 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-03-24 10:35:42 | -2.6 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-03-24 10:36:41 | -2.6 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_WKROFILE_Raw | 2026-03-24 09:20:20 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-03-24 09:17:50 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-03-24 09:21:50 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-03-24 09:21:51 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-03-24 09:23:50 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-03-24 09:27:50 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-03-24 09:23:20 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-03-24 09:30:32 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-03-24 09:30:32 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-03-24 09:31:01 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-03-24 09:31:01 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-03-24 09:31:02 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-03-24 09:32:03 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-03-24 09:35:50 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-03-24 09:35:20 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-03-24 09:34:49 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-03-24 09:34:49 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-03-24 09:34:20 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-03-24 09:45:51 | -1.7 | [OK] Fresh |
| df_VhTrans_Raw | 2026-03-24 09:48:35 | -1.8 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-03-24 09:49:06 | -1.8 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-03-24 09:50:26 | -1.8 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-03-24 09:48:06 | -1.8 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-03-24 09:48:36 | -1.8 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-03-24 09:48:36 | -1.8 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-03-24 09:53:17 | -1.9 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-03-24 09:53:17 | -1.9 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-03-24 09:52:47 | -1.9 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-03-24 09:53:21 | -1.9 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-03-24 09:53:20 | -1.9 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-03-24 09:53:17 | -1.9 | [OK] Fresh |
| df_WarClaim_Raw | 2026-03-24 09:53:19 | -1.9 | [OK] Fresh |
| df_Technician_Raw | 2026-03-24 09:53:47 | -1.9 | [OK] Fresh |
| df_CONTACT_Raw | 2026-03-24 09:53:17 | -1.9 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

