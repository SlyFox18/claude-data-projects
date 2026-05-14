# Data Freshness Report

**Generated:** 2026-05-14 08:01:27
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

- **df_GlTrans_Full_Raw** (RawSource) - Last refreshed: 2026-04-16 01:32:30 (678.5 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-04-23 19:54:02 (492.1 hours ago)
- **df_ServiceTimeSheets_Raw** (RawSource) - Last refreshed: 2026-05-04 17:29:11 (230.5 hours ago)
- **df_Fact_OpenOrders** (FactTable) - Last refreshed: 2026-05-05 13:01:23 (211 hours ago)
- **df_Fact_OpenOrderParts** (FactTable) - Last refreshed: 2026-05-05 13:00:58 (211 hours ago)
- **df_Dim_WKCDPART** (Dimension) - Last refreshed: 2026-05-06 15:04:38 (184.9 hours ago)
- **df_Dim_WkCodeFl** (Dimension) - Last refreshed: 2026-05-06 15:26:40 (184.6 hours ago)
- **df_Fact_JobCodePartFrequency** (FactTable) - Last refreshed: 2026-05-07 13:25:40 (162.6 hours ago)
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Last refreshed: 2026-05-07 13:25:51 (162.6 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_BranchUserAccess | 2026-04-23 19:54:02 | 492.1 | [CRIT] Critical |
| df_Dim_WKCDPART | 2026-05-06 15:04:38 | 184.9 | [CRIT] Critical |
| df_Dim_WkCodeFl | 2026-05-06 15:26:40 | 184.6 | [CRIT] Critical |
| df_Dim_Part | 2026-05-14 10:08:30 | -2.1 | [OK] Fresh |
| df_Dim_Customer | 2026-05-14 10:06:31 | -2.1 | [OK] Fresh |
| df_Dim_Date | 2026-05-14 10:08:17 | -2.1 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-05-14 10:10:52 | -2.2 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-05-14 10:10:51 | -2.2 | [OK] Fresh |
| df_Dim_Technicans | 2026-05-14 10:10:55 | -2.2 | [OK] Fresh |
| df_Dim_JobCode | 2026-05-14 10:11:25 | -2.2 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-05-14 10:12:01 | -2.2 | [OK] Fresh |
| df_Dim_Salesperson | 2026-05-14 10:10:53 | -2.2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrderParts | 2026-05-05 13:00:58 | 211 | [CRIT] Critical |
| df_Fact_OpenOrders | 2026-05-05 13:01:23 | 211 | [CRIT] Critical |
| df_Fact_JobCodePartFrequency | 2026-05-07 13:25:40 | 162.6 | [CRIT] Critical |
| df_Fact_JobCodeFrequency_Branch | 2026-05-07 13:25:51 | 162.6 | [CRIT] Critical |
| df_FactPartTransactions_Incremental | 2026-05-14 10:14:45 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-05-14 10:19:45 | -2.3 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-05-14 10:18:42 | -2.3 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-05-14 10:20:15 | -2.3 | [OK] Fresh |
| df_Fact_Inventory | 2026-05-14 10:19:13 | -2.3 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-05-14 10:20:13 | -2.3 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-05-14 10:24:06 | -2.4 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-05-14 10:28:19 | -2.4 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-05-14 10:25:05 | -2.4 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-05-14 10:27:19 | -2.4 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-05-14 10:25:06 | -2.4 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-05-14 10:27:50 | -2.4 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-05-14 10:27:49 | -2.4 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-05-14 10:24:35 | -2.4 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-05-14 10:27:19 | -2.4 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-05-14 10:24:36 | -2.4 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-05-14 10:24:07 | -2.4 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-05-14 10:31:03 | -2.5 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-05-14 10:31:01 | -2.5 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-05-14 10:30:30 | -2.5 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-05-14 10:31:01 | -2.5 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-05-14 10:30:30 | -2.5 | [OK] Fresh |
| df_Fact_Transfers | 2026-05-14 10:35:00 | -2.6 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-05-14 10:37:47 | -2.6 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-05-14 10:38:18 | -2.6 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-05-14 10:37:46 | -2.6 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-05-14 10:37:48 | -2.6 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-05-14 10:37:46 | -2.6 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-05-14 10:37:49 | -2.6 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-05-14 12:32:57 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | 2026-04-16 01:32:30 | 678.5 | [CRIT] Critical |
| df_ServiceTimeSheets_Raw | 2026-05-04 17:29:11 | 230.5 | [CRIT] Critical |
| df_InHist_PmManage_Raw | 2026-05-14 09:21:42 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-05-14 09:22:12 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-05-14 09:18:21 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-05-14 09:20:42 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-05-14 09:23:42 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-05-14 09:25:42 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-05-14 09:43:32 | -1.7 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-05-14 09:45:47 | -1.7 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-05-14 09:45:47 | -1.7 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-05-14 09:46:47 | -1.8 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-05-14 09:46:47 | -1.8 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-05-14 09:50:01 | -1.8 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-05-14 09:50:01 | -1.8 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-05-14 09:51:32 | -1.8 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-05-14 09:46:47 | -1.8 | [OK] Fresh |
| df_INSALORD_Raw | 2026-05-14 09:50:02 | -1.8 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-05-14 09:50:01 | -1.8 | [OK] Fresh |
| df_InMaster_Raw | 2026-05-14 09:47:47 | -1.8 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-05-14 09:51:34 | -1.8 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-05-14 09:58:02 | -1.9 | [OK] Fresh |
| df_VhTrans_Raw | 2026-05-14 09:54:17 | -1.9 | [OK] Fresh |
| df_WarClaim_Raw | 2026-05-14 09:58:02 | -1.9 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-05-14 09:58:02 | -1.9 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-05-14 09:57:32 | -1.9 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-05-14 09:58:02 | -1.9 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-05-14 09:55:16 | -1.9 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-05-14 09:58:02 | -1.9 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-05-14 09:53:46 | -1.9 | [OK] Fresh |
| df_CONTACT_Raw | 2026-05-14 09:58:02 | -1.9 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-05-14 09:57:33 | -1.9 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-05-14 09:54:17 | -1.9 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-05-14 09:55:16 | -1.9 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-05-14 09:54:16 | -1.9 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-05-14 09:55:16 | -1.9 | [OK] Fresh |
| df_Technician_Raw | 2026-05-14 09:58:33 | -2 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

