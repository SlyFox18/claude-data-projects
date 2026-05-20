# Data Freshness Report

**Generated:** 2026-05-20 08:01:32
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 81 | 83.5% |
| Stale | 0 | 0% |
| Critical | 4 | 4.1% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_GlMaster_Raw** (RawSource) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Last refreshed: 2026-05-06 15:04:38 (328.9 hours ago)
- **df_Dim_WkCodeFl** (Dimension) - Last refreshed: 2026-05-06 15:26:40 (328.6 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | 2026-05-06 15:04:38 | 328.9 | [CRIT] Critical |
| df_Dim_WkCodeFl | 2026-05-06 15:26:40 | 328.6 | [CRIT] Critical |
| df_Dim_Date | 2026-05-20 09:49:41 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-05-20 09:50:11 | -1.8 | [OK] Fresh |
| df_Dim_Technicans | 2026-05-20 09:54:51 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-05-20 09:54:50 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-05-20 09:55:01 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-05-20 09:54:50 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-05-20 09:54:50 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-05-20 09:52:41 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-05-20 09:55:51 | -1.9 | [OK] Fresh |
| df_Dim_BranchUserAccess | 2026-05-20 10:01:58 | -2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_ServiceTimeSheet_Audit | 2026-05-19 22:06:56 | 9.9 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-05-20 09:58:22 | -1.9 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-05-20 10:03:52 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-05-20 10:02:22 | -2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-05-20 10:03:52 | -2 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-05-20 10:04:22 | -2 | [OK] Fresh |
| df_Fact_Inventory | 2026-05-20 10:02:52 | -2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-05-20 10:09:44 | -2.1 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-05-20 10:09:28 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-05-20 10:08:31 | -2.1 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-05-20 10:09:33 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-05-20 10:09:02 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-05-20 10:09:25 | -2.1 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-05-20 10:12:06 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-05-20 10:13:14 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-05-20 10:12:37 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-05-20 10:12:14 | -2.2 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-05-20 10:15:51 | -2.2 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-05-20 10:16:20 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-05-20 10:13:11 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-05-20 10:16:20 | -2.2 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-05-20 10:16:50 | -2.3 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-05-20 10:22:07 | -2.3 | [OK] Fresh |
| df_Fact_Transfers | 2026-05-20 10:19:50 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-05-20 10:16:23 | -2.3 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-05-20 10:23:07 | -2.4 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-05-20 10:22:37 | -2.4 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-05-20 10:22:43 | -2.4 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-05-20 10:22:38 | -2.4 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-05-20 10:22:39 | -2.4 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-05-20 12:33:30 | -4.5 | [OK] Fresh |
| df_Fact_OpenOrderParts | 2026-05-20 12:50:38 | -4.8 | [OK] Fresh |
| df_Fact_OpenOrders | 2026-05-20 12:50:41 | -4.8 | [OK] Fresh |
| df_Fact_JobCodePartFrequency | 2026-05-20 12:54:14 | -4.9 | [OK] Fresh |
| df_Fact_JobCodeFrequency_Branch | 2026-05-20 12:55:53 | -4.9 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-05-19 21:41:06 | 10.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-05-20 09:20:14 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-05-20 09:21:44 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-05-20 09:17:44 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-05-20 09:23:14 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-05-20 09:27:44 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-05-20 09:23:44 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-05-20 09:23:44 | -1.4 | [OK] Fresh |
| df_INSALORD_Raw | 2026-05-20 09:34:18 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-05-20 09:30:25 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-05-20 09:30:26 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-05-20 09:29:54 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-05-20 09:30:55 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-05-20 09:32:25 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-05-20 09:29:56 | -1.5 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-05-20 09:36:42 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-05-20 09:35:36 | -1.6 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-05-20 09:39:20 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-05-20 09:39:21 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-05-20 09:39:21 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-05-20 09:34:37 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-05-20 09:34:38 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-05-20 09:34:37 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-05-20 09:38:50 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-05-20 09:38:50 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-05-20 09:39:20 | -1.6 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-05-20 09:43:32 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-05-20 09:43:03 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-05-20 09:43:34 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-05-20 09:44:02 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-05-20 09:44:03 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-05-20 09:40:51 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-05-20 09:43:33 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-05-20 09:43:33 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-05-20 09:43:33 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-05-20 09:43:33 | -1.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

