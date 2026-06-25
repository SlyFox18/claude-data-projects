# Data Freshness Report

**Generated:** 2026-06-25 08:01:23
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 75 | 75% |
| Stale | 0 | 0% |
| Critical | 8 | 8% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Fact_JobCodePartFrequency** (FactTable) - Never refreshed!
- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!
- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Never refreshed!
- **df_Dim_WkCodeFl** (Dimension) - Never refreshed!
- **df_Dim_Franchise** (Dimension) - Last refreshed: 2026-06-01 12:33:08 (571.5 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_Franchise | 2026-06-01 12:33:08 | 571.5 | [CRIT] Critical |
| df_Dim_BranchUserAccess | 2026-06-24 10:01:59 | 22 | [OK] Fresh |
| df_Dim_Customer | 2026-06-24 15:03:17 | 17 | [OK] Fresh |
| df_Dim_Date | 2026-06-24 15:02:19 | 17 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-06-24 15:08:30 | 16.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-06-24 15:08:58 | 16.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-06-24 15:08:58 | 16.9 | [OK] Fresh |
| df_Dim_Part | 2026-06-24 15:05:21 | 16.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-06-24 15:08:59 | 16.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-06-24 15:10:08 | 16.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-06-24 15:12:38 | 16.8 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceTimeSheet_Audit | 2026-06-24 14:18:58 | 17.7 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-06-24 15:15:03 | 16.8 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-06-24 15:20:03 | 16.7 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-06-24 15:20:03 | 16.7 | [OK] Fresh |
| df_Fact_Inventory | 2026-06-24 15:20:03 | 16.7 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-06-24 15:18:32 | 16.7 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-06-24 15:21:03 | 16.7 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-06-24 15:25:45 | 16.6 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-06-24 15:24:44 | 16.6 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-06-24 15:24:45 | 16.6 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-06-24 15:27:57 | 16.6 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-06-24 15:25:23 | 16.6 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-06-24 15:25:15 | 16.6 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-06-24 15:25:15 | 16.6 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-06-24 15:28:24 | 16.5 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-06-24 15:31:07 | 16.5 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-06-24 15:28:25 | 16.5 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-06-24 15:31:38 | 16.5 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-06-24 15:31:08 | 16.5 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-06-24 15:31:10 | 16.5 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-06-24 15:31:08 | 16.5 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-06-24 15:28:55 | 16.5 | [OK] Fresh |
| df_Fact_Transfers | 2026-06-24 15:34:38 | 16.4 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-06-24 15:37:53 | 16.4 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-06-24 15:36:52 | 16.4 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-06-24 15:36:53 | 16.4 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-06-24 15:36:54 | 16.4 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-06-24 15:36:51 | 16.4 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-06-24 15:40:48 | 16.3 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-06-24 16:17:57 | 15.7 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-06-25 12:33:27 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-06-24 14:01:57 | 18 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-06-24 14:44:16 | 17.3 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-06-24 14:45:15 | 17.3 | [OK] Fresh |
| df_InMaster_Raw | 2026-06-24 14:46:45 | 17.2 | [OK] Fresh |
| df_INSALORD_Raw | 2026-06-24 14:48:58 | 17.2 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-06-24 14:50:59 | 17.2 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-06-24 14:48:59 | 17.2 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-06-24 14:49:29 | 17.2 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-06-24 14:48:58 | 17.2 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-06-24 14:48:58 | 17.2 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-06-24 14:53:11 | 17.1 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-06-24 14:54:11 | 17.1 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-06-24 14:54:41 | 17.1 | [OK] Fresh |
| df_Technician_Raw | 2026-06-24 14:56:57 | 17.1 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-06-24 14:53:41 | 17.1 | [OK] Fresh |
| df_VhTrans_Raw | 2026-06-24 14:53:42 | 17.1 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-06-24 14:53:42 | 17.1 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-06-24 14:56:57 | 17.1 | [OK] Fresh |
| df_WarClaim_Raw | 2026-06-24 14:56:27 | 17.1 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-06-24 14:53:41 | 17.1 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-06-24 14:56:57 | 17.1 | [OK] Fresh |
| df_CONTACT_Raw | 2026-06-24 14:56:57 | 17.1 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-06-24 14:56:27 | 17.1 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-06-24 14:56:57 | 17.1 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-06-24 14:56:57 | 17.1 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-06-24 14:56:57 | 17.1 | [OK] Fresh |
| df_WKRODESC_Raw | Error | 0 | [?] Error |
| df_WKROFILE_Raw | Error | 0 | [?] Error |
| df_WKVEHFL_Raw | Error | 0 | [?] Error |
| df_JDIS_PART_INFORMATION_Raw | Error | 0 | [?] Error |
| df_InHist_PmManage_Raw | 2026-06-25 09:22:18 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-06-25 09:18:18 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-06-25 09:22:48 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-06-25 09:25:49 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-06-25 09:24:48 | -1.4 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-06-25 12:03:28 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-06-25 12:05:26 | -4.1 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-06-25 13:00:45 | -5 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

