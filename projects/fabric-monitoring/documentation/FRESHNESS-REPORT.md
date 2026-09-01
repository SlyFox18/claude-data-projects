# Data Freshness Report

**Generated:** 2026-09-01 08:02:03
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 79 | 76% |
| Stale | 0 | 0% |
| Critical | 13 | 12.5% |

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
- **df_NonJD_Parts_Ordering_Raw** (RawSource) - Last refreshed: 2026-08-04 12:05:30 (667.9 hours ago)
- **df_Fact_PriceUpdate_Enriched** (FactTable) - Last refreshed: 2026-08-11 16:05:21 (495.9 hours ago)
- **df_InMaster_Parts_Ordering_Raw** (RawSource) - Last refreshed: 2026-08-17 19:46:00 (348.3 hours ago)
- **df_Fact_ServiceRecommendations** (FactTable) - Last refreshed: 2026-08-21 15:56:04 (256.1 hours ago)
- **df_GlMaster_Raw** (RawSource) - Last refreshed: 2026-08-24 13:57:10 (186.1 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_Part | 2026-09-01 09:45:06 | -1.7 | [OK] Fresh |
| df_Dim_Date | 2026-09-01 09:41:37 | -1.7 | [OK] Fresh |
| df_Dim_Customer | 2026-09-01 09:41:37 | -1.7 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-09-01 09:41:37 | -1.7 | [OK] Fresh |
| df_Dim_Technicans | 2026-09-01 09:47:16 | -1.8 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-09-01 09:46:46 | -1.8 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-09-01 09:47:16 | -1.8 | [OK] Fresh |
| df_Dim_JobCode | 2026-09-01 09:46:48 | -1.8 | [OK] Fresh |
| df_Dim_Salesperson | 2026-09-01 09:46:46 | -1.8 | [OK] Fresh |
| df_Dim_BranchUserAccess | 2026-09-01 10:02:13 | -2 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-09-01 12:36:48 | -4.6 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_PriceUpdate_Enriched | 2026-08-11 16:05:21 | 495.9 | [CRIT] Critical |
| df_Fact_ServiceRecommendations | 2026-08-21 15:56:04 | 256.1 | [CRIT] Critical |
| df_Fact_ServiceTimeSheet_Audit | 2026-08-31 14:18:02 | 17.7 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-09-01 09:50:09 | -1.8 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-09-01 09:50:09 | -1.8 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-09-01 09:50:09 | -1.8 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-09-01 09:50:41 | -1.8 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-09-01 09:49:09 | -1.8 | [OK] Fresh |
| df_Fact_Inventory | 2026-09-01 09:49:39 | -1.8 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-09-01 09:53:24 | -1.9 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-09-01 09:57:31 | -1.9 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-09-01 09:52:54 | -1.9 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-09-01 09:52:56 | -1.9 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-09-01 09:52:55 | -1.9 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-09-01 09:52:55 | -1.9 | [OK] Fresh |
| df_Fact_Transfers | 2026-09-01 10:04:06 | -2 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-09-01 10:03:35 | -2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-09-01 09:59:42 | -2 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-09-01 10:04:01 | -2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-09-01 09:59:42 | -2 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-09-01 10:04:37 | -2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-09-01 09:59:12 | -2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-09-01 10:00:42 | -2 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-09-01 10:04:30 | -2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-09-01 09:59:43 | -2 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-09-01 10:07:45 | -2.1 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-09-01 10:07:16 | -2.1 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-09-01 10:07:46 | -2.1 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-09-01 10:06:46 | -2.1 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-09-01 10:05:00 | -2.1 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-09-01 10:06:45 | -2.1 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-09-01 10:07:16 | -2.1 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-09-01 12:32:08 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_NonJD_Parts_Ordering_Raw | 2026-08-04 12:05:30 | 667.9 | [CRIT] Critical |
| df_InMaster_Parts_Ordering_Raw | 2026-08-17 19:46:00 | 348.3 | [CRIT] Critical |
| df_GlMaster_Raw | 2026-08-24 13:57:10 | 186.1 | [CRIT] Critical |
| df_ServiceTimeSheets_Raw | 2026-08-31 14:02:45 | 18 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-09-01 09:19:24 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-09-01 09:19:23 | -1.3 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-09-01 09:22:54 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-09-01 09:19:53 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-09-01 09:17:53 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-09-01 09:18:54 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-09-01 09:21:23 | -1.3 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-09-01 09:25:36 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-09-01 09:25:06 | -1.4 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-09-01 09:28:14 | -1.4 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-09-01 09:25:06 | -1.4 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-09-01 09:25:06 | -1.4 | [OK] Fresh |
| df_InMaster_Raw | 2026-09-01 09:25:06 | -1.4 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-09-01 09:30:26 | -1.5 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-09-01 09:30:57 | -1.5 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-09-01 09:32:40 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-09-01 09:33:10 | -1.5 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-09-01 09:33:11 | -1.5 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-09-01 09:29:56 | -1.5 | [OK] Fresh |
| df_VhTrans_Raw | 2026-09-01 09:34:10 | -1.5 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-09-01 09:32:41 | -1.5 | [OK] Fresh |
| df_INSALORD_Raw | 2026-09-01 09:29:57 | -1.5 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-09-01 09:33:10 | -1.5 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-09-01 09:30:26 | -1.5 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-09-01 09:29:57 | -1.5 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-09-01 09:33:43 | -1.5 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-09-01 09:35:53 | -1.6 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-09-01 09:35:53 | -1.6 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-09-01 09:35:53 | -1.6 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-09-01 09:35:53 | -1.6 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-09-01 09:35:53 | -1.6 | [OK] Fresh |
| df_WarClaim_Raw | 2026-09-01 09:35:53 | -1.6 | [OK] Fresh |
| df_Technician_Raw | 2026-09-01 09:35:53 | -1.6 | [OK] Fresh |
| df_CONTACT_Raw | 2026-09-01 09:35:53 | -1.6 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-09-01 09:35:53 | -1.6 | [OK] Fresh |
| df_InMaster_PartsLookup_Raw | 2026-09-01 12:52:00 | -4.8 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

