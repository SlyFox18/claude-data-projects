# Data Freshness Report

**Generated:** 2026-05-07 08:01:28
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 75 | 78.1% |
| Stale | 4 | 4.2% |
| Critical | 2 | 2.1% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_GlTrans_Full_Raw** (RawSource) - Last refreshed: 2026-04-16 01:32:30 (510.5 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-04-23 19:54:02 (324.1 hours ago)

---

## Stale - Monitor Closely

The following dataflows are approaching staleness:

- **df_ServiceTimeSheets_Raw** (RawSource) - Last refreshed: 2026-05-04 17:29:11 (62.5 hours ago)
- **df_Fact_OpenOrders** (FactTable) - Last refreshed: 2026-05-05 13:01:23 (43 hours ago)
- **df_Fact_OpenOrderParts** (FactTable) - Last refreshed: 2026-05-05 13:00:58 (43 hours ago)
- **df_Fact_JobCodePartFrequency** (FactTable) - Last refreshed: 2026-05-05 13:05:31 (42.9 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_BranchUserAccess | 2026-04-23 19:54:02 | 324.1 | [CRIT] Critical |
| df_Dim_WKCDPART | 2026-05-06 15:04:38 | 16.9 | [OK] Fresh |
| df_Dim_WkCodeFl | 2026-05-06 15:26:40 | 16.6 | [OK] Fresh |
| df_Dim_Part | 2026-05-07 10:15:51 | -2.2 | [OK] Fresh |
| df_Dim_Customer | 2026-05-07 10:13:21 | -2.2 | [OK] Fresh |
| df_Dim_Date | 2026-05-07 10:12:51 | -2.2 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-05-07 10:18:08 | -2.3 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-05-07 10:18:34 | -2.3 | [OK] Fresh |
| df_Dim_Technicans | 2026-05-07 10:18:05 | -2.3 | [OK] Fresh |
| df_Dim_JobCode | 2026-05-07 10:18:33 | -2.3 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-05-07 10:19:06 | -2.3 | [OK] Fresh |
| df_Dim_Salesperson | 2026-05-07 10:18:04 | -2.3 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrders | 2026-05-05 13:01:23 | 43 | [WARN] Stale |
| df_Fact_OpenOrderParts | 2026-05-05 13:00:58 | 43 | [WARN] Stale |
| df_Fact_JobCodePartFrequency | 2026-05-05 13:05:31 | 42.9 | [WARN] Stale |
| df_FactPartTransactions_Incremental | 2026-05-07 10:21:30 | -2.3 | [OK] Fresh |
| df_Fact_Inventory | 2026-05-07 10:26:02 | -2.4 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-05-07 10:27:30 | -2.4 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-05-07 10:25:00 | -2.4 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-05-07 10:27:00 | -2.4 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-05-07 10:26:00 | -2.4 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-05-07 10:32:14 | -2.5 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-05-07 10:31:10 | -2.5 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-05-07 10:31:12 | -2.5 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-05-07 10:32:41 | -2.5 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-05-07 10:32:12 | -2.5 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-05-07 10:31:41 | -2.5 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-05-07 10:35:26 | -2.6 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-05-07 10:36:24 | -2.6 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-05-07 10:39:07 | -2.6 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-05-07 10:35:25 | -2.6 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-05-07 10:38:37 | -2.6 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-05-07 10:38:37 | -2.6 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-05-07 10:34:56 | -2.6 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-05-07 10:35:25 | -2.6 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-05-07 10:45:23 | -2.7 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-05-07 10:45:21 | -2.7 | [OK] Fresh |
| df_Fact_Transfers | 2026-05-07 10:42:38 | -2.7 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-05-07 10:45:25 | -2.7 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-05-07 10:41:14 | -2.7 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-05-07 10:45:22 | -2.7 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-05-07 10:45:21 | -2.7 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-05-07 10:41:50 | -2.7 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-05-07 10:46:22 | -2.8 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | 2026-04-16 01:32:30 | 510.5 | [CRIT] Critical |
| df_ServiceTimeSheets_Raw | 2026-05-04 17:29:11 | 62.5 | [WARN] Stale |
| df_GlTrans_Raw | 2026-05-07 09:22:15 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-05-07 09:21:44 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-05-07 09:20:14 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-05-07 09:18:14 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-05-07 09:25:14 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-05-07 09:23:48 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-05-07 09:44:03 | -1.7 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-05-07 09:46:16 | -1.7 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-05-07 09:50:30 | -1.8 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-05-07 09:52:00 | -1.8 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-05-07 09:50:30 | -1.8 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-05-07 09:46:46 | -1.8 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-05-07 09:47:18 | -1.8 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-05-07 09:47:17 | -1.8 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-05-07 09:47:17 | -1.8 | [OK] Fresh |
| df_INSALORD_Raw | 2026-05-07 09:50:30 | -1.8 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-05-07 09:50:30 | -1.8 | [OK] Fresh |
| df_InMaster_Raw | 2026-05-07 09:48:17 | -1.8 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-05-07 09:52:30 | -1.9 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-05-07 09:56:13 | -1.9 | [OK] Fresh |
| df_VhTrans_Raw | 2026-05-07 09:55:13 | -1.9 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-05-07 09:55:14 | -1.9 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-05-07 09:55:13 | -1.9 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-05-07 09:54:42 | -1.9 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-05-07 09:58:22 | -1.9 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-05-07 09:55:13 | -1.9 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-05-07 10:01:35 | -2 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-05-07 10:01:06 | -2 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-05-07 10:02:39 | -2 | [OK] Fresh |
| df_Technician_Raw | 2026-05-07 10:00:36 | -2 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-05-07 10:01:06 | -2 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-05-07 10:01:06 | -2 | [OK] Fresh |
| df_WarClaim_Raw | 2026-05-07 10:00:35 | -2 | [OK] Fresh |
| df_CONTACT_Raw | 2026-05-07 10:00:36 | -2 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-05-07 10:00:39 | -2 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

