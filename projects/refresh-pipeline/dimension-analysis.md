# Dimension Analysis - Pipeline_Dimensions

Cross-reference of all dimension dataflows against deployed semantic models.
Used to determine which dimensions need daily refresh vs weekly/monthly, and which dataflows are unused.

**Analysis Date:** February 19, 2026
**Source:** Scanned all 30 semantic models across 4 workspaces (RP - Parts Reports, RP - Service Reports, RP - Financial Reports, RP - Sandbox)

---

## Dimension Pipeline - Refresh Schedule

### Daily Refresh (data changes daily, critical for reports)

| Dataflow | Lakehouse Table | Reports | Why Daily |
|----------|----------------|---------|-----------|
| df_Dim_Part | dim_Parts | 11 reports | Parts data changes constantly (pricing, inventory, status) |
| df_Dim_Customer | dim_CustomerList | 8 reports | Customer assignments, CSM, route day change |
| df_Dim_Date | dim_DateTable | 18 reports | Dynamic flags (YTD, rolling periods, MTD) recalculate daily |
| df_UniqueCustomer_Lookup | lookup_UniqueCustomers_Invoice | 1 (Customer Anatomy V2) | Syncs with daily invoice data for unique customer flags |
| df_Dim_UniqueCustomers | dim_UniqueCustomers | 1 (Unique Parts Customers) | Syncs with daily fact tables |
| df_Dim_Branch12_Parts | dim_Branch12_Parts | 1 (Combine Vault Sales) | Has R12 rolling metrics that update daily |
| df_CustomerLookup | CustomerLookup | 1 (Customer Anatomy V2) | Fact-building helper, refreshes with dims for ordering |

**Total: 7 dataflows**

### Weekly Refresh (changes occasionally)

| Dataflow | Lakehouse Table | Reports | Notes |
|----------|----------------|---------|-------|
| df_Dim_Technicans | dim_Technician_Code_Names | 2 (Labor Perf V2, Open WO) | Technicians don't change often |
| df_Dim_JobCode | dim_JobCode | 2 (First Pass Fill, Top 50 Jobs) | Job codes are fairly stable |

**Total: 2 dataflows**

### Monthly Refresh (reference data, rarely changes)

| Dataflow | Lakehouse Table | Reports | Notes |
|----------|----------------|---------|-------|
| df_Dim_Location | dim_BranchLocation | 22 reports | Locations don't change; most-used dimension but static |
| df_Dim_DealerGroupCode | dim_DealerGroupCode | 3 (Bin Location, Price Matrix, Inv Analysis V3) | Reference codes |
| df_Dim_Franchise | dim_Franchise | 4 (Bin Location, Price Matrix, Inv Analysis V3, Sparc) | 43 manufacturers |
| df_Dim_SLC | dim_SLC | 2 (Price Matrix, Inv Analysis V3) | 123 stock location codes |
| df_Dim_Source | dim_Source | 2 (Price Matrix, Inv Analysis V3) | 267 source codes |
| df_Dim_VendorCode | dim_VendorCode | 2 (Price Matrix, Inv Analysis V3) | 1,311 vendor codes |
| df_Dim_ModuleType | dim_ModuleType | 1 (Inv Analysis V3) | 11 invoice module types |
| df_Dim_CommodityCode | dim_CommodityCode | 1 (Inv Analysis V3) | 780 commodity codes |
| df_Dim_PaymentMethod | dim_PaymentMethod | 1 (Inv Analysis V3) | 5 payment methods |
| df_Dim_AdjustmentType | dim_AdjustmentType | 1 (Parts Adjustments) | 7 static adjustment types |
| df_Dim_PromoType | dim_PromoType | 1 (Parts Promo) | Promo type classification |
| df_Dim_RepairOrder | dim_RepairOrder | 1 (Parts Promo) | Repair order dimension |
| df_Dim_JobType | Dim_JobType | 1 (Top 50 Job Codes) | 7 job types |

**Total: 13 dataflows**

---

## Dimension Usage Cross-Reference

### By Report (which dimensions each report uses)

| Report | Workspace | Dimensions Used |
|--------|-----------|-----------------|
| **Customer Anatomy V2** | RP - Sandbox | dim_BranchLocation, dim_CustomerList, dim_DateTable, dim_Parts, dim_EngagedAcres*, lookup_UniqueCustomers_Invoice |
| **Inspections - V2** | RP - Service Reports | dim_BranchLocation, dim_CustomerList, dim_DateTable, dim_Parts |
| **Inventory Analysis V3** | RP - Sandbox | dim_BranchLocation, dim_CommodityCode, dim_DealerGroupCode, dim_Franchise, dim_ModuleType, dim_Parts, dim_PaymentMethod, dim_SLC, dim_Source, dim_VendorCode, dim_DateTable |
| **Open Work Orders** | RP - Service Reports | dim_BranchLocation, dim_CustomerList, dim_DateTable, dim_Technician_Code_Names, dim_AgingBucket* |
| **Labor Performance V2** | RP - Service Reports | dim_BranchLocation, dim_DateTable, dim_Technician_Code_Names |
| **First Pass Fill** | RP - Parts Reports | dim_BranchLocation, dim_DateTable, dim_Parts, dim_JobCode |
| **Parts Adjustments** | RP - Parts Reports | dim_BranchLocation, dim_DateTable, dim_Parts, dim_AdjustmentType |
| **Parts Promo** | RP - Sandbox | dim_BranchLocation, dim_CustomerList, dim_DateTable, dim_Parts, dim_PromoType, dim_RepairOrder |
| **Price Matrix** | RP - Parts Reports | dim_BranchLocation, dim_DateTable, dim_DealerGroupCode, dim_Franchise, dim_Parts, dim_SLC, dim_Source, dim_VendorCode |
| **60+ Days Past Due** | RP - Financial Reports | dim_BranchLocation, dim_CustomerList, dim_DateTable |
| **Unique Parts Customers** | RP - Parts Reports | dim_BranchLocation, dim_CustomerList, dim_DateTable, dim_UniqueCustomers |
| **Combine Vault Sales** | RP - Parts Reports | dim_BranchLocation, dim_Branch12_Parts, dim_DateTable, dim_Parts |
| **Part Sales with Low Margin** | RP - Parts Reports | dim_BranchLocation, dim_CustomerList, dim_DateTable, dim_Parts, dim_Parts_LowMargin* |
| **Pin Capture** | RP - Parts Reports | dim_BranchLocation, dim_CustomerList, dim_DateTable, dim_Parts |
| **Parts Not Re-Ordered** | RP - Parts Reports | dim_BranchLocation, dim_DateTable |
| **Open Parts Tickets** | RP - Parts Reports | dim_BranchLocation, dim_DateTable |
| **Negative On Hand** | RP - Parts Reports | dim_BranchLocation, dim_DateTable |
| **Physical Inventory** | RP - Parts Reports | dim_BranchLocation, dim_DateTable |
| **Bin Location Report** | RP - Parts Reports | dim_BranchLocation, dim_DealerGroupCode, dim_Franchise, dim_Parts |
| **Sparc Inventory Health** | RP - Sandbox | dim_BranchLocation, dim_DateTable, dim_Franchise |
| **Top 50 - Job Codes** | RP - Sandbox | dim_BranchLocation, dim_DateTable, dim_JobCode, Dim_JobType |

*dim_EngagedAcres = CSV upload, not a dataflow
*dim_AgingBucket = calculated table in semantic model
*dim_Parts_LowMargin = inline Power Query in semantic model (no dataflow)

### By Dimension (which reports use each dimension)

| Dimension | Count | Reports |
|-----------|-------|---------|
| dim_BranchLocation | 22 | All modernized reports |
| dim_DateTable | 18 | All reports except Bin Location |
| dim_Parts | 11 | Parts Adjustments, Bin Location, Combine Vault, First Pass Fill, Low Margin, Pin Capture, Price Matrix, Inspections V2, Customer Anatomy V2, Inv Analysis V3, Parts Promo |
| dim_CustomerList | 8 | Low Margin, Pin Capture, Unique Parts, 60+ Past Due, Inspections V2, Open WO, Customer Anatomy V2, Parts Promo |
| dim_Franchise | 4 | Bin Location, Price Matrix, Inv Analysis V3, Sparc |
| dim_DealerGroupCode | 3 | Bin Location, Price Matrix, Inv Analysis V3 |
| dim_JobCode | 2 | First Pass Fill, Top 50 Jobs |
| dim_Technician_Code_Names | 2 | Labor Perf V2, Open WO |
| dim_SLC | 2 | Price Matrix, Inv Analysis V3 |
| dim_Source | 2 | Price Matrix, Inv Analysis V3 |
| dim_VendorCode | 2 | Price Matrix, Inv Analysis V3 |
| lookup_UniqueCustomers_Invoice | 1 | Customer Anatomy V2 |
| dim_UniqueCustomers | 1 | Unique Parts Customers |
| dim_Branch12_Parts | 1 | Combine Vault Sales |
| dim_AdjustmentType | 1 | Parts Adjustments |
| dim_PromoType | 1 | Parts Promo |
| dim_RepairOrder | 1 | Parts Promo |
| dim_CommodityCode | 1 | Inv Analysis V3 |
| dim_ModuleType | 1 | Inv Analysis V3 |
| dim_PaymentMethod | 1 | Inv Analysis V3 |
| Dim_JobType | 1 | Top 50 Job Codes |

---

## Unused Dataflows - Archive Candidates

These dataflows exist in `LH_Master_Data / Dataflows / 03 - Dimensions` but are NOT referenced by any deployed semantic model.

| Dataflow | Lakehouse Table | Notes |
|----------|----------------|-------|
| **df_Dim_BranchFranchise** | dim_BranchFranchise | Inv Analysis V3 uses a calculated table instead |
| **df_Dim_InvoiceLookup** | dim_InvoiceLookup | Not used by any model |
| **df_Dim_InvoiceType** | dim_InvoiceType | Not used by any model |
| **df_Dim_SlicerControl** | SlicerTable | Models use calculated slicer tables instead |
| **df_Dim_Vehicle** | dim_Vehicle | Feature not yet deployed to any report |
| **df_Dim_WorkOrderLookup** | dim_WorkOrderLookup | Not used by any model |
| **df_Dim_WorkOrderMaster** | dim_WorkOrderMaster | Not used by any model |
| **df_Dim_WorkOrderStatus** | Dim_WorkOrderStatus | Not used by any model |
| **df_Dim_WorkOrderType** | dim_WorkOrderType | Not used by any model |

### Borderline - Legacy Only

| Dataflow | Lakehouse Table | Notes |
|----------|----------------|-------|
| **df_Dim_Branch** | dim_Branch | Only used by 5 legacy/old reports (pre-migration to dim_BranchLocation). All V2 reports use dim_BranchLocation. Candidate for archive once legacy reports are retired. |

### Not a Dataflow (report-level only)

| Table | Notes |
|-------|-------|
| dim_Parts_LowMargin | Built with inline Power Query at semantic model level. Decision documented in `projects/part sales with low margin/docs/05-archive/COLUMN-SOURCE-DECISION.md` |
| dim_AgingBucket | Calculated table in Open Work Orders semantic model |
| dim_EngagedAcres | CSV upload to Lakehouse, not a dataflow |
| dim_DateFilter | Parameter table in Inventory Analysis V3 |

---

## Pipeline_Dimensions - Proposed Batch Structure

Based on the daily refresh group (7 DFs), structured into 2 batches:

### Batch 1 (4 concurrent, starts immediately)
- **df_Dim_Part** (dim_Parts) - heaviest, ~5-6 min solo
- **df_Dim_Customer** (dim_CustomerList) - ~2 min solo
- **df_CustomerLookup** (CustomerLookup) - ~1:30 solo
- **df_Dim_Date** (dim_DateTable) - <15 sec solo

### Batch 2 (3 concurrent, after Batch 1)
- **df_UniqueCustomer_Lookup** (lookup_UniqueCustomers_Invoice) - ~1:30 solo
- **df_Dim_UniqueCustomers** (dim_UniqueCustomers) - ~1:30 solo
- **df_Dim_Branch12_Parts** (dim_Branch12_Parts) - ~1:30 solo

### Monthly dimensions (set inactive or separate pipeline)
All 13 monthly DFs - run manually or on a monthly schedule

### Weekly dimensions (evaluate adding to daily or separate schedule)
df_Dim_Technicans, df_Dim_JobCode - 2 DFs

**Actual daily pipeline duration: 8m 26s** (Batch 1: 5m 44s limited by dim_Parts, Batch 2: 2m 38s)
**Actual monthly pipeline duration: 13m 17s** (3 batches of 5/5/3)

Tested Feb 19, 2026 ~12 PM (business hours). Expect faster at 3:30 AM off-peak.

---

**Last Updated:** February 19, 2026
