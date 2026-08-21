# Data Freshness Report

**Generated:** 2026-08-21 08:01:33
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 78 | 75% |
| Stale |  | 0% |
| Critical | 11 | 10.6% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!
- **df_Fact_JobCodePartFrequency** (FactTable) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Never refreshed!
- **df_Dim_PartDemands** (Dimension) - Never refreshed!
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Never refreshed!
- **df_Dim_WkCodeFl** (Dimension) - Never refreshed!
- **df_NonJD_Parts_Ordering_Raw** (RawSource) - Last refreshed: 2026-08-04 12:05:30 (403.9 hours ago)
- **df_Fact_PriceUpdate_Enriched** (FactTable) - Last refreshed: 2026-08-11 16:05:21 (231.9 hours ago)
- **df_InMaster_Parts_Ordering_Raw** (RawSource) - Last refreshed: 2026-08-17 19:46:00 (84.3 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_BranchUserAccess | 2026-08-19 10:02:09 | 46 | [WARN] Stale |
| df_Dim_Customer | 2026-08-21 09:52:14 | -1.8 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-08-21 09:51:45 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-08-21 09:51:44 | -1.8 | [OK] Fresh |
| df_Dim_Part | 2026-08-21 09:57:45 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-08-21 09:59:25 | -2 | [OK] Fresh |
| df_Dim_JobCode | 2026-08-21 09:59:55 | -2 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-08-21 09:59:55 | -2 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-08-21 09:59:55 | -2 | [OK] Fresh |
| df_Dim_Salesperson | 2026-08-21 09:59:55 | -2 | [OK] Fresh |
| df_Dim_Technicans | 2026-08-21 09:59:25 | -2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_PriceUpdate_Enriched | 2026-08-11 16:05:21 | 231.9 | [CRIT] Critical |
| df_Fact_ServiceTimeSheet_Audit | 2026-08-20 14:19:59 | 17.7 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-08-21 10:03:42 | -2 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-08-21 10:03:42 | -2 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-08-21 10:09:24 | -2.1 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-08-21 10:09:53 | -2.1 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-08-21 10:04:44 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-08-21 10:10:22 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-08-21 10:06:40 | -2.1 | [OK] Fresh |
| df_Fact_Inventory | 2026-08-21 10:04:43 | -2.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-08-21 10:05:41 | -2.1 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-08-21 10:09:53 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-08-21 10:09:24 | -2.1 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-08-21 10:16:18 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-08-21 10:13:37 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-08-21 10:13:07 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-08-21 10:13:37 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-08-21 10:14:08 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-08-21 10:16:18 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-08-21 10:16:19 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-08-21 10:13:37 | -2.2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-08-21 10:10:53 | -2.2 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-08-21 10:16:48 | -2.3 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-08-21 10:16:21 | -2.3 | [OK] Fresh |
| df_Fact_Transfers | 2026-08-21 10:20:18 | -2.3 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-08-21 10:23:32 | -2.4 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-08-21 10:22:32 | -2.4 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-08-21 10:22:34 | -2.4 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-08-21 10:22:38 | -2.4 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-08-21 10:22:34 | -2.4 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-08-21 10:22:32 | -2.4 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-08-21 12:32:39 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_NonJD_Parts_Ordering_Raw | 2026-08-04 12:05:30 | 403.9 | [CRIT] Critical |
| df_InMaster_Parts_Ordering_Raw | 2026-08-17 19:46:00 | 84.3 | [CRIT] Critical |
| df_ServiceTimeSheets_Raw | 2026-08-20 14:03:25 | 18 | [OK] Fresh |
| df_GlTrans_Raw | 2026-08-21 09:22:18 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-08-21 09:18:20 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-08-21 09:20:48 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-08-21 09:24:48 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-08-21 09:24:19 | -1.4 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-08-21 09:22:48 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-08-21 09:29:48 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-08-21 09:32:32 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-08-21 09:33:02 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-08-21 09:32:32 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-08-21 09:32:02 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-08-21 09:32:31 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-08-21 09:33:31 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-08-21 09:36:13 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-08-21 09:37:14 | -1.6 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-08-21 09:39:26 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-08-21 09:39:57 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-08-21 09:39:56 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-08-21 09:35:43 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-08-21 09:39:56 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-08-21 09:39:26 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-08-21 09:35:43 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-08-21 09:39:27 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-08-21 09:35:13 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-08-21 09:35:43 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-08-21 09:39:26 | -1.6 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-08-21 09:42:10 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-08-21 09:41:41 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-08-21 09:42:10 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-08-21 09:42:10 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-08-21 09:42:11 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-08-21 09:41:40 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-08-21 09:42:11 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-08-21 09:45:19 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-08-21 09:41:41 | -1.7 | [OK] Fresh |
| df_InMaster_PartsLookup_Raw | 2026-08-21 12:53:28 | -4.9 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

