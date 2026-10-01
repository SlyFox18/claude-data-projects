# Data Freshness Report

**Generated:** 2026-10-01 08:01:25
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 90 | 86.5% |
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
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-09-09 10:05:56 (525.9 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_BranchUserAccess | 2026-09-09 10:05:56 | 525.9 | [CRIT] Critical |
| df_Dim_Date | 2026-10-01 09:39:24 | -1.6 | [OK] Fresh |
| df_Dim_Customer | 2026-10-01 09:39:24 | -1.6 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-10-01 09:38:53 | -1.6 | [OK] Fresh |
| df_Dim_JobCode | 2026-10-01 09:44:35 | -1.7 | [OK] Fresh |
| df_Dim_Part | 2026-10-01 09:42:54 | -1.7 | [OK] Fresh |
| df_Dim_Technicans | 2026-10-01 09:45:05 | -1.7 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-10-01 09:44:34 | -1.7 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-10-01 09:45:08 | -1.7 | [OK] Fresh |
| df_Dim_Salesperson | 2026-10-01 09:44:35 | -1.7 | [OK] Fresh |
| df_Dim_VendorCode | 2026-10-01 12:33:32 | -4.5 | [OK] Fresh |
| df_Dim_SLC | 2026-10-01 12:32:02 | -4.5 | [OK] Fresh |
| df_Dim_AdjustmentType | 2026-10-01 12:33:31 | -4.5 | [OK] Fresh |
| df_Dim_Source | 2026-10-01 12:32:02 | -4.5 | [OK] Fresh |
| df_Dim_CommodityCode | 2026-10-01 12:33:59 | -4.5 | [OK] Fresh |
| df_Dim_Franchise | 2026-10-01 12:32:01 | -4.5 | [OK] Fresh |
| df_Dim_DealerGroupCode | 2026-10-01 12:32:02 | -4.5 | [OK] Fresh |
| df_Dim_ModuleType | 2026-10-01 12:33:29 | -4.5 | [OK] Fresh |
| df_Dim_Location | 2026-10-01 12:32:02 | -4.5 | [OK] Fresh |
| df_Dim_PaymentMethod | 2026-10-01 12:33:29 | -4.5 | [OK] Fresh |
| df_Dim_PromoType | 2026-10-01 12:35:54 | -4.6 | [OK] Fresh |
| df_Dim_JobType | 2026-10-01 12:35:58 | -4.6 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-10-01 12:35:54 | -4.6 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_PriceUpdate_Enriched | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceRecommendations | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceTimeSheet_Audit | 2026-09-30 14:18:19 | 17.7 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-10-01 09:47:25 | -1.8 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-10-01 09:47:55 | -1.8 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-10-01 09:47:55 | -1.8 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-10-01 09:47:55 | -1.8 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-10-01 09:51:19 | -1.8 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-10-01 09:48:55 | -1.8 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-10-01 09:51:19 | -1.8 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-10-01 09:51:19 | -1.8 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-10-01 09:51:19 | -1.8 | [OK] Fresh |
| df_Fact_Inventory | 2026-10-01 09:47:55 | -1.8 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-10-01 09:50:50 | -1.8 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-10-01 09:50:50 | -1.8 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-10-01 09:58:07 | -1.9 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-10-01 09:56:10 | -1.9 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-10-01 09:55:10 | -1.9 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-10-01 09:52:43 | -1.9 | [OK] Fresh |
| df_Fact_Transfers | 2026-10-01 09:56:40 | -1.9 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-10-01 09:58:07 | -1.9 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-10-01 09:55:40 | -1.9 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-10-01 09:53:44 | -1.9 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-10-01 09:56:10 | -1.9 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-10-01 09:55:40 | -1.9 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-10-01 09:58:07 | -1.9 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-10-01 09:53:15 | -1.9 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-10-01 09:53:14 | -1.9 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-10-01 09:58:07 | -1.9 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-10-01 09:53:45 | -1.9 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-10-01 09:59:07 | -2 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-10-01 09:59:07 | -2 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-10-01 12:31:50 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_InMaster_Parts_Ordering_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_NonJD_Parts_Ordering_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-09-30 14:02:19 | 18 | [OK] Fresh |
| df_Invoice_Raw | 2026-10-01 09:19:36 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-10-01 09:19:36 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-10-01 09:17:36 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-10-01 09:18:36 | -1.3 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-10-01 09:27:17 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-10-01 09:25:06 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-10-01 09:24:06 | -1.4 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-10-01 09:27:46 | -1.4 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-10-01 09:26:47 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-10-01 09:27:17 | -1.4 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-10-01 09:27:16 | -1.4 | [OK] Fresh |
| df_GlTrans_Raw | 2026-10-01 09:23:36 | -1.4 | [OK] Fresh |
| df_InMaster_Raw | 2026-10-01 09:27:47 | -1.4 | [OK] Fresh |
| df_WarClaim_Raw | 2026-10-01 09:34:08 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-10-01 09:32:09 | -1.5 | [OK] Fresh |
| df_VhTrans_Raw | 2026-10-01 09:32:10 | -1.5 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-10-01 09:32:10 | -1.5 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-10-01 09:30:12 | -1.5 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-10-01 09:34:08 | -1.5 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-10-01 09:34:08 | -1.5 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-10-01 09:34:08 | -1.5 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-10-01 09:34:08 | -1.5 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-10-01 09:34:08 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-10-01 09:30:11 | -1.5 | [OK] Fresh |
| df_INSALORD_Raw | 2026-10-01 09:29:12 | -1.5 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-10-01 09:29:41 | -1.5 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-10-01 09:29:13 | -1.5 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-10-01 09:32:40 | -1.5 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-10-01 09:32:10 | -1.5 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-10-01 09:32:09 | -1.5 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-10-01 09:29:41 | -1.5 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-10-01 09:32:09 | -1.5 | [OK] Fresh |
| df_Technician_Raw | 2026-10-01 09:34:38 | -1.6 | [OK] Fresh |
| df_CONTACT_Raw | 2026-10-01 09:34:38 | -1.6 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-10-01 09:34:37 | -1.6 | [OK] Fresh |
| df_InMaster_PartsLookup_Raw | 2026-10-01 12:52:08 | -4.8 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

