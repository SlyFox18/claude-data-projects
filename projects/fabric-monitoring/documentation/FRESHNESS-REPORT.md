# Data Freshness Report

**Generated:** 2026-08-11 08:01:36
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 77 | 75.5% |
| Stale | 0 | 0% |
| Critical | 12 | 11.8% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_GlMaster_Raw** (RawSource) - Never refreshed!
- **df_Fact_JobCodePartFrequency** (FactTable) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Never refreshed!
- **df_Dim_PartDemands** (Dimension) - Never refreshed!
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Never refreshed!
- **df_Dim_WkCodeFl** (Dimension) - Never refreshed!
- **df_InMaster_Parts_Ordering_Raw** (RawSource) - Last refreshed: 2026-08-04 12:02:29 (164 hours ago)
- **df_NonJD_Parts_Ordering_Raw** (RawSource) - Last refreshed: 2026-08-04 12:05:30 (163.9 hours ago)
- **df_InMaster_PartsLookup_Raw** (RawSource) - Last refreshed: 2026-08-07 12:43:53 (91.3 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_Part | Error | 0 | [?] Error |
| df_Dim_Customer | 2026-08-11 09:48:47 | -1.8 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-08-11 09:47:46 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-08-11 09:48:15 | -1.8 | [OK] Fresh |
| df_Dim_Technicans | 2026-08-11 09:56:31 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-08-11 09:56:29 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-08-11 09:56:30 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-08-11 09:56:58 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-08-11 09:56:28 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-08-11 09:58:28 | -2 | [OK] Fresh |
| df_Dim_BranchUserAccess | 2026-08-11 10:02:08 | -2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceTimeSheet_Audit | 2026-08-10 14:19:38 | 17.7 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-08-11 10:02:25 | -2 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-08-11 10:01:56 | -2 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-08-11 10:00:56 | -2 | [OK] Fresh |
| df_Fact_Inventory | 2026-08-11 10:01:55 | -2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-08-11 10:04:27 | -2.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-08-11 10:10:28 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-08-11 10:12:42 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-08-11 10:14:10 | -2.2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-08-11 10:15:12 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-08-11 10:13:40 | -2.2 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-08-11 10:14:41 | -2.2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-08-11 10:13:12 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-08-11 10:18:25 | -2.3 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-08-11 10:20:36 | -2.3 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-08-11 10:17:28 | -2.3 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-08-11 10:17:55 | -2.3 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-08-11 10:20:38 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-08-11 10:20:37 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-08-11 10:21:10 | -2.3 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-08-11 10:17:56 | -2.3 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-08-11 10:17:26 | -2.3 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-08-11 10:25:08 | -2.4 | [OK] Fresh |
| df_Fact_Transfers | 2026-08-11 10:53:09 | -2.9 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-08-11 10:56:43 | -2.9 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-08-11 10:55:44 | -2.9 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-08-11 10:56:13 | -2.9 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-08-11 10:55:44 | -2.9 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-08-11 10:55:43 | -2.9 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-08-11 10:55:44 | -2.9 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-08-11 12:32:37 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_InMaster_Parts_Ordering_Raw | 2026-08-04 12:02:29 | 164 | [CRIT] Critical |
| df_NonJD_Parts_Ordering_Raw | 2026-08-04 12:05:30 | 163.9 | [CRIT] Critical |
| df_InMaster_PartsLookup_Raw | 2026-08-07 12:43:53 | 91.3 | [CRIT] Critical |
| df_ServiceTimeSheets_Raw | 2026-08-10 14:03:10 | 18 | [OK] Fresh |
| df_GlTrans_Raw | 2026-08-11 09:22:26 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-08-11 09:21:56 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-08-11 09:17:56 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-08-11 09:20:56 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-08-11 09:24:26 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-08-11 09:23:26 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-08-11 09:29:56 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-08-11 09:32:39 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-08-11 09:32:39 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-08-11 09:32:39 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-08-11 09:32:08 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-08-11 09:32:38 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-08-11 09:33:39 | -1.5 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-08-11 09:39:33 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-08-11 09:36:51 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-08-11 09:37:21 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-08-11 09:40:03 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-08-11 09:39:33 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-08-11 09:40:03 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-08-11 09:35:51 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-08-11 09:35:21 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-08-11 09:39:32 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-08-11 09:35:21 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-08-11 09:35:51 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-08-11 09:39:02 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-08-11 09:39:33 | -1.6 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-08-11 09:42:16 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-08-11 09:42:16 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-08-11 09:42:16 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-08-11 09:42:16 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-08-11 09:41:46 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-08-11 09:41:46 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-08-11 09:42:16 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-08-11 09:42:16 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-08-11 09:41:46 | -1.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

