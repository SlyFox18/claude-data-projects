# Data Freshness Report

**Generated:** 2026-06-04 08:01:27
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 79 | 79.8% |
| Stale |  | 0% |
| Critical | 8 | 8.1% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_GlMaster_Raw** (RawSource) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Last refreshed: 2026-05-06 15:04:38 (688.9 hours ago)
- **df_Dim_WkCodeFl** (Dimension) - Last refreshed: 2026-05-06 15:26:40 (688.6 hours ago)
- **df_Fact_OpenOrders** (FactTable) - Last refreshed: 2026-05-20 12:50:41 (355.2 hours ago)
- **df_Fact_OpenOrderParts** (FactTable) - Last refreshed: 2026-05-20 12:50:38 (355.2 hours ago)
- **df_Fact_JobCodePartFrequency** (FactTable) - Last refreshed: 2026-05-20 12:54:14 (355.1 hours ago)
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Last refreshed: 2026-05-20 12:55:53 (355.1 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | 2026-05-06 15:04:38 | 688.9 | [CRIT] Critical |
| df_Dim_WkCodeFl | 2026-05-06 15:26:40 | 688.6 | [CRIT] Critical |
| df_Dim_Franchise | 2026-06-01 12:33:08 | 67.5 | [WARN] Stale |
| df_Dim_BranchUserAccess | 2026-06-03 10:01:27 | 22 | [OK] Fresh |
| df_Dim_Part | 2026-06-04 10:09:43 | -2.1 | [OK] Fresh |
| df_Dim_Customer | 2026-06-04 10:07:09 | -2.1 | [OK] Fresh |
| df_Dim_Date | 2026-06-04 10:06:41 | -2.1 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-06-04 10:11:54 | -2.2 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-06-04 10:11:55 | -2.2 | [OK] Fresh |
| df_Dim_Technicans | 2026-06-04 10:11:55 | -2.2 | [OK] Fresh |
| df_Dim_JobCode | 2026-06-04 10:11:55 | -2.2 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-06-04 10:12:54 | -2.2 | [OK] Fresh |
| df_Dim_Salesperson | 2026-06-04 10:11:58 | -2.2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrders | 2026-05-20 12:50:41 | 355.2 | [CRIT] Critical |
| df_Fact_OpenOrderParts | 2026-05-20 12:50:38 | 355.2 | [CRIT] Critical |
| df_Fact_JobCodePartFrequency | 2026-05-20 12:54:14 | 355.1 | [CRIT] Critical |
| df_Fact_JobCodeFrequency_Branch | 2026-05-20 12:55:53 | 355.1 | [CRIT] Critical |
| df_Fact_ServiceTimeSheet_Audit | 2026-06-03 14:17:59 | 17.7 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-06-04 10:16:02 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-06-04 10:20:32 | -2.3 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-06-04 10:21:02 | -2.3 | [OK] Fresh |
| df_Fact_Inventory | 2026-06-04 10:20:02 | -2.3 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-06-04 10:20:04 | -2.3 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-06-04 10:21:33 | -2.3 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-06-04 10:26:17 | -2.4 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-06-04 10:25:17 | -2.4 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-06-04 10:25:17 | -2.4 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-06-04 10:25:47 | -2.4 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-06-04 10:26:27 | -2.4 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-06-04 10:25:46 | -2.4 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-06-04 10:29:10 | -2.5 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-06-04 10:29:40 | -2.5 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-06-04 10:32:38 | -2.5 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-06-04 10:32:39 | -2.5 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-06-04 10:29:51 | -2.5 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-06-04 10:32:07 | -2.5 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-06-04 10:32:37 | -2.5 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-06-04 10:32:37 | -2.5 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-06-04 10:28:40 | -2.5 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-06-04 10:28:40 | -2.5 | [OK] Fresh |
| df_Fact_Transfers | 2026-06-04 10:36:08 | -2.6 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-06-04 10:39:22 | -2.6 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-06-04 10:38:22 | -2.6 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-06-04 10:39:52 | -2.6 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-06-04 10:39:22 | -2.6 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-06-04 10:38:25 | -2.6 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-06-04 10:40:22 | -2.7 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-06-04 12:33:30 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-06-03 14:01:58 | 18 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-06-04 09:22:00 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-06-04 09:18:02 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-06-04 09:21:00 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-06-04 09:26:00 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-06-04 09:24:05 | -1.4 | [OK] Fresh |
| df_GlTrans_Raw | 2026-06-04 09:23:00 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-06-04 09:45:51 | -1.7 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-06-04 09:43:35 | -1.7 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-06-04 09:46:21 | -1.7 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-06-04 09:45:51 | -1.7 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-06-04 09:50:05 | -1.8 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-06-04 09:46:53 | -1.8 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-06-04 09:50:05 | -1.8 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-06-04 09:51:36 | -1.8 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-06-04 09:46:53 | -1.8 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-06-04 09:50:06 | -1.8 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-06-04 09:52:06 | -1.8 | [OK] Fresh |
| df_INSALORD_Raw | 2026-06-04 09:50:06 | -1.8 | [OK] Fresh |
| df_InMaster_Raw | 2026-06-04 09:47:51 | -1.8 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-06-04 09:54:32 | -1.9 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-06-04 09:56:02 | -1.9 | [OK] Fresh |
| df_VhTrans_Raw | 2026-06-04 09:56:47 | -1.9 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-06-04 09:55:02 | -1.9 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-06-04 09:54:33 | -1.9 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-06-04 09:55:05 | -1.9 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-06-04 09:55:02 | -1.9 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-06-04 10:00:12 | -2 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-06-04 09:59:10 | -2 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-06-04 09:59:40 | -2 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-06-04 09:59:40 | -2 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-06-04 09:59:12 | -2 | [OK] Fresh |
| df_Technician_Raw | 2026-06-04 09:59:40 | -2 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-06-04 09:59:40 | -2 | [OK] Fresh |
| df_WarClaim_Raw | 2026-06-04 09:59:42 | -2 | [OK] Fresh |
| df_CONTACT_Raw | 2026-06-04 09:59:39 | -2 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-06-04 12:02:17 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-06-04 12:05:23 | -4.1 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

