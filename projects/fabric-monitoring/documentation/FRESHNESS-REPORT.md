# Data Freshness Report

**Generated:** 2026-05-01 08:01:24
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 85 | 96.6% |
| Stale | 0 | 0% |
| Critical | 2 | 2.3% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_GlTrans_Full_Raw** (RawSource) - Last refreshed: 2026-04-16 01:32:30 (366.5 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-04-23 19:54:02 (180.1 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_BranchUserAccess | 2026-04-23 19:54:02 | 180.1 | [CRIT] Critical |
| df_Dim_Customer | 2026-05-01 09:50:11 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-05-01 09:49:10 | -1.8 | [OK] Fresh |
| df_Dim_Part | 2026-05-01 09:52:10 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-05-01 09:54:21 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-05-01 09:54:20 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-05-01 09:53:50 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-05-01 09:54:50 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-05-01 09:54:20 | -1.9 | [OK] Fresh |
| df_Dim_SLC | 2026-05-01 12:32:47 | -4.5 | [OK] Fresh |
| df_Dim_Location | 2026-05-01 12:32:17 | -4.5 | [OK] Fresh |
| df_Dim_Source | 2026-05-01 12:32:18 | -4.5 | [OK] Fresh |
| df_Dim_DealerGroupCode | 2026-05-01 12:32:47 | -4.5 | [OK] Fresh |
| df_Dim_Franchise | 2026-05-01 12:32:48 | -4.5 | [OK] Fresh |
| df_Dim_VendorCode | 2026-05-01 12:34:32 | -4.6 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-05-01 12:38:40 | -4.6 | [OK] Fresh |
| df_Dim_AdjustmentType | 2026-05-01 12:34:27 | -4.6 | [OK] Fresh |
| df_Dim_JobType | 2026-05-01 12:37:40 | -4.6 | [OK] Fresh |
| df_Dim_CommodityCode | 2026-05-01 12:35:30 | -4.6 | [OK] Fresh |
| df_Dim_PromoType | 2026-05-01 12:40:10 | -4.6 | [OK] Fresh |
| df_Dim_PaymentMethod | 2026-05-01 12:34:28 | -4.6 | [OK] Fresh |
| df_Dim_ModuleType | 2026-05-01 12:34:57 | -4.6 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_FactPartTransactions_Incremental | 2026-05-01 10:01:06 | -2 | [OK] Fresh |
| df_Fact_Inventory | 2026-05-01 10:02:31 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-05-01 10:02:30 | -2 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-05-01 10:03:00 | -2 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-05-01 10:03:05 | -2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-05-01 10:02:30 | -2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-05-01 10:07:04 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-05-01 10:07:59 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-05-01 10:06:55 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-05-01 10:06:57 | -2.1 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-05-01 10:07:57 | -2.1 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-05-01 10:13:37 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-05-01 10:13:07 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-05-01 10:14:44 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-05-01 10:13:38 | -2.2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-05-01 10:10:53 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-05-01 10:14:07 | -2.2 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-05-01 10:16:58 | -2.3 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-05-01 10:17:58 | -2.3 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-05-01 10:16:58 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-05-01 10:16:58 | -2.3 | [OK] Fresh |
| df_Fact_Transfers | 2026-05-01 10:20:58 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-05-01 10:17:28 | -2.3 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-05-01 10:23:45 | -2.4 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-05-01 10:24:45 | -2.4 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-05-01 10:23:44 | -2.4 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-05-01 10:23:14 | -2.4 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-05-01 10:23:45 | -2.4 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-05-01 10:23:44 | -2.4 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | 2026-04-16 01:32:30 | 366.5 | [CRIT] Critical |
| df_Parts_InterbranchTransfer_Raw | 2026-05-01 09:17:43 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-05-01 09:19:45 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-05-01 09:23:14 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-05-01 09:23:43 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-05-01 09:28:13 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-05-01 09:24:12 | -1.4 | [OK] Fresh |
| df_GlTrans_Raw | 2026-05-01 09:25:13 | -1.4 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-05-01 09:30:55 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-05-01 09:30:27 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-05-01 09:30:55 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-05-01 09:31:25 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-05-01 09:30:26 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-05-01 09:32:26 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-05-01 09:35:39 | -1.6 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-05-01 09:38:50 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-05-01 09:36:09 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-05-01 09:39:50 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-05-01 09:38:50 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-05-01 09:38:50 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-05-01 09:34:39 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-05-01 09:34:39 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-05-01 09:38:51 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-05-01 09:34:39 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-05-01 09:34:40 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-05-01 09:38:20 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-05-01 09:38:51 | -1.6 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-05-01 09:42:32 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-05-01 09:42:32 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-05-01 09:42:32 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-05-01 09:42:32 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-05-01 09:42:32 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-05-01 09:42:02 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-05-01 09:42:32 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-05-01 09:42:32 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-05-01 09:43:33 | -1.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

