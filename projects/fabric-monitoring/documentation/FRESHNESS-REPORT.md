# Data Freshness Report

**Generated:** 2026-05-27 08:02:23
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 78 | 80.4% |
| Stale | 0 | 0% |
| Critical | 8 | 8.2% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_GlMaster_Raw** (RawSource) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Last refreshed: 2026-05-06 15:04:38 (497 hours ago)
- **df_Dim_WkCodeFl** (Dimension) - Last refreshed: 2026-05-06 15:26:40 (496.6 hours ago)
- **df_Fact_OpenOrders** (FactTable) - Last refreshed: 2026-05-20 12:50:41 (163.2 hours ago)
- **df_Fact_OpenOrderParts** (FactTable) - Last refreshed: 2026-05-20 12:50:38 (163.2 hours ago)
- **df_Fact_JobCodePartFrequency** (FactTable) - Last refreshed: 2026-05-20 12:54:14 (163.1 hours ago)
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Last refreshed: 2026-05-20 12:55:53 (163.1 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | 2026-05-06 15:04:38 | 497 | [CRIT] Critical |
| df_Dim_WkCodeFl | 2026-05-06 15:26:40 | 496.6 | [CRIT] Critical |
| df_Dim_Franchise | 2026-05-26 16:21:38 | 15.7 | [OK] Fresh |
| df_Dim_Salesperson | 2026-05-27 09:52:04 | -1.8 | [OK] Fresh |
| df_Dim_Technicans | 2026-05-27 09:51:33 | -1.8 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-05-27 09:52:03 | -1.8 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-05-27 09:51:33 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-05-27 09:48:21 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-05-27 09:48:52 | -1.8 | [OK] Fresh |
| df_Dim_JobCode | 2026-05-27 09:52:03 | -1.8 | [OK] Fresh |
| df_Dim_Part | 2026-05-27 09:49:52 | -1.8 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-05-27 09:54:03 | -1.9 | [OK] Fresh |
| df_Dim_BranchUserAccess | 2026-05-27 10:02:03 | -2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrders | 2026-05-20 12:50:41 | 163.2 | [CRIT] Critical |
| df_Fact_OpenOrderParts | 2026-05-20 12:50:38 | 163.2 | [CRIT] Critical |
| df_Fact_JobCodePartFrequency | 2026-05-20 12:54:14 | 163.1 | [CRIT] Critical |
| df_Fact_JobCodeFrequency_Branch | 2026-05-20 12:55:53 | 163.1 | [CRIT] Critical |
| df_Fact_ServiceTimeSheet_Audit | 2026-05-26 14:16:58 | 17.8 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-05-27 09:56:30 | -1.9 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-05-27 10:00:59 | -2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-05-27 10:01:09 | -2 | [OK] Fresh |
| df_Fact_Inventory | 2026-05-27 10:00:30 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-05-27 09:59:29 | -2 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-05-27 10:01:30 | -2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-05-27 10:09:09 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-05-27 10:05:21 | -2.1 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-05-27 10:09:41 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-05-27 10:05:49 | -2.1 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-05-27 10:09:10 | -2.1 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-05-27 10:10:09 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-05-27 10:06:49 | -2.1 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-05-27 10:09:38 | -2.1 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-05-27 10:06:20 | -2.1 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-05-27 10:06:23 | -2.1 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-05-27 10:06:20 | -2.1 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-05-27 10:12:26 | -2.2 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-05-27 10:12:56 | -2.2 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-05-27 10:13:02 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-05-27 10:12:59 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-05-27 10:12:56 | -2.2 | [OK] Fresh |
| df_Fact_Transfers | 2026-05-27 10:16:32 | -2.2 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-05-27 10:19:49 | -2.3 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-05-27 10:18:48 | -2.3 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-05-27 10:19:16 | -2.3 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-05-27 10:19:17 | -2.3 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-05-27 10:19:18 | -2.3 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-05-27 10:19:17 | -2.3 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-05-27 12:33:00 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-05-26 14:02:32 | 18 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-05-27 09:17:44 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-05-27 09:21:20 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-05-27 09:22:44 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-05-27 09:19:44 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-05-27 09:23:45 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-05-27 09:23:44 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-05-27 09:27:14 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-05-27 09:29:26 | -1.5 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-05-27 09:33:48 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-05-27 09:29:58 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-05-27 09:29:58 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-05-27 09:29:26 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-05-27 09:30:26 | -1.5 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-05-27 09:34:48 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-05-27 09:34:47 | -1.5 | [OK] Fresh |
| df_INSALORD_Raw | 2026-05-27 09:33:47 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-05-27 09:31:26 | -1.5 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-05-27 09:33:46 | -1.5 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-05-27 09:33:47 | -1.5 | [OK] Fresh |
| df_VhTrans_Raw | 2026-05-27 09:37:32 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-05-27 09:37:34 | -1.6 | [OK] Fresh |
| df_WarClaim_Raw | 2026-05-27 09:40:47 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-05-27 09:37:02 | -1.6 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-05-27 09:41:17 | -1.6 | [OK] Fresh |
| df_Technician_Raw | 2026-05-27 09:41:17 | -1.6 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-05-27 09:37:34 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-05-27 09:37:32 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-05-27 09:37:04 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-05-27 09:38:33 | -1.6 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-05-27 09:41:17 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-05-27 09:41:17 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-05-27 09:41:17 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-05-27 09:41:17 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-05-27 09:41:17 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-05-27 09:41:17 | -1.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

