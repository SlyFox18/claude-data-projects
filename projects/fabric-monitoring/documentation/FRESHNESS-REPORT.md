# Data Freshness Report

**Generated:** 2026-04-09 08:01:17
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 72 | 84.7% |
| Stale | 0 | 0% |
| Critical | 12 | 14.1% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Dim_Source** (Dimension) - Last refreshed: 2026-04-01 12:32:43 (187.5 hours ago)
- **df_Dim_SLC** (Dimension) - Last refreshed: 2026-04-01 12:32:43 (187.5 hours ago)
- **df_Dim_DealerGroupCode** (Dimension) - Last refreshed: 2026-04-01 12:33:15 (187.5 hours ago)
- **df_Dim_Location** (Dimension) - Last refreshed: 2026-04-01 12:32:12 (187.5 hours ago)
- **df_Dim_PaymentMethod** (Dimension) - Last refreshed: 2026-04-01 12:36:30 (187.4 hours ago)
- **df_Dim_VendorCode** (Dimension) - Last refreshed: 2026-04-01 12:36:33 (187.4 hours ago)
- **df_Dim_ModuleType** (Dimension) - Last refreshed: 2026-04-01 12:36:29 (187.4 hours ago)
- **df_Dim_Franchise** (Dimension) - Last refreshed: 2026-04-01 12:34:17 (187.4 hours ago)
- **df_Dim_CommodityCode** (Dimension) - Last refreshed: 2026-04-01 12:36:59 (187.4 hours ago)
- **df_Dim_JobType** (Dimension) - Last refreshed: 2026-04-01 12:39:11 (187.4 hours ago)
- **df_Dim_AdjustmentType** (Dimension) - Last refreshed: 2026-04-01 12:35:59 (187.4 hours ago)
- **df_Dim_PromoType** (Dimension) - Last refreshed: 2026-04-01 12:43:40 (187.3 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_DealerGroupCode | 2026-04-01 12:33:15 | 187.5 | [CRIT] Critical |
| df_Dim_Location | 2026-04-01 12:32:12 | 187.5 | [CRIT] Critical |
| df_Dim_SLC | 2026-04-01 12:32:43 | 187.5 | [CRIT] Critical |
| df_Dim_Source | 2026-04-01 12:32:43 | 187.5 | [CRIT] Critical |
| df_Dim_JobType | 2026-04-01 12:39:11 | 187.4 | [CRIT] Critical |
| df_Dim_VendorCode | 2026-04-01 12:36:33 | 187.4 | [CRIT] Critical |
| df_Dim_PaymentMethod | 2026-04-01 12:36:30 | 187.4 | [CRIT] Critical |
| df_Dim_ModuleType | 2026-04-01 12:36:29 | 187.4 | [CRIT] Critical |
| df_Dim_CommodityCode | 2026-04-01 12:36:59 | 187.4 | [CRIT] Critical |
| df_Dim_Franchise | 2026-04-01 12:34:17 | 187.4 | [CRIT] Critical |
| df_Dim_AdjustmentType | 2026-04-01 12:35:59 | 187.4 | [CRIT] Critical |
| df_Dim_PromoType | 2026-04-01 12:43:40 | 187.3 | [CRIT] Critical |
| df_Dim_Customer | 2026-04-09 10:05:27 | -2.1 | [OK] Fresh |
| df_Dim_Date | 2026-04-09 10:04:23 | -2.1 | [OK] Fresh |
| df_Dim_Part | 2026-04-09 10:07:57 | -2.1 | [OK] Fresh |
| df_Dim_Technicans | 2026-04-09 10:10:13 | -2.2 | [OK] Fresh |
| df_Dim_JobCode | 2026-04-09 10:10:42 | -2.2 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-04-09 10:10:13 | -2.2 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-04-09 10:11:13 | -2.2 | [OK] Fresh |
| df_Dim_Salesperson | 2026-04-09 10:10:10 | -2.2 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-04-09 10:10:11 | -2.2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_FactPartTransactions_Incremental | 2026-04-09 10:14:06 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-04-09 10:19:07 | -2.3 | [OK] Fresh |
| df_Fact_Inventory | 2026-04-09 10:19:35 | -2.3 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-04-09 10:17:34 | -2.3 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-04-09 10:20:05 | -2.3 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-04-09 10:19:35 | -2.3 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-04-09 10:27:34 | -2.4 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-04-09 10:28:05 | -2.4 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-04-09 10:25:23 | -2.4 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-04-09 10:23:54 | -2.4 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-04-09 10:23:56 | -2.4 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-04-09 10:24:53 | -2.4 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-04-09 10:24:54 | -2.4 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-04-09 10:24:23 | -2.4 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-04-09 10:28:05 | -2.4 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-04-09 10:32:15 | -2.5 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-04-09 10:28:37 | -2.5 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-04-09 10:31:45 | -2.5 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-04-09 10:31:45 | -2.5 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-04-09 10:31:47 | -2.5 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-04-09 10:32:16 | -2.5 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-04-09 10:29:04 | -2.5 | [OK] Fresh |
| df_Fact_Transfers | 2026-04-09 10:34:45 | -2.6 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-04-09 10:37:01 | -2.6 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-04-09 10:38:01 | -2.6 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-04-09 10:37:30 | -2.6 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-04-09 10:37:00 | -2.6 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-04-09 10:37:00 | -2.6 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_WKROFILE_Raw | 2026-04-09 09:20:25 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-04-09 09:17:55 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-04-09 09:21:56 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-04-09 09:21:25 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-04-09 09:23:56 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-04-09 09:24:56 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-04-09 09:43:34 | -1.7 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-04-09 09:45:46 | -1.7 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-04-09 09:49:28 | -1.8 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-04-09 09:49:33 | -1.8 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-04-09 09:50:58 | -1.8 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-04-09 09:50:58 | -1.8 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-04-09 09:46:46 | -1.8 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-04-09 09:46:46 | -1.8 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-04-09 09:46:46 | -1.8 | [OK] Fresh |
| df_InMaster_Raw | 2026-04-09 09:47:16 | -1.8 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-04-09 09:46:17 | -1.8 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-04-09 09:49:28 | -1.8 | [OK] Fresh |
| df_INSALORD_Raw | 2026-04-09 09:49:28 | -1.8 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-04-09 09:57:27 | -1.9 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-04-09 09:53:44 | -1.9 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-04-09 09:57:27 | -1.9 | [OK] Fresh |
| df_WarClaim_Raw | 2026-04-09 09:57:27 | -1.9 | [OK] Fresh |
| df_VhTrans_Raw | 2026-04-09 09:53:46 | -1.9 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-04-09 09:57:27 | -1.9 | [OK] Fresh |
| df_CONTACT_Raw | 2026-04-09 09:57:27 | -1.9 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-04-09 09:57:27 | -1.9 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-04-09 09:57:27 | -1.9 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-04-09 09:57:27 | -1.9 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-04-09 09:53:14 | -1.9 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-04-09 09:53:45 | -1.9 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-04-09 09:54:44 | -1.9 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-04-09 09:53:44 | -1.9 | [OK] Fresh |
| df_Technician_Raw | 2026-04-09 09:57:27 | -1.9 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-04-09 09:53:15 | -1.9 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

