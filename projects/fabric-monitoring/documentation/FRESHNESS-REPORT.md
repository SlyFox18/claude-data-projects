# Data Freshness Report

**Generated:** 2026-05-18 08:01:33
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

- **df_GlMaster_Raw** (RawSource) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_ServiceTimeSheets_Raw** (RawSource) - Last refreshed: 2026-05-04 17:29:11 (326.5 hours ago)
- **df_Fact_OpenOrders** (FactTable) - Last refreshed: 2026-05-05 13:01:23 (307 hours ago)
- **df_Fact_OpenOrderParts** (FactTable) - Last refreshed: 2026-05-05 13:00:58 (307 hours ago)
- **df_Dim_WKCDPART** (Dimension) - Last refreshed: 2026-05-06 15:04:38 (280.9 hours ago)
- **df_Dim_WkCodeFl** (Dimension) - Last refreshed: 2026-05-06 15:26:40 (280.6 hours ago)
- **df_Fact_JobCodePartFrequency** (FactTable) - Last refreshed: 2026-05-07 13:25:40 (258.6 hours ago)
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Last refreshed: 2026-05-07 13:25:51 (258.6 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | 2026-05-06 15:04:38 | 280.9 | [CRIT] Critical |
| df_Dim_WkCodeFl | 2026-05-06 15:26:40 | 280.6 | [CRIT] Critical |
| df_Dim_Part | 2026-05-18 10:08:34 | -2.1 | [OK] Fresh |
| df_Dim_Date | 2026-05-18 10:05:08 | -2.1 | [OK] Fresh |
| df_Dim_Customer | 2026-05-18 10:06:06 | -2.1 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-05-18 10:10:49 | -2.2 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-05-18 10:10:47 | -2.2 | [OK] Fresh |
| df_Dim_Technicans | 2026-05-18 10:10:50 | -2.2 | [OK] Fresh |
| df_Dim_JobCode | 2026-05-18 10:10:46 | -2.2 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-05-18 10:13:56 | -2.2 | [OK] Fresh |
| df_Dim_Salesperson | 2026-05-18 10:10:19 | -2.2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrders | 2026-05-05 13:01:23 | 307 | [CRIT] Critical |
| df_Fact_OpenOrderParts | 2026-05-05 13:00:58 | 307 | [CRIT] Critical |
| df_Fact_JobCodePartFrequency | 2026-05-07 13:25:40 | 258.6 | [CRIT] Critical |
| df_Fact_JobCodeFrequency_Branch | 2026-05-07 13:25:51 | 258.6 | [CRIT] Critical |
| df_FactPartTransactions_Incremental | 2026-05-18 10:16:25 | -2.2 | [OK] Fresh |
| df_Fact_Inventory | 2026-05-18 10:21:27 | -2.3 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-05-18 10:21:27 | -2.3 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-05-18 10:21:57 | -2.3 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-05-18 10:20:26 | -2.3 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-05-18 10:26:11 | -2.4 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-05-18 10:26:11 | -2.4 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-05-18 10:22:27 | -2.4 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-05-18 10:27:12 | -2.4 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-05-18 10:26:41 | -2.4 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-05-18 10:26:41 | -2.4 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-05-18 10:27:11 | -2.4 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-05-18 10:29:53 | -2.5 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-05-18 10:33:39 | -2.5 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-05-18 10:30:52 | -2.5 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-05-18 10:29:24 | -2.5 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-05-18 10:33:09 | -2.5 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-05-18 10:29:23 | -2.5 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-05-18 10:33:08 | -2.5 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-05-18 10:33:08 | -2.5 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-05-18 10:33:39 | -2.5 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-05-18 10:29:52 | -2.5 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-05-18 10:39:53 | -2.6 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-05-18 10:40:22 | -2.6 | [OK] Fresh |
| df_Fact_Transfers | 2026-05-18 10:37:38 | -2.6 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-05-18 10:40:23 | -2.6 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-05-18 10:40:24 | -2.7 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-05-18 10:41:07 | -2.7 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-05-18 10:40:53 | -2.7 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-05-18 12:33:30 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-05-04 17:29:11 | 326.5 | [CRIT] Critical |
| df_Parts_InterbranchTransfer_Raw | 2026-05-18 09:18:18 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-05-18 09:21:48 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-05-18 09:22:18 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-05-18 09:20:18 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-05-18 09:25:19 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-05-18 09:23:48 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-05-18 09:45:48 | -1.7 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-05-18 09:43:35 | -1.7 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-05-18 09:46:19 | -1.7 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-05-18 09:46:48 | -1.8 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-05-18 09:51:32 | -1.8 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-05-18 09:46:48 | -1.8 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-05-18 09:50:32 | -1.8 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-05-18 09:51:33 | -1.8 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-05-18 09:46:48 | -1.8 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-05-18 09:50:02 | -1.8 | [OK] Fresh |
| df_INSALORD_Raw | 2026-05-18 09:50:02 | -1.8 | [OK] Fresh |
| df_InMaster_Raw | 2026-05-18 09:47:49 | -1.8 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-05-18 09:50:02 | -1.8 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-05-18 09:58:01 | -1.9 | [OK] Fresh |
| df_CONTACT_Raw | 2026-05-18 09:57:31 | -1.9 | [OK] Fresh |
| df_WarClaim_Raw | 2026-05-18 09:58:01 | -1.9 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-05-18 09:58:01 | -1.9 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-05-18 09:58:01 | -1.9 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-05-18 09:58:01 | -1.9 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-05-18 09:58:01 | -1.9 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-05-18 09:58:03 | -1.9 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-05-18 09:54:17 | -1.9 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-05-18 09:54:17 | -1.9 | [OK] Fresh |
| df_Technician_Raw | 2026-05-18 09:58:01 | -1.9 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-05-18 09:53:46 | -1.9 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-05-18 09:54:17 | -1.9 | [OK] Fresh |
| df_VhTrans_Raw | 2026-05-18 09:54:17 | -1.9 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-05-18 09:54:17 | -1.9 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-05-18 09:55:17 | -1.9 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

