# Data Freshness Report

**Generated:** 2026-06-08 08:01:30
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 76 | 76% |
| Stale | 2 | 2% |
| Critical | 6 | 6% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Dim_WkCodeFl** (Dimension) - Never refreshed!
- **df_GlMaster_Raw** (RawSource) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Never refreshed!
- **df_Dim_Franchise** (Dimension) - Last refreshed: 2026-06-01 12:33:08 (163.5 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-06-03 10:01:27 (118 hours ago)

---

## Stale - Monitor Closely

The following dataflows are approaching staleness:

- **df_ServiceTimeSheets_Raw** (RawSource) - Last refreshed: 2026-06-05 14:02:06 (66 hours ago)
- **df_Fact_ServiceTimeSheet_Audit** (FactTable) - Last refreshed: 2026-06-05 14:17:58 (65.7 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_Franchise | 2026-06-01 12:33:08 | 163.5 | [CRIT] Critical |
| df_Dim_BranchUserAccess | 2026-06-03 10:01:27 | 118 | [CRIT] Critical |
| df_Dim_Part | 2026-06-08 10:08:49 | -2.1 | [OK] Fresh |
| df_Dim_Customer | 2026-06-08 10:06:19 | -2.1 | [OK] Fresh |
| df_Dim_Date | 2026-06-08 10:05:25 | -2.1 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-06-08 10:10:38 | -2.2 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-06-08 10:11:18 | -2.2 | [OK] Fresh |
| df_Dim_Technicans | 2026-06-08 10:11:06 | -2.2 | [OK] Fresh |
| df_Dim_JobCode | 2026-06-08 10:11:07 | -2.2 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-06-08 10:12:08 | -2.2 | [OK] Fresh |
| df_Dim_Salesperson | 2026-06-08 10:11:07 | -2.2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_ServiceTimeSheet_Audit | 2026-06-05 14:17:58 | 65.7 | [WARN] Stale |
| df_FactPartTransactions_Incremental | 2026-06-08 10:14:42 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-06-08 10:19:39 | -2.3 | [OK] Fresh |
| df_Fact_Inventory | 2026-06-08 10:19:09 | -2.3 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-06-08 10:18:39 | -2.3 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-06-08 10:19:40 | -2.3 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-06-08 10:20:40 | -2.3 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-06-08 10:25:22 | -2.4 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-06-08 10:25:22 | -2.4 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-06-08 10:27:35 | -2.4 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-06-08 10:24:23 | -2.4 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-06-08 10:24:23 | -2.4 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-06-08 10:27:35 | -2.4 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-06-08 10:24:58 | -2.4 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-06-08 10:28:05 | -2.4 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-06-08 10:25:23 | -2.4 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-06-08 10:29:08 | -2.5 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-06-08 10:33:58 | -2.5 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-06-08 10:33:58 | -2.5 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-06-08 10:33:28 | -2.5 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-06-08 10:31:16 | -2.5 | [OK] Fresh |
| df_Fact_Transfers | 2026-06-08 10:37:29 | -2.6 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-06-08 10:34:28 | -2.6 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-06-08 10:40:12 | -2.6 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-06-08 10:34:30 | -2.6 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-06-08 10:40:13 | -2.6 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-06-08 10:39:43 | -2.6 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-06-08 10:39:43 | -2.6 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-06-08 10:42:51 | -2.7 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-06-08 10:40:42 | -2.7 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-06-08 12:33:29 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-06-05 14:02:06 | 66 | [WARN] Stale |
| df_InHist_PmManage_Raw | 2026-06-08 09:22:17 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-06-08 09:17:47 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-06-08 09:20:47 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-06-08 09:27:44 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-06-08 09:24:17 | -1.4 | [OK] Fresh |
| df_GlTrans_Raw | 2026-06-08 09:23:47 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-06-08 09:45:56 | -1.7 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-06-08 09:43:41 | -1.7 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-06-08 09:46:24 | -1.7 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-06-08 09:45:54 | -1.7 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-06-08 09:50:39 | -1.8 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-06-08 09:47:54 | -1.8 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-06-08 09:51:08 | -1.8 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-06-08 09:50:10 | -1.8 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-06-08 09:46:54 | -1.8 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-06-08 09:51:39 | -1.8 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-06-08 09:50:39 | -1.8 | [OK] Fresh |
| df_INSALORD_Raw | 2026-06-08 09:50:09 | -1.8 | [OK] Fresh |
| df_InMaster_Raw | 2026-06-08 09:47:54 | -1.8 | [OK] Fresh |
| df_WarClaim_Raw | 2026-06-08 09:57:48 | -1.9 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-06-08 09:55:23 | -1.9 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-06-08 09:54:24 | -1.9 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-06-08 09:57:48 | -1.9 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-06-08 09:57:49 | -1.9 | [OK] Fresh |
| df_VhTrans_Raw | 2026-06-08 09:54:54 | -1.9 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-06-08 09:53:52 | -1.9 | [OK] Fresh |
| df_Technician_Raw | 2026-06-08 09:58:18 | -1.9 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-06-08 09:57:49 | -1.9 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-06-08 09:53:53 | -1.9 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-06-08 09:54:23 | -1.9 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-06-08 09:54:23 | -1.9 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-06-08 09:58:18 | -2 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-06-08 09:58:19 | -2 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-06-08 09:58:19 | -2 | [OK] Fresh |
| df_CONTACT_Raw | 2026-06-08 09:58:18 | -2 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-06-08 12:02:14 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-06-08 12:04:40 | -4.1 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

