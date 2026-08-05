# Data Freshness Report

**Generated:** 2026-08-05 08:01:31
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 81 | 79.4% |
| Stale | 0 | 0% |
| Critical | 10 | 9.8% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!
- **df_Fact_JobCodePartFrequency** (FactTable) - Never refreshed!
- **df_GlMaster_Raw** (RawSource) - Never refreshed!
- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Dim_PartDemands** (Dimension) - Never refreshed!
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Never refreshed!
- **df_Dim_WkCodeFl** (Dimension) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Never refreshed!
- **df_Dim_CommodityCode** (Dimension) - Last refreshed: 2026-08-01 12:35:04 (91.4 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_CommodityCode | 2026-08-01 12:35:04 | 91.4 | [CRIT] Critical |
| df_Dim_RepairOrder | 2026-08-04 09:52:06 | 22.2 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-08-04 09:52:07 | 22.2 | [OK] Fresh |
| df_Dim_Salesperson | 2026-08-04 09:51:36 | 22.2 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-08-04 09:51:37 | 22.2 | [OK] Fresh |
| df_Dim_Technicans | 2026-08-04 09:51:36 | 22.2 | [OK] Fresh |
| df_Dim_Customer | 2026-08-04 09:49:26 | 22.2 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-08-04 09:48:26 | 22.2 | [OK] Fresh |
| df_Dim_Date | 2026-08-04 09:48:56 | 22.2 | [OK] Fresh |
| df_Dim_Part | 2026-08-04 09:49:56 | 22.2 | [OK] Fresh |
| df_Dim_JobCode | 2026-08-04 09:51:36 | 22.2 | [OK] Fresh |
| df_Dim_BranchUserAccess | 2026-08-05 10:04:14 | -2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_FactPartTransactions_Incremental | 2026-08-04 09:54:34 | 22.1 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-08-04 09:57:34 | 22.1 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-08-04 09:56:04 | 22.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-08-04 09:55:04 | 22.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-08-04 09:56:05 | 22.1 | [OK] Fresh |
| df_Fact_Inventory | 2026-08-04 09:55:34 | 22.1 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-08-04 10:01:48 | 22 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-08-04 10:00:15 | 22 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-08-04 10:01:16 | 22 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-08-04 10:04:06 | 22 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-08-04 09:59:46 | 22 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-08-04 10:04:07 | 22 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-08-04 10:04:09 | 22 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-08-04 10:00:16 | 22 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-08-04 10:00:45 | 22 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-08-04 10:05:07 | 21.9 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-08-04 10:07:19 | 21.9 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-08-04 10:07:20 | 21.9 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-08-04 10:07:20 | 21.9 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-08-04 10:07:19 | 21.9 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-08-04 10:07:22 | 21.9 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-08-04 10:04:35 | 21.9 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-08-04 10:13:04 | 21.8 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-08-04 10:14:04 | 21.8 | [OK] Fresh |
| df_Fact_Transfers | 2026-08-04 10:11:20 | 21.8 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-08-04 10:13:34 | 21.8 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-08-04 10:13:36 | 21.8 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-08-04 10:13:04 | 21.8 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-08-04 10:13:03 | 21.8 | [OK] Fresh |
| df_Fact_ServiceTimeSheet_Audit | 2026-08-04 14:20:07 | 17.7 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-08-05 12:32:07 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_InMaster_Parts_Ordering_Raw | 2026-08-04 12:02:29 | 20 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-08-04 12:05:30 | 19.9 | [OK] Fresh |
| df_InMaster_PartsLookup_Raw | 2026-08-04 12:29:42 | 19.5 | [OK] Fresh |
| df_ServiceTimeSheets_Raw | 2026-08-04 14:02:39 | 18 | [OK] Fresh |
| df_GlTrans_Raw | 2026-08-05 09:22:23 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-08-05 09:21:53 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-08-05 09:18:23 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-08-05 09:20:53 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-08-05 09:23:53 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-08-05 09:23:23 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-08-05 09:29:53 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-08-05 09:32:36 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-08-05 09:32:06 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-08-05 09:32:36 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-08-05 09:32:06 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-08-05 09:33:06 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-08-05 09:34:06 | -1.5 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-08-05 09:40:00 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-08-05 09:37:49 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-08-05 09:37:19 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-08-05 09:40:01 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-08-05 09:40:01 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-08-05 09:36:19 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-08-05 09:40:00 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-08-05 09:36:19 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-08-05 09:40:00 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-08-05 09:36:19 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-08-05 09:35:49 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-08-05 09:40:01 | -1.6 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-08-05 09:42:18 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-08-05 09:42:13 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-08-05 09:42:43 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-08-05 09:42:43 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-08-05 09:42:13 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-08-05 09:40:31 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-08-05 09:42:48 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-08-05 09:42:18 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-08-05 09:42:43 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-08-05 09:42:13 | -1.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

