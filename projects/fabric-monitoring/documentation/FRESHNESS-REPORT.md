# Data Freshness Report

**Generated:** 2026-05-25 08:01:24
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 74 | 76.3% |
| Stale |  | 0% |
| Critical | 10 | 10.3% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_GlMaster_Raw** (RawSource) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Last refreshed: 2026-05-06 15:04:38 (448.9 hours ago)
- **df_Dim_WkCodeFl** (Dimension) - Last refreshed: 2026-05-06 15:26:40 (448.6 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-05-20 10:01:58 (118 hours ago)
- **df_Fact_OpenOrders** (FactTable) - Last refreshed: 2026-05-20 12:50:41 (115.2 hours ago)
- **df_Fact_OpenOrderParts** (FactTable) - Last refreshed: 2026-05-20 12:50:38 (115.2 hours ago)
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Last refreshed: 2026-05-20 12:55:53 (115.1 hours ago)
- **df_Fact_JobCodePartFrequency** (FactTable) - Last refreshed: 2026-05-20 12:54:14 (115.1 hours ago)
- **df_ServiceTimeSheets_Raw** (RawSource) - Last refreshed: 2026-05-20 16:19:52 (111.7 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | 2026-05-06 15:04:38 | 448.9 | [CRIT] Critical |
| df_Dim_WkCodeFl | 2026-05-06 15:26:40 | 448.6 | [CRIT] Critical |
| df_Dim_BranchUserAccess | 2026-05-20 10:01:58 | 118 | [CRIT] Critical |
| df_Dim_Part | 2026-05-25 10:07:56 | -2.1 | [OK] Fresh |
| df_Dim_Customer | 2026-05-25 10:05:17 | -2.1 | [OK] Fresh |
| df_Dim_Date | 2026-05-25 10:04:46 | -2.1 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-05-25 10:10:21 | -2.2 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-05-25 10:10:22 | -2.2 | [OK] Fresh |
| df_Dim_Technicans | 2026-05-25 10:10:21 | -2.2 | [OK] Fresh |
| df_Dim_JobCode | 2026-05-25 10:10:22 | -2.2 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-05-25 10:11:30 | -2.2 | [OK] Fresh |
| df_Dim_Salesperson | 2026-05-25 10:10:26 | -2.2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrders | 2026-05-20 12:50:41 | 115.2 | [CRIT] Critical |
| df_Fact_OpenOrderParts | 2026-05-20 12:50:38 | 115.2 | [CRIT] Critical |
| df_Fact_JobCodePartFrequency | 2026-05-20 12:54:14 | 115.1 | [CRIT] Critical |
| df_Fact_JobCodeFrequency_Branch | 2026-05-20 12:55:53 | 115.1 | [CRIT] Critical |
| df_Fact_ServiceTimeSheet_Audit | 2026-05-22 19:21:07 | 60.7 | [WARN] Stale |
| df_FactPartTransactions_Incremental | 2026-05-25 10:14:08 | -2.2 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-05-25 10:19:38 | -2.3 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-05-25 10:20:10 | -2.3 | [OK] Fresh |
| df_Fact_Inventory | 2026-05-25 10:18:48 | -2.3 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-05-25 10:17:39 | -2.3 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-05-25 10:20:08 | -2.3 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-05-25 10:25:27 | -2.4 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-05-25 10:25:27 | -2.4 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-05-25 10:28:08 | -2.4 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-05-25 10:23:54 | -2.4 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-05-25 10:27:38 | -2.4 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-05-25 10:28:09 | -2.4 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-05-25 10:24:25 | -2.4 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-05-25 10:24:55 | -2.4 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-05-25 10:24:54 | -2.4 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-05-25 10:28:38 | -2.5 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-05-25 10:32:19 | -2.5 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-05-25 10:31:50 | -2.5 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-05-25 10:29:08 | -2.5 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-05-25 10:31:49 | -2.5 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-05-25 10:31:50 | -2.5 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-05-25 10:32:20 | -2.5 | [OK] Fresh |
| df_Fact_Transfers | 2026-05-25 10:35:49 | -2.6 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-05-25 10:39:05 | -2.6 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-05-25 10:38:36 | -2.6 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-05-25 10:38:35 | -2.6 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-05-25 10:39:35 | -2.6 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-05-25 10:38:35 | -2.6 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-05-25 10:38:35 | -2.6 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-05-25 12:33:29 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-05-20 16:19:52 | 111.7 | [CRIT] Critical |
| df_InHist_PmManage_Raw | 2026-05-25 09:22:02 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-05-25 09:20:47 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-05-25 09:22:03 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-05-25 09:24:53 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-05-25 09:25:01 | -1.4 | [OK] Fresh |
| df_GlTrans_Raw | 2026-05-25 09:22:47 | -1.4 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-05-25 09:45:55 | -1.7 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-05-25 09:45:56 | -1.7 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-05-25 09:44:58 | -1.7 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-05-25 09:42:44 | -1.7 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-05-25 09:45:56 | -1.7 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-05-25 09:44:56 | -1.7 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-05-25 09:50:38 | -1.8 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-05-25 09:49:08 | -1.8 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-05-25 09:50:08 | -1.8 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-05-25 09:49:07 | -1.8 | [OK] Fresh |
| df_INSALORD_Raw | 2026-05-25 09:49:07 | -1.8 | [OK] Fresh |
| df_InMaster_Raw | 2026-05-25 09:46:58 | -1.8 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-05-25 09:49:07 | -1.8 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-05-25 09:57:05 | -1.9 | [OK] Fresh |
| df_CONTACT_Raw | 2026-05-25 09:56:34 | -1.9 | [OK] Fresh |
| df_WarClaim_Raw | 2026-05-25 09:56:35 | -1.9 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-05-25 09:56:34 | -1.9 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-05-25 09:57:34 | -1.9 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-05-25 09:57:06 | -1.9 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-05-25 09:56:34 | -1.9 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-05-25 09:56:34 | -1.9 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-05-25 09:53:22 | -1.9 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-05-25 09:53:25 | -1.9 | [OK] Fresh |
| df_Technician_Raw | 2026-05-25 09:57:04 | -1.9 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-05-25 09:52:50 | -1.9 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-05-25 09:53:20 | -1.9 | [OK] Fresh |
| df_VhTrans_Raw | 2026-05-25 09:53:21 | -1.9 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-05-25 09:52:51 | -1.9 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-05-25 09:54:21 | -1.9 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

