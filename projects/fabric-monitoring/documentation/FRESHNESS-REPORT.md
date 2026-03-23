# Data Freshness Report

**Generated:** 2026-03-23 14:54:17
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 66 | 83.5% |
| Stale | 0 | 0% |
| Critical | 0 | 0% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_Part | 2026-03-23 09:54:13 | 5 | [OK] Fresh |
| df_Dim_Technicans | 2026-03-23 09:56:23 | 5 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-03-23 09:56:23 | 5 | [OK] Fresh |
| df_Dim_JobCode | 2026-03-23 09:56:53 | 5 | [OK] Fresh |
| df_Dim_Customer | 2026-03-23 09:51:43 | 5 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-03-23 09:56:53 | 5 | [OK] Fresh |
| df_Dim_Date | 2026-03-23 09:51:15 | 5 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-03-23 15:58:44 | -1.1 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_FactPartTransactions_Incremental | 2026-03-23 09:59:49 | 4.9 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-03-23 10:03:48 | 4.8 | [OK] Fresh |
| df_Fact_Inventory | 2026-03-23 10:04:51 | 4.8 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-03-23 10:04:49 | 4.8 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-03-23 10:07:50 | 4.8 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-03-23 10:05:17 | 4.8 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-03-23 10:12:39 | 4.7 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-03-23 10:13:10 | 4.7 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-03-23 10:12:07 | 4.7 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-03-23 10:12:39 | 4.7 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-03-23 10:11:38 | 4.7 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-03-23 10:12:14 | 4.7 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-03-23 10:15:59 | 4.6 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-03-23 10:19:37 | 4.6 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-03-23 10:19:37 | 4.6 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-03-23 10:15:56 | 4.6 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-03-23 10:16:23 | 4.6 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-03-23 10:19:36 | 4.6 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-03-23 10:15:53 | 4.6 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-03-23 10:25:25 | 4.5 | [OK] Fresh |
| df_Fact_Transfers | 2026-03-23 10:23:10 | 4.5 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-03-23 10:26:25 | 4.5 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-03-23 10:25:25 | 4.5 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-03-23 10:25:24 | 4.5 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-03-23 16:18:33 | -1.4 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_WKROFILE_Raw | 2026-03-23 09:20:15 | 5.6 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-03-23 09:17:45 | 5.6 | [OK] Fresh |
| df_Invoice_Raw | 2026-03-23 09:23:15 | 5.5 | [OK] Fresh |
| df_GlTrans_Raw | 2026-03-23 09:21:45 | 5.5 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-03-23 09:23:15 | 5.5 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-03-23 09:21:15 | 5.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-03-23 09:30:28 | 5.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-03-23 09:30:29 | 5.4 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-03-23 09:30:58 | 5.4 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-03-23 09:31:28 | 5.4 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-03-23 09:30:58 | 5.4 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-03-23 09:37:39 | 5.3 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-03-23 09:35:08 | 5.3 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-03-23 09:34:09 | 5.3 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-03-23 09:34:08 | 5.3 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-03-23 09:34:38 | 5.3 | [OK] Fresh |
| df_INSALORD_Raw | 2026-03-23 09:34:07 | 5.3 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-03-23 09:44:33 | 5.2 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-03-23 09:44:33 | 5.2 | [OK] Fresh |
| df_WarClaim_Raw | 2026-03-23 09:44:33 | 5.2 | [OK] Fresh |
| df_VhTrans_Raw | 2026-03-23 09:40:20 | 5.2 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-03-23 09:40:51 | 5.2 | [OK] Fresh |
| df_CONTACT_Raw | 2026-03-23 09:44:33 | 5.2 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-03-23 09:44:33 | 5.2 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-03-23 09:44:33 | 5.2 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-03-23 09:44:33 | 5.2 | [OK] Fresh |
| df_Technician_Raw | 2026-03-23 09:44:33 | 5.2 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-03-23 09:40:21 | 5.2 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-03-23 09:41:50 | 5.2 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-03-23 09:39:50 | 5.2 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-03-23 09:40:21 | 5.2 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-03-23 09:45:03 | 5.1 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-03-23 16:14:20 | -1.3 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

