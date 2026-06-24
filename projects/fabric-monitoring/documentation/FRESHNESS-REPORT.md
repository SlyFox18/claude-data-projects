# Data Freshness Report

**Generated:** 2026-06-24 08:01:38
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 79 | 79% |
| Stale | 0 | 0% |
| Critical | 9 | 9% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_GlMaster_Raw** (RawSource) - Never refreshed!
- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Never refreshed!
- **df_Fact_JobCodePartFrequency** (FactTable) - Never refreshed!
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Never refreshed!
- **df_Dim_WkCodeFl** (Dimension) - Never refreshed!
- **df_Dim_Franchise** (Dimension) - Last refreshed: 2026-06-01 12:33:08 (547.5 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_Franchise | 2026-06-01 12:33:08 | 547.5 | [CRIT] Critical |
| df_Dim_Part | 2026-06-23 09:51:07 | 22.2 | [OK] Fresh |
| df_Dim_Customer | 2026-06-23 09:49:07 | 22.2 | [OK] Fresh |
| df_Dim_Date | 2026-06-23 09:48:37 | 22.2 | [OK] Fresh |
| df_Dim_Technicans | 2026-06-23 09:52:47 | 22.1 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-06-23 09:52:47 | 22.1 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-06-23 09:53:18 | 22.1 | [OK] Fresh |
| df_Dim_JobCode | 2026-06-23 09:53:17 | 22.1 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-06-23 09:54:18 | 22.1 | [OK] Fresh |
| df_Dim_Salesperson | 2026-06-23 09:52:47 | 22.1 | [OK] Fresh |
| df_Dim_BranchUserAccess | 2026-06-24 10:01:59 | -2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_FactPartTransactions_Incremental | 2026-06-23 09:56:10 | 22.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-06-23 10:01:41 | 22 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-06-23 10:02:41 | 22 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-06-23 10:00:11 | 22 | [OK] Fresh |
| df_Fact_Inventory | 2026-06-23 10:01:11 | 22 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-06-23 10:01:41 | 22 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-06-23 10:09:51 | 21.9 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-06-23 10:06:37 | 21.9 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-06-23 10:07:34 | 21.9 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-06-23 10:06:35 | 21.9 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-06-23 10:10:20 | 21.9 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-06-23 10:08:08 | 21.9 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-06-23 10:07:05 | 21.9 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-06-23 10:07:33 | 21.9 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-06-23 10:10:50 | 21.8 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-06-23 10:11:21 | 21.8 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-06-23 10:13:44 | 21.8 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-06-23 10:14:24 | 21.8 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-06-23 10:14:07 | 21.8 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-06-23 10:13:36 | 21.8 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-06-23 10:13:35 | 21.8 | [OK] Fresh |
| df_Fact_Transfers | 2026-06-23 10:18:05 | 21.7 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-06-23 10:20:21 | 21.7 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-06-23 10:20:53 | 21.7 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-06-23 10:20:22 | 21.7 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-06-23 10:20:22 | 21.7 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-06-23 10:20:22 | 21.7 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-06-23 10:20:24 | 21.7 | [OK] Fresh |
| df_Fact_ServiceTimeSheet_Audit | 2026-06-23 14:19:27 | 17.7 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-06-23 16:18:27 | 15.7 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-06-24 12:32:57 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_WKINVREG_Raw | 2026-06-23 09:30:57 | 22.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-06-23 09:32:56 | 22.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-06-23 09:31:55 | 22.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-06-23 09:30:56 | 22.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-06-23 09:31:56 | 22.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-06-23 09:31:26 | 22.5 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-06-23 09:39:53 | 22.4 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-06-23 09:36:08 | 22.4 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-06-23 09:35:38 | 22.4 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-06-23 09:38:52 | 22.4 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-06-23 09:38:22 | 22.4 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-06-23 09:38:52 | 22.4 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-06-23 09:35:07 | 22.4 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-06-23 09:35:08 | 22.4 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-06-23 09:38:52 | 22.4 | [OK] Fresh |
| df_VhTrans_Raw | 2026-06-23 09:38:22 | 22.4 | [OK] Fresh |
| df_INSALORD_Raw | 2026-06-23 09:35:08 | 22.4 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-06-23 09:35:08 | 22.4 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-06-23 09:38:52 | 22.4 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-06-23 09:41:39 | 22.3 | [OK] Fresh |
| df_WarClaim_Raw | 2026-06-23 09:41:38 | 22.3 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-06-23 09:42:08 | 22.3 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-06-23 09:42:08 | 22.3 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-06-23 09:41:39 | 22.3 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-06-23 09:42:09 | 22.3 | [OK] Fresh |
| df_CONTACT_Raw | 2026-06-23 09:42:08 | 22.3 | [OK] Fresh |
| df_Technician_Raw | 2026-06-23 09:42:08 | 22.3 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-06-23 09:42:29 | 22.3 | [OK] Fresh |
| df_ServiceTimeSheets_Raw | 2026-06-23 15:58:20 | 16.1 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-06-24 09:20:16 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-06-24 09:17:46 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-06-24 09:22:16 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-06-24 09:24:46 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-06-24 09:23:47 | -1.4 | [OK] Fresh |
| df_GlTrans_Raw | 2026-06-24 09:26:17 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-06-24 09:31:28 | -1.5 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-06-24 12:02:38 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-06-24 12:04:39 | -4.1 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

