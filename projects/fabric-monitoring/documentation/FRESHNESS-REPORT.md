# Data Freshness Report

**Generated:** 2026-08-24 08:01:33
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 76 | 73.1% |
| Stale | 3 | 2.9% |
| Critical | 12 | 11.5% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Never refreshed!
- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!
- **df_Dim_PartDemands** (Dimension) - Never refreshed!
- **df_Fact_JobCodePartFrequency** (FactTable) - Never refreshed!
- **df_Dim_WkCodeFl** (Dimension) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Never refreshed!
- **df_NonJD_Parts_Ordering_Raw** (RawSource) - Last refreshed: 2026-08-04 12:05:30 (475.9 hours ago)
- **df_Fact_PriceUpdate_Enriched** (FactTable) - Last refreshed: 2026-08-11 16:05:21 (303.9 hours ago)
- **df_InMaster_Parts_Ordering_Raw** (RawSource) - Last refreshed: 2026-08-17 19:46:00 (156.3 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-08-19 10:02:09 (118 hours ago)

---

## Stale - Monitor Closely

The following dataflows are approaching staleness:

- **df_ServiceTimeSheets_Raw** (RawSource) - Last refreshed: 2026-08-21 14:02:38 (66 hours ago)
- **df_Fact_ServiceTimeSheet_Audit** (FactTable) - Last refreshed: 2026-08-21 14:20:04 (65.7 hours ago)
- **df_Fact_ServiceRecommendations** (FactTable) - Last refreshed: 2026-08-21 15:56:04 (64.1 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_BranchUserAccess | 2026-08-19 10:02:09 | 118 | [CRIT] Critical |
| df_Dim_Date | 2026-08-24 09:48:41 | -1.8 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-08-24 09:48:12 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-08-24 09:49:10 | -1.8 | [OK] Fresh |
| df_Dim_Technicans | 2026-08-24 09:56:51 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-08-24 09:56:51 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-08-24 09:56:50 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-08-24 09:57:20 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-08-24 09:55:10 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-08-24 09:59:26 | -2 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-08-24 09:58:21 | -2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_PriceUpdate_Enriched | 2026-08-11 16:05:21 | 303.9 | [CRIT] Critical |
| df_Fact_ServiceTimeSheet_Audit | 2026-08-21 14:20:04 | 65.7 | [WARN] Stale |
| df_Fact_ServiceRecommendations | 2026-08-21 15:56:04 | 64.1 | [WARN] Stale |
| df_Fact_Service_Detail | 2026-08-24 10:04:18 | -2 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-08-24 10:02:49 | -2 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-08-24 10:01:48 | -2 | [OK] Fresh |
| df_Fact_Inventory | 2026-08-24 10:02:18 | -2 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-08-24 10:08:04 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-08-24 10:08:30 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-08-24 10:05:19 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-08-24 10:09:31 | -2.1 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-08-24 10:09:15 | -2.1 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-08-24 10:08:32 | -2.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-08-24 10:05:48 | -2.1 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-08-24 10:13:35 | -2.2 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-08-24 10:15:49 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-08-24 10:13:06 | -2.2 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-08-24 10:15:49 | -2.2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-08-24 10:10:33 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-08-24 10:15:50 | -2.2 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-08-24 10:15:51 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-08-24 10:13:37 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-08-24 10:15:50 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-08-24 10:13:36 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-08-24 10:13:06 | -2.2 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-08-24 10:22:05 | -2.3 | [OK] Fresh |
| df_Fact_Transfers | 2026-08-24 10:19:21 | -2.3 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-08-24 10:21:35 | -2.3 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-08-24 10:21:34 | -2.3 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-08-24 10:21:35 | -2.3 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-08-24 10:21:34 | -2.3 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-08-24 10:21:36 | -2.3 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-08-24 12:32:28 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_NonJD_Parts_Ordering_Raw | 2026-08-04 12:05:30 | 475.9 | [CRIT] Critical |
| df_InMaster_Parts_Ordering_Raw | 2026-08-17 19:46:00 | 156.3 | [CRIT] Critical |
| df_ServiceTimeSheets_Raw | 2026-08-21 14:02:38 | 66 | [WARN] Stale |
| df_InHist_PmManage_Raw | 2026-08-24 09:21:44 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-08-24 09:22:14 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-08-24 09:18:14 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-08-24 09:20:44 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-08-24 09:23:14 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-08-24 09:24:14 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-08-24 09:30:15 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-08-24 09:32:55 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-08-24 09:33:26 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-08-24 09:33:26 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-08-24 09:32:25 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-08-24 09:32:56 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-08-24 09:33:56 | -1.5 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-08-24 09:40:19 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-08-24 09:40:19 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-08-24 09:40:19 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-08-24 09:37:06 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-08-24 09:38:07 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-08-24 09:36:07 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-08-24 09:36:07 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-08-24 09:36:06 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-08-24 09:36:06 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-08-24 09:40:19 | -1.6 | [OK] Fresh |
| df_CONTACT_Raw | 2026-08-24 09:43:02 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-08-24 09:43:02 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-08-24 09:42:32 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-08-24 09:43:02 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-08-24 09:43:02 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-08-24 09:43:02 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-08-24 09:42:32 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-08-24 09:40:49 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-08-24 09:43:02 | -1.7 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-08-24 09:40:48 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-08-24 09:42:31 | -1.7 | [OK] Fresh |
| df_VhTrans_Raw | 2026-08-24 09:40:49 | -1.7 | [OK] Fresh |
| df_InMaster_PartsLookup_Raw | 2026-08-24 12:53:28 | -4.9 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

