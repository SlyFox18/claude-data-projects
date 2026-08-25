# Data Freshness Report

**Generated:** 2026-08-25 08:01:32
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 80 | 76.9% |
| Stale | 0 | 0% |
| Critical | 12 | 11.5% |

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
- **df_NonJD_Parts_Ordering_Raw** (RawSource) - Last refreshed: 2026-08-04 12:05:30 (499.9 hours ago)
- **df_Fact_PriceUpdate_Enriched** (FactTable) - Last refreshed: 2026-08-11 16:05:21 (327.9 hours ago)
- **df_InMaster_Parts_Ordering_Raw** (RawSource) - Last refreshed: 2026-08-17 19:46:00 (180.3 hours ago)
- **df_Fact_ServiceRecommendations** (FactTable) - Last refreshed: 2026-08-21 15:56:04 (88.1 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_Date | 2026-08-24 09:48:41 | 22.2 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-08-24 09:48:12 | 22.2 | [OK] Fresh |
| df_Dim_Customer | 2026-08-24 09:49:10 | 22.2 | [OK] Fresh |
| df_Dim_Salesperson | 2026-08-24 09:56:50 | 22.1 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-08-24 09:56:51 | 22.1 | [OK] Fresh |
| df_Dim_Technicans | 2026-08-24 09:56:51 | 22.1 | [OK] Fresh |
| df_Dim_Part | 2026-08-24 09:55:10 | 22.1 | [OK] Fresh |
| df_Dim_JobCode | 2026-08-24 09:57:20 | 22.1 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-08-24 09:59:26 | 22 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-08-24 09:58:21 | 22 | [OK] Fresh |
| df_Dim_BranchUserAccess | 2026-08-25 10:02:13 | -2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_PriceUpdate_Enriched | 2026-08-11 16:05:21 | 327.9 | [CRIT] Critical |
| df_Fact_ServiceRecommendations | 2026-08-21 15:56:04 | 88.1 | [CRIT] Critical |
| df_Fact_Service_Detail | 2026-08-24 10:04:18 | 22 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-08-24 10:02:49 | 22 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-08-24 10:01:48 | 22 | [OK] Fresh |
| df_Fact_Inventory | 2026-08-24 10:02:18 | 22 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-08-24 10:08:30 | 21.9 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-08-24 10:08:04 | 21.9 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-08-24 10:05:19 | 21.9 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-08-24 10:09:31 | 21.9 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-08-24 10:05:48 | 21.9 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-08-24 10:09:15 | 21.9 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-08-24 10:08:32 | 21.9 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-08-24 10:13:36 | 21.8 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-08-24 10:15:49 | 21.8 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-08-24 10:13:06 | 21.8 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-08-24 10:15:49 | 21.8 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-08-24 10:10:33 | 21.8 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-08-24 10:15:50 | 21.8 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-08-24 10:15:50 | 21.8 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-08-24 10:13:37 | 21.8 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-08-24 10:15:51 | 21.8 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-08-24 10:13:06 | 21.8 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-08-24 10:21:35 | 21.7 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-08-24 10:22:05 | 21.7 | [OK] Fresh |
| df_Fact_Transfers | 2026-08-24 10:19:21 | 21.7 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-08-24 10:21:34 | 21.7 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-08-24 10:21:34 | 21.7 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-08-24 10:21:35 | 21.7 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-08-24 10:21:36 | 21.7 | [OK] Fresh |
| df_Fact_ServiceTimeSheet_Audit | 2026-08-24 14:20:06 | 17.7 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-08-24 16:18:12 | 15.7 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-08-25 12:32:09 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_NonJD_Parts_Ordering_Raw | 2026-08-04 12:05:30 | 499.9 | [CRIT] Critical |
| df_InMaster_Parts_Ordering_Raw | 2026-08-17 19:46:00 | 180.3 | [CRIT] Critical |
| df_WKVEHFL_Raw | 2026-08-24 09:32:25 | 22.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-08-24 09:33:56 | 22.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-08-24 09:33:26 | 22.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-08-24 09:32:56 | 22.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-08-24 09:32:55 | 22.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-08-24 09:33:26 | 22.5 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-08-24 09:37:06 | 22.4 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-08-24 09:38:07 | 22.4 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-08-24 09:40:19 | 22.4 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-08-24 09:40:19 | 22.4 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-08-24 09:40:19 | 22.4 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-08-24 09:36:06 | 22.4 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-08-24 09:36:06 | 22.4 | [OK] Fresh |
| df_INSALORD_Raw | 2026-08-24 09:36:07 | 22.4 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-08-24 09:40:19 | 22.4 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-08-24 09:36:07 | 22.4 | [OK] Fresh |
| df_WarClaim_Raw | 2026-08-24 09:42:31 | 22.3 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-08-24 09:42:32 | 22.3 | [OK] Fresh |
| df_VhTrans_Raw | 2026-08-24 09:40:49 | 22.3 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-08-24 09:40:49 | 22.3 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-08-24 09:40:48 | 22.3 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-08-24 09:43:02 | 22.3 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-08-24 09:43:02 | 22.3 | [OK] Fresh |
| df_CONTACT_Raw | 2026-08-24 09:43:02 | 22.3 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-08-24 09:42:32 | 22.3 | [OK] Fresh |
| df_Technician_Raw | 2026-08-24 09:43:02 | 22.3 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-08-24 09:43:02 | 22.3 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-08-24 09:43:02 | 22.3 | [OK] Fresh |
| df_GlMaster_Raw | 2026-08-24 13:57:10 | 18.1 | [OK] Fresh |
| df_ServiceTimeSheets_Raw | 2026-08-24 14:05:41 | 17.9 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-08-25 09:21:37 | -1.3 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-08-25 09:27:06 | -1.4 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-08-25 09:23:05 | -1.4 | [OK] Fresh |
| df_GlTrans_Raw | 2026-08-25 09:23:05 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-08-25 09:23:06 | -1.4 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-08-25 09:23:04 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-08-25 09:22:38 | -1.4 | [OK] Fresh |
| df_InMaster_PartsLookup_Raw | 2026-08-25 12:56:25 | -4.9 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

