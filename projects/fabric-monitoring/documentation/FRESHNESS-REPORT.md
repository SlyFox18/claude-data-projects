# Data Freshness Report

**Generated:** 2026-08-31 08:11:10
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 76 | 73.1% |
| Stale | 2 | 1.9% |
| Critical | 14 | 13.5% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Fact_JobCodePartFrequency** (FactTable) - Never refreshed!
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Never refreshed!
- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Dim_PartDemands** (Dimension) - Never refreshed!
- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!
- **df_Dim_WkCodeFl** (Dimension) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Never refreshed!
- **df_NonJD_Parts_Ordering_Raw** (RawSource) - Last refreshed: 2026-08-04 12:05:30 (644.1 hours ago)
- **df_Fact_PriceUpdate_Enriched** (FactTable) - Last refreshed: 2026-08-11 16:05:21 (472.1 hours ago)
- **df_InMaster_Parts_Ordering_Raw** (RawSource) - Last refreshed: 2026-08-17 19:46:00 (324.4 hours ago)
- **df_Fact_ServiceRecommendations** (FactTable) - Last refreshed: 2026-08-21 15:56:04 (232.2 hours ago)
- **df_GlMaster_Raw** (RawSource) - Last refreshed: 2026-08-24 13:57:10 (162.2 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-08-26 10:02:17 (118.1 hours ago)

---

## Stale - Monitor Closely

The following dataflows are approaching staleness:

- **df_ServiceTimeSheets_Raw** (RawSource) - Last refreshed: 2026-08-28 14:02:42 (66.1 hours ago)
- **df_Fact_ServiceTimeSheet_Audit** (FactTable) - Last refreshed: 2026-08-28 14:21:01 (65.8 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_BranchUserAccess | 2026-08-26 10:02:17 | 118.1 | [CRIT] Critical |
| df_Dim_Date | 2026-08-31 09:41:46 | -1.5 | [OK] Fresh |
| df_Dim_Customer | 2026-08-31 09:41:45 | -1.5 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-08-31 09:41:15 | -1.5 | [OK] Fresh |
| df_Dim_Technicans | 2026-08-31 09:48:02 | -1.6 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-08-31 09:47:27 | -1.6 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-08-31 09:47:27 | -1.6 | [OK] Fresh |
| df_Dim_Part | 2026-08-31 09:45:46 | -1.6 | [OK] Fresh |
| df_Dim_JobCode | 2026-08-31 09:47:26 | -1.6 | [OK] Fresh |
| df_Dim_Salesperson | 2026-08-31 09:47:27 | -1.6 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-08-31 09:47:57 | -1.6 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_PriceUpdate_Enriched | 2026-08-11 16:05:21 | 472.1 | [CRIT] Critical |
| df_Fact_ServiceRecommendations | 2026-08-21 15:56:04 | 232.2 | [CRIT] Critical |
| df_Fact_ServiceTimeSheet_Audit | 2026-08-28 14:21:01 | 65.8 | [WARN] Stale |
| df_FactPartTransactions_Incremental | 2026-08-31 09:50:26 | -1.7 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-08-31 09:50:56 | -1.7 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-08-31 09:52:55 | -1.7 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-08-31 09:50:55 | -1.7 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-08-31 09:55:06 | -1.7 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-08-31 09:51:25 | -1.7 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-08-31 09:55:36 | -1.7 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-08-31 09:55:06 | -1.7 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-08-31 09:55:36 | -1.7 | [OK] Fresh |
| df_Fact_Inventory | 2026-08-31 09:50:26 | -1.7 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-08-31 09:55:06 | -1.7 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-08-31 09:55:05 | -1.7 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-08-31 10:01:27 | -1.8 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-08-31 09:59:28 | -1.8 | [OK] Fresh |
| df_Fact_Transfers | 2026-08-31 10:00:58 | -1.8 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-08-31 09:57:16 | -1.8 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-08-31 09:59:27 | -1.8 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-08-31 09:59:57 | -1.8 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-08-31 09:59:28 | -1.8 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-08-31 09:57:47 | -1.8 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-08-31 09:57:16 | -1.8 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-08-31 09:57:46 | -1.8 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-08-31 09:57:46 | -1.8 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-08-31 10:05:54 | -1.9 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-08-31 10:04:15 | -1.9 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-08-31 10:05:17 | -1.9 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-08-31 10:05:44 | -1.9 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-08-31 10:05:48 | -1.9 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-08-31 10:04:16 | -1.9 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-08-31 12:32:10 | -4.4 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_NonJD_Parts_Ordering_Raw | 2026-08-04 12:05:30 | 644.1 | [CRIT] Critical |
| df_InMaster_Parts_Ordering_Raw | 2026-08-17 19:46:00 | 324.4 | [CRIT] Critical |
| df_GlMaster_Raw | 2026-08-24 13:57:10 | 162.2 | [CRIT] Critical |
| df_ServiceTimeSheets_Raw | 2026-08-28 14:02:42 | 66.1 | [WARN] Stale |
| df_Invoice_Raw | 2026-08-31 09:19:18 | -1.1 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-08-31 09:19:18 | -1.1 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-08-31 09:17:48 | -1.1 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-08-31 09:19:18 | -1.1 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-08-31 09:18:49 | -1.1 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-08-31 09:24:59 | -1.2 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-08-31 09:22:48 | -1.2 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-08-31 09:24:59 | -1.2 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-08-31 09:24:59 | -1.2 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-08-31 09:25:00 | -1.2 | [OK] Fresh |
| df_InMaster_Raw | 2026-08-31 09:25:00 | -1.2 | [OK] Fresh |
| df_GlTrans_Raw | 2026-08-31 09:20:48 | -1.2 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-08-31 09:31:15 | -1.3 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-08-31 09:29:17 | -1.3 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-08-31 09:29:45 | -1.3 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-08-31 09:30:16 | -1.3 | [OK] Fresh |
| df_INSALORD_Raw | 2026-08-31 09:29:17 | -1.3 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-08-31 09:29:15 | -1.3 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-08-31 09:27:36 | -1.3 | [OK] Fresh |
| df_VhTrans_Raw | 2026-08-31 09:33:07 | -1.4 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-08-31 09:35:48 | -1.4 | [OK] Fresh |
| df_WarClaim_Raw | 2026-08-31 09:36:26 | -1.4 | [OK] Fresh |
| df_CONTACT_Raw | 2026-08-31 09:35:48 | -1.4 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-08-31 09:35:48 | -1.4 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-08-31 09:36:18 | -1.4 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-08-31 09:36:18 | -1.4 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-08-31 09:35:48 | -1.4 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-08-31 09:33:38 | -1.4 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-08-31 09:33:36 | -1.4 | [OK] Fresh |
| df_Technician_Raw | 2026-08-31 09:36:18 | -1.4 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-08-31 09:33:07 | -1.4 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-08-31 09:35:48 | -1.4 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-08-31 09:33:36 | -1.4 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-08-31 09:33:36 | -1.4 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-08-31 09:34:07 | -1.4 | [OK] Fresh |
| df_InMaster_PartsLookup_Raw | 2026-08-31 12:51:58 | -4.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

