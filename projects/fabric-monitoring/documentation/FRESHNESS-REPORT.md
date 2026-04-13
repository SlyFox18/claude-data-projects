# Data Freshness Report

**Generated:** 2026-04-13 08:01:19
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 74 | 86% |
| Stale | 0 | 0% |
| Critical | 12 | 14% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Dim_Source** (Dimension) - Last refreshed: 2026-04-01 12:32:43 (283.5 hours ago)
- **df_Dim_SLC** (Dimension) - Last refreshed: 2026-04-01 12:32:43 (283.5 hours ago)
- **df_Dim_DealerGroupCode** (Dimension) - Last refreshed: 2026-04-01 12:33:15 (283.5 hours ago)
- **df_Dim_Location** (Dimension) - Last refreshed: 2026-04-01 12:32:12 (283.5 hours ago)
- **df_Dim_PaymentMethod** (Dimension) - Last refreshed: 2026-04-01 12:36:30 (283.4 hours ago)
- **df_Dim_VendorCode** (Dimension) - Last refreshed: 2026-04-01 12:36:33 (283.4 hours ago)
- **df_Dim_ModuleType** (Dimension) - Last refreshed: 2026-04-01 12:36:29 (283.4 hours ago)
- **df_Dim_Franchise** (Dimension) - Last refreshed: 2026-04-01 12:34:17 (283.4 hours ago)
- **df_Dim_CommodityCode** (Dimension) - Last refreshed: 2026-04-01 12:36:59 (283.4 hours ago)
- **df_Dim_JobType** (Dimension) - Last refreshed: 2026-04-01 12:39:11 (283.4 hours ago)
- **df_Dim_AdjustmentType** (Dimension) - Last refreshed: 2026-04-01 12:35:59 (283.4 hours ago)
- **df_Dim_PromoType** (Dimension) - Last refreshed: 2026-04-01 12:43:40 (283.3 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_DealerGroupCode | 2026-04-01 12:33:15 | 283.5 | [CRIT] Critical |
| df_Dim_Location | 2026-04-01 12:32:12 | 283.5 | [CRIT] Critical |
| df_Dim_SLC | 2026-04-01 12:32:43 | 283.5 | [CRIT] Critical |
| df_Dim_Source | 2026-04-01 12:32:43 | 283.5 | [CRIT] Critical |
| df_Dim_JobType | 2026-04-01 12:39:11 | 283.4 | [CRIT] Critical |
| df_Dim_VendorCode | 2026-04-01 12:36:33 | 283.4 | [CRIT] Critical |
| df_Dim_PaymentMethod | 2026-04-01 12:36:30 | 283.4 | [CRIT] Critical |
| df_Dim_ModuleType | 2026-04-01 12:36:29 | 283.4 | [CRIT] Critical |
| df_Dim_CommodityCode | 2026-04-01 12:36:59 | 283.4 | [CRIT] Critical |
| df_Dim_Franchise | 2026-04-01 12:34:17 | 283.4 | [CRIT] Critical |
| df_Dim_AdjustmentType | 2026-04-01 12:35:59 | 283.4 | [CRIT] Critical |
| df_Dim_PromoType | 2026-04-01 12:43:40 | 283.3 | [CRIT] Critical |
| df_Dim_Customer | 2026-04-13 09:50:10 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-04-13 09:49:10 | -1.8 | [OK] Fresh |
| df_Dim_JobCode | 2026-04-13 09:54:30 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-04-13 09:54:30 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-04-13 09:54:29 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-04-13 09:54:59 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-04-13 09:52:19 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-04-13 09:55:30 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-04-13 09:54:01 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_FactPartTransactions_Incremental | 2026-04-13 09:57:55 | -1.9 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-04-13 10:02:56 | -2 | [OK] Fresh |
| df_Fact_Inventory | 2026-04-13 10:02:55 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-04-13 10:01:58 | -2 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-04-13 10:02:56 | -2 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-04-13 10:03:26 | -2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-04-13 10:08:17 | -2.1 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-04-13 10:08:12 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-04-13 10:08:43 | -2.1 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-04-13 10:07:43 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-04-13 10:07:10 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-04-13 10:07:44 | -2.1 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-04-13 10:11:29 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-04-13 10:12:30 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-04-13 10:10:58 | -2.2 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-04-13 10:15:13 | -2.2 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-04-13 10:15:12 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-04-13 10:15:15 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-04-13 10:11:56 | -2.2 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-04-13 10:15:13 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-04-13 10:15:12 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-04-13 10:11:28 | -2.2 | [OK] Fresh |
| df_Fact_Transfers | 2026-04-13 10:19:13 | -2.3 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-04-13 10:21:56 | -2.3 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-04-13 10:21:57 | -2.3 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-04-13 10:21:56 | -2.3 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-04-13 10:21:57 | -2.3 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-04-13 10:21:57 | -2.3 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-04-13 10:22:26 | -2.4 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Raw | 2026-04-13 09:20:23 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-04-13 09:21:23 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-04-13 09:20:22 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-04-13 09:17:53 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-04-13 09:23:53 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-04-13 09:24:23 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-04-13 09:28:23 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-04-13 09:32:36 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-04-13 09:31:36 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-04-13 09:31:07 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-04-13 09:31:37 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-04-13 09:31:37 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-04-13 09:31:06 | -1.5 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-04-13 09:36:19 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-04-13 09:35:49 | -1.6 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-04-13 09:39:00 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-04-13 09:34:49 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-04-13 09:39:00 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-04-13 09:39:00 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-04-13 09:40:01 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-04-13 09:39:00 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-04-13 09:34:48 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-04-13 09:38:30 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-04-13 09:34:49 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-04-13 09:38:30 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-04-13 09:34:48 | -1.6 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-04-13 09:42:45 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-04-13 09:42:45 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-04-13 09:43:15 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-04-13 09:42:46 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-04-13 09:42:45 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-04-13 09:42:15 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-04-13 09:42:45 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-04-13 09:42:45 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-04-13 09:42:45 | -1.7 | [OK] Fresh |
| df_GlTrans_Full_Raw | 2026-04-13 12:57:40 | -4.9 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

