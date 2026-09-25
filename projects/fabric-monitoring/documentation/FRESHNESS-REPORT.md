# Data Freshness Report

**Generated:** 2026-09-25 08:01:24
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 78 | 75% |
| Stale | 0 | 0% |
| Critical | 12 | 11.5% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Fact_ServiceRecommendations** (FactTable) - Never refreshed!
- **df_Fact_PriceUpdate_Enriched** (FactTable) - Never refreshed!
- **df_GlMaster_Raw** (RawSource) - Never refreshed!
- **df_InMaster_Parts_Ordering_Raw** (RawSource) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_NonJD_Parts_Ordering_Raw** (RawSource) - Never refreshed!
- **df_Dim_WkCodeFl** (Dimension) - Never refreshed!
- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Never refreshed!
- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!
- **df_Fact_JobCodePartFrequency** (FactTable) - Never refreshed!
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-09-09 10:05:56 (381.9 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_BranchUserAccess | 2026-09-09 10:05:56 | 381.9 | [CRIT] Critical |
| df_Dim_Date | 2026-09-25 09:38:57 | -1.6 | [OK] Fresh |
| df_Dim_Customer | 2026-09-25 09:39:27 | -1.6 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-09-25 09:38:57 | -1.6 | [OK] Fresh |
| df_Dim_Technicans | 2026-09-25 09:44:40 | -1.7 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-09-25 09:44:41 | -1.7 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-09-25 09:44:40 | -1.7 | [OK] Fresh |
| df_Dim_Salesperson | 2026-09-25 09:44:40 | -1.7 | [OK] Fresh |
| df_Dim_JobCode | 2026-09-25 09:44:41 | -1.7 | [OK] Fresh |
| df_Dim_Part | 2026-09-25 09:42:58 | -1.7 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-09-25 09:45:11 | -1.7 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_PriceUpdate_Enriched | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceRecommendations | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceTimeSheet_Audit | 2026-09-24 14:18:46 | 17.7 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-09-25 09:47:19 | -1.8 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-09-25 09:47:49 | -1.8 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-09-25 09:47:49 | -1.8 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-09-25 09:47:49 | -1.8 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-09-25 09:50:44 | -1.8 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-09-25 09:48:50 | -1.8 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-09-25 09:51:44 | -1.8 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-09-25 09:51:14 | -1.8 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-09-25 09:51:14 | -1.8 | [OK] Fresh |
| df_Fact_Inventory | 2026-09-25 09:48:19 | -1.8 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-09-25 09:50:44 | -1.8 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-09-25 09:50:44 | -1.8 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-09-25 09:56:13 | -1.9 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-09-25 09:55:12 | -1.9 | [OK] Fresh |
| df_Fact_Transfers | 2026-09-25 09:56:42 | -1.9 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-09-25 09:53:09 | -1.9 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-09-25 09:55:43 | -1.9 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-09-25 09:58:09 | -1.9 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-09-25 09:53:38 | -1.9 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-09-25 09:53:38 | -1.9 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-09-25 09:55:42 | -1.9 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-09-25 09:55:42 | -1.9 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-09-25 09:53:38 | -1.9 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-09-25 09:53:39 | -1.9 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-09-25 09:58:39 | -2 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-09-25 09:58:39 | -2 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-09-25 09:59:09 | -2 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-09-25 09:58:39 | -2 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-09-25 09:58:39 | -2 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-09-25 12:32:21 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_InMaster_Parts_Ordering_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_NonJD_Parts_Ordering_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-09-24 14:03:01 | 18 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-09-25 09:17:39 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-09-25 09:19:09 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-09-25 09:19:09 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-09-25 09:19:39 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-09-25 09:18:39 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-09-25 09:21:09 | -1.3 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-09-25 09:25:52 | -1.4 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-09-25 09:25:24 | -1.4 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-09-25 09:25:25 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-09-25 09:24:53 | -1.4 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-09-25 09:27:19 | -1.4 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-09-25 09:27:49 | -1.4 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-09-25 09:27:19 | -1.4 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-09-25 09:25:23 | -1.4 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-09-25 09:28:19 | -1.4 | [OK] Fresh |
| df_INSALORD_Raw | 2026-09-25 09:27:19 | -1.4 | [OK] Fresh |
| df_InMaster_Raw | 2026-09-25 09:25:55 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-09-25 09:23:09 | -1.4 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-09-25 09:27:49 | -1.4 | [OK] Fresh |
| df_WarClaim_Raw | 2026-09-25 09:32:19 | -1.5 | [OK] Fresh |
| df_VhTrans_Raw | 2026-09-25 09:30:14 | -1.5 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-09-25 09:32:19 | -1.5 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-09-25 09:32:19 | -1.5 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-09-25 09:32:19 | -1.5 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-09-25 09:31:30 | -1.5 | [OK] Fresh |
| df_CONTACT_Raw | 2026-09-25 09:31:50 | -1.5 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-09-25 09:31:49 | -1.5 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-09-25 09:29:45 | -1.5 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-09-25 09:29:47 | -1.5 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-09-25 09:30:16 | -1.5 | [OK] Fresh |
| df_Technician_Raw | 2026-09-25 09:31:49 | -1.5 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-09-25 09:31:49 | -1.5 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-09-25 09:30:14 | -1.5 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-09-25 09:30:16 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-09-25 09:30:16 | -1.5 | [OK] Fresh |
| df_InMaster_PartsLookup_Raw | 2026-09-25 12:52:09 | -4.8 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

