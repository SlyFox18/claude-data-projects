# Data Freshness Report

**Generated:** 2026-06-30 08:01:34
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 79 | 79% |
| Stale | 0 | 0% |
| Critical | 7 | 7% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!
- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Fact_JobCodePartFrequency** (FactTable) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Never refreshed!
- **df_Dim_WkCodeFl** (Dimension) - Never refreshed!
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Never refreshed!

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_Date | 2026-06-30 09:51:45 | -1.8 | [OK] Fresh |
| df_Dim_Technicans | 2026-06-30 09:56:55 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-06-30 09:56:26 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-06-30 09:56:55 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-06-30 09:56:56 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-06-30 09:56:55 | -1.9 | [OK] Fresh |
| df_Dim_Customer | 2026-06-30 09:52:46 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-06-30 09:57:55 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-06-30 09:54:46 | -1.9 | [OK] Fresh |
| df_Dim_BranchUserAccess | 2026-06-30 10:01:35 | -2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceTimeSheet_Audit | 2026-06-29 21:43:35 | 10.3 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-06-30 10:03:49 | -2 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-06-30 10:00:19 | -2 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-06-30 10:06:48 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-06-30 10:05:19 | -2.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-06-30 10:06:48 | -2.1 | [OK] Fresh |
| df_Fact_Inventory | 2026-06-30 10:04:48 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-06-30 10:10:32 | -2.2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-06-30 10:11:31 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-06-30 10:15:53 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-06-30 10:16:22 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-06-30 10:11:32 | -2.2 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-06-30 10:12:01 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-06-30 10:15:53 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-06-30 10:13:33 | -2.2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-06-30 10:12:03 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-06-30 10:17:23 | -2.3 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-06-30 10:19:35 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-06-30 10:20:05 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-06-30 10:19:36 | -2.3 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-06-30 10:16:53 | -2.3 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-06-30 10:19:35 | -2.3 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-06-30 10:20:05 | -2.3 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-06-30 10:26:48 | -2.4 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-06-30 10:25:48 | -2.4 | [OK] Fresh |
| df_Fact_Transfers | 2026-06-30 10:23:35 | -2.4 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-06-30 10:25:48 | -2.4 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-06-30 10:25:49 | -2.4 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-06-30 10:25:49 | -2.4 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-06-30 10:25:48 | -2.4 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-06-30 12:33:27 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-06-29 21:37:12 | 10.4 | [OK] Fresh |
| df_GlTrans_Raw | 2026-06-30 09:22:15 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-06-30 09:18:14 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-06-30 09:20:44 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-06-30 09:21:45 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-06-30 09:24:14 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-06-30 09:23:45 | -1.4 | [OK] Fresh |
| df_InMaster_Raw | 2026-06-30 09:34:27 | -1.5 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-06-30 09:30:15 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-06-30 09:32:57 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-06-30 09:32:27 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-06-30 09:32:57 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-06-30 09:33:27 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-06-30 09:32:27 | -1.5 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-06-30 09:40:20 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-06-30 09:40:20 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-06-30 09:38:08 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-06-30 09:37:38 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-06-30 09:36:38 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-06-30 09:36:38 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-06-30 09:40:20 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-06-30 09:36:38 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-06-30 09:36:38 | -1.6 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-06-30 09:46:03 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-06-30 09:46:02 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-06-30 09:46:03 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-06-30 09:46:03 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-06-30 09:46:03 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-06-30 09:46:02 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-06-30 09:46:03 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-06-30 09:46:02 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-06-30 09:46:04 | -1.7 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-06-30 09:40:50 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-06-30 09:43:50 | -1.7 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-06-30 09:40:50 | -1.7 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-06-30 09:41:11 | -1.7 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-06-30 12:03:15 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-06-30 12:05:16 | -4.1 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

