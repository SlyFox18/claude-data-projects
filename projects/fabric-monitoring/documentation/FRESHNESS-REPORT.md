# Data Freshness Report

**Generated:** 2026-04-10 08:01:19
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 73 | 85.9% |
| Stale | 0 | 0% |
| Critical | 12 | 14.1% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Dim_Source** (Dimension) - Last refreshed: 2026-04-01 12:32:43 (211.5 hours ago)
- **df_Dim_SLC** (Dimension) - Last refreshed: 2026-04-01 12:32:43 (211.5 hours ago)
- **df_Dim_DealerGroupCode** (Dimension) - Last refreshed: 2026-04-01 12:33:15 (211.5 hours ago)
- **df_Dim_Location** (Dimension) - Last refreshed: 2026-04-01 12:32:12 (211.5 hours ago)
- **df_Dim_PaymentMethod** (Dimension) - Last refreshed: 2026-04-01 12:36:30 (211.4 hours ago)
- **df_Dim_VendorCode** (Dimension) - Last refreshed: 2026-04-01 12:36:33 (211.4 hours ago)
- **df_Dim_ModuleType** (Dimension) - Last refreshed: 2026-04-01 12:36:29 (211.4 hours ago)
- **df_Dim_Franchise** (Dimension) - Last refreshed: 2026-04-01 12:34:17 (211.4 hours ago)
- **df_Dim_CommodityCode** (Dimension) - Last refreshed: 2026-04-01 12:36:59 (211.4 hours ago)
- **df_Dim_JobType** (Dimension) - Last refreshed: 2026-04-01 12:39:11 (211.4 hours ago)
- **df_Dim_AdjustmentType** (Dimension) - Last refreshed: 2026-04-01 12:35:59 (211.4 hours ago)
- **df_Dim_PromoType** (Dimension) - Last refreshed: 2026-04-01 12:43:40 (211.3 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_DealerGroupCode | 2026-04-01 12:33:15 | 211.5 | [CRIT] Critical |
| df_Dim_Location | 2026-04-01 12:32:12 | 211.5 | [CRIT] Critical |
| df_Dim_SLC | 2026-04-01 12:32:43 | 211.5 | [CRIT] Critical |
| df_Dim_Source | 2026-04-01 12:32:43 | 211.5 | [CRIT] Critical |
| df_Dim_JobType | 2026-04-01 12:39:11 | 211.4 | [CRIT] Critical |
| df_Dim_VendorCode | 2026-04-01 12:36:33 | 211.4 | [CRIT] Critical |
| df_Dim_PaymentMethod | 2026-04-01 12:36:30 | 211.4 | [CRIT] Critical |
| df_Dim_ModuleType | 2026-04-01 12:36:29 | 211.4 | [CRIT] Critical |
| df_Dim_CommodityCode | 2026-04-01 12:36:59 | 211.4 | [CRIT] Critical |
| df_Dim_Franchise | 2026-04-01 12:34:17 | 211.4 | [CRIT] Critical |
| df_Dim_AdjustmentType | 2026-04-01 12:35:59 | 211.4 | [CRIT] Critical |
| df_Dim_PromoType | 2026-04-01 12:43:40 | 211.3 | [CRIT] Critical |
| df_Dim_Customer | 2026-04-10 09:50:30 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-04-10 09:49:29 | -1.8 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-04-10 09:57:59 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-04-10 09:58:00 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-04-10 09:58:02 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-04-10 09:52:59 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-04-10 09:57:59 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-04-10 09:57:29 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-04-10 09:58:59 | -2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_AdjustmentPairs | 2026-04-09 15:07:30 | 16.9 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-04-10 10:02:04 | -2 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-04-10 10:07:05 | -2.1 | [OK] Fresh |
| df_Fact_Inventory | 2026-04-10 10:06:35 | -2.1 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-04-10 10:06:07 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-04-10 10:07:05 | -2.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-04-10 10:07:05 | -2.1 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-04-10 10:15:03 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-04-10 10:14:33 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-04-10 10:12:22 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-04-10 10:15:05 | -2.2 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-04-10 10:10:48 | -2.2 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-04-10 10:10:51 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-04-10 10:16:03 | -2.2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-04-10 10:11:49 | -2.2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-04-10 10:11:53 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-04-10 10:16:04 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-04-10 10:11:35 | -2.2 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-04-10 10:18:46 | -2.3 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-04-10 10:19:16 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-04-10 10:18:46 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-04-10 10:18:16 | -2.3 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-04-10 10:19:16 | -2.3 | [OK] Fresh |
| df_Fact_Transfers | 2026-04-10 10:22:16 | -2.4 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-04-10 10:24:30 | -2.4 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-04-10 10:25:29 | -2.4 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-04-10 10:25:01 | -2.4 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-04-10 10:24:31 | -2.4 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-04-10 10:24:29 | -2.4 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_WKROFILE_Raw | 2026-04-10 09:20:28 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-04-10 09:17:58 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-04-10 09:21:58 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-04-10 09:21:58 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-04-10 09:23:28 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-04-10 09:23:58 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-04-10 09:28:28 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-04-10 09:31:03 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-04-10 09:31:33 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-04-10 09:33:02 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-04-10 09:32:02 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-04-10 09:32:03 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-04-10 09:32:03 | -1.5 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-04-10 09:39:31 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-04-10 09:39:34 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-04-10 09:36:48 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-04-10 09:35:17 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-04-10 09:36:24 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-04-10 09:39:30 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-04-10 09:35:14 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-04-10 09:39:30 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-04-10 09:35:16 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-04-10 09:39:31 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-04-10 09:39:01 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-04-10 09:35:14 | -1.6 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-04-10 09:42:46 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-04-10 09:43:46 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-04-10 09:43:16 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-04-10 09:42:47 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-04-10 09:43:46 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-04-10 09:43:19 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-04-10 09:42:16 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-04-10 09:40:31 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-04-10 09:43:16 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-04-10 09:43:16 | -1.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

