# Data Freshness Report

**Generated:** 2026-05-15 08:01:37
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 74 | 76.3% |
| Stale | 0 | 0% |
| Critical | 10 | 10.3% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_GlMaster_Raw** (RawSource) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Last refreshed: 2026-04-16 01:32:30 (702.5 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-04-23 19:54:02 (516.1 hours ago)
- **df_ServiceTimeSheets_Raw** (RawSource) - Last refreshed: 2026-05-04 17:29:11 (254.5 hours ago)
- **df_Fact_OpenOrderParts** (FactTable) - Last refreshed: 2026-05-05 13:00:58 (235 hours ago)
- **df_Fact_OpenOrders** (FactTable) - Last refreshed: 2026-05-05 13:01:23 (235 hours ago)
- **df_Dim_WKCDPART** (Dimension) - Last refreshed: 2026-05-06 15:04:38 (208.9 hours ago)
- **df_Dim_WkCodeFl** (Dimension) - Last refreshed: 2026-05-06 15:26:40 (208.6 hours ago)
- **df_Fact_JobCodePartFrequency** (FactTable) - Last refreshed: 2026-05-07 13:25:40 (186.6 hours ago)
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Last refreshed: 2026-05-07 13:25:51 (186.6 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_BranchUserAccess | 2026-04-23 19:54:02 | 516.1 | [CRIT] Critical |
| df_Dim_WKCDPART | 2026-05-06 15:04:38 | 208.9 | [CRIT] Critical |
| df_Dim_WkCodeFl | 2026-05-06 15:26:40 | 208.6 | [CRIT] Critical |
| df_Dim_Part | 2026-05-15 09:56:12 | -1.9 | [OK] Fresh |
| df_Dim_Customer | 2026-05-15 09:54:10 | -1.9 | [OK] Fresh |
| df_Dim_Date | 2026-05-15 09:53:10 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-05-15 10:01:02 | -2 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-05-15 09:58:24 | -2 | [OK] Fresh |
| df_Dim_Technicans | 2026-05-15 09:58:24 | -2 | [OK] Fresh |
| df_Dim_JobCode | 2026-05-15 09:58:23 | -2 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-05-15 09:59:24 | -2 | [OK] Fresh |
| df_Dim_Salesperson | 2026-05-15 09:58:28 | -2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrderParts | 2026-05-05 13:00:58 | 235 | [CRIT] Critical |
| df_Fact_OpenOrders | 2026-05-05 13:01:23 | 235 | [CRIT] Critical |
| df_Fact_JobCodePartFrequency | 2026-05-07 13:25:40 | 186.6 | [CRIT] Critical |
| df_Fact_JobCodeFrequency_Branch | 2026-05-07 13:25:51 | 186.6 | [CRIT] Critical |
| df_FactPartTransactions_Incremental | 2026-05-15 10:04:26 | -2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-05-15 10:09:10 | -2.1 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-05-15 10:07:41 | -2.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-05-15 10:10:16 | -2.1 | [OK] Fresh |
| df_Fact_Inventory | 2026-05-15 10:08:44 | -2.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-05-15 10:09:46 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-05-15 10:15:00 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-05-15 10:15:46 | -2.2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-05-15 10:15:06 | -2.2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-05-15 10:15:01 | -2.2 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-05-15 10:15:02 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-05-15 10:14:30 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-05-15 10:18:33 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-05-15 10:21:43 | -2.3 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-05-15 10:22:13 | -2.3 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-05-15 10:19:31 | -2.3 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-05-15 10:18:02 | -2.3 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-05-15 10:18:31 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-05-15 10:22:13 | -2.3 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-05-15 10:19:05 | -2.3 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-05-15 10:21:42 | -2.3 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-05-15 10:22:42 | -2.4 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-05-15 10:33:07 | -2.5 | [OK] Fresh |
| df_Fact_Transfers | 2026-05-15 10:29:52 | -2.5 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-05-15 10:32:39 | -2.5 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-05-15 10:32:37 | -2.5 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-05-15 10:32:41 | -2.5 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-05-15 10:32:38 | -2.5 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-05-15 10:32:37 | -2.5 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-05-15 12:33:32 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlTrans_Full_Raw | 2026-04-16 01:32:30 | 702.5 | [CRIT] Critical |
| df_ServiceTimeSheets_Raw | 2026-05-04 17:29:11 | 254.5 | [CRIT] Critical |
| df_GlTrans_Raw | 2026-05-15 09:22:17 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-05-15 09:22:17 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-05-15 09:20:47 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-05-15 09:18:47 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-05-15 09:24:18 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-05-15 09:24:17 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-05-15 09:29:47 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-05-15 09:34:01 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-05-15 09:33:03 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-05-15 09:32:00 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-05-15 09:33:04 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-05-15 09:32:00 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-05-15 09:33:00 | -1.5 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-05-15 09:37:15 | -1.6 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-05-15 09:39:59 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-05-15 09:36:44 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-05-15 09:40:00 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-05-15 09:36:14 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-05-15 09:39:59 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-05-15 09:40:02 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-05-15 09:35:45 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-05-15 09:39:32 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-05-15 09:36:14 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-05-15 09:36:14 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-05-15 09:39:30 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-05-15 09:44:38 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-05-15 09:47:21 | -1.8 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-05-15 09:47:21 | -1.8 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-05-15 09:47:22 | -1.8 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-05-15 09:47:21 | -1.8 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-05-15 09:47:21 | -1.8 | [OK] Fresh |
| df_WarClaim_Raw | 2026-05-15 09:47:21 | -1.8 | [OK] Fresh |
| df_Technician_Raw | 2026-05-15 09:47:22 | -1.8 | [OK] Fresh |
| df_CONTACT_Raw | 2026-05-15 09:47:22 | -1.8 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-05-15 09:47:22 | -1.8 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

