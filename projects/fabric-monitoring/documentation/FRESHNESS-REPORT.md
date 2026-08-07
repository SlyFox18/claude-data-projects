# Data Freshness Report

**Generated:** 2026-08-07 08:01:34
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 72 | 70.6% |
| Stale | 9 | 8.8% |
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

## Stale - Monitor Closely

The following dataflows are approaching staleness:

- **df_Fact_NegativeOnHand_OnHandNoBin** (FactTable) - Last refreshed: 2026-08-04 10:13:04 (69.8 hours ago)
- **df_Fact_Planter_Inspection_Part_Sales** (FactTable) - Last refreshed: 2026-08-04 10:13:34 (69.8 hours ago)
- **df_Fact_Top50_JobCodes** (FactTable) - Last refreshed: 2026-08-04 10:14:04 (69.8 hours ago)
- **df_Fact_AdjustmentPairs** (FactTable) - Last refreshed: 2026-08-04 10:13:04 (69.8 hours ago)
- **df_Fact_PartsPromo** (FactTable) - Last refreshed: 2026-08-04 10:13:03 (69.8 hours ago)
- **df_Fact_InSalOrd_InSalPar** (FactTable) - Last refreshed: 2026-08-04 10:13:36 (69.8 hours ago)
- **df_InMaster_Parts_Ordering_Raw** (RawSource) - Last refreshed: 2026-08-04 12:02:29 (68 hours ago)
- **df_NonJD_Parts_Ordering_Raw** (RawSource) - Last refreshed: 2026-08-04 12:05:30 (67.9 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-08-05 10:04:14 (46 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_BranchUserAccess | 2026-08-05 10:04:14 | 46 | [WARN] Stale |
| df_Dim_Part | 2026-08-07 09:52:03 | -1.8 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-08-07 09:50:33 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-08-07 09:50:34 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-08-07 09:51:33 | -1.8 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-08-07 09:54:13 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-08-07 09:54:43 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-08-07 09:54:13 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-08-07 09:54:43 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-08-07 09:56:13 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-08-07 09:54:13 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_Top50_JobCodes | 2026-08-04 10:14:04 | 69.8 | [WARN] Stale |
| df_Fact_PartsPromo | 2026-08-04 10:13:03 | 69.8 | [WARN] Stale |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-08-04 10:13:04 | 69.8 | [WARN] Stale |
| df_Fact_Planter_Inspection_Part_Sales | 2026-08-04 10:13:34 | 69.8 | [WARN] Stale |
| df_Fact_AdjustmentPairs | 2026-08-04 10:13:04 | 69.8 | [WARN] Stale |
| df_Fact_InSalOrd_InSalPar | 2026-08-04 10:13:36 | 69.8 | [WARN] Stale |
| df_Fact_ServiceTimeSheet_Audit | 2026-08-06 14:19:40 | 17.7 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-08-07 09:58:37 | -2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-08-07 10:02:07 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-08-07 10:00:07 | -2 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-08-07 09:59:37 | -2 | [OK] Fresh |
| df_Fact_Inventory | 2026-08-07 09:59:07 | -2 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-08-07 10:09:51 | -2.1 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-08-07 10:09:52 | -2.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-08-07 10:07:07 | -2.1 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-08-07 10:10:03 | -2.1 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-08-07 10:16:22 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-08-07 10:13:49 | -2.2 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-08-07 10:11:21 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-08-07 10:14:08 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-08-07 10:13:39 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-08-07 10:10:51 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-08-07 10:16:22 | -2.2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-08-07 10:11:24 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-08-07 10:14:09 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-08-07 10:14:08 | -2.2 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-08-07 10:20:24 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-08-07 10:17:21 | -2.3 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-08-07 10:16:22 | -2.3 | [OK] Fresh |
| df_Fact_Transfers | 2026-08-07 10:46:17 | -2.7 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-08-07 12:32:43 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_InMaster_Parts_Ordering_Raw | 2026-08-04 12:02:29 | 68 | [WARN] Stale |
| df_NonJD_Parts_Ordering_Raw | 2026-08-04 12:05:30 | 67.9 | [WARN] Stale |
| df_ServiceTimeSheets_Raw | 2026-08-06 14:02:13 | 18 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-08-07 09:20:30 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-08-07 09:18:30 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-08-07 09:24:30 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-08-07 09:23:00 | -1.4 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-08-07 09:22:30 | -1.4 | [OK] Fresh |
| df_GlTrans_Raw | 2026-08-07 09:22:30 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-08-07 09:31:00 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-08-07 09:33:44 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-08-07 09:33:42 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-08-07 09:34:14 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-08-07 09:34:13 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-08-07 09:33:44 | -1.5 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-08-07 09:38:25 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-08-07 09:36:54 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-08-07 09:36:54 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-08-07 09:37:54 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-08-07 09:36:54 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-08-07 09:36:55 | -1.6 | [OK] Fresh |
| df_InMaster_Raw | 2026-08-07 09:34:43 | -1.6 | [OK] Fresh |
| df_CONTACT_Raw | 2026-08-07 09:45:25 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-08-07 09:45:26 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-08-07 09:44:56 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-08-07 09:45:25 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-08-07 09:45:25 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-08-07 09:45:25 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-08-07 09:45:27 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-08-07 09:45:26 | -1.7 | [OK] Fresh |
| df_VhTrans_Raw | 2026-08-07 09:41:36 | -1.7 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-08-07 09:40:36 | -1.7 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-08-07 09:41:06 | -1.7 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-08-07 09:40:36 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-08-07 09:45:25 | -1.7 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-08-07 09:41:06 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-08-07 09:43:07 | -1.7 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-08-07 09:41:06 | -1.7 | [OK] Fresh |
| df_InMaster_PartsLookup_Raw | 2026-08-07 12:43:53 | -4.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

