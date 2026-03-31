# Data Freshness Report

**Generated:** 2026-03-31 08:01:16
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
| df_Dim_Customer | 2026-03-31 09:51:18 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-03-31 09:50:17 | -1.8 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-03-31 09:56:42 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-03-31 09:55:39 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-03-31 09:55:41 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-03-31 09:55:40 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-03-31 09:56:09 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-03-31 09:53:29 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_Parts_Details | 2026-03-31 10:04:03 | -2 | [OK] Fresh |
| df_Fact_Inventory | 2026-03-31 10:03:35 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-03-31 10:03:04 | -2 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-03-31 09:59:02 | -2 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-03-31 10:06:03 | -2.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-03-31 10:04:32 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-03-31 10:09:50 | -2.1 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-03-31 10:14:07 | -2.2 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-03-31 10:10:32 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-03-31 10:14:07 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-03-31 10:13:37 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-03-31 10:15:06 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-03-31 10:11:21 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-03-31 10:11:20 | -2.2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-03-31 10:10:48 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-03-31 10:14:37 | -2.2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-03-31 10:10:50 | -2.2 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-03-31 10:17:55 | -2.3 | [OK] Fresh |
| df_Fact_Transfers | 2026-03-31 10:21:19 | -2.3 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-03-31 10:17:56 | -2.3 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-03-31 10:17:55 | -2.3 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-03-31 10:23:34 | -2.4 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-03-31 10:23:35 | -2.4 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-03-31 10:24:03 | -2.4 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-03-31 10:24:04 | -2.4 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-03-31 10:25:04 | -2.4 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_JDIS_PART_INFORMATION_Raw | Error | 0 | [?] Error |
| df_InHist_PmManage_Raw | 2026-03-31 09:21:50 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-03-31 09:21:44 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-03-31 09:19:14 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-03-31 09:20:14 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-03-31 09:23:44 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-03-31 09:23:15 | -1.4 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-03-31 09:32:05 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-03-31 09:30:28 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-03-31 09:31:28 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-03-31 09:31:27 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-03-31 09:31:27 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-03-31 09:32:27 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-03-31 09:36:16 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-03-31 09:36:14 | -1.6 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-03-31 09:40:06 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-03-31 09:40:06 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-03-31 09:40:08 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-03-31 09:35:14 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-03-31 09:35:14 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-03-31 09:37:22 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-03-31 09:39:38 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-03-31 09:40:06 | -1.6 | [OK] Fresh |
| df_WarClaim_Raw | 2026-03-31 09:44:26 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-03-31 09:44:26 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-03-31 09:44:27 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-03-31 09:44:26 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-03-31 09:44:26 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-03-31 09:44:26 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-03-31 09:44:26 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-03-31 09:44:27 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-03-31 09:41:39 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-03-31 09:44:30 | -1.7 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-03-31 12:55:34 | -4.9 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

