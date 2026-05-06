# Data Freshness Report

**Generated:** 2026-05-06 08:01:41
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 75 | 81.5% |
| Stale |  | 0% |
| Critical | 2 | 2.2% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_GlTrans_Full_Raw** (RawSource) - Last refreshed: 2026-04-16 01:32:30 (486.5 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-04-23 19:54:02 (300.1 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_BranchUserAccess | 2026-04-23 19:54:02 | 300.1 | [CRIT] Critical |
| df_Dim_Date | 2026-05-06 09:51:08 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-05-06 09:51:39 | -1.8 | [OK] Fresh |
| df_Dim_Salesperson | 2026-05-06 09:56:48 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-05-06 09:56:48 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-05-06 09:56:47 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-05-06 09:57:48 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-05-06 09:56:48 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-05-06 09:56:47 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-05-06 09:54:38 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrderParts | 2026-05-05 13:00:58 | 19 | [OK] Fresh |
| df_Fact_OpenOrders | 2026-05-05 13:01:23 | 19 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-05-06 10:04:09 | -2 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-05-06 10:00:09 | -2 | [OK] Fresh |
| df_Fact_Inventory | 2026-05-06 10:05:09 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-05-06 10:05:40 | -2.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-05-06 10:05:40 | -2.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-05-06 10:06:41 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-05-06 10:10:33 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-05-06 10:12:04 | -2.2 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-05-06 10:11:08 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-05-06 10:14:50 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-05-06 10:14:18 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-05-06 10:15:19 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-05-06 10:14:51 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-05-06 10:15:18 | -2.2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-05-06 10:11:39 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-05-06 10:11:00 | -2.2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-05-06 10:11:28 | -2.2 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-05-06 10:18:03 | -2.3 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-05-06 10:18:06 | -2.3 | [OK] Fresh |
| df_Fact_Transfers | 2026-05-06 10:21:34 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-05-06 10:17:34 | -2.3 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-05-06 10:18:03 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-05-06 10:18:03 | -2.3 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-05-06 10:24:17 | -2.4 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-05-06 10:24:18 | -2.4 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-05-06 10:24:47 | -2.4 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-05-06 10:23:50 | -2.4 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-05-06 10:24:17 | -2.4 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-05-06 10:24:19 | -2.4 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | 2026-04-16 01:32:30 | 486.5 | [CRIT] Critical |
| df_ServiceTimeSheets_Raw | 2026-05-04 17:29:11 | 38.5 | [WARN] Stale |
| df_WKROFILE_Raw | 2026-05-06 09:20:16 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-05-06 09:17:46 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-05-06 09:21:46 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-05-06 09:23:46 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-05-06 09:23:46 | -1.4 | [OK] Fresh |
| df_GlTrans_Raw | 2026-05-06 09:23:16 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-05-06 09:28:46 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-05-06 09:32:03 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-05-06 09:31:32 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-05-06 09:31:31 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-05-06 09:31:31 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-05-06 09:31:00 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-05-06 09:33:00 | -1.5 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-05-06 09:35:40 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-05-06 09:36:41 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-05-06 09:37:08 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-05-06 09:40:26 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-05-06 09:40:26 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-05-06 09:35:11 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-05-06 09:35:10 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-05-06 09:34:41 | -1.6 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-05-06 09:44:10 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-05-06 09:44:41 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-05-06 09:44:10 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-05-06 09:45:10 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-05-06 09:44:09 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-05-06 09:44:09 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-05-06 09:44:10 | -1.7 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-05-06 09:40:55 | -1.7 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-05-06 09:40:55 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-05-06 09:44:39 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-05-06 09:41:56 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-05-06 09:44:40 | -1.7 | [OK] Fresh |
| df_VhTrans_Raw | 2026-05-06 09:40:55 | -1.7 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-05-06 09:40:56 | -1.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

