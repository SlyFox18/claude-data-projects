# Data Freshness Report

**Generated:** 2026-05-12 08:01:35
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

- **df_GlTrans_Full_Raw** (RawSource) - Last refreshed: 2026-04-16 01:32:30 (630.5 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-04-23 19:54:02 (444.1 hours ago)
- **df_ServiceTimeSheets_Raw** (RawSource) - Last refreshed: 2026-05-04 17:29:11 (182.5 hours ago)
- **df_Fact_OpenOrders** (FactTable) - Last refreshed: 2026-05-05 13:01:23 (163 hours ago)
- **df_Fact_OpenOrderParts** (FactTable) - Last refreshed: 2026-05-05 13:00:58 (163 hours ago)
- **df_Dim_WKCDPART** (Dimension) - Last refreshed: 2026-05-06 15:04:38 (136.9 hours ago)
- **df_Dim_WkCodeFl** (Dimension) - Last refreshed: 2026-05-06 15:26:40 (136.6 hours ago)
- **df_Fact_JobCodePartFrequency** (FactTable) - Last refreshed: 2026-05-07 13:25:40 (114.6 hours ago)
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Last refreshed: 2026-05-07 13:25:51 (114.6 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_BranchUserAccess | 2026-04-23 19:54:02 | 444.1 | [CRIT] Critical |
| df_Dim_WKCDPART | 2026-05-06 15:04:38 | 136.9 | [CRIT] Critical |
| df_Dim_WkCodeFl | 2026-05-06 15:26:40 | 136.6 | [CRIT] Critical |
| df_Dim_Date | 2026-05-12 09:50:55 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-05-12 09:51:54 | -1.8 | [OK] Fresh |
| df_Dim_Technicans | 2026-05-12 09:56:16 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-05-12 09:56:15 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-05-12 09:56:15 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-05-12 09:53:53 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-05-12 09:56:16 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-05-12 09:56:26 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-05-12 09:57:16 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrders | 2026-05-05 13:01:23 | 163 | [CRIT] Critical |
| df_Fact_OpenOrderParts | 2026-05-05 13:00:58 | 163 | [CRIT] Critical |
| df_Fact_JobCodePartFrequency | 2026-05-07 13:25:40 | 114.6 | [CRIT] Critical |
| df_Fact_JobCodeFrequency_Branch | 2026-05-07 13:25:51 | 114.6 | [CRIT] Critical |
| df_Fact_InternalWorkOrders | 2026-05-11 19:42:44 | 12.3 | [OK] Fresh |
| df_Fact_Inventory | 2026-05-12 10:04:15 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-05-12 10:03:14 | -2 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-05-12 09:59:44 | -2 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-05-12 10:04:44 | -2.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-05-12 10:05:45 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-05-12 10:04:45 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-05-12 10:09:29 | -2.1 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-05-12 10:10:18 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-05-12 10:09:31 | -2.1 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-05-12 10:13:48 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-05-12 10:10:29 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-05-12 10:13:15 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-05-12 10:13:14 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-05-12 10:12:46 | -2.2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-05-12 10:10:31 | -2.2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-05-12 10:10:29 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-05-12 10:13:15 | -2.2 | [OK] Fresh |
| df_Fact_Transfers | 2026-05-12 10:20:03 | -2.3 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-05-12 10:16:33 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-05-12 10:16:33 | -2.3 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-05-12 10:16:31 | -2.3 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-05-12 10:16:33 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-05-12 10:16:31 | -2.3 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-05-12 10:22:17 | -2.3 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-05-12 10:22:47 | -2.4 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-05-12 10:22:47 | -2.4 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-05-12 10:22:48 | -2.4 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-05-12 10:22:48 | -2.4 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-05-12 10:23:17 | -2.4 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | 2026-04-16 01:32:30 | 630.5 | [CRIT] Critical |
| df_ServiceTimeSheets_Raw | 2026-05-04 17:29:11 | 182.5 | [CRIT] Critical |
| df_Parts_InterbranchTransfer_Raw | 2026-05-12 09:17:44 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-05-12 09:20:14 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-05-12 09:21:45 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-05-12 09:21:44 | -1.3 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-05-12 09:28:14 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-05-12 09:24:14 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-05-12 09:23:44 | -1.4 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-05-12 09:31:26 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-05-12 09:32:56 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-05-12 09:30:56 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-05-12 09:30:55 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-05-12 09:30:26 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-05-12 09:32:56 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-05-12 09:36:07 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-05-12 09:36:37 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-05-12 09:35:09 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-05-12 09:40:26 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-05-12 09:35:07 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-05-12 09:35:08 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-05-12 09:35:08 | -1.6 | [OK] Fresh |
| df_CONTACT_Raw | 2026-05-12 09:44:37 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-05-12 09:44:37 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-05-12 09:44:36 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-05-12 09:44:37 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-05-12 09:44:39 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-05-12 09:44:37 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-05-12 09:44:37 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-05-12 09:44:37 | -1.7 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-05-12 09:40:56 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-05-12 09:44:37 | -1.7 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-05-12 09:40:56 | -1.7 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-05-12 09:40:55 | -1.7 | [OK] Fresh |
| df_VhTrans_Raw | 2026-05-12 09:40:56 | -1.7 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-05-12 09:40:56 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-05-12 09:41:55 | -1.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

