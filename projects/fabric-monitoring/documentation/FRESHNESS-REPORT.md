# Data Freshness Report

**Generated:** 2026-05-22 08:01:30
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 75 | 77.3% |
| Stale | 6 | 6.2% |
| Critical | 4 | 4.1% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_GlMaster_Raw** (RawSource) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Last refreshed: 2026-05-06 15:04:38 (376.9 hours ago)
- **df_Dim_WkCodeFl** (Dimension) - Last refreshed: 2026-05-06 15:26:40 (376.6 hours ago)

---

## Stale - Monitor Closely

The following dataflows are approaching staleness:

- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-05-20 10:01:58 (46 hours ago)
- **df_Fact_OpenOrderParts** (FactTable) - Last refreshed: 2026-05-20 12:50:38 (43.2 hours ago)
- **df_Fact_OpenOrders** (FactTable) - Last refreshed: 2026-05-20 12:50:41 (43.2 hours ago)
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Last refreshed: 2026-05-20 12:55:53 (43.1 hours ago)
- **df_Fact_JobCodePartFrequency** (FactTable) - Last refreshed: 2026-05-20 12:54:14 (43.1 hours ago)
- **df_ServiceTimeSheets_Raw** (RawSource) - Last refreshed: 2026-05-20 16:19:52 (39.7 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | 2026-05-06 15:04:38 | 376.9 | [CRIT] Critical |
| df_Dim_WkCodeFl | 2026-05-06 15:26:40 | 376.6 | [CRIT] Critical |
| df_Dim_BranchUserAccess | 2026-05-20 10:01:58 | 46 | [WARN] Stale |
| df_Dim_Part | 2026-05-22 10:09:10 | -2.1 | [OK] Fresh |
| df_Dim_Customer | 2026-05-22 10:06:13 | -2.1 | [OK] Fresh |
| df_Dim_Date | 2026-05-22 10:06:49 | -2.1 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-05-22 10:11:22 | -2.2 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-05-22 10:11:21 | -2.2 | [OK] Fresh |
| df_Dim_Technicans | 2026-05-22 10:11:34 | -2.2 | [OK] Fresh |
| df_Dim_JobCode | 2026-05-22 10:11:36 | -2.2 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-05-22 10:12:23 | -2.2 | [OK] Fresh |
| df_Dim_Salesperson | 2026-05-22 10:11:23 | -2.2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrders | 2026-05-20 12:50:41 | 43.2 | [WARN] Stale |
| df_Fact_OpenOrderParts | 2026-05-20 12:50:38 | 43.2 | [WARN] Stale |
| df_Fact_JobCodePartFrequency | 2026-05-20 12:54:14 | 43.1 | [WARN] Stale |
| df_Fact_JobCodeFrequency_Branch | 2026-05-20 12:55:53 | 43.1 | [WARN] Stale |
| df_Fact_ServiceTimeSheet_Audit | 2026-05-21 13:45:47 | 18.3 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-05-22 10:15:11 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-05-22 10:20:11 | -2.3 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-05-22 10:20:40 | -2.3 | [OK] Fresh |
| df_Fact_Inventory | 2026-05-22 10:20:40 | -2.3 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-05-22 10:20:50 | -2.3 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-05-22 10:18:45 | -2.3 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-05-22 10:26:32 | -2.4 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-05-22 10:24:33 | -2.4 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-05-22 10:24:39 | -2.4 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-05-22 10:25:01 | -2.4 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-05-22 10:25:33 | -2.4 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-05-22 10:25:32 | -2.4 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-05-22 10:28:45 | -2.5 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-05-22 10:31:58 | -2.5 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-05-22 10:29:47 | -2.5 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-05-22 10:31:59 | -2.5 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-05-22 10:29:45 | -2.5 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-05-22 10:32:29 | -2.5 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-05-22 10:32:29 | -2.5 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-05-22 10:32:28 | -2.5 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-05-22 10:29:15 | -2.5 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-05-22 10:28:44 | -2.5 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-05-22 10:39:46 | -2.6 | [OK] Fresh |
| df_Fact_Transfers | 2026-05-22 10:36:28 | -2.6 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-05-22 10:39:15 | -2.6 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-05-22 10:39:13 | -2.6 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-05-22 10:39:15 | -2.6 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-05-22 10:39:14 | -2.6 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-05-22 10:39:15 | -2.6 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-05-22 12:33:29 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-05-20 16:19:52 | 39.7 | [WARN] Stale |
| df_Parts_InterbranchTransfer_Raw | 2026-05-22 09:17:44 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-05-22 09:21:14 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-05-22 09:22:14 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-05-22 09:20:15 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-05-22 09:25:14 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-05-22 09:23:44 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-05-22 09:46:18 | -1.7 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-05-22 09:44:03 | -1.7 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-05-22 09:46:18 | -1.7 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-05-22 09:47:18 | -1.8 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-05-22 09:51:30 | -1.8 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-05-22 09:47:18 | -1.8 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-05-22 09:50:30 | -1.8 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-05-22 09:46:48 | -1.8 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-05-22 09:50:30 | -1.8 | [OK] Fresh |
| df_INSALORD_Raw | 2026-05-22 09:51:30 | -1.8 | [OK] Fresh |
| df_InMaster_Raw | 2026-05-22 09:48:19 | -1.8 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-05-22 09:50:31 | -1.8 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-05-22 09:55:13 | -1.9 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-05-22 09:56:42 | -1.9 | [OK] Fresh |
| df_VhTrans_Raw | 2026-05-22 09:55:13 | -1.9 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-05-22 09:53:00 | -1.9 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-05-22 09:55:12 | -1.9 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-05-22 09:55:42 | -1.9 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-05-22 09:55:42 | -1.9 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-05-22 09:55:43 | -1.9 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-05-22 09:59:25 | -2 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-05-22 09:59:26 | -2 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-05-22 09:59:27 | -2 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-05-22 09:59:26 | -2 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-05-22 09:59:26 | -2 | [OK] Fresh |
| df_WarClaim_Raw | 2026-05-22 09:59:27 | -2 | [OK] Fresh |
| df_Technician_Raw | 2026-05-22 09:59:26 | -2 | [OK] Fresh |
| df_CONTACT_Raw | 2026-05-22 09:59:26 | -2 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-05-22 09:58:55 | -2 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

