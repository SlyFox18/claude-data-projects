# Data Freshness Report

**Generated:** 2026-03-30 08:01:21
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 68 | 85% |
| Stale | 0 | 0% |
| Critical | 0 | 0% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_Customer | 2026-03-30 09:50:57 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-03-30 09:50:31 | -1.8 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-03-30 09:56:39 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-03-30 09:55:09 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-03-30 09:55:09 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-03-30 09:55:39 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-03-30 09:55:39 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-03-30 09:52:57 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_Parts_Details | 2026-03-30 10:04:06 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-03-30 10:03:05 | -2 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-03-30 09:59:05 | -2 | [OK] Fresh |
| df_Fact_Inventory | 2026-03-30 10:04:35 | -2.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-03-30 10:06:05 | -2.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-03-30 10:07:06 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-03-30 10:12:20 | -2.2 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-03-30 10:10:50 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-03-30 10:15:35 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-03-30 10:15:36 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-03-30 10:16:08 | -2.2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-03-30 10:11:49 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-03-30 10:11:21 | -2.2 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-03-30 10:12:49 | -2.2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-03-30 10:12:51 | -2.2 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-03-30 10:19:45 | -2.3 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-03-30 10:19:48 | -2.3 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-03-30 10:19:45 | -2.3 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-03-30 10:17:04 | -2.3 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-03-30 10:16:36 | -2.3 | [OK] Fresh |
| df_Fact_Transfers | 2026-03-30 10:23:47 | -2.4 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-03-30 10:26:29 | -2.4 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-03-30 10:27:00 | -2.4 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-03-30 10:26:31 | -2.4 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-03-30 10:26:01 | -2.4 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-03-30 10:26:30 | -2.4 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_WKROFILE_Raw | 2026-03-30 09:20:14 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-03-30 09:17:53 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-03-30 09:21:44 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-03-30 09:21:44 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-03-30 09:23:14 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-03-30 09:23:44 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-03-30 09:28:44 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-03-30 09:31:26 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-03-30 09:31:26 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-03-30 09:32:26 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-03-30 09:32:26 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-03-30 09:33:26 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-03-30 09:32:26 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-03-30 09:37:06 | -1.6 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-03-30 09:39:48 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-03-30 09:37:06 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-03-30 09:39:48 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-03-30 09:39:49 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-03-30 09:36:06 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-03-30 09:36:06 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-03-30 09:35:37 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-03-30 09:35:36 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-03-30 09:39:49 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-03-30 09:39:19 | -1.6 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-03-30 09:44:02 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-03-30 09:43:33 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-03-30 09:43:00 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-03-30 09:43:02 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-03-30 09:43:32 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-03-30 09:43:30 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-03-30 09:43:02 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-03-30 09:40:48 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-03-30 09:43:32 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-03-30 09:43:32 | -1.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

