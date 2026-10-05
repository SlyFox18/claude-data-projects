# Data Freshness Report

**Generated:** 2026-10-05 08:01:28
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 76 | 73.1% |
| Stale | 2 | 1.9% |
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
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-09-09 10:05:56 (621.9 hours ago)

---

## Stale - Monitor Closely

The following dataflows are approaching staleness:

- **df_ServiceTimeSheets_Raw** (RawSource) - Last refreshed: 2026-10-02 14:02:59 (66 hours ago)
- **df_Fact_ServiceTimeSheet_Audit** (FactTable) - Last refreshed: 2026-10-02 14:19:03 (65.7 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_BranchUserAccess | 2026-09-09 10:05:56 | 621.9 | [CRIT] Critical |
| df_Dim_Date | 2026-10-05 09:38:39 | -1.6 | [OK] Fresh |
| df_Dim_Customer | 2026-10-05 09:38:38 | -1.6 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-10-05 09:38:08 | -1.6 | [OK] Fresh |
| df_Dim_Technicans | 2026-10-05 09:44:22 | -1.7 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-10-05 09:44:21 | -1.7 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-10-05 09:44:23 | -1.7 | [OK] Fresh |
| df_Dim_Salesperson | 2026-10-05 09:44:22 | -1.7 | [OK] Fresh |
| df_Dim_JobCode | 2026-10-05 09:44:23 | -1.7 | [OK] Fresh |
| df_Dim_Part | 2026-10-05 09:42:40 | -1.7 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-10-05 09:45:22 | -1.7 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_PriceUpdate_Enriched | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceRecommendations | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceTimeSheet_Audit | 2026-10-02 14:19:03 | 65.7 | [WARN] Stale |
| df_FactPartTransactions_Incremental | 2026-10-05 09:47:07 | -1.8 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-10-05 09:48:37 | -1.8 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-10-05 09:48:37 | -1.8 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-10-05 09:48:08 | -1.8 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-10-05 09:50:31 | -1.8 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-10-05 09:48:37 | -1.8 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-10-05 09:51:01 | -1.8 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-10-05 09:50:31 | -1.8 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-10-05 09:51:31 | -1.8 | [OK] Fresh |
| df_Fact_Inventory | 2026-10-05 09:48:07 | -1.8 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-10-05 09:51:01 | -1.8 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-10-05 09:50:31 | -1.8 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-10-05 09:56:23 | -1.9 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-10-05 09:55:23 | -1.9 | [OK] Fresh |
| df_Fact_Transfers | 2026-10-05 09:56:53 | -1.9 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-10-05 09:52:57 | -1.9 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-10-05 09:55:23 | -1.9 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-10-05 09:58:19 | -1.9 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-10-05 09:53:27 | -1.9 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-10-05 09:53:26 | -1.9 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-10-05 09:55:23 | -1.9 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-10-05 09:55:23 | -1.9 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-10-05 09:53:27 | -1.9 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-10-05 09:53:56 | -1.9 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-10-05 09:58:50 | -2 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-10-05 09:58:20 | -2 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-10-05 09:59:20 | -2 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-10-05 09:58:20 | -2 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-10-05 09:58:19 | -2 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-10-05 12:32:48 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_NonJD_Parts_Ordering_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_InMaster_Parts_Ordering_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-10-02 14:02:59 | 66 | [WARN] Stale |
| df_InTrans_PartsCounter_Raw | 2026-10-05 09:19:38 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-10-05 09:19:38 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-10-05 09:19:08 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-10-05 09:21:08 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-10-05 09:18:38 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-10-05 09:17:38 | -1.3 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-10-05 09:22:38 | -1.4 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-10-05 09:24:52 | -1.4 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-10-05 09:25:23 | -1.4 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-10-05 09:24:53 | -1.4 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-10-05 09:24:53 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-10-05 09:24:53 | -1.4 | [OK] Fresh |
| df_INSALORD_Raw | 2026-10-05 09:28:18 | -1.4 | [OK] Fresh |
| df_InMaster_Raw | 2026-10-05 09:26:52 | -1.4 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-10-05 09:28:18 | -1.4 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-10-05 09:32:42 | -1.5 | [OK] Fresh |
| df_CONTACT_Raw | 2026-10-05 09:33:12 | -1.5 | [OK] Fresh |
| df_WarClaim_Raw | 2026-10-05 09:32:43 | -1.5 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-10-05 09:30:45 | -1.5 | [OK] Fresh |
| df_VhTrans_Raw | 2026-10-05 09:30:44 | -1.5 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-10-05 09:33:12 | -1.5 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-10-05 09:33:13 | -1.5 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-10-05 09:32:43 | -1.5 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-10-05 09:32:43 | -1.5 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-10-05 09:33:12 | -1.5 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-10-05 09:28:48 | -1.5 | [OK] Fresh |
| df_Technician_Raw | 2026-10-05 09:33:13 | -1.5 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-10-05 09:30:45 | -1.5 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-10-05 09:31:14 | -1.5 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-10-05 09:28:48 | -1.5 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-10-05 09:30:45 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-10-05 09:30:45 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-10-05 09:28:48 | -1.5 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-10-05 09:30:45 | -1.5 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-10-05 09:28:48 | -1.5 | [OK] Fresh |
| df_InMaster_PartsLookup_Raw | 2026-10-05 12:52:10 | -4.8 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

