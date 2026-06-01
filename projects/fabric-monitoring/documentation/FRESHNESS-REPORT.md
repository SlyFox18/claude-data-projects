# Data Freshness Report

**Generated:** 2026-06-01 08:01:32
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 16 | 16.2% |
| Stale | 61 | 61.6% |
| Critical | 9 | 9.1% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_GlMaster_Raw** (RawSource) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Last refreshed: 2026-05-06 15:04:38 (616.9 hours ago)
- **df_Dim_WkCodeFl** (Dimension) - Last refreshed: 2026-05-06 15:26:40 (616.6 hours ago)
- **df_Fact_OpenOrderParts** (FactTable) - Last refreshed: 2026-05-20 12:50:38 (283.2 hours ago)
- **df_Fact_OpenOrders** (FactTable) - Last refreshed: 2026-05-20 12:50:41 (283.2 hours ago)
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Last refreshed: 2026-05-20 12:55:53 (283.1 hours ago)
- **df_Fact_JobCodePartFrequency** (FactTable) - Last refreshed: 2026-05-20 12:54:14 (283.1 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-05-27 10:02:03 (118 hours ago)

---

## Stale - Monitor Closely

The following dataflows are approaching staleness:

- **df_RepairOrderDetail_Raw** (RawSource) - Last refreshed: 2026-05-29 09:33:38 (70.5 hours ago)
- **df_INSALORD_Raw** (RawSource) - Last refreshed: 2026-05-29 09:33:38 (70.5 hours ago)
- **df_VHSTOCK_Raw** (RawSource) - Last refreshed: 2026-05-29 09:34:03 (70.5 hours ago)
- **df_INSALPAR_Raw** (RawSource) - Last refreshed: 2026-05-29 09:33:09 (70.5 hours ago)
- **df_TechnicianEfficiency_Raw** (RawSource) - Last refreshed: 2026-05-29 09:38:51 (70.4 hours ago)
- **df_TechnicianAttendance_Raw** (RawSource) - Last refreshed: 2026-05-29 09:38:20 (70.4 hours ago)
- **df_Insalpar_Audit_Raw** (RawSource) - Last refreshed: 2026-05-29 09:38:51 (70.4 hours ago)
- **df_TechnicianInvoice_Raw** (RawSource) - Last refreshed: 2026-05-29 09:38:51 (70.4 hours ago)
- **df_VhStockAccess_Raw** (RawSource) - Last refreshed: 2026-05-29 09:38:50 (70.4 hours ago)
- **df_VhTrans_Raw** (RawSource) - Last refreshed: 2026-05-29 09:38:51 (70.4 hours ago)
- **df_TechnicianPunchedTime_Raw** (RawSource) - Last refreshed: 2026-05-29 09:39:52 (70.4 hours ago)
- **df_TechnicianInvoiceDetail_Raw** (RawSource) - Last refreshed: 2026-05-29 09:36:03 (70.4 hours ago)
- **df_TechnicianPunchedDetail_Raw** (RawSource) - Last refreshed: 2026-05-29 09:34:39 (70.4 hours ago)
- **df_WARSUBCI_LABOUR_Raw** (RawSource) - Last refreshed: 2026-05-29 09:42:35 (70.3 hours ago)
- **df_WarClaim_Raw** (RawSource) - Last refreshed: 2026-05-29 09:42:07 (70.3 hours ago)
- **df_Technician_Raw** (RawSource) - Last refreshed: 2026-05-29 09:42:04 (70.3 hours ago)
- **df_Branch_Name_Raw** (RawSource) - Last refreshed: 2026-05-29 09:45:04 (70.3 hours ago)
- **df_BranchOperational_Raw** (RawSource) - Last refreshed: 2026-05-29 09:42:04 (70.3 hours ago)
- **df_CONTACT_Raw** (RawSource) - Last refreshed: 2026-05-29 09:43:04 (70.3 hours ago)
- **df_ArMaster_Contact_Raw** (RawSource) - Last refreshed: 2026-05-29 09:42:06 (70.3 hours ago)
- **df_ArMaster_Customer_Raw** (RawSource) - Last refreshed: 2026-05-29 09:42:04 (70.3 hours ago)
- **df_ARMASTER_Raw** (RawSource) - Last refreshed: 2026-05-29 09:42:04 (70.3 hours ago)
- **df_Dim_Date** (Dimension) - Last refreshed: 2026-05-29 09:50:53 (70.2 hours ago)
- **df_Dim_Customer** (Dimension) - Last refreshed: 2026-05-29 09:52:11 (70.2 hours ago)
- **df_Dim_Salesperson** (Dimension) - Last refreshed: 2026-05-29 09:56:01 (70.1 hours ago)
- **df_Dim_UniqueCustomers** (Dimension) - Last refreshed: 2026-05-29 09:56:02 (70.1 hours ago)
- **df_Dim_Technicans** (Dimension) - Last refreshed: 2026-05-29 09:56:04 (70.1 hours ago)
- **df_Dim_Part** (Dimension) - Last refreshed: 2026-05-29 09:53:50 (70.1 hours ago)
- **df_Dim_Branch12_Parts** (Dimension) - Last refreshed: 2026-05-29 09:56:01 (70.1 hours ago)
- **df_Dim_JobCode** (Dimension) - Last refreshed: 2026-05-29 09:56:32 (70.1 hours ago)
- **df_Fact_Service_Detail** (FactTable) - Last refreshed: 2026-05-29 10:02:59 (70 hours ago)
- **df_FactPartTransactions_Incremental** (FactTable) - Last refreshed: 2026-05-29 09:59:28 (70 hours ago)
- **df_Fact_Service_Invoices** (FactTable) - Last refreshed: 2026-05-29 10:04:59 (69.9 hours ago)
- **df_Fact_Parts_Details** (FactTable) - Last refreshed: 2026-05-29 10:04:31 (69.9 hours ago)
- **df_Fact_Inventory** (FactTable) - Last refreshed: 2026-05-29 10:07:24 (69.9 hours ago)
- **df_Fact_WorkOrderParts** (FactTable) - Last refreshed: 2026-05-29 10:04:29 (69.9 hours ago)
- **df_Fact_Service_Parts_Detail** (FactTable) - Last refreshed: 2026-05-29 10:11:29 (69.8 hours ago)
- **df_Fact_Parts_Invoices** (FactTable) - Last refreshed: 2026-05-29 10:12:33 (69.8 hours ago)
- **df_Fact_First_Pass_Fill** (FactTable) - Last refreshed: 2026-05-29 10:15:15 (69.8 hours ago)
- **df_Fact_CustomerPerformance** (FactTable) - Last refreshed: 2026-05-29 10:11:30 (69.8 hours ago)
- **df_Fact_LaborJobSummary** (FactTable) - Last refreshed: 2026-05-29 10:12:29 (69.8 hours ago)
- **df_Fact_Invoice_UniqueCustomers** (FactTable) - Last refreshed: 2026-05-29 10:12:31 (69.8 hours ago)
- **df_Fact_PartsAdjustments** (FactTable) - Last refreshed: 2026-05-29 10:18:04 (69.7 hours ago)
- **df_Fact_Branch12_Transactions** (FactTable) - Last refreshed: 2026-05-29 10:17:34 (69.7 hours ago)
- **df_Fact_Invoice_InventoryAnalysis** (FactTable) - Last refreshed: 2026-05-29 10:22:11 (69.7 hours ago)
- **df_Fact_Parts_With_Open_Orders** (FactTable) - Last refreshed: 2026-05-29 10:17:34 (69.7 hours ago)
- **df_Fact_MDInvoices_Closed** (FactTable) - Last refreshed: 2026-05-29 10:24:55 (69.6 hours ago)
- **df_Fact_MDInvoices_NoFreight** (FactTable) - Last refreshed: 2026-05-29 10:24:55 (69.6 hours ago)
- **df_Fact_PendingInspections** (FactTable) - Last refreshed: 2026-05-29 10:24:24 (69.6 hours ago)
- **df_Fact_InTrans_UniqueCustomers** (FactTable) - Last refreshed: 2026-05-29 10:24:54 (69.6 hours ago)
- **df_Fact_Equipment_Sales** (FactTable) - Last refreshed: 2026-05-29 10:24:53 (69.6 hours ago)
- **df_Fact_InSalOrd_InSalPar** (FactTable) - Last refreshed: 2026-05-29 10:31:06 (69.5 hours ago)
- **df_Fact_PartsPromo** (FactTable) - Last refreshed: 2026-05-29 10:31:38 (69.5 hours ago)
- **df_Fact_Transfers** (FactTable) - Last refreshed: 2026-05-29 10:28:53 (69.5 hours ago)
- **df_Fact_Top50_JobCodes** (FactTable) - Last refreshed: 2026-05-29 10:32:07 (69.5 hours ago)
- **df_Fact_NegativeOnHand_OnHandNoBin** (FactTable) - Last refreshed: 2026-05-29 10:31:07 (69.5 hours ago)
- **df_Fact_AdjustmentPairs** (FactTable) - Last refreshed: 2026-05-29 10:31:37 (69.5 hours ago)
- **df_Fact_Planter_Inspection_Part_Sales** (FactTable) - Last refreshed: 2026-05-29 10:31:37 (69.5 hours ago)
- **df_ServiceTimeSheets_Raw** (RawSource) - Last refreshed: 2026-05-29 14:02:02 (66 hours ago)
- **df_Fact_ServiceTimeSheet_Audit** (FactTable) - Last refreshed: 2026-05-29 14:17:59 (65.7 hours ago)
- **df_Fact_PartSales_24Hours** (FactTable) - Last refreshed: 2026-05-29 16:16:10 (63.8 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | 2026-05-06 15:04:38 | 616.9 | [CRIT] Critical |
| df_Dim_WkCodeFl | 2026-05-06 15:26:40 | 616.6 | [CRIT] Critical |
| df_Dim_BranchUserAccess | 2026-05-27 10:02:03 | 118 | [CRIT] Critical |
| df_Dim_Date | 2026-05-29 09:50:53 | 70.2 | [WARN] Stale |
| df_Dim_Customer | 2026-05-29 09:52:11 | 70.2 | [WARN] Stale |
| df_Dim_Technicans | 2026-05-29 09:56:04 | 70.1 | [WARN] Stale |
| df_Dim_UniqueCustomers | 2026-05-29 09:56:02 | 70.1 | [WARN] Stale |
| df_Dim_Branch12_Parts | 2026-05-29 09:56:01 | 70.1 | [WARN] Stale |
| df_Dim_Salesperson | 2026-05-29 09:56:01 | 70.1 | [WARN] Stale |
| df_Dim_JobCode | 2026-05-29 09:56:32 | 70.1 | [WARN] Stale |
| df_Dim_Part | 2026-05-29 09:53:50 | 70.1 | [WARN] Stale |
| df_Dim_Franchise | 2026-06-01 12:33:08 | -4.5 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-06-01 12:39:00 | -4.6 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrders | 2026-05-20 12:50:41 | 283.2 | [CRIT] Critical |
| df_Fact_OpenOrderParts | 2026-05-20 12:50:38 | 283.2 | [CRIT] Critical |
| df_Fact_JobCodePartFrequency | 2026-05-20 12:54:14 | 283.1 | [CRIT] Critical |
| df_Fact_JobCodeFrequency_Branch | 2026-05-20 12:55:53 | 283.1 | [CRIT] Critical |
| df_Fact_Service_Detail | 2026-05-29 10:02:59 | 70 | [WARN] Stale |
| df_FactPartTransactions_Incremental | 2026-05-29 09:59:28 | 70 | [WARN] Stale |
| df_Fact_Inventory | 2026-05-29 10:07:24 | 69.9 | [WARN] Stale |
| df_Fact_Parts_Details | 2026-05-29 10:04:31 | 69.9 | [WARN] Stale |
| df_Fact_WorkOrderParts | 2026-05-29 10:04:29 | 69.9 | [WARN] Stale |
| df_Fact_Service_Invoices | 2026-05-29 10:04:59 | 69.9 | [WARN] Stale |
| df_Fact_LaborJobSummary | 2026-05-29 10:12:29 | 69.8 | [WARN] Stale |
| df_Fact_CustomerPerformance | 2026-05-29 10:11:30 | 69.8 | [WARN] Stale |
| df_Fact_First_Pass_Fill | 2026-05-29 10:15:15 | 69.8 | [WARN] Stale |
| df_Fact_Service_Parts_Detail | 2026-05-29 10:11:29 | 69.8 | [WARN] Stale |
| df_Fact_Invoice_UniqueCustomers | 2026-05-29 10:12:31 | 69.8 | [WARN] Stale |
| df_Fact_Parts_Invoices | 2026-05-29 10:12:33 | 69.8 | [WARN] Stale |
| df_Fact_Parts_With_Open_Orders | 2026-05-29 10:17:34 | 69.7 | [WARN] Stale |
| df_Fact_PartsAdjustments | 2026-05-29 10:18:04 | 69.7 | [WARN] Stale |
| df_Fact_Invoice_InventoryAnalysis | 2026-05-29 10:22:11 | 69.7 | [WARN] Stale |
| df_Fact_Branch12_Transactions | 2026-05-29 10:17:34 | 69.7 | [WARN] Stale |
| df_Fact_PendingInspections | 2026-05-29 10:24:24 | 69.6 | [WARN] Stale |
| df_Fact_InTrans_UniqueCustomers | 2026-05-29 10:24:54 | 69.6 | [WARN] Stale |
| df_Fact_MDInvoices_Closed | 2026-05-29 10:24:55 | 69.6 | [WARN] Stale |
| df_Fact_Equipment_Sales | 2026-05-29 10:24:53 | 69.6 | [WARN] Stale |
| df_Fact_MDInvoices_NoFreight | 2026-05-29 10:24:55 | 69.6 | [WARN] Stale |
| df_Fact_Transfers | 2026-05-29 10:28:53 | 69.5 | [WARN] Stale |
| df_Fact_Top50_JobCodes | 2026-05-29 10:32:07 | 69.5 | [WARN] Stale |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-05-29 10:31:07 | 69.5 | [WARN] Stale |
| df_Fact_AdjustmentPairs | 2026-05-29 10:31:37 | 69.5 | [WARN] Stale |
| df_Fact_InSalOrd_InSalPar | 2026-05-29 10:31:06 | 69.5 | [WARN] Stale |
| df_Fact_Planter_Inspection_Part_Sales | 2026-05-29 10:31:37 | 69.5 | [WARN] Stale |
| df_Fact_PartsPromo | 2026-05-29 10:31:38 | 69.5 | [WARN] Stale |
| df_Fact_ServiceTimeSheet_Audit | 2026-05-29 14:17:59 | 65.7 | [WARN] Stale |
| df_Fact_PartSales_24Hours | 2026-05-29 16:16:10 | 63.8 | [WARN] Stale |
| df_Fact_InternalWorkOrders | 2026-06-01 12:33:18 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_INSALPAR_Raw | 2026-05-29 09:33:09 | 70.5 | [WARN] Stale |
| df_RepairOrderDetail_Raw | 2026-05-29 09:33:38 | 70.5 | [WARN] Stale |
| df_INSALORD_Raw | 2026-05-29 09:33:38 | 70.5 | [WARN] Stale |
| df_VHSTOCK_Raw | 2026-05-29 09:34:03 | 70.5 | [WARN] Stale |
| df_VhTrans_Raw | 2026-05-29 09:38:51 | 70.4 | [WARN] Stale |
| df_VhStockAccess_Raw | 2026-05-29 09:38:50 | 70.4 | [WARN] Stale |
| df_TechnicianPunchedTime_Raw | 2026-05-29 09:39:52 | 70.4 | [WARN] Stale |
| df_TechnicianPunchedDetail_Raw | 2026-05-29 09:34:39 | 70.4 | [WARN] Stale |
| df_TechnicianEfficiency_Raw | 2026-05-29 09:38:51 | 70.4 | [WARN] Stale |
| df_TechnicianAttendance_Raw | 2026-05-29 09:38:20 | 70.4 | [WARN] Stale |
| df_TechnicianInvoiceDetail_Raw | 2026-05-29 09:36:03 | 70.4 | [WARN] Stale |
| df_TechnicianInvoice_Raw | 2026-05-29 09:38:51 | 70.4 | [WARN] Stale |
| df_Insalpar_Audit_Raw | 2026-05-29 09:38:51 | 70.4 | [WARN] Stale |
| df_BranchOperational_Raw | 2026-05-29 09:42:04 | 70.3 | [WARN] Stale |
| df_CONTACT_Raw | 2026-05-29 09:43:04 | 70.3 | [WARN] Stale |
| df_Technician_Raw | 2026-05-29 09:42:04 | 70.3 | [WARN] Stale |
| df_ArMaster_Customer_Raw | 2026-05-29 09:42:04 | 70.3 | [WARN] Stale |
| df_ARMASTER_Raw | 2026-05-29 09:42:04 | 70.3 | [WARN] Stale |
| df_Branch_Name_Raw | 2026-05-29 09:45:04 | 70.3 | [WARN] Stale |
| df_ArMaster_Contact_Raw | 2026-05-29 09:42:06 | 70.3 | [WARN] Stale |
| df_WarClaim_Raw | 2026-05-29 09:42:07 | 70.3 | [WARN] Stale |
| df_WARSUBCI_LABOUR_Raw | 2026-05-29 09:42:35 | 70.3 | [WARN] Stale |
| df_ServiceTimeSheets_Raw | 2026-05-29 14:02:02 | 66 | [WARN] Stale |
| df_InMaster_Raw | Error | 0 | [?] Error |
| df_WKOTHSUB_Raw | Error | 0 | [?] Error |
| df_InMaster_Parts_Ordering_Raw | 2026-06-01 12:02:22 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-06-01 12:04:43 | -4.1 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-06-01 12:46:09 | -4.7 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-06-01 12:49:39 | -4.8 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-06-01 12:48:09 | -4.8 | [OK] Fresh |
| df_GlTrans_Raw | 2026-06-01 12:49:10 | -4.8 | [OK] Fresh |
| df_Invoice_Raw | 2026-06-01 12:52:09 | -4.8 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-06-01 12:51:39 | -4.8 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-06-01 12:57:09 | -4.9 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-06-01 12:59:21 | -5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-06-01 13:00:22 | -5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-06-01 12:59:21 | -5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-06-01 13:01:21 | -5 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

