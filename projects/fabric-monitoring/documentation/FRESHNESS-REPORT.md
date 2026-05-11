# Data Freshness Report

**Generated:** 2026-05-11 08:01:30
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

- **df_GlTrans_Full_Raw** (RawSource) - Last refreshed: 2026-04-16 01:32:30 (606.5 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-04-23 19:54:02 (420.1 hours ago)
- **df_ServiceTimeSheets_Raw** (RawSource) - Last refreshed: 2026-05-04 17:29:11 (158.5 hours ago)
- **df_Fact_OpenOrders** (FactTable) - Last refreshed: 2026-05-05 13:01:23 (139 hours ago)
- **df_Fact_OpenOrderParts** (FactTable) - Last refreshed: 2026-05-05 13:00:58 (139 hours ago)
- **df_Dim_WKCDPART** (Dimension) - Last refreshed: 2026-05-06 15:04:38 (112.9 hours ago)
- **df_Dim_WkCodeFl** (Dimension) - Last refreshed: 2026-05-06 15:26:40 (112.6 hours ago)
- **df_Fact_JobCodePartFrequency** (FactTable) - Last refreshed: 2026-05-07 13:25:40 (90.6 hours ago)
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Last refreshed: 2026-05-07 13:25:51 (90.6 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_BranchUserAccess | 2026-04-23 19:54:02 | 420.1 | [CRIT] Critical |
| df_Dim_WKCDPART | 2026-05-06 15:04:38 | 112.9 | [CRIT] Critical |
| df_Dim_WkCodeFl | 2026-05-06 15:26:40 | 112.6 | [CRIT] Critical |
| df_Dim_Part | 2026-05-11 10:08:25 | -2.1 | [OK] Fresh |
| df_Dim_Customer | 2026-05-11 10:05:37 | -2.1 | [OK] Fresh |
| df_Dim_Date | 2026-05-11 10:05:06 | -2.1 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-05-11 10:11:20 | -2.2 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-05-11 10:10:56 | -2.2 | [OK] Fresh |
| df_Dim_Technicans | 2026-05-11 10:10:50 | -2.2 | [OK] Fresh |
| df_Dim_JobCode | 2026-05-11 10:11:18 | -2.2 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-05-11 10:11:48 | -2.2 | [OK] Fresh |
| df_Dim_Salesperson | 2026-05-11 10:10:55 | -2.2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrderParts | 2026-05-05 13:00:58 | 139 | [CRIT] Critical |
| df_Fact_OpenOrders | 2026-05-05 13:01:23 | 139 | [CRIT] Critical |
| df_Fact_JobCodePartFrequency | 2026-05-07 13:25:40 | 90.6 | [CRIT] Critical |
| df_Fact_JobCodeFrequency_Branch | 2026-05-07 13:25:51 | 90.6 | [CRIT] Critical |
| df_FactPartTransactions_Incremental | 2026-05-11 10:14:22 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-05-11 10:19:15 | -2.3 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-05-11 10:17:44 | -2.3 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-05-11 10:19:46 | -2.3 | [OK] Fresh |
| df_Fact_Inventory | 2026-05-11 10:18:48 | -2.3 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-05-11 10:19:44 | -2.3 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-05-11 10:23:28 | -2.4 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-05-11 10:24:29 | -2.4 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-05-11 10:27:39 | -2.4 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-05-11 10:24:58 | -2.4 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-05-11 10:23:29 | -2.4 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-05-11 10:28:11 | -2.4 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-05-11 10:23:58 | -2.4 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-05-11 10:24:30 | -2.4 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-05-11 10:27:09 | -2.4 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-05-11 10:28:39 | -2.5 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-05-11 10:30:51 | -2.5 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-05-11 10:31:21 | -2.5 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-05-11 10:31:22 | -2.5 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-05-11 10:31:51 | -2.5 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-05-11 10:31:22 | -2.5 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-05-11 10:28:41 | -2.5 | [OK] Fresh |
| df_Fact_Transfers | 2026-05-11 10:34:53 | -2.6 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-05-11 10:37:38 | -2.6 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-05-11 10:38:07 | -2.6 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-05-11 10:37:38 | -2.6 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-05-11 10:37:39 | -2.6 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-05-11 10:37:36 | -2.6 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-05-11 10:37:37 | -2.6 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-05-11 12:57:57 | -4.9 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | 2026-04-16 01:32:30 | 606.5 | [CRIT] Critical |
| df_ServiceTimeSheets_Raw | 2026-05-04 17:29:11 | 158.5 | [CRIT] Critical |
| df_InHist_PmManage_Raw | 2026-05-11 09:21:18 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-05-11 09:20:15 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-05-11 09:18:45 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-05-11 09:24:16 | -1.4 | [OK] Fresh |
| df_GlTrans_Raw | 2026-05-11 09:24:15 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-05-11 09:25:15 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-05-11 09:43:36 | -1.7 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-05-11 09:45:49 | -1.7 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-05-11 09:45:48 | -1.7 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-05-11 09:46:49 | -1.8 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-05-11 09:46:49 | -1.8 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-05-11 09:50:02 | -1.8 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-05-11 09:50:01 | -1.8 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-05-11 09:51:01 | -1.8 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-05-11 09:46:49 | -1.8 | [OK] Fresh |
| df_INSALORD_Raw | 2026-05-11 09:50:01 | -1.8 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-05-11 09:50:03 | -1.8 | [OK] Fresh |
| df_InMaster_Raw | 2026-05-11 09:47:50 | -1.8 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-05-11 09:51:31 | -1.8 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-05-11 09:57:57 | -1.9 | [OK] Fresh |
| df_VhTrans_Raw | 2026-05-11 09:54:13 | -1.9 | [OK] Fresh |
| df_WarClaim_Raw | 2026-05-11 09:57:26 | -1.9 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-05-11 09:57:57 | -1.9 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-05-11 09:57:56 | -1.9 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-05-11 09:57:26 | -1.9 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-05-11 09:54:13 | -1.9 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-05-11 09:57:26 | -1.9 | [OK] Fresh |
| df_Technician_Raw | 2026-05-11 09:57:26 | -1.9 | [OK] Fresh |
| df_CONTACT_Raw | 2026-05-11 09:57:56 | -1.9 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-05-11 09:57:57 | -1.9 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-05-11 09:53:43 | -1.9 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-05-11 09:54:13 | -1.9 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-05-11 09:55:13 | -1.9 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-05-11 09:54:13 | -1.9 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-05-11 09:54:13 | -1.9 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

