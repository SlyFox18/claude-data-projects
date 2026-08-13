# Data Freshness Report

**Generated:** 2026-08-13 08:01:31
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 78 | 75.7% |
| Stale |  | 0% |
| Critical | 12 | 11.7% |

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
- **df_InMaster_Parts_Ordering_Raw** (RawSource) - Last refreshed: 2026-08-04 12:02:29 (212 hours ago)
- **df_NonJD_Parts_Ordering_Raw** (RawSource) - Last refreshed: 2026-08-04 12:05:30 (211.9 hours ago)
- **df_InMaster_PartsLookup_Raw** (RawSource) - Last refreshed: 2026-08-07 12:43:53 (139.3 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_BranchUserAccess | 2026-08-12 10:02:40 | 22 | [OK] Fresh |
| df_Dim_Customer | 2026-08-13 09:50:49 | -1.8 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-08-13 09:50:20 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-08-13 09:50:19 | -1.8 | [OK] Fresh |
| df_Dim_Part | 2026-08-13 09:56:50 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-08-13 09:58:30 | -2 | [OK] Fresh |
| df_Dim_JobCode | 2026-08-13 09:59:01 | -2 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-08-13 09:59:01 | -2 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-08-13 10:03:31 | -2 | [OK] Fresh |
| df_Dim_Salesperson | 2026-08-13 09:58:31 | -2 | [OK] Fresh |
| df_Dim_Technicans | 2026-08-13 09:59:00 | -2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_PriceUpdate_Enriched | 2026-08-11 16:05:21 | 39.9 | [WARN] Stale |
| df_Fact_ServiceTimeSheet_Audit | 2026-08-12 14:20:01 | 17.7 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-08-13 10:05:55 | -2.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-08-13 10:07:58 | -2.1 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-08-13 10:08:25 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-08-13 10:09:28 | -2.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-08-13 10:07:57 | -2.1 | [OK] Fresh |
| df_Fact_Inventory | 2026-08-13 10:06:57 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-08-13 10:11:40 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-08-13 10:13:10 | -2.2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-08-13 10:14:12 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-08-13 10:12:11 | -2.2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-08-13 10:12:11 | -2.2 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-08-13 10:12:10 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-08-13 10:17:24 | -2.3 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-08-13 10:19:36 | -2.3 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-08-13 10:16:24 | -2.3 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-08-13 10:19:35 | -2.3 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-08-13 10:16:25 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-08-13 10:19:36 | -2.3 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-08-13 10:20:15 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-08-13 10:19:36 | -2.3 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-08-13 10:16:24 | -2.3 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-08-13 10:16:54 | -2.3 | [OK] Fresh |
| df_Fact_Transfers | 2026-08-13 10:23:35 | -2.4 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-08-13 10:26:19 | -2.4 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-08-13 10:25:49 | -2.4 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-08-13 10:25:49 | -2.4 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-08-13 10:25:50 | -2.4 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-08-13 10:25:49 | -2.4 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-08-13 10:25:19 | -2.4 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-08-13 12:32:39 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_InMaster_Parts_Ordering_Raw | 2026-08-04 12:02:29 | 212 | [CRIT] Critical |
| df_NonJD_Parts_Ordering_Raw | 2026-08-04 12:05:30 | 211.9 | [CRIT] Critical |
| df_InMaster_PartsLookup_Raw | 2026-08-07 12:43:53 | 139.3 | [CRIT] Critical |
| df_ServiceTimeSheets_Raw | 2026-08-12 14:04:43 | 17.9 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-08-13 09:18:14 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-08-13 09:21:44 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-08-13 09:20:44 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-08-13 09:25:44 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-08-13 09:24:14 | -1.4 | [OK] Fresh |
| df_GlTrans_Raw | 2026-08-13 09:23:14 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-08-13 09:30:44 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-08-13 09:34:08 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-08-13 09:33:26 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-08-13 09:32:56 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-08-13 09:32:57 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-08-13 09:33:27 | -1.5 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-08-13 09:37:10 | -1.6 | [OK] Fresh |
| df_InMaster_Raw | 2026-08-13 09:34:58 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-08-13 09:38:40 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-08-13 09:39:10 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-08-13 09:36:41 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-08-13 09:36:51 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-08-13 09:37:21 | -1.6 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-08-13 09:44:13 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-08-13 09:43:43 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-08-13 09:44:13 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-08-13 09:44:14 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-08-13 09:43:44 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-08-13 09:44:13 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-08-13 09:44:13 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-08-13 09:43:44 | -1.7 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-08-13 09:41:31 | -1.7 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-08-13 09:41:31 | -1.7 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-08-13 09:41:35 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-08-13 09:44:14 | -1.7 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-08-13 09:42:01 | -1.7 | [OK] Fresh |
| df_VhTrans_Raw | 2026-08-13 09:41:31 | -1.7 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-08-13 09:41:30 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-08-13 09:41:31 | -1.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

