# Data Freshness Report

**Generated:** 2026-05-13 08:01:35
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 74 | 76.3% |
| Stale | 0 | 0% |
| Critical | 9 | 9.3% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_GlTrans_Full_Raw** (RawSource) - Last refreshed: 2026-04-16 01:32:30 (654.5 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-04-23 19:54:02 (468.1 hours ago)
- **df_ServiceTimeSheets_Raw** (RawSource) - Last refreshed: 2026-05-04 17:29:11 (206.5 hours ago)
- **df_Fact_OpenOrders** (FactTable) - Last refreshed: 2026-05-05 13:01:23 (187 hours ago)
- **df_Fact_OpenOrderParts** (FactTable) - Last refreshed: 2026-05-05 13:00:58 (187 hours ago)
- **df_Dim_WKCDPART** (Dimension) - Last refreshed: 2026-05-06 15:04:38 (160.9 hours ago)
- **df_Dim_WkCodeFl** (Dimension) - Last refreshed: 2026-05-06 15:26:40 (160.6 hours ago)
- **df_Fact_JobCodePartFrequency** (FactTable) - Last refreshed: 2026-05-07 13:25:40 (138.6 hours ago)
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Last refreshed: 2026-05-07 13:25:51 (138.6 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_BranchUserAccess | 2026-04-23 19:54:02 | 468.1 | [CRIT] Critical |
| df_Dim_WKCDPART | 2026-05-06 15:04:38 | 160.9 | [CRIT] Critical |
| df_Dim_WkCodeFl | 2026-05-06 15:26:40 | 160.6 | [CRIT] Critical |
| df_Dim_Date | 2026-05-13 10:03:49 | -2 | [OK] Fresh |
| df_Dim_Technicans | 2026-05-13 10:07:40 | -2.1 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-05-13 10:07:39 | -2.1 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-05-13 10:08:06 | -2.1 | [OK] Fresh |
| df_Dim_Salesperson | 2026-05-13 10:08:37 | -2.1 | [OK] Fresh |
| df_Dim_JobCode | 2026-05-13 10:10:06 | -2.1 | [OK] Fresh |
| df_Dim_Customer | 2026-05-13 10:04:49 | -2.1 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-05-13 10:09:37 | -2.1 | [OK] Fresh |
| df_Dim_Part | 2026-05-13 10:05:47 | -2.1 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrderParts | 2026-05-05 13:00:58 | 187 | [CRIT] Critical |
| df_Fact_OpenOrders | 2026-05-05 13:01:23 | 187 | [CRIT] Critical |
| df_Fact_JobCodeFrequency_Branch | 2026-05-07 13:25:51 | 138.6 | [CRIT] Critical |
| df_Fact_JobCodePartFrequency | 2026-05-07 13:25:40 | 138.6 | [CRIT] Critical |
| df_Fact_InternalWorkOrders | 2026-05-12 13:07:07 | 18.9 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-05-13 10:12:34 | -2.2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-05-13 10:16:05 | -2.2 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-05-13 10:17:34 | -2.3 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-05-13 10:17:35 | -2.3 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-05-13 10:22:18 | -2.3 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-05-13 10:22:16 | -2.3 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-05-13 10:17:35 | -2.3 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-05-13 10:21:18 | -2.3 | [OK] Fresh |
| df_Fact_Inventory | 2026-05-13 10:17:07 | -2.3 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-05-13 10:21:48 | -2.3 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-05-13 10:21:16 | -2.3 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-05-13 10:25:31 | -2.4 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-05-13 10:26:01 | -2.4 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-05-13 10:26:33 | -2.4 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-05-13 10:23:16 | -2.4 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-05-13 10:26:01 | -2.4 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-05-13 10:25:31 | -2.4 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-05-13 10:29:15 | -2.5 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-05-13 10:29:15 | -2.5 | [OK] Fresh |
| df_Fact_Transfers | 2026-05-13 10:33:16 | -2.5 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-05-13 10:28:45 | -2.5 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-05-13 10:29:16 | -2.5 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-05-13 10:29:15 | -2.5 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-05-13 10:36:50 | -2.6 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-05-13 10:37:30 | -2.6 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-05-13 10:36:30 | -2.6 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-05-13 10:35:30 | -2.6 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-05-13 10:37:00 | -2.6 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-05-13 10:35:33 | -2.6 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | 2026-04-16 01:32:30 | 654.5 | [CRIT] Critical |
| df_ServiceTimeSheets_Raw | 2026-05-04 17:29:11 | 206.5 | [CRIT] Critical |
| df_InHist_PmManage_Raw | 2026-05-13 09:21:15 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-05-13 09:19:45 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-05-13 09:17:45 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-05-13 09:21:45 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-05-13 09:23:45 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-05-13 09:25:45 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-05-13 09:42:10 | -1.7 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-05-13 09:45:24 | -1.7 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-05-13 09:45:01 | -1.7 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-05-13 09:44:24 | -1.7 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-05-13 09:44:24 | -1.7 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-05-13 09:44:53 | -1.7 | [OK] Fresh |
| df_InMaster_Raw | 2026-05-13 09:46:24 | -1.7 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-05-13 09:52:21 | -1.8 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-05-13 09:49:38 | -1.8 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-05-13 09:49:37 | -1.8 | [OK] Fresh |
| df_VhTrans_Raw | 2026-05-13 09:52:21 | -1.8 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-05-13 09:52:20 | -1.8 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-05-13 09:48:38 | -1.8 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-05-13 09:52:20 | -1.8 | [OK] Fresh |
| df_INSALORD_Raw | 2026-05-13 09:48:37 | -1.8 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-05-13 09:52:24 | -1.8 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-05-13 09:48:38 | -1.8 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-05-13 09:49:08 | -1.8 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-05-13 09:51:50 | -1.8 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-05-13 09:56:33 | -1.9 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-05-13 09:56:34 | -1.9 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-05-13 09:56:33 | -1.9 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-05-13 09:56:33 | -1.9 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-05-13 09:56:34 | -1.9 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-05-13 09:53:50 | -1.9 | [OK] Fresh |
| df_Technician_Raw | 2026-05-13 09:56:34 | -1.9 | [OK] Fresh |
| df_WarClaim_Raw | 2026-05-13 09:56:34 | -1.9 | [OK] Fresh |
| df_CONTACT_Raw | 2026-05-13 09:56:33 | -1.9 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-05-13 09:56:34 | -1.9 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

