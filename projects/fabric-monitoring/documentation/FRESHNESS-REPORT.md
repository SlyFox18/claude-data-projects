# Data Freshness Report

**Generated:** 2026-09-07 08:01:31
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 76 | 73.1% |
| Stale | 2 | 1.9% |
| Critical | 13 | 12.5% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_NonJD_Parts_Ordering_Raw** (RawSource) - Never refreshed!
- **df_Fact_JobCodePartFrequency** (FactTable) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Never refreshed!
- **df_Dim_PartDemands** (Dimension) - Never refreshed!
- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!
- **df_Dim_WkCodeFl** (Dimension) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Never refreshed!
- **df_Fact_PriceUpdate_Enriched** (FactTable) - Last refreshed: 2026-08-11 16:05:21 (639.9 hours ago)
- **df_Fact_ServiceRecommendations** (FactTable) - Last refreshed: 2026-08-21 15:56:04 (400.1 hours ago)
- **df_GlMaster_Raw** (RawSource) - Last refreshed: 2026-08-24 13:57:10 (330.1 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-09-02 10:01:39 (118 hours ago)

---

## Stale - Monitor Closely

The following dataflows are approaching staleness:

- **df_ServiceTimeSheets_Raw** (RawSource) - Last refreshed: 2026-09-04 14:02:42 (66 hours ago)
- **df_Fact_ServiceTimeSheet_Audit** (FactTable) - Last refreshed: 2026-09-04 14:18:35 (65.7 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_BranchUserAccess | 2026-09-02 10:01:39 | 118 | [CRIT] Critical |
| df_Dim_Date | 2026-09-07 09:38:59 | -1.6 | [OK] Fresh |
| df_Dim_Customer | 2026-09-07 09:39:28 | -1.6 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-09-07 09:38:58 | -1.6 | [OK] Fresh |
| df_Dim_Technicans | 2026-09-07 09:44:40 | -1.7 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-09-07 09:44:40 | -1.7 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-09-07 09:45:09 | -1.7 | [OK] Fresh |
| df_Dim_Part | 2026-09-07 09:42:59 | -1.7 | [OK] Fresh |
| df_Dim_JobCode | 2026-09-07 09:45:10 | -1.7 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-09-07 09:45:40 | -1.7 | [OK] Fresh |
| df_Dim_Salesperson | 2026-09-07 09:48:03 | -1.8 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_PriceUpdate_Enriched | 2026-08-11 16:05:21 | 639.9 | [CRIT] Critical |
| df_Fact_ServiceRecommendations | 2026-08-21 15:56:04 | 400.1 | [CRIT] Critical |
| df_Fact_ServiceTimeSheet_Audit | 2026-09-04 14:18:35 | 65.7 | [WARN] Stale |
| df_Fact_WorkOrderParts | 2026-09-07 09:50:41 | -1.8 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-09-07 09:51:11 | -1.8 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-09-07 09:50:41 | -1.8 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-09-07 09:51:40 | -1.8 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-09-07 09:49:40 | -1.8 | [OK] Fresh |
| df_Fact_Inventory | 2026-09-07 09:50:40 | -1.8 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-09-07 09:56:32 | -1.9 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-09-07 09:56:32 | -1.9 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-09-07 09:54:08 | -1.9 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-09-07 09:53:36 | -1.9 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-09-07 09:54:36 | -1.9 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-09-07 09:56:32 | -1.9 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-09-07 09:57:58 | -1.9 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-09-07 09:56:32 | -1.9 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-09-07 09:54:06 | -1.9 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-09-07 09:54:06 | -1.9 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-09-07 09:57:58 | -1.9 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-09-07 09:53:36 | -1.9 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-09-07 09:56:32 | -1.9 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-09-07 10:03:17 | -2 | [OK] Fresh |
| df_Fact_Transfers | 2026-09-07 09:59:58 | -2 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-09-07 10:04:15 | -2 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-09-07 09:58:28 | -2 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-09-07 09:58:28 | -2 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-09-07 09:58:58 | -2 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-09-07 10:03:47 | -2 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-09-07 10:05:47 | -2.1 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-09-07 10:05:45 | -2.1 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-09-07 10:05:48 | -2.1 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-09-07 12:32:15 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_NonJD_Parts_Ordering_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlMaster_Raw | 2026-08-24 13:57:10 | 330.1 | [CRIT] Critical |
| df_ServiceTimeSheets_Raw | 2026-09-04 14:02:42 | 66 | [WARN] Stale |
| df_InTrans_PartsCounter_Raw | 2026-09-07 09:19:28 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-09-07 09:18:58 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-09-07 09:19:28 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-09-07 09:17:28 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-09-07 09:20:58 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-09-07 09:18:28 | -1.3 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-09-07 09:25:39 | -1.4 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-09-07 09:25:40 | -1.4 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-09-07 09:25:09 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-09-07 09:25:08 | -1.4 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-09-07 09:27:38 | -1.4 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-09-07 09:28:08 | -1.4 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-09-07 09:27:39 | -1.4 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-09-07 09:25:39 | -1.4 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-09-07 09:27:38 | -1.4 | [OK] Fresh |
| df_INSALORD_Raw | 2026-09-07 09:27:08 | -1.4 | [OK] Fresh |
| df_InMaster_Raw | 2026-09-07 09:25:39 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-09-07 09:22:58 | -1.4 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-09-07 09:27:08 | -1.4 | [OK] Fresh |
| df_WarClaim_Raw | 2026-09-07 09:33:33 | -1.5 | [OK] Fresh |
| df_VhTrans_Raw | 2026-09-07 09:30:34 | -1.5 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-09-07 09:32:04 | -1.5 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-09-07 09:33:02 | -1.5 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-09-07 09:32:34 | -1.5 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-09-07 09:33:02 | -1.5 | [OK] Fresh |
| df_CONTACT_Raw | 2026-09-07 09:32:32 | -1.5 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-09-07 09:32:04 | -1.5 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-09-07 09:30:04 | -1.5 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-09-07 09:30:14 | -1.5 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-09-07 09:30:34 | -1.5 | [OK] Fresh |
| df_Technician_Raw | 2026-09-07 09:32:32 | -1.5 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-09-07 09:32:33 | -1.5 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-09-07 09:30:07 | -1.5 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-09-07 09:30:04 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-09-07 09:30:04 | -1.5 | [OK] Fresh |
| df_InMaster_PartsLookup_Raw | 2026-09-07 12:52:11 | -4.8 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

