# Data Freshness Report

**Generated:** 2026-03-19 06:01:26
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 70 | 58.3% |
| Stale | 0 | 0% |
| Critical | 45 | 37.5% |

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
- **df_Dim_WorkOrderStatus** (Dimension) - Never refreshed!
- **df_Dim_WorkOrderLookup** (Dimension) - Never refreshed!
- **df_Dim_WorkOrderMaster** (Dimension) - Never refreshed!
- **df_Dim_WorkOrderType** (Dimension) - Never refreshed!
- **df_Fact_InvoiceHeader** (FactTable) - Never refreshed!
- **df_Engaged_Acres** (AdHoc) - Never refreshed!
- **df_Dim_Vehicle** (Dimension) - Last refreshed: 2026-02-19 15:53:04 (662.1 hours ago)
- **df_Dim_DealerGroupCode** (Dimension) - Last refreshed: 2026-02-19 18:52:02 (659.2 hours ago)
- **df_Dim_Location** (Dimension) - Last refreshed: 2026-02-19 18:51:32 (659.2 hours ago)
- **df_Dim_SLC** (Dimension) - Last refreshed: 2026-02-19 18:51:33 (659.2 hours ago)
- **df_Dim_Source** (Dimension) - Last refreshed: 2026-02-19 18:51:32 (659.2 hours ago)
- **df_Dim_Franchise** (Dimension) - Last refreshed: 2026-02-19 18:51:32 (659.2 hours ago)
- **df_Dim_VendorCode** (Dimension) - Last refreshed: 2026-02-19 18:57:19 (659.1 hours ago)
- **df_Dim_ModuleType** (Dimension) - Last refreshed: 2026-02-19 18:54:12 (659.1 hours ago)
- **DF_PartMaster_Snapshot_Weekly** (AdHoc) - Last refreshed: 2026-03-15 06:04:32 (95.9 hours ago)

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
| DF_PartMaster_Snapshot_Weekly | 2026-03-15 06:04:32 | 95.9 | [CRIT] Critical |
| df_CustomerLookup | 2026-03-18 09:49:57 | 20.2 | [OK] Fresh |
| df_UniqueCustomer_Lookup | 2026-03-18 09:51:57 | 20.2 | [OK] Fresh |
| df_InTrans_Incremental | 2026-03-18 21:07:51 | 8.9 | [OK] Fresh |
| DF_PartMaster_Snapshot_Daily | 2026-03-19 07:05:00 | -1.1 | [OK] Fresh |

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
| df_Dim_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_BranchFranchise | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_Vehicle | 2026-02-19 15:53:04 | 662.1 | [CRIT] Critical |
| df_Dim_SLC | 2026-02-19 18:51:33 | 659.2 | [CRIT] Critical |
| df_Dim_Source | 2026-02-19 18:51:32 | 659.2 | [CRIT] Critical |
| df_Dim_DealerGroupCode | 2026-02-19 18:52:02 | 659.2 | [CRIT] Critical |
| df_Dim_Franchise | 2026-02-19 18:51:32 | 659.2 | [CRIT] Critical |
| df_Dim_Location | 2026-02-19 18:51:32 | 659.2 | [CRIT] Critical |
| df_Dim_ModuleType | 2026-02-19 18:54:12 | 659.1 | [CRIT] Critical |
| df_Dim_VendorCode | 2026-02-19 18:57:19 | 659.1 | [CRIT] Critical |
| df_Dim_Date | 2026-03-18 09:49:57 | 20.2 | [OK] Fresh |
| df_Dim_Customer | 2026-03-18 09:50:57 | 20.2 | [OK] Fresh |
| df_Dim_Part | 2026-03-18 09:53:57 | 20.1 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-03-18 09:56:38 | 20.1 | [OK] Fresh |
| df_Dim_JobCode | 2026-03-18 09:57:07 | 20.1 | [OK] Fresh |
| df_Dim_Technicans | 2026-03-18 09:56:07 | 20.1 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-03-18 09:56:07 | 20.1 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-03-18 09:58:07 | 20.1 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_InvoiceHeader | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_LaborWIP | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_WarrantyClaims | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_LaborPunches | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_LaborJobs | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_LaborInvoiced | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_Machines_Serviced | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_WorkOrderLabor | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_PartTransactions | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_Part_Transactions | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_WorkOrderComprehensive | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_WorkOrderHeader | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_WorkOrderJobs | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_Inventory | 2026-03-18 12:46:06 | 17.3 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-03-18 12:45:36 | 17.3 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-03-18 12:44:36 | 17.3 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-03-18 12:47:06 | 17.2 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-03-18 12:49:36 | 17.2 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-03-18 12:55:11 | 17.1 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-03-18 12:59:56 | 17 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-03-18 13:00:25 | 17 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-03-18 12:59:25 | 17 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-03-18 12:59:26 | 17 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-03-18 13:00:26 | 17 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-03-18 13:01:06 | 17 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-03-18 13:07:22 | 16.9 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-03-18 13:15:37 | 16.8 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-03-18 13:11:53 | 16.8 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-03-18 13:11:23 | 16.8 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-03-18 13:11:25 | 16.8 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-03-18 13:17:39 | 16.7 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-03-18 13:21:11 | 16.7 | [OK] Fresh |
| df_Fact_Transfers | 2026-03-18 13:22:07 | 16.7 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-03-18 13:24:57 | 16.6 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-03-18 13:25:19 | 16.6 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-03-18 13:24:50 | 16.6 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-03-18 13:31:20 | 16.5 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-03-18 21:17:33 | 8.7 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_INTRANS_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_CustomerAnatomy_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_InMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_WKVEHFL_Raw | 2026-03-18 09:29:55 | 20.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-03-18 09:29:55 | 20.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-03-18 09:30:25 | 20.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-03-18 09:29:55 | 20.5 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-03-18 09:33:07 | 20.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-03-18 09:29:25 | 20.5 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-03-18 09:33:36 | 20.5 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-03-18 09:38:19 | 20.4 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-03-18 09:37:50 | 20.4 | [OK] Fresh |
| df_VhTrans_Raw | 2026-03-18 09:37:49 | 20.4 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-03-18 09:38:20 | 20.4 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-03-18 09:38:20 | 20.4 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-03-18 09:34:37 | 20.4 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-03-18 09:38:49 | 20.4 | [OK] Fresh |
| df_INSALORD_Raw | 2026-03-18 09:35:06 | 20.4 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-03-18 09:35:07 | 20.4 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-03-18 09:34:38 | 20.4 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-03-18 09:41:31 | 20.3 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-03-18 09:41:30 | 20.3 | [OK] Fresh |
| df_WarClaim_Raw | 2026-03-18 09:41:30 | 20.3 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-03-18 09:41:30 | 20.3 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-03-18 09:42:00 | 20.3 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-03-18 09:41:30 | 20.3 | [OK] Fresh |
| df_CONTACT_Raw | 2026-03-18 09:42:00 | 20.3 | [OK] Fresh |
| df_Technician_Raw | 2026-03-18 09:42:01 | 20.3 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-03-18 09:43:30 | 20.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-03-19 09:21:42 | -3.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-03-19 09:20:11 | -3.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-03-19 09:21:11 | -3.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-03-19 09:17:41 | -3.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-03-19 09:24:42 | -3.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-03-19 09:23:42 | -3.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-03-19 09:42:15 | -3.7 | [OK] Fresh |

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

