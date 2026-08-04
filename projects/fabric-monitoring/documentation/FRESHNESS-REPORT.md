# Data Freshness Report

**Generated:** 2026-08-04 08:01:39
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 81 | 79.4% |
| Stale |  | 0% |
| Critical | 9 | 8.8% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_GlMaster_Raw** (RawSource) - Never refreshed!
- **df_Fact_JobCodePartFrequency** (FactTable) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Never refreshed!
- **df_Dim_PartDemands** (Dimension) - Never refreshed!
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Never refreshed!
- **df_Dim_WkCodeFl** (Dimension) - Never refreshed!

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_CommodityCode | 2026-08-01 12:35:04 | 67.4 | [WARN] Stale |
| df_Dim_RepairOrder | 2026-08-04 09:52:06 | -1.8 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-08-04 09:52:07 | -1.8 | [OK] Fresh |
| df_Dim_Salesperson | 2026-08-04 09:51:36 | -1.8 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-08-04 09:51:37 | -1.8 | [OK] Fresh |
| df_Dim_Technicans | 2026-08-04 09:51:36 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-08-04 09:49:26 | -1.8 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-08-04 09:48:26 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-08-04 09:48:56 | -1.8 | [OK] Fresh |
| df_Dim_Part | 2026-08-04 09:49:56 | -1.8 | [OK] Fresh |
| df_Dim_JobCode | 2026-08-04 09:51:36 | -1.8 | [OK] Fresh |
| df_Dim_BranchUserAccess | 2026-08-04 10:01:37 | -2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceTimeSheet_Audit | 2026-08-03 14:19:58 | 17.7 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-08-04 09:54:34 | -1.9 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-08-04 09:56:04 | -1.9 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-08-04 09:55:04 | -1.9 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-08-04 09:57:34 | -1.9 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-08-04 09:56:05 | -1.9 | [OK] Fresh |
| df_Fact_Inventory | 2026-08-04 09:55:34 | -1.9 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-08-04 10:04:06 | -2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-08-04 10:01:16 | -2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-08-04 10:04:07 | -2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-08-04 10:01:48 | -2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-08-04 10:04:09 | -2 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-08-04 10:00:15 | -2 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-08-04 09:59:46 | -2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-08-04 10:00:45 | -2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-08-04 10:00:16 | -2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-08-04 10:04:35 | -2.1 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-08-04 10:07:19 | -2.1 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-08-04 10:07:20 | -2.1 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-08-04 10:07:19 | -2.1 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-08-04 10:07:22 | -2.1 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-08-04 10:07:20 | -2.1 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-08-04 10:05:07 | -2.1 | [OK] Fresh |
| df_Fact_Transfers | 2026-08-04 10:11:20 | -2.2 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-08-04 10:14:04 | -2.2 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-08-04 10:13:36 | -2.2 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-08-04 10:13:34 | -2.2 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-08-04 10:13:04 | -2.2 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-08-04 10:13:04 | -2.2 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-08-04 10:13:03 | -2.2 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-08-04 12:33:06 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-08-03 14:02:42 | 18 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-08-04 09:21:48 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-08-04 09:18:18 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-08-04 09:22:19 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-08-04 09:20:48 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-08-04 09:22:48 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-08-04 09:23:49 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-08-04 09:30:18 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-08-04 09:33:02 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-08-04 09:32:31 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-08-04 09:33:32 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-08-04 09:33:30 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-08-04 09:32:31 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-08-04 09:34:31 | -1.5 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-08-04 09:38:13 | -1.6 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-08-04 09:40:25 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-08-04 09:40:24 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-08-04 09:40:24 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-08-04 09:36:43 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-08-04 09:40:24 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-08-04 09:37:12 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-08-04 09:40:24 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-08-04 09:40:23 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-08-04 09:36:43 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-08-04 09:36:13 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-08-04 09:36:43 | -1.6 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-08-04 09:42:36 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-08-04 09:43:06 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-08-04 09:42:36 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-08-04 09:43:06 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-08-04 09:43:06 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-08-04 09:43:06 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-08-04 09:42:41 | -1.7 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-08-04 09:40:54 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-08-04 09:43:10 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-08-04 09:43:06 | -1.7 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-08-04 12:02:29 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-08-04 12:05:30 | -4.1 | [OK] Fresh |
| df_InMaster_PartsLookup_Raw | 2026-08-04 12:29:42 | -4.5 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

