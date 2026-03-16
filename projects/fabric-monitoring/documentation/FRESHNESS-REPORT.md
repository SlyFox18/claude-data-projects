# Data Freshness Report

**Generated:** 2026-03-16 06:01:27
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 70 | 58.3% |
| Stale | 0 | 0% |
| Critical | 44 | 36.7% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Fact_WarrantyClaims** (FactTable) - Never refreshed!
- **df_Fact_PartTransactions** (FactTable) - Never refreshed!
- **df_Fact_WorkOrderComprehensive** (FactTable) - Never refreshed!
- **df_Fact_WorkOrderJobs** (FactTable) - Never refreshed!
- **df_Fact_WorkOrderHeader** (FactTable) - Never refreshed!
- **df_Fact_Part_Transactions** (FactTable) - Never refreshed!
- **df_Fact_LaborJobs** (FactTable) - Never refreshed!
- **df_Fact_LaborInvoiced** (FactTable) - Never refreshed!
- **df_Fact_LaborPunches** (FactTable) - Never refreshed!
- **df_Fact_Machines_Serviced** (FactTable) - Never refreshed!
- **df_Fact_LaborWIP** (FactTable) - Never refreshed!
- **df_Transform_Jobs** (Transformation) - Never refreshed!
- **df_Transform_jdis_Part_Information** (Transformation) - Never refreshed!
- **df_Transform_Parts** (Transformation) - Never refreshed!
- **Equipment Service - Data Quality Validation** (AdHoc) - Never refreshed!
- **df_Transform_Vehicles** (Transformation) - Never refreshed!
- **df_Transform_Customers** (Transformation) - Never refreshed!
- **df_InMaster_Raw** (RawSource) - Never refreshed!
- **df_Fact_WorkOrderLabor** (FactTable) - Never refreshed!
- **df_INTRANS_Raw** (RawSource) - Never refreshed!
- **df_Part_Master_Duplicate_Analysis** (AdHoc) - Never refreshed!
- **df_jdis_Part_Information_Verification** (AdHoc) - Never refreshed!
- **df_Dim_InvoiceType** (Dimension) - Never refreshed!
- **df_Dim_InvoiceLookup** (Dimension) - Never refreshed!
- **df_Dim_SlicerControl** (Dimension) - Never refreshed!
- **df_Customer_ID_Analysis** (AdHoc) - Never refreshed!
- **df_DealerGroupCode_Analysis** (AdHoc) - Never refreshed!
- **df_CustomerAnatomy_Raw** (RawSource) - Never refreshed!
- **df_Dim_BranchFranchise** (Dimension) - Never refreshed!
- **df_Dim_Branch** (Dimension) - Never refreshed!
- **df_Dim_WorkOrderLookup** (Dimension) - Never refreshed!
- **df_Engaged_Acres** (AdHoc) - Never refreshed!
- **df_Dim_WorkOrderStatus** (Dimension) - Never refreshed!
- **df_Dim_WorkOrderType** (Dimension) - Never refreshed!
- **df_Dim_WorkOrderMaster** (Dimension) - Never refreshed!
- **df_Fact_InvoiceHeader** (FactTable) - Never refreshed!
- **df_Dim_Vehicle** (Dimension) - Last refreshed: 2026-02-19 15:53:04 (590.1 hours ago)
- **df_Dim_SLC** (Dimension) - Last refreshed: 2026-02-19 18:51:33 (587.2 hours ago)
- **df_Dim_DealerGroupCode** (Dimension) - Last refreshed: 2026-02-19 18:52:02 (587.2 hours ago)
- **df_Dim_Location** (Dimension) - Last refreshed: 2026-02-19 18:51:32 (587.2 hours ago)
- **df_Dim_Source** (Dimension) - Last refreshed: 2026-02-19 18:51:32 (587.2 hours ago)
- **df_Dim_Franchise** (Dimension) - Last refreshed: 2026-02-19 18:51:32 (587.2 hours ago)
- **df_Dim_VendorCode** (Dimension) - Last refreshed: 2026-02-19 18:57:19 (587.1 hours ago)
- **df_Dim_ModuleType** (Dimension) - Last refreshed: 2026-02-19 18:54:12 (587.1 hours ago)

---

## Freshness by Category

### AdHoc

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_jdis_Part_Information_Verification | Never | 999999 | [NEVER] Never Refreshed |
| df_Part_Master_Duplicate_Analysis | Never | 999999 | [NEVER] Never Refreshed |
| Equipment Service - Data Quality Validation | Never | 999999 | [NEVER] Never Refreshed |
| df_Engaged_Acres | Never | 999999 | [NEVER] Never Refreshed |
| df_DealerGroupCode_Analysis | Never | 999999 | [NEVER] Never Refreshed |
| df_Customer_ID_Analysis | Never | 999999 | [NEVER] Never Refreshed |
| DF_PartMaster_Snapshot_Weekly | 2026-03-15 06:04:32 | 23.9 | [OK] Fresh |
| DF_PartMaster_Snapshot_Daily | 2026-03-16 07:06:28 | -1.1 | [OK] Fresh |
| df_InTrans_Incremental | 2026-03-16 09:46:56 | -3.8 | [OK] Fresh |
| df_CustomerLookup | 2026-03-16 09:50:39 | -3.8 | [OK] Fresh |
| df_UniqueCustomer_Lookup | 2026-03-16 09:56:16 | -3.9 | [OK] Fresh |

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WorkOrderType | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_InvoiceType | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_InvoiceLookup | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_SlicerControl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WorkOrderStatus | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WorkOrderMaster | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WorkOrderLookup | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_BranchFranchise | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_Vehicle | 2026-02-19 15:53:04 | 590.1 | [CRIT] Critical |
| df_Dim_SLC | 2026-02-19 18:51:33 | 587.2 | [CRIT] Critical |
| df_Dim_Source | 2026-02-19 18:51:32 | 587.2 | [CRIT] Critical |
| df_Dim_DealerGroupCode | 2026-02-19 18:52:02 | 587.2 | [CRIT] Critical |
| df_Dim_Franchise | 2026-02-19 18:51:32 | 587.2 | [CRIT] Critical |
| df_Dim_Location | 2026-02-19 18:51:32 | 587.2 | [CRIT] Critical |
| df_Dim_VendorCode | 2026-02-19 18:57:19 | 587.1 | [CRIT] Critical |
| df_Dim_ModuleType | 2026-02-19 18:54:12 | 587.1 | [CRIT] Critical |
| df_Dim_Date | 2026-03-16 09:50:39 | -3.8 | [OK] Fresh |
| df_Dim_Customer | 2026-03-16 09:51:09 | -3.8 | [OK] Fresh |
| df_Dim_Part | 2026-03-16 09:53:40 | -3.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-03-16 09:58:26 | -4 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-03-16 09:58:57 | -4 | [OK] Fresh |
| df_Dim_JobCode | 2026-03-16 09:58:56 | -4 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-03-16 09:58:56 | -4 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_InvoiceHeader | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_LaborWIP | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_Machines_Serviced | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_PartTransactions | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_LaborJobs | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_LaborInvoiced | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_LaborPunches | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_WorkOrderJobs | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_WorkOrderLabor | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_Part_Transactions | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_WarrantyClaims | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_WorkOrderComprehensive | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_WorkOrderHeader | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_Parts_Details | 2026-03-16 10:07:20 | -4.1 | [OK] Fresh |
| df_Fact_Inventory | 2026-03-16 10:09:50 | -4.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-03-16 10:07:50 | -4.1 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-03-16 10:08:20 | -4.1 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-03-16 10:11:50 | -4.2 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-03-16 10:20:58 | -4.3 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-03-16 10:25:11 | -4.4 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-03-16 10:26:11 | -4.4 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-03-16 10:25:41 | -4.4 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-03-16 10:25:10 | -4.4 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-03-16 10:27:13 | -4.4 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-03-16 10:26:10 | -4.4 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-03-16 10:29:56 | -4.5 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-03-16 10:31:25 | -4.5 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-03-16 10:30:25 | -4.5 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-03-16 10:30:26 | -4.5 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-03-16 10:30:25 | -4.5 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-03-16 10:34:15 | -4.6 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-03-16 10:36:15 | -4.6 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-03-16 10:34:45 | -4.6 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-03-16 10:43:36 | -4.7 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-03-16 10:43:06 | -4.7 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-03-16 10:43:06 | -4.7 | [OK] Fresh |
| df_Fact_Transfers | 2026-03-16 10:40:46 | -4.7 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-03-16 10:44:06 | -4.7 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_CustomerAnatomy_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_InMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_INTRANS_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_Parts_InterbranchTransfer_Raw | 2026-03-16 09:20:13 | -3.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-03-16 09:21:13 | -3.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-03-16 09:20:43 | -3.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-03-16 09:22:43 | -3.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-03-16 09:22:43 | -3.4 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-03-16 09:23:13 | -3.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-03-16 09:25:43 | -3.4 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-03-16 09:32:10 | -3.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-03-16 09:28:29 | -3.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-03-16 09:29:00 | -3.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-03-16 09:28:59 | -3.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-03-16 09:29:30 | -3.5 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-03-16 09:33:10 | -3.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-03-16 09:29:29 | -3.5 | [OK] Fresh |
| df_INSALORD_Raw | 2026-03-16 09:31:40 | -3.5 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-03-16 09:32:10 | -3.5 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-03-16 09:32:40 | -3.5 | [OK] Fresh |
| df_VhTrans_Raw | 2026-03-16 09:37:57 | -3.6 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-03-16 09:39:34 | -3.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-03-16 09:37:56 | -3.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-03-16 09:37:56 | -3.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-03-16 09:37:57 | -3.6 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-03-16 09:38:26 | -3.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-03-16 09:35:10 | -3.6 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-03-16 09:42:52 | -3.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-03-16 09:42:53 | -3.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-03-16 09:42:21 | -3.7 | [OK] Fresh |
| df_Technician_Raw | 2026-03-16 09:42:53 | -3.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-03-16 09:42:21 | -3.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-03-16 09:42:21 | -3.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-03-16 09:42:52 | -3.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-03-16 09:42:23 | -3.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-03-16 09:42:21 | -3.7 | [OK] Fresh |

### Transformation

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Transform_Parts | Never | 999999 | [NEVER] Never Refreshed |
| df_Transform_Vehicles | Never | 999999 | [NEVER] Never Refreshed |
| df_Transform_Jobs | Never | 999999 | [NEVER] Never Refreshed |
| df_Transform_Customers | Never | 999999 | [NEVER] Never Refreshed |
| df_Transform_jdis_Part_Information | Never | 999999 | [NEVER] Never Refreshed |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

