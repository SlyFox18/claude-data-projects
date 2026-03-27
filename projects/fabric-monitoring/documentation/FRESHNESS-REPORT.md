# Data Freshness Report

**Generated:** 2026-03-27 08:01:20
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
| df_Dim_Customer | 2026-03-27 09:50:46 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-03-27 09:50:16 | -1.8 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-03-27 09:55:56 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-03-27 09:54:56 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-03-27 09:55:00 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-03-27 09:55:26 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-03-27 09:55:26 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-03-27 09:52:47 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_Planter_Inspection_Part_Sales | 2026-03-26 20:53:12 | 11.1 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-03-27 10:02:23 | -2 | [OK] Fresh |
| df_Fact_Inventory | 2026-03-27 10:02:52 | -2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-03-27 10:03:23 | -2 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-03-27 09:58:22 | -2 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-03-27 10:04:22 | -2.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-03-27 10:06:23 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-03-27 10:10:08 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-03-27 10:12:09 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-03-27 10:14:57 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-03-27 10:14:56 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-03-27 10:14:57 | -2.2 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-03-27 10:10:39 | -2.2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-03-27 10:11:08 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-03-27 10:10:40 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-03-27 10:15:25 | -2.2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-03-27 10:11:11 | -2.2 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-03-27 10:19:10 | -2.3 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-03-27 10:19:11 | -2.3 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-03-27 10:19:10 | -2.3 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-03-27 10:16:27 | -2.3 | [OK] Fresh |
| df_Fact_Transfers | 2026-03-27 10:22:39 | -2.4 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-03-27 10:24:51 | -2.4 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-03-27 10:25:55 | -2.4 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-03-27 10:25:22 | -2.4 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-03-27 10:26:22 | -2.4 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Raw | 2026-03-27 09:21:44 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-03-27 09:17:44 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-03-27 09:20:14 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-03-27 09:21:14 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-03-27 09:23:44 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-03-27 09:23:44 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-03-27 09:28:14 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-03-27 09:30:59 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-03-27 09:30:58 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-03-27 09:31:30 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-03-27 09:31:28 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-03-27 09:32:29 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-03-27 09:31:59 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-03-27 09:36:10 | -1.6 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-03-27 09:39:25 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-03-27 09:36:41 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-03-27 09:39:24 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-03-27 09:39:23 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-03-27 09:35:12 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-03-27 09:35:10 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-03-27 09:35:10 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-03-27 09:34:40 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-03-27 09:39:24 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-03-27 09:38:54 | -1.6 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-03-27 09:44:08 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-03-27 09:43:37 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-03-27 09:43:37 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-03-27 09:43:07 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-03-27 09:44:07 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-03-27 09:43:38 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-03-27 09:43:10 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-03-27 09:40:56 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-03-27 09:43:38 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-03-27 09:43:39 | -1.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

