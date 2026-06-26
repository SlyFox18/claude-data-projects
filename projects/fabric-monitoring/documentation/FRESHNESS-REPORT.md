# Data Freshness Report

**Generated:** 2026-06-26 08:01:33
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 78 | 78% |
| Stale |  | 0% |
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
| df_Dim_BranchUserAccess | 2026-06-24 10:01:59 | 46 | [WARN] Stale |
| df_Dim_Date | 2026-06-26 09:49:08 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-06-26 09:50:08 | -1.8 | [OK] Fresh |
| df_Dim_Technicans | 2026-06-26 09:56:18 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-06-26 09:54:49 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-06-26 09:54:49 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-06-26 09:53:08 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-06-26 09:55:18 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-06-26 09:54:48 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-06-26 09:56:18 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceTimeSheet_Audit | 2026-06-25 14:19:00 | 17.7 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-06-26 10:04:12 | -2 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-06-26 09:59:12 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-06-26 10:02:42 | -2 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-06-26 10:04:12 | -2 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-06-26 10:08:55 | -2.1 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-06-26 10:09:59 | -2.1 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-06-26 10:09:59 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-06-26 10:09:55 | -2.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-06-26 10:05:12 | -2.1 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-06-26 10:09:27 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-06-26 10:08:54 | -2.1 | [OK] Fresh |
| df_Fact_Inventory | 2026-06-26 10:04:42 | -2.1 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-06-26 10:12:41 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-06-26 10:13:40 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-06-26 10:12:12 | -2.2 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-06-26 10:16:01 | -2.2 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-06-26 10:16:01 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-06-26 10:16:01 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-06-26 10:16:02 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-06-26 10:12:40 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-06-26 10:12:10 | -2.2 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-06-26 10:22:16 | -2.3 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-06-26 10:16:31 | -2.3 | [OK] Fresh |
| df_Fact_Transfers | 2026-06-26 10:20:02 | -2.3 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-06-26 10:22:15 | -2.3 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-06-26 10:22:14 | -2.3 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-06-26 10:22:16 | -2.3 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-06-26 10:22:14 | -2.3 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-06-26 10:24:45 | -2.4 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-06-26 12:33:29 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-06-25 14:02:31 | 18 | [OK] Fresh |
| df_GlTrans_Raw | 2026-06-26 09:22:22 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-06-26 09:18:22 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-06-26 09:20:22 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-06-26 09:21:53 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-06-26 09:23:52 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-06-26 09:23:52 | -1.4 | [OK] Fresh |
| df_InMaster_Raw | 2026-06-26 09:33:35 | -1.5 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-06-26 09:29:23 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-06-26 09:32:04 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-06-26 09:31:34 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-06-26 09:32:04 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-06-26 09:32:04 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-06-26 09:31:33 | -1.5 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-06-26 09:40:03 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-06-26 09:39:59 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-06-26 09:37:19 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-06-26 09:35:47 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-06-26 09:39:59 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-06-26 09:39:59 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-06-26 09:36:47 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-06-26 09:39:28 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-06-26 09:35:46 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-06-26 09:35:47 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-06-26 09:39:28 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-06-26 09:35:47 | -1.6 | [OK] Fresh |
| df_CONTACT_Raw | 2026-06-26 09:43:10 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-06-26 09:43:10 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-06-26 09:43:10 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-06-26 09:43:10 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-06-26 09:43:10 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-06-26 09:42:40 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-06-26 09:40:58 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-06-26 09:43:11 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-06-26 09:42:41 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-06-26 09:43:10 | -1.7 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-06-26 12:02:05 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-06-26 12:04:35 | -4.1 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

