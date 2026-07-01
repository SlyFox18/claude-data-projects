# Data Freshness Report

**Generated:** 2026-07-01 08:01:39
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 91 | 91% |
| Stale | 0 | 0% |
| Critical | 3 | 3% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_Date | 2026-07-01 09:54:43 | -1.9 | [OK] Fresh |
| df_Dim_Customer | 2026-07-01 09:55:42 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-07-01 09:57:40 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-07-01 10:00:16 | -2 | [OK] Fresh |
| df_Dim_Salesperson | 2026-07-01 09:59:53 | -2 | [OK] Fresh |
| df_Dim_Technicans | 2026-07-01 09:59:47 | -2 | [OK] Fresh |
| df_Dim_BranchUserAccess | 2026-07-01 10:02:13 | -2 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-07-01 10:00:16 | -2 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-07-01 09:59:52 | -2 | [OK] Fresh |
| df_Dim_VendorCode | 2026-07-01 12:34:14 | -4.5 | [OK] Fresh |
| df_Dim_PaymentMethod | 2026-07-01 12:34:14 | -4.5 | [OK] Fresh |
| df_Dim_Source | 2026-07-01 12:32:05 | -4.5 | [OK] Fresh |
| df_Dim_SLC | 2026-07-01 12:32:35 | -4.5 | [OK] Fresh |
| df_Dim_Location | 2026-07-01 12:32:06 | -4.5 | [OK] Fresh |
| df_Dim_DealerGroupCode | 2026-07-01 12:32:35 | -4.5 | [OK] Fresh |
| df_Dim_Franchise | 2026-07-01 12:32:35 | -4.5 | [OK] Fresh |
| df_Dim_AdjustmentType | 2026-07-01 12:34:15 | -4.5 | [OK] Fresh |
| df_Dim_CommodityCode | 2026-07-01 12:35:15 | -4.6 | [OK] Fresh |
| df_Dim_ModuleType | 2026-07-01 12:34:45 | -4.6 | [OK] Fresh |
| df_Dim_PromoType | 2026-07-01 12:39:26 | -4.6 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-07-01 12:38:25 | -4.6 | [OK] Fresh |
| df_Dim_JobType | 2026-07-01 12:37:25 | -4.6 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceTimeSheet_Audit | 2026-06-30 14:19:59 | 17.7 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-07-01 10:03:47 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-07-01 10:08:32 | -2.1 | [OK] Fresh |
| df_Fact_Inventory | 2026-07-01 10:09:35 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-07-01 10:09:51 | -2.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-07-01 10:10:22 | -2.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-07-01 10:10:20 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-07-01 10:14:19 | -2.2 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-07-01 10:14:41 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-07-01 10:15:49 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-07-01 10:14:46 | -2.2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-07-01 10:15:12 | -2.2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-07-01 10:15:39 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-07-01 10:19:22 | -2.3 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-07-01 10:19:26 | -2.3 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-07-01 10:18:27 | -2.3 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-07-01 10:19:02 | -2.3 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-07-01 10:19:51 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-07-01 10:22:30 | -2.4 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-07-01 10:22:36 | -2.4 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-07-01 10:23:11 | -2.4 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-07-01 10:22:39 | -2.4 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-07-01 10:22:33 | -2.4 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-07-01 10:32:20 | -2.5 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-07-01 10:32:48 | -2.5 | [OK] Fresh |
| df_Fact_Transfers | 2026-07-01 10:28:42 | -2.5 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-07-01 10:32:19 | -2.5 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-07-01 10:31:21 | -2.5 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-07-01 10:31:51 | -2.5 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-07-01 10:31:47 | -2.5 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-07-01 12:33:02 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-06-30 14:02:27 | 18 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-07-01 09:18:18 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-07-01 09:20:47 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-07-01 09:22:17 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-07-01 09:26:49 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-07-01 09:23:46 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-07-01 09:24:18 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-07-01 09:31:59 | -1.5 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-07-01 09:29:48 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-07-01 09:31:59 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-07-01 09:32:29 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-07-01 09:32:58 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-07-01 09:32:58 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-07-01 09:39:15 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-07-01 09:39:08 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-07-01 09:40:14 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-07-01 09:37:41 | -1.6 | [OK] Fresh |
| df_InMaster_Raw | 2026-07-01 09:35:04 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-07-01 09:37:42 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-07-01 09:38:11 | -1.6 | [OK] Fresh |
| df_WarClaim_Raw | 2026-07-01 09:46:26 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-07-01 09:44:06 | -1.7 | [OK] Fresh |
| df_VhTrans_Raw | 2026-07-01 09:42:48 | -1.7 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-07-01 09:42:56 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-07-01 09:46:28 | -1.7 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-07-01 09:43:54 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-07-01 09:45:58 | -1.7 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-07-01 09:43:03 | -1.7 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-07-01 09:43:27 | -1.7 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-07-01 09:43:08 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-07-01 09:46:33 | -1.8 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-07-01 09:46:30 | -1.8 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-07-01 09:46:58 | -1.8 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-07-01 09:46:54 | -1.8 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-07-01 09:47:38 | -1.8 | [OK] Fresh |
| df_CONTACT_Raw | 2026-07-01 09:46:36 | -1.8 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-07-01 12:02:48 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-07-01 12:06:17 | -4.1 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

