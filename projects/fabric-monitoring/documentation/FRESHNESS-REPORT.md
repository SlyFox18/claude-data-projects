# Data Freshness Report

**Generated:** 2026-05-21 08:01:41
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 81 | 83.5% |
| Stale | 0 | 0% |
| Critical | 4 | 4.1% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_GlMaster_Raw** (RawSource) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Last refreshed: 2026-05-06 15:04:38 (352.9 hours ago)
- **df_Dim_WkCodeFl** (Dimension) - Last refreshed: 2026-05-06 15:26:40 (352.6 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | 2026-05-06 15:04:38 | 352.9 | [CRIT] Critical |
| df_Dim_WkCodeFl | 2026-05-06 15:26:40 | 352.6 | [CRIT] Critical |
| df_Dim_BranchUserAccess | 2026-05-20 10:01:58 | 22 | [OK] Fresh |
| df_Dim_Date | 2026-05-21 10:07:20 | -2.1 | [OK] Fresh |
| df_Dim_Customer | 2026-05-21 10:07:52 | -2.1 | [OK] Fresh |
| df_Dim_Technicans | 2026-05-21 10:12:48 | -2.2 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-05-21 10:12:49 | -2.2 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-05-21 10:12:45 | -2.2 | [OK] Fresh |
| df_Dim_Part | 2026-05-21 10:10:25 | -2.2 | [OK] Fresh |
| df_Dim_JobCode | 2026-05-21 10:12:47 | -2.2 | [OK] Fresh |
| df_Dim_Salesperson | 2026-05-21 10:12:50 | -2.2 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-05-21 10:13:49 | -2.2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrders | 2026-05-20 12:50:41 | 19.2 | [OK] Fresh |
| df_Fact_OpenOrderParts | 2026-05-20 12:50:38 | 19.2 | [OK] Fresh |
| df_Fact_JobCodePartFrequency | 2026-05-20 12:54:14 | 19.1 | [OK] Fresh |
| df_Fact_JobCodeFrequency_Branch | 2026-05-20 12:55:53 | 19.1 | [OK] Fresh |
| df_Fact_ServiceTimeSheet_Audit | 2026-05-20 17:13:17 | 14.8 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-05-21 10:16:20 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-05-21 10:21:18 | -2.3 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-05-21 10:21:47 | -2.3 | [OK] Fresh |
| df_Fact_Inventory | 2026-05-21 10:20:48 | -2.3 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-05-21 10:19:51 | -2.3 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-05-21 10:21:48 | -2.3 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-05-21 10:26:30 | -2.4 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-05-21 10:25:32 | -2.4 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-05-21 10:25:30 | -2.4 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-05-21 10:25:59 | -2.4 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-05-21 10:26:29 | -2.4 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-05-21 10:33:11 | -2.5 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-05-21 10:36:23 | -2.6 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-05-21 10:35:55 | -2.6 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-05-21 10:36:23 | -2.6 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-05-21 10:39:07 | -2.6 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-05-21 10:38:35 | -2.6 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-05-21 10:39:06 | -2.6 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-05-21 10:39:07 | -2.6 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-05-21 10:39:06 | -2.6 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-05-21 10:35:23 | -2.6 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-05-21 10:35:23 | -2.6 | [OK] Fresh |
| df_Fact_Transfers | 2026-05-21 10:49:18 | -2.8 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-05-21 10:52:12 | -2.8 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-05-21 10:52:13 | -2.8 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-05-21 10:52:12 | -2.8 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-05-21 10:52:12 | -2.8 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-05-21 10:54:13 | -2.9 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-05-21 10:52:42 | -2.9 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-05-21 12:33:00 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-05-20 16:19:52 | 15.7 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-05-21 09:17:46 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-05-21 09:21:16 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-05-21 09:22:17 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-05-21 09:20:16 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-05-21 09:25:47 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-05-21 09:23:46 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-05-21 09:45:50 | -1.7 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-05-21 09:43:36 | -1.7 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-05-21 09:45:50 | -1.7 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-05-21 09:46:50 | -1.8 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-05-21 09:51:32 | -1.8 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-05-21 09:46:50 | -1.8 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-05-21 09:50:04 | -1.8 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-05-21 09:51:32 | -1.8 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-05-21 09:46:50 | -1.8 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-05-21 09:50:02 | -1.8 | [OK] Fresh |
| df_INSALORD_Raw | 2026-05-21 09:50:03 | -1.8 | [OK] Fresh |
| df_InMaster_Raw | 2026-05-21 09:47:51 | -1.8 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-05-21 09:50:02 | -1.8 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-05-21 09:56:17 | -1.9 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-05-21 09:54:16 | -1.9 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-05-21 09:58:37 | -1.9 | [OK] Fresh |
| df_VhTrans_Raw | 2026-05-21 09:54:16 | -1.9 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-05-21 09:53:46 | -1.9 | [OK] Fresh |
| df_Technician_Raw | 2026-05-21 09:58:36 | -1.9 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-05-21 09:54:16 | -1.9 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-05-21 09:53:46 | -1.9 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-05-21 09:54:16 | -1.9 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-05-21 09:59:06 | -2 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-05-21 09:59:07 | -2 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-05-21 09:59:06 | -2 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-05-21 09:58:37 | -2 | [OK] Fresh |
| df_WarClaim_Raw | 2026-05-21 09:59:08 | -2 | [OK] Fresh |
| df_CONTACT_Raw | 2026-05-21 09:59:07 | -2 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-05-21 09:59:06 | -2 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

