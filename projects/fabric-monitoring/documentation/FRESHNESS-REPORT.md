# Data Freshness Report

**Generated:** 2026-04-21 08:01:27
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 73 | 83% |
| Stale | 0 | 0% |
| Critical | 14 | 15.9% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Dim_DealerGroupCode** (Dimension) - Last refreshed: 2026-04-01 12:33:15 (475.5 hours ago)
- **df_Dim_SLC** (Dimension) - Last refreshed: 2026-04-01 12:32:43 (475.5 hours ago)
- **df_Dim_Source** (Dimension) - Last refreshed: 2026-04-01 12:32:43 (475.5 hours ago)
- **df_Dim_Location** (Dimension) - Last refreshed: 2026-04-01 12:32:12 (475.5 hours ago)
- **df_Dim_ModuleType** (Dimension) - Last refreshed: 2026-04-01 12:36:29 (475.4 hours ago)
- **df_Dim_PaymentMethod** (Dimension) - Last refreshed: 2026-04-01 12:36:30 (475.4 hours ago)
- **df_Dim_VendorCode** (Dimension) - Last refreshed: 2026-04-01 12:36:33 (475.4 hours ago)
- **df_Dim_Franchise** (Dimension) - Last refreshed: 2026-04-01 12:34:17 (475.4 hours ago)
- **df_Dim_CommodityCode** (Dimension) - Last refreshed: 2026-04-01 12:36:59 (475.4 hours ago)
- **df_Dim_JobType** (Dimension) - Last refreshed: 2026-04-01 12:39:11 (475.4 hours ago)
- **df_Dim_AdjustmentType** (Dimension) - Last refreshed: 2026-04-01 12:35:59 (475.4 hours ago)
- **df_Dim_PromoType** (Dimension) - Last refreshed: 2026-04-01 12:43:40 (475.3 hours ago)
- **df_GlTrans_Full_Raw** (RawSource) - Last refreshed: 2026-04-16 01:32:30 (126.5 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-04-17 14:51:30 (89.2 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_SLC | 2026-04-01 12:32:43 | 475.5 | [CRIT] Critical |
| df_Dim_DealerGroupCode | 2026-04-01 12:33:15 | 475.5 | [CRIT] Critical |
| df_Dim_Source | 2026-04-01 12:32:43 | 475.5 | [CRIT] Critical |
| df_Dim_Location | 2026-04-01 12:32:12 | 475.5 | [CRIT] Critical |
| df_Dim_JobType | 2026-04-01 12:39:11 | 475.4 | [CRIT] Critical |
| df_Dim_AdjustmentType | 2026-04-01 12:35:59 | 475.4 | [CRIT] Critical |
| df_Dim_VendorCode | 2026-04-01 12:36:33 | 475.4 | [CRIT] Critical |
| df_Dim_PaymentMethod | 2026-04-01 12:36:30 | 475.4 | [CRIT] Critical |
| df_Dim_ModuleType | 2026-04-01 12:36:29 | 475.4 | [CRIT] Critical |
| df_Dim_CommodityCode | 2026-04-01 12:36:59 | 475.4 | [CRIT] Critical |
| df_Dim_Franchise | 2026-04-01 12:34:17 | 475.4 | [CRIT] Critical |
| df_Dim_PromoType | 2026-04-01 12:43:40 | 475.3 | [CRIT] Critical |
| df_Dim_BranchUserAccess | 2026-04-17 14:51:30 | 89.2 | [CRIT] Critical |
| df_Dim_Customer | 2026-04-21 09:49:22 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-04-21 09:48:22 | -1.8 | [OK] Fresh |
| df_Dim_Part | 2026-04-21 09:51:51 | -1.8 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-04-21 09:54:02 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-04-21 09:54:02 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-04-21 09:54:05 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-04-21 09:54:02 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-04-21 09:55:01 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-04-21 09:54:05 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_FactPartTransactions_Incremental | 2026-04-21 09:57:23 | -1.9 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-04-21 10:02:53 | -2 | [OK] Fresh |
| df_Fact_Inventory | 2026-04-21 10:02:23 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-04-21 10:01:54 | -2 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-04-21 10:03:24 | -2 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-04-21 10:02:54 | -2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-04-21 10:08:12 | -2.1 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-04-21 10:08:12 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-04-21 10:09:13 | -2.1 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-04-21 10:08:14 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-04-21 10:07:12 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-04-21 10:07:12 | -2.1 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-04-21 10:11:58 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-04-21 10:12:55 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-04-21 10:11:56 | -2.2 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-04-21 10:16:13 | -2.2 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-04-21 10:15:43 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-04-21 10:15:43 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-04-21 10:12:27 | -2.2 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-04-21 10:16:13 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-04-21 10:15:13 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-04-21 10:11:55 | -2.2 | [OK] Fresh |
| df_Fact_Transfers | 2026-04-21 10:19:13 | -2.3 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-04-21 10:21:56 | -2.3 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-04-21 10:21:56 | -2.3 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-04-21 10:21:57 | -2.3 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-04-21 10:21:56 | -2.3 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-04-21 10:21:56 | -2.3 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-04-21 10:22:26 | -2.4 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | 2026-04-16 01:32:30 | 126.5 | [CRIT] Critical |
| df_WKROFILE_Raw | 2026-04-21 09:20:24 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-04-21 09:21:24 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-04-21 09:18:23 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-04-21 09:22:24 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-04-21 09:27:54 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-04-21 09:23:54 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-04-21 09:23:24 | -1.4 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-04-21 09:30:07 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-04-21 09:31:09 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-04-21 09:30:07 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-04-21 09:31:07 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-04-21 09:31:06 | -1.5 | [OK] Fresh |
| df_INSALORD_Raw | 2026-04-21 09:34:20 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-04-21 09:32:07 | -1.5 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-04-21 09:34:20 | -1.5 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-04-21 09:34:20 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-04-21 09:39:47 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-04-21 09:35:50 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-04-21 09:34:50 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-04-21 09:38:48 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-04-21 09:38:48 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-04-21 09:36:03 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-04-21 09:38:18 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-04-21 09:38:49 | -1.6 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-04-21 09:38:48 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-04-21 09:38:48 | -1.6 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-04-21 09:42:33 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-04-21 09:42:31 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-04-21 09:42:31 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-04-21 09:42:32 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-04-21 09:42:32 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-04-21 09:42:33 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-04-21 09:42:32 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-04-21 09:42:31 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-04-21 09:42:31 | -1.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

