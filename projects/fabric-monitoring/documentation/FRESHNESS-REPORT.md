# Data Freshness Report

**Generated:** 2026-04-17 08:01:24
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 75 | 85.2% |
| Stale | 0 | 0% |
| Critical | 12 | 13.6% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Dim_Source** (Dimension) - Last refreshed: 2026-04-01 12:32:43 (379.5 hours ago)
- **df_Dim_SLC** (Dimension) - Last refreshed: 2026-04-01 12:32:43 (379.5 hours ago)
- **df_Dim_DealerGroupCode** (Dimension) - Last refreshed: 2026-04-01 12:33:15 (379.5 hours ago)
- **df_Dim_Location** (Dimension) - Last refreshed: 2026-04-01 12:32:12 (379.5 hours ago)
- **df_Dim_PaymentMethod** (Dimension) - Last refreshed: 2026-04-01 12:36:30 (379.4 hours ago)
- **df_Dim_VendorCode** (Dimension) - Last refreshed: 2026-04-01 12:36:33 (379.4 hours ago)
- **df_Dim_ModuleType** (Dimension) - Last refreshed: 2026-04-01 12:36:29 (379.4 hours ago)
- **df_Dim_Franchise** (Dimension) - Last refreshed: 2026-04-01 12:34:17 (379.4 hours ago)
- **df_Dim_CommodityCode** (Dimension) - Last refreshed: 2026-04-01 12:36:59 (379.4 hours ago)
- **df_Dim_JobType** (Dimension) - Last refreshed: 2026-04-01 12:39:11 (379.4 hours ago)
- **df_Dim_AdjustmentType** (Dimension) - Last refreshed: 2026-04-01 12:35:59 (379.4 hours ago)
- **df_Dim_PromoType** (Dimension) - Last refreshed: 2026-04-01 12:43:40 (379.3 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_SLC | 2026-04-01 12:32:43 | 379.5 | [CRIT] Critical |
| df_Dim_DealerGroupCode | 2026-04-01 12:33:15 | 379.5 | [CRIT] Critical |
| df_Dim_Source | 2026-04-01 12:32:43 | 379.5 | [CRIT] Critical |
| df_Dim_Location | 2026-04-01 12:32:12 | 379.5 | [CRIT] Critical |
| df_Dim_JobType | 2026-04-01 12:39:11 | 379.4 | [CRIT] Critical |
| df_Dim_AdjustmentType | 2026-04-01 12:35:59 | 379.4 | [CRIT] Critical |
| df_Dim_VendorCode | 2026-04-01 12:36:33 | 379.4 | [CRIT] Critical |
| df_Dim_PaymentMethod | 2026-04-01 12:36:30 | 379.4 | [CRIT] Critical |
| df_Dim_ModuleType | 2026-04-01 12:36:29 | 379.4 | [CRIT] Critical |
| df_Dim_CommodityCode | 2026-04-01 12:36:59 | 379.4 | [CRIT] Critical |
| df_Dim_Franchise | 2026-04-01 12:34:17 | 379.4 | [CRIT] Critical |
| df_Dim_PromoType | 2026-04-01 12:43:40 | 379.3 | [CRIT] Critical |
| df_Dim_BranchUserAccess | 2026-04-15 21:33:59 | 34.5 | [OK] Fresh |
| df_Dim_Customer | 2026-04-17 09:49:42 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-04-17 09:48:40 | -1.8 | [OK] Fresh |
| df_Dim_Part | 2026-04-17 09:51:41 | -1.8 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-04-17 09:54:00 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-04-17 09:53:50 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-04-17 09:53:52 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-04-17 09:53:51 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-04-17 09:54:52 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-04-17 09:53:52 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_FactPartTransactions_Incremental | 2026-04-17 09:57:17 | -1.9 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-04-17 10:02:16 | -2 | [OK] Fresh |
| df_Fact_Inventory | 2026-04-17 10:02:16 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-04-17 10:01:17 | -2 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-04-17 10:02:46 | -2 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-04-17 10:02:46 | -2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-04-17 10:07:51 | -2.1 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-04-17 10:07:49 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-04-17 10:08:22 | -2.1 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-04-17 10:07:18 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-04-17 10:07:19 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-04-17 10:07:01 | -2.1 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-04-17 10:11:07 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-04-17 10:12:08 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-04-17 10:10:37 | -2.2 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-04-17 10:14:49 | -2.2 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-04-17 10:14:49 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-04-17 10:14:50 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-04-17 10:12:02 | -2.2 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-04-17 10:15:18 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-04-17 10:14:51 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-04-17 10:11:07 | -2.2 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-04-17 10:21:33 | -2.3 | [OK] Fresh |
| df_Fact_Transfers | 2026-04-17 10:18:19 | -2.3 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-04-17 10:21:01 | -2.3 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-04-17 10:21:03 | -2.3 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-04-17 10:21:01 | -2.3 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-04-17 10:20:31 | -2.3 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-04-17 10:21:03 | -2.3 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | 2026-04-16 01:32:30 | 30.5 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-04-17 09:18:15 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-04-17 09:21:44 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-04-17 09:20:14 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-04-17 09:21:44 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-04-17 09:23:15 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-04-17 09:28:14 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-04-17 09:23:45 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-04-17 09:30:55 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-04-17 09:32:26 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-04-17 09:31:28 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-04-17 09:30:55 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-04-17 09:31:55 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-04-17 09:30:56 | -1.5 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-04-17 09:38:49 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-04-17 09:35:09 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-04-17 09:36:08 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-04-17 09:40:19 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-04-17 09:38:53 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-04-17 09:38:52 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-04-17 09:34:39 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-04-17 09:34:37 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-04-17 09:38:49 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-04-17 09:34:39 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-04-17 09:34:38 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-04-17 09:38:19 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-04-17 09:38:50 | -1.6 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-04-17 09:43:01 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-04-17 09:43:01 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-04-17 09:43:01 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-04-17 09:43:01 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-04-17 09:43:01 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-04-17 09:42:31 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-04-17 09:43:01 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-04-17 09:43:01 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-04-17 09:42:33 | -1.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

