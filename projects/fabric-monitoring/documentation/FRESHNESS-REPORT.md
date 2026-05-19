# Data Freshness Report

**Generated:** 2026-05-19 08:01:29
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 76 | 78.4% |
| Stale | 0 | 0% |
| Critical | 8 | 8.2% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_GlMaster_Raw** (RawSource) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Fact_OpenOrderParts** (FactTable) - Last refreshed: 2026-05-05 13:00:58 (331 hours ago)
- **df_Fact_OpenOrders** (FactTable) - Last refreshed: 2026-05-05 13:01:23 (331 hours ago)
- **df_Dim_WKCDPART** (Dimension) - Last refreshed: 2026-05-06 15:04:38 (304.9 hours ago)
- **df_Dim_WkCodeFl** (Dimension) - Last refreshed: 2026-05-06 15:26:40 (304.6 hours ago)
- **df_Fact_JobCodePartFrequency** (FactTable) - Last refreshed: 2026-05-07 13:25:40 (282.6 hours ago)
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Last refreshed: 2026-05-07 13:25:51 (282.6 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | 2026-05-06 15:04:38 | 304.9 | [CRIT] Critical |
| df_Dim_WkCodeFl | 2026-05-06 15:26:40 | 304.6 | [CRIT] Critical |
| df_Dim_Part | 2026-05-19 09:52:11 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-05-19 09:48:40 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-05-19 09:49:40 | -1.8 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-05-19 09:54:51 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-05-19 09:54:22 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-05-19 09:54:21 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-05-19 09:54:21 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-05-19 09:55:21 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-05-19 09:54:22 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrders | 2026-05-05 13:01:23 | 331 | [CRIT] Critical |
| df_Fact_OpenOrderParts | 2026-05-05 13:00:58 | 331 | [CRIT] Critical |
| df_Fact_JobCodePartFrequency | 2026-05-07 13:25:40 | 282.6 | [CRIT] Critical |
| df_Fact_JobCodeFrequency_Branch | 2026-05-07 13:25:51 | 282.6 | [CRIT] Critical |
| df_Fact_ServiceTimeSheet_Audit | 2026-05-18 21:10:32 | 10.8 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-05-19 09:57:45 | -1.9 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-05-19 10:02:45 | -2 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-05-19 10:03:15 | -2 | [OK] Fresh |
| df_Fact_Inventory | 2026-05-19 10:02:15 | -2 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-05-19 10:03:15 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-05-19 10:01:15 | -2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-05-19 10:08:14 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-05-19 10:07:11 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-05-19 10:07:11 | -2.1 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-05-19 10:07:46 | -2.1 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-05-19 10:07:42 | -2.1 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-05-19 10:08:11 | -2.1 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-05-19 10:11:02 | -2.2 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-05-19 10:13:57 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-05-19 10:11:31 | -2.2 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-05-19 10:14:28 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-05-19 10:11:37 | -2.2 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-05-19 10:13:58 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-05-19 10:13:59 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-05-19 10:14:56 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-05-19 10:11:03 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-05-19 10:11:01 | -2.2 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-05-19 10:22:15 | -2.3 | [OK] Fresh |
| df_Fact_Transfers | 2026-05-19 10:17:58 | -2.3 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-05-19 10:20:15 | -2.3 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-05-19 10:20:16 | -2.3 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-05-19 10:20:45 | -2.3 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-05-19 10:20:45 | -2.3 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-05-19 10:20:45 | -2.3 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-05-19 12:33:32 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_InHist_PmManage_Raw | 2026-05-19 09:21:14 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-05-19 09:22:14 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-05-19 09:20:44 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-05-19 09:18:14 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-05-19 09:23:44 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-05-19 09:23:44 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-05-19 09:28:46 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-05-19 09:32:59 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-05-19 09:31:59 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-05-19 09:31:59 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-05-19 09:31:00 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-05-19 09:31:31 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-05-19 09:31:59 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-05-19 09:36:12 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-05-19 09:36:13 | -1.6 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-05-19 09:39:07 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-05-19 09:39:56 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-05-19 09:38:57 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-05-19 09:38:57 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-05-19 09:35:12 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-05-19 09:38:57 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-05-19 09:35:12 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-05-19 09:38:58 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-05-19 09:35:13 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-05-19 09:35:42 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-05-19 09:38:26 | -1.6 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-05-19 09:42:40 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-05-19 09:42:40 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-05-19 09:42:41 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-05-19 09:42:40 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-05-19 09:42:40 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-05-19 09:42:41 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-05-19 09:42:40 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-05-19 09:42:41 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-05-19 09:42:40 | -1.7 | [OK] Fresh |
| df_ServiceTimeSheets_Raw | 2026-05-19 12:57:14 | -4.9 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

