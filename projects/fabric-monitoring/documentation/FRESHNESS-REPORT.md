# Data Freshness Report

**Generated:** 2026-05-26 08:01:23
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 75 | 77.3% |
| Stale | 0 | 0% |
| Critical | 10 | 10.3% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_GlMaster_Raw** (RawSource) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Last refreshed: 2026-05-06 15:04:38 (472.9 hours ago)
- **df_Dim_WkCodeFl** (Dimension) - Last refreshed: 2026-05-06 15:26:40 (472.6 hours ago)
- **df_Fact_OpenOrders** (FactTable) - Last refreshed: 2026-05-20 12:50:41 (139.2 hours ago)
- **df_Fact_OpenOrderParts** (FactTable) - Last refreshed: 2026-05-20 12:50:38 (139.2 hours ago)
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Last refreshed: 2026-05-20 12:55:53 (139.1 hours ago)
- **df_Fact_JobCodePartFrequency** (FactTable) - Last refreshed: 2026-05-20 12:54:14 (139.1 hours ago)
- **df_ServiceTimeSheets_Raw** (RawSource) - Last refreshed: 2026-05-20 16:19:52 (135.7 hours ago)
- **df_Fact_ServiceTimeSheet_Audit** (FactTable) - Last refreshed: 2026-05-22 19:21:07 (84.7 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | 2026-05-06 15:04:38 | 472.9 | [CRIT] Critical |
| df_Dim_WkCodeFl | 2026-05-06 15:26:40 | 472.6 | [CRIT] Critical |
| df_Dim_Date | 2026-05-26 09:49:58 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-05-26 09:51:01 | -1.8 | [OK] Fresh |
| df_Dim_Technicans | 2026-05-26 09:55:11 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-05-26 09:55:11 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-05-26 09:55:11 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-05-26 09:55:11 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-05-26 09:55:11 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-05-26 09:52:59 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-05-26 09:56:11 | -1.9 | [OK] Fresh |
| df_Dim_BranchUserAccess | 2026-05-26 10:02:02 | -2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrders | 2026-05-20 12:50:41 | 139.2 | [CRIT] Critical |
| df_Fact_OpenOrderParts | 2026-05-20 12:50:38 | 139.2 | [CRIT] Critical |
| df_Fact_JobCodeFrequency_Branch | 2026-05-20 12:55:53 | 139.1 | [CRIT] Critical |
| df_Fact_JobCodePartFrequency | 2026-05-20 12:54:14 | 139.1 | [CRIT] Critical |
| df_Fact_ServiceTimeSheet_Audit | 2026-05-22 19:21:07 | 84.7 | [CRIT] Critical |
| df_Fact_WorkOrderParts | 2026-05-26 10:04:14 | -2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-05-26 10:03:45 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-05-26 10:02:15 | -2 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-05-26 09:58:44 | -2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-05-26 10:10:00 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-05-26 10:09:57 | -2.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-05-26 10:05:15 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-05-26 10:09:00 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-05-26 10:08:58 | -2.1 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-05-26 10:09:29 | -2.1 | [OK] Fresh |
| df_Fact_Inventory | 2026-05-26 10:04:45 | -2.1 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-05-26 10:15:27 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-05-26 10:15:00 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-05-26 10:15:56 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-05-26 10:15:27 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-05-26 10:15:58 | -2.2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-05-26 10:12:43 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-05-26 10:18:11 | -2.3 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-05-26 10:18:11 | -2.3 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-05-26 10:18:13 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-05-26 10:18:41 | -2.3 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-05-26 10:18:41 | -2.3 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-05-26 10:25:56 | -2.4 | [OK] Fresh |
| df_Fact_Transfers | 2026-05-26 10:22:41 | -2.4 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-05-26 10:25:26 | -2.4 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-05-26 10:25:27 | -2.4 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-05-26 10:25:26 | -2.4 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-05-26 10:25:37 | -2.4 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-05-26 10:25:26 | -2.4 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-05-26 12:33:28 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-05-20 16:19:52 | 135.7 | [CRIT] Critical |
| df_Parts_InterbranchTransfer_Raw | 2026-05-26 09:17:44 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-05-26 09:20:14 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-05-26 09:21:44 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-05-26 09:24:13 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-05-26 09:27:44 | -1.4 | [OK] Fresh |
| df_GlTrans_Raw | 2026-05-26 09:22:43 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-05-26 09:24:44 | -1.4 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-05-26 09:30:55 | -1.5 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-05-26 09:34:12 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-05-26 09:31:26 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-05-26 09:30:25 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-05-26 09:29:55 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-05-26 09:30:55 | -1.5 | [OK] Fresh |
| df_INSALORD_Raw | 2026-05-26 09:34:10 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-05-26 09:31:55 | -1.5 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-05-26 09:34:10 | -1.5 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-05-26 09:34:09 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-05-26 09:39:56 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-05-26 09:35:09 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-05-26 09:38:55 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-05-26 09:38:56 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-05-26 09:36:12 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-05-26 09:38:26 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-05-26 09:38:26 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-05-26 09:38:56 | -1.6 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-05-26 09:38:56 | -1.6 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-05-26 09:42:38 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-05-26 09:42:39 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-05-26 09:42:39 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-05-26 09:42:39 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-05-26 09:43:38 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-05-26 09:42:39 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-05-26 09:42:08 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-05-26 09:42:08 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-05-26 09:42:08 | -1.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

